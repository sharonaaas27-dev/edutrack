import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/utils/format.dart';

/// Responsive stat grid that sizes rows by content instead of forcing a
/// fixed aspect ratio (which overflows when text scales or content grows).
class StatGrid extends StatelessWidget {
  const StatGrid({
    super.key,
    required this.columns,
    required this.children,
    this.spacing = AppSpacing.md,
  }) : assert(columns > 0, 'columns must be positive');

  final int columns;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalGap = spacing * (columns - 1);
        final itemWidth =
            ((constraints.maxWidth - totalGap) / columns).clamp(0.0, 320.0);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Canonical statistic card used by every dashboard. Replaces the
/// per-screen duplicates (animated count-up kept subtle and optional).
class AppStatCard extends StatelessWidget {
  const AppStatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.color = AppColors.primary,
    this.onTap,
    this.animateValue = true,
    this.semanticValue,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  /// Numeric count-up animation for integer values (skipped for text).
  final bool animateValue;

  /// Screen-reader label, e.g. "Total students: 12".
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: AppSpacing.md),
          _ValueText(
            value: value,
            color: color,
            animate: animateValue,
            textTheme: textTheme,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            style: textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    final card = Card(
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: content,
            ),
    );
    final label = semanticValue ?? '$title: $value';
    return Semantics(label: label, button: onTap != null, child: card);
  }
}

class _ValueText extends StatelessWidget {
  const _ValueText({
    required this.value,
    required this.color,
    required this.animate,
    required this.textTheme,
  });

  final String value;
  final Color color;
  final bool animate;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final target = int.tryParse(value);
    if (!animate || target == null) {
      return Text(
        value,
        style: textTheme.headlineSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: target),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        return Text(
          formatCount(animated),
          style: textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        );
      },
    );
  }
}

/// Compact horizontal stat tile (icon + value + label in a row).
/// Used for dense summary strips such as the attendance register.
class AppStatTile extends StatelessWidget {
  const AppStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, color: color, size: 20,
                  semanticLabel: label),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ValueText(
                    value: value,
                    color: color,
                    animate: true,
                    textTheme: textTheme,
                  ),
                  Text(
                    label,
                    style: textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
/// Canonical quick-action tile (icon + label + chevron). Used by every
/// dashboard's action grid so actions look and behave identically.
class AppActionCard extends StatelessWidget {
  const AppActionCard({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28, semanticLabel: label),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.textHint,
                    semanticLabel: 'Open',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
