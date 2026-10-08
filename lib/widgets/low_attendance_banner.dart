import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/utils/format.dart';

/// Reusable low-attendance warning. Rendered only when the caller's data
/// actually breaches the 75% threshold — never with hard-coded values.
class LowAttendanceBanner extends StatelessWidget {
  const LowAttendanceBanner({
    super.key,
    required this.subjectName,
    required this.percentage,
    this.onTap,
  });

  final String subjectName;
  final double percentage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final content = Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              semanticLabel: 'Warning',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Low Attendance',
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your attendance in $subjectName is '
                  '${formatPercentage(percentage)}. '
                  'Please improve your attendance.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.error,
              semanticLabel: 'Open details',
            ),
        ],
      ),
    );
    final labeled = Semantics(
      label: 'Low attendance warning for $subjectName, '
          '${formatPercentage(percentage)}',
      button: onTap != null,
      child: content,
    );
    if (onTap == null) return labeled;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: labeled,
    );
  }
}
