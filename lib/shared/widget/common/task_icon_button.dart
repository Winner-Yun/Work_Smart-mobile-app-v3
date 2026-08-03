import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/features/user/repository/task_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/task_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Task icon shown in the app bar of every main tab, opening [TaskScreen],
/// with a small badge showing how many tasks are pending.
class TaskIconButton extends StatefulWidget {
  final Map<String, dynamic>? loginData;
  final Color? iconColor;

  const TaskIconButton({super.key, this.loginData, this.iconColor});

  @override
  State<TaskIconButton> createState() => _TaskIconButtonState();
}

class _TaskIconButtonState extends State<TaskIconButton> {
  final TaskRepository _taskRepo = TaskRepository(TaskService());
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final workspaceId = prefs.getString('selected_workspace_id');
      if (workspaceId == null || workspaceId.isEmpty) return;

      final tasks = await _taskRepo.getWorkspaceTasks(
        workspaceId,
        status: 'pending',
      );
      if (mounted) setState(() => _pendingCount = tasks.length);
    } catch (_) {
      // Best-effort badge only — a failed count fetch shouldn't be noisy.
    }
  }

  Future<void> _openTasks() async {
    await Navigator.pushNamed(
      context,
      AppRoute.taskScreen,
      arguments: widget.loginData,
    );
    if (mounted) _loadPendingCount();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: AppStrings.tr('task_menu'),
          onPressed: _openTasks,
          icon: Icon(Icons.assessment_outlined, color: widget.iconColor),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: Text(
              _pendingCount > 9 ? '9+' : '$_pendingCount',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
