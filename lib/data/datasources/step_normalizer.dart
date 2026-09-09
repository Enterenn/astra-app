import '../../core/lifecycle/lifecycle_compaction.dart';
import '../../core/time/local_day_calculator.dart';
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

/// Converts cumulative step readings into 5-minute [NormalizedStepBucket] increments.
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
    DateTime? lastIngestionUtc,
  }) async {
    final readings = await source
        .watchStepReadings()
        .take(maxReadings)
        .toList();
    return normalizeReadings(
      source: source,
      readings: readings,
      initialBaseline: initialBaseline,
      lastIngestionUtc: lastIngestionUtc,
    );
  }

  StepNormalizationResult normalizeReadings({
    required DataIngestionSource source,
    required Iterable<StepReading> readings,
    int? initialBaseline,
    DateTime? lastIngestionUtc,
  }) {
    final bucketValues = <DateTime, int>{};
    final zoneOffset = _formatZoneOffset(clock.currentZoneOffset());

    int? baseline = initialBaseline;
    DateTime? previousObservedAtUtc = lastIngestionUtc;
    for (final reading in readings) {
      final cumulativeSteps = reading.cumulativeSteps;

      if (baseline == null) {
        baseline = cumulativeSteps;
        previousObservedAtUtc = reading.observedAtUtc;
        continue;
      }

      final isHardwareReset = cumulativeSteps < baseline;
      final intervalStartUtc = isHardwareReset
          ? null
          : _intervalStartBefore(previousObservedAtUtc, reading.observedAtUtc);
      final elapsedSincePrevious = intervalStartUtc == null
          ? null
          : reading.observedAtUtc.difference(intervalStartUtc);
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

      if (intervalStartUtc == null) {
        _creditBucket(
          bucketValues,
          _floorToFiveMinuteUtc(reading.observedAtUtc),
          increment,
        );
      } else {
        _creditIncrementAcrossLocalDays(
          bucketValues: bucketValues,
          increment: increment,
          intervalStartUtc: intervalStartUtc,
          intervalEndUtc: reading.observedAtUtc,
          zoneOffset: zoneOffset,
        );
      }
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
      terminalBaseline: baseline ?? initialBaseline,
    );
  }

  DateTime? _intervalStartBefore(DateTime? start, DateTime end) {
    if (start == null || !start.isBefore(end)) {
      return null;
    }
    return start;
  }

  void _creditIncrementAcrossLocalDays({
    required Map<DateTime, int> bucketValues,
    required int increment,
    required DateTime intervalStartUtc,
    required DateTime intervalEndUtc,
    required String zoneOffset,
  }) {
    final totalElapsedMs =
        intervalEndUtc.difference(intervalStartUtc).inMilliseconds;
    if (totalElapsedMs <= 0) {
      _creditBucket(
        bucketValues,
        _floorToFiveMinuteUtc(intervalEndUtc),
        increment,
      );
      return;
    }

    final startLocalDay = LocalDayCalculator.localDay(
      utc: intervalStartUtc,
      zoneOffset: zoneOffset,
    );
    final endLocalDay = LocalDayCalculator.localDay(
      utc: intervalEndUtc,
      zoneOffset: zoneOffset,
    );

    if (startLocalDay == endLocalDay) {
      _creditBucket(
        bucketValues,
        _floorToFiveMinuteUtc(intervalEndUtc),
        increment,
      );
      return;
    }

    var segmentStart = intervalStartUtc;
    var currentLocalDay = startLocalDay;
    var allocated = 0;
    var segmentIndex = 0;

    while (true) {
      final nextLocalDay = currentLocalDay.add(const Duration(days: 1));
      final nextMidnightUtc = localBucketStartUtc(
        localBucket: nextLocalDay,
        zoneOffset: zoneOffset,
      );

      final isLastSegment = !nextMidnightUtc.isBefore(intervalEndUtc);
      final segmentEnd = isLastSegment ? intervalEndUtc : nextMidnightUtc;
      final segmentElapsedMs =
          segmentEnd.difference(segmentStart).inMilliseconds;

      final portion = isLastSegment
          ? increment - allocated
          : ((increment * segmentElapsedMs) / totalElapsedMs).round();

      if (portion > 0) {
        _creditBucket(
          bucketValues,
          _bucketForDaySegment(
            segmentStartUtc: segmentStart,
            segmentEndUtc: segmentEnd,
            zoneOffset: zoneOffset,
            isFirstSegment: segmentIndex == 0,
            isLastSegment: isLastSegment,
          ),
          portion,
        );
      }

      allocated += portion;

      if (isLastSegment) {
        break;
      }

      segmentStart = nextMidnightUtc;
      currentLocalDay = nextLocalDay;
      segmentIndex += 1;
    }
  }

  DateTime _bucketForDaySegment({
    required DateTime segmentStartUtc,
    required DateTime segmentEndUtc,
    required String zoneOffset,
    required bool isFirstSegment,
    required bool isLastSegment,
  }) {
    if (isLastSegment) {
      return _floorToFiveMinuteUtc(segmentEndUtc);
    }
    if (isFirstSegment) {
      return _floorToFiveMinuteUtc(segmentStartUtc);
    }

    final localDay = LocalDayCalculator.localDay(
      utc: segmentStartUtc,
      zoneOffset: zoneOffset,
    );
    final noonLocal = DateTime.utc(
      localDay.year,
      localDay.month,
      localDay.day,
      12,
    );
    return localBucketStartUtc(
      localBucket: noonLocal,
      zoneOffset: zoneOffset,
    );
  }

  void _creditBucket(
    Map<DateTime, int> bucketValues,
    DateTime bucketStartUtc,
    int increment,
  ) {
    bucketValues.update(
      bucketStartUtc,
      (value) => value + increment,
      ifAbsent: () => increment,
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
