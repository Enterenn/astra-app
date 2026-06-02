class StepReading {
  StepReading({required this.cumulativeSteps, required DateTime observedAtUtc})
    : observedAtUtc = observedAtUtc.toUtc() {
    if (cumulativeSteps < 0) {
      throw ArgumentError.value(
        cumulativeSteps,
        'cumulativeSteps',
        'must be non-negative',
      );
    }
  }

  final int cumulativeSteps;
  final DateTime observedAtUtc;
}
