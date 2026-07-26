import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';

class InitialRouteResolver {
  static Future<String> resolve() async {
    final dbHelper = DatabaseHelper();
    final cachedLogin = await dbHelper.getCachedLogin();

    final tutorialSeen = await dbHelper.getConfig('tutorial_seen') == 'true';

    if (!tutorialSeen) {
      return AppRoute.tutorial;
    }

    if (cachedLogin == null) {
      return AppRoute.authScreen;
    }

    return _resolveAuthenticatedRoute(cachedLogin);
  }

  static String _resolveAuthenticatedRoute(Map<String, dynamic> cachedLogin) {
    final userType = cachedLogin['user_type']?.toString().toLowerCase();
    if (userType == 'admin') {
      return AppRoute.authScreen;
    }
    return AppRoute.appmain;
  }
}
