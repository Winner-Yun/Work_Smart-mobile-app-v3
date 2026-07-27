import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';

class PolicyService {
  final ApiClient _apiClient = ApiClient();

  /// Backend error bodies are usually `{"message": "..."}`, but on some
  /// failures (5xx from a proxy, HTML error pages, etc.) the response body
  /// isn't a Map at all — indexing a String or List with `['message']`
  /// throws a TypeError that then masks the real error, so this only reads
  /// the key when [data] is actually a Map.
  String _extractServerMessage(dynamic data, String? fallback) {
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return fallback ?? 'Unknown error';
  }

  Future<Map<String, dynamic>> fetchPolicy(String workspaceId) async {
    final String endpoint = ApiEndpoints.workspacePolicy(workspaceId);
    debugPrint('[PolicyService] Requesting: $endpoint');

    try {
      final Response response = await _apiClient.get(endpoint);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data;
        }
        throw Exception('Invalid response format');
      } else {
        throw Exception(
          'Failed to load policy. Status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final serverMessage = _extractServerMessage(e.response?.data, e.message);
      debugPrint(
        '[PolicyService] DioError: $statusCode - $serverMessage | Endpoint: $endpoint',
      );
      throw Exception('Network error [$statusCode]: $serverMessage');
    } catch (e, stackTrace) {
      debugPrint('[PolicyService] Unexpected Error: $e');
      debugPrint('[PolicyService] StackTrace: $stackTrace');
      throw Exception('Unexpected error: $e');
    }
  }
}
