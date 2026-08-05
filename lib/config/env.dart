import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static const String _defaultApiBaseUrl =
      'https://worksmart-production.up.railway.app/';

  static String get apiBaseUrl {
    final String? fromEnv = dotenv.env['API_BASE_URL'];
    return (fromEnv == null || fromEnv.trim().isEmpty)
        ? _defaultApiBaseUrl
        : fromEnv;
  }

}
