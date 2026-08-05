import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/features/user/repository/task_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/task_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide pending-task count, shared by every [TaskIconButton] instance so
/// an update from any screen is reflected on every badge.
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

  // Also warms TaskScreen's own cache (same key), so tapping the icon renders instantly.
  Future<void> refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final workspaceId = prefs.getString('selected_workspace_id');
      if (workspaceId == null || workspaceId.isEmpty) {
        pendingCount.value = 0;
        return;
      }

      final tasks = await _taskRepo.getWorkspaceTasks(workspaceId);
      pendingCount.value = tasks.where((t) => t.status == 'pending').length;

      final sorted = tasks.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await prefs.setString(
        'cached_tasks_$workspaceId',
        jsonEncode(sorted.map((t) => t.toJson()).toList()),
      );
    } catch (_) {
      // Best-effort badge only — a failed count fetch shouldn't be noisy.
    }
  }
}

/// Task icon shown in every main tab's app bar, with a pending-task count badge
/// kept live app-wide via [_TaskBadgeController].
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
    final Color ringColor =
        Theme.of(context).appBarTheme.backgroundColor ??
        Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: AppStrings.tr('task_menu'),
          onPressed: _openTasks,
          icon: Icon(Icons.assessment_outlined, color: widget.iconColor),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: ValueListenableBuilder<int>(
            valueListenable: _controller.pendingCount,
            builder: (context, pendingCount, _) {
              if (pendingCount <= 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: ringColor, width: 1.5),
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
