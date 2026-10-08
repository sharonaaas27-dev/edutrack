import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/core/routes/app_routes.dart';
import 'package:edutrack/core/utils/date_format.dart';
import 'package:edutrack/core/utils/format.dart';
import 'package:edutrack/core/utils/responsive.dart';
import 'package:edutrack/models/dashboard.dart';
import 'package:edutrack/models/user.dart';
import 'package:edutrack/providers/attendance_provider.dart';
import 'package:edutrack/providers/auth_provider.dart';
import 'package:edutrack/providers/dashboard_provider.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/widgets/app_avatar.dart';
import 'package:edutrack/widgets/app_cards.dart';
import 'package:edutrack/widgets/app_shell.dart';
import 'package:edutrack/widgets/app_states.dart';
import 'package:edutrack/widgets/attendance_bar_chart.dart';
import 'package:edutrack/widgets/attendance_ring.dart';
import 'package:edutrack/widgets/empty_state.dart';
import 'package:edutrack/widgets/low_attendance_banner.dart';
import 'package:edutrack/widgets/section_header.dart';
import 'package:edutrack/widgets/user_badge.dart';

/// Student landing page: greeting, today's overview, subjects with live
/// per-subject attendance, warnings, and recent history. Everything comes
/// from the dashboard payload — no fabricated statistics.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final students = context.read<StudentProvider>();
    if (students.students.isEmpty && !students.isLoading) {
      await students.loadStudents();
    }
    if (!mounted) return;
    await context.read<SubjectProvider>().ensureLoaded();
    if (!mounted) return;
    await context.read<SubjectProvider>().preloadRosters();
    if (!mounted) return;
    await context.read<AttendanceProvider>().ensureLoaded();
    if (!mounted) return;
    final studentId = context.read<AuthProvider>().currentUser?.studentId;
    if (studentId != null && mounted) {
      await context.read<DashboardProvider>().loadStudent(studentId);
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dashboard = context.watch<DashboardProvider>();
    final data = dashboard.student;
    final studentId = auth.currentUser?.studentId;

    return AppShell(
      title: AppStrings.dashboardTitle,
      selectedIndex: 0,
      actions: [
        IconButton(
          tooltip: AppStrings.logout,
          onPressed: () => auth.logout(),
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
      body: PageBody(
        child: RefreshIndicator(
          onRefresh: () async {
            if (studentId != null) {
              await context
                  .read<DashboardProvider>()
                  .loadStudent(studentId, force: true);
            }
          },
          child: _buildState(context, dashboard, data, studentId),
        ),
      ),
    );
  }

  Widget _buildState(
    BuildContext context,
    DashboardProvider dashboard,
    StudentDashboardData? data,
    String? studentId,
  ) {
    if (dashboard.isLoading && data == null) {
      return const AppLoadingSkeleton(itemCount: 4, itemHeight: 130);
    }
    if (dashboard.errorMessage != null && data == null) {
      return AppErrorState(
        message: dashboard.errorMessage!,
        onRetry: () {
          if (studentId != null) {
            context.read<DashboardProvider>().loadStudent(studentId);
          }
        },
      );
    }
    if (data == null) {
      return const EmptyState(
        title: 'No dashboard data',
        subtitle: 'Your account is not linked to a student record yet.',
        icon: Icons.person_outline_rounded,
      );
    }
    return _content(context, data, studentId!);
  }

  Widget _content(
    BuildContext context,
    StudentDashboardData data,
    String studentId,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthProvider>();
    final subjects = context.watch<SubjectProvider>();
    final displayName = UserBadge.nameFor(auth.currentUser, data.name);
    final todayName = weekdayName(DateTime.now());
    final classesToday = data.subjects.where((s) {
      final subject = subjects.getById(s.subjectId);
      return subject != null &&
          subject.schedule.any((slot) => slot.day == todayName);
    }).toList();
    final columns =
        responsiveValue<int>(context, mobile: 2, tablet: 3, desktop: 4);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_greeting()}, $displayName',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${formatDate(DateTime.now())} · ${data.course}',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          UserBadge(
            displayName: displayName,
            role: auth.role ?? UserRole.student,
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: "Today's overview"),
          const SizedBox(height: AppSpacing.sm),
          StatGrid(
            columns: columns,
            children: [
              AppStatCard(
                title: AppStrings.attendance,
                value: formatPercentage(data.overall.percentage),
                subtitle:
                    '${data.overall.present + data.overall.late} of ${data.overall.total} classes',
                icon: Icons.fact_check_outlined,
                color: AppColors.attendance(data.overall.percentage),
                animateValue: false,
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.studentAttendance,
                  arguments: studentId,
                ),
              ),
              AppStatCard(
                title: AppStrings.subjects,
                value: formatCount(data.subjects.length),
                subtitle: 'Enrolled',
                icon: Icons.menu_book_outlined,
                color: AppColors.info,
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.studentSubjects,
                  arguments: studentId,
                ),
              ),
              AppStatCard(
                title: 'Classes today',
                value: formatCount(classesToday.length),
                subtitle: classesToday.isEmpty
                    ? 'No classes scheduled'
                    : classesToday.map((s) => s.code).take(2).join(', '),
                icon: Icons.calendar_today_outlined,
                color: AppColors.primary,
              ),
              AppStatCard(
                title: 'Low subjects',
                value: formatCount(data.lowSubjects.length),
                subtitle: data.lowSubjects.isEmpty
                    ? 'All above 75%'
                    : 'Below 75%',
                icon: Icons.warning_amber_outlined,
                color: data.lowSubjects.isEmpty
                    ? AppColors.success
                    : AppColors.error,
              ),
            ],
          ),
          if (data.lowSubjects.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final low in data.lowSubjects)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: LowAttendanceBanner(
                  subjectName: low.name,
                  percentage: low.stats.percentage,
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.studentSubjectDetails,
                    arguments: {
                      'studentId': studentId,
                      'subjectId': low.subjectId,
                    },
                  ),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: 'My subjects',
            actionLabel: 'View All',
            onAction: () => Navigator.of(context).pushNamed(
              AppRoutes.studentSubjects,
              arguments: studentId,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (data.subjects.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'No subjects enrolled yet.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < data.subjects.length; i++) ...[
                    _SubjectTile(
                      subject: data.subjects[i],
                      studentId: studentId,
                    ),
                    if (i != data.subjects.length - 1)
                      const Divider(height: 1, indent: 72),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(
            title: 'Subject attendance',
            icon: Icons.bar_chart_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: data.subjects.isEmpty
                  ? Text(
                      'Attendance per subject will appear here.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  : AttendanceBarChart(
                      segments: [
                        for (final s in data.subjects)
                          BarSegment(
                            label: s.code,
                            percentage: s.stats.percentage,
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: 'Recent attendance',
            actionLabel: 'History',
            onAction: () => Navigator.of(context).pushNamed(
              AppRoutes.studentAttendance,
              arguments: studentId,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < data.recent.length; i++) ...[
                  _RecentTile(record: data.recent[i]),
                  if (i != data.recent.length - 1)
                    const Divider(height: 1, indent: 72),
                ],
                if (data.recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'No attendance records yet.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  AttendanceRing(
                    percentage: data.overall.percentage,
                    size: 72,
                    strokeWidth: 7,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall attendance',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Present ${data.overall.present} · '
                          'Absent ${data.overall.absent} · '
                          'Late ${data.overall.late}',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.subject, required this.studentId});

  final SubjectBreakdownData subject;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = AppColors.attendance(subject.stats.percentage);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      dense: true,
      leading: AppAvatar(name: subject.name, radius: 20),
      title: Text(
        subject.name,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${subject.code} · ${subject.teacherName}',
        style: textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        formatPercentage(subject.stats.percentage),
        style: textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.studentSubjectDetails,
        arguments: {'studentId': studentId, 'subjectId': subject.subjectId},
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.record});

  final DashboardRecentRecord record;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      dense: true,
      leading: AppAvatar(name: record.subjectName, radius: 20),
      title: Text(
        record.subjectName,
        style: textTheme.bodyMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${formatDate(record.date)} · ${record.mark}',
        style: textTheme.bodySmall,
      ),
      trailing: Text(
        record.mark == 'absent' ? 'Missed' : 'Attended',
        style: textTheme.labelSmall?.copyWith(
          color: record.mark == 'absent'
              ? AppColors.error
              : AppColors.success,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
