import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_worksmart_app/app/routes/initial_route_resolver.dart';
import 'package:flutter_worksmart_app/config/language_manager.dart';
import 'package:flutter_worksmart_app/config/theme_manager.dart';
import 'package:flutter_worksmart_app/core/util/notification/local_notification_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Runs in a separate background isolate when a push arrives while the app is
// backgrounded/terminated, so it needs its own Firebase init. Must stay a
// top-level (or static) function — instance methods can't be used here.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class AppBootstrap {
  static Future<String> init() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    _listenForForegroundMessages();
    await _printFirebaseConnectionInfo();

    // Init environment variables. `.env` is optional at runtime — if it's
    // missing (e.g. stripped from a production build), `dotenv.env` just
    // stays empty instead of throwing and taking the whole app down before
    // a single frame renders. Every `Env.*` getter already falls back to a
    // safe default for this case.
    try {
      await dotenv.load(fileName: '.env', isOptional: true);
    } catch (e) {
      debugPrint('[AppBootstrap] Failed to load .env: $e');
    }

    FlutterError.onError = (details) =>
        FlutterError.dumpErrorToConsole(details);

    // Load preferences
    await ThemeManager().loadSettings();
    await LanguageManager().loadSettings();

    return await InitialRouteResolver.resolve();
  }

  // Prints which installed package and which Firebase project this build
  // actually wired up to, so a mismatch (wrong google-services.json, wrong
  // applicationId) is obvious in the console instead of failing silently.
  static Future<void> _printFirebaseConnectionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final options = Firebase.app().options;

    debugPrint('===== FIREBASE CONNECTION =====');
    debugPrint('Package name : ${packageInfo.packageName}');
    debugPrint('Project ID   : ${options.projectId}');
    debugPrint('App ID       : ${options.appId}');
    debugPrint('Sender ID    : ${options.messagingSenderId}');
    debugPrint('================================');
  }

  // While the app is in the foreground, Android does not auto-display FCM
  // notifications — it's left to the app to show one, so we surface it
  // through the same local-notification channel used elsewhere.
  static void _listenForForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      LocalNotificationService.instance.show(
        title: notification.title ?? '',
        body: notification.body ?? '',
      );
    });
  }
}
