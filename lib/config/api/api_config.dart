import 'package:flutter_worksmart_app/config/env.dart';

class ApiConfig {
  ApiConfig._();

  // Every endpoint path (ApiEndpoints.*) starts with '/', and baseUrl is
  // joined with them via plain string concatenation (both in ApiClient's
  // BaseOptions + Dio's own baseUrl/path join, and in the raw token-refresh
  // request). If API_BASE_URL also ends with '/' (easy to do in .env),
  // every request ends up with a double slash, e.g. '..."up.railway.app//auth/me'.
  // Stripping it here fixes it regardless of how the env var is set.
  static final String baseUrl = _stripTrailingSlash(
    String.fromEnvironment('API_BASE_URL', defaultValue: Env.apiBaseUrl),
  );

  static String _stripTrailingSlash(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);
}
