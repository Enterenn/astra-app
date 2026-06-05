/// Shared increment math for live display and bucket normalization.
///
/// Cumulative counter semantics: the hardware baseline always advances to the
/// latest reading in callers; phantom steps beyond the rate cap are discarded,
/// not deferred.
///
/// [elapsedSincePrevious] uses inter-arrival time between consecutive
/// `observedAtUtc` values. The `pedometer` package sets `StepCount.timeStamp` to
/// `DateTime.now()` at Dart receipt — delivery latency, not hardware step time.
/// That is acceptable for burst/shake detection.
class StepIncrementCalculator {
  const StepIncrementCalculator();

  /// Maximum physiologically plausible steps credited per second of inter-arrival
  /// time. Human sprint peaks around ~4/s; 5/s adds margin.
  static const int kMaxStepsPerSecond = 5;

  /// Returns the step delta from [baseline] to [current], or null when the
  /// reading should be ignored (sensor noise).
  ///
  /// A large drop is treated as a reboot/reset; small drops are sensor noise.
  /// When [elapsedSincePrevious] is provided, credited delta is capped to
  /// `max(1, ceil(kMaxStepsPerSecond × elapsedMs / 1000))`.
  /// When [elapsedSincePrevious] is null (first increment after baseline seed),
  /// no rate cap is applied.
  int? calculate({
    required int current,
    required int baseline,
    Duration? elapsedSincePrevious,
  }) {
    if (current >= baseline) {
      final rawDelta = current - baseline;
      if (elapsedSincePrevious == null) {
        return rawDelta;
      }
      final maxDelta = _maxDeltaForElapsed(elapsedSincePrevious.inMilliseconds);
      return rawDelta < maxDelta ? rawDelta : maxDelta;
    }

    final resetThreshold = baseline ~/ 2;
    if (current <= resetThreshold) {
      return current;
    }

    return null;
  }

  int _maxDeltaForElapsed(int elapsedMs) {
    final scaled = (kMaxStepsPerSecond * elapsedMs) / 1000.0;
    final capped = scaled.ceil();
    return capped < 1 ? 1 : capped;
  }
}
