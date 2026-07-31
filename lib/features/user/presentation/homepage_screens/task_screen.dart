import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
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

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (mounted) setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    _workspaceId = prefs.getString('selected_workspace_id');

    if (_workspaceId == null || _workspaceId!.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final tasks = await _taskRepo.getWorkspaceTasks(_workspaceId!);
      if (!mounted) return;
      setState(() {
        _tasks = tasks..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[TaskScreen] Failed to load tasks: $e');
      if (mounted) setState(() => _isLoading = false);
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
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'pending':
      default:
        return 'Pending';
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
        return AppColors.warning;
      case 'pending':
      default:
        return AppColors.textGrey;
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tasks',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const TaskSkeletonLoading()
          : RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: _loadTasks,
              child: _tasks.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: DataEmptyState(
                            imageAsset: AppImg.emptyState,
                            message: 'No tasks yet',
                          ),
                        ).animate().fadeIn(duration: 300.ms),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        return _buildTaskItem(_tasks[index])
                            .animate()
                            .fadeIn(delay: (60 * index).ms, duration: 240.ms)
                            .slideY(begin: 0.08, end: 0, curve: Curves.easeOut);
                      },
                    ),
            ),
    );
  }

  Widget _buildTaskItem(TaskModel task) {
    final statusColor = _statusColor(task.status);
    final priorityColor = _priorityColor(task.priority);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openTaskDetail(task),
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
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
                      left: Radius.circular(16),
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
