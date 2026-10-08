import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/providers/student_provider.dart';
import 'package:edutrack/screens/admin/student_form.dart';
import 'package:edutrack/widgets/empty_state.dart';
import 'package:edutrack/widgets/gradient_header.dart';

class EditStudentScreen extends StatelessWidget {
  const EditStudentScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentProvider>();
    final student = provider.getById(studentId);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.editStudent)),
      body: SafeArea(
        child: student == null
            ? const EmptyState(
                title: 'Student not found',
                subtitle: 'This record may have been deleted.',
                icon: Icons.person_off_outlined,
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GradientHeader(
                          accentLabel: 'Editing ${student.studentId}',
                          title: student.name,
                          subtitle:
                              'Update the record below. Changes reflect instantly across the app.',
                          icon: Icons.edit_note_rounded,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: StudentForm(
                              key: ValueKey(student.id),
                              initial: student,
                              submitLabel: AppStrings.saveChanges,
                              isSaving: provider.isSaving,
                              onSubmit: (updated) async {
                                final error = await context
                                    .read<StudentProvider>()
                                    .updateStudent(updated);
                                if (!context.mounted) return;
                                if (error == null) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          AppStrings.studentUpdated,
                                        ),
                                      ),
                                    );
                                } else {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(content: Text(error)),
                                    );
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
