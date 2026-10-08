import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/screens/admin/subject_form.dart';
import 'package:edutrack/widgets/gradient_header.dart';

class AddSubjectScreen extends StatelessWidget {
  const AddSubjectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<SubjectProvider>().isSaving;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.addSubject)),
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
                    accentLabel: 'New subject',
                    title: 'Add a new subject',
                    subtitle:
                        'Define the subject, its academics, faculty and weekly schedule.',
                    icon: Icons.library_add_outlined,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: SubjectForm(
                        submitLabel: AppStrings.addSubject,
                        isSaving: isSaving,
                        onSubmit: (subject) async {
                          final error = await context
                              .read<SubjectProvider>()
                              .addSubject(subject);
                          if (!context.mounted) return;
                          if (error == null) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text(AppStrings.subjectAdded),
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
