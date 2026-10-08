import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/routes/app_routes.dart';
import 'package:edutrack/core/utils/date_format.dart';
import 'package:edutrack/core/utils/responsive.dart';
import 'package:edutrack/models/attendance.dart';
import 'package:edutrack/models/subject.dart';
import 'package:edutrack/providers/attendance_provider.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/widgets/app_shell.dart';
import 'package:edutrack/widgets/app_states.dart';
import 'package:edutrack/widgets/app_cards.dart';
import 'package:edutrack/widgets/attendance_ring.dart';
import 'package:edutrack/widgets/attendance_status_chip.dart';
import 'package:edutrack/widgets/empty_state.dart';
import 'package:edutrack/widgets/section_header.dart';

/// Student-facing attendance page: overall percentage, summary tiles,
/// and newest-first history with date / subject / status.
class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key, this.studentId});

  /// Resolved to the logged-in student by the backend in a later stage.
  /// Falls back to the first mock student for the Stage 3 demo.
  final String? studentId;

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final students = context.read<StudentProvider>();
      if (students.students.isEmpty && !students.isLoading) {
        students.loadStudents();
      }
      context.read<SubjectProvider>().ensureLoaded().then((_) {
        if (mounted) context.read<SubjectProvider>().preloadRosters();
      });
      context.read<AttendanceProvider>().ensureLoaded().then((_) {
        if (mounted) context.read<AttendanceProvider>().refreshPercentages();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final students = context.watch<StudentProvider>();
    final subjects = context.watch<SubjectProvider>();
    final attendance = context.watch<AttendanceProvider>();

    final resolvedId =
        widget.studentId ??
        (students.students.isNotEmpty ? students.students.first.id : null);
    final student = resolvedId == null ? null : students.getById(resolvedId);
    final history = resolvedId == null
        ? <AttendanceRecord>[]
        : attendance.historyFor(resolvedId);
    final stats = resolvedId == null
        ? StudentAttendanceStats.empty
        : attendance.statsFor(resolvedId);
    final enrolledSubjects = resolvedId == null
        ? <Subject>[]
        : subjects.subjects
              .where((s) => subjects.rosterFor(s.id).contains(resolvedId))
              .toList();

    return AppShell(
      title: 'My Attendance',
      selectedIndex: 2,
      body: PageBody(
        child: attendance.isLoading && !attendance.isLoaded
            ? const AppLoadingSkeleton(itemCount: 3, itemHeight: 130)
            : student == null
            ? const EmptyState(
                title: 'No attendance found',
                subtitle: 'Student records are still loading.',
                icon: Icons.fact_check_outlined,
              )
            : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.gradientStart,
                                AppColors.gradientEnd,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusXl,
                            ),
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
                                      'OVERALL ATTENDANCE',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: AppColors.accentGold,
                                        letterSpacing: 1.4,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      student.name,
                                      style: textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${student.studentId} · ${stats.total} classes',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      'Present and Late count as attended.',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
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
                        const SizedBox(height: AppSpacing.lg),
                        const SectionHeader(title: 'Subject-wise'),
                        const SizedBox(height: AppSpacing.sm),
                        if (enrolledSubjects.isEmpty)
                          Text(
                            'No subjects enrolled yet.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          )
                        else
                          Card(
                            child: Column(
                              children: [
                                for (
                                  var i = 0;
                                  i < enrolledSubjects.length;
                                  i++
                                ) ...[
                                  _SubjectRow(
                                    subject: enrolledSubjects[i],
                                    percentage: attendance.percentageForSubject(
                                      resolvedId!,
                                      enrolledSubjects[i].id,
                                    ),
                                    studentId: resolvedId,
                                  ),
                                  if (i != enrolledSubjects.length - 1)
                                    const Divider(height: 1),
                                ],
                              ],
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
                            subtitle: 'Attendance history will appear here.',
                            icon: Icons.history_rounded,
                          )
                        else
                          Card(
                            child: Column(
                              children: [
                                for (var i = 0; i < history.length; i++) ...[
                                  _HistoryRow(
                                    record: history[i],
                                    subjectName: subjects.nameFor(
                                      history[i].subjectId,
                                    ),
                                  ),
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

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.subject,
    required this.percentage,
    required this.studentId,
  });

  final Subject subject;
  final double percentage;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = AppColors.attendance(percentage);
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.avatarFor(subject.code),
        child: Text(
          subject.initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ),
      title: Text(
        subject.name,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subject.code, style: textTheme.bodySmall),
      trailing: Text(
        '${percentage.toStringAsFixed(0)}%',
        style: textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.studentSubjectDetails,
        arguments: {'studentId': studentId, 'subjectId': subject.id},
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record, required this.subjectName});

  final AttendanceRecord record;
  final String subjectName;

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
            Text(_shortMonth(record.date.month), style: textTheme.bodySmall),
          ],
        ),
      ),
      title: Text(
        subjectName,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${weekdayName(record.date)} · ${formatDate(record.date)}'
        '${record.remarks != null ? ' · ${record.remarks}' : ''}',
        style: textTheme.bodySmall,
      ),
      trailing: AttendanceStatusChip(mark: record.mark, compact: true),
    );
  }
}

String _shortMonth(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}
