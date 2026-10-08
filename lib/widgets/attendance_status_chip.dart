import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/models/attendance.dart';

/// Single colored chip for one [AttendanceMark]. All status styling lives
/// here — screens must reuse this instead of duplicating colors.
class AttendanceStatusChip extends StatelessWidget {
  const AttendanceStatusChip({
    super.key,
    required this.mark,
    this.compact = false,
  });

  final AttendanceMark mark;
  final bool compact;

  Color get _color {
    switch (mark) {
      case AttendanceMark.present:
        return AppColors.success;
      case AttendanceMark.absent:
        return AppColors.error;
      case AttendanceMark.late:
        return AppColors.warning;
    }
  }

  Color get _background {
    switch (mark) {
      case AttendanceMark.present:
        return AppColors.successBackground;
      case AttendanceMark.absent:
        return AppColors.errorBackground;
      case AttendanceMark.late:
        return AppColors.warningBackground;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mark.icon, size: compact ? 13 : 15, color: _color),
          const SizedBox(width: 4),
          Text(
            mark.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
