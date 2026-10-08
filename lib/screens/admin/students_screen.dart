import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/core/routes/app_routes.dart';
import 'package:edutrack/core/utils/format.dart';
import 'package:edutrack/core/utils/responsive.dart';
import 'package:edutrack/models/student.dart';
import 'package:edutrack/models/user.dart';
import 'package:edutrack/providers/auth_provider.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/widgets/app_avatar.dart';
import 'package:edutrack/widgets/app_dropdown.dart';
import 'package:edutrack/widgets/app_search_field.dart';
import 'package:edutrack/widgets/app_shell.dart';
import 'package:edutrack/widgets/app_states.dart';
import 'package:edutrack/widgets/empty_state.dart';
import 'package:edutrack/widgets/student_card.dart';

/// Main student-management screen: search, filter, list, add.
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StudentProvider>();
      _searchController.text = provider.searchQuery;
      if (provider.students.isEmpty && !provider.isLoading) {
        provider.loadStudents();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => const _FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<StudentProvider>();
    final isAdmin =
        context.watch<AuthProvider>().role == UserRole.admin;
    final results = provider.filteredStudents;

    return AppShell(
      title: AppStrings.studentsTitle,
      selectedIndex: 1,
      actions: [
        Stack(
          children: [
            IconButton(
              tooltip: AppStrings.filters,
              onPressed: _openFilters,
              icon: const Icon(Icons.filter_list_rounded),
            ),
            if (provider.hasActiveFilters)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.addStudent),
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text(AppStrings.addStudent),
            )
          : null,
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.studentsSubtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppSearchField(
              controller: _searchController,
              hintText: AppStrings.searchStudentsHint,
              onChanged: (v) =>
                  context.read<StudentProvider>().setSearchQuery(v),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    provider.isLoading
                        ? 'Loading students…'
                        : '${results.length} of ${provider.totalCount} students',
                    style: textTheme.bodySmall,
                  ),
                ),
                if (provider.hasActiveFilters)
                  TextButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      context.read<StudentProvider>().clearFilters();
                    },
                    icon: const Icon(
                      Icons.clear_all_rounded,
                      size: 18,
                    ),
                    label: const Text(AppStrings.clearFilters),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildBody(provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(StudentProvider provider) {
    if (provider.isLoading && provider.students.isEmpty) {
      return const AppLoadingSkeleton(key: ValueKey('loading'));
    }

    if (provider.errorMessage != null && provider.students.isEmpty) {
      return AppErrorState(
        key: const ValueKey('error'),
        message: provider.errorMessage!,
        onRetry: () => context.read<StudentProvider>().loadStudents(),
      );
    }

    final results = provider.filteredStudents;
    if (results.isEmpty) {
      return SingleChildScrollView(
        key: const ValueKey('empty'),
        child: EmptyState(
          title: AppStrings.noStudentsFound,
          subtitle: AppStrings.noStudentsHint,
          actionLabel: provider.hasActiveFilters
              ? AppStrings.clearFilters
              : null,
          onAction: provider.hasActiveFilters
              ? () {
                  _searchController.clear();
                  context.read<StudentProvider>().clearFilters();
                }
              : null,
        ),
      );
    }

    return RefreshIndicator(
      key: const ValueKey('list'),
      onRefresh: () => context.read<StudentProvider>().loadStudents(),
      child: ResponsiveLayout(
        mobile: (_) => ListView.separated(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final student = results[index];
            return StudentCard(
              student: student,
              onTap: () => Navigator.of(
                context,
              ).pushNamed(AppRoutes.studentDetails, arguments: student.id),
            );
          },
        ),
        tablet: (_) => _StudentTable(results: results),
        desktop: (_) => _StudentTable(results: results),
      ),
    );
  }
}

/// Dense data table for tablet/desktop: ID, name, course, year,
/// attendance, action. Mobile keeps cards (see _buildBody).
class _StudentTable extends StatelessWidget {
  const _StudentTable({required this.results});

  final List<Student> results;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.widthOf(context),
            ),
            child: DataTable(
              headingTextStyle: textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
              columns: const [
                DataColumn(label: Text('STUDENT')),
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('COURSE')),
                DataColumn(label: Text('YEAR')),
                DataColumn(label: Text('ATTENDANCE'), numeric: true),
                DataColumn(label: Text('')),
              ],
              rows: [
                for (final student in results)
                  DataRow(
                    onSelectChanged: (_) => Navigator.of(context).pushNamed(
                      AppRoutes.studentDetails,
                      arguments: student.id,
                    ),
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppAvatar(
                                name: student.name, radius: 18),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              student.name,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(student.studentId)),
                      DataCell(Text(student.course)),
                      DataCell(Text(
                          '${student.year} · ${student.section}')),
                      DataCell(
                        Text(
                          formatPercentage(
                              student.attendancePercentage),
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.attendance(
                                student.attendancePercentage),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const DataCell(Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textHint,
                      )),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _course;
  late String _year;
  late String _section;
  late AttendanceBand _band;

  @override
  void initState() {
    super.initState();
    final provider = context.read<StudentProvider>();
    _course = provider.courseFilter;
    _year = provider.yearFilter;
    _section = provider.sectionFilter;
    _band = provider.attendanceBand;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<StudentProvider>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.filters,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _course = 'All';
                      _year = 'All';
                      _section = 'All';
                      _band = AttendanceBand.all;
                    });
                  },
                  child: const Text(AppStrings.clearFilters),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String>(
              label: AppStrings.courseFilter,
              value: _course,
              items: provider.availableCourses,
              onChanged: (v) => setState(() => _course = v ?? 'All'),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppDropdown<String>(
                    label: AppStrings.yearFilter,
                    value: _year,
                    items: provider.availableYears,
                    onChanged: (v) => setState(() => _year = v ?? 'All'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppDropdown<String>(
                    label: AppStrings.sectionFilter,
                    value: _section,
                    items: provider.availableSections,
                    onChanged: (v) => setState(() => _section = v ?? 'All'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppStrings.attendanceFilter.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                _BandChip(
                  label: 'All',
                  selected: _band == AttendanceBand.all,
                  onTap: () => setState(() => _band = AttendanceBand.all),
                ),
                _BandChip(
                  label: 'Above 85%',
                  selected: _band == AttendanceBand.above85,
                  onTap: () => setState(() => _band = AttendanceBand.above85),
                ),
                _BandChip(
                  label: '75–85%',
                  selected: _band == AttendanceBand.range75to85,
                  onTap: () =>
                      setState(() => _band = AttendanceBand.range75to85),
                ),
                _BandChip(
                  label: 'Below 75%',
                  selected: _band == AttendanceBand.below75,
                  onTap: () => setState(() => _band = AttendanceBand.below75),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () {
                final target = context.read<StudentProvider>();
                target.setCourseFilter(_course);
                target.setYearFilter(_year);
                target.setSectionFilter(_section);
                target.setAttendanceBand(_band);
                Navigator.of(context).pop();
              },
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BandChip extends StatelessWidget {
  const _BandChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.primaryLight,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
    );
  }
}
