import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';
import 'package:flutter_worksmart_app/shared/model/invite_action_response.dart';
import 'package:flutter_worksmart_app/shared/model/invite_model.dart';

class InviteService {
  final ApiClient _apiClient = ApiClient();

  Future<InviteResponse> fetchMyInvites({int page = 1, int limit = 10}) async {
    final String endpoint = '${ApiEndpoints.myInvites}?page=$page&limit=$limit';
    debugPrint('[InviteService] Requesting: $endpoint');

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
      debugPrint(
        '[InviteService] DioError: $statusCode - $serverMessage | Endpoint: $endpoint',
      );
      throw Exception('Network error [$statusCode]: $serverMessage');
    } catch (e, stackTrace) {
      debugPrint('[InviteService] Unexpected Error: $e');
      debugPrint('[InviteService] StackTrace: $stackTrace');
      throw Exception('Unexpected error: $e');
    }
  }

  Future<InviteActionResponse> acceptInvite(String inviteId) async {
    final String endpoint = ApiEndpoints.acceptInvite(inviteId);
    debugPrint('[InviteService] POST: $endpoint');

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
      debugPrint(
        '[InviteService] DioError: $statusCode - $serverMessage | Endpoint: $endpoint',
      );
      throw Exception('Network error [$statusCode]: $serverMessage');
    } catch (e, stackTrace) {
      debugPrint('[InviteService] Unexpected Error: $e');
      debugPrint('[InviteService] StackTrace: $stackTrace');
      throw Exception('Unexpected error: $e');
    }
  }

  Future<InviteActionResponse> rejectInvite(String inviteId) async {
    final String endpoint = ApiEndpoints.rejectInvite(inviteId);
    debugPrint('[InviteService] PATCH: $endpoint');

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
      debugPrint(
        '[InviteService] DioError: $statusCode - $serverMessage | Endpoint: $endpoint',
      );
      throw Exception('Network error [$statusCode]: $serverMessage');
    } catch (e, stackTrace) {
      debugPrint('[InviteService] Unexpected Error: $e');
      debugPrint('[InviteService] StackTrace: $stackTrace');
      throw Exception('Unexpected error: $e');
    }
  }
}
