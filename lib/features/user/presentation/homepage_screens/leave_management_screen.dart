import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/features/user/auth/repository/leave_repository.dart';
import 'package:flutter_worksmart_app/features/user/auth/repository/policy_repository.dart';
import 'package:flutter_worksmart_app/features/user/auth/service/leave_service.dart';
import 'package:flutter_worksmart_app/features/user/auth/service/policy_service.dart';
import 'package:flutter_worksmart_app/features/user/logic/leave_request_logic.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/leave_all_requests_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/leave_detail_view_screen.dart';
import 'package:flutter_worksmart_app/shared/model/leave_model.dart';
import 'package:flutter_worksmart_app/shared/widget/common/leave_management_skeleton_loading.dart';
import 'package:flutter_worksmart_app/shared/widget/user/data_empty_state.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeaveDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const LeaveDetailScreen({super.key, this.loginData});

  @override
  State<LeaveDetailScreen> createState() => _LeaveDetailScreenState();
}

class _LeaveDetailScreenState extends State<LeaveDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _annualController;
  late AnimationController _sickController;
  late Animation<double> _annualAnimation;
  late Animation<double> _sickAnimation;

  // Fallback totals used until the workspace policy (cached locally, or
  // freshly fetched from the server) provides the real limits.
  static const int _defaultAnnualTotal = 18;
  static const int _defaultSickTotal = 5;
  int _annualTotal = _defaultAnnualTotal;
  int _sickTotal = _defaultSickTotal;

  final LeaveRepository _leaveRepo = LeaveRepository(LeaveService());
  final PolicyRepository _policyRepo = PolicyRepository(PolicyService());
  List<LeaveModel> _leaveRecords = <LeaveModel>[];
  List<LeaveModel> _history = <LeaveModel>[];
  String? _workspaceId;
  int _annualUsed = 0;
  int _sickUsed = 0;
  double _annualRatio = 0.0;
  double _sickRatio = 0.0;

  String? _selectedForRemoveRequestId;
  bool _isOpeningAllRequests = false;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _scrolledUp = false;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();

    // Set up animation controllers
    _annualController = AnimationController(vsync: this, duration: 1500.ms);
    _sickController = AnimationController(vsync: this, duration: 1500.ms);

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Now create the animations; they'll be re-targeted once real data
    // (and the real policy totals) have loaded.
    _annualAnimation = Tween<double>(begin: 0, end: _annualRatio).animate(
      CurvedAnimation(parent: _annualController, curve: Curves.easeInOut),
    );
    _sickAnimation = Tween<double>(begin: 0, end: _sickRatio).animate(
      CurvedAnimation(parent: _sickController, curve: Curves.easeInOut),
    );

    _loadInitialData();
  }

  void _onScroll() {
    if (_scrollController.position.pixels < -100 &&
        !_scrolledUp &&
        !_isRefreshing) {
      _scrolledUp = true;
      _handleRefresh();
    } else if (_scrollController.position.pixels >= -10) {
      _scrolledUp = false;
    }
  }

  /// Resolves the workspace, then waits for the policy to be fetched fresh
  /// from the server before loading the leave list — the skeleton stays up
  /// for this whole span, so the screen never flashes the hardcoded
  /// fallback totals (or a stale cached value) before jumping to the real
  /// numbers a moment later.
  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _workspaceId = prefs.getString('selected_workspace_id');

    if (_workspaceId == null || _workspaceId!.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    await _fetchPolicyFromServer();
    await _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _workspaceId = prefs.getString('selected_workspace_id');

    if (_workspaceId == null || _workspaceId!.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Leave totals come from the workspace policy, cached locally — read it
    // here instead of hardcoding limits. By the time this runs on initial
    // load, `_loadInitialData` has already awaited a fresh server fetch, so
    // this is normally reading back what that fetch just saved.
    final cachedPolicyMap = await DatabaseHelper().getCachedPolicy(
      _workspaceId!,
    );
    _applyPolicyLimits(cachedPolicyMap);

    try {
      final leaves = await _leaveRepo.getMyLeaves(_workspaceId!);
      if (!mounted) return;
      setState(() {
        _leaveRecords = leaves;
        _applyUserData();
        _isLoading = false;
      });
    } catch (e) {
      // The list endpoint is known to be unreliable right now, so fail
      // open with an empty list rather than crashing the screen.
      debugPrint('[LeaveDetailScreen] Failed to load leaves: $e');
      if (mounted) {
        setState(() {
          _leaveRecords = <LeaveModel>[];
          _annualUsed = 0;
          _sickUsed = 0;
          _annualRatio = 0;
          _sickRatio = 0;
          _history = [];
          _isLoading = false;
          _updateAnimations();
        });
      }
    }
  }

  void _applyPolicyLimits(Map<String, dynamic>? policyMap) {
    final int? annualLimit = _readPositiveInt(
      policyMap?['annual_leave_limit'],
    );
    final int? sickLimit = _readPositiveInt(policyMap?['sick_leave_limit']);
    if (annualLimit != null) _annualTotal = annualLimit;
    if (sickLimit != null) _sickTotal = sickLimit;
  }

  int? _readPositiveInt(dynamic value) {
    final int? parsed = value is num ? value.toInt() : int.tryParse('$value');
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  /// Fetches the policy fresh from the server, updates the local cache
  /// (skipping the write if nothing changed), and refreshes the on-screen
  /// totals. Best-effort: falls back to whatever is cached on failure.
  Future<void> _fetchPolicyFromServer() async {
    final String? workspaceId = _workspaceId;
    if (workspaceId == null || workspaceId.isEmpty) return;

    try {
      final fetchedPolicy = await _policyRepo.getPolicy(workspaceId);
      final policyMap = {
        'id': fetchedPolicy.id,
        'workspace_id': fetchedPolicy.workspaceId,
        'name': fetchedPolicy.name,
        'work_start_time': fetchedPolicy.workStartTime,
        'work_end_time': fetchedPolicy.workEndTime,
        'check_in_start': fetchedPolicy.checkInStart,
        'check_out_start': fetchedPolicy.checkOutStart,
        'late_buffer_minutes': fetchedPolicy.lateBufferMinutes,
        'deadline_scan_minutes': fetchedPolicy.deadlineScanMinutes,
        'annual_leave_limit': fetchedPolicy.annualLeaveLimit,
        'sick_leave_limit': fetchedPolicy.sickLeaveLimit,
        'status': fetchedPolicy.status,
      };

      final cachedPolicyMap = await DatabaseHelper().getCachedPolicy(
        workspaceId,
      );
      final bool policyChanged =
          cachedPolicyMap == null ||
          jsonEncode(cachedPolicyMap) != jsonEncode(policyMap);
      if (policyChanged) {
        await DatabaseHelper().saveCachedPolicy(workspaceId, policyMap);
      }

      if (!mounted) return;
      setState(() {
        _applyPolicyLimits(policyMap);
        _annualRatio = (_annualUsed / _annualTotal).clamp(0, 1).toDouble();
        _sickRatio = (_sickUsed / _sickTotal).clamp(0, 1).toDouble();
      });
    } catch (e) {
      // Policy refresh is best-effort; fall back to whatever is cached.
      debugPrint('[LeaveDetailScreen] Failed to refresh policy: $e');
    }
  }

  /// Pull-to-refresh (triggered by overscrolling past the top, matching the
  /// homepage gesture): re-fetches the policy fresh and reloads the leave
  /// list. Guarded by `_isRefreshing`/`_scrolledUp` (see `_onScroll`) so a
  /// single pull gesture only triggers one round of calls instead of firing
  /// again on every scroll event while overscrolled.
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    if (mounted) setState(() => _isRefreshing = true);

    await _fetchPolicyFromServer();
    await _loadData();

    if (mounted) setState(() => _isRefreshing = false);
  }

  void _applyUserData() {
    _annualUsed = _sumUsedDays('annual_leave');
    _sickUsed = _sumUsedDays('sick_leave');

    _annualRatio = (_annualUsed / _annualTotal).clamp(0, 1).toDouble();
    _sickRatio = (_sickUsed / _sickTotal).clamp(0, 1).toDouble();

    _history = _leaveRecords.toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    _updateAnimations();
  }

  int _sumUsedDays(String type) {
    final approvedRecords = _leaveRecords
        .where(
          (record) => record.leaveType == type && record.status == 'approved',
        )
        .toList();

    return approvedRecords.fold(
      0,
      (sum, record) => sum + record.durationInDays,
    );
  }

  void _updateAnimations() {
    // Update animations with new ratio values
    _annualAnimation = Tween<double>(begin: 0, end: _annualRatio).animate(
      CurvedAnimation(parent: _annualController, curve: Curves.easeInOut),
    );
    _sickAnimation = Tween<double>(begin: 0, end: _sickRatio).animate(
      CurvedAnimation(parent: _sickController, curve: Curves.easeInOut),
    );

    // Restart animations
    _annualController.forward(from: 0);
    _sickController.forward(from: 0);
  }

  void _refreshLeaveDataWithAnimation() {
    _loadData();
    _annualAnimation = Tween<double>(begin: 0, end: _annualRatio).animate(
      CurvedAnimation(parent: _annualController, curve: Curves.easeInOut),
    );
    _sickAnimation = Tween<double>(begin: 0, end: _sickRatio).animate(
      CurvedAnimation(parent: _sickController, curve: Curves.easeInOut),
    );
    _annualController.forward(from: 0);
    _sickController.forward(from: 0);
  }

  Future<void> _confirmAndDelete(LeaveModel record) async {
    final bool removed = await LeaveRequestLogic.confirmAndDeleteLeave(
      context,
      record: record,
      onDelete: () => _leaveRepo.deleteLeave(record.id),
      showSnackBar: false,
    );
    if (!removed) return;

    setState(() {
      _selectedForRemoveRequestId = null;
      _refreshLeaveDataWithAnimation();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        content: Text(
          AppStrings.tr('leave_request_removed'),
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _annualController.dispose();
    _sickController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: _isLoading || _isRefreshing
          ? const LeaveManagementSkeletonLoading()
          : Column(
              children: [
                _buildDoubleOverviewCard(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        AppStrings.tr('request_history'),
                        AppStrings.tr('view_all'),
                      ),
                      const SizedBox(height: 5),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          if (_history.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top:
                                      MediaQuery.of(context).size.height *
                                      0.1,
                                ),
                                child: _buildEmptyState(context),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.only(
                                left: 20,
                                right: 20,
                                bottom: 20,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final record = _history[index];
                                  return _buildTimelineItem(record);
                                }, childCount: _history.length),
                              ),
                            ),
                        ],
                      ),
                      _buildPullToRefreshIndicator(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomAction(),
    );
  }

  // --- Pull-to-refresh indicator: matches the homepage's overscroll-driven
  // rotating arrow → refresh icon. Once the pull is released, `_isRefreshing`
  // swaps the whole screen to the skeleton loader (see `build` above) so
  // this indicator never needs its own "loading" state or text.
  Widget _buildPullToRefreshIndicator() {
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        if (!_scrollController.hasClients) return const SizedBox.shrink();

        double overscroll = _scrollController.position.pixels < 0
            ? -_scrollController.position.pixels
            : 0.0;

        if (overscroll <= 0 || _isLoading || _isRefreshing) {
          return const SizedBox.shrink();
        }

        double progress = (overscroll / 100.0).clamp(0.0, 1.0);
        bool isReadyToRelease = progress >= 0.95;

        return Positioned(
          top: 10 + (overscroll * 0.2),
          child: Opacity(
            opacity: progress,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).cardTheme.color ??
                    (Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade800
                        : Colors.white),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Transform.rotate(
                angle: progress * 6.28,
                child: Icon(
                  isReadyToRelease
                      ? Icons.refresh_rounded
                      : Icons.arrow_downward_rounded,
                  color: isReadyToRelease
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade500,
                  size: 22,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.tertiary,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        AppStrings.tr('leave_details_title'),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildDoubleOverviewCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 30, left: 20, right: 20, top: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildLeaveProgressItem(
                  _annualAnimation,
                  _annualUsed,
                  _annualTotal,
                  AppStrings.tr('annual_leave'),
                  Colors.white,
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
              Expanded(
                child: _buildLeaveProgressItem(
                  _sickAnimation,
                  _sickUsed,
                  _sickTotal,
                  AppStrings.tr('sick_leave'),
                  AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white70, size: 16),
              const SizedBox(width: 5),
              Text(
                '${AppStrings.tr('you_have_remaining_leave')} ${(_annualTotal - _annualUsed) + (_sickTotal - _sickUsed)} ${AppStrings.tr('days')} ${AppStrings.tr('this_year')}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveProgressItem(
    Animation<double> animation,
    int used,
    int total,
    String label,
    Color color,
  ) {
    return Row(
      children: [
        _buildAnimatedCircularIndicator(animation, used, total, color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${AppStrings.tr('remaining')} ${total - used} ${AppStrings.tr('days')}",
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedCircularIndicator(
    Animation<double> animation,
    int used,
    int total,
    Color color,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 55,
              height: 55,
              child: CircularProgressIndicator(
                value: animation.value,
                strokeWidth: 5,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  color == Colors.white ? AppColors.secondary : color,
                ),
              ),
            ),
            Text(
              "$used/$total",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimelineItem(LeaveModel record) {
    final String title = LeaveRequestLogic.getLeaveTitle(record.leaveType);
    final String statusText = LeaveRequestLogic.getStatusText(record.status);
    final Color color = LeaveRequestLogic.getStatusColor(record.status);
    final String dateLabel = _formatDateRange(record.startDate, record.endDate);
    final bool isRemovable = LeaveRequestLogic.canRemoveStatus(record.status);
    final bool isSelectedForRemove =
        isRemovable && _selectedForRemoveRequestId == record.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        onLongPress: () {
          if (!isRemovable) return;
          setState(() {
            _selectedForRemoveRequestId = isSelectedForRemove
                ? null
                : record.id;
          });
        },
        onTap: () async {
          if (_selectedForRemoveRequestId != null) {
            if (!isRemovable) {
              await LeaveRequestLogic.showRemoveNotAllowedDialog(context);
              return;
            }
            setState(() {
              _selectedForRemoveRequestId = isSelectedForRemove
                  ? null
                  : record.id;
            });
            return;
          }

          final bool? wasDeleted = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => LeaveDetailViewScreen(leave: record),
            ),
          );

          if (wasDeleted == true && mounted) {
            setState(() {
              _selectedForRemoveRequestId = null;
              _refreshLeaveDataWithAnimation();
            });
          }
        },
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(15),
            border: isSelectedForRemove
                ? Border.all(
                    color: Colors.red.withValues(alpha: 0.35),
                    width: 1,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              isSelectedForRemove
                  ? TextButton.icon(
                      onPressed: () => _confirmAndDelete(record),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: Text(
                        AppStrings.tr('remove_button'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )
                  : Text(
                      statusText,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  String _formatDateRange(DateTime start, DateTime end) {
    final formatter = DateFormat('dd MMM yyyy');
    final startLabel = formatter.format(start);
    final endLabel = formatter.format(end);

    if (startLabel == endLabel) {
      return startLabel;
    }
    return "$startLabel - $endLabel";
  }

  Widget _buildEmptyState(BuildContext context) {
    return DataEmptyState(
      imageAsset: AppImg.emptyState,
      message: AppStrings.tr('no_records'),
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        if (action.isNotEmpty)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              await _openAllRequests();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                action,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomAction() {
    final bool canRequestSickLeave = _getActiveSickRequestCount() < 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: canRequestSickLeave
                  ? () => _openLeaveRequest(AppRoute.sickleaveScreen)
                  : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 55),
                side: BorderSide(
                  color: canRequestSickLeave
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.withOpacity(0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                AppStrings.tr('request_sick_leave'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: canRequestSickLeave
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _openLeaveRequest(AppRoute.annualleaveScreen),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                minimumSize: const Size(0, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                AppStrings.tr('request_annual_leave'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLeaveRequest(String routeName) async {
    if (routeName == AppRoute.sickleaveScreen) {
      final int activeSickRequests = _getActiveSickRequestCount();
      if (activeSickRequests >= 2) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You already have $activeSickRequests active sick leave request(s). Please wait for approval or remove an existing request.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    await Navigator.pushNamed(context, routeName, arguments: widget.loginData);
    if (!mounted) return;

    setState(() {
      _selectedForRemoveRequestId = null;
      _refreshLeaveDataWithAnimation();
    });
  }

  Future<void> _openAllRequests() async {
    if (_isOpeningAllRequests) return;
    _isOpeningAllRequests = true;

    try {
      final Object? result = await Navigator.pushNamed(
        context,
        AppRoute.leaveAllRequestsScreen,
        arguments: widget.loginData,
      );

      if (!mounted || result != true) return;

      setState(() {
        _selectedForRemoveRequestId = null;
        _refreshLeaveDataWithAnimation();
      });
    } catch (error) {
      debugPrint('Failed to open leaveAllRequestsScreen: $error');
      if (!mounted) return;

      final bool? fallbackResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              LeaveAllRequestsScreen(loginData: widget.loginData),
        ),
      );

      if (!mounted || fallbackResult != true) return;

      setState(() {
        _selectedForRemoveRequestId = null;
        _refreshLeaveDataWithAnimation();
      });
    } finally {
      _isOpeningAllRequests = false;
    }
  }

  int _getActiveSickRequestCount() {
    return _leaveRecords
        .where(
          (record) =>
              record.leaveType == 'sick_leave' &&
              (record.status == 'pending' || record.status == 'approved'),
        )
        .length;
  }
}
