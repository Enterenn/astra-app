class TimestampCodec {
  const TimestampCodec._();

  static String formatUtc(DateTime value) {
    final utc = value.toUtc();
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
    final totalMinutes = offset.inMinutes;
    final sign = totalMinutes < 0 ? '-' : '+';
    final absoluteMinutes = totalMinutes.abs();
    final hours = absoluteMinutes ~/ 60;
    final minutes = absoluteMinutes % 60;
    return '$sign${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}';
  }
}
