import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/core/utils/validators.dart';
import 'package:edutrack/models/subject.dart';
import 'package:edutrack/screens/admin/student_form.dart'
    show courseOptions, yearOptions, sectionOptions;
import 'package:edutrack/widgets/app_dropdown.dart';
import 'package:edutrack/widgets/custom_button.dart';
import 'package:edutrack/widgets/custom_text_field.dart';
import 'package:edutrack/widgets/section_header.dart';

const List<String> semesterOptions = [
  'S1',
  'S2',
  'S3',
  'S4',
  'S5',
  'S6',
  'S7',
  'S8',
];

const List<String> weekdayOptions = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

/// Shared add/edit form so both subject screens validate identically.
class SubjectForm extends StatefulWidget {
  const SubjectForm({
    super.key,
    this.initial,
    required this.submitLabel,
    required this.isSaving,
    required this.onSubmit,
  });

  final Subject? initial;
  final String submitLabel;
  final bool isSaving;
  final ValueChanged<Subject> onSubmit;

  @override
  State<SubjectForm> createState() => _SubjectFormState();
}

class _SubjectFormState extends State<SubjectForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _credits;
  late final TextEditingController _teacher;
  late final TextEditingController _room;
  late String? _course;
  late String? _year;
  late String? _semester;
  late String? _section;
  late bool _isActive;
  late List<ClassSchedule> _schedule;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _code = TextEditingController(text: initial?.code ?? '');
    _name = TextEditingController(text: initial?.name ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    _credits = TextEditingController(
      text: initial != null ? '${initial.credits}' : '',
    );
    _teacher = TextEditingController(text: initial?.teacherName ?? '');
    _room = TextEditingController(text: initial?.room ?? '');
    _course = initial?.course;
    _year = initial?.year;
    _semester = initial?.semester;
    _section = initial?.section;
    _isActive = initial?.isActive ?? true;
    _schedule = List<ClassSchedule>.from(initial?.schedule ?? const []);
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _description.dispose();
    _credits.dispose();
    _teacher.dispose();
    _room.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_course == null ||
        _year == null ||
        _semester == null ||
        _section == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please select course, year, semester and section.'),
          ),
        );
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    widget.onSubmit(
      Subject(
        id: widget.initial?.id ?? 'sub-$now',
        code: _code.text.trim().toUpperCase(),
        name: _name.text.trim(),
        description: _description.text.trim(),
        credits: int.parse(_credits.text.trim()),
        course: _course!,
        year: _year!,
        semester: _semester!,
        section: _section!,
        teacherName: _teacher.text.trim(),
        room: _room.text.trim(),
        schedule: _schedule,
        isActive: _isActive,
      ),
    );
  }

  Future<void> _addSlot() async {
    final slot = await showModalBottomSheet<ClassSchedule>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => const _SlotSheet(),
    );
    if (slot != null) setState(() => _schedule = [..._schedule, slot]);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Subject details'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: CustomTextField(
                  controller: _code,
                  label: AppStrings.subjectCodeLabel,
                  hint: 'CS401',
                  textInputAction: TextInputAction.next,
                  prefixIcon: Icons.tag_rounded,
                  validator: (v) => Validators.required(
                    v,
                    message: AppStrings.subjectCodeRequired,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 1,
                child: CustomTextField(
                  controller: _credits,
                  label: AppStrings.creditsLabel,
                  hint: '1–10',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  prefixIcon: Icons.star_outline_rounded,
                  validator: Validators.credits,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          CustomTextField(
            controller: _name,
            label: AppStrings.subjectNameLabel,
            hint: 'e.g. Machine Learning',
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.menu_book_outlined,
            validator: (v) =>
                Validators.required(v, message: AppStrings.subjectNameRequired),
          ),
          const SizedBox(height: AppSpacing.md),
          CustomTextField(
            controller: _description,
            label: 'Description',
            hint: 'What this subject covers',
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.description_outlined,
            validator: null,
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(
            title: 'Academics',
            color: AppColors.accentViolet,
          ),
          const SizedBox(height: AppSpacing.md),
          AppDropdown<String>(
            label: AppStrings.courseLabel,
            prefixIcon: Icons.school_outlined,
            value: _course,
            items: courseOptions,
            onChanged: (v) => setState(() => _course = v),
            validator: (v) => v == null ? AppStrings.courseRequired : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppDropdown<String>(
                  label: AppStrings.yearLabel,
                  prefixIcon: Icons.calendar_month_outlined,
                  value: _year,
                  items: yearOptions,
                  onChanged: (v) => setState(() => _year = v),
                  validator: (v) => v == null ? AppStrings.yearRequired : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppDropdown<String>(
                  label: 'Semester',
                  prefixIcon: Icons.layers_outlined,
                  value: _semester,
                  items: semesterOptions,
                  onChanged: (v) => setState(() => _semester = v),
                  validator: (v) =>
                      v == null ? AppStrings.semesterRequired : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppDropdown<String>(
            label: AppStrings.sectionLabel,
            prefixIcon: Icons.group_outlined,
            value: _section,
            items: sectionOptions,
            onChanged: (v) => setState(() => _section = v),
            validator: (v) => v == null ? AppStrings.sectionRequired : null,
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(
            title: 'Faculty & venue',
            color: AppColors.info,
          ),
          const SizedBox(height: AppSpacing.md),
          CustomTextField(
            controller: _teacher,
            label: AppStrings.teacherLabel,
            hint: 'e.g. Dr. Anil Kumar',
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.person_outline_rounded,
            validator: (v) =>
                Validators.required(v, message: AppStrings.teacherRequired),
          ),
          const SizedBox(height: AppSpacing.md),
          CustomTextField(
            controller: _room,
            label: 'Room',
            hint: 'e.g. R-201',
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.meeting_room_outlined,
            validator: null,
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Schedule',
                  color: AppColors.warning,
                ),
              ),
              TextButton.icon(
                onPressed: _addSlot,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add slot'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_schedule.isEmpty)
            Text(
              'No class slots yet — optional, but helpful for students.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            ..._schedule.map(
              (slot) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.schedule_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(slot.label, style: textTheme.bodyMedium),
                  trailing: IconButton(
                    tooltip: 'Remove slot',
                    onPressed: () => setState(
                      () => _schedule = _schedule
                          .where((s) => s != slot)
                          .toList(),
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Active subject',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Inactive subjects stay in history but hide from new enrollment.',
              style: textTheme.bodySmall,
            ),
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          CustomButton(
            text: widget.submitLabel,
            isLoading: widget.isSaving,
            onPressed: widget.isSaving ? null : _submit,
            icon: Icons.check_rounded,
          ),
        ],
      ),
    );
  }
}

class _SlotSheet extends StatefulWidget {
  const _SlotSheet();

  @override
  State<_SlotSheet> createState() => _SlotSheetState();
}

class _SlotSheetState extends State<_SlotSheet> {
  String _day = weekdayOptions.first;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
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
            Text(
              'Add class slot',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppDropdown<String>(
              label: 'Day',
              value: _day,
              items: weekdayOptions,
              onChanged: (v) => setState(() => _day = v ?? _day),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _start,
                      );
                      if (picked != null) setState(() => _start = picked);
                    },
                    icon: const Icon(Icons.access_time_rounded),
                    label: Text('Start ${_fmt(_start)}'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _end,
                      );
                      if (picked != null) setState(() => _end = picked);
                    },
                    icon: const Icon(Icons.access_time_rounded),
                    label: Text('End ${_fmt(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () {
                final startMinutes = _start.hour * 60 + _start.minute;
                final endMinutes = _end.hour * 60 + _end.minute;
                if (endMinutes <= startMinutes) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('End time must be after start time.'),
                      ),
                    );
                  return;
                }
                Navigator.of(context).pop(
                  ClassSchedule(
                    day: _day,
                    startTime: _fmt(_start),
                    endTime: _fmt(_end),
                  ),
                );
              },
              child: const Text('Add slot'),
            ),
          ],
        ),
      ),
    );
  }
}

