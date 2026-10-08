import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_spacing.dart';

/// Reusable primary button used across the app.
class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isEnabled = true,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isEnabled;

  bool get _disabled => !isEnabled || isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    final label = isLoading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSpacing.iconSize),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(text),
            ],
          );

    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: label,
        ),
      ),
    );
  }
}
