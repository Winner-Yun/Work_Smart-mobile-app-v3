import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';
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
