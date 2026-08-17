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
    final info = await fetchWorkspaceMembersInfo(workspaceId);
    return info.total;
  }

  Future<WorkspaceMembersInfo> fetchWorkspaceMembersInfo(
    String workspaceId,
  ) async {
    final String endpoint = ApiEndpoints.workspaceMembers(workspaceId);

    try {
      final Response response = await _apiClient.get(endpoint);
      if (response.statusCode != 200) return WorkspaceMembersInfo();

      final dynamic data = response.data;
      if (data is! Map<String, dynamic>) return WorkspaceMembersInfo();

      int? total;
      final dynamic rawTotal = data['total'];
      if (rawTotal is int) {
        total = rawTotal;
      } else if (rawTotal is num) {
        total = rawTotal.toInt();
      }

      String? ownerName;
      final dynamic members = data['members'];
      if (members is List) {
        for (final member in members) {
          if (member is Map &&
              member['role']?.toString().toLowerCase() == 'owner') {
            final name = member['name']?.toString().trim();
            if (name != null && name.isNotEmpty) {
              ownerName = name;
              break;
            }
          }
        }
      }

      return WorkspaceMembersInfo(total: total, ownerName: ownerName);
    } catch (e) {
      return WorkspaceMembersInfo();
    }
  }
}

class WorkspaceMembersInfo {
  final int? total;
  final String? ownerName;

  WorkspaceMembersInfo({this.total, this.ownerName});
}
