class StepReading {
  StepReading({required this.cumulativeSteps, required DateTime observedAtUtc})
    : observedAtUtc = observedAtUtc.toUtc() {
    assert(cumulativeSteps >= 0, 'cumulativeSteps must be non-negative');
  }

  final int cumulativeSteps;
  final DateTime observedAtUtc;
}
