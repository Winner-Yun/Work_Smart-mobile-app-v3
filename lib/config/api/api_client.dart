import 'package:dio/dio.dart';
import 'package:flutter_worksmart_app/config/api/api_config.dart';
import 'package:flutter_worksmart_app/config/api/api_endpoints.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';

class ApiClient {
  ApiClient._internal() {
    // No default content-type here — each request sets its own via `_optionsFor`,
    // otherwise multipart uploads can't override a base-level JSON header.
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: ApiConfig.sendTimeout,
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
          final bool isRefreshCall =
              error.requestOptions.path == ApiEndpoints.refreshToken;
          final bool alreadyRetried =
              error.requestOptions.extra['retriedAfterRefresh'] == true;

          if (error.response?.statusCode == 401 &&
              !isRefreshCall &&
              !alreadyRetried) {
            final success = await _refreshToken();

            if (success) {
              final cachedLogin = await _databaseHelper.getCachedLogin();
              final String? newAccessToken = cachedLogin?['access_token']
                  ?.toString();

              if (newAccessToken != null) {
                error.requestOptions.extra['retriedAfterRefresh'] = true;
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
              // Refresh token is dead — force logout and wipe all cached user data.
              await _databaseHelper.clearAllUserData();
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

  // Shares one refresh call across concurrent 401s so a rotating refresh
  // token isn't used twice and the session doesn't get wrongly cleared.
  Future<bool>? _refreshInFlight;

  Future<bool> _refreshToken() {
    return _refreshInFlight ??= _performTokenRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _performTokenRefresh() async {
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
    return _dio.patch(
      endpoint,
      data: data,
      queryParameters: queryParameters,
      options: _optionsFor(data),
    );
  }

  Future<Response<dynamic>> post(String endpoint, {Object? data}) {
    return _dio.post(endpoint, data: data, options: _optionsFor(data));
  }

  // FormData (multipart uploads) sets its own content-type; everything else gets JSON.
  Options? _optionsFor(Object? data) {
    if (data is FormData) return null;
    return Options(contentType: 'application/json');
  }

  Future<Response<dynamic>> put(String endpoint, {Object? data}) {
    return _dio.put(endpoint, data: data, options: _optionsFor(data));
  }

  Future<Response<dynamic>> delete(String endpoint, {Object? data}) {
    return _dio.delete(endpoint, data: data);
  }
}
