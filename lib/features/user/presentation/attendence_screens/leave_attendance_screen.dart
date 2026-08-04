import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/core/constants/app_durations.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/features/user/repository/leave_repository.dart';
import 'package:flutter_worksmart_app/features/user/repository/policy_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/leave_service.dart';
import 'package:flutter_worksmart_app/features/user/service/policy_service.dart';
import 'package:flutter_worksmart_app/features/user/logic/leave_request_logic.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/leave_all_requests_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/leave_detail_view_screen.dart';
import 'package:flutter_worksmart_app/shared/model/leave_model.dart';
import 'package:flutter_worksmart_app/shared/widget/common/leave_attendance_skeleton_loading.dart';
import 'package:flutter_worksmart_app/shared/widget/common/task_icon_button.dart';
import 'package:flutter_worksmart_app/shared/widget/user/data_empty_state.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeaveAttendanceScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const LeaveAttendanceScreen({super.key, this.loginData});

  @override
  State<LeaveAttendanceScreen> createState() => _LeaveAttendanceScreenState();
}

class _LeaveAttendanceScreenState extends State<LeaveAttendanceScreen> {
  // Fallback totals until the workspace policy provides the real limits.
  static const int _defaultAnnualTotal = 18;
  static const int _defaultSickTotal = 5;

  final LeaveRepository _leaveRepo = LeaveRepository(LeaveService());
  final PolicyRepository _policyRepo = PolicyRepository(PolicyService());
  List<LeaveModel> _leaveRecords = <LeaveModel>[];
  List<LeaveModel> _history = <LeaveModel>[];
  String? _workspaceId;
  int _annualTotal = _defaultAnnualTotal;
  int _sickTotal = _defaultSickTotal;
  int _annualUsed = 0;
  int _sickUsed = 0;
  int _annualRemaining = _defaultAnnualTotal;
  int _sickRemaining = _defaultSickTotal;
  late Map<String, dynamic>? loginData;
  String? _selectedForRemoveRequestId;
  bool _isRemoveMode = false;
  bool _isOpeningAllRequests = false;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _scrolledUp = false;

  late final ScrollController _scrollController;

  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    loginData = widget.loginData;
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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

  // Cache-first; a true cold start still waits on the network since
  // there's nothing meaningful to show otherwise.
  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _workspaceId = prefs.getString('selected_workspace_id');

    if (_workspaceId == null || _workspaceId!.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final String workspaceId = _workspaceId!;
    final cachedPolicyMap = await DatabaseHelper().getCachedPolicy(
      workspaceId,
    );
    final List<LeaveModel>? cachedLeaves = await _readCachedLeaves(
      prefs,
      workspaceId,
    );

    final bool hasLocalData = cachedPolicyMap != null || cachedLeaves != null;

    if (hasLocalData) {
      _applyPolicyLimits(cachedPolicyMap);
      // Brief artificial delay so the cache read doesn't pop in instantly.
      await Future.delayed(AppDurations.minSkeletonDisplay);
      if (mounted) {
        setState(() {
          _leaveRecords = cachedLeaves ?? <LeaveModel>[];
          _applyLeaveComputations();
          _isLoading = false;
        });
      }
      unawaited(_refreshFromServerInBackground());
    } else {
      await _fetchPolicyFromServer();
      await _loadData();
    }
  }

  Future<void> _refreshFromServerInBackground() async {
    final String? workspaceId = _workspaceId;
    if (workspaceId == null || workspaceId.isEmpty) return;

    await _fetchPolicyFromServer();

    try {
      final List<LeaveModel> fetchedLeaves = await _leaveRepo.getMyLeaves(
        workspaceId,
      );

      final bool leavesChanged =
          jsonEncode(_leaveRecords.map((l) => l.toJson()).toList()) !=
          jsonEncode(fetchedLeaves.map((l) => l.toJson()).toList());

      if (leavesChanged) {
        if (!mounted) return;
        setState(() {
          _leaveRecords = fetchedLeaves;
          _applyLeaveComputations();
        });
      }

      final prefs = await SharedPreferences.getInstance();
      await _saveCachedLeaves(prefs, workspaceId, fetchedLeaves);
    } catch (e) {
      // Best-effort; the cache-first data already on screen stays put.
      debugPrint(
        '[LeaveAttendanceScreen] Background leave refresh failed: $e',
      );
    }
  }

