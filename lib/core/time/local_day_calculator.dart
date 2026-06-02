import 'timestamp_codec.dart';

class LocalDayCalculator {
  const LocalDayCalculator._();

  static DateTime localDay({
    required DateTime utc,
    required String zoneOffset,
  }) {
    final localInstant = utc.toUtc().add(
      TimestampCodec.parseZoneOffset(zoneOffset),
    );
    return DateTime.utc(
      localInstant.year,
      localInstant.month,
      localInstant.day,
    );
  }
}
