import 'package:dio/dio.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';

class TaskService {
  final ApiClient _apiClient = ApiClient();

  String _extractServerMessage(dynamic data, String? fallback) {
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return fallback ?? 'Unknown error';
  }

  Future<dynamic> fetchWorkspaceTasks(
    String workspaceId, {
    int page = 1,
    int limit = 50,
    String? status,
    String? priority,
  }) async {
    final String endpoint = ApiEndpoints.workspaceTasks(workspaceId);
    final Map<String, dynamic> queryParams = {
      'page': page,
      'limit': limit,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
    };

    try {
      final Response response = await _apiClient.get(
        endpoint,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> &&
            data.containsKey('data') &&
            (data['data'] is Map || data['data'] is List)) {
          return data['data'];
        }
        return data;
      } else {
        throw Exception(
          'Failed to fetch tasks. Status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final serverMessage = _extractServerMessage(e.response?.data, e.message);
      throw Exception('Network error [$statusCode]: $serverMessage');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Map<String, dynamic>> updateTaskStatus(
    String taskId,
    String status,
  ) async {
    final String endpoint = ApiEndpoints.taskStatus(taskId);

    try {
      final Response response = await _apiClient.patch(
        endpoint,
        data: {'status': status},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) return data;
        throw Exception('Invalid response format');
      } else {
        throw Exception(
          'Failed to update task status. Status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final serverMessage = _extractServerMessage(e.response?.data, e.message);
      throw Exception('Network error [$statusCode]: $serverMessage');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }
}
