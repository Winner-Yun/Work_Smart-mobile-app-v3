import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/config/language_manager.dart';
import 'package:flutter_worksmart_app/config/theme_manager.dart';
import 'package:flutter_worksmart_app/core/util/database/realtime_data_controller.dart';
import 'package:flutter_worksmart_app/core/util/database/user_data.dart';
import 'package:flutter_worksmart_app/core/util/notification/local_notification_service.dart';
import 'package:flutter_worksmart_app/features/user/presentation/profile&setting_screens/setting_screen.dart';
import 'package:flutter_worksmart_app/shared/model/user_model/user_profile.dart';

abstract class SettingLogic extends State<SettingsScreen> {
  static final RealtimeDataController _dataController =
      RealtimeDataController();

  dynamic _resolveAppSettings(Map<String, dynamic>? record) {
    return record?['app_settings'] ?? record?['app_setting'];
  }

  bool _resolveNotificationEnabled(
    dynamic appSettings, {
    bool fallback = true,
  }) {
    if (appSettings is! Map) {
      return fallback;
    }

    return _readBoolValue(
      appSettings['notifications_enabled'] ??
          appSettings['notification_enable'] ??
          appSettings['notification_enabled'],
      fallback: fallback,
    );
  }

  bool _readBoolValue(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }

    final String normalized = (value ?? '').toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return fallback;
  }

  // --- State Variables ---
  late UserProfile currentUser;
  late String? loggedInUserId;
  bool isNotification = true;
  bool isSavingNotification = false;
  bool _shouldRefreshOnPop = false;
  StreamSubscription<Map<String, dynamic>?>? _userRecordSubscription;

  @override
  void initState() {
    super.initState();
    loggedInUserId = widget.loginData?['uid'];
    loadData();
    _listenUserRecordRealtime();
  }

  @override
  void dispose() {
    _userRecordSubscription?.cancel();
    _userRecordSubscription = null;
    super.dispose();
  }

  void _listenUserRecordRealtime() {
    final String userId = (loggedInUserId ?? '').trim();
    if (userId.isEmpty) {
      return;
    }

    _userRecordSubscription?.cancel();
    _userRecordSubscription = _dataController.watchUserRecord(userId).listen((
      record,
    ) {
      if (!mounted || record == null) {
        return;
      }

      final dynamic appSettings = _resolveAppSettings(record);
      final bool resolvedNotification = _resolveNotificationEnabled(
        appSettings,
        fallback: true,
      );

      final int userIndex = usersFinalData.indexWhere(
        (user) => user['uid']?.toString().trim() == userId,
      );
      if (userIndex != -1) {
        if (appSettings is Map) {
          usersFinalData[userIndex]['app_settings'] = Map<String, dynamic>.from(
            appSettings,
          );
        }
      }

      setState(() {
        isNotification = resolvedNotification;
      });
    });
  }

  void loadData() {
    final String userId = (widget.loginData?['uid'] ?? '').toString().trim();

    final Map<String, dynamic> currentUserData = userId.isEmpty
        ? defaultUserRecord
        : usersFinalData.firstWhere(
            (user) => user['uid']?.toString().trim() == userId,
            orElse: () => defaultUserRecord,
          );

    currentUser = UserProfile.fromJson(currentUserData);

    final dynamic appSettings = userId.isNotEmpty
        ? () {
            final int idx = usersFinalData.indexWhere(
              (u) => u['uid']?.toString().trim() == userId,
            );
            return idx != -1 ? _resolveAppSettings(usersFinalData[idx]) : null;
          }()
        : null;

    isNotification = _resolveNotificationEnabled(appSettings, fallback: true);
  }

  Future<void> handleLanguageChange(
    BuildContext context,
    String langCode,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(25),
          ),
          child: const CircularProgressIndicator(),
        ),
      ),
    );

    // Change language
    await LanguageManager().changeLanguage(langCode);
    _shouldRefreshOnPop = true;

    if (!context.mounted) return;

    // Close dialog FIRST (using root navigator)
    Navigator.of(context, rootNavigator: true).pop();
  }

  bool get shouldRefreshOnPop => _shouldRefreshOnPop;

  Future<void> handleNotificationChange(bool value) async {
    if (isSavingNotification) return;

    final String userId = (loggedInUserId ?? '').trim();
    if (userId.isEmpty) return;

    final bool previousValue = isNotification;
    setState(() {
      isNotification = value;
      isSavingNotification = true;
    });

    if (value) {
      await LocalNotificationService.instance.requestPermissions();
    } else {
      await LocalNotificationService.instance.cancelAll();
    }

    final int userIndex = usersFinalData.indexWhere(
      (user) => user['uid']?.toString().trim() == userId,
    );

    final Map<String, dynamic> appSettings =
        userIndex != -1 && usersFinalData[userIndex]['app_settings'] is Map
        ? Map<String, dynamic>.from(
            usersFinalData[userIndex]['app_settings'] as Map,
          )
        : <String, dynamic>{};

    appSettings['notifications_enabled'] = value;

    try {
      await _dataController.updateUserRecord(userId, {
        'app_settings': appSettings,
      });

      final Map<String, dynamic>? savedRecord = await _dataController
          .fetchUserRecordById(userId);
      final dynamic savedAppSettings = savedRecord?['app_settings'];
      final bool savedNotificationValue = _readBoolValue(
        savedAppSettings is Map
            ? savedAppSettings['notifications_enabled']
            : null,
        fallback: value,
      );

      if (userIndex != -1) {
        usersFinalData[userIndex]['app_settings'] = savedAppSettings is Map
            ? Map<String, dynamic>.from(savedAppSettings)
            : appSettings;
      }

      if (mounted) {
        setState(() {
          isNotification = savedNotificationValue;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isNotification = previousValue;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update notification setting.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSavingNotification = false;
        });
      }
    }
  }

  bool get isDarkMode => ThemeManager().isDarkMode;
}
