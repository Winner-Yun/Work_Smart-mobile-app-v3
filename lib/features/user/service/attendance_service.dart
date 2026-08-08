import 'package:dio/dio.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';

class AttendanceService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> checkIn(
    String workspaceId, {
    required double latitude,
    required double longitude,
    required bool faceVerified,
    required bool livenessVerified,
    required bool mockLocationDetected,
  }) {
    return _postScan(
      ApiEndpoints.attendanceCheckIn(workspaceId),
      label: 'checkIn',
      latitude: latitude,
      longitude: longitude,
      faceVerified: faceVerified,
      livenessVerified: livenessVerified,
      mockLocationDetected: mockLocationDetected,
    );
  }

  Future<Map<String, dynamic>> checkOut(
    String workspaceId, {
    required double latitude,
    required double longitude,
    required bool faceVerified,
    required bool livenessVerified,
    required bool mockLocationDetected,
  }) {
    return _postScan(
      ApiEndpoints.attendanceCheckOut(workspaceId),
      label: 'checkOut',
      latitude: latitude,
      longitude: longitude,
      faceVerified: faceVerified,
      livenessVerified: livenessVerified,
      mockLocationDetected: mockLocationDetected,
    );
  }

  Future<dynamic> fetchMyAttendance(
    String workspaceId, {
    int? page,
    int? limit,
    String? sortBy,
    String? sortOrder,
    String? status,
    String? dateFilter,
  }) async {
    final String endpoint = ApiEndpoints.attendanceMe(workspaceId);
    final Map<String, dynamic> queryParams = {
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
      if (sortBy != null) 'sort_by': sortBy,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (status != null) 'status': status,
      if (dateFilter != null) 'date_filter': dateFilter,
    };

    try {
      final Response response = await _apiClient.get(
        endpoint,
        queryParameters: queryParams.isEmpty ? null : queryParams,
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
          'Failed to fetch attendance. Status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final serverMessage = e.response?.data?['message'] ?? e.message;
      throw Exception('Network error [$statusCode]: $serverMessage');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Map<String, dynamic>> _postScan(
    String endpoint, {
    required String label,
    required double latitude,
    required double longitude,
    required bool faceVerified,
    required bool livenessVerified,
    required bool mockLocationDetected,
  }) async {
    final Map<String, dynamic> body = {
      'latitude': latitude,
      'longitude': longitude,
      'face_verified': faceVerified,
      'liveness_verified': livenessVerified,
      'mock_location_detected': mockLocationDetected,
    };


    try {
      final Response response = await _apiClient.post(endpoint, data: body);


      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data.containsKey('data') && data['data'] is Map
              ? Map<String, dynamic>.from(data['data'] as Map)
              : data;
        }
        throw Exception('Invalid response format');
      } else {
        throw Exception(
          'Failed to $label. Status: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final serverMessage = e.response?.data?['message'] ?? e.message;
      throw Exception('Network error [$statusCode]: $serverMessage');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }
}
