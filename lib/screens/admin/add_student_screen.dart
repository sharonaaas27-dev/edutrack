import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/screens/admin/student_form.dart';
import 'package:edutrack/widgets/gradient_header.dart';

class AddStudentScreen extends StatelessWidget {
  const AddStudentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<StudentProvider>().isSaving;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.addStudent)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const GradientHeader(
                    accentLabel: 'New record',
                    title: 'Add a new student',
                    subtitle:
                        'Fill in the details below. Required fields are validated instantly.',
                    icon: Icons.person_add_alt_rounded,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: StudentForm(
                        submitLabel: AppStrings.addStudent,
                        isSaving: isSaving,
                        onSubmit: (student) async {
                          final error = await context
                              .read<StudentProvider>()
                              .addStudent(student);
                          if (!context.mounted) return;
                          if (error == null) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text(AppStrings.studentAdded),
                                ),
                              );
                          } else {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(SnackBar(content: Text(error)));
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
