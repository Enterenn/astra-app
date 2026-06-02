/// Evaluates whether step ingestion data is stale per platform thresholds.
///
/// Android: 12 hours — avoids false stale after overnight sleep.
/// iOS: 4 hours — honest backfill model without WorkManager parity.
bool isStaleData({
  required DateTime? lastIngestionUtc,
  required DateTime nowUtc,
  required bool isIos,
}) {
  if (lastIngestionUtc == null) {
    return false;
  }
  final threshold = isIos ? const Duration(hours: 4) : const Duration(hours: 12);
  return nowUtc.difference(lastIngestionUtc) > threshold;
}
