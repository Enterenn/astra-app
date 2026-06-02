import 'local_day_calculator.dart';
import 'time_provider.dart';
import 'timestamp_codec.dart';

/// Formats the user's current local calendar day as `YYYY-MM-DD`.
///
/// Uses [TimeSnapshot.zoneOffset] from [TimeProvider.snapshot()] — not device
/// `DateTime.now()` — aligned with [LocalDayCalculator] / [StepRepository.getTodaySteps].
String formatLocalDayIso(TimeSnapshot snapshot) {
  final localDay = LocalDayCalculator.localDay(
    utc: snapshot.nowUtc,
    zoneOffset: TimestampCodec.formatZoneOffset(snapshot.zoneOffset),
  );
  String two(int n) => n.toString().padLeft(2, '0');
  return '${localDay.year}-${two(localDay.month)}-${two(localDay.day)}';
}
