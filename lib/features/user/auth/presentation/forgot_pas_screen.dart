// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/features/user/auth/presentation/change_pas_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  final List<TextEditingController> _otpControllers = List.generate(
    4,
    (index) => TextEditingController(),
  );

  @override
  void dispose() {
    _emailController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleResetRequest() {
    if (_formKey.currentState!.validate()) {
      setState(() => _currentStep = 1);
    }
  }

  void _verifyOtpAndNavigate() async {
    String otp = _otpControllers.map((controller) => controller.text).join();

    if (otp.length == 4) {
      _showLoadingOverlay();

      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ResetPasswordScreen(resetEmail: _emailController.text.trim()),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr('otp_length_error'))),
      );
    }
  }

  void _showLoadingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 3,
                  ).animate().rotate(duration: 1.seconds),
                  const SizedBox(height: 20),
                  Text(
                    AppStrings.tr('verifying'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
          ),
        );
      },
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
          height: 280,
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
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () {
              if (_currentStep == 1) {
                setState(() => _currentStep = 0);
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        Positioned(
          bottom: 60,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogoBadge().animate().fadeIn(duration: 600.ms),
              const SizedBox(height: 20),
              Text(
                _currentStep == 0
                    ? AppStrings.tr('forgot_password')
                    : AppStrings.tr('verify_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ).animate(key: ValueKey(_currentStep)).fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AppImg.appIcon, width: 16),
          const SizedBox(width: 8),
          Text(
            "WorkSmart",
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContainer() {
    return Transform.translate(
      offset: const Offset(0, -30),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _currentStep == 0
              ? _buildEmailInput().animate().fadeIn()
              : _buildOtpInput().animate().fadeIn(),
        ),
      ),
    );
  }

  Widget _buildEmailInput() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey(0),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.tr('forgot_password_desc'),
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 30),
          _buildThemedTextField(
            controller: _emailController,
            label: AppStrings.tr('email_label'),
            hint: "example@email.com",
            icon: Icons.email_outlined,
          ),
          const SizedBox(height: 40),
          _buildPrimaryButton(
            label: AppStrings.tr('send_button'),
            onTap: _handleResetRequest,
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInput() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.tr('otp_message'),
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _otpBox(first: true, last: false, index: 0),
            const SizedBox(width: 10),
            _otpBox(first: false, last: false, index: 1),
            const SizedBox(width: 10),
            _otpBox(first: false, last: false, index: 2),
            const SizedBox(width: 10),
            _otpBox(first: false, last: true, index: 3),
          ],
        ),
        const SizedBox(height: 40),
        _buildPrimaryButton(
          label: AppStrings.tr('verify_button'),
          onTap: _verifyOtpAndNavigate,
        ),
        Center(
          child: TextButton(
            onPressed: () {},
            child: Text(
              AppStrings.tr('resend_code'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _otpBox({
    required bool first,
    required bool last,
    required int index,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Theme(
          data: theme.copyWith(
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: theme.colorScheme.primary,
              selectionHandleColor: theme.colorScheme.primary,
              selectionColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: TextField(
            controller: _otpControllers[index],
            autofocus: index == 0,
            onChanged: (value) {
              if (value.length == 1 && !last) {
                FocusScope.of(context).nextFocus();
              }
              if (value.isEmpty && !first) {
                FocusScope.of(context).previousFocus();
              }
              if (value.length == 1 && last) {
                _verifyOtpAndNavigate();
              }
            },
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            keyboardType: TextInputType.number,
            inputFormatters: [
              LengthLimitingTextInputFormatter(1),
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(counterText: ""),
          ),
        ),
      ),
    );
  }

  Widget _buildThemedTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Theme(
          data: theme.copyWith(
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: theme.colorScheme.primary,
              selectionHandleColor: theme.colorScheme.primary,
              selectionColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: TextFormField(
            controller: controller,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return AppStrings.tr('enter_email_error');
              }
              if (!RegExp(
                r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
              ).hasMatch(value)) {
                return AppStrings.tr('invalid_email_error');
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: theme.colorScheme.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
