import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/core/routes/app_routes.dart';
import 'package:edutrack/core/utils/format.dart';
import 'package:edutrack/core/utils/responsive.dart';
import 'package:edutrack/providers/attendance_provider.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/widgets/app_avatar.dart';
import 'package:edutrack/widgets/app_shell.dart';
import 'package:edutrack/widgets/app_states.dart';
import 'package:edutrack/widgets/empty_state.dart';

/// Student-facing "My Subjects" list with per-subject attendance.
class StudentSubjectsScreen extends StatefulWidget {
  const StudentSubjectsScreen({super.key, this.studentId});

  /// Resolved to the logged-in student by the backend in a later stage.
  final String? studentId;

  @override
  State<StudentSubjectsScreen> createState() => _StudentSubjectsScreenState();
}

class _StudentSubjectsScreenState extends State<StudentSubjectsScreen> {
  String? _cachedFor;
  Future<List<String>>? _cachedFuture;

  /// Cached so provider rebuilds don't refire the roster query.
  Future<List<String>> _subjectIds(String studentId) {
    if (_cachedFor != studentId || _cachedFuture == null) {
      _cachedFor = studentId;
      _cachedFuture = context.read<SubjectProvider>().studentSubjectIds(
        studentId,
      );
    }
    return _cachedFuture!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final students = context.read<StudentProvider>();
      if (students.students.isEmpty && !students.isLoading) {
        students.loadStudents();
      }
      context.read<SubjectProvider>().ensureLoaded();
      context.read<AttendanceProvider>().ensureLoaded();
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

    return AppShell(
      title: AppStrings.mySubjects,
      selectedIndex: 1,
      body: PageBody(
        child:
            (students.isLoading && students.students.isEmpty) ||
                (subjects.isLoading && !subjects.isLoaded)
            ? const AppLoadingSkeleton(itemCount: 4, itemHeight: 96)
            : resolvedId == null
            ? const EmptyState(
                title: 'No subjects found',
                subtitle: 'Student records are still loading.',
                icon: Icons.menu_book_outlined,
              )
            : FutureBuilder<List<String>>(
                future: _subjectIds(resolvedId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return AppErrorState(
                      message: 'Unable to load enrollments. Please try again.',
                      onRetry: () => setState(() {
                        _cachedFor = null;
                        _cachedFuture = null;
                      }),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const AppLoadingSkeleton(
                        itemCount: 4, itemHeight: 96);
                  }
                  final mine = subjects.subjectsForStudent(
                    resolvedId,
                    snapshot.data!,
                  );
                  if (mine.isEmpty) {
                    return const EmptyState(
                      title: AppStrings.noEnrolledSubjects,
                      subtitle:
                          'Subjects you enroll in will appear here.',
                      icon: Icons.menu_book_outlined,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${mine.length} enrolled',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(
                        child: ListView.separated(
                          itemCount: mine.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, index) {
                            final subject = mine[index];
                            final pct = attendance.percentageForSubject(
                              resolvedId,
                              subject.id,
                            );
                            final color = AppColors.attendance(pct);
                            return Card(
                              child: InkWell(
                                onTap: () =>
                                    Navigator.of(context).pushNamed(
                                      AppRoutes.studentSubjectDetails,
                                      arguments: {
                                        'studentId': resolvedId,
                                        'subjectId': subject.id,
                                      },
                                    ),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusLg,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    AppSpacing.lg,
                                  ),
                                  child: Row(
                                    children: [
                                      AppAvatar(
                                        name: subject.name,
                                        radius: 24,
                                      ),
                                      const SizedBox(width: AppSpacing.lg),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              subject.name,
                                              style: textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${subject.code} · ${subject.teacherName}',
                                              style: textTheme.bodySmall,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${subject.academicLabel} · ${subject.credits} Credits',
                                              style: textTheme.bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        AppColors.textHint,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            formatPercentage(pct),
                                            style: textTheme.titleMedium
                                                ?.copyWith(
                                                  color: color,
                                                  fontWeight:
                                                      FontWeight.w800,
                                                ),
                                          ),
                                          Text(
                                            'Attendance',
                                            style: textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.textHint,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
