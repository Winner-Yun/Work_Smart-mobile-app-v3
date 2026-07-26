import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Best-effort, human-readable description of the current device, used to
/// populate the local face-update audit log. Never throws — falls back to a
/// generic label if the platform plugin is unavailable (e.g. web).
class DeviceInfoHelper {
  DeviceInfoHelper._();

  static Future<String> describeCurrentDevice() async {
    if (kIsWeb) return 'web_browser';

    try {
      final DeviceInfoPlugin plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return 'Android ${info.version.release} • ${info.manufacturer} ${info.model}';
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return 'iOS ${info.systemVersion} • ${info.utsname.machine}';
      }
      return Platform.operatingSystem;
    } catch (_) {
      return 'unknown_device';
    }
  }
}
