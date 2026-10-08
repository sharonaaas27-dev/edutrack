import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';

/// Canonical section header: eyebrow title on the left, optional action
/// ("View All →") on the right. Replaces ad-hoc title rows everywhere.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.color = AppColors.primary,
    this.actionLabel,
    this.onAction,
  }) : assert(
          (actionLabel == null) == (onAction == null),
          'actionLabel and onAction must be provided together',
        );

  final String title;
  final IconData? icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: color,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              minimumSize: const Size(48, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionLabel!),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
      ],
    );
  }
}
