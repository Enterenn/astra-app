/// Lightweight relative time formatting without the `intl` package.
///
/// Returns human-readable elapsed time from [instantUtc] to [nowUtc].
String formatRelativeTime({
  required DateTime? instantUtc,
  required DateTime nowUtc,
}) {
  if (instantUtc == null) {
    return 'never';
  }

  final elapsed = nowUtc.difference(instantUtc);
  if (elapsed.isNegative) {
    return 'just now';
  }

  final totalMinutes = elapsed.inMinutes;
  if (totalMinutes < 1) {
    return 'just now';
  }
  if (totalMinutes < 60) {
    final label = totalMinutes == 1 ? 'minute' : 'minutes';
    return '$totalMinutes $label ago';
  }

  final totalHours = elapsed.inHours;
  if (totalHours < 24) {
    final label = totalHours == 1 ? 'hour' : 'hours';
    return '$totalHours $label ago';
  }

  final totalDays = elapsed.inDays;
  final label = totalDays == 1 ? 'day' : 'days';
  return '$totalDays $label ago';
}
