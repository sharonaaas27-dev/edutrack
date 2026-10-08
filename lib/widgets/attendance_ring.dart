import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_colors.dart';

/// Animated circular attendance indicator.
class AttendanceRing extends StatelessWidget {
  const AttendanceRing({
    super.key,
    required this.percentage,
    this.size = 84,
    this.strokeWidth = 8,
    this.showLabel = true,
  });

  final double percentage;
  final double size;
  final double strokeWidth;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.attendance(percentage);
    final clamped = (percentage / 100).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: clamped),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: strokeWidth,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              if (showLabel)
                Text(
                  '${percentage.toStringAsFixed(percentage % 1 == 0 ? 0 : 1)}%',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
