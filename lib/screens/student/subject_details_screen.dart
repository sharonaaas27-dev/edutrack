import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/utils/date_format.dart';
import 'package:edutrack/models/attendance.dart';
import 'package:edutrack/providers/attendance_provider.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/widgets/app_cards.dart';
import 'package:edutrack/widgets/attendance_ring.dart';
import 'package:edutrack/widgets/attendance_status_chip.dart';
import 'package:edutrack/widgets/empty_state.dart';
import 'package:edutrack/widgets/section_header.dart';

/// Student-facing detail for one subject: info, schedule, per-subject
/// attendance stats, and subject-filtered history.
class StudentSubjectDetailsScreen extends StatefulWidget {
  const StudentSubjectDetailsScreen({
    super.key,
    required this.studentId,
    required this.subjectId,
  });

  final String studentId;
  final String subjectId;

  @override
  State<StudentSubjectDetailsScreen> createState() =>
      _StudentSubjectDetailsScreenState();
}

class _StudentSubjectDetailsScreenState
    extends State<StudentSubjectDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubjectProvider>().ensureLoaded();
      context.read<AttendanceProvider>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subjects = context.watch<SubjectProvider>();
    final attendance = context.watch<AttendanceProvider>();
    final subject = subjects.getById(widget.subjectId);

    if (subject == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subject')),
        body: const SafeArea(
          child: EmptyState(
            title: 'Subject not found',
            subtitle: 'This record may have been deleted.',
            icon: Icons.menu_book_outlined,
          ),
        ),
      );
    }

    final stats = attendance.statsForSubject(
      widget.studentId,
      widget.subjectId,
    );
    final history = attendance.historyForSubject(
      widget.studentId,
      widget.subjectId,
    );
    final avatarColor = AppColors.avatarFor(subject.code);

    return Scaffold(
      appBar: AppBar(title: Text(subject.code)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [avatarColor, AppColors.gradientEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: AttendanceRing(
                            percentage: stats.percentage,
                            size: 88,
                            strokeWidth: 9,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xl),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject.code.toUpperCase(),
                                style: textTheme.labelSmall?.copyWith(
                                  color: AppColors.accentGold,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                subject.name,
                                style: textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${subject.teacherName} · ${stats.total} classes',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  StatGrid(
                    columns: 4,
                    spacing: AppSpacing.sm,
                    children: [
                      _MiniTile(
                        label: 'Present',
                        value: '${stats.present}',
                        color: AppColors.success,
                      ),
                      _MiniTile(
                        label: 'Absent',
                        value: '${stats.absent}',
                        color: AppColors.error,
                      ),
                      _MiniTile(
                        label: 'Late',
                        value: '${stats.late}',
                        color: AppColors.warning,
                      ),
                      _MiniTile(
                        label: 'Total',
                        value: '${stats.total}',
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(
                            title: 'About this subject',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (subject.description.isNotEmpty)
                            Text(
                              subject.description,
                              style: textTheme.bodyMedium,
                            ),
                          if (subject.description.isNotEmpty)
                            const SizedBox(height: AppSpacing.md),
                          _MetaRow(
                            icon: Icons.layers_outlined,
                            text:
                                '${subject.course} · ${subject.year} · ${subject.semester} · Section ${subject.section}',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _MetaRow(
                            icon: Icons.meeting_room_outlined,
                            text:
                                'Room ${subject.room.isEmpty ? '—' : subject.room} · ${subject.credits} Credits',
                          ),
                          if (subject.schedule.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            for (final slot in subject.schedule)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                child: _MetaRow(
                                  icon: Icons.schedule_outlined,
                                  text: slot.label,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: 'History',
                    icon: Icons.history_rounded,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (history.isEmpty)
                    const EmptyState(
                      title: 'No records yet',
                      subtitle: 'Attendance in this subject will appear here.',
                      icon: Icons.history_rounded,
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (var i = 0; i < history.length; i++) ...[
                            _HistoryRow(record: history[i]),
                            if (i != history.length - 1)
                              const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
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
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      dense: true,
      leading: Container(
        width: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${record.date.day}',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              formatDate(record.date).split(' ')[1],
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
      title: Text(
        formatDate(record.date),
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(weekdayName(record.date), style: textTheme.bodySmall),
      trailing: AttendanceStatusChip(mark: record.mark, compact: true),
    );
  }
}
