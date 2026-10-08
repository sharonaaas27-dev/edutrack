const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Lightweight date formatting (avoids adding intl for Stage 2).
String formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String weekdayName(DateTime date) => _weekdays[date.weekday - 1];
