import '../../../core/time/local_day_calculator.dart';
import '../../../core/time/time_provider.dart';
import '../../../core/time/timestamp_codec.dart';
import '../../models/normalized_step_bucket.dart';

/// Returns the total steps for the finest resolution present in [byResolution].
///
/// Resolution priority (finest first): 5min → hourly → daily.
/// Prevents double-counting when mixed-resolution rows exist for the same period.
int finestResolutionTotal(Map<String, int> byResolution) {
  for (final resolution in const [
    kFiveMinuteResolution,
    kHourlyResolution,
    kDailyResolution,
  ]) {
    final total = byResolution[resolution];
    if (total != null) {
      return total;
    }
  }
  return 0;
}

/// Conservative UTC window for today's rows before per-row [zone_offset] filtering.
///
/// Uses reference local day ±1 day so extreme offsets (+14/−12) still match
/// [LocalDayCalculator] semantics while excluding aged history via
/// [idx_timeseries_query].
({
  DateTime referenceToday,
  DateTime lowerInclusive,
  DateTime upperExclusive,
})
todaySampleUtcBounds(TimeProvider clock) {
  final timeSnapshot = clock.snapshot();
  final referenceToday = LocalDayCalculator.localDay(
    utc: timeSnapshot.nowUtc,
    zoneOffset: TimestampCodec.formatZoneOffset(timeSnapshot.zoneOffset),
  );
  final bounds = sampleUtcBoundsForLocalDay(referenceToday);
  return (
    referenceToday: bounds.referenceLocalDay,
    lowerInclusive: bounds.lowerInclusive,
    upperExclusive: bounds.upperExclusive,
  );
}

/// UTC query window for [localDay] before per-row [zone_offset] filtering.
({
  DateTime referenceLocalDay,
  DateTime lowerInclusive,
  DateTime upperExclusive,
})
sampleUtcBoundsForLocalDay(DateTime localDay) {
  // Keep the same UTC semantics as [LocalDayCalculator.localDay], otherwise
  // equality checks (DateTime.utc) will fail.
  final referenceLocalDay =
      DateTime.utc(localDay.year, localDay.month, localDay.day);
  return (
    referenceLocalDay: referenceLocalDay,
    lowerInclusive: referenceLocalDay.subtract(const Duration(days: 1)),
    upperExclusive: referenceLocalDay.add(const Duration(days: 2)),
  );
}
