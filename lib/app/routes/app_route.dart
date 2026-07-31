import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/features/user/auth/authscreen.dart';
import 'package:flutter_worksmart_app/features/user/auth/tutorail_screens/tutorial_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/annual_leave_request_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/attendance_calendar_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/attendance_detail_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/leave_all_requests_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/attendence_screens/sick_leave_request_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/assign_user_face_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/face_scan_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/invites_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/leave_management_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/request_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/task_screen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/mainscreen.dart';
import 'package:flutter_worksmart_app/features/user/presentation/profile&setting_screens/help_support_screen.dart';

/// AppRoute: Central routing configuration
///
class AppRoute {
  static const String tutorial = '/tutorial';
  static const String authScreen = '/auth';
  static const String appmain = '/appmain';
  static const String attendanceDetail = '/attendance-detail';
  static const String leaderboardScreen = '/leaderboardScreen';
  static const String achievementScreen = '/achievementScreen';
  static const String attendanCalendarScreen = '/callenderScreen';
  static const String forgotpassScreen = '/forgotpassScreen';
  static const String leaveDatailScreen = '/leaveDetailScreen';
  static const String faceScanScreen = '/faceScanScreen';
  static const String attendanceScreen = '/attendance-screen';
  static const String sickleaveScreen = '/sickleaveScreen';
  static const String annualleaveScreen = '/annualleaveScreen-screen';
  static const String leaveAllRequestsScreen = '/leaveAllRequestsScreen';
  static const String settingScreen = '/settingScreen';
  static const String helpSupportScreen = '/helpSupportScreen';
  static const String registerFace = '/registerFace';
  static const String invitesScreen = '/invitesScreen';
  static const String taskScreen = '/taskScreen';
  static const String requestScreen = '/requestScreen';

  // ──────────────── ROUTE DEFINITIONS ────────────────

  static Map<String, WidgetBuilder> routes = {
    // Auth Routes
    tutorial: (context) => const TutorialScreen(),
    authScreen: (context) => const Authscreen(),

    // Main App
    appmain: (context) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        final initialIndex = args['initialIndex'] as int? ?? 0;
        return MainScreen(loginData: args, initialIndex: initialIndex);
      }
      return const _CachedLoginGate();
    },

    // Attendance Routes
    attendanceDetail: _buildRoute(
      (args) => AttendanceDetailScreen(loginData: args),
    ),
    attendanCalendarScreen: _buildRoute(
      (args) => AttendanceCalendarScreen(loginData: args),
    ),
    leaveDatailScreen: _buildRoute(
      (args) => LeaveDetailScreen(loginData: args),
    ),

    // Leave Request Routes
    sickleaveScreen: _buildRoute(
      (args) => SickLeaveRequestScreen(loginData: args),
    ),
    annualleaveScreen: _buildRoute(
      (args) => AnnualLeaveRequestScreen(loginData: args),
    ),
    leaveAllRequestsScreen: _buildRoute(
      (args) => LeaveAllRequestsScreen(loginData: args),
    ),

    // Face Recognition Routes
    faceScanScreen: _buildRoute((args) => FaceScanScreen(loginData: args)),
    registerFace: _buildRoute(
      (args) => RegisterFaceScanScreen(loginData: args),
    ),

    // Settings Routes
    helpSupportScreen: (context) => const HelpSupportScreen(),

    // Invite Routes
    invitesScreen: _buildRoute((args) => InvitesScreen(loginData: args)),

    // Task & Request Routes
    taskScreen: _buildRoute((args) => TaskScreen(loginData: args)),
    requestScreen: _buildRoute((args) => RequestScreen(loginData: args)),
  };

  static WidgetBuilder _buildRoute(
    Widget Function(Map<String, dynamic>?) builder,
  ) {
    return (context) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      return builder(args);
    };
  }
}

class _CachedLoginGate extends StatelessWidget {
  const _CachedLoginGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: DatabaseHelper().getCachedLogin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final cachedLogin = snapshot.data;
        if (cachedLogin == null) {
          return const Authscreen();
        }

        final userType = cachedLogin['user_type']?.toString().toLowerCase();
        if (userType == 'admin') {
          return const Authscreen();
        }

        final loginData = {
          'uid': cachedLogin['user_id'],
          'username': cachedLogin['username'],
          'userType': userType ?? 'employee',
        };

        return MainScreen(loginData: loginData);
      },
    );
  }
}
