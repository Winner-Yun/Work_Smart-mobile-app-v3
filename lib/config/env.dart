import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  // Public backend URL, not a secret — hardcoded as a last-resort fallback
  // so the app can still reach the API even with no `.env` file and no
  // `--dart-define=API_BASE_URL=...` override (see ApiConfig.baseUrl).
  static const String _defaultApiBaseUrl =
      'https://worksmart-production.up.railway.app/';

  static String get apiBaseUrl {
    final String? fromEnv = dotenv.env['API_BASE_URL'];
    return (fromEnv == null || fromEnv.trim().isEmpty)
        ? _defaultApiBaseUrl
        : fromEnv;
  }
  static String get authApiKey => dotenv.env['AUTH_API_KEY'] ?? '';
  static String get passwordPepper => dotenv.env['PASSWORD_PEPPER'] ?? '';
  static String get cloudinaryApiKey => dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  static String get cloudinaryApiSecret =>
      dotenv.env['CLOUDINARY_API_SECRET'] ?? '';
  static String get cloudinaryCloudName =>
      dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'dwrf0xt1x';
  static String get defaultUserPassword =>
      dotenv.env['DEFAULT_USER_PASSWORD'] ?? 'worksmart123';
}
