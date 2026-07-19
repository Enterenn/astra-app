import 'timestamp_codec.dart';

/// Derives the local calendar day (UTC midnight) from a UTC sample and stored zone offset.
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
