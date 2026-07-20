import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/core/util/database/realtime_data_controller.dart';

class AuthLogic {
  final BuildContext context;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final GlobalKey<FormState> formKey;
  final RealtimeDataController _realtimeDataController;

  Map<String, dynamic>? _lastAuthenticatedUser;

  AuthLogic({
    required this.context,
    required this.usernameController,
    required this.passwordController,
    required this.formKey,
    RealtimeDataController? realtimeDataController,
  }) : _realtimeDataController =
           realtimeDataController ?? RealtimeDataController();

  Future<void> checkCachedLogin(
    Function(String, String, String) onAutoLogin,
  ) async {
    final dbHelper = DatabaseHelper();
    final cachedLogin = await dbHelper.getCachedLogin();

    if (cachedLogin != null) {
      final username = cachedLogin['username'] as String;
      final userType = cachedLogin['user_type'] as String;
      final userId = cachedLogin['user_id'] as String;

      final userRecord = await _realtimeDataController
          .watchUserRecord(userId)
          .first;
      if (userRecord == null) {
        await dbHelper.clearCachedLogin();
        _showDeletedAccountAlert();
        return;
      }

      // Verify account is not suspended before auto-login.
      final status = (userRecord['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (status == 'suspended') {
        await dbHelper.clearCachedLogin();
        _showSuspendedAlert();
        return;
      }

      onAutoLogin(username, userId, userType);
    }
  }

  Future<bool> handleLogin() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (formKey.currentState != null && formKey.currentState!.validate()) {
      final user = await _realtimeDataController.authenticateUser(
        username: username,
        password: password,
      );

      if (user == null) {
        _showErrorSnackBar(AppStrings.tr('invalid_credentials'));
        return false;
      }

      final accountStatus = (user['status'] ?? '').toString();
      if (accountStatus == 'suspended') {
        _showSuspendedAlert();
        return false;
      }

      _lastAuthenticatedUser = user;

      _showSuccessSnackBar(AppStrings.tr('logging_in_employee'));

      final dbHelper = DatabaseHelper();
      await dbHelper.saveCachedLogin(
        (user['display_name'] ?? username).toString(),
        password,
        user['uid'].toString(),
        'employee',
      );

      return true;
    }
    return false;
  }

  Map<String, dynamic> getLoginData() {
    final username = usernameController.text.trim();
    final user = _lastAuthenticatedUser;
    final String resolvedUserId = (user?['uid'] ?? username).toString().trim();

    return {
      'uid': resolvedUserId,
      'user_id': resolvedUserId,
      'userId': resolvedUserId,
      'username': (user?['display_name'] ?? username).toString(),
      'userType': 'employee',
    };
  }

  void navigateToMainApp(Map<String, dynamic> loginData) {
    Navigator.pushReplacementNamed(
      context,
      AppRoute.appmain,
      arguments: loginData,
    );
  }

  void clearForm() {
    usernameController.clear();
    passwordController.clear();
  }

  void showSuspendedAlert() {
    _showSuspendedAlert();
  }

  void showDeletedAccountAlert() {
    _showDeletedAccountAlert();
  }

  void _showSuspendedAlert() {
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;
        final isDark = theme.brightness == Brightness.dark;
        final dialogSurface = colorScheme.surface;

        final mutedTextColor = colorScheme.onSurface.withValues(alpha: 0.68);
        final subtleBorderColor = colorScheme.outline.withValues(
          alpha: isDark ? 0.45 : 0.18,
        );
        final closeButtonBackground = colorScheme.onSurface.withValues(
          alpha: isDark ? 0.10 : 0.06,
        );
        final warningAccentColor = colorScheme.error;
        final warningBodyTextColor = colorScheme.error.withValues(
          alpha: isDark ? 0.92 : 0.82,
        );
        final warningHeroBackground = warningAccentColor.withValues(
          alpha: isDark ? 0.18 : 0.14,
        );
        final warningPanelBackground = warningAccentColor.withValues(
          alpha: isDark ? 0.16 : 0.12,
        );
        final warningPanelIconBackground = warningAccentColor.withValues(
          alpha: isDark ? 0.22 : 0.18,
        );

        return Dialog(
          backgroundColor: dialogSurface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: subtleBorderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Material(
                    color: closeButtonBackground,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close_rounded, color: mutedTextColor),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: warningHeroBackground,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 40,
                    color: warningAccentColor,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  AppStrings.tr('account_suspended_title'),
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: warningAccentColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppStrings.tr('account_suspended_description'),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: mutedTextColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: warningPanelBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: warningAccentColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: warningPanelIconBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.priority_high_rounded,
                          size: 18,
                          color: warningAccentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.tr('warning_label'),
                              style: textTheme.labelLarge?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: warningAccentColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppStrings.tr('account_suspended_message'),
                              style: textTheme.bodySmall?.copyWith(
                                fontSize: 13,
                                color: warningBodyTextColor,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      AppStrings.tr('account_suspended_ok'),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: colorScheme.onError,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeletedAccountAlert() {
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;
        final isDark = theme.brightness == Brightness.dark;
        final dialogSurface = colorScheme.surface;

        final mutedTextColor = colorScheme.onSurface.withValues(alpha: 0.68);
        final subtleBorderColor = colorScheme.outline.withValues(
          alpha: isDark ? 0.45 : 0.18,
        );
        final closeButtonBackground = colorScheme.onSurface.withValues(
          alpha: isDark ? 0.10 : 0.06,
        );
        final warningAccentColor = colorScheme.error;
        final warningBodyTextColor = colorScheme.error.withValues(
          alpha: isDark ? 0.92 : 0.82,
        );
        final warningHeroBackground = warningAccentColor.withValues(
          alpha: isDark ? 0.18 : 0.14,
        );
        final warningPanelBackground = warningAccentColor.withValues(
          alpha: isDark ? 0.16 : 0.12,
        );
        final warningPanelIconBackground = warningAccentColor.withValues(
          alpha: isDark ? 0.22 : 0.18,
        );

        return Dialog(
          backgroundColor: dialogSurface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: subtleBorderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Material(
                    color: closeButtonBackground,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close_rounded, color: mutedTextColor),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: warningHeroBackground,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.person_off_rounded,
                    size: 40,
                    color: warningAccentColor,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  AppStrings.tr('account_deleted_title'),
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: warningAccentColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppStrings.tr('account_deleted_description'),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: mutedTextColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: warningPanelBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: warningAccentColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: warningPanelIconBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.priority_high_rounded,
                          size: 18,
                          color: warningAccentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.tr('warning_label'),
                              style: textTheme.labelLarge?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: warningAccentColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppStrings.tr('account_deleted_message'),
                              style: textTheme.bodySmall?.copyWith(
                                fontSize: 13,
                                color: warningBodyTextColor,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      AppStrings.tr('account_deleted_ok'),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: colorScheme.onError,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void autoLoginNavigation(String username, String userId, String userType) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.tr('logging_in_employee')),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 1),
      ),
    );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (context.mounted) {
        final String resolvedUserId = userId.trim();
        final loginData = {
          'uid': resolvedUserId,
          'user_id': resolvedUserId,
          'userId': resolvedUserId,
          'username': username,
          'userType': userType,
        };

        Navigator.pushReplacementNamed(
          context,
          AppRoute.appmain,
          arguments: loginData,
        );
      }
    });
  }
}
