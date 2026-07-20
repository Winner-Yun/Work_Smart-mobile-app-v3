import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/config/language_manager.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/features/user/auth/logic/auth_logic.dart';

// Authscreen: Employee login UI (Mobile)
class Authscreen extends StatefulWidget {
  const Authscreen({super.key});

  @override
  State<Authscreen> createState() => _AuthscreenState();
}

class _AuthscreenState extends State<Authscreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool obscurePassword = true;
  bool _isLoggingIn = false;
  bool _handledSuspendedRouteAlert = false;
  bool _handledDeletedRouteAlert = false;
  late AuthLogic authLogic;

  // ─────────── SCREEN INITIALIZATION ───────────

  @override
  void initState() {
    super.initState();
    // Initialize auth logic
    authLogic = AuthLogic(
      context: context,
      usernameController: _usernameController,
      passwordController: _passwordController,
      formKey: _formKey,
    );
    _checkCachedLogin();
  }

  void _checkCachedLogin() {
    authLogic.checkCachedLogin((username, userId, userType) {
      authLogic.autoLoginNavigation(username, userId, userType);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map<String, dynamic>) {
      return;
    }

    if (!_handledSuspendedRouteAlert && args['showSuspendedDialog'] == true) {
      _handledSuspendedRouteAlert = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        authLogic.showSuspendedAlert();
      });
    }

    if (!_handledDeletedRouteAlert && args['showDeletedDialog'] == true) {
      _handledDeletedRouteAlert = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        authLogic.showDeletedAccountAlert();
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─────────── LOGIN PROCESSING ───────────

  Future<void> _handleLogin() async {
    if (_isLoggingIn) {
      return;
    }

    setState(() => _isLoggingIn = true);

    bool loginSucceeded = false;
    try {
      final isValid = await authLogic.handleLogin();
      if (!isValid || !mounted) {
        return;
      }

      loginSucceeded = true;
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        final loginData = authLogic.getLoginData();
        authLogic.navigateToMainApp(loginData);
        authLogic.clearForm();
      }
    } finally {
      if (mounted && !loginSucceeded) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  // ─────────── MAIN WIDGET BUILD ───────────
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageManager(),
      builder: (context, child) {
        final theme = Theme.of(context);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: theme.cardTheme.color,
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Stack(
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

                      // --- Language Switcher ---
                      Positioned(
                        top: 50,
                        right: 20,
                        child: _buildLanguageButton(theme),
                      ),

                      Positioned(
                        top: 60,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15.0,
                            vertical: 5,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 800),
                                tween: Tween(begin: 0.0, end: 1.0),
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: Transform.scale(
                                      scale: value,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Center(
                                  child: Hero(
                                    tag: 'logo',
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset(
                                            AppImg.appIcon,
                                            width: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            "WorkSmart",
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                              decoration: TextDecoration.none,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 70),
                              Column(
                                key: const ValueKey<String>('employee'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.tr('smart_hr_system'),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    AppStrings.tr('welcome'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, -30 + ((1.0 - value) * 100)),
                        child: Opacity(
                          opacity: value.clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: Transform.translate(
                      offset: const Offset(0, -30),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: _buildLoginForm(theme),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageButton(ThemeData theme) {
    final languageManager = LanguageManager();
    final isKhmer = languageManager.locale == 'km';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final newLang = isKhmer ? 'en' : 'km';
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => Center(
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(),
              ),
            ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
          );

          await Future.delayed(const Duration(milliseconds: 800));

          if (context.mounted) {
            Navigator.of(context).pop();
            languageManager.changeLanguage(newLang);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                isKhmer ? "ភាសាខ្មែរ" : "English",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  AppStrings.tr('smart_hr_management'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.tr('login_subtitle_employee'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            AppStrings.tr('username_or_id'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Theme(
            data: theme.copyWith(
              textSelectionTheme: TextSelectionThemeData(
                cursorColor: theme.colorScheme.primary,
                selectionHandleColor: theme.colorScheme.primary,
                selectionColor: theme.colorScheme.primary.withValues(
                  alpha: 0.2,
                ),
              ),
            ),
            child: TextFormField(
              controller: _usernameController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppStrings.tr('enter_id_error');
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: AppStrings.tr('enter_id_hint'),
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.tr('password'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Theme(
            data: theme.copyWith(
              textSelectionTheme: TextSelectionThemeData(
                cursorColor: theme.colorScheme.primary,
                selectionHandleColor: theme.colorScheme.primary,
                selectionColor: theme.colorScheme.primary.withValues(
                  alpha: 0.2,
                ),
              ),
            ),
            child: TextFormField(
              controller: _passwordController,
              obscureText: obscurePassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppStrings.tr('enter_password_error');
                }
                if (value.length < 6) {
                  return AppStrings.tr('password_length_error');
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: AppStrings.tr('enter_password_hint'),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: () =>
                      setState(() => obscurePassword = !obscurePassword),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentGeometry.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoute.forgotpassScreen);
              },
              child: Text(
                AppStrings.tr('forgot_password'),
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoggingIn ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isLoggingIn
                    ? Row(
                        key: const ValueKey<String>('login-loading'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            AppStrings.tr('logging_in_employee'),
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        AppStrings.tr('login_button'),
                        key: const ValueKey<String>('login-text'),
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
