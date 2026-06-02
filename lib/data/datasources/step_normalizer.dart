import '../../core/time/time_provider.dart';
import '../models/normalized_step_bucket.dart';
import 'data_ingestion_source.dart';

class StepNormalizer {
  const StepNormalizer({required this.clock});

  final TimeProvider clock;

  Future<List<NormalizedStepBucket>> normalize(
    DataIngestionSource source,
  ) async {
    final bucketValues = <DateTime, int>{};
    final zoneOffset = _formatZoneOffset(clock.currentZoneOffset());

    int? baseline;
    await for (final reading in source.watchStepReadings()) {
      final cumulativeSteps = reading.cumulativeSteps;

      if (baseline == null) {
        baseline = cumulativeSteps;
        continue;
      }

      final increment = cumulativeSteps >= baseline
          ? cumulativeSteps - baseline
          : cumulativeSteps;
      baseline = cumulativeSteps;

      if (increment <= 0) {
        continue;
      }

      // Buckets are aligned to absolute UTC 5-minute boundaries from the
      // injected clock so normalization stays deterministic in tests.
      final bucketStartUtc = _floorToFiveMinuteUtc(clock.nowUtc());
      bucketValues.update(
        bucketStartUtc,
        (value) => value + increment,
        ifAbsent: () => increment,
      );
    }

    return [
      for (final entry in bucketValues.entries)
        NormalizedStepBucket(
          startTimeUtc: entry.key,
          endTimeUtc: entry.key.add(const Duration(minutes: 5)),
          value: entry.value,
          provider: source.providerId,
          deviceId: source.deviceId,
          zoneOffset: zoneOffset,
        ),
    ];
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
