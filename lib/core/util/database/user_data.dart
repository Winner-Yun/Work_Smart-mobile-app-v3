import 'package:flutter_worksmart_app/shared/model/user_model/user_profile.dart';

final List<Map<String, dynamic>> usersFinalData = <Map<String, dynamic>>[];

List<UserProfile> get usersFinalProfiles =>
    usersFinalData.map(UserProfile.fromJson).toList();

Map<String, dynamic> get defaultUserRecord => usersFinalData.isNotEmpty
    ? Map<String, dynamic>.from(usersFinalData.first)
    : <String, dynamic>{};

void setUsersFinalData(List<Map<String, dynamic>> users) {
  usersFinalData
    ..clear()
    ..addAll(users.map((item) => Map<String, dynamic>.from(item)));
}
