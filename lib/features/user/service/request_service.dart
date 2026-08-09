import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';

class RequestService {
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

  Future<dynamic> fetchMyRequests(
    String workspaceId, {
    int page = 1,
    int limit = 50,
    String? status,
  }) async {
    final String endpoint = ApiEndpoints.myRequests(workspaceId);
    final Map<String, dynamic> queryParams = {
      'page': page,
      'limit': limit,
      if (status != null) 'status': status,
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
          'Failed to fetch requests. Status: ${response.statusCode}',
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

  Future<Map<String, dynamic>> createRequest(
    String workspaceId, {
    required String title,
    required String description,
    List<File> images = const [],
  }) async {
    final String endpoint = ApiEndpoints.workspaceRequests(workspaceId);
    final Map<String, dynamic> fields = {
      'title': title,
      'description': description,
    };
    for (int i = 0; i < images.length && i < 5; i++) {
      fields['image_${i + 1}'] = await MultipartFile.fromFile(
        images[i].path,
        filename: images[i].path.split('/').last,
      );
    }
    final FormData formData = FormData.fromMap(fields);


    try {
      final Response response = await _apiClient.post(endpoint, data: formData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) return data;
        throw Exception('Invalid response format');
      } else {
        throw Exception(
          'Failed to submit request. Status: ${response.statusCode}',
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

  Future<void> deleteRequest(String requestId) async {
    final String endpoint = ApiEndpoints.requestById(requestId);

    try {
      final Response response = await _apiClient.delete(endpoint);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Failed to delete request. Status: ${response.statusCode}',
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
