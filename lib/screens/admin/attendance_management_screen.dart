import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/core/routes/app_routes.dart';
import 'package:edutrack/core/utils/responsive.dart';
import 'package:edutrack/models/student.dart';
import 'package:edutrack/providers/attendance_provider.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/repositories/attendance_repository.dart';
import 'package:edutrack/widgets/app_dropdown.dart';
import 'package:edutrack/widgets/app_shell.dart';
import 'package:edutrack/widgets/app_states.dart';
import 'package:edutrack/widgets/attendance_card.dart';
import 'package:edutrack/widgets/attendance_summary_card.dart';
import 'package:edutrack/widgets/custom_button.dart';
import 'package:edutrack/widgets/date_selector.dart';
import 'package:edutrack/widgets/empty_state.dart';
import 'package:edutrack/widgets/gradient_header.dart';
import 'package:edutrack/widgets/section_header.dart';

/// Daily attendance marking: pick a date, mark every student, save.
class AttendanceManagementScreen extends StatefulWidget {
  const AttendanceManagementScreen({super.key});

  @override
  State<AttendanceManagementScreen> createState() =>
      _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState
    extends State<AttendanceManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final students = context.read<StudentProvider>();
      if (students.students.isEmpty && !students.isLoading) {
        students.loadStudents();
      }
      final subjects = context.read<SubjectProvider>();
      subjects.ensureLoaded().then((_) {
        if (!mounted) return;
        final attendance = context.read<AttendanceProvider>();
        if (attendance.selectedSubjectId == null) {
          final list = context.read<SubjectProvider>().subjects;
          if (list.isNotEmpty) attendance.selectSubject(list.first.id);
        }
        subjects.preloadRosters();
      });
      context.read<AttendanceProvider>().ensureLoaded().then((_) {
        if (mounted) context.read<AttendanceProvider>().refreshPercentages();
      });
    });
  }

  void _shiftDay(int delta) {
    final provider = context.read<AttendanceProvider>();
    provider.selectDate(provider.selectedDate.add(Duration(days: delta)));
  }

  Future<void> _pickDate() async {
    final provider = context.read<AttendanceProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) provider.selectDate(picked);
  }

  Future<void> _save(List<String> enrolledIds) async {
    final provider = context.read<AttendanceProvider>();
    final error = await provider.saveDay(enrolledIds);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error ?? AppStrings.attendanceSaved),
          backgroundColor: error == null ? AppColors.success : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final students = context.watch<StudentProvider>();
    final subjects = context.watch<SubjectProvider>();
    final attendance = context.watch<AttendanceProvider>();

    final subjectId = attendance.selectedSubjectId;
    final enrolledIds = subjectId == null
        ? <String>[]
        : subjects.rosterFor(subjectId);
    final enrolled = enrolledIds
        .map(students.getById)
        .whereType<Student>()
        .toList();
    final summary = subjectId == null
        ? attendance.summaryForDate(attendance.selectedDate)
        : attendance.summaryForDateAndSubject(
            attendance.selectedDate,
            subjectId,
          );
    final unmarked = attendance.unmarkedCount(enrolledIds);
    final hasRecords = subjectId == null
        ? attendance.selectedDateHasRecords
        : attendance.hasRecordsForDateAndSubject(
            attendance.selectedDate,
            subjectId,
          );
    final hasChanges = attendance.hasUnsavedChanges(enrolledIds);

    return AppShell(
      title: 'Attendance',
      selectedIndex: 3,
      actions: [
        IconButton(
          tooltip: 'Attendance report',
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.attendanceReport),
          icon: const Icon(Icons.assessment_outlined),
        ),
      ],
      body: PageBody(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                        const GradientHeader(
                          accentLabel: 'Daily register',
                          title: 'Mark attendance',
                          subtitle:
                              'Select a date and subject, mark every student, then save.',
                          icon: Icons.fact_check_outlined,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const SectionHeader(
                          title: 'Date & subject',
                          icon: Icons.calendar_today_outlined,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DateSelector(
                          selectedDate: attendance.selectedDate,
                          onPrevious: () => _shiftDay(-1),
                          onNext: () => _shiftDay(1),
                          onPickDate: _pickDate,
                          nextEnabled: !isSameDay(
                            attendance.selectedDate,
                            normalizeDay(DateTime.now()),
                          ),
                        ),
                    const SizedBox(height: AppSpacing.md),
                    AppDropdown<String>(
                      label: AppStrings.selectSubject,
                      prefixIcon: Icons.menu_book_outlined,
                      value: subjectId,
                      items: [
                        for (final s in subjects.subjects) s.id,
                      ],
                      labelFor: (id) {
                        final s = subjects.getById(id);
                        return s == null ? id : '${s.code} · ${s.name}';
                      },
                      onChanged: (id) => context
                          .read<AttendanceProvider>()
                          .selectSubject(id),
                    ),
                        const SizedBox(height: AppSpacing.md),
                        if (attendance.isLoading && !attendance.isLoaded)
                          const LinearProgressIndicator()
                        else ...[
                          AttendanceSummaryCard(summary: summary),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  hasRecords
                                      ? 'Register for this date'
                                      : 'No attendance recorded',
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: attendance.isSaving
                                    ? null
                                    : () => context
                                          .read<AttendanceProvider>()
                                          .markAllPresent(enrolledIds),
                                icon: const Icon(
                                  Icons.done_all_rounded,
                                  size: 18,
                                ),
                                label: const Text('Mark all present'),
                              ),
                            ],
                          ),
                          if (!hasRecords && !hasChanges)
                            const SizedBox(height: AppSpacing.sm),
                          if (!hasRecords && !hasChanges)
                            Text(
                              "Attendance hasn't been marked for this date and subject yet.",
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                    if (attendance.errorMessage != null)
                      AppErrorState(
                        message: attendance.errorMessage!,
                        onRetry: () => context
                            .read<AttendanceProvider>()
                            .loadAttendance(),
                      ),
                        if (subjectId == null)
                          const EmptyState(
                            title: AppStrings.selectSubject,
                            subtitle:
                                'Choose a subject above to load its register.',
                            icon: Icons.menu_book_outlined,
                          )
                        else if (students.isLoading &&
                            students.students.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(AppSpacing.xl),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (enrolled.isEmpty)
                          EmptyState(
                            title: AppStrings.noEnrolledStudents,
                            subtitle:
                                'Enroll students from the subject details page.',
                            icon: Icons.people_outline_rounded,
                            actionLabel: AppStrings.manageStudents,
                            onAction: () => Navigator.of(context)
                                .pushNamed(
                                  AppRoutes.manageEnrollment,
                                  arguments: subjectId,
                                )
                                .then((_) {
                                  if (context.mounted) {
                                    context.read<SubjectProvider>().loadRoster(
                                      subjectId,
                                    );
                                  }
                                }),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: enrolled.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.md),
                            itemBuilder: (context, index) {
                              final student = enrolled[index];
                              return AttendanceCard(
                                student: student,
                                selected: attendance.draftFor(student.id),
                                onSelect: (mark) => context
                                    .read<AttendanceProvider>()
                                    .setMark(student.id, mark),
                              );
                            },
                          ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
                if (enrolled.isNotEmpty)
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      AppSpacing.md,
                      AppSpacing.screenPadding,
                      AppSpacing.screenPadding,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (attendance.saveError != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Text(
                              attendance.saveError!,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (unmarked > 0)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Text(
                              '$unmarked student${unmarked == 1 ? '' : 's'} still unmarked',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        CustomButton(
                          text: hasChanges || !hasRecords
                              ? AppStrings.saveAttendance
                              : 'Attendance up to date',
                          isLoading: attendance.isSaving,
                          onPressed: attendance.isSaving
                              ? null
                              : () => _save(enrolledIds),
                          icon: Icons.save_outlined,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
  }
}

