import 'package:dio/dio.dart';
import 'package:flutter_worksmart_app/config/api/api_config.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,

        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: ApiConfig.sendTimeout,
        headers: const {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Fetch the current access token
          final cachedLogin = await _databaseHelper.getCachedLogin();
          final String? accessToken = cachedLogin?['access_token']?.toString();

          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.path != ApiEndpoints.refreshToken) {
            final success = await _refreshToken();

            if (success) {
              final cachedLogin = await _databaseHelper.getCachedLogin();
              final String? newAccessToken = cachedLogin?['access_token']
                  ?.toString();

              if (newAccessToken != null) {
                error.requestOptions.headers['Authorization'] =
                    'Bearer $newAccessToken';
                try {
                  final retryResponse = await _dio.fetch(error.requestOptions);
                  return handler.resolve(retryResponse);
                } catch (retryError) {
                  return handler.next(retryError as DioException);
                }
              }
            } else {
              await _databaseHelper.clearCachedLogin();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  late final Dio _dio;
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Dio get client => _dio;

  Future<bool> _refreshToken() async {
    try {
      final cachedLogin = await _databaseHelper.getCachedLogin();
      final String? refreshToken = cachedLogin?['refresh_token']?.toString();

      if (refreshToken == null || refreshToken.isEmpty) return false;

      final response = await Dio().post(
        '${ApiConfig.baseUrl}${ApiEndpoints.refreshToken}',
        data: {'refresh_token': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        final newAccessToken = body['access_token'];
        final newRefreshToken = body['refresh_token'] ?? refreshToken;

        // Update tokens in your local database
        await _databaseHelper.updateTokens(newAccessToken, newRefreshToken);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Response<dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get(endpoint, queryParameters: queryParameters);
  }

  Future<Response<dynamic>> patch(
    String endpoint, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.patch(endpoint, data: data, queryParameters: queryParameters);
  }

  Future<Response<dynamic>> post(String endpoint, {Object? data}) {
    return _dio.post(endpoint, data: data);
  }

  Future<Response<dynamic>> put(String endpoint, {Object? data}) {
    return _dio.put(endpoint, data: data);
  }

  Future<Response<dynamic>> delete(String endpoint, {Object? data}) {
    return _dio.delete(endpoint, data: data);
  }
}
