import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';

class LeaveService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> createLeave(
    String workspaceId, {
    required String leaveType,
    required String reason,
    required String startDate,
    required String endDate,
    File? attachment,
  }) async {
    final String endpoint = ApiEndpoints.createLeave(workspaceId);
    final FormData formData = FormData.fromMap({
      'leave_type': leaveType,
      'reason': reason,
      'start_date': startDate,
      'end_date': endDate,
      if (attachment != null)
        'attachment': await MultipartFile.fromFile(
          attachment.path,
          filename: attachment.path.split('/').last,
        ),
    });

    return _submit(
      endpoint,
      formData,
      isPost: true,
      label: 'createLeave',
    );
  }

  Future<Map<String, dynamic>> updateLeave(
    String leaveId, {
    String? leaveType,
    String? reason,
    String? startDate,
    String? endDate,
    File? attachment,
  }) async {
    final String endpoint = ApiEndpoints.leaveById(leaveId);
    final FormData formData = FormData.fromMap({
      if (leaveType != null) 'leave_type': leaveType,
      if (reason != null) 'reason': reason,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (attachment != null)
        'attachment': await MultipartFile.fromFile(
          attachment.path,
          filename: attachment.path.split('/').last,
        ),
    });

    return _submit(
      endpoint,
      formData,
      isPost: false,
      label: 'updateLeave',
    );
  }

  /// Lists the current user's leave requests for [workspaceId].
  ///
  /// The backend doesn't document a dedicated "list" route yet, so this
  /// reuses the create collection path (`GET` on the same URL as the `POST`
  /// in [createLeave]) following the same REST convention as the rest of
  /// this API. Update this if the real list endpoint differs once the
  /// backend-side bug mentioned for it is fixed.
  Future<dynamic> fetchMyLeaves(
    String workspaceId, {
    int? page,
    int? limit,
    String? status,
  }) async {
    final String endpoint = ApiEndpoints.createLeave(workspaceId);
    final Map<String, dynamic> queryParams = {
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
      if (status != null) 'status': status,
    };
    debugPrint('[LeaveService] GET $endpoint');
    debugPrint('[LeaveService] Query Params: $queryParams');

    try {
      final Response response = await _apiClient.get(
        endpoint,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      debugPrint('[LeaveService] Status Code: ${response.statusCode}');
      debugPrint('[LeaveService] Response Data: ${response.data}');

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
          'Failed to fetch leaves. Status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final serverMessage = e.response?.data?['message'] ?? e.message;
      debugPrint(
        '[LeaveService] DioError: $statusCode - $serverMessage | Endpoint: $endpoint',
      );
      throw Exception('Network error [$statusCode]: $serverMessage');
    } catch (e, stackTrace) {
      debugPrint('[LeaveService] Unexpected Error: $e');
      debugPrint('[LeaveService] StackTrace: $stackTrace');
      throw Exception('Unexpected error: $e');
    }
  }

  Future<void> deleteLeave(String leaveId) async {
    final String endpoint = ApiEndpoints.leaveById(leaveId);
    debugPrint('[LeaveService] DELETE $endpoint');

    try {
      final Response response = await _apiClient.delete(endpoint);
      debugPrint('[LeaveService] Status Code: ${response.statusCode}');

      if (response.statusCode != 200 &&
          response.statusCode != 201 &&
          response.statusCode != 204) {
        throw Exception(
          'Failed to delete leave. Status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final serverMessage = e.response?.data?['message'] ?? e.message;
      debugPrint(
        '[LeaveService] DioError: $statusCode - $serverMessage | Endpoint: $endpoint',
      );
      throw Exception('Network error [$statusCode]: $serverMessage');
    } catch (e, stackTrace) {
      debugPrint('[LeaveService] Unexpected Error: $e');
      debugPrint('[LeaveService] StackTrace: $stackTrace');
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Map<String, dynamic>> _submit(
    String endpoint,
    FormData formData, {
    required bool isPost,
    required String label,
  }) async {
    debugPrint('[LeaveService] ${isPost ? 'POST' : 'PATCH'} $endpoint');

    try {
      final Response response = isPost
          ? await _apiClient.post(endpoint, data: formData)
          : await _apiClient.patch(endpoint, data: formData);

      debugPrint('[LeaveService] Status Code: ${response.statusCode}');
      debugPrint('[LeaveService] Response Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data.containsKey('data') && data['data'] is Map
              ? Map<String, dynamic>.from(data['data'] as Map)
              : data;
        }
        throw Exception('Invalid response format');
      } else {
        throw Exception('Failed to $label. Status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final serverMessage = e.response?.data?['message'] ?? e.message;
      debugPrint(
        '[LeaveService] DioError: $statusCode - $serverMessage | Endpoint: $endpoint',
      );
      throw Exception('Network error [$statusCode]: $serverMessage');
    } catch (e, stackTrace) {
      debugPrint('[LeaveService] Unexpected Error: $e');
      debugPrint('[LeaveService] StackTrace: $stackTrace');
      throw Exception('Unexpected error: $e');
    }
  }
}
