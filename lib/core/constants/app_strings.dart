import 'package:flutter_worksmart_app/config/language_manager.dart';
import 'strings/menu_strings.dart';
import 'strings/auth_strings.dart';
import 'strings/tutorial_strings.dart';
import 'strings/admin_tutorial_strings.dart';
import 'strings/home_map_strings.dart';
import 'strings/attendance_strings.dart';
import 'strings/leave_management_strings.dart';
import 'strings/annual_leave_request_strings.dart';
import 'strings/sick_leave_request_strings.dart';
import 'strings/notification_strings.dart';
import 'strings/leaderboard_strings.dart';
import 'strings/achievement_strings.dart';
import 'strings/calendar_strings.dart';
import 'strings/face_scan_strings.dart';
import 'strings/help_support_strings.dart';
import 'strings/profile_strings.dart';
import 'strings/settings_strings.dart';
import 'strings/telegram_strings.dart';
import 'strings/date_time_strings.dart';
import 'strings/manage_users_strings.dart';
import 'strings/admin_dashboard_strings.dart';
import 'strings/geofencing_strings.dart';

class AppStrings {
  static String get currentLang => LanguageManager().locale;

  static const Map<String, Map<String, String>> data = {
    'en': {
      ...menuStringsEn,
      ...authStringsEn,
      ...tutorialStringsEn,
      ...adminTutorialStringsEn,
      ...homeMapStringsEn,
      ...attendanceStringsEn,
      ...leaveManagementStringsEn,
      ...annualLeaveRequestStringsEn,
      ...sickLeaveRequestStringsEn,
      ...notificationStringsEn,
      ...leaderboardStringsEn,
      ...achievementStringsEn,
      ...calendarStringsEn,
      ...faceScanStringsEn,
      ...helpSupportStringsEn,
      ...profileStringsEn,
      ...settingsStringsEn,
      ...telegramStringsEn,
      ...dateTimeStringsEn,
      ...manageUsersStringsEn,
      ...adminDashboardStringsEn,
      ...geofencingStringsEn,
    },
    'km': {
      ...menuStringsKm,
      ...authStringsKm,
      ...tutorialStringsKm,
      ...adminTutorialStringsKm,
      ...homeMapStringsKm,
      ...attendanceStringsKm,
      ...leaveManagementStringsKm,
      ...annualLeaveRequestStringsKm,
      ...sickLeaveRequestStringsKm,
      ...notificationStringsKm,
      ...leaderboardStringsKm,
      ...achievementStringsKm,
      ...calendarStringsKm,
      ...faceScanStringsKm,
      ...helpSupportStringsKm,
      ...profileStringsKm,
      ...settingsStringsKm,
      ...telegramStringsKm,
      ...dateTimeStringsKm,
      ...manageUsersStringsKm,
      ...adminDashboardStringsKm,
      ...geofencingStringsKm,
    },
  };

  static String tr(String key) {
    return data[currentLang]?[key] ?? key;
  }
}
