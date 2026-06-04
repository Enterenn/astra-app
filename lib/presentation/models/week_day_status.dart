/// Display model for one day in the Today week progress strip.
class WeekDayStatus {
  const WeekDayStatus({
    required this.localDay,
    required this.weekdayLabel,
    required this.dayNumber,
    required this.isToday,
    required this.isFuture,
    required this.goalMet,
  });

  final DateTime localDay;
  final String weekdayLabel;
  final int dayNumber;
  final bool isToday;
  final bool isFuture;

  /// Past or today with `totalSteps >= daily goal`.
  final bool goalMet;
}
