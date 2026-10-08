import 'package:flutter/material.dart';

/// Canonical labeled dropdown. Wraps DropdownButtonFormField so every
/// filter/form dropdown shares labels, density, and validation behavior.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.prefixIcon,
    this.validator,
    this.labelFor,
  });

  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final IconData? prefixIcon;
  final String? Function(T?)? validator;

  /// Custom label per item (defaults to the item's `toString()`).
  final String Function(T item)? labelFor;

  @override
  Widget build(BuildContext context) {
    final safeValue = value != null && items.contains(value) ? value : null;
    return DropdownButtonFormField<T>(
      initialValue: safeValue,
      // Required: without this the button sizes to its longest item and
      // overflows the input decorator on narrow screens.
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item,
            child: Text(
              labelFor?.call(item) ?? '$item',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
      validator: validator,
    );
  }
}
