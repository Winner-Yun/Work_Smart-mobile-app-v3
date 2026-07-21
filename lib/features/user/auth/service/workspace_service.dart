import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

    debugPrint('--------------------------------------------------');
    debugPrint(' [WorkspaceService] GET $endpoint');
    debugPrint(' [WorkspaceService] Query Params: $queryParams');

    try {
      final Response response = await _apiClient.get(
        endpoint,
        queryParameters: queryParams,
      );

      debugPrint(' [WorkspaceService] Status Code: ${response.statusCode}');
      debugPrint(' [WorkspaceService] Response Data: ${response.data}');
      debugPrint('--------------------------------------------------');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        return data['workspaces'] ?? [];
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint(' [WorkspaceService] DioException Caught!');
      debugPrint('   • Request URI: ${e.requestOptions.uri}');
      debugPrint('   • Status Code: ${e.response?.statusCode}');
      debugPrint('   • Response Data: ${e.response?.data}');
      debugPrint('--------------------------------------------------');
      rethrow;
    } catch (e) {
      debugPrint('[WorkspaceService] Unexpected Error: $e');
      rethrow;
    }
  }
}