  Future<List<LeaveModel>?> _readCachedLeaves(
    SharedPreferences prefs,
    String workspaceId,
  ) async {
    final String? raw = prefs.getString(_leavesCacheKey(workspaceId));
    if (raw == null) return null;
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => LeaveModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint(
        '[LeaveAttendanceScreen] Failed to decode cached leaves: $e',
      );
      return null;
    }
  }

  Future<void> _saveCachedLeaves(
    SharedPreferences prefs,
    String workspaceId,
    List<LeaveModel> leaves,
  ) async {
    final String encoded = jsonEncode(
      leaves.map((l) => l.toJson()).toList(),
    );
    await prefs.setString(_leavesCacheKey(workspaceId), encoded);
  }

  String _leavesCacheKey(String workspaceId) => 'cached_leaves_$workspaceId';

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _workspaceId = prefs.getString('selected_workspace_id');

    if (_workspaceId == null || _workspaceId!.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final cachedPolicyMap = await DatabaseHelper().getCachedPolicy(
      _workspaceId!,
    );
    _applyPolicyLimits(cachedPolicyMap);

    try {
      final leaves = await _leaveRepo.getMyLeaves(_workspaceId!);
      if (!mounted) return;
      setState(() {
        _leaveRecords = leaves;
        _applyLeaveComputations();
        _isLoading = false;
      });
      await _saveCachedLeaves(prefs, _workspaceId!, leaves);
    } catch (e) {
      // The list endpoint is unreliable; fail open with an empty list.
      debugPrint('[LeaveAttendanceScreen] Failed to load leaves: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyLeaveComputations() {
    _annualUsed = _sumUsedDays(
      (type) => type.contains('annual') || type.contains('casual'),
    );
    _sickUsed = _sumUsedDays((type) => type.contains('sick'));

    _annualRemaining = (_annualTotal - _annualUsed).clamp(0, _annualTotal);
    _sickRemaining = (_sickTotal - _sickUsed).clamp(0, _sickTotal);

    _history = _leaveRecords.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _applyPolicyLimits(Map<String, dynamic>? policyMap) {
    final int? annualLimit = _readPositiveInt(policyMap?['annual_leave_limit']);
    final int? sickLimit = _readPositiveInt(policyMap?['sick_leave_limit']);
    if (annualLimit != null) _annualTotal = annualLimit;
    if (sickLimit != null) _sickTotal = sickLimit;
  }

  int? _readPositiveInt(dynamic value) {
    final int? parsed = value is num ? value.toInt() : int.tryParse('$value');
    return (parsed != null && parsed > 0) ? parsed : null;
  }

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
        _annualRemaining = (_annualTotal - _annualUsed).clamp(0, _annualTotal);
        _sickRemaining = (_sickTotal - _sickUsed).clamp(0, _sickTotal);
      });
    } catch (e) {
      // Policy refresh is best-effort; fall back to whatever is cached.
      debugPrint('[LeaveAttendanceScreen] Failed to refresh policy: $e');
    }
  }

  // Guarded by _isRefreshing so continuous overscroll doesn't refire this
  // on every scroll event (see _onScroll).
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    if (mounted) setState(() => _isRefreshing = true);

    await _fetchPolicyFromServer();
    await _loadData();

    if (mounted) setState(() => _isRefreshing = false);
  }

  int _sumUsedDays(bool Function(String normalizedLeaveType) matches) {
    return _leaveRecords
        .where(
          (record) =>
              matches(record.leaveType.toLowerCase()) &&
              record.status == 'approved',
        )
        .fold(0, (sum, record) => sum + record.durationInDays);
  }

  void _handleLongPress(LeaveModel record) {
    if (!LeaveRequestLogic.canRemoveStatus(record.status)) return;
    setState(() {
      final bool isSelectedForRemove = _selectedForRemoveRequestId == record.id;

      if (isSelectedForRemove) {
        _selectedForRemoveRequestId = null;
        _isRemoveMode = false;
      } else {
        _selectedForRemoveRequestId = record.id;
        _isRemoveMode = true;
      }
    });
  }

  Future<void> _handleTap(LeaveModel record) async {
    final bool isSelectedForRemove = _selectedForRemoveRequestId == record.id;

    if (_isRemoveMode) {
      if (!LeaveRequestLogic.canRemoveStatus(record.status)) {
        await LeaveRequestLogic.showRemoveNotAllowedDialog(context);
        return;
      }
      setState(() {
        if (isSelectedForRemove) {
          _selectedForRemoveRequestId = null;
          _isRemoveMode = false;
        } else {
          _selectedForRemoveRequestId = record.id;
        }
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
        _isRemoveMode = false;
        _loadData();
      });
    }
  }

  Future<void> _confirmAndDelete(LeaveModel record) async {
    final bool removed = await LeaveRequestLogic.confirmAndDeleteLeave(
      context,
      record: record,
      onDelete: () => _leaveRepo.deleteLeave(record.id),
    );
    if (!removed) return;

    setState(() {
      _selectedForRemoveRequestId = null;
      _isRemoveMode = false;
      _loadData();
    });
  }

  Future<void> _openLeaveRequest(String routeName) async {
    if (routeName == AppRoute.sickleaveScreen) {
      final activeSickRequests = _leaveRecords
          .where(
            (record) =>
                record.leaveType.toLowerCase().contains('sick') &&
                (record.status == 'pending' || record.status == 'approved'),
          )
          .length;

      if (activeSickRequests >= 1) {
        return;
      }
    }

    await Navigator.pushNamed(context, routeName, arguments: loginData);
    if (!mounted) return;

    setState(() {
      _selectedForRemoveRequestId = null;
      _isRemoveMode = false;
      _loadData();
    });
  }

  Future<void> _openAllRequests() async {
    if (_isOpeningAllRequests) return;
    _isOpeningAllRequests = true;

    try {
      final Object? result = await Navigator.pushNamed(
        context,
        AppRoute.leaveAllRequestsScreen,
        arguments: loginData,
      );

      if (!mounted || result != true) return;

      setState(() {
        _selectedForRemoveRequestId = null;
        _isRemoveMode = false;
        _loadData();
      });
    } catch (error) {
      if (!mounted) return;

      final bool? fallbackResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => LeaveAllRequestsScreen(loginData: loginData),
        ),
      );

      if (!mounted || fallbackResult != true) return;

      setState(() {
        _selectedForRemoveRequestId = null;
        _isRemoveMode = false;
        _loadData();
      });
    } finally {
      _isOpeningAllRequests = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      bottomNavigationBar: _buildBottomAction(context),
      body: _isLoading || _isRefreshing
          ? const LeaveAttendanceSkeletonLoading()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummarySection(context),
                          const SizedBox(height: 30),
                          _buildListHeader(context),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 260.ms)
                    .slideY(begin: -0.04, end: 0),

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
                                  top: MediaQuery.of(context).size.height * 0.1,
                                ),
                                child: _buildEmptyState(context),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final record = _history[index];
                                  return _buildRequestListItem(
                                        record: record,
                                        context: context,
                                        title: LeaveRequestLogic.getLeaveTitle(
                                          record.leaveType,
                                        ),
                                        subtitle: _formatDateRange(record),
                                        status: LeaveRequestLogic.getStatusText(
                                          record.status,
                                        ),
                                        statusColor:
                                            LeaveRequestLogic.getStatusColor(
                                              record.status,
                                            ),
                                        icon: LeaveRequestLogic.getLeaveIcon(
                                          record.leaveType,
                                        ),
                                        onLongPress: () {
                                          _handleLongPress(record);
                                        },
                                        onTap: () async {
                                          await _handleTap(record);
                                        },
                                      )
                                      .animate()
                                      .fadeIn(
                                        delay: (index * 45).ms,
                                        duration: 220.ms,
                                      )
                                      .slideX(begin: 0.06, end: 0);
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
    );
  }

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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      title: Text(
        AppStrings.tr('leave_menu'),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [TaskIconButton(loginData: loginData)],
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            context: context,
            title: AppStrings.tr('annual_leave'),
            value: _annualRemaining.toString().padLeft(2, '0'),
            icon: Icons.calendar_today_outlined,
            iconColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildSummaryCard(
            context: context,
            title: AppStrings.tr('sick_leave'),
            value: _sickRemaining.toString().padLeft(2, '0'),
            icon: Icons.medical_services_outlined,
            iconColor: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AppStrings.tr('recent_requests'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: () async {
            await _openAllRequests();
          },
          child: Text(
            AppStrings.tr('view_all'),
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return DataEmptyState(
      imageAsset: AppImg.emptyState,
      message: AppStrings.tr('no_records'),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    final activeSickRequests = _leaveRecords
        .where(
          (record) =>
              record.leaveType.toLowerCase().contains('sick') &&
              (record.status == 'pending' || record.status == 'approved'),
        )
        .length;
    final canRequestSick = activeSickRequests < 1;

    return Container(
          padding: const EdgeInsets.fromLTRB(20, 15, 20, 35),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: canRequestSick
                      ? () => _openLeaveRequest(AppRoute.sickleaveScreen)
                      : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 55),
                    side: BorderSide(
                      color: canRequestSick
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
                      color: canRequestSick
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
                  onPressed: () =>
                      _openLeaveRequest(AppRoute.annualleaveScreen),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    minimumSize: const Size(0, 55),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    AppStrings.tr('request_annual_leave'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: 180.ms, duration: 240.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 4),

              Expanded(
                child: Text(
                  AppStrings.tr('days_remaining'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateRange(LeaveModel record) {
    final DateTime startDate = record.startDate;
    final DateTime endDate = record.endDate;

    if (startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day) {
      return _dateFormatter.format(startDate);
    }

    final String endText = DateFormat('dd MMM yyyy').format(endDate);
    String startText = DateFormat('dd MMM').format(startDate);

    if (startDate.year == endDate.year && startDate.month == endDate.month) {
      startText = DateFormat('dd').format(startDate);
    }

    return '$startText - $endText';
  }

  Widget _buildRequestListItem({
    required LeaveModel record,
    required BuildContext context,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required IconData icon,
    VoidCallback? onLongPress,
    VoidCallback? onTap,
  }) {
    final bool isRemovable = LeaveRequestLogic.canRemoveStatus(record.status);
    final bool isSelectedForRemove =
        isRemovable && _selectedForRemoveRequestId == record.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(15),
            border: isSelectedForRemove
                ? Border.all(
                    color: Colors.red.withValues(alpha: 0.35),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).dividerColor.withOpacity(0.1),
                child: Icon(icon, color: Colors.grey, size: 20),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    if (record.reason.trim().isNotEmpty) ...[
                      Text(
                        record.reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
