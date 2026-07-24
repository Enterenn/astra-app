/// Shared increment math for live display and bucket normalization.
///
/// Cumulative counter semantics: the hardware baseline always advances to the
/// latest reading in callers; phantom steps beyond the rate cap are discarded,
/// not deferred.
///
/// Persist drain pre-filter: [shouldForwardForPersistence] — no rate cap.
/// Live UI and bucket credit: [calculate] — includes rate cap when elapsed is set.
///
/// [elapsedSincePrevious] uses inter-arrival time between consecutive
/// `observedAtUtc` values. The `pedometer` package sets `StepCount.timeStamp` to
/// `DateTime.now()` at Dart receipt — delivery latency, not hardware step time.
/// That is acceptable for burst/shake detection.
class StepIncrementCalculator {
  const StepIncrementCalculator({this.rateLimitEnabled = kRateLimitEnabled});

  /// When false, [calculate] returns the raw delta even when
  /// [elapsedSincePrevious] is set. Defaults to [kRateLimitEnabled].
  final bool rateLimitEnabled;

  /// Maximum physiologically plausible steps credited per second of inter-arrival
  /// time. Human sprint peaks around ~4/s; 5/s adds margin.
  static const int kMaxStepsPerSecond = 5;

  /// Field A/B shake test: build with
  /// `--dart-define=STEP_RATE_LIMIT_ENABLED=false` to disable the cap.
  static const bool kRateLimitEnabled = bool.fromEnvironment(
    'STEP_RATE_LIMIT_ENABLED',
    defaultValue: true,
  );

  /// Returns the step delta from [baseline] to [current], or null when the
  /// reading should be ignored (sensor noise).
  ///
  /// A large drop is treated as a reboot/reset; small drops are sensor noise.
  /// When [elapsedSincePrevious] is provided, credited delta is capped to
  /// `max(1, ceil(kMaxStepsPerSecond × elapsedMs / 1000))`.
  /// When [elapsedSincePrevious] is null (first increment after baseline seed),
  /// no rate cap is applied.
  ///
  /// For persist drain gating use [shouldForwardForPersistence] instead — it
  /// uses strict `>` at baseline (anti double-credit) and skips rate limiting.
  int? calculate({
    required int current,
    required int baseline,
    Duration? elapsedSincePrevious,
  }) {
    if (current >= baseline) {
      final rawDelta = current - baseline;
      if (elapsedSincePrevious == null || !rateLimitEnabled) {
        return rawDelta;
      }
      final maxDelta = _maxDeltaForElapsed(elapsedSincePrevious.inMilliseconds);
      return rawDelta < maxDelta ? rawDelta : maxDelta;
    }

    final resetThreshold = _hardwareResetThreshold(baseline);
    if (current <= resetThreshold) {
      return current;
    }

    return null;
  }

  /// Whether [current] should leave the monitor drain and enter the persist
  /// pipeline (normalizer → collector). Does not apply rate limiting — that
  /// remains in [calculate] for live UI and bucket credit.
  ///
  /// Intentional difference vs [calculate]: uses strict `>` at baseline so
  /// readings exactly at persisted baseline are dropped before normalizer
  /// (anti double-credit); [calculate] returns `0` at equality which the
  /// normalizer skips anyway.
  bool shouldForwardForPersistence({
    required int current,
    required int baseline,
  }) {
    if (current > baseline) return true;
    if (current <= _hardwareResetThreshold(baseline)) return true;
    return false;
  }

  int _hardwareResetThreshold(int baseline) => baseline ~/ 2;

  int _maxDeltaForElapsed(int elapsedMs) {
    if (elapsedMs <= 0) {
      return 1;
    }
    final scaled = (kMaxStepsPerSecond * elapsedMs) / 1000.0;
    final capped = scaled.ceil();
    return capped < 1 ? 1 : capped;
  }
}
