import '../../../core/time/local_day_calculator.dart';
import '../../../core/time/time_provider.dart';
import '../../../core/time/timestamp_codec.dart';
import '../../models/chart_day_aggregate.dart';
import '../../models/chart_month_aggregate.dart';
import '../../models/normalized_step_bucket.dart';
import '../../models/timeseries_sample_model.dart';
import '_step_sample_bounds.dart';

// Exclusive upper bound aligns with sampleUtcBoundsForLocalDay buffer (+2 days).
const chartSamplesWhereClause =
    'type = ? AND start_time >= ? AND start_time < ?';

List<Object?> chartSamplesWhereArgs({
  required DateTime sqlLowerBoundUtc,
  required DateTime sqlUpperBoundUtc,
}) =>
    [
      kStepSampleType,
      TimestampCodec.formatUtc(sqlLowerBoundUtc),
      TimestampCodec.formatUtc(sqlUpperBoundUtc),
    ];

({
  DateTime referenceToday,
  DateTime windowStart,
  DateTime sqlLowerBoundUtc,
  DateTime sqlUpperBoundUtc,
})
dailyChartQueryBounds({required int days, required TimeProvider clock}) {
  final timeSnapshot = clock.snapshot();
  final referenceToday = LocalDayCalculator.localDay(
    utc: timeSnapshot.nowUtc,
    zoneOffset: TimestampCodec.formatZoneOffset(timeSnapshot.zoneOffset),
  );
  final windowStart = referenceToday.subtract(Duration(days: days - 1));
  // Mirrors sampleUtcBoundsForLocalDay(windowStart).lowerInclusive — see
  // _step_sample_bounds.dart buffer contract (±1 / +2 day UTC envelope).
  final sqlLowerBoundUtc = windowStart.subtract(const Duration(days: 1));
  final sqlUpperBoundUtc =
      sampleUtcBoundsForLocalDay(referenceToday).upperExclusive;
  return (
    referenceToday: referenceToday,
    windowStart: windowStart,
    sqlLowerBoundUtc: sqlLowerBoundUtc,
    sqlUpperBoundUtc: sqlUpperBoundUtc,
  );
}

({
  DateTime referenceToday,
  DateTime windowStart,
  DateTime sqlLowerBoundUtc,
  DateTime sqlUpperBoundUtc,
})
monthlyChartQueryBounds({required int months, required TimeProvider clock}) {
  final timeSnapshot = clock.snapshot();
  final referenceToday = LocalDayCalculator.localDay(
    utc: timeSnapshot.nowUtc,
    zoneOffset: TimestampCodec.formatZoneOffset(timeSnapshot.zoneOffset),
  );
  // Intentional DateTime.utc month rollover — Dart normalizes month <= 0
  // (e.g. June minus 11 months → July prior year). Do not replace with manual
  // year/month splitting; chart tests depend on this normalization.
  final windowStart = DateTime.utc(
    referenceToday.year,
    referenceToday.month - (months - 1),
    1,
  );
  final sqlLowerBoundUtc = windowStart.subtract(const Duration(days: 1));
  final sqlUpperBoundUtc =
      sampleUtcBoundsForLocalDay(referenceToday).upperExclusive;
  return (
    referenceToday: referenceToday,
    windowStart: windowStart,
    sqlLowerBoundUtc: sqlLowerBoundUtc,
    sqlUpperBoundUtc: sqlUpperBoundUtc,
  );
}

Map<DateTime, Map<String, int>> accumulateStepsByDayAndResolution({
  required List<Map<String, Object?>> rows,
  required DateTime windowStart,
  required DateTime referenceToday,
}) {
  final byDayAndResolution = <DateTime, Map<String, int>>{};
  for (final row in rows) {
    final sample = TimeseriesSampleModel.fromMap(row);
    final rowLocalDay = LocalDayCalculator.localDay(
      utc: sample.startTimeUtc,
      zoneOffset: sample.zoneOffset,
    );
    if (rowLocalDay.isBefore(windowStart) || rowLocalDay.isAfter(referenceToday)) {
      continue;
    }
    byDayAndResolution
        .putIfAbsent(rowLocalDay, () => {})
        .update(
          sample.resolution,
          (v) => v + sample.value.toInt(),
          ifAbsent: () => sample.value.toInt(),
        );
  }
  return byDayAndResolution;
}

List<ChartDayAggregate> chartDailyAggregatesFromRows({
  required List<Map<String, Object?>> rows,
  required DateTime referenceToday,
  required DateTime windowStart,
  required int days,
}) {
  final byDayAndResolution = accumulateStepsByDayAndResolution(
    rows: rows,
    windowStart: windowStart,
    referenceToday: referenceToday,
  );

  final results = <ChartDayAggregate>[];
  for (var i = 0; i < days; i++) {
    final day = referenceToday.subtract(Duration(days: i));
    results.add(
      ChartDayAggregate(
        localDay: day,
        totalSteps: finestResolutionTotal(byDayAndResolution[day] ?? {}),
      ),
    );
  }
  return results;
}

List<ChartMonthAggregate> chartMonthlyAggregatesFromRows({
  required List<Map<String, Object?>> rows,
  required DateTime referenceToday,
  required DateTime windowStart,
  required int months,
}) {
  final byDayAndResolution = accumulateStepsByDayAndResolution(
    rows: rows,
    windowStart: windowStart,
    referenceToday: referenceToday,
  );

  final results = <ChartMonthAggregate>[];
  for (var monthOffset = 0; monthOffset < months; monthOffset++) {
    // Month iteration via DateTime.utc rollover — same normalization as
    // monthlyChartQueryBounds; do not replace with manual year/month math.
    final monthStart = DateTime.utc(
      referenceToday.year,
      referenceToday.month - monthOffset,
      1,
    );
    final monthEnd = monthOffset == 0
        ? referenceToday
        // day 0 of next month = last calendar day of monthStart's month.
        // Intentional DateTime.utc rollover — do not replace with manual month math.
        : DateTime.utc(monthStart.year, monthStart.month + 1, 0);

    var totalSteps = 0;
    var dayCount = 0;
    var day = monthStart;
    while (!day.isAfter(monthEnd)) {
      totalSteps += finestResolutionTotal(byDayAndResolution[day] ?? {});
      dayCount++;
      day = day.add(const Duration(days: 1));
    }

    results.add(
      ChartMonthAggregate(
        monthStart: monthStart,
        averageDailySteps: dayCount > 0 ? (totalSteps / dayCount).round() : 0,
        totalSteps: totalSteps,
        dayCount: dayCount,
      ),
    );
  }
  return results;
}
