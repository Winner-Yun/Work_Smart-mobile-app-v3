import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_worksmart_app/app/routes/initial_route_resolver.dart';
import 'package:flutter_worksmart_app/config/env.dart';
import 'package:flutter_worksmart_app/config/language_manager.dart';
import 'package:flutter_worksmart_app/config/theme_manager.dart';

class AppBootstrap {
  static Future<String> init() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Init environment variables
    await dotenv.load(fileName: '.env');
    Env.googleMapsApiKey;

    FlutterError.onError = (details) =>
        FlutterError.dumpErrorToConsole(details);

    // Load preferences
    await ThemeManager().loadSettings();
    await LanguageManager().loadSettings();

    return await InitialRouteResolver.resolve();
  }
}
