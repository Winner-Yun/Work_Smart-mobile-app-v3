import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/features/user/repository/leave_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/leave_service.dart';
import 'package:flutter_worksmart_app/features/user/logic/leave_request_logic.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/leave_detail_view_screen.dart';
import 'package:flutter_worksmart_app/shared/model/leave_model.dart';
import 'package:flutter_worksmart_app/shared/widget/common/system_loading_dialog.dart';
import 'package:flutter_worksmart_app/shared/widget/user/data_empty_state.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeaveAllRequestsScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const LeaveAllRequestsScreen({super.key, this.loginData});

  @override
  State<LeaveAllRequestsScreen> createState() => _LeaveAllRequestsScreenState();
}

class _LeaveAllRequestsScreenState extends State<LeaveAllRequestsScreen> {
  final LeaveRepository _leaveRepo = LeaveRepository(LeaveService());
  List<LeaveModel> _history = <LeaveModel>[];
  List<LeaveModel> _filteredHistory = <LeaveModel>[];
  String? _workspaceId;
  DateTime? _selectedDate;
  String? _selectedForRemoveRequestId;
  bool _isRemoveMode = false;
  bool _hasDeletedLeaveRequest = false;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _scrolledUp = false;
  LeaveSortBy _sortBy = LeaveSortBy.dateNewest;

  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy');
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadData();
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

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Scroll-up-to-refresh (matches homepage/leave-management gesture). Shows
  /// SystemLoadingDialog over the current list instead of the initial-load
  /// spinner, and always clears via `finally` so a failed fetch can't leave
  /// the non-dismissible dialog stuck or permanently block further
  /// pull-to-refresh attempts.
  Future<void> _handleRefresh() async {
    if (_isRefreshing || !mounted) return;
    setState(() => _isRefreshing = true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SystemLoadingDialog(
        title: 'Refreshing...',
        subtitle: 'Getting the latest leave data',
      ),
    );

    try {
      await _loadData();
    } catch (e) {
      debugPrint('[LeaveAllRequestsScreen] refresh error: $e');
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _workspaceId = prefs.getString('selected_workspace_id');

    if (_workspaceId == null || _workspaceId!.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final leaves = await _leaveRepo.getMyLeaves(_workspaceId!);
      if (!mounted) return;
      setState(() {
        _history = leaves.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      // The list endpoint is known to be unreliable right now, so fail
      // open with an empty list rather than crashing the screen.
      debugPrint('[LeaveAllRequestsScreen] Failed to load leaves: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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

  void _handleLongPress(LeaveModel record, bool isSelectedForRemove) {
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

  Future<void> _handleTap(LeaveModel record, bool isSelectedForRemove) async {
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
        builder: (context) => LeaveDetailViewScreen(leave: record),
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
                  : Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        CustomScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          slivers: [
                            if (_filteredHistory.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: _buildEmptyState(context)
                                    .animate(
                                      key: const ValueKey('leave-empty-state'),
                                    )
                                    .fadeIn(
                                      duration: 260.ms,
                                      curve: Curves.easeOut,
                                    )
                                    .slideY(
                                      begin: 0.06,
                                      end: 0,
                                      duration: 260.ms,
                                      curve: Curves.easeOut,
                                    ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  10,
                                  20,
                                  20,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final record = _filteredHistory[index];
                                    return _buildRequestListItem(record)
                                        .animate()
                                        .fadeIn(delay: (80 * index).ms)
                                        .slideY(
                                          begin: 0.1,
                                          end: 0,
                                          curve: Curves.easeOut,
                                        );
                                  }, childCount: _filteredHistory.length),
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
      ),
    );
  }

  // Matches the homepage/leave-screen overscroll gesture.
  Widget _buildPullToRefreshIndicator() {
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        if (!_scrollController.hasClients) return const SizedBox.shrink();

        double overscroll = _scrollController.position.pixels < 0
            ? -_scrollController.position.pixels
            : 0.0;

        if (overscroll <= 0 || _isRefreshing) {
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

  Widget _buildRequestListItem(LeaveModel record) {
    final String title = LeaveRequestLogic.getLeaveTitle(record.leaveType);
    final String subtitle = LeaveRequestLogic.formatDateRange(record);
    final String status = LeaveRequestLogic.getStatusText(record.status);
    final Color statusColor = LeaveRequestLogic.getStatusColor(record.status);
    final IconData icon = LeaveRequestLogic.getLeaveIcon(record.leaveType);
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
                    if (record.reason.trim().isNotEmpty) ...[
                      Text(
                        record.reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textGrey.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
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
