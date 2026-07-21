import 'package:flutter_worksmart_app/config/env.dart';

class ApiConfig {
  ApiConfig._();

  static final String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: Env.apiBaseUrl,
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);
}
