import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:flutter_worksmart_app/features/user/auth/auth_logic.dart';
import 'package:flutter_worksmart_app/features/user/repository/user_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/user_service.dart';
import 'package:flutter_worksmart_app/features/user/logic/face_scan_logic.dart';
import 'package:intl/intl.dart';

/// Orchestrates the secure "Update Face" flow shared by Settings and the
/// homepage shortcut: cooldown check, user confirmation, Google re-auth,
/// verify against the stored embedding, then re-register the new face.
/// Re-registering is the update — there's no separate backend endpoint.
class UpdateFaceFlowController {
  UpdateFaceFlowController._();

  static Future<void> start(
    BuildContext context, {
    required Map<String, dynamic>? loginData,
  }) async {
    final String userId = (loginData?['uid'] ?? '').toString().trim();
    if (userId.isEmpty) {
      _showSnack(context, AppStrings.tr('unable_to_resolve_user_id'));
      return;
    }

    final FaceUpdateEligibility eligibility = await DatabaseHelper()
        .getFaceUpdateEligibility(userId);
    if (!eligibility.allowed && eligibility.nextAllowedAtUtc != null) {
      if (!context.mounted) return;
      await _showCooldownDialog(context, eligibility.nextAllowedAtUtc!);
      return;
    }

    if (!context.mounted) return;
    final bool acknowledged = await _showExplanationDialog(context);
    if (!acknowledged || !context.mounted) return;

    String currentEmail = '';
    try {
      final userProfile = await UserRepository(
        UserService(),
      ).getUserProfile();
      currentEmail = userProfile.email;
    } catch (_) {
      // No email check if the profile fetch fails — re-auth still requires Google sign-in.
    }

    if (!context.mounted) return;
    final GoogleReauthResult reauthResult = await AuthLogic(
      context: context,
    ).reauthenticateForSensitiveAction(expectedEmail: currentEmail);

    if (reauthResult.status != GoogleReauthStatus.success) {
      if (!context.mounted) return;
      _showSnack(context, _reauthFailureMessage(reauthResult.status));
      return;
    }

    if (!context.mounted) return;
    final dynamic verifyResult = await Navigator.pushNamed(
      context,
      AppRoute.faceScanScreen,
      arguments: {
        ...?loginData,
        'scanType': FaceScanLogic.scanTypeVerifyOnly,
      },
    );

    if (verifyResult != true) {
      // Scan screen already surfaced the error — nothing more to do here.
      return;
    }

    // Let the camera fully release before the register screen claims it again.
    await Future.delayed(const Duration(milliseconds: 400));

    if (!context.mounted) return;
    await Navigator.pushNamed(
      context,
      AppRoute.registerFace,
      arguments: loginData,
    );
  }

  static Future<bool> _showExplanationDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.face_retouching_natural_rounded,
              color: theme.colorScheme.primary,
              size: 48,
            ),
          ),
          title: Text(
            AppStrings.tr('update_face_explain_title'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStep(theme, '1', AppStrings.tr('update_face_step_reauth')),
              const SizedBox(height: 10),
              _buildStep(theme, '2', AppStrings.tr('update_face_step_verify')),
              const SizedBox(height: 10),
              _buildStep(theme, '3', AppStrings.tr('update_face_step_capture')),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(AppStrings.tr('cancel_button')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppStrings.tr('update_face_continue'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  static Widget _buildStep(ThemeData theme, String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: theme.colorScheme.primary,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }

  static Future<void> _showCooldownDialog(
    BuildContext context,
    DateTime nextAllowedAtUtc,
  ) async {
    final String formattedDate = DateFormat(
      'dd MMM yyyy',
    ).format(nextAllowedAtUtc.toLocal());

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppStrings.tr('update_face_cooldown_title')),
        content: Text(
          '${AppStrings.tr('update_face_cooldown_msg')} $formattedDate.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppStrings.tr('understood')),
          ),
        ],
      ),
    );
  }

  static String _reauthFailureMessage(GoogleReauthStatus status) {
    switch (status) {
      case GoogleReauthStatus.emailMismatch:
        return AppStrings.tr('update_face_reauth_mismatch');
      case GoogleReauthStatus.cancelled:
        return AppStrings.tr('update_face_reauth_cancelled');
      case GoogleReauthStatus.success:
        return '';
      case GoogleReauthStatus.error:
        return AppStrings.tr('update_face_reauth_failed');
    }
  }

  static void _showSnack(BuildContext context, String message) {
    if (message.isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
