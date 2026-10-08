import 'package:flutter/material.dart';
import 'package:edutrack/core/constants/app_colors.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/core/utils/date_format.dart';
import 'package:edutrack/core/utils/validators.dart';
import 'package:edutrack/models/student.dart';
import 'package:edutrack/widgets/app_dropdown.dart';
import 'package:edutrack/widgets/custom_button.dart';
import 'package:edutrack/widgets/custom_text_field.dart';
import 'package:edutrack/widgets/section_header.dart';

const List<String> courseOptions = [
  'Computer Science',
  'Mathematics',
  'Physics',
  'Business Administration',
  'Chemistry',
  'English Literature',
];

const List<String> yearOptions = [
  '1st Year',
  '2nd Year',
  '3rd Year',
  '4th Year',
];

const List<String> sectionOptions = ['A', 'B', 'C'];

/// Shared add/edit form so both screens validate identically.
class StudentForm extends StatefulWidget {
  const StudentForm({
    super.key,
    this.initial,
    required this.submitLabel,
    required this.isSaving,
    required this.onSubmit,
  });

  final Student? initial;
  final String submitLabel;
  final bool isSaving;
  final ValueChanged<Student> onSubmit;

  @override
  State<StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<StudentForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _studentId;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _attendance;
  late String? _course;
  late String? _year;
  late String? _section;
  late DateTime _dob;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _studentId = TextEditingController(text: initial?.studentId ?? '');
    _email = TextEditingController(text: initial?.email ?? '');
    _phone = TextEditingController(text: initial?.phone ?? '');
    _address = TextEditingController(text: initial?.address ?? '');
    _attendance = TextEditingController(
      text: initial != null
          ? initial.attendancePercentage.toStringAsFixed(
              initial.attendancePercentage % 1 == 0 ? 0 : 1,
            )
          : '',
    );
    _course = initial?.course;
    _year = initial?.year;
    _section = initial?.section;
    _dob = initial?.dateOfBirth ?? DateTime(DateTime.now().year - 18, 1, 1);
  }

  @override
  void dispose() {
    _name.dispose();
    _studentId.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _attendance.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob,
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_course == null || _year == null || _section == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please select course, year and section.'),
          ),
        );
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    widget.onSubmit(
      Student(
        id: widget.initial?.id ?? 's$now',
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        studentId: _studentId.text.trim().toUpperCase(),
        course: _course!,
        year: _year!,
        section: _section!,
        dateOfBirth: _dob,
        address: _address.text.trim(),
        attendancePercentage: double.parse(_attendance.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Basic details'),
          const SizedBox(height: AppSpacing.md),
          CustomTextField(
            controller: _name,
            label: AppStrings.fullNameLabel,
            hint: 'e.g. Rahul Nair',
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.person_outline_rounded,
            validator: (v) =>
                Validators.required(v, message: AppStrings.nameRequired),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _studentId,
                  label: AppStrings.studentIdLabel,
                  hint: 'STU013',
                  textInputAction: TextInputAction.next,
                  prefixIcon: Icons.badge_outlined,
                  validator: (v) => Validators.required(
                    v,
                    message: AppStrings.studentIdRequired,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: CustomTextField(
                  controller: _attendance,
                  label: AppStrings.attendanceLabel,
                  hint: '0 – 100',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  prefixIcon: Icons.percent_rounded,
                  validator: Validators.attendance,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          CustomTextField(
            controller: _email,
            label: AppStrings.emailLabel,
            hint: AppStrings.emailHint,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.mail_outline_rounded,
            validator: Validators.email,
          ),
          const SizedBox(height: AppSpacing.md),
          CustomTextField(
            controller: _phone,
            label: AppStrings.phoneLabel,
            hint: '+91 XXXXX XXXXX',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.phone_outlined,
            validator: Validators.phone,
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(
            title: 'Academics',
            color: AppColors.accentViolet,
          ),
          const SizedBox(height: AppSpacing.md),
          AppDropdown<String>(
            label: AppStrings.courseLabel,
            prefixIcon: Icons.menu_book_outlined,
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
                  label: AppStrings.sectionLabel,
                  prefixIcon: Icons.group_outlined,
                  value: _section,
                  items: sectionOptions,
                  onChanged: (v) => setState(() => _section = v),
                  validator: (v) =>
                      v == null ? AppStrings.sectionRequired : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(
            title: 'Additional info',
            color: AppColors.info,
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: _pickDob,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: AppStrings.dobLabel,
                prefixIcon: Icon(Icons.cake_outlined),
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(formatDate(_dob), style: textTheme.bodyMedium),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          CustomTextField(
            controller: _address,
            label: AppStrings.addressLabel,
            hint: 'Street, City',
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.home_outlined,
            onChanged: null,
            validator: null,
          ),
          const SizedBox(height: AppSpacing.xl),
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
