/// Read model for Trends twelve-month monthly chart (D-21 extension).
///
/// Produced by [StepAggregationRepository.getChartMonthlyAggregates]; consumed by
/// `HistoryCubit` / `TrendsMonthlyBarChart` in Story 12.3. Not a persistence entity.
class ChartMonthAggregate {
  const ChartMonthAggregate({
    required this.monthStart,
    required this.averageDailySteps,
    required this.totalSteps,
    required this.dayCount,
  });

  /// Date-only UTC key for the first day of the calendar month.
  final DateTime monthStart;

  /// Pre-rounded average daily steps for the month window.
  final int averageDailySteps;

  /// Sum of daily step totals in the month window (test/debug friendly).
  final int totalSteps;

  /// Calendar days in the month window used as denominator.
  final int dayCount;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChartMonthAggregate &&
            runtimeType == other.runtimeType &&
            monthStart == other.monthStart &&
            averageDailySteps == other.averageDailySteps &&
            totalSteps == other.totalSteps &&
            dayCount == other.dayCount;
  }

  @override
  int get hashCode =>
      Object.hash(monthStart, averageDailySteps, totalSteps, dayCount);
}
