import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';

class FaceService {
  final ApiClient _apiClient = ApiClient();

  // Your existing registerFace method
  Future<Map<String, dynamic>> registerFace(List<num> embeddings) async {
    final String endpoint = ApiEndpoints.faceRegister;
    debugPrint('[FaceService] Requesting: $endpoint');

    try {
      final Response response = await _apiClient.post(
        endpoint,
        data: {"embeddings": embeddings},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) return data;
        throw Exception('Invalid response format');
      } else {
        throw Exception(
          'Failed to register face. Status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final serverMessage = e.response?.data?['message'] ?? e.message;
      debugPrint('[FaceService] DioError: $statusCode - $serverMessage');
      throw Exception('Network error [$statusCode]: $serverMessage');
    } catch (e) {
      debugPrint('[FaceService] Unexpected Error: $e');
      throw Exception('Unexpected error: $e');
    }
  }

  // NEW: Get Face Embeddings Method
  Future<Map<String, dynamic>> getMyFaceEmbeddings() async {
    final String endpoint = ApiEndpoints.faceMe;
    debugPrint('[FaceService] Requesting: $endpoint');

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
          'Failed to fetch face embeddings. Status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final serverMessage = e.response?.data?['message'] ?? e.message;
      debugPrint('[FaceService] DioError: $statusCode - $serverMessage');
      throw Exception('Network error [$statusCode]: $serverMessage');
    } catch (e) {
      debugPrint('[FaceService] Unexpected Error: $e');
      throw Exception('Unexpected error: $e');
    }
  }
}
