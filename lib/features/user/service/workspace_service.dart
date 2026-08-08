import 'package:dio/dio.dart';
import 'package:flutter_worksmart_app/config/api/api_client.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';

class WorkspaceService {
  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> fetchWorkspaces({
    bool onlyOwner = false,
    bool onlyMember = true,
  }) async {
    final String endpoint = ApiEndpoints.myWorkspaces; // '/workspace/me'

    // Set query parameters for Swagger API
    final Map<String, dynamic> queryParams = {
      'only_owner': onlyOwner,
      'only_member': onlyMember,
    };


    try {
      final Response response = await _apiClient.get(
        endpoint,
        queryParameters: queryParams,
      );


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        return data['workspaces'] ?? [];
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } on DioException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<int?> fetchWorkspaceMemberCount(String workspaceId) async {
    final String endpoint = ApiEndpoints.workspaceMembers(workspaceId);

    try {
      final Response response = await _apiClient.get(endpoint);
      if (response.statusCode != 200) return null;

      final dynamic data = response.data;
      if (data is! Map<String, dynamic>) return null;

      final dynamic total = data['total'];
      if (total is int) return total;
      if (total is num) return total.toInt();
      return null;
    } catch (e) {
      return null;
    }
  }
}
