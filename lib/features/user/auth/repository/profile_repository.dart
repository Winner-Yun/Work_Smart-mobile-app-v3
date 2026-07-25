import 'dart:io';

import 'package:flutter_worksmart_app/features/user/auth/service/profile_service.dart';

class ProfileRepository {
  final ProfileService _service;

  ProfileRepository(this._service);

  Future<Map<String, dynamic>> updateProfileImage(File imageFile) async {
    try {
      return await _service.updateProfileImage(imageFile);
    } catch (e) {
      rethrow;
    }
  }
}
