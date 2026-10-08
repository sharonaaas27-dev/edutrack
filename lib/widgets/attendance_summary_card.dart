import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/utils/responsive.dart';
import 'package:edutrack/models/attendance.dart';
import 'package:edutrack/widgets/app_cards.dart';

/// Four-tile Total / Present / Absent / Late summary strip.
/// Layout and tiles come from the canonical components.
class AttendanceSummaryCard extends StatelessWidget {
  const AttendanceSummaryCard({super.key, required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    return StatGrid(
      columns: responsiveValue<int>(context, mobile: 2, tablet: 4, desktop: 4),
      children: [
        AppStatTile(
          label: 'Total',
          value: '${summary.total}',
          icon: Icons.groups_outlined,
          color: AppColors.secondary,
        ),
        AppStatTile(
          label: 'Present',
          value: '${summary.present}',
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
        ),
        AppStatTile(
          label: 'Absent',
          value: '${summary.absent}',
          icon: Icons.cancel_outlined,
          color: AppColors.error,
        ),
        AppStatTile(
          label: 'Late',
          value: '${summary.late}',
          icon: Icons.access_time_outlined,
          color: AppColors.warning,
        ),
      ],
    );
  }
}
