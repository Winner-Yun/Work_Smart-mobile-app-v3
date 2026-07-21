import 'package:flutter_worksmart_app/features/user/auth/service/user_service.dart';
import 'package:flutter_worksmart_app/shared/model/user_model.dart';

class UserRepository {
  final UserService _userService;

  UserRepository(this._userService);

  Future<UserModel> getUserProfile() async {
    final data = await _userService.fetchUserProfile();
    return UserModel.fromJson(data);
  }
}
