/// API base configuration.
class ApiConfig {
  ApiConfig._();

  /// Reads from --dart-define or defaults to your Vercel backend.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://smart-atd-backend.vercel.app',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);
}
