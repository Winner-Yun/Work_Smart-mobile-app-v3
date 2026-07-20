import 'package:flutter_worksmart_app/core/constants/default_profile_urls.dart';
import 'package:flutter_worksmart_app/shared/model/activity_models/leave_record.dart';

import 'achievements.dart';
import 'app_settings.dart';
import 'biometrics.dart';
import 'telegram_account.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String roleTitle;
  final String profileUrl;
  final String phone;
  final String email;
  final String officeId;
  final String departmentId;
  final String gender;
  final Biometrics biometrics;
  final List<LeaveRecord> leaveRecords;
  final TelegramAccount telegram;
  final Achievements achievements;
  final AppSettings appSettings;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.roleTitle,
    required this.profileUrl,
    required this.phone,
    required this.email,
    required this.officeId,
    required this.departmentId,
    required this.gender,
    required this.biometrics,
    required this.telegram,
    required this.leaveRecords,
    required this.achievements,
    required this.appSettings,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    String readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return fallback;
    }

    final gender = readString(['gender'], fallback: 'male');
    final resolvedProfileUrl = DefaultProfileUrls.resolve(
      gender: gender,
      providedUrl: readString(['profile_url', 'profileUrl']),
    );

    final dynamic appSettingsJson = json['app_settings'] ?? json['app_setting'];
    return UserProfile(
      uid: readString(['uid', 'user_id', 'userId']),
      displayName: readString(['display_name', 'displayName', 'name']),
      roleTitle: readString(['role_title', 'roleTitle']),
      profileUrl: resolvedProfileUrl,
      phone: readString(['phone', 'phone_number', 'phoneNumber']),
      email: readString(['email', 'email_address', 'emailAddress']),
      officeId: readString(['office_id', 'officeId']),
      departmentId: readString(['department_id', 'departmentId']),
      gender: gender,
      biometrics: Biometrics.fromJson(const <String, dynamic>{}),
      telegram: TelegramAccount.fromJson(json['telegram'] ?? {}),
      leaveRecords:
          (json['leave_records'] as List<dynamic>?)
              ?.map((e) => LeaveRecord.fromJson(e))
              .toList() ??
          [],
      achievements: Achievements.fromJson(json['achievements'] ?? {}),
      appSettings: AppSettings.fromJson(
        appSettingsJson is Map<String, dynamic>
            ? appSettingsJson
            : <String, dynamic>{},
      ),
    );
  }
}
