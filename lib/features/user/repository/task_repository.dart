import 'package:flutter_worksmart_app/features/user/service/task_service.dart';
import 'package:flutter_worksmart_app/shared/model/task_model.dart';

class TaskRepository {
  final TaskService _service;

  TaskRepository(this._service);

  /// Tolerates a plain list or a paginated wrapper under `data`/`items`/`results`/`tasks`.
  Future<List<TaskModel>> getWorkspaceTasks(
    String workspaceId, {
    int page = 1,
    int limit = 50,
    String? status,
    String? priority,
  }) async {
    final dynamic raw = await _service.fetchWorkspaceTasks(
      workspaceId,
      page: page,
      limit: limit,
      status: status,
      priority: priority,
    );

    List<dynamic>? rawList;
    if (raw is List) {
      rawList = raw;
    } else if (raw is Map<String, dynamic>) {
      final dynamic nested =
          raw['data'] ?? raw['tasks'] ?? raw['items'] ?? raw['results'];
      if (nested is List) rawList = nested;
    }

    if (rawList == null) return <TaskModel>[];

    return rawList
        .whereType<Map>()
        .map((json) => TaskModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<TaskModel> updateTaskStatus(String taskId, String status) async {
    final json = await _service.updateTaskStatus(taskId, status);
    return TaskModel.fromJson(json);
  }
}
