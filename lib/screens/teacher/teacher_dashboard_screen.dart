import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
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
import 'package:edutrack/widgets/empty_state.dart';
import 'package:edutrack/widgets/section_header.dart';
import 'package:edutrack/widgets/user_badge.dart';

/// Teacher landing page: today's classes, pending registers, recent
/// activity, and fast paths to daily workflows. All numbers come from the
/// dashboard payload — nothing is fabricated.
class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
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
    await context.read<DashboardProvider>().loadTeacher();
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
    final data = dashboard.teacher;
    final displayName =
        UserBadge.nameFor(auth.currentUser, null);

    return AppShell(
      title: 'Teacher Dashboard',
      selectedIndex: 0,
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: () => auth.logout(),
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
      body: PageBody(
        child: RefreshIndicator(
          onRefresh: () =>
              context.read<DashboardProvider>().loadTeacher(),
          child: _buildState(context, dashboard, data, displayName, auth),
        ),
      ),
    );
  }

  Widget _buildState(
    BuildContext context,
    DashboardProvider dashboard,
    TeacherDashboardData? data,
    String displayName,
    AuthProvider auth,
  ) {
    if (dashboard.isLoading && data == null) {
      return const AppLoadingSkeleton(itemCount: 4, itemHeight: 130);
    }
    if (dashboard.errorMessage != null && data == null) {
      return AppErrorState(
        message: dashboard.errorMessage!,
        onRetry: () => context.read<DashboardProvider>().loadTeacher(),
      );
    }
    if (data == null) {
      return const EmptyState(
        title: 'No dashboard data',
        subtitle: 'Pull to refresh and try again.',
        icon: Icons.dashboard_outlined,
      );
    }
    return _content(context, data, displayName, auth);
  }

  Widget _content(
    BuildContext context,
    TeacherDashboardData data,
    String displayName,
    AuthProvider auth,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final subjects = context.watch<SubjectProvider>();
    final todayName = weekdayName(DateTime.now());
    final todaysClasses = subjects.subjects
        .where((s) =>
            s.isActive &&
            s.schedule.any((slot) => slot.day == todayName))
        .toList();
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
            '${formatDate(DateTime.now())} · ${data.totalStudents} students · '
            '${data.totalSubjects} subjects',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          UserBadge(
            displayName: displayName,
            role: auth.role ?? UserRole.teacher,
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'At a glance'),
          const SizedBox(height: AppSpacing.sm),
          StatGrid(
            columns: columns,
            children: [
              AppStatCard(
                title: 'Students',
                value: formatCount(data.totalStudents),
                subtitle: 'Across classes',
                icon: Icons.groups_outlined,
                color: AppColors.primary,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.students),
              ),
              AppStatCard(
                title: 'Subjects',
                value: formatCount(data.totalSubjects),
                subtitle: 'In catalog',
                icon: Icons.menu_book_outlined,
                color: AppColors.info,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.subjects),
              ),
              AppStatCard(
                title: "Today's present",
                value: formatCount(data.today.present + data.today.late),
                subtitle: 'Marked today',
                icon: Icons.how_to_reg_outlined,
                color: AppColors.success,
                onTap: () => Navigator.of(context)
                    .pushNamed(AppRoutes.attendanceReport),
              ),
              AppStatCard(
                title: 'Pending registers',
                value: formatCount(data.pendingSubjectsToday.length),
                subtitle: data.pendingSubjectsToday.isEmpty
                    ? 'All caught up'
                    : 'Unmarked today',
                icon: Icons.pending_actions_outlined,
                color: data.pendingSubjectsToday.isEmpty
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: 'Attendance trend',
            icon: Icons.show_chart_rounded,
            color: AppColors.info,
            actionLabel: 'Report',
            onAction: () => Navigator.of(context)
                .pushNamed(AppRoutes.attendanceReport),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall ${formatPercentage(data.overall.percentage)} '
                    'across ${data.overall.total} records',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (data.trend.isEmpty)
                    Text(
                      'No attendance records yet.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
                    AttendanceBarChart(
                      segments: [
                        for (final p in data.trend)
                          BarSegment(
                            label: _shortDay(p.date),
                            percentage: p.percentage,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: "Today's classes",
            icon: Icons.calendar_today_outlined,
            actionLabel: 'Take attendance',
            onAction: () =>
                Navigator.of(context).pushNamed(AppRoutes.attendance),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (todaysClasses.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'No classes scheduled for $todayName.',
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
                  for (var i = 0; i < todaysClasses.length; i++) ...[
                    _ClassTile(subjectId: todaysClasses[i].id),
                    if (i != todaysClasses.length - 1)
                      const Divider(height: 1, indent: 72),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: 'Pending attendance',
            icon: Icons.pending_actions_outlined,
            color: AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (data.pendingSubjectsToday.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'All registers for today are marked. Nice work!',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0;
                      i < data.pendingSubjectsToday.length;
                      i++) ...[
                    _PendingTile(
                        pending: data.pendingSubjectsToday[i]),
                    if (i != data.pendingSubjectsToday.length - 1)
                      const Divider(height: 1, indent: 72),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: 'Recent activity',
            icon: Icons.history_rounded,
            actionLabel: 'Report',
            onAction: () => Navigator.of(context)
                .pushNamed(AppRoutes.attendanceReport),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                for (var i = 0;
                    i < data.recentAttendance.length;
                    i++) ...[
                  _RecentTile(record: data.recentAttendance[i]),
                  if (i != data.recentAttendance.length - 1)
                    const Divider(height: 1, indent: 72),
                ],
                if (data.recentAttendance.isEmpty)
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
          const SectionHeader(title: 'Daily workflows'),
          const SizedBox(height: AppSpacing.sm),
          StatGrid(
            columns: responsiveValue<int>(context,
                mobile: 2, tablet: 3, desktop: 4),
            children: [
              AppActionCard(
                label: 'Take Attendance',
                icon: Icons.fact_check_outlined,
                color: AppColors.success,
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(AppRoutes.attendance),
              ),
              AppActionCard(
                label: 'View Students',
                icon: Icons.people_outline_rounded,
                color: AppColors.info,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.students),
              ),
              AppActionCard(
                label: 'View Subjects',
                icon: Icons.menu_book_outlined,
                color: AppColors.accentViolet,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.subjects),
              ),
              AppActionCard(
                label: 'Reports',
                icon: Icons.assessment_outlined,
                color: AppColors.primary,
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(AppRoutes.attendanceReport),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _shortDay(DateTime date) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[date.weekday - 1]} ${date.day}';
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subject = context.watch<SubjectProvider>().getById(subjectId);
    if (subject == null) return const SizedBox.shrink();
    final todayName = weekdayName(DateTime.now());
    final slots = subject.schedule
        .where((slot) => slot.day == todayName)
        .map((slot) => '${slot.startTime}–${slot.endTime}')
        .join(', ');
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
        '${subject.code} · $slots',
        style: textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textHint,
      ),
      onTap: () =>
          Navigator.of(context).pushNamed(AppRoutes.attendance),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.pending});

  final PendingSubjectData pending;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      dense: true,
      leading: AppAvatar(name: pending.name, radius: 20),
      title: Text(
        pending.name,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${pending.code} · ${pending.enrolled} enrolled',
        style: textTheme.bodySmall,
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textHint,
      ),
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.attendance),
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
      leading: AppAvatar(name: record.studentName, radius: 20),
      title: Text(
        '${record.studentName} · ${record.subjectName}',
        style: textTheme.bodyMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${formatDate(record.date)} · ${record.mark}',
        style: textTheme.bodySmall,
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textHint,
      ),
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.studentDetails,
        arguments: record.studentId,
      ),
    );
  }
}
