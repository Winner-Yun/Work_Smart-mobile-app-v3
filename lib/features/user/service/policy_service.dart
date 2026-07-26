import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';

class PolicyService {
  final ApiClient _apiClient = ApiClient();

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
      final serverMessage = e.response?.data?['message'] ?? e.message;
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
