import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/core/util/database/realtime_data_controller.dart';
import 'package:flutter_worksmart_app/core/util/database/user_data.dart';
import 'package:flutter_worksmart_app/features/user/logic/leave_request_logic.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/leave_detail_view_screen.dart';
import 'package:flutter_worksmart_app/shared/model/activity_models/leave_record.dart';
import 'package:flutter_worksmart_app/shared/model/user_model/user_profile.dart';
import 'package:flutter_worksmart_app/shared/widget/user/data_empty_state.dart';
import 'package:intl/intl.dart';

class LeaveAllRequestsScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const LeaveAllRequestsScreen({super.key, this.loginData});

  @override
  State<LeaveAllRequestsScreen> createState() => _LeaveAllRequestsScreenState();
}

class _LeaveAllRequestsScreenState extends State<LeaveAllRequestsScreen> {
  late UserProfile _currentUser;
  late List<LeaveRecord> _history;
  late List<LeaveRecord> _filteredHistory = [];
  late String? loggedInUserId;
  DateTime? _selectedDate;
  String? _selectedForRemoveRequestId;
  bool _isRemoveMode = false;
  bool _hasDeletedLeaveRequest = false;
  bool _isLoading = true;
  LeaveSortBy _sortBy = LeaveSortBy.dateNewest;
  final RealtimeDataController _realtimeDataController =
      RealtimeDataController();

  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    loggedInUserId = widget.loginData?['uid'];
    _loadData();
  }

  Future<void> _loadData() async {
    final resolvedUserId = _resolveUserId();
    debugPrint('Resolved user ID: $resolvedUserId');
    debugPrint('loginUserId: $loggedInUserId');
    final users = await _realtimeDataController.fetchUserRecords();

    final currentUserData = users.firstWhere(
      (user) =>
          (user['uid'] ?? user['user_id'] ?? user['userId'])
              .toString()
              .trim() ==
          resolvedUserId,
      orElse: () => users.first,
    );
    debugPrint(usersFinalData.toString());
    _currentUser = UserProfile.fromJson(currentUserData);

    _history = _currentUser.leaveRecords.toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    setState(() {
      _currentUser = UserProfile.fromJson(currentUserData);

      _history = (_currentUser.leaveRecords).toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));

      _applyFilter();
      _isLoading = false;
    });
  }

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

  void _applyFilter() {
    _filteredHistory = LeaveRequestLogic.filterHistoryByDate(
      _history,
      _selectedDate,
    );
    _filteredHistory = LeaveRequestLogic.sortHistory(_filteredHistory, _sortBy);
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
      _applyFilter();
    });
  }

  void _clearDate() {
    setState(() {
      _selectedDate = null;
      _applyFilter();
    });
  }

  void _handleLongPress(LeaveRecord record, bool isSelectedForRemove) {
    if (!LeaveRequestLogic.canRemoveStatus(record.status)) return;
    final LeaveRemoveModeState state =
        LeaveRequestLogic.getLongPressRemoveModeState(
          record: record,
          isSelectedForRemove: isSelectedForRemove,
        );

    setState(() {
      _selectedForRemoveRequestId = state.selectedForRemoveRequestId;
      _isRemoveMode = state.isRemoveMode;
    });
  }

  Future<void> _handleTap(LeaveRecord record, bool isSelectedForRemove) async {
    if (_isRemoveMode) {
      if (!LeaveRequestLogic.canRemoveStatus(record.status)) {
        await LeaveRequestLogic.showRemoveNotAllowedDialog(context);
        return;
      }
      final LeaveRemoveModeState state =
          LeaveRequestLogic.getTapRemoveModeState(
            record: record,
            isSelectedForRemove: isSelectedForRemove,
          );

      setState(() {
        _selectedForRemoveRequestId = state.selectedForRemoveRequestId;
        _isRemoveMode = state.isRemoveMode;
      });
      return;
    }

    final bool? wasDeleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LeaveDetailViewScreen(leave: record, userId: _currentUser.uid),
      ),
    );

    if (wasDeleted == true && mounted) {
      setState(() {
        _selectedForRemoveRequestId = null;
        _isRemoveMode = false;
        _hasDeletedLeaveRequest = true;
        _loadData();
      });
    }
  }

  Future<void> _confirmAndDelete(LeaveRecord record) async {
    final bool removed = await LeaveRequestLogic.confirmAndDeleteLeave(
      context,
      record: record,
      userId: _currentUser.uid,
    );
    if (!removed) return;

    setState(() {
      _selectedForRemoveRequestId = null;
      _isRemoveMode = false;
      _hasDeletedLeaveRequest = true;
      _loadData();
    });
  }

  void _popWithResult() {
    Navigator.pop(context, _hasDeletedLeaveRequest);
  }

  Future<bool> _onWillPop() async {
    _popWithResult();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(context),
        body: Column(
          children: [
            _buildFilterAndSort(context),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState(context)
                  : _filteredHistory.isEmpty
                  ? _buildEmptyState(context)
                        .animate(key: const ValueKey('leave-empty-state'))
                        .fadeIn(duration: 260.ms, curve: Curves.easeOut)
                        .slideY(
                          begin: 0.06,
                          end: 0,
                          duration: 260.ms,
                          curve: Curves.easeOut,
                        )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filteredHistory.length,
                      itemBuilder: (context, index) {
                        final record = _filteredHistory[index];
                        return _buildRequestListItem(record)
                            .animate()
                            .fadeIn(delay: (80 * index).ms)
                            .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios,
          color: Theme.of(context).iconTheme.color,
          size: 20,
        ),
        onPressed: _popWithResult,
      ),
      title: Text(
        AppStrings.tr('request_history'),
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildFilterAndSort(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        children: [
          // Date Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedDate == null
                        ? 'All dates'
                        : _dateFormatter.format(_selectedDate!),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _pickDate(context),
                  child: Text(
                    AppStrings.tr('select_date'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_selectedDate != null)
                  IconButton(
                    onPressed: _clearDate,
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.grey,
                    tooltip: 'Clear',
                  ),
              ],
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 12),
          // Sort Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.sort,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<LeaveSortBy>(
                    value: _sortBy,
                    underline: const SizedBox(),
                    isExpanded: true,
                    onChanged: (LeaveSortBy? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _sortBy = newValue;
                          _applyFilter();
                        });
                      }
                    },
                    items: [
                      DropdownMenuItem(
                        value: LeaveSortBy.dateNewest,
                        child: Text(
                          AppStrings.tr('sort_newest_date'),
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: LeaveSortBy.dateOldest,
                        child: Text(
                          AppStrings.tr('sort_oldest_date'),
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: LeaveSortBy.statusPending,
                        child: Text(
                          AppStrings.tr('status_pending'),
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: LeaveSortBy.statusApproved,
                        child: Text(
                          AppStrings.tr('status_approved'),
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: LeaveSortBy.statusRejected,
                        child: Text(
                          AppStrings.tr('status_rejected'),
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return DataEmptyState(
      imageAsset: AppImg.emptyState,
      message: AppStrings.tr('no_records'),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildRequestListItem(LeaveRecord record) {
    final String title = LeaveRequestLogic.getLeaveTitle(record.type);
    final String subtitle = LeaveRequestLogic.formatDateRange(record);
    final String status = LeaveRequestLogic.getStatusText(record.status);
    final Color statusColor = LeaveRequestLogic.getStatusColor(record.status);
    final IconData icon = LeaveRequestLogic.getLeaveIcon(record.type);
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
          _handleLongPress(record, isSelectedForRemove);
        },
        onTap: () async {
          await _handleTap(record, isSelectedForRemove);
        },
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
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
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 13,
                      ),
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
