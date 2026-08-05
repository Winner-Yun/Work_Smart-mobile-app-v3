import 'package:flutter_worksmart_app/config/env.dart';

class ApiConfig {
  ApiConfig._();

  // Avoids a double slash if API_BASE_URL already ends with '/'.
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
