import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';

class UserService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> fetchUserProfile() async {
    const String endpoint = ApiEndpoints.me;
    debugPrint('[UserService] Requesting: $endpoint');

    try {
      final Response response = await _apiClient.get(endpoint);

      if (response.statusCode == 200) {
        // Handle both {data: {...}} and direct {...} responses
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data.containsKey('data') && data['data'] is Map
              ? Map<String, dynamic>.from(data['data'] as Map)
              : data;
        }
        return Map<String, dynamic>.from(data as Map);
      } else {
        throw Exception(
          'Failed to load profile. Status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final serverMessage = e.response?.data?['message'] ?? e.message;
      debugPrint(
        '[UserService] DioError: $statusCode - $serverMessage | Endpoint: $endpoint',
      );
      throw Exception('Network error [$statusCode]: $serverMessage');
    } catch (e, stackTrace) {
      debugPrint('[UserService] Unexpected Error: $e');
      debugPrint('[UserService] StackTrace: $stackTrace');
      throw Exception('Unexpected error: $e');
    }
  }
}
