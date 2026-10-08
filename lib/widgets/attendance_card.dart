import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/models/attendance.dart';
import 'package:edutrack/models/student.dart';
import 'package:edutrack/widgets/app_avatar.dart';

/// One tappable marking row: avatar + identity + Present/Absent/Late.
/// The selected mark is visually obvious via filled color.
class AttendanceCard extends StatelessWidget {
  const AttendanceCard({
    super.key,
    required this.student,
    required this.selected,
    required this.onSelect,
  });

  final Student student;
  final AttendanceMark? selected;
  final ValueChanged<AttendanceMark> onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                  name: student.name,
                  imageUrl: student.profileImageUrl,
                  radius: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${student.studentId} · ${student.course} • ${student.section}',
                        style: textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                for (final mark in AttendanceMark.values)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: mark == AttendanceMark.late ? 0 : AppSpacing.sm,
                      ),
                      child: _MarkButton(
                        studentName: student.name,
                        mark: mark,
                        selected: selected == mark,
                        onTap: () => onSelect(mark),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({
    required this.studentName,
    required this.mark,
    required this.selected,
    required this.onTap,
  });

  final String studentName;
  final AttendanceMark mark;
  final bool selected;
  final VoidCallback onTap;

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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mark $studentName as ${mark.label}'
          '${selected ? ', currently selected' : ''}',
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            backgroundColor: selected ? _color : Colors.transparent,
            foregroundColor: selected ? Colors.white : _color,
            side: BorderSide(color: selected ? _color : AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
          icon: Icon(mark.icon, size: 16),
          label: Text(
            mark.label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
