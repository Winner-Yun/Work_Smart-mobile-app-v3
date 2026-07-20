import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemes {
  static final TextTheme _khmerTextTheme = GoogleFonts.notoSansKhmerTextTheme();

  // --- Light Theme ---
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    textTheme: _khmerTextTheme,
    primaryTextTheme: _khmerTextTheme.apply(
      bodyColor: AppColors.primary,
      displayColor: AppColors.primary,
    ),
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.lightBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      tertiary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.lightSurface,
    ),

    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBg),
      ),
    ),
  );

  // --- Dark Theme ---
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    textTheme: _khmerTextTheme.apply(
      bodyColor: AppColors.textLight,
      displayColor: AppColors.textLight,
    ),
    primaryTextTheme: _khmerTextTheme.apply(
      bodyColor: AppColors.primary,
      displayColor: AppColors.primary,
    ),
    scaffoldBackgroundColor: AppColors.darkBg,

    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),

    colorScheme: const ColorScheme.dark(
      primary: AppColors.tertiary,
      secondary: AppColors.secondary,
      tertiary: AppColors.darkSurface,
      surface: AppColors.darkSurface,
      error: AppColors.error,
    ),
  );
}
