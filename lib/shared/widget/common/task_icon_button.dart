import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/features/user/repository/task_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/task_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide pending-task count, shared by every [TaskIconButton] instance.
///
/// Each screen creates its own `TaskIconButton`, so a plain per-widget count
/// only ever refreshed on that one instance's initState/return-from-task-page.
/// Routing the count through this singleton means an update triggered from
/// any screen (or the periodic poll below) is reflected on every badge,
/// regardless of which screen is currently visible.
class _TaskBadgeController {
  _TaskBadgeController._internal();
  static final _TaskBadgeController instance = _TaskBadgeController._internal();

  static const _pollInterval = Duration(seconds: 30);

  final TaskRepository _taskRepo = TaskRepository(TaskService());
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  Timer? _pollTimer;
  int _activeListeners = 0;

  void attach() {
    _activeListeners++;
    refresh();
    _pollTimer ??= Timer.periodic(_pollInterval, (_) => refresh());
  }

  void detach() {
    _activeListeners--;
    if (_activeListeners <= 0) {
      _activeListeners = 0;
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final workspaceId = prefs.getString('selected_workspace_id');
      if (workspaceId == null || workspaceId.isEmpty) {
        pendingCount.value = 0;
        return;
      }

      final tasks = await _taskRepo.getWorkspaceTasks(
        workspaceId,
        status: 'pending',
      );
      pendingCount.value = tasks.length;
    } catch (_) {
      // Best-effort badge only — a failed count fetch shouldn't be noisy.
    }
  }
}

/// Task icon shown in the app bar of every main tab, opening [TaskScreen],
/// with a small badge showing how many tasks are pending. The count is kept
/// live across the whole app (not just this button) via [_TaskBadgeController].
class TaskIconButton extends StatefulWidget {
  final Map<String, dynamic>? loginData;
  final Color? iconColor;

  const TaskIconButton({super.key, this.loginData, this.iconColor});

  @override
  State<TaskIconButton> createState() => _TaskIconButtonState();
}

class _TaskIconButtonState extends State<TaskIconButton> {
  final _TaskBadgeController _controller = _TaskBadgeController.instance;

  @override
  void initState() {
    super.initState();
    _controller.attach();
  }

  @override
  void dispose() {
    _controller.detach();
    super.dispose();
  }

  Future<void> _openTasks() async {
    await Navigator.pushNamed(
      context,
      AppRoute.taskScreen,
      arguments: widget.loginData,
    );
    _controller.refresh();
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
          child: ValueListenableBuilder<int>(
            valueListenable: _controller.pendingCount,
            builder: (context, pendingCount, _) {
              if (pendingCount <= 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  pendingCount > 9 ? '9+' : '$pendingCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
