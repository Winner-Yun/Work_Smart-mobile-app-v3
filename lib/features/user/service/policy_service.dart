import 'package:dio/dio.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';

class PolicyService {
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

  Future<Map<String, dynamic>> fetchPolicy(String workspaceId) async {
    final String endpoint = ApiEndpoints.workspacePolicy(workspaceId);

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
      throw Exception('Network error [$statusCode]: $serverMessage');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }
}
