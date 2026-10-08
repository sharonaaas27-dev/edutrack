import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edutrack/core/constants/app_colors.dart';

/// Centralized typography built on Inter (via Google Fonts).
///
/// Screens must use [Theme.of(context).textTheme] rather than
/// hard-coding sizes.
class AppTextTheme {
  AppTextTheme._();

  static TextTheme get light {
    final base = ThemeData.light().textTheme;
    final inter = GoogleFonts.interTextTheme(base);
    return inter.copyWith(
      displayLarge: inter.displayLarge?.copyWith(
        fontSize: 32,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      ),
      headlineSmall: inter.headlineSmall?.copyWith(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.25,
      ),
      titleLarge: inter.titleLarge?.copyWith(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: inter.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleSmall: inter.titleSmall?.copyWith(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: inter.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodyMedium: inter.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodySmall: inter.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      labelLarge: inter.labelLarge?.copyWith(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      labelMedium: inter.labelMedium?.copyWith(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
      labelSmall: inter.labelSmall?.copyWith(
        fontSize: 11,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}
