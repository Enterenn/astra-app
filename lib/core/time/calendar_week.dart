/// Calendar week helpers (Monday–Sunday) for local date-only keys.
abstract final class CalendarWeek {
  static const weekdayLabels = <String>[
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  /// Returns Monday–Sunday [DateTime] keys (UTC date-only) for the week containing [referenceToday].
  static List<DateTime> daysContaining(DateTime referenceToday) {
    final monday = referenceToday.subtract(
      Duration(days: referenceToday.weekday - DateTime.monday),
    );
    return List.generate(
      7,
      (index) => monday.add(Duration(days: index)),
    );
  }

  static String weekdayLabelFor(DateTime localDay) {
    return weekdayLabels[localDay.weekday - DateTime.monday];
  }
}
