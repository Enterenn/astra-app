import '../../core/time/time_provider.dart';
import '../models/normalized_step_bucket.dart';
import '../models/step_reading.dart';
import 'data_ingestion_source.dart';

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
  const StepNormalizer({required this.clock});

  final TimeProvider clock;

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
    for (final reading in readings) {
      final cumulativeSteps = reading.cumulativeSteps;
      lastCumulative = cumulativeSteps;

      if (baseline == null) {
        baseline = cumulativeSteps;
        continue;
      }

      final increment = _calculateIncrement(
        current: cumulativeSteps,
        baseline: baseline,
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

  int? _calculateIncrement({required int current, required int baseline}) {
    if (current >= baseline) {
      return current - baseline;
    }

    // A large drop is treated as a reboot/reset; small drops are sensor noise.
    final resetThreshold = baseline ~/ 2;
    if (current <= resetThreshold) {
      return current;
    }

    return null;
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
