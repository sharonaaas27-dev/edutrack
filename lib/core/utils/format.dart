// Consistent value formatting across the app.
// See also date_format.dart for calendar formatting.

/// `87%`, `66.7%` — whole numbers stay whole, fractions keep one digit.
String formatPercentage(double value) {
  if (value.isNaN) return '—';
  final rounded = value % 1 == 0;
  return '${value.toStringAsFixed(rounded ? 0 : 1)}%';
}

/// Compact counts for stat cards: `1.2k` beyond 9999, plain otherwise.
String formatCount(int value) {
  if (value < 10000) return '$value';
  final k = value / 1000;
  final text = k % 1 == 0 ? k.toStringAsFixed(0) : k.toStringAsFixed(1);
  return '${text}k';
}
