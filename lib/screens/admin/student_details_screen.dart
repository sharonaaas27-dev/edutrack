import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/core/routes/app_routes.dart';
import 'package:edutrack/core/utils/date_format.dart';
import 'package:edutrack/core/utils/format.dart';
import 'package:edutrack/models/student.dart';
import 'package:edutrack/providers/attendance_provider.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/widgets/app_avatar.dart';
import 'package:edutrack/widgets/app_dialog.dart';
import 'package:edutrack/widgets/attendance_ring.dart';
import 'package:edutrack/widgets/empty_state.dart';
import 'package:edutrack/widgets/section_header.dart';

/// Full student profile resolved by ID through the provider.
class StudentDetailsScreen extends StatefulWidget {
  const StudentDetailsScreen({super.key, required this.studentId});

  final String studentId;

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubjectProvider>().ensureLoaded();
      context.read<AttendanceProvider>().ensureLoaded().then((_) {
        if (mounted) context.read<AttendanceProvider>().refreshPercentages();
      });
    });
  }

  Future<void> _confirmDelete(BuildContext context, Student student) async {
    final confirmed = await showConfirmDialog(
      context,
      title: AppStrings.deleteStudent,
      message: 'Are you sure you want to delete ${student.name}?',
    );

    if (!confirmed || !context.mounted) return;
    final error = await context.read<StudentProvider>().deleteStudent(
      student.id,
    );
    if (!context.mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.studentDeleted)),
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
    final student = context.watch<StudentProvider>().getById(widget.studentId);
    final attendance = context.watch<AttendanceProvider>();
    final stats = attendance.statsFor(widget.studentId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Details'),
        actions: [
          if (student != null)
            IconButton(
              tooltip: AppStrings.editStudent,
              onPressed: () => Navigator.of(
                context,
              ).pushNamed(AppRoutes.editStudent, arguments: student.id),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (student != null)
            IconButton(
              tooltip: AppStrings.delete,
              onPressed: () => _confirmDelete(context, student),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: student == null
            ? const EmptyState(
                title: 'Student not found',
                subtitle:
                    'This record may have been deleted. Go back and try again.',
                icon: Icons.person_off_outlined,
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProfileBanner(student: student),
                        const SizedBox(height: AppSpacing.lg),
                        _InfoSection(
                          eyebrow: AppStrings.personalInfo,
                          icon: Icons.badge_outlined,
                          rows: [
                            _Row(
                              icon: Icons.mail_outline_rounded,
                              label: 'Email',
                              value: student.email,
                            ),
                            _Row(
                              icon: Icons.phone_outlined,
                              label: 'Phone',
                              value: student.phone.isEmpty
                                  ? '—'
                                  : student.phone,
                            ),
                            _Row(
                              icon: Icons.cake_outlined,
                              label: 'Date of birth',
                              value: formatDate(student.dateOfBirth),
                            ),
                            _Row(
                              icon: Icons.home_outlined,
                              label: 'Address',
                              value: student.address.isEmpty
                                  ? '—'
                                  : student.address,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _InfoSection(
                          eyebrow: AppStrings.academicInfo,
                          icon: Icons.school_outlined,
                          rows: [
                            _Row(
                              icon: Icons.numbers_rounded,
                              label: 'Student ID',
                              value: student.studentId,
                            ),
                            _Row(
                              icon: Icons.menu_book_outlined,
                              label: 'Course',
                              value: student.course,
                            ),
                            _Row(
                              icon: Icons.calendar_month_outlined,
                              label: 'Year',
                              value: student.year,
                            ),
                            _Row(
                              icon: Icons.group_outlined,
                              label: 'Section',
                              value: 'Section ${student.section}',
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
                                    AttendanceRing(
                                      percentage: stats.total == 0
                                          ? student.attendancePercentage
                                          : stats.percentage,
                                    ),
                                    const SizedBox(width: AppSpacing.xl),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SectionHeader(
                                            title: AppStrings.attendanceTitle,
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                          Text(
                                            student.attendanceStatus.label,
                                            style: textTheme.titleLarge
                                                ?.copyWith(
                                                  color: AppColors.attendance(
                                                    student
                                                        .attendancePercentage,
                                                  ),
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                          Text(
                                            stats.total == 0
                                                ? 'No attendance records yet.'
                                                : 'Present ${stats.present} · Absent ${stats.absent} · Late ${stats.late} · Total ${stats.total}',
                                            style: textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      Navigator.of(context).pushNamed(
                                        AppRoutes.studentAttendance,
                                        arguments: student.id,
                                      ),
                                  icon: const Icon(Icons.history_rounded),
                                  label: const Text(AppStrings.viewHistory),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _SubjectAttendanceSection(
                          textTheme: textTheme,
                          studentId: student.id,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    Navigator.of(context).pushNamed(
                                      AppRoutes.editStudent,
                                      arguments: student.id,
                                    ),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text(AppStrings.editStudent),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                ),
                                onPressed: () =>
                                    _confirmDelete(context, student),
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
              ),
      ),
    );
  }
}

/// Per-subject attendance for one student, resolved from the roster.
class _SubjectAttendanceSection extends StatefulWidget {
  const _SubjectAttendanceSection({
    required this.textTheme,
    required this.studentId,
  });

  final TextTheme textTheme;
  final String studentId;

  @override
  State<_SubjectAttendanceSection> createState() =>
      _SubjectAttendanceSectionState();
}

class _SubjectAttendanceSectionState extends State<_SubjectAttendanceSection> {
  late final Future<List<String>> _subjectIds;

  @override
  void initState() {
    super.initState();
    _subjectIds = context.read<SubjectProvider>().studentSubjectIds(
      widget.studentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = widget.textTheme;
    final studentId = widget.studentId;
    final subjects = context.watch<SubjectProvider>();
    final attendance = context.watch<AttendanceProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Subject attendance',
              icon: Icons.menu_book_outlined,
            ),
            const Divider(height: AppSpacing.xl),
            FutureBuilder<List<String>>(
              future: _subjectIds,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }
                final mine = subjects.subjectsForStudent(
                  studentId,
                  snapshot.data!,
                );
                if (mine.isEmpty) {
                  return Text(
                    'Not enrolled in any subject yet.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  );
                }
                return Column(
                  children: mine.map((s) {
                    final pct = attendance.percentageForSubject(
                      studentId,
                      s.id,
                    );
                    final color = AppColors.attendance(pct);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: AppAvatar(name: s.name, radius: 20),
                      title: Text(
                        s.name,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(s.code, style: textTheme.bodySmall),
                      trailing: Text(
                        formatPercentage(pct),
                        style: textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.subjectDetails, arguments: s.id),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final avatarColor = AppColors.avatarFor(student.name);
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
            tag: 'student-avatar-${student.id}',
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 32,
                backgroundColor: avatarColor,
                child: Text(
                  student.initials,
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
                Text(
                  student.name,
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${student.studentId} · ${student.course}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    '${student.year} • Section ${student.section}',
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
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
  final List<_Row> rows;

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
