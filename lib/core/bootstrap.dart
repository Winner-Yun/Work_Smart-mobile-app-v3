import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_worksmart_app/app/routes/initial_route_resolver.dart';
import 'package:flutter_worksmart_app/config/language_manager.dart';
import 'package:flutter_worksmart_app/config/theme_manager.dart';
import 'package:flutter_worksmart_app/core/util/notification/local_notification_service.dart';

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

    try {
      await dotenv.load(fileName: '.env', isOptional: true);
    } catch (_) {}

    FlutterError.onError = (details) =>
        FlutterError.dumpErrorToConsole(details);

    // Load preferences
    await ThemeManager().loadSettings();
    await LanguageManager().loadSettings();

    return await InitialRouteResolver.resolve();
  }

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
