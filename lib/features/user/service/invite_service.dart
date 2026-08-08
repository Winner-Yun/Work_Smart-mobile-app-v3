import 'package:dio/dio.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';
import 'package:flutter_worksmart_app/shared/model/invite_action_response.dart';
import 'package:flutter_worksmart_app/shared/model/invite_model.dart';

class InviteService {
  final ApiClient _apiClient = ApiClient();

  Future<InviteResponse> fetchMyInvites({int page = 1, int limit = 10}) async {
    final String endpoint = '${ApiEndpoints.myInvites}?page=$page&limit=$limit';

    try {
      final Response response = await _apiClient.get(endpoint);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return InviteResponse.fromJson(data);
        }
        throw Exception('Invalid response format');
      } else {
        throw Exception(
          'Failed to load invites. Status: ${response.statusCode}',
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

  Future<InviteActionResponse> acceptInvite(String inviteId) async {
    final String endpoint = ApiEndpoints.acceptInvite(inviteId);

    try {
      final Response response = await _apiClient.post(endpoint, data: {});

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return InviteActionResponse.fromJson(data);
        }
        throw Exception('Invalid response format');
      } else {
        throw Exception(
          'Failed to accept invite. Status: ${response.statusCode}',
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

  /// Joins a workspace via a shareable invite code, as opposed to [acceptInvite].
  Future<Map<String, dynamic>> joinByCode(String code) async {
    final String endpoint = ApiEndpoints.joinInviteByCode(code);

    try {
      final Response response = await _apiClient.post(endpoint, data: {});

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) return data;
        return <String, dynamic>{};
      } else {
        throw Exception('Failed to join workspace');
      }
    } on DioException catch (e) {
      final dynamic responseData = e.response?.data;
      // This endpoint uses FastAPI-style {"detail": "..."} errors, not {"message": "..."}.
      final String? serverMessage = responseData is Map
          ? (responseData['detail'] ?? responseData['message'])
                ?.toString()
                .trim()
          : null;
      // Surface the backend's own message instead of a generic wrapped network error.
      throw Exception(
        (serverMessage != null && serverMessage.isNotEmpty)
            ? serverMessage
            : 'Failed to join workspace',
      );
    } catch (e) {
      throw Exception('Failed to join workspace');
    }
  }

  Future<InviteActionResponse> rejectInvite(String inviteId) async {
    final String endpoint = ApiEndpoints.rejectInvite(inviteId);

    try {
      final Response response = await _apiClient.patch(endpoint, data: {});

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return InviteActionResponse.fromJson(data);
        }
        throw Exception('Invalid response format');
      } else {
        throw Exception(
          'Failed to reject invite. Status: ${response.statusCode}',
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
