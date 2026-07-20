import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/core/util/database/realtime_data_controller.dart';
import 'package:flutter_worksmart_app/core/util/database/user_data.dart';
import 'package:flutter_worksmart_app/features/user/logic/leave_request_logic.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/leave_all_requests_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/leave_detail_view_screen.dart';
import 'package:flutter_worksmart_app/shared/model/activity_models/leave_record.dart';
import 'package:flutter_worksmart_app/shared/model/user_model/user_profile.dart';
import 'package:flutter_worksmart_app/shared/widget/common/leave_management_skeleton_loading.dart';
import 'package:flutter_worksmart_app/shared/widget/user/data_empty_state.dart';
import 'package:intl/intl.dart';

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

  static const int _annualTotal = 18;
  static const int _sickTotal = 5;

  late UserProfile _currentUser;
  late List<LeaveRecord> _leaveRecords;
  late List<LeaveRecord> _history;
  late int _annualUsed;
  late int _sickUsed;
  late double _annualRatio;
  late double _sickRatio;

  String? _selectedForRemoveRequestId;
  bool _isOpeningAllRequests = false;
  bool _isLoading = true;

  final RealtimeDataController _realtimeDataController =
      RealtimeDataController();

  String _resolveUserId() {
    // Try to get from loginData first
    final fromLoginData =
        (widget.loginData?['uid'] ??
                widget.loginData?['user_id'] ??
                widget.loginData?['userId'] ??
                '')
            .toString()
            .trim();

    if (fromLoginData.isNotEmpty) {
      return fromLoginData;
    }

    // Fall back to FirebaseAuth current user
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (firebaseUid.isNotEmpty) {
      return firebaseUid;
    }

    // Last resort: use first user from the list if available
    if (usersFinalData.isNotEmpty) {
      final firstUserId =
          (usersFinalData.first['uid'] ??
                  usersFinalData.first['user_id'] ??
                  usersFinalData.first['userId'] ??
                  '')
              .toString()
              .trim();
      if (firstUserId.isNotEmpty) {
        return firstUserId;
      }
    }

    return '';
  }

  @override
  void initState() {
    super.initState();

    // Initialize late variables with default values to prevent LateInitializationError
    _currentUser = UserProfile.fromJson(defaultUserRecord);
    _leaveRecords = [];
    _history = [];
    _annualUsed = 0;
    _sickUsed = 0;
    _annualRatio = 0.0;
    _sickRatio = 0.0;

    // Set up animation controllers
    _annualController = AnimationController(vsync: this, duration: 1500.ms);
    _sickController = AnimationController(vsync: this, duration: 1500.ms);

    // Load actual data first
    _loadData();

    // Now create and start animations with the loaded data
    _annualAnimation = Tween<double>(begin: 0, end: _annualRatio).animate(
      CurvedAnimation(parent: _annualController, curve: Curves.easeInOut),
    );
    _sickAnimation = Tween<double>(begin: 0, end: _sickRatio).animate(
      CurvedAnimation(parent: _sickController, curve: Curves.easeInOut),
    );

    _annualController.forward();
    _sickController.forward();
  }

  Future<void> _loadData() async {
    final resolvedUserId = _resolveUserId();

    await _loadUserDataFromFirebase(resolvedUserId);
  }

  Future<void> _loadUserDataFromFirebase(String userId) async {
    try {
      final users = await _realtimeDataController.fetchUserRecords();

      if (users.isEmpty) {
        setState(() {
          _currentUser = UserProfile.fromJson(defaultUserRecord);
          _applyUserData();
          _isLoading = false;
        });
        return;
      }

      final userData = users.firstWhere(
        (user) =>
            (user['uid'] ?? user['user_id'] ?? user['userId'])
                .toString()
                .trim() ==
            userId,
        orElse: () => users.first,
      );
      debugPrint(userData.toString());

      setState(() {
        _currentUser = UserProfile.fromJson(userData);
        _applyUserData();
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrintStack(stackTrace: stack);

      setState(() {
        _currentUser = UserProfile.fromJson(defaultUserRecord);
        _leaveRecords = _currentUser.leaveRecords;
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

  void _applyUserData() {
    _leaveRecords = _currentUser.leaveRecords;

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
        .where((record) => record.type == type && record.status == 'approved')
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

  Future<void> _confirmAndDelete(LeaveRecord record) async {
    final bool removed = await LeaveRequestLogic.confirmAndDeleteLeave(
      context,
      record: record,
      userId: _currentUser.uid,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Column(
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
            child: _isLoading
                ? const LeaveManagementSkeletonLoading()
                : _history.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 20,
                    ),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final record = _history[index];
                      return _buildTimelineItem(record);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAction(),
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

  Widget _buildTimelineItem(LeaveRecord record) {
    final String title = LeaveRequestLogic.getLeaveTitle(record.type);
    final String statusText = LeaveRequestLogic.getStatusText(record.status);
    final Color color = LeaveRequestLogic.getStatusColor(record.status);
    final String dateLabel = _formatDateRange(record.startDate, record.endDate);
    final bool isRemovable = LeaveRequestLogic.canRemoveStatus(record.status);
    final bool isSelectedForRemove =
        isRemovable && _selectedForRemoveRequestId == record.requestId;

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
                : record.requestId;
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
                  : record.requestId;
            });
            return;
          }

          final bool? wasDeleted = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => LeaveDetailViewScreen(
                leave: record,
                userId: _currentUser.uid,
              ),
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
              record.type == 'sick_leave' &&
              (record.status == 'pending' || record.status == 'approved'),
        )
        .length;
  }
}
