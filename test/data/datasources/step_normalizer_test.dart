@Tags(['critical'])
library;

import 'dart:async';

import 'package:astra_app/core/metrics/derived_activity_metrics.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/datasources/step_normalizer.dart';
import 'package:astra_app/core/time/time_provider.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/step_reading.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStepSource implements DataIngestionSource {
  _FakeStepSource(this._readings);

  final List<StepReading> _readings;

  @override
  String get providerId => kInternalPhoneProvider;

  @override
  String get deviceId => kSmartphoneDeviceId;

  @override
  Stream<StepReading> watchStepReadings() => Stream.fromIterable(_readings);
}

class _LiveStepSource implements DataIngestionSource {
  _LiveStepSource(this._readings);

  final List<StepReading> _readings;

  @override
  String get providerId => kInternalPhoneProvider;

  @override
  String get deviceId => kSmartphoneDeviceId;

  @override
  Stream<StepReading> watchStepReadings() async* {
    for (final reading in _readings) {
      yield reading;
    }
    await Completer<void>().future;
  }
}

class _SequenceTimeProvider implements TimeProvider {
  _SequenceTimeProvider(this._nowUtcValues);

  final List<DateTime> _nowUtcValues;
  var _index = 0;

  @override
  DateTime nowUtc() {
    final value = _nowUtcValues[_index];
    if (_index < _nowUtcValues.length - 1) {
      _index += 1;
    }
    return value.toUtc();
  }

  @override
  Duration currentZoneOffset() => const Duration(hours: 2);

  @override
  TimeSnapshot snapshot() {
    return TimeSnapshot(nowUtc: nowUtc(), zoneOffset: currentZoneOffset());
  }
}

