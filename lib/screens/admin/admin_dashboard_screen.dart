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
import 'package:edutrack/widgets/empty_state.dart';
import 'package:edutrack/widgets/section_header.dart';
import 'package:edutrack/widgets/user_badge.dart';

/// Admin landing page. Every number comes from the dashboard API payload
/// (or the identical offline aggregation) — nothing is fabricated.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
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
    await context.read<DashboardProvider>().loadAdmin();
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
    final data = dashboard.admin;
    final displayName =
        UserBadge.nameFor(auth.currentUser, null);

    return AppShell(
      title: AppStrings.adminTitle,
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
          onRefresh: () =>
              context.read<DashboardProvider>().loadAdmin(),
          child: _buildState(context, dashboard, data, displayName, auth),
        ),
      ),
    );
  }

  Widget _buildState(
    BuildContext context,
    DashboardProvider dashboard,
    AdminDashboardData? data,
    String displayName,
    AuthProvider auth,
  ) {
    if (dashboard.isLoading && data == null) {
      return const AppLoadingSkeleton(itemCount: 5, itemHeight: 120);
    }
    if (dashboard.errorMessage != null && data == null) {
      return AppErrorState(
        message: dashboard.errorMessage!,
        onRetry: () => context.read<DashboardProvider>().loadAdmin(),
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
    AdminDashboardData data,
    String displayName,
    AuthProvider auth,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final columns = responsiveValue<int>(context,
        mobile: 2, tablet: 3, desktop: 4);
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
            role: auth.role ?? UserRole.admin,
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Overview'),
          const SizedBox(height: AppSpacing.sm),
          StatGrid(
            columns: columns,
            children: [
              AppStatCard(
                title: AppStrings.totalStudents,
                value: formatCount(data.totalStudents),
                subtitle: 'Enrolled',
                icon: Icons.groups_outlined,
                color: AppColors.primary,
                onTap: () => Navigator.of(context)
                    .pushNamed(AppRoutes.students),
              ),
              AppStatCard(
                title: AppStrings.totalSubjects,
                value: formatCount(data.totalSubjects),
                subtitle: '${data.activeSubjects} active',
                icon: Icons.menu_book_outlined,
                color: AppColors.accentViolet,
                onTap: () => Navigator.of(context)
                    .pushNamed(AppRoutes.subjects),
              ),
              AppStatCard(
                title: 'Attendance rate',
                value: formatPercentage(data.overall.percentage),
                subtitle:
                    '${data.overall.present + data.overall.late} of ${data.overall.total} records',
                icon: Icons.insights_outlined,
                color: AppColors.info,
                animateValue: false,
                onTap: () => Navigator.of(context)
                    .pushNamed(AppRoutes.attendanceReport),
              ),
              AppStatCard(
                title: AppStrings.lowAttendance,
                value: formatCount(data.lowAttendanceCount),
                subtitle: 'Below 75%',
                icon: Icons.warning_amber_outlined,
                color: AppColors.error,
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
                    'Today: ${data.today.present + data.today.late} present · '
                    '${data.today.absent} absent · '
                    '${data.today.late} late',
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
                            subLabel: '${p.total}',
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: 'Needs attention',
            icon: Icons.priority_high_rounded,
            color: AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (data.lowAttendanceStudents.isEmpty)
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
                        'Every student is above 75% attendance. Great work!',
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
                      i < data.lowAttendanceStudents.length;
                      i++) ...[
                    _StudentTile(ref: data.lowAttendanceStudents[i]),
                    if (i != data.lowAttendanceStudents.length - 1)
                      const Divider(height: 1, indent: 72),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(
            title: 'Recent students',
            icon: Icons.person_add_alt_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < data.recentStudents.length; i++) ...[
                  _StudentTile(ref: data.recentStudents[i]),
                  if (i != data.recentStudents.length - 1)
                    const Divider(height: 1, indent: 72),
                ],
                if (data.recentStudents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'No students yet.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: 'Recent attendance',
            icon: Icons.history_rounded,
            actionLabel: 'Report',
            onAction: () => Navigator.of(context)
                .pushNamed(AppRoutes.attendanceReport),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < data.recentAttendance.length; i++) ...[
                  _RecordTile(record: data.recentAttendance[i]),
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
          const SectionHeader(title: 'Quick actions'),
          const SizedBox(height: AppSpacing.sm),
          StatGrid(
            columns: responsiveValue<int>(context,
                mobile: 2, tablet: 3, desktop: 5),
            children: [
              AppActionCard(
                label: AppStrings.addStudent,
                icon: Icons.person_add_alt_rounded,
                color: AppColors.primary,
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(AppRoutes.addStudent),
              ),
              AppActionCard(
                label: AppStrings.viewStudents,
                icon: Icons.people_outline_rounded,
                color: AppColors.info,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.students),
              ),
              AppActionCard(
                label: AppStrings.manageAttendance,
                icon: Icons.fact_check_outlined,
                color: AppColors.success,
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(AppRoutes.attendance),
              ),
              AppActionCard(
                label: AppStrings.viewSubjects,
                icon: Icons.menu_book_outlined,
                color: AppColors.accentViolet,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.subjects),
              ),
              AppActionCard(
                label: 'Reports',
                icon: Icons.assessment_outlined,
                color: AppColors.secondary,
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

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.ref});

  final DashboardStudentRef ref;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      dense: true,
      leading: AppAvatar(name: ref.name, radius: 20),
      title: Text(ref.name, style: textTheme.bodyMedium),
      subtitle: Text(
        '${ref.studentId} · ${formatPercentage(ref.percentage)}',
        style: textTheme.bodySmall,
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textHint,
      ),
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.studentDetails,
        arguments: ref.id,
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

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
