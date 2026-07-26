import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_worksmart_app/config/env.dart';
import 'package:flutter_worksmart_app/config/language_manager.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/attendance_stats_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/leave_attendance_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/home_tab_wrapper.dart';
import 'package:flutter_worksmart_app/features/user/presentation/profile&setting_screens/profile_screens.dart';

class MainScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;
  final int initialIndex;

  const MainScreen({super.key, this.loginData, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  bool _hasShownPasswordChangeAlert = false;
  bool _isShowingPasswordChangeAlert = false;
  bool _cachedPasswordUsesDefault = false;
  bool _isHomeStartupFlowCompleted = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    LanguageManager().addListener(_handleLanguageChanged);
    _loadDefaultPasswordStateFromCache();
  }

  @override
  void dispose() {
    LanguageManager().removeListener(_handleLanguageChanged);
    super.dispose();
  }

  void _handleLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadDefaultPasswordStateFromCache() async {
    final cachedLogin = await DatabaseHelper().getCachedLogin();
    final cachedPassword = (cachedLogin?['password'] ?? '').toString().trim();
    final defaultPassword = Env.defaultUserPassword.trim();

    _cachedPasswordUsesDefault =
        cachedPassword.isNotEmpty &&
        defaultPassword.isNotEmpty &&
        cachedPassword == defaultPassword;

    _maybePromptPasswordChange();
  }

  void _maybePromptPasswordChange() {
    if (!_isHomeStartupFlowCompleted ||
        _hasShownPasswordChangeAlert ||
        _isShowingPasswordChangeAlert ||
        !_cachedPasswordUsesDefault) {
      return;
    }

    _hasShownPasswordChangeAlert = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPasswordChangeAlert();
    });
  }

  Future<void> _showPasswordChangeAlert() async {
    if (!mounted || _isShowingPasswordChangeAlert) {
      return;
    }

    _isShowingPasswordChangeAlert = true;
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
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
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
    );
    _isShowingPasswordChangeAlert = false;
  }

  // ──────────────── EMPLOYEE APP NAVIGATION ────────────────
  // Renders main tabs: Home, Attendance, Leave Requests, Profile
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> screens = [
      HomeTabWrapper(
        loginData: widget.loginData,
        onStartupFlowCompleted: () {
          if (_isHomeStartupFlowCompleted) return;
          _isHomeStartupFlowCompleted = true;
          _maybePromptPasswordChange();
        },
        onProfileTap: () {
          setState(() {
            _currentIndex = 3;
          });
        },
      ),
      AttendanceStatsScreen(loginData: widget.loginData),
      LeaveAttendanceScreen(loginData: widget.loginData),
      ProfileScreen(loginData: widget.loginData),
    ];

    Widget scaffoldBody = Scaffold(
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
}
