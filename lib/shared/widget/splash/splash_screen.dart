import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_worksmart_app/config/app_colors.dart';
import 'package:flutter_worksmart_app/core/constants/app_img.dart';
import 'package:flutter_worksmart_app/core/constants/app_strings.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  final String nextRoute;
  final Duration minDuration;

  const SplashScreen({
    super.key,
    required this.nextRoute,
    this.minDuration = const Duration(milliseconds: 3000),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoPulse;
  late final Animation<double> _logoTilt;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;

  bool _devModeChecked = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _logoPulse = Tween<double>(begin: 0.94, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _logoTilt = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.24), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.05, 0.55, curve: Curves.easeOutCubic),
          ),
        );

    _subtitleFade = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
      ),
    );

    _checkDeveloperModeAndProceed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkDeveloperModeAndProceed() async {
    // Wait for splash duration
    await Future<void>.delayed(widget.minDuration);
    if (!mounted) return;
    if (_devModeChecked) return;
    _devModeChecked = true;
    bool developerMode = false;
    try {
      // developerMode = await FlutterJailbreakDetection.developerMode;
    } catch (_) {
      developerMode = false;
    }
    if (developerMode) {
      // Show blocking alert and exit if not closed
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          final colorScheme = theme.colorScheme;
          return AlertDialog(
            backgroundColor: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppStrings.tr('developer_mode_alert_title'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.tr('developer_mode_alert_message'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    SystemNavigator.pop();
                  },
                  icon: const Icon(Icons.exit_to_app_rounded),
                  label: Text(AppStrings.tr('exit_app')),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      );
      // If dialog is somehow dismissed, exit anyway
      SystemNavigator.pop();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(widget.nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF0B1F2A);
    const accent = Color(0xFF5ED3F3);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final wave = math.sin(_controller.value * 2 * math.pi);
            final orbShift = 18.0 * wave;

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: const [Color(0xFF0B1F2A), Color(0xFF142D3B)],
                  begin: Alignment(-1 + (0.12 * wave), -1),
                  end: Alignment(1, 1 - (0.12 * wave)),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 110 + orbShift,
                    left: -40,
                    child: _GlowOrb(size: 140, color: accent.withOpacity(0.14)),
                  ),
                  Positioned(
                    bottom: 130 - orbShift,
                    right: -28,
                    child: _GlowOrb(
                      size: 120,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.rotate(
                          angle: _logoTilt.value,
                          child: Transform.scale(
                            scale: _logoPulse.value,
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: background,
                                shape: BoxShape.circle,
                                border: Border.all(color: accent, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withOpacity(0.28),
                                    blurRadius: 24,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                AppImg.appIconLight,
                                width: 48,
                                height: 48,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SlideTransition(
                          position: _titleSlide,
                          child: FadeTransition(
                            opacity: _subtitleFade,
                            child: Text(
                              'WorkSmart',
                              style: GoogleFonts.montserrat(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FadeTransition(
                          opacity: _subtitleFade,
                          child: Text(
                            'Smarter work, every day',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white70,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Transform.scale(
                          scale: 0.92 + ((_logoPulse.value - 0.94) * 0.7),
                          child: const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 44, spreadRadius: 10),
          ],
        ),
      ),
    );
  }
}
