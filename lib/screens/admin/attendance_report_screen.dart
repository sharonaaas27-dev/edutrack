import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/models/attendance.dart';
import 'package:edutrack/models/student.dart';
import 'package:edutrack/models/subject.dart';
import 'package:edutrack/core/utils/format.dart';
import 'package:edutrack/providers/attendance_provider.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/widgets/app_avatar.dart';
import 'package:edutrack/widgets/app_dropdown.dart';
import 'package:edutrack/widgets/app_search_field.dart';
import 'package:edutrack/widgets/attendance_bar_chart.dart';
import 'package:edutrack/widgets/attendance_ring.dart';
import 'package:edutrack/widgets/attendance_status_chip.dart';
import 'package:edutrack/widgets/empty_state.dart';
import 'package:edutrack/widgets/gradient_header.dart';
import 'package:edutrack/widgets/section_header.dart';

/// Overall statistics, low/high attendance lists, and filtered per-student
/// table. All values are computed live from attendance records.
class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key, this.initialSubjectId});

  /// Preselects the subject filter (e.g. from subject details).
  final String? initialSubjectId;

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  String _query = '';
  String _course = 'All';
  String _section = 'All';
  AttendanceMark? _status;
  String? _subjectId;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.initialSubjectId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final students = context.read<StudentProvider>();
      if (students.students.isEmpty && !students.isLoading) {
        students.loadStudents();
      }
      context.read<SubjectProvider>().ensureLoaded();
      context.read<AttendanceProvider>().ensureLoaded();
    });
  }

  List<Student> _filtered(
    List<Student> students,
    AttendanceProvider attendance,
  ) {
    final q = _query.trim().toLowerCase();
    return students.where((s) {
      if (_course != 'All' && s.course != _course) return false;
      if (_section != 'All' && s.section != _section) return false;
      if (q.isNotEmpty &&
          !s.name.toLowerCase().contains(q) &&
          !s.studentId.toLowerCase().contains(q)) {
        return false;
      }
      if (_status != null) {
        final history = _subjectId == null
            ? attendance.historyFor(s.id)
            : attendance.historyForSubject(s.id, _subjectId!);
        if (history.isEmpty || history.first.mark != _status) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final students = context.watch<StudentProvider>();
    final subjects = context.watch<SubjectProvider>();
    final attendance = context.watch<AttendanceProvider>();
    final overall = attendance.overallSummary;
    final lowIds = attendance.lowAttendanceStudentIds.toSet();
    final top = attendance.topAttendees(limit: 3);
    final rows = _filtered(students.students, attendance);

    final selectedSubject = _subjectId == null
        ? null
        : subjects.getById(_subjectId!);
    final subjectSummary = _subjectId == null
        ? null
        : attendance.subjectSummary(_subjectId!);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Report')),
      body: SafeArea(
        child: attendance.isLoading && !attendance.isLoaded
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GradientHeader(
                          accentLabel: 'Insights',
                          title:
                              '${overall.attendanceRate.toStringAsFixed(1)}% overall',
                          subtitle:
                              '${overall.present + overall.late} attended of ${overall.total} records · '
                              '${overall.presentRate.toStringAsFixed(1)}% present · '
                              '${overall.absentRate.toStringAsFixed(1)}% absent · '
                              '${overall.lateRate.toStringAsFixed(1)}% late',
                          icon: Icons.insights_outlined,
                          trailing: AttendanceRing(
                            percentage: overall.attendanceRate,
                            size: 64,
                            strokeWidth: 7,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SectionHeader(
                          icon: Icons.emoji_events_outlined,
                          title: 'Highest attendance',
                          color: AppColors.accentGold,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (top.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.lg),
                              child: Text('No attendance records yet.'),
                            ),
                          )
                        else
                          ...top.map((stats) {
                            final student = students.getById(stats.studentId);
                            if (student == null) return const SizedBox.shrink();
                            return _TopRow(
                              student: student,
                              stats: stats,
                              rank: top.indexOf(stats) + 1,
                            );
                          }),
                        const SizedBox(height: AppSpacing.lg),
                        SectionHeader(
                          icon: Icons.warning_amber_outlined,
                          title: 'Low attendance (< 75%) · ${lowIds.length}',
                          color: AppColors.error,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (lowIds.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.celebration_outlined,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      'No students below 75%. Excellent!',
                                      style: textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...lowIds.map((id) {
                            final student = students.getById(id);
                            if (student == null) return const SizedBox.shrink();
                            final stats = attendance.statsFor(id);
                            return _LowRow(student: student, stats: stats);
                          }),
                        const SizedBox(height: AppSpacing.lg),
                        SectionHeader(
                          icon: Icons.menu_book_outlined,
                          title: 'Subject report',
                          color: AppColors.accentViolet,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _SubjectFilter(
                          subjects: subjects.subjects,
                          selectedId: _subjectId,
                          onChanged: (v) => setState(() => _subjectId = v),
                        ),
                        if (selectedSubject != null &&
                            subjectSummary != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _SubjectReportCard(
                            subjectName:
                                '${selectedSubject.code} · ${selectedSubject.name}',
                            summary: subjectSummary,
                            lowCount: attendance
                                .lowAttendanceForSubject(_subjectId!)
                                .length,
                            studentCount: attendance
                                .subjectStudentIds(_subjectId!)
                                .length,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        SectionHeader(
                          icon: Icons.table_chart_outlined,
                          title: _subjectId == null
                              ? 'All students'
                              : 'Students · ${selectedSubject?.code ?? ''}',
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _ReportFilters(
                          query: _query,
                          course: _course,
                          section: _section,
                          status: _status,
                          courses: students.availableCourses,
                          sections: students.availableSections,
                          onQuery: (v) => setState(() => _query = v),
                          onCourse: (v) => setState(() => _course = v ?? 'All'),
                          onSection: (v) =>
                              setState(() => _section = v ?? 'All'),
                          onStatus: (v) => setState(() => _status = v),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (rows.isEmpty)
                          const EmptyState(
                            title: 'No matching records',
                            subtitle: 'Try changing your search or filters.',
                            icon: Icons.search_off_rounded,
                          )
                        else
                          Card(
                            child: Column(
                              children: [
                                for (var i = 0; i < rows.length; i++) ...[
                                  _StudentRow(
                                    student: rows[i],
                                    stats: _subjectId == null
                                        ? attendance.statsFor(rows[i].id)
                                        : attendance.statsForSubject(
                                            rows[i].id,
                                            _subjectId!,
                                          ),
                                    latest: _subjectId == null
                                        ? attendance
                                              .historyFor(rows[i].id)
                                              .firstOrNull
                                              ?.mark
                                        : attendance
                                              .historyForSubject(
                                                rows[i].id,
                                                _subjectId!,
                                              )
                                              .firstOrNull
                                              ?.mark,
                                  ),
                                  if (i != rows.length - 1)
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

class _SubjectFilter extends StatelessWidget {
  const _SubjectFilter({
    required this.subjects,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Subject> subjects;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = subjects.any((s) => s.id == selectedId)
        ? selectedId
        : null;
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      // Required: constrains the button to the available width.
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: AppStrings.selectSubject,
        prefixIcon: Icon(Icons.menu_book_outlined),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text(AppStrings.allSubjects),
        ),
        for (final s in subjects)
          DropdownMenuItem<String>(
            value: s.id,
            child: Text(
              '${s.code} · ${s.name}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _SubjectReportCard extends StatelessWidget {
  const _SubjectReportCard({
    required this.subjectName,
    required this.summary,
    required this.lowCount,
    required this.studentCount,
  });

  final String subjectName;
  final AttendanceSummary summary;
  final int lowCount;
  final int studentCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subjectName,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Total Students: $studentCount · '
              'Average Attendance: ${formatPercentage(summary.attendanceRate)}',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
                    AttendanceBarChart(
                      height: 120,
                      segments: [
                        BarSegment(
                          label: 'Present',
                          percentage: summary.presentRate,
                          color: AppColors.success,
                        ),
                        BarSegment(
                          label: 'Late',
                          percentage: summary.lateRate,
                          color: AppColors.warning,
                        ),
                        BarSegment(
                          label: 'Absent',
                          percentage: summary.absentRate,
                          color: AppColors.error,
                        ),
                      ],
                    ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Low Attendance: $lowCount',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.student,
    required this.stats,
    required this.rank,
  });

  final Student student;
  final StudentAttendanceStats stats;
  final int rank;

  @override
  Widget build(BuildContext context) {
    const medals = ['🥇', '🥈', '🥉'];
    return Card(
      child: ListTile(
        leading: AppAvatar(name: student.name, radius: 22),
        title: Text(
          '${medals[rank - 1]} ${student.name}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${student.studentId} · ${stats.total} classes',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Text(
          '${stats.percentage.toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _LowRow extends StatelessWidget {
  const _LowRow({required this.student, required this.stats});

  final Student student;
  final StudentAttendanceStats stats;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: ListTile(
        leading: AppAvatar(name: student.name, radius: 22),
        title: Text(
          student.name,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${student.studentId} · Present ${stats.present} · Absent ${stats.absent} · Late ${stats.late}',
          style: textTheme.bodySmall,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.errorBackground,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(
            '${stats.percentage.toStringAsFixed(1)}%',
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportFilters extends StatelessWidget {
  const _ReportFilters({
    required this.query,
    required this.course,
    required this.section,
    required this.status,
    required this.courses,
    required this.sections,
    required this.onQuery,
    required this.onCourse,
    required this.onSection,
    required this.onStatus,
  });

  final String query;
  final String course;
  final String section;
  final AttendanceMark? status;
  final List<String> courses;
  final List<String> sections;
  final ValueChanged<String> onQuery;
  final ValueChanged<String?> onCourse;
  final ValueChanged<String?> onSection;
  final ValueChanged<AttendanceMark?> onStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppSearchField(
          hintText: 'Search student…',
          onChanged: onQuery,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppDropdown<String>(
                label: 'Course',
                value: course,
                items: courses,
                onChanged: onCourse,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppDropdown<String>(
                label: 'Section',
                value: section,
                items: sections,
                onChanged: onSection,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All statuses'),
                selected: status == null,
                onSelected: (_) => onStatus(null),
              ),
              const SizedBox(width: AppSpacing.sm),
              for (final mark in AttendanceMark.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text('Latest: ${mark.label}'),
                    selected: status == mark,
                    onSelected: (_) => onStatus(status == mark ? null : mark),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.stats,
    required this.latest,
  });

  final Student student;
  final StudentAttendanceStats stats;
  final AttendanceMark? latest;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = AppColors.attendance(stats.percentage);
    final latestMark = latest;
    return ListTile(
      dense: true,
      leading: AppAvatar(name: student.name, radius: 18),
      title: Text(student.name, style: textTheme.bodyMedium),
      subtitle: Text(
        '${stats.present}P · ${stats.absent}A · ${stats.late}L of ${stats.total}',
        style: textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (latestMark != null)
            AttendanceStatusChip(mark: latestMark, compact: true),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${stats.percentage.toStringAsFixed(0)}%',
            style: textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

