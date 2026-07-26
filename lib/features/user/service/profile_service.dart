import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';

class ProfileService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> updateProfileImage(File imageFile) async {
    final String endpoint = ApiEndpoints.updateProfileImage;
    debugPrint('[ProfileService] Requesting: $endpoint');

    try {
      // Create FormData with the image file matching key 'image'
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      });

      // Execute PATCH request using ApiClient (token is attached automatically)[cite: 1]
      final Response response = await _apiClient.patch(
        endpoint,
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data;
        }
        throw Exception('Invalid response format');
      } else {
        throw Exception(
          'Failed to update profile image. Status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final serverMessage = e.response?.data?['message'] ?? e.message;
      debugPrint(
        '[ProfileService] DioError: $statusCode - $serverMessage | Endpoint: $endpoint',
      );
      throw Exception('Network error [$statusCode]: $serverMessage');
    } catch (e, stackTrace) {
      debugPrint('[ProfileService] Unexpected Error: $e');
      debugPrint('[ProfileService] StackTrace: $stackTrace');
      throw Exception('Unexpected error: $e');
    }
  }
}
