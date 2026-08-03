import 'package:flutter_worksmart_app/features/user/service/user_service.dart';
import 'package:flutter_worksmart_app/shared/model/user_model.dart';

class UserRepository {
  final UserService _userService;

  UserRepository(this._userService);

  Future<UserModel> getUserProfile() async {
    final data = await _userService.fetchUserProfile();
    return UserModel.fromJson(data);
  }

  Future<UserModel> updateProfile({String? name, String? gender}) async {
    final Map<String, dynamic> updates = {
      if (name != null) 'name': name,
      if (gender != null) 'gender': gender,
    };
    final data = await _userService.updateProfile(updates);
    return UserModel.fromJson(data);
  }

  Future<UserModel> updateAllowNotification(bool allow) async {
    final data = await _userService.updateAllowNotification(allow);
    return UserModel.fromJson(data);
  }

  Future<void> logout(String refreshToken) {
    return _userService.logout(refreshToken);
  }
}
