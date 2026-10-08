import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/core/routes/app_routes.dart';
import 'package:edutrack/core/utils/responsive.dart';
import 'package:edutrack/models/subject.dart';
import 'package:edutrack/models/user.dart';
import 'package:edutrack/providers/auth_provider.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/widgets/app_avatar.dart';
import 'package:edutrack/widgets/app_dropdown.dart';
import 'package:edutrack/widgets/app_search_field.dart';
import 'package:edutrack/widgets/app_shell.dart';
import 'package:edutrack/widgets/app_states.dart';
import 'package:edutrack/widgets/empty_state.dart';
import 'package:edutrack/widgets/subject_card.dart';

/// Admin subject management: search, filter, list, add.
class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SubjectProvider>();
      _searchController.text = provider.searchQuery;
      provider.ensureLoaded().then((_) {
        if (mounted) context.read<SubjectProvider>().preloadRosters();
      });
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
      builder: (_) => const _SubjectFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<SubjectProvider>();
    final isAdmin =
        context.watch<AuthProvider>().role == UserRole.admin;
    final results = provider.filteredSubjects;

    return AppShell(
      title: AppStrings.subjectsTitle,
      selectedIndex: 2,
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
                  Navigator.of(context).pushNamed(AppRoutes.addSubject),
              icon: const Icon(Icons.add_rounded),
              label: const Text(AppStrings.addSubject),
            )
          : null,
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage academic subjects and enrollments.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppSearchField(
              controller: _searchController,
              hintText: AppStrings.searchSubjectsHint,
              onChanged: (v) =>
                  context.read<SubjectProvider>().setSearchQuery(v),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    provider.isLoading && !provider.isLoaded
                        ? 'Loading subjects…'
                        : '${results.length} of ${provider.totalCount} subjects',
                    style: textTheme.bodySmall,
                  ),
                ),
                if (provider.hasActiveFilters)
                  TextButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      context.read<SubjectProvider>().clearFilters();
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

  Widget _buildBody(SubjectProvider provider) {
    if (provider.isLoading && !provider.isLoaded) {
      return const AppLoadingSkeleton(
        key: ValueKey('loading'),
        itemHeight: 120,
      );
    }

    if (provider.errorMessage != null && provider.subjects.isEmpty) {
      return AppErrorState(
        key: const ValueKey('error'),
        message: provider.errorMessage!,
        onRetry: () => context.read<SubjectProvider>().loadSubjects(),
      );
    }

    final results = provider.filteredSubjects;
    if (results.isEmpty) {
      return SingleChildScrollView(
        key: const ValueKey('empty'),
        child: EmptyState(
          title: AppStrings.noSubjectsFound,
          subtitle: AppStrings.noSubjectsHint,
          icon: Icons.menu_book_outlined,
          actionLabel: provider.hasActiveFilters
              ? AppStrings.clearFilters
              : null,
          onAction: provider.hasActiveFilters
              ? () {
                  _searchController.clear();
                  context.read<SubjectProvider>().clearFilters();
                }
              : null,
        ),
      );
    }

    return RefreshIndicator(
      key: const ValueKey('list'),
      onRefresh: () async {
        final provider = context.read<SubjectProvider>();
        await provider.loadSubjects();
        if (!mounted) return;
        await provider.preloadRosters();
      },
      child: ResponsiveLayout(
        mobile: (_) => ListView.separated(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final subject = results[index];
            return SubjectCard(
              subject: subject,
              enrolledCount: provider.enrolledCount(subject.id),
              onTap: () => Navigator.of(
                context,
              ).pushNamed(AppRoutes.subjectDetails, arguments: subject.id),
            );
          },
        ),
        tablet: (_) => _SubjectTable(results: results),
        desktop: (_) => _SubjectTable(results: results),
      ),
    );
  }
}

/// Dense data table for tablet/desktop: code, name, course, semester,
/// enrolled, status. Mobile keeps cards (see _buildBody).
class _SubjectTable extends StatelessWidget {
  const _SubjectTable({required this.results});

  final List<Subject> results;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rosters = context.watch<SubjectProvider>();
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
                DataColumn(label: Text('SUBJECT')),
                DataColumn(label: Text('CODE')),
                DataColumn(label: Text('COURSE')),
                DataColumn(label: Text('SEMESTER')),
                DataColumn(label: Text('ENROLLED'), numeric: true),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('')),
              ],
              rows: [
                for (final subject in results)
                  DataRow(
                    onSelectChanged: (_) => Navigator.of(context).pushNamed(
                      AppRoutes.subjectDetails,
                      arguments: subject.id,
                    ),
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppAvatar(
                                name: subject.name, radius: 18),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              subject.name,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(subject.code)),
                      DataCell(Text(subject.course)),
                      DataCell(Text(subject.semester)),
                      DataCell(Text(
                          '${rosters.enrolledCount(subject.id)}')),
                      DataCell(
                        Text(
                          subject.isActive ? 'Active' : 'Inactive',
                          style: textTheme.bodyMedium?.copyWith(
                            color: subject.isActive
                                ? AppColors.success
                                : AppColors.textHint,
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

class _SubjectFilterSheet extends StatefulWidget {
  const _SubjectFilterSheet();

  @override
  State<_SubjectFilterSheet> createState() => _SubjectFilterSheetState();
}

class _SubjectFilterSheetState extends State<_SubjectFilterSheet> {
  late String _course;
  late String _year;
  late String _semester;
  late String _section;
  late SubjectStatusFilter _status;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SubjectProvider>();
    _course = provider.courseFilter;
    _year = provider.yearFilter;
    _semester = provider.semesterFilter;
    _section = provider.sectionFilter;
    _status = provider.statusFilter;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<SubjectProvider>();

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
                      _semester = 'All';
                      _section = 'All';
                      _status = SubjectStatusFilter.all;
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
                    label: 'Semester',
                    value: _semester,
                    items: provider.availableSemesters,
                    onChanged: (v) => setState(() => _semester = v ?? 'All'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String>(
              label: AppStrings.sectionFilter,
              value: _section,
              items: provider.availableSections,
              onChanged: (v) => setState(() => _section = v ?? 'All'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'STATUS',
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
                _StatusChip(
                  label: 'All',
                  selected: _status == SubjectStatusFilter.all,
                  onTap: () =>
                      setState(() => _status = SubjectStatusFilter.all),
                ),
                _StatusChip(
                  label: 'Active',
                  selected: _status == SubjectStatusFilter.active,
                  onTap: () =>
                      setState(() => _status = SubjectStatusFilter.active),
                ),
                _StatusChip(
                  label: 'Inactive',
                  selected: _status == SubjectStatusFilter.inactive,
                  onTap: () =>
                      setState(() => _status = SubjectStatusFilter.inactive),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () {
                final target = context.read<SubjectProvider>();
                target.setCourseFilter(_course);
                target.setYearFilter(_year);
                target.setSemesterFilter(_semester);
                target.setSectionFilter(_section);
                target.setStatusFilter(_status);
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
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

