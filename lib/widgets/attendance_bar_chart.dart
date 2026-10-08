import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/utils/format.dart';

/// A single bar segment for [AttendanceBarChart].
class BarSegment {
  const BarSegment({
    required this.label,
    required this.percentage,
    this.subLabel,
    this.color,
  });

  final String label;
  final double percentage;
  final String? subLabel;

  /// Fixed bar color. Defaults to the semantic attendance-band color,
  /// which is right for rate values; pass explicit colors for
  /// category breakdowns (present/late/absent).
  final Color? color;
}

/// Minimal dependency-free bar chart for attendance rates.
///
/// Bars animate in, use semantic attendance colors, and expose a full
/// textual summary to screen readers (charts must never be color-only).
class AttendanceBarChart extends StatelessWidget {
  const AttendanceBarChart({
    super.key,
    required this.segments,
    this.height = 168,
    this.maxValue = 100,
  });

  final List<BarSegment> segments;
  final double height;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }
    final summary = segments
        .map((s) => '${s.label}: ${formatPercentage(s.percentage)}')
        .join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Attendance chart. $summary',
          container: true,
          child: SizedBox(
            height: height,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) {
                return CustomPaint(
                  painter: _BarPainter(
                    values: [
                      for (final s in segments)
                        (s.percentage / maxValue).clamp(0.0, 1.0) *
                            progress,
                    ],
                    colors: [
                      for (final s in segments)
                        s.color ?? AppColors.attendance(s.percentage),
                    ],
                    gapColor: AppColors.surfaceVariant,
                    radius: AppSpacing.radiusSm,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in segments)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      formatPercentage(s.percentage),
                      style: textTheme.labelSmall?.copyWith(
                        color: s.color ??
                            AppColors.attendance(s.percentage),
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                    ),
                    Text(
                      s.label,
                      style: textTheme.bodySmall,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.values,
    required this.colors,
    required this.gapColor,
    required this.radius,
  });

  final List<double> values;
  final List<Color> colors;
  final Color gapColor;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const gap = 10.0;
    final slot = size.width / values.length;
    final barWidth = (slot - gap).clamp(8.0, 44.0);
    final trackPaint = Paint()..color = gapColor;

    for (var i = 0; i < values.length; i++) {
      final left = slot * i + (slot - barWidth) / 2;
      final trackRect = RRect.fromLTRBR(
        left,
        0,
        left + barWidth,
        size.height,
        Radius.circular(radius),
      );
      canvas.drawRRect(trackRect, trackPaint);

      final fillHeight = size.height * values[i].clamp(0.0, 1.0);
      if (fillHeight <= 0) continue;
      final fillPaint = Paint()..color = colors[i];
      final fillRect = RRect.fromLTRBR(
        left,
        size.height - fillHeight,
        left + barWidth,
        size.height,
        Radius.circular(radius),
      );
      canvas.drawRRect(fillRect, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}
