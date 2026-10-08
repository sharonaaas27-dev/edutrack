import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/core/routes/app_routes.dart';
import 'package:edutrack/core/utils/format.dart';
import 'package:edutrack/models/subject.dart';
import 'package:edutrack/providers/attendance_provider.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/widgets/app_avatar.dart';
import 'package:edutrack/widgets/app_dialog.dart';
import 'package:edutrack/widgets/attendance_ring.dart';
import 'package:edutrack/widgets/empty_state.dart';
import 'package:edutrack/widgets/section_header.dart';

/// Full subject profile: info sections, live statistics, enrolled
/// students, enrollment management, edit, and delete.
class SubjectDetailsScreen extends StatefulWidget {
  const SubjectDetailsScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  State<SubjectDetailsScreen> createState() => _SubjectDetailsScreenState();
}

class _SubjectDetailsScreenState extends State<SubjectDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final students = context.read<StudentProvider>();
      if (students.students.isEmpty && !students.isLoading) {
        students.loadStudents();
      }
      context.read<SubjectProvider>().ensureLoaded().then((_) {
        if (mounted) {
          context.read<SubjectProvider>().loadRoster(widget.subjectId);
        }
      });
      context.read<AttendanceProvider>().ensureLoaded();
    });
  }

  Future<void> _confirmDelete(BuildContext context, Subject subject) async {
    final confirmed = await showConfirmDialog(
      context,
      title: AppStrings.deleteSubject,
      message: 'Are you sure you want to delete ${subject.name}?',
    );

    if (!confirmed || !context.mounted) return;
    final error = await context.read<SubjectProvider>().deleteSubject(
      subject.id,
    );
    if (!context.mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.subjectDeleted)),
        );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subject = context.watch<SubjectProvider>().getById(widget.subjectId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subject Details'),
        actions: [
          if (subject != null)
            IconButton(
              tooltip: AppStrings.editSubject,
              onPressed: () => Navigator.of(
                context,
              ).pushNamed(AppRoutes.editSubject, arguments: subject.id),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (subject != null)
            IconButton(
              tooltip: AppStrings.delete,
              onPressed: () => _confirmDelete(context, subject),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: subject == null
            ? const EmptyState(
                title: 'Subject not found',
                subtitle:
                    'This record may have been deleted. Go back and try again.',
                icon: Icons.menu_book_outlined,
              )
            : _DetailsBody(
                subject: subject,
                textTheme: textTheme,
                onDelete: () => _confirmDelete(context, subject),
              ),
      ),
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({
    required this.subject,
    required this.textTheme,
    required this.onDelete,
  });

  final Subject subject;
  final TextTheme textTheme;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final students = context.watch<StudentProvider>();
    final subjects = context.watch<SubjectProvider>();
    final attendance = context.watch<AttendanceProvider>();

    final roster = subjects.rosterFor(subject.id);
    final summary = attendance.subjectSummary(subject.id);
    final average = summary.attendanceRate;
    final lowIds = attendance.lowAttendanceForSubject(subject.id, roster);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SubjectBanner(subject: subject),
              const SizedBox(height: AppSpacing.lg),
              _InfoSection(
                eyebrow: 'Subject information',
                icon: Icons.info_outline_rounded,
                rows: [
                  _Row(
                    icon: Icons.tag_rounded,
                    label: 'Code',
                    value: subject.code,
                  ),
                  _Row(
                    icon: Icons.menu_book_outlined,
                    label: 'Name',
                    value: subject.name,
                  ),
                  _Row(
                    icon: Icons.description_outlined,
                    label: 'Description',
                    value: subject.description.isEmpty
                        ? '—'
                        : subject.description,
                  ),
                  _Row(
                    icon: Icons.star_outline_rounded,
                    label: 'Credits',
                    value: '${subject.credits}',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _InfoSection(
                eyebrow: AppStrings.academicInfo,
                icon: Icons.school_outlined,
                rows: [
                  _Row(
                    icon: Icons.school_outlined,
                    label: 'Course',
                    value: subject.course,
                  ),
                  _Row(
                    icon: Icons.calendar_month_outlined,
                    label: 'Year',
                    value: subject.year,
                  ),
                  _Row(
                    icon: Icons.layers_outlined,
                    label: 'Semester',
                    value: subject.semester,
                  ),
                  _Row(
                    icon: Icons.group_outlined,
                    label: 'Section',
                    value: 'Section ${subject.section}',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _InfoSection(
                eyebrow: 'Faculty',
                icon: Icons.person_outline_rounded,
                rows: [
                  _Row(
                    icon: Icons.badge_outlined,
                    label: 'Teacher',
                    value: subject.teacherName,
                  ),
                  _Row(
                    icon: Icons.meeting_room_outlined,
                    label: 'Room',
                    value: subject.room.isEmpty ? '—' : subject.room,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _InfoSection(
                eyebrow: 'Schedule',
                icon: Icons.schedule_outlined,
                rows: [
                  if (subject.schedule.isEmpty)
                    const _Row(
                      icon: Icons.event_busy_outlined,
                      label: 'Slots',
                      value: 'No class slots defined yet.',
                    )
                  else
                    for (final slot in subject.schedule)
                      _Row(
                        icon: Icons.access_time_rounded,
                        label: slot.day,
                        value: '${slot.startTime} – ${slot.endTime}',
                      ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          AttendanceRing(percentage: average),
                          const SizedBox(width: AppSpacing.xl),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'STATISTICS',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: AppColors.primary,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '${roster.length} enrolled',
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  summary.total == 0
                                      ? 'No attendance recorded for this subject.'
                                      : 'Present ${summary.present} · Absent ${summary.absent} · Late ${summary.late} · ${lowIds.length} low',
                                  style: textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pushNamed(
                          AppRoutes.attendanceReport,
                          arguments: subject.id,
                        ),
                        icon: const Icon(Icons.assessment_outlined),
                        label: const Text('View subject report'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'STUDENTS · ${roster.length}',
                              style: textTheme.labelSmall?.copyWith(
                                color: AppColors.primary,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.of(context)
                                .pushNamed(
                                  AppRoutes.manageEnrollment,
                                  arguments: subject.id,
                                )
                                .then((_) {
                                  if (context.mounted) {
                                    context.read<SubjectProvider>().loadRoster(
                                      subject.id,
                                    );
                                  }
                                }),
                            icon: const Icon(
                              Icons.group_add_outlined,
                              size: 18,
                            ),
                            label: const Text(AppStrings.manageStudents),
                          ),
                        ],
                      ),
                      const Divider(height: AppSpacing.xl),
                      if (roster.isEmpty)
                        Text(
                          AppStrings.noEnrolledStudents,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        )
                      else
                        ...roster.map((id) {
                          final s = students.getById(id);
                          if (s == null) return const SizedBox.shrink();
                          final pct = attendance.percentageForSubject(
                            id,
                            subject.id,
                          );
                          final color = AppColors.attendance(pct);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading:
                                AppAvatar(name: s.name, radius: 20),
                            title: Text(
                              s.name,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${s.studentId} · ${formatPercentage(pct)}',
                              style: textTheme.bodySmall,
                            ),
                            trailing: Icon(
                              Icons.circle,
                              size: 10,
                              color: color,
                            ),
                            onTap: () => Navigator.of(context).pushNamed(
                              AppRoutes.studentDetails,
                              arguments: s.id,
                            ),
                          );
                        }),
                      if (lowIds.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.errorBackground,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                          child: Text(
                            'Low attendance (< 75%): ${lowIds.length} student${lowIds.length == 1 ? '' : 's'}',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.editSubject, arguments: subject.id),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text(AppStrings.editSubject),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text(AppStrings.delete),
                    ),
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

class _SubjectBanner extends StatelessWidget {
  const _SubjectBanner({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final avatarColor = AppColors.avatarFor(subject.code);
    return Container(
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
          Hero(
            tag: 'subject-avatar-${subject.id}',
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 32,
                backgroundColor: avatarColor,
                child: Text(
                  subject.initials,
                  style: textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: subject.isActive
                        ? AppColors.success
                        : Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    subject.isActive ? 'ACTIVE' : 'INACTIVE',
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
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
                const SizedBox(height: 2),
                Text(
                  '${subject.code} · ${subject.teacherName}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${subject.academicLabel} · ${subject.credits} Credits',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.eyebrow,
    required this.icon,
    required this.rows,
  });

  final String eyebrow;
  final IconData icon;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: eyebrow, icon: icon),
            const Divider(height: AppSpacing.xl),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, size: 18, color: AppColors.secondaryLight),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
