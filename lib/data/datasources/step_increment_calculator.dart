/// Shared increment math for live display and bucket normalization.
class StepIncrementCalculator {
  const StepIncrementCalculator();

  /// Returns the step delta from [baseline] to [current], or null when the
  /// reading should be ignored (sensor noise).
  ///
  /// A large drop is treated as a reboot/reset; small drops are sensor noise.
  int? calculate({required int current, required int baseline}) {
    if (current >= baseline) {
      return current - baseline;
    }

    final resetThreshold = baseline ~/ 2;
    if (current <= resetThreshold) {
      return current;
    }

    return null;
  }
}
