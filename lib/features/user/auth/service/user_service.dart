import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';

class UserService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> fetchUserProfile() async {
    const String endpoint =
        '/auth/me'; // Update with your ApiEndpoints.authMe if you have one
    debugPrint(' [UserService] Requesting: $endpoint');

    try {
      final Response response = await _apiClient.get(endpoint);

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(
          'Failed to load profile. Status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      debugPrint(' [UserService] Network Error: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      debugPrint(' [UserService] Unexpected Error: $e');
      throw Exception('Unexpected error: $e');
    }
  }
}
