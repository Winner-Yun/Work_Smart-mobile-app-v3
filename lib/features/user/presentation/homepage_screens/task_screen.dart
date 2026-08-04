import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/core/constants/app_durations.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/task_detail_screen.dart';
import 'package:flutter_worksmart_app/features/user/repository/task_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/task_service.dart';
import 'package:flutter_worksmart_app/shared/model/task_model.dart';
import 'package:flutter_worksmart_app/shared/widget/common/task_skeleton_loading.dart';
import 'package:flutter_worksmart_app/shared/widget/user/data_empty_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaskScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const TaskScreen({super.key, this.loginData});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final TaskRepository _taskRepo = TaskRepository(TaskService());
  List<TaskModel> _tasks = <TaskModel>[];
  String? _workspaceId;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _scrolledUp = false;

  // Set by tapping a stat in the header; null shows every task.
  String? _statusFilter;

  // Manual pull-to-refresh only — the silent background refresh in
  // `_initData` never touches this flag.
  bool get isRefreshing => _isRefreshing;

  List<TaskModel> get _visibleTasks => _statusFilter == null
      ? _tasks
      : _tasks.where((t) => t.status == _statusFilter).toList();

  SharedPreferences? _prefs;
  late final ScrollController _scrollController;

  String? get _cacheKey => (_workspaceId == null || _workspaceId!.isEmpty)
      ? null
      : 'cached_tasks_$_workspaceId';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _initData();
  }

  // Matches the homepage/leave-screen overscroll-to-refresh gesture.
  void _onScroll() {
    if (_scrollController.position.pixels < -100 &&
        !_scrolledUp &&
        !_isRefreshing) {
      _scrolledUp = true;
      _loadTasks();
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

  // Cache-first: show cached data immediately, then refresh from the
  // network in the background; only a true cold start shows the skeleton.
  Future<void> _initData() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    _workspaceId = _prefs!.getString('selected_workspace_id');

    if (_workspaceId == null || _workspaceId!.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final bool hasLocalData = await _loadFromLocal();

    if (!mounted) return;

    if (hasLocalData) {
      // Brief artificial delay so loading doesn't pop in instantly.
      await Future.delayed(AppDurations.minSkeletonDisplay);
      if (!mounted) return;
      setState(() => _isLoading = false);
      _fetchFromNetwork(showLoading: false);
    } else {
      await _fetchFromNetwork(showLoading: true);
    }
  }

  Future<bool> _loadFromLocal() async {
    final prefs = _prefs;
    final cacheKey = _cacheKey;
    if (prefs == null || cacheKey == null) return false;

    final cachedJson = prefs.getString(cacheKey);
    if (cachedJson == null) return false;

    try {
      final List<dynamic> decoded = jsonDecode(cachedJson);
      _tasks =
          decoded
              .map((json) => TaskModel.fromJson(json as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return _tasks.isNotEmpty;
    } catch (e) {
      debugPrint('[TaskScreen] Error parsing cached tasks: $e');
      return false;
    }
  }

  // Only toggles _isLoading — _isRefreshing is owned by `_loadTasks`;
  // also used for the silent background refresh in `_initData`.
  Future<void> _fetchFromNetwork({required bool showLoading}) async {
    final workspaceId = _workspaceId;
    if (workspaceId == null || workspaceId.isEmpty) return;

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final tasks = await _taskRepo.getWorkspaceTasks(workspaceId)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;

      final newJson = jsonEncode(tasks.map((t) => t.toJson()).toList());
      final currentJson = jsonEncode(_tasks.map((t) => t.toJson()).toList());

      if (newJson != currentJson) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
        await _saveToCache(newJson);
      } else if (showLoading) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[TaskScreen] Failed to load tasks: $e');
      if (mounted && showLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveToCache(String tasksJson) async {
    final prefs = _prefs;
    final cacheKey = _cacheKey;
    if (prefs == null || cacheKey == null) return;
    try {
      await prefs.setString(cacheKey, tasksJson);
    } catch (e) {
      debugPrint('[TaskScreen] Error saving tasks cache: $e');
    }
  }

  // Swaps to the skeleton (see build) instead of the overscroll indicator;
  // always clears `_isRefreshing` in finally so a failed refresh can't
  // permanently block further pulls.
  Future<void> _loadTasks() async {
    if (_isRefreshing || !mounted) return;
    setState(() => _isRefreshing = true);
    try {
      await _fetchFromNetwork(showLoading: false);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _openTaskDetail(TaskModel task) async {
    final result = await Navigator.push<TaskModel>(
      context,
      MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)),
    );

    if (result != null && mounted) {
      setState(() {
        final index = _tasks.indexWhere((t) => t.id == result.id);
        if (index != -1) _tasks[index] = result;
      });
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return AppStrings.tr('request_status_in_progress');
      case 'completed':
        return AppStrings.tr('request_status_completed');
      case 'pending':
      default:
        return AppStrings.tr('request_status_pending');
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'in_progress':
        return Icons.autorenew_rounded;
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'pending':
      default:
        return Icons.schedule_rounded;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'in_progress':
        return AppColors.info;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.error;
      case 'low':
        return AppColors.success;
      case 'medium':
      default:
        return AppColors.warning;
    }
  }

  IconData _priorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Icons.keyboard_double_arrow_up_rounded;
      case 'low':
        return Icons.keyboard_arrow_down_rounded;
      case 'medium':
      default:
        return Icons.drag_handle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<TaskModel> visibleTasks = _visibleTasks;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppStrings.tr('task_menu'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading || _isRefreshing
          ? const TaskSkeletonLoading()
          : Stack(
              alignment: Alignment.topCenter,
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      sliver: SliverToBoxAdapter(child: _buildStatsHeader()),
                    ),
                    if (visibleTasks.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.45,
                          child: DataEmptyState(
                            imageAsset: AppImg.emptyState,
                            message: AppStrings.tr('no_tasks_yet'),
                          ),
                        ).animate().fadeIn(duration: 300.ms),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return _buildTaskItem(visibleTasks[index])
                                  .animate()
                                  .fadeIn(
                                    delay: (60 * index).ms,
                                    duration: 240.ms,
                                  )
                                  .slideY(
                                    begin: 0.08,
                                    end: 0,
                                    curve: Curves.easeOut,
                                  );
                            },
                            childCount: visibleTasks.length,
                          ),
                        ),
                      ),
                  ],
                ),
                _buildPullToRefreshIndicator(),
              ],
            ),
    );
  }

  Widget _buildStatsHeader() {
    final int pendingCount = _tasks
        .where((t) => t.status == 'pending')
        .length;
    final int inProgressCount = _tasks
        .where((t) => t.status == 'in_progress')
        .length;
    final int completedCount = _tasks
        .where((t) => t.status == 'completed')
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 18),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatTile(
              AppColors.warning,
              pendingCount,
              AppStrings.tr('request_status_pending'),
              'pending',
            ),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatTile(
              AppColors.info,
              inProgressCount,
              AppStrings.tr('request_status_in_progress'),
              'in_progress',
            ),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatTile(
              AppColors.success,
              completedCount,
              AppStrings.tr('request_status_completed'),
              'completed',
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildStatTile(Color color, int count, String label, String status) {
    final bool isSelected = _statusFilter == status;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() => _statusFilter = isSelected ? null : status);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 3,
              width: isSelected ? 22 : 0,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Theme.of(context).dividerColor.withOpacity(0.15),
    );
  }

  // Matches the homepage/leave-screen overscroll-to-refresh gesture.
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

  Widget _buildTaskItem(TaskModel task) {
    final statusColor = _statusColor(task.status);
    final priorityColor = _priorityColor(task.priority);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openTaskDetail(task),
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 14),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(20),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: priorityColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _priorityIcon(task.priority),
                                color: priorityColor,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ((task.description ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            task.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if ((task.deadline ?? '').trim().isNotEmpty) ...[
                              Icon(
                                Icons.event_outlined,
                                size: 14,
                                color: AppColors.textGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                task.deadline!,
                                style: TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                            ] else
                              const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _statusIcon(task.status),
                                    size: 12,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _statusLabel(task.status),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