void main() {
  group('StepNormalizer', () {
    test(
      'converts positive cumulative deltas into UTC 5-minute buckets',
      () async {
        final normalizer = StepNormalizer(
          clock: _SequenceTimeProvider([DateTime.utc(2026, 6, 2, 12)]),
        );
        final source = _FakeStepSource([
          StepReading(
            cumulativeSteps: 10,
            observedAtUtc: DateTime.utc(2026, 6, 2, 7),
          ),
          StepReading(
            cumulativeSteps: 15,
            observedAtUtc: DateTime.utc(2026, 6, 2, 7, 1),
          ),
          StepReading(
            cumulativeSteps: 30,
            observedAtUtc: DateTime.utc(2026, 6, 2, 7, 6),
          ),
        ]);

        final result = await normalizer.normalize(source, maxReadings: 3);
        final buckets = result.buckets;

        expect(buckets, hasLength(2));
        expect(buckets.first.startTimeUtc, DateTime.utc(2026, 6, 2, 7));
        expect(buckets.first.endTimeUtc, DateTime.utc(2026, 6, 2, 7, 5));
        expect(buckets.first.value, 5);
        expect(buckets.last.startTimeUtc, DateTime.utc(2026, 6, 2, 7, 5));
        expect(buckets.last.endTimeUtc, DateTime.utc(2026, 6, 2, 7, 10));
        expect(buckets.last.value, 15);
      },
    );

    test('handles counter reset without producing negative totals', () async {
      final normalizer = StepNormalizer(
        clock: _SequenceTimeProvider([
          DateTime.utc(2026, 6, 2, 7, 1),
          DateTime.utc(2026, 6, 2, 7, 2),
        ]),
      );
      final source = _FakeStepSource([
        StepReading(
          cumulativeSteps: 1000,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7),
        ),
        StepReading(
          cumulativeSteps: 1050,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7, 1),
        ),
        StepReading(
          cumulativeSteps: 200,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7, 2),
        ),
      ]);

      final buckets = (await normalizer.normalize(source, maxReadings: 3)).buckets;

      expect(buckets, hasLength(1));
      expect(buckets.single.value, 250);
      expect(buckets.single.value, isNonNegative);
    });

    test('emits storage-ready step metadata for each bucket', () async {
      final normalizer = StepNormalizer(
        clock: _SequenceTimeProvider([DateTime.utc(2026, 6, 2, 7, 1)]),
      );
      final source = _FakeStepSource([
        StepReading(
          cumulativeSteps: 1,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7),
        ),
        StepReading(
          cumulativeSteps: 3,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7, 1),
        ),
      ]);

      final buckets = (await normalizer.normalize(source, maxReadings: 2)).buckets;
      final bucket = buckets.single;

      expect(bucket.type, kStepSampleType);
      expect(bucket.unit, kStepSampleUnit);
      expect(bucket.resolution, kFiveMinuteResolution);
      expect(bucket.provider, kInternalPhoneProvider);
      expect(bucket.deviceId, kSmartphoneDeviceId);
      expect(bucket.zoneOffset, '+02:00');
    });

    test('uses reading observation time instead of processing time', () async {
      final normalizer = StepNormalizer(
        clock: _SequenceTimeProvider([DateTime.utc(2026, 6, 2, 12)]),
      );
      final readings = [
        StepReading(
          cumulativeSteps: 10,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7),
        ),
        StepReading(
          cumulativeSteps: 15,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7, 1),
        ),
        StepReading(
          cumulativeSteps: 30,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7, 6),
        ),
      ];
      final source = _FakeStepSource(readings);

      final buckets = normalizer.normalizeReadings(
        source: source,
        readings: readings,
      ).buckets;

      expect(buckets, hasLength(2));
      expect(buckets.first.startTimeUtc, DateTime.utc(2026, 6, 2, 7));
      expect(buckets.last.startTimeUtc, DateTime.utc(2026, 6, 2, 7, 5));
    });

    test('bounded stream normalization returns for live streams', () async {
      final normalizer = StepNormalizer(
        clock: _SequenceTimeProvider([DateTime.utc(2026, 6, 2, 7, 1)]),
      );
      final source = _LiveStepSource([
        StepReading(
          cumulativeSteps: 10,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7),
        ),
        StepReading(
          cumulativeSteps: 15,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7, 1),
        ),
      ]);

      final buckets = (await normalizer.normalize(source, maxReadings: 2)).buckets;

      expect(buckets, hasLength(1));
      expect(buckets.single.value, 5);
    });

    test(
      'applies persisted baseline when only one new reading is available',
      () {
        final normalizer = StepNormalizer(
          clock: _SequenceTimeProvider([DateTime.utc(2026, 6, 2, 7, 1)]),
        );
        final readings = [
          StepReading(
            cumulativeSteps: 5100,
            observedAtUtc: DateTime.utc(2026, 6, 2, 7, 1),
          ),
        ];
        final source = _FakeStepSource(readings);

        final result = normalizer.normalizeReadings(
          source: source,
          readings: readings,
          initialBaseline: 5000,
        );

        expect(result.buckets, hasLength(1));
        expect(result.buckets.single.value, 100);
        expect(result.terminalBaseline, 5100);
      },
    );

    test('rate-limits shake burst so buckets do not store full phantom jump', () {
      final normalizer = StepNormalizer(
        clock: _SequenceTimeProvider([DateTime.utc(2026, 6, 2, 7, 1)]),
      );
      final t0 = DateTime.utc(2026, 6, 2, 7);
      final readings = [
        StepReading(cumulativeSteps: 1000, observedAtUtc: t0),
        StepReading(
          cumulativeSteps: 1050,
          observedAtUtc: t0.add(const Duration(milliseconds: 200)),
        ),
      ];
      final source = _FakeStepSource(readings);

      final result = normalizer.normalizeReadings(
        source: source,
        readings: readings,
      );

      expect(result.buckets, hasLength(1));
      expect(result.buckets.single.value, 1);
      expect(result.terminalBaseline, 1050);
    });

    test('rejects small counter dips as glitches', () async {
      final normalizer = StepNormalizer(
        clock: _SequenceTimeProvider([DateTime.utc(2026, 6, 2, 7, 1)]),
      );
      final source = _FakeStepSource([
        StepReading(
          cumulativeSteps: 1000,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7),
        ),
        StepReading(
          cumulativeSteps: 1050,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7, 1),
        ),
        StepReading(
          cumulativeSteps: 1049,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7, 2),
        ),
        StepReading(
          cumulativeSteps: 1055,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7, 3),
        ),
      ]);

      final buckets = (await normalizer.normalize(source, maxReadings: 4)).buckets;

      expect(buckets, hasLength(1));
      expect(buckets.single.value, 55);
    });

    test('same local day gap keeps single bucket at reading time', () {
      final normalizer = StepNormalizer(
        clock: _SequenceTimeProvider([DateTime.utc(2026, 6, 2, 7, 1)]),
      );
      final readings = [
        StepReading(
          cumulativeSteps: 1000,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7),
        ),
        StepReading(
          cumulativeSteps: 1100,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7, 30),
        ),
      ];
      final source = _FakeStepSource(readings);

      final result = normalizer.normalizeReadings(
        source: source,
        readings: readings,
      );

      expect(result.buckets, hasLength(1));
      expect(result.buckets.single.startTimeUtc, DateTime.utc(2026, 6, 2, 7, 30));
      expect(result.buckets.single.value, 100);
    });

    test('splits increment proportionally when gap crosses local midnight', () {
      final normalizer = StepNormalizer(
        clock: _SequenceTimeProvider([DateTime.utc(2026, 6, 2, 6)]),
      );
      final mondayLate = DateTime.utc(2026, 6, 1, 21, 50);
      final tuesdayMorning = DateTime.utc(2026, 6, 2, 6);
      final readings = [
        StepReading(cumulativeSteps: 1000, observedAtUtc: mondayLate),
        StepReading(cumulativeSteps: 15000, observedAtUtc: tuesdayMorning),
      ];
      final source = _FakeStepSource(readings);

      final result = normalizer.normalizeReadings(
        source: source,
        readings: readings,
      );

      expect(result.buckets, hasLength(2));
      final mondayBucket = result.buckets.firstWhere(
        (b) => b.startTimeUtc.isBefore(DateTime.utc(2026, 6, 1, 22)),
      );
      final tuesdayBucket = result.buckets.firstWhere(
        (b) => !b.startTimeUtc.isBefore(DateTime.utc(2026, 6, 2)),
      );
      expect(mondayBucket.value, greaterThan(0));
      expect(tuesdayBucket.value, greaterThan(0));
      expect(
        mondayBucket.value + tuesdayBucket.value,
        14000,
      );
      expect(mondayBucket.startTimeUtc, DateTime.utc(2026, 6, 1, 21, 50));
      expect(tuesdayBucket.startTimeUtc, DateTime.utc(2026, 6, 2, 6));
    });

    test('distributes increment across multiple days without collect gap', () {
      final normalizer = StepNormalizer(
        clock: _SequenceTimeProvider([DateTime.utc(2026, 6, 4, 6)]),
      );
      final readings = [
        StepReading(
          cumulativeSteps: 500,
          observedAtUtc: DateTime.utc(2026, 6, 1, 21, 50),
        ),
        StepReading(
          cumulativeSteps: 3500,
          observedAtUtc: DateTime.utc(2026, 6, 4, 6),
        ),
      ];
      final source = _FakeStepSource(readings);

      final result = normalizer.normalizeReadings(
        source: source,
        readings: readings,
      );

      expect(result.buckets.length, greaterThanOrEqualTo(3));
      expect(
        result.buckets.fold<int>(0, (sum, bucket) => sum + bucket.value),
        3000,
      );
      final localDays = result.buckets.map((bucket) {
        final local = bucket.startTimeUtc.add(const Duration(hours: 2));
        return DateTime.utc(local.year, local.month, local.day);
      }).toSet();
      expect(localDays.length, greaterThanOrEqualTo(3));
    });

    test('terminalBaseline reflects last accepted baseline not rejected reading', () {
      final normalizer = StepNormalizer(
        clock: _SequenceTimeProvider([DateTime.utc(2026, 6, 2, 7, 3)]),
      );
      final readings = [
        StepReading(
          cumulativeSteps: 1000,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7),
        ),
        StepReading(
          cumulativeSteps: 1050,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7, 1),
        ),
        StepReading(
          cumulativeSteps: 1049,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7, 2),
        ),
      ];
      final source = _FakeStepSource(readings);

      final result = normalizer.normalizeReadings(
        source: source,
        readings: readings,
      );

      expect(result.terminalBaseline, 1050);
      expect(result.buckets.single.value, 50);
    });

    test('midnight split enables more accurate walking time estimate', () {
      final normalizer = StepNormalizer(
        clock: _SequenceTimeProvider([DateTime.utc(2026, 6, 2, 6)]),
      );
      final readings = [
        StepReading(
          cumulativeSteps: 1000,
          observedAtUtc: DateTime.utc(2026, 6, 1, 21, 50),
        ),
        StepReading(
          cumulativeSteps: 15000,
          observedAtUtc: DateTime.utc(2026, 6, 2, 6),
        ),
      ];
      final source = _FakeStepSource(readings);

      final result = normalizer.normalizeReadings(
        source: source,
        readings: readings,
      );

      final activeBuckets = result.buckets
          .map(
            (bucket) => TimeseriesSampleModel(
              id: bucket.startTimeUtc.toIso8601String(),
              startTimeUtc: bucket.startTimeUtc,
              endTimeUtc: bucket.endTimeUtc,
              type: bucket.type,
              value: bucket.value,
              unit: bucket.unit,
              resolution: bucket.resolution,
              provider: bucket.provider,
              deviceId: bucket.deviceId,
              zoneOffset: bucket.zoneOffset,
            ),
          )
          .toList();

      final metrics = DerivedActivityMetrics.compute(
        displaySteps: 14000,
        activeBuckets: activeBuckets,
      );

      expect(
        metrics.walkingDuration.inMinutes,
        greaterThan(5),
      );
    });
  });
}
