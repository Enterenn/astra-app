import 'package:astra_app/l10n/app_localizations.dart';

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

/// Localized relative time using [AppLocalizations] ARB keys.
String formatRelativeTimeLocalized(
  AppLocalizations l10n, {
  required DateTime? instantUtc,
  required DateTime nowUtc,
}) {
  if (instantUtc == null) {
    return l10n.relativeTimeNever;
  }

  final elapsed = nowUtc.difference(instantUtc);
  if (elapsed.isNegative) {
    return l10n.relativeTimeJustNow;
  }

  final totalMinutes = elapsed.inMinutes;
  if (totalMinutes < 1) {
    return l10n.relativeTimeJustNow;
  }
  if (totalMinutes < 60) {
    return l10n.relativeTimeMinutesAgo(totalMinutes);
  }

  final totalHours = elapsed.inHours;
  if (totalHours < 24) {
    return l10n.relativeTimeHoursAgo(totalHours);
  }

  return l10n.relativeTimeDaysAgo(elapsed.inDays);
}
