import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/config/env.dart';
import 'package:flutter_worksmart_app/config/language_manager.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/core/util/database/realtime_data_controller.dart';
import 'package:flutter_worksmart_app/core/util/database/user_data.dart';
import 'package:flutter_worksmart_app/features/user/auth/presentation/change_pas_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/activity_screens/activity_feed_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/attendance_stats_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/leave_attendance_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/homepagescreen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/profile&setting_screens/profile_screen_web_stub.dart'
    if (dart.library.io) 'package:flutter_worksmart_app/features/user/presentation/profile&setting_screens/profile_screens.dart';

class MainScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;
  final int initialIndex;

  const MainScreen({super.key, this.loginData, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  final RealtimeDataController _realtimeDataController =
      RealtimeDataController();
  StreamSubscription<Map<String, dynamic>?>? _userRecordSubscription;
  bool _isHandlingSuspendedAccount = false;
  bool _isTelegramConnected = false;
  bool _hasShownPasswordChangeAlert = false;
  bool _isShowingPasswordChangeAlert = false;
  bool _cachedPasswordUsesDefault = false;
  bool _isHomeStartupFlowCompleted = false;
  Map<String, dynamic>? _latestUserRecord;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    LanguageManager().addListener(_handleLanguageChanged);
    _syncTelegramStatusFromLocalCache();
    _loadDefaultPasswordStateFromCache();
    _listenForAccountStateChanges();
  }

  @override
  void dispose() {
    LanguageManager().removeListener(_handleLanguageChanged);
    _userRecordSubscription?.cancel();
    super.dispose();
  }

  void _handleLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _listenForAccountStateChanges() {
    final uid = (widget.loginData?['uid'] ?? '').toString().trim();
    if (uid.isEmpty) {
      return;
    }

    _userRecordSubscription?.cancel();
    _userRecordSubscription = _realtimeDataController
        .watchUserRecord(uid)
        .listen((userRecord) {
          if (userRecord == null) {
            _forceLogoutForDeletedAccount();
            return;
          }

          _latestUserRecord = userRecord;

          final isConnected = _extractTelegramConnection(userRecord);
          if (_isTelegramConnected != isConnected) {
            if (mounted) {
              setState(() => _isTelegramConnected = isConnected);
            } else {
              _isTelegramConnected = isConnected;
            }
          }

          final accountStatus = (userRecord['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (accountStatus == 'suspended') {
            _forceLogoutForSuspendedAccount();
            return;
          }

          _maybePromptPasswordChange(userRecord);
        });
  }

  void _syncTelegramStatusFromLocalCache() {
    final uid = (widget.loginData?['uid'] ?? '').toString().trim();
    if (uid.isEmpty) {
      _isTelegramConnected = false;
      return;
    }

    final int userIndex = usersFinalData.indexWhere(
      (user) => user['uid']?.toString().trim() == uid,
    );
    final userRecord = userIndex == -1 ? null : usersFinalData[userIndex];
    _isTelegramConnected = _extractTelegramConnection(userRecord);
  }

  bool _extractTelegramConnection(Map<String, dynamic>? userRecord) {
    final telegram = userRecord?['telegram'];
    if (telegram is! Map) {
      return false;
    }

    final dynamic value = telegram['is_connected'];
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  Future<void> _loadDefaultPasswordStateFromCache() async {
    final cachedLogin = await DatabaseHelper().getCachedLogin();
    final cachedPassword = (cachedLogin?['password'] ?? '').toString().trim();
    final defaultPassword = Env.defaultUserPassword.trim();

    _cachedPasswordUsesDefault =
        cachedPassword.isNotEmpty &&
        defaultPassword.isNotEmpty &&
        cachedPassword == defaultPassword;

    _maybePromptPasswordChange(_latestUserRecord);
  }

  bool _requiresPasswordChange(Map<String, dynamic>? userRecord) {
    if (userRecord == null) {
      return false;
    }

    final bool? requiresChange = _readNullableBool(
      userRecord['requires_password_change'],
    );
    if (requiresChange != null) {
      return requiresChange;
    }

    return _cachedPasswordUsesDefault;
  }

  bool? _readNullableBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return null;
  }

  void _maybePromptPasswordChange(Map<String, dynamic>? userRecord) {
    if (!_isHomeStartupFlowCompleted ||
        _isHandlingSuspendedAccount ||
        _hasShownPasswordChangeAlert ||
        _isShowingPasswordChangeAlert) {
      return;
    }

    if (!_requiresPasswordChange(userRecord)) {
      return;
    }

    _hasShownPasswordChangeAlert = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPasswordChangeAlert();
    });
  }

  Future<void> _showPasswordChangeAlert() async {
    if (!mounted ||
        _isShowingPasswordChangeAlert ||
        _isHandlingSuspendedAccount) {
      return;
    }

    _isShowingPasswordChangeAlert = true;
    final shouldOpenChangePassword =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(AppStrings.tr('default_password_alert_title')),
              content: Text(AppStrings.tr('default_password_alert_message')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    AppStrings.tr('later'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    AppStrings.tr('change_now'),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
    _isShowingPasswordChangeAlert = false;

    if (!mounted || !shouldOpenChangePassword || _isHandlingSuspendedAccount) {
      return;
    }

    final uid = (widget.loginData?['uid'] ?? '').toString().trim();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangePasswordScreen(
          isFromProfile: true,
          userId: uid.isEmpty ? null : uid,
        ),
      ),
    );

    if (!mounted || _isHandlingSuspendedAccount) {
      return;
    }
  }

  Future<void> _forceLogoutForSuspendedAccount() async {
    if (_isHandlingSuspendedAccount) {
      return;
    }

    _isHandlingSuspendedAccount = true;
    await _userRecordSubscription?.cancel();
    await DatabaseHelper().clearCachedLogin();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoute.authScreen,
      (route) => false,
      arguments: {'showSuspendedDialog': true},
    );
  }

  Future<void> _forceLogoutForDeletedAccount() async {
    if (_isHandlingSuspendedAccount) {
      return;
    }

    _isHandlingSuspendedAccount = true;
    await _userRecordSubscription?.cancel();
    await DatabaseHelper().clearCachedLogin();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoute.authScreen,
      (route) => false,
      arguments: {'showDeletedDialog': true},
    );
  }

  // ──────────────── EMPLOYEE APP NAVIGATION ────────────────
  // Renders main tabs: Home, Attendance, Leave Requests, Profile
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final isActivityTab = _currentIndex == 3;

    final List<Widget> screens = [
      HomePageScreen(
        loginData: widget.loginData,
        onStartupFlowCompleted: () {
          if (_isHomeStartupFlowCompleted) {
            return;
          }
          _isHomeStartupFlowCompleted = true;
          _maybePromptPasswordChange(_latestUserRecord);
        },
        onProfileTap: () {
          setState(() {
            _currentIndex = 4;
          });
        },
      ),
      AttendanceStatsScreen(loginData: widget.loginData),
      LeaveAttendanceScreen(loginData: widget.loginData),
      ActivityFeedScreen(loginData: widget.loginData),
      ProfileScreen(loginData: widget.loginData),
    ];

    Widget scaffoldBody = Scaffold(
      appBar: isActivityTab
          ? buildActivityAppBar(
              context,
              showTelegramConnectAction: !_isTelegramConnected,
              onTelegramConfigTap: () async {
                await Navigator.pushNamed(
                  context,
                  AppRoute.telegramConfig,
                  arguments: widget.loginData,
                );

                if (!mounted) return;
                setState(_syncTelegramStatusFromLocalCache);
              },
              onNotificationTap: () => Navigator.pushNamed(
                context,
                AppRoute.notificationScreen,
                arguments: widget.loginData,
              ),
              notificationBell: _buildNotificationBell(context),
            )
          : null,
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).cardTheme.color,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_filled),
              label: AppStrings.tr('home_menu'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.how_to_reg),
              label: AppStrings.tr('atd_menu'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.beach_access),
              label: AppStrings.tr('leave_menu'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.timeline_rounded),
              label: AppStrings.tr('activity_menu'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person),
              label: AppStrings.tr('profile_menu'),
            ),
          ],
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: scaffoldBody,
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    final String uid = (widget.loginData?['uid'] ?? '').toString().trim();
    if (uid.isEmpty) {
      return _buildNotificationBellContent(context, showDot: false);
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _realtimeDataController.watchUserNotifications(uid),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <Map<String, dynamic>>[];

        final bool hasUnreadNotifications = notifications.any((item) {
          final raw = item['isRead'] ?? item['is_read'];
          if (raw is bool) return raw == false;

          final normalized = (raw ?? '').toString().trim().toLowerCase();
          return normalized == 'false' ||
              normalized == '0' ||
              normalized == 'no';
        });

        return _buildNotificationBellContent(
          context,
          showDot: hasUnreadNotifications,
        );
      },
    );
  }

  Widget _buildNotificationBellContent(
    BuildContext context, {
    required bool showDot,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          Icon(
            Icons.notifications_none,
            color: Theme.of(context).iconTheme.color,
          ),
          if (showDot)
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
