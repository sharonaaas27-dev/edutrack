import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:edutrack/core/constants/app_spacing.dart';
import 'package:edutrack/core/constants/app_strings.dart';
import 'package:edutrack/providers/subject_provider.dart';
import 'package:edutrack/screens/admin/subject_form.dart';
import 'package:edutrack/widgets/empty_state.dart';
import 'package:edutrack/widgets/gradient_header.dart';

class EditSubjectScreen extends StatelessWidget {
  const EditSubjectScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubjectProvider>();
    final subject = provider.getById(subjectId);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.editSubject)),
      body: SafeArea(
        child: subject == null
            ? const EmptyState(
                title: 'Subject not found',
                subtitle: 'This record may have been deleted.',
                icon: Icons.menu_book_outlined,
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
                          accentLabel: 'Editing ${subject.code}',
                          title: subject.name,
                          subtitle:
                              'Update the record below. Changes reflect instantly across the app.',
                          icon: Icons.edit_note_rounded,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: SubjectForm(
                              key: ValueKey(subject.id),
                              initial: subject,
                              submitLabel: AppStrings.saveChanges,
                              isSaving: provider.isSaving,
                              onSubmit: (updated) async {
                                final error = await context
                                    .read<SubjectProvider>()
                                    .updateSubject(updated);
                                if (!context.mounted) return;
                                if (error == null) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          AppStrings.subjectUpdated,
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
