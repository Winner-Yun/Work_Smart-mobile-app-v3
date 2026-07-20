import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_worksmart_app/config/language_manager.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:flutter_worksmart_app/features/user/auth/logic/auth_logic.dart';

// Authscreen: Employee login UI (Mobile) — Google sign-in only.
class Authscreen extends StatefulWidget {
  const Authscreen({super.key});

  @override
  State<Authscreen> createState() => _AuthscreenState();
}

class _AuthscreenState extends State<Authscreen> {
  bool _isLoggingIn = false;
  bool _handledSuspendedRouteAlert = false;
  bool _handledDeletedRouteAlert = false;
  late AuthLogic authLogic;

  // ─────────── SCREEN INITIALIZATION ───────────

  @override
  void initState() {
    super.initState();
    authLogic = AuthLogic(context: context);
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

  // ─────────── LOGIN PROCESSING ───────────

  Future<void> _handleGoogleSignIn() async {
    if (_isLoggingIn) {
      return;
    }

    setState(() => _isLoggingIn = true);

    bool loginSucceeded = false;
    try {
      final isValid = await authLogic.handleGoogleSignIn();
      if (!isValid || !mounted) {
        return;
      }

      loginSucceeded = true;
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        final loginData = authLogic.getLoginData();
        authLogic.navigateToMainApp(loginData);
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
                                        color: Theme.of(
                                          context,
                                        ).cardTheme.color,
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
                                    'Smart HR System',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Welcome Back',
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
                        child: _buildGoogleSignInPanel(theme),
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

  // ─────────── GOOGLE SIGN-IN PANEL ───────────
  // Replaces the old username/password form: sign-up and login are the
  // same action here — the backend upserts the account on first sign-in.
  Widget _buildGoogleSignInPanel(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Smart HR Management',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to manage your attendance, leave, and notifications in one place.',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        _buildFeatureRow(
          theme,
          icon: Icons.face_retouching_natural_rounded,
          title: 'Face Attendance',
          subtitle: 'Check in and out with a quick face scan',
        ),
        const SizedBox(height: 16),
        _buildFeatureRow(
          theme,
          icon: Icons.event_available_rounded,
          title: 'Leave Management',
          subtitle: 'Apply for leave and track approval status',
        ),
        const SizedBox(height: 16),
        _buildFeatureRow(
          theme,
          icon: Icons.notifications_active_rounded,
          title: 'Instant Notifications',
          subtitle: 'Stay updated on approvals and announcements',
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: Divider(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Sign in to continue',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoggingIn ? null : _handleGoogleSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.onSurface,
              elevation: 0,
              side: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.18),
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isLoggingIn
                  ? Row(
                      key: const ValueKey<String>('google-login-loading'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Signing in...',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      key: const ValueKey<String>('google-login-text'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(AppImg.googleLogo, width: 22, height: 22),
                        const SizedBox(width: 14),
                        Text(
                          'Continue with Google',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            children: [
              TextSpan(text: 'By continuing, you agree to our '),
              TextSpan(
                text: 'Terms of Service',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatureRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
