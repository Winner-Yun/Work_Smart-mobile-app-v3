import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static const String _defaultApiBaseUrl = 'null';

  static String get apiBaseUrl {
    final String? fromEnv = dotenv.env['API_BASE_URL'];
    return (fromEnv == null || fromEnv.trim().isEmpty)
        ? _defaultApiBaseUrl
        : fromEnv;
  }

  /// Controls developer-mode / mock-location detection on the splash screen
  /// and homepage. When `true`, both screens run the checks and block usage
  /// if developer mode or a fake GPS is detected. When `false`, both screens
  /// skip the checks entirely.
  static bool get developerModeDetectionEnabled {
    final String? fromEnv = dotenv.env['DEVELOPER_MODE_DETECTION_ENABLED'];
    return (fromEnv?.trim().toLowerCase() ?? 'true') != 'false';
  }
}
