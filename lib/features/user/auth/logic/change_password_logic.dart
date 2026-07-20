import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/core/util/database/realtime_data_controller.dart';

class ChangePasswordResult {
  final bool isSuccess;
  final String? errorKey;

  const ChangePasswordResult._({required this.isSuccess, this.errorKey});

  factory ChangePasswordResult.success() {
    return const ChangePasswordResult._(isSuccess: true);
  }

  factory ChangePasswordResult.failure(String errorKey) {
    return ChangePasswordResult._(isSuccess: false, errorKey: errorKey);
  }
}

class ChangePasswordLogic {
  final RealtimeDataController _realtimeDataController;
  final DatabaseHelper _databaseHelper;

  ChangePasswordLogic({
    RealtimeDataController? realtimeDataController,
    DatabaseHelper? databaseHelper,
  }) : _realtimeDataController =
           realtimeDataController ?? RealtimeDataController(),
       _databaseHelper = databaseHelper ?? DatabaseHelper();

  Future<ChangePasswordResult> changePassword({
    required String newPassword,
    required bool isFromProfile,
    String? oldPassword,
    String? userId,
    String? resetEmail,
  }) async {
    final String normalizedNewPassword = newPassword.trim();
    if (normalizedNewPassword.isEmpty) {
      return ChangePasswordResult.failure('password_empty_error');
    }

    final String? targetUserId = await _resolveTargetUserId(
      userId: userId,
      resetEmail: resetEmail,
    );

    if (targetUserId == null || targetUserId.isEmpty) {
      return ChangePasswordResult.failure('password_target_user_not_found');
    }

    if (isFromProfile) {
      final String normalizedOldPassword = oldPassword?.trim() ?? '';
      if (normalizedOldPassword.isEmpty) {
        return ChangePasswordResult.failure('password_empty_error');
      }

      final user = await _realtimeDataController.authenticateUser(
        username: targetUserId,
        password: normalizedOldPassword,
      );

      if (user == null) {
        return ChangePasswordResult.failure('old_password_incorrect');
      }
    }

    try {
      await _realtimeDataController.updateUserRecord(targetUserId, {
        'password': normalizedNewPassword,
        'requires_password_change': false,
      });
      await _syncCachedPasswordIfSameUser(
        targetUserId: targetUserId,
        newPassword: normalizedNewPassword,
      );
      return ChangePasswordResult.success();
    } catch (_) {
      return ChangePasswordResult.failure('password_change_failed');
    }
  }

  Future<String?> _resolveTargetUserId({
    String? userId,
    String? resetEmail,
  }) async {
    final String directUserId = (userId ?? '').trim();
    if (directUserId.isNotEmpty) {
      return directUserId;
    }

    final String normalizedEmail = (resetEmail ?? '').trim().toLowerCase();
    if (normalizedEmail.isNotEmpty) {
      final users = await _realtimeDataController.fetchUserRecords();
      for (final user in users) {
        final String email = (user['email'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (email == normalizedEmail) {
          final String matchedUid = (user['uid'] ?? '').toString().trim();
          if (matchedUid.isNotEmpty) {
            return matchedUid;
          }
        }
      }
    }

    final cachedLogin = await _databaseHelper.getCachedLogin();
    final String cachedUserId = (cachedLogin?['user_id'] ?? '')
        .toString()
        .trim();
    if (cachedUserId.isNotEmpty) {
      return cachedUserId;
    }

    return null;
  }

  Future<void> _syncCachedPasswordIfSameUser({
    required String targetUserId,
    required String newPassword,
  }) async {
    final cachedLogin = await _databaseHelper.getCachedLogin();
    if (cachedLogin == null) {
      return;
    }

    final String cachedUserId = (cachedLogin['user_id'] ?? '')
        .toString()
        .trim();
    if (cachedUserId != targetUserId) {
      return;
    }

    final String username = (cachedLogin['username'] ?? '').toString();
    final String userType = (cachedLogin['user_type'] ?? 'employee').toString();
    final dynamic rawSessionExpiresAt = cachedLogin['session_expires_at'];
    final int? sessionExpiresMs = rawSessionExpiresAt is num
        ? rawSessionExpiresAt.toInt()
        : int.tryParse(rawSessionExpiresAt?.toString() ?? '');

    await _databaseHelper.saveCachedLogin(
      username,
      newPassword,
      cachedUserId,
      userType,
      sessionExpiresAt: sessionExpiresMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(sessionExpiresMs, isUtc: true),
    );
  }
}
