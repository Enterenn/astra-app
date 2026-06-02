class LocalDayCalculator {
  const LocalDayCalculator._();

  static DateTime localDay({
    required DateTime utc,
    required String zoneOffset,
  }) {
    final localInstant = utc.toUtc().add(_parseZoneOffset(zoneOffset));
    return DateTime.utc(
      localInstant.year,
      localInstant.month,
      localInstant.day,
    );
  }

  static Duration _parseZoneOffset(String value) {
    final match = RegExp(r'^([+-])(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid zone offset format', value);
    }

    final hours = int.parse(match.group(2)!);
    final minutes = int.parse(match.group(3)!);
    if (hours > 23 || minutes > 59) {
      throw FormatException('Invalid zone offset range', value);
    }

    final duration = Duration(hours: hours, minutes: minutes);
    return match.group(1) == '-' ? -duration : duration;
  }
}
