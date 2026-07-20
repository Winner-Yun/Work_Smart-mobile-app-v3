import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/features/user/auth/logic/change_password_logic.dart';

class ChangePasswordScreen extends StatefulWidget {
  final bool isFromProfile;
  final String? userId;
  final String? resetEmail;

  const ChangePasswordScreen({
    super.key,
    this.isFromProfile = false,
    this.userId,
    this.resetEmail,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class ResetPasswordScreen extends ChangePasswordScreen {
  const ResetPasswordScreen({
    super.key,
    super.isFromProfile,
    super.userId,
    super.resetEmail,
  });
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final ChangePasswordLogic _changePasswordLogic = ChangePasswordLogic();
  final _formKey = GlobalKey<FormState>();
  final _oldPassController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _obscureOld = true;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _oldPassController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final result = await _changePasswordLogic.changePassword(
      newPassword: _passController.text,
      oldPassword: widget.isFromProfile ? _oldPassController.text : null,
      isFromProfile: widget.isFromProfile,
      userId: widget.userId,
      resetEmail: widget.resetEmail,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.tr(result.errorKey ?? 'password_change_failed'),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).cardTheme.color,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 80,
            ).animate().scale(duration: 400.ms),
            const SizedBox(height: 20),
            Text(
              AppStrings.tr('success_title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.tr('success_message'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: Text(
                  AppStrings.tr('back_to_login'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).cardTheme.color,
        body: SingleChildScrollView(
          child: Column(children: [_buildHeader(), _buildFormContainer()]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(AppImg.authBackground),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.9),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 60,
          left: 15,
          child: CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        Positioned(
          bottom: 70,
          left: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isFromProfile
                    ? AppStrings.tr('change_password_action')
                    : AppStrings.tr('reset_password_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
              Text(
                AppStrings.tr('reset_password_subtitle'),
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormContainer() {
    final theme = Theme.of(context);
    return Transform.translate(
      offset: const Offset(0, -30),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (widget.isFromProfile) ...[
                _buildThemedPasswordField(
                  _oldPassController,
                  AppStrings.tr('old_password_label'),
                  AppStrings.tr('old_password_hint'),
                  Icons.lock_outline_rounded,
                  _obscureOld,
                  () => setState(() => _obscureOld = !_obscureOld),
                ),
                const SizedBox(height: 25),
              ],
              _buildThemedPasswordField(
                _passController,
                AppStrings.tr('new_password_label'),
                AppStrings.tr('new_password_hint'),
                Icons.lock_reset_rounded,
                _obscurePass,
                () => setState(() => _obscurePass = !_obscurePass),
              ),
              const SizedBox(height: 25),
              _buildThemedPasswordField(
                _confirmPassController,
                AppStrings.tr('confirm_password_label'),
                AppStrings.tr('confirm_password_hint'),
                Icons.verified_user_outlined,
                _obscureConfirm,
                () => setState(() => _obscureConfirm = !_obscureConfirm),
                isConfirm: true,
              ),
              // if (widget.isFromProfile)
              //   Align(
              //     alignment: Alignment.centerRight,
              //     child: TextButton(
              //       onPressed: () {
              //         Navigator.pushNamed(context, AppRoute.forgotpassScreen);
              //       },
              //       child: Text(AppStrings.tr('forgot_password')),
              //     ),
              //   ),
              const SizedBox(height: 20),
              _buildSubmitButton(),
            ],
          ),
        ),
      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
    );
  }

  Widget _buildThemedPasswordField(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData prefixIcon,
    bool obscure,
    VoidCallback toggle, {
    bool isConfirm = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Theme(
          data: theme.copyWith(
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: theme.colorScheme.primary,
              selectionHandleColor: theme.colorScheme.primary,
              selectionColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: TextFormField(
            controller: ctrl,
            obscureText: obscure,
            style: const TextStyle(fontSize: 16),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return AppStrings.tr('password_empty_error');
              }
              if (val.length < 6) return AppStrings.tr('password_length_error');
              if (isConfirm && val != _passController.text) {
                return AppStrings.tr('password_mismatch_error');
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(prefixIcon, color: theme.colorScheme.primary),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 20,
                ),
                onPressed: toggle,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: _isSubmitting ? null : _handleReset,
        child: _isSubmitting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: theme.colorScheme.onPrimary,
                ),
              )
            : Text(
                AppStrings.tr('change_password_button'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
