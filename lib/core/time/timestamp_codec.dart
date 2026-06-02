class TimestampCodec {
  const TimestampCodec._();

  static String formatUtc(DateTime value) {
    final utc = value.toUtc();
    if (utc.millisecond != 0 || utc.microsecond != 0) {
      throw FormatException('Timestamp must be second-aligned', value);
    }

    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${twoDigits(utc.month)}-'
        '${twoDigits(utc.day)}T'
        '${twoDigits(utc.hour)}:'
        '${twoDigits(utc.minute)}:'
        '${twoDigits(utc.second)}Z';
  }

  static DateTime parseUtc(String value) {
    if (!value.endsWith('Z')) {
      throw FormatException(
        'Timestamp must be stored as UTC with Z suffix',
        value,
      );
    }
    return DateTime.parse(value).toUtc();
  }

  static String formatZoneOffset(Duration offset) {
    if (offset.inMicroseconds % Duration.microsecondsPerMinute != 0) {
      throw FormatException('Zone offset must be minute-aligned', offset);
    }

    final totalMinutes = offset.inMinutes;
    final sign = totalMinutes < 0 ? '-' : '+';
    final absoluteMinutes = totalMinutes.abs();
    if (absoluteMinutes > 14 * Duration.minutesPerHour) {
      throw FormatException('Invalid zone offset range', offset);
    }

    final hours = absoluteMinutes ~/ 60;
    final minutes = absoluteMinutes % 60;
    return '$sign${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}';
  }

  static Duration parseZoneOffset(String value) {
    final match = RegExp(r'^([+-])(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid zone offset format', value);
    }

    final hours = int.parse(match.group(2)!);
    final minutes = int.parse(match.group(3)!);
    if (minutes > 59) {
      throw FormatException('Invalid zone offset range', value);
    }

    final absoluteMinutes = hours * Duration.minutesPerHour + minutes;
    if (absoluteMinutes > 14 * Duration.minutesPerHour) {
      throw FormatException('Invalid zone offset range', value);
    }

    final duration = Duration(minutes: absoluteMinutes);
    return match.group(1) == '-' ? -duration : duration;
  }
}
