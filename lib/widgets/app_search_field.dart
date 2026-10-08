import 'package:flutter/material.dart';

/// Canonical search field: hint, search icon, clear button, accessible.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller == null
            ? null
            : ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller!,
                builder: (context, value, _) {
                  if (value.text.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      controller!.clear();
                      onChanged?.call('');
                    },
                    icon: const Icon(Icons.clear_rounded),
                  );
                },
              ),
      ),
    );
    return Semantics(
      label: hintText,
      textField: true,
      child: field,
    );
  }
}
