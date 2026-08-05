import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_worksmart_app/app/routes/initial_route_resolver.dart';
import 'package:flutter_worksmart_app/config/language_manager.dart';
import 'package:flutter_worksmart_app/config/theme_manager.dart';
import 'package:flutter_worksmart_app/core/util/notification/local_notification_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Runs in its own isolate for backgrounded/terminated pushes, so must stay top-level.
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

    // `.env` is optional at runtime — missing it just leaves dotenv.env empty
    // instead of crashing, since every `Env.*` getter has a safe fallback.
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

  // Logs the connected Firebase project so a config mismatch is obvious, not silent.
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

  // Android won't auto-display FCM notifications in the foreground, so show one ourselves.
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
