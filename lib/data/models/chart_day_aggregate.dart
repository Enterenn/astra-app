/// Read model for History chart daily totals (D-21).
///
/// Produced by [StepAggregationRepository.getChartDailyAggregates]; consumed by
/// `HistoryCubit` / `StepBarChart` in Story 3.3. Not a persistence entity.
class ChartDayAggregate {
  const ChartDayAggregate({
    required this.localDay,
    required this.totalSteps,
  });

  /// Date-only UTC key from `LocalDayCalculator.localDay`.
  final DateTime localDay;

  final int totalSteps;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChartDayAggregate &&
            runtimeType == other.runtimeType &&
            localDay == other.localDay &&
            totalSteps == other.totalSteps;
  }

  @override
  int get hashCode => Object.hash(localDay, totalSteps);
}
