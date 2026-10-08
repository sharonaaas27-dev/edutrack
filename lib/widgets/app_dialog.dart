import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';

/// Canonical destructive-action confirmation. Returns true when the user
/// confirms, false/null on cancel/dismiss. Danger styling is centralized
/// here instead of rebuilt per screen.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
  IconData icon = Icons.delete_outline_rounded,
  bool danger = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final color = danger ? AppColors.error : AppColors.primary;
      final background =
          danger ? AppColors.errorBackground : AppColors.primaryLight;
      return AlertDialog(
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Canonical info dialog for About/acknowledgement flows.
Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  String actionLabel = 'Got it',
  IconData icon = Icons.info_outline_rounded,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: AppColors.infoBackground,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.info_outline_rounded,
            color: AppColors.info),
      ),
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text(message, textAlign: TextAlign.center),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(actionLabel),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
    ),
  );
}
