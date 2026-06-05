import '../../core/time/time_provider.dart';
import '../models/normalized_step_bucket.dart';
import '../models/step_reading.dart';
import 'data_ingestion_source.dart';
import 'step_increment_calculator.dart';

/// Output of [StepNormalizer.normalize] / [StepNormalizer.normalizeReadings].
class StepNormalizationResult {
  const StepNormalizationResult({
    required this.buckets,
    this.terminalBaseline,
  });

  final List<NormalizedStepBucket> buckets;

  /// Last cumulative counter observed, for persistence across collection runs.
  final int? terminalBaseline;
}

class StepNormalizer {
  const StepNormalizer({
    required this.clock,
    this.incrementCalculator = const StepIncrementCalculator(),
  });

  final TimeProvider clock;
  final StepIncrementCalculator incrementCalculator;

  Future<StepNormalizationResult> normalize(
    DataIngestionSource source, {
    required int maxReadings,
    int? initialBaseline,
  }) async {
    final readings = await source
        .watchStepReadings()
        .take(maxReadings)
        .toList();
    return normalizeReadings(
      source: source,
      readings: readings,
      initialBaseline: initialBaseline,
    );
  }

  StepNormalizationResult normalizeReadings({
    required DataIngestionSource source,
    required Iterable<StepReading> readings,
    int? initialBaseline,
  }) {
    final bucketValues = <DateTime, int>{};
    final zoneOffset = _formatZoneOffset(clock.currentZoneOffset());

    int? baseline = initialBaseline;
    int? lastCumulative;
    DateTime? previousObservedAtUtc;
    for (final reading in readings) {
      final cumulativeSteps = reading.cumulativeSteps;
      lastCumulative = cumulativeSteps;

      if (baseline == null) {
        baseline = cumulativeSteps;
        previousObservedAtUtc = reading.observedAtUtc;
        continue;
      }

      final elapsedSincePrevious = previousObservedAtUtc == null
          ? null
          : reading.observedAtUtc.difference(previousObservedAtUtc);
      previousObservedAtUtc = reading.observedAtUtc;

      final increment = incrementCalculator.calculate(
        current: cumulativeSteps,
        baseline: baseline,
        elapsedSincePrevious: elapsedSincePrevious,
      );

      if (increment == null) {
        continue;
      }

      baseline = cumulativeSteps;

      if (increment <= 0) {
        continue;
      }

      final bucketStartUtc = _floorToFiveMinuteUtc(reading.observedAtUtc);
      bucketValues.update(
        bucketStartUtc,
        (value) => value + increment,
        ifAbsent: () => increment,
      );
    }

    return StepNormalizationResult(
      buckets: [
        for (final entry in bucketValues.entries)
          NormalizedStepBucket(
            startTimeUtc: entry.key,
            endTimeUtc: entry.key.add(const Duration(minutes: 5)),
            value: entry.value,
            provider: source.providerId,
            deviceId: source.deviceId,
            zoneOffset: zoneOffset,
          ),
      ],
      terminalBaseline: lastCumulative ?? initialBaseline,
    );
  }

  DateTime _floorToFiveMinuteUtc(DateTime value) {
    final utc = value.toUtc();
    return DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute - (utc.minute % 5),
    );
  }

  String _formatZoneOffset(Duration offset) {
    final totalMinutes = offset.inMinutes;
    final sign = totalMinutes < 0 ? '-' : '+';
    final absoluteMinutes = totalMinutes.abs();
    final hours = absoluteMinutes ~/ 60;
    final minutes = absoluteMinutes % 60;
    return '$sign${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}';
  }
}
