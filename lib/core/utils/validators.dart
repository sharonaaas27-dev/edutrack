import 'package:edutrack/core/constants/app_strings.dart';

/// Reusable form validators. Pure functions — no UI code here.
abstract final class Validators {
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return AppStrings.emailRequired;
    if (!_emailRegExp.hasMatch(input)) return AppStrings.emailInvalid;
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return AppStrings.passwordRequired;
    if (value.length < 6) return AppStrings.passwordTooShort;
    return null;
  }

  static String? required(String? value, {String message = 'Required.'}) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? phone(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return null;
    final digits = input.replaceAll(RegExp(r'[\s+\-()]'), '');
    if (digits.length < 7 || int.tryParse(digits) == null) {
      return AppStrings.phoneInvalid;
    }
    return null;
  }

  static String? attendance(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return AppStrings.attendanceRequired;
    final parsed = double.tryParse(input);
    if (parsed == null || parsed < 0 || parsed > 100) {
      return AppStrings.attendanceRange;
    }
    return null;
  }

  static String? credits(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return AppStrings.creditsRequired;
    final parsed = int.tryParse(input);
    if (parsed == null || parsed < 1 || parsed > 10) {
      return AppStrings.creditsInvalid;
    }
    return null;
  }
}
