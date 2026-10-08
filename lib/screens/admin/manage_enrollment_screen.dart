import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/widgets/app_avatar.dart';
import 'package:edutrack/widgets/app_search_field.dart';
import 'package:edutrack/widgets/app_states.dart';
import 'package:edutrack/widgets/custom_button.dart';
import 'package:edutrack/widgets/empty_state.dart';

/// Roster editor for one subject: search students, toggle checkboxes,
/// save enrollment.
class ManageEnrollmentScreen extends StatefulWidget {
  const ManageEnrollmentScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  State<ManageEnrollmentScreen> createState() => _ManageEnrollmentScreenState();
}

class _ManageEnrollmentScreenState extends State<ManageEnrollmentScreen> {
  late final TextEditingController _searchController;
  String _query = '';
  late Set<String> _selected;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selected = {};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final students = context.read<StudentProvider>();
      if (students.students.isEmpty && !students.isLoading) {
        students.loadStudents();
      }
      final subjects = context.read<SubjectProvider>();
      subjects.ensureLoaded().then((_) {
        if (!mounted) return;
        subjects.loadRoster(widget.subjectId).then((_) {
          if (!mounted) return;
          setState(() {
            _selected = context
                .read<SubjectProvider>()
                .rosterFor(widget.subjectId)
                .toSet();
            _initialized = true;
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = await context.read<SubjectProvider>().saveEnrollment(
      widget.subjectId,
      _selected.toList(),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.enrollmentSaved)),
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
    final students = context.watch<StudentProvider>();
    final subjects = context.watch<SubjectProvider>();
    final subject = subjects.getById(widget.subjectId);

    final q = _query.trim().toLowerCase();
    final all = students.students.where((s) {
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) ||
          s.studentId.toLowerCase().contains(q) ||
          s.course.toLowerCase().contains(q) ||
          s.section.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.manageStudents)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child:
                      !_initialized ||
                          (students.isLoading && students.students.isEmpty)
                      ? const AppLoadingSkeleton(
                          itemCount: 5, itemHeight: 72)
                      : all.isEmpty
                      ? const EmptyState(
                          title: AppStrings.noStudentsFound,
                          subtitle: AppStrings.noStudentsHint,
                          icon: Icons.people_outline_rounded,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.screenPadding,
                                AppSpacing.lg,
                                AppSpacing.screenPadding,
                                AppSpacing.sm,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (subject != null)
                                    Text(
                                      '${subject.code} · ${subject.name}',
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    '${_selected.length} selected',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  AppSearchField(
                                    controller: _searchController,
                                    hintText:
                                        'Search name, ID, course, section…',
                                    onChanged: (v) =>
                                        setState(() => _query = v),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.screenPadding,
                                ),
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.sm,
                                  ),
                                  itemCount: all.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final s = all[index];
                                    final checked = _selected.contains(s.id);
                                    return CheckboxListTile(
                                      value: checked,
                                      onChanged: (v) => setState(() {
                                        if (v == true) {
                                          _selected.add(s.id);
                                        } else {
                                          _selected.remove(s.id);
                                        }
                                      }),
                                      secondary: AppAvatar(
                                        name: s.name,
                                        radius: 20,
                                      ),
                                      title: Text(
                                        s.name,
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${s.studentId} · ${s.course} • ${s.section}',
                                        style: textTheme.bodySmall,
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.trailing,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: CustomButton(
                    text: AppStrings.saveEnrollment,
                    isLoading: subjects.isSaving,
                    onPressed: subjects.isSaving ? null : _save,
                    icon: Icons.check_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
