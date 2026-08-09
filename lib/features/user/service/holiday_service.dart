import 'package:dio/dio.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';

class HolidayService {
  final ApiClient _apiClient = ApiClient();

  /// Reads `data['message']` only when [data] is a Map — some 5xx/proxy errors
  /// return a non-Map body, and indexing that directly throws a TypeError.
  String _extractServerMessage(dynamic data, String? fallback) {
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return fallback ?? 'Unknown error';
  }

  Future<Map<String, dynamic>> fetchHolidayConfig(String workspaceId) async {
    final String endpoint = ApiEndpoints.holidayConfig(workspaceId);

    try {
      final Response response = await _apiClient.get(endpoint);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data.containsKey('data') && data['data'] is Map
              ? Map<String, dynamic>.from(data['data'] as Map)
              : data;
        }
        throw Exception('Invalid response format');
      } else {
        throw Exception(
          'Failed to load holiday config. Status: ${response.statusCode}',
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

  Future<dynamic> fetchHolidays(
    String workspaceId, {
    int page = 1,
    int limit = 100,
  }) async {
    final String endpoint = ApiEndpoints.workspaceHolidays(workspaceId);

    try {
      final Response response = await _apiClient.get(
        endpoint,
        queryParameters: {'page': page, 'limit': limit},
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
          'Failed to load holidays. Status: ${response.statusCode}',
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
