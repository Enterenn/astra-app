import 'local_day_calculator.dart';
import 'local_day_formatter.dart';
import 'time_provider.dart';
import 'timestamp_codec.dart';

/// Returns the ISO local-day key (`YYYY-MM-DD`) for [snapshot].
String localDayIsoFromSnapshot(TimeSnapshot snapshot) {
  return formatLocalDayIso(snapshot);
}

/// Whether the local calendar day changed between [previousDayIso] and [snapshot].
bool hasLocalDayChanged({
  required String? previousDayIso,
  required TimeSnapshot snapshot,
}) {
  if (previousDayIso == null) {
    return false;
  }
  return previousDayIso != localDayIsoFromSnapshot(snapshot);
}

/// Duration from [snapshot.nowUtc] until the next local midnight.
Duration untilNextLocalMidnight(TimeSnapshot snapshot) {
  final zoneOffset = TimestampCodec.formatZoneOffset(snapshot.zoneOffset);
  final localDay = LocalDayCalculator.localDay(
    utc: snapshot.nowUtc,
    zoneOffset: zoneOffset,
  );
  final offset = TimestampCodec.parseZoneOffset(zoneOffset);
  final nextLocalMidnightUtc = DateTime.utc(
    localDay.year,
    localDay.month,
    localDay.day,
  ).add(const Duration(days: 1)).subtract(offset);

  final remaining = nextLocalMidnightUtc.difference(snapshot.nowUtc);
  if (remaining.isNegative || remaining == Duration.zero) {
    return Duration.zero;
  }
  return remaining;
}
