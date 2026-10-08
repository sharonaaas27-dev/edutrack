import 'package:flutter/material.dart';

/// Centralized color system for EduTrack.
///
/// All colors used in the app should come from here so the palette
/// can be changed in a single place.
abstract final class AppColors {
  // Primary — deep emerald green.
  static const Color primary = Color(0xFF0E7C5B);
  static const Color primaryDark = Color(0xFF0A5C44);
  static const Color primaryLight = Color(0xFFE3F2EC);
  static const Color primaryContainer = Color(0xFFCDE9DD);

  // Secondary — dark neutral.
  static const Color secondary = Color(0xFF1F2937);
  static const Color secondaryLight = Color(0xFF4B5563);

  // Background / surface.
  static const Color background = Color(0xFFF6F7F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEEF1F4);

  // Text.
  static const Color textPrimary = Color(0xFF1A1C1E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // Borders / dividers.
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFE5E7EB);

  // Status.
  static const Color success = Color(0xFF16A34A);
  static const Color successBackground = Color(0xFFDCFCE7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBackground = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBackground = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBackground = Color(0xFFDBEAFE);

  // Neutrals for icons / disabled states.
  static const Color disabled = Color(0xFFD1D5DB);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color shadow = Color(0x1A1A1C1E);

  // Gradient + illustration accents (Stage 2 creative polish).
  static const Color gradientStart = Color(0xFF0E7C5B);
  static const Color gradientEnd = Color(0xFF0A3D30);
  static const Color accentGold = Color(0xFFFBBF24);
  static const Color accentSky = Color(0xFF38BDF8);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentRose = Color(0xFFF43F5E);

  /// Deterministic avatar background derived from a name.
  static Color avatarFor(String name) {
    const palette = [
      Color(0xFF0E7C5B),
      Color(0xFF2563EB),
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
      Color(0xFFEA580C),
      Color(0xFF0891B2),
    ];
    if (name.isEmpty) return palette[0];
    var hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash * 31 + unit) % 997;
    }
    return palette[hash % palette.length];
  }

  /// Attendance band color. Thresholds: >=85 good, 75–84 average, <75 low.
  static Color attendance(double percentage) {
    if (percentage >= 85) return success;
    if (percentage >= 75) return warning;
    return error;
  }

  static Color attendanceBackground(double percentage) {
    if (percentage >= 85) return successBackground;
    if (percentage >= 75) return warningBackground;
    return errorBackground;
  }
}
