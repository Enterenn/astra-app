import 'dart:async';

import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/datasources/step_normalizer.dart';
import 'package:astra_app/core/time/time_provider.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/step_reading.dart';
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

        final buckets = await normalizer.normalize(source, maxReadings: 3);

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

      final buckets = await normalizer.normalize(source, maxReadings: 3);

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

      final buckets = await normalizer.normalize(source, maxReadings: 2);
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
      );

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

      final buckets = await normalizer.normalize(source, maxReadings: 2);

      expect(buckets, hasLength(1));
      expect(buckets.single.value, 5);
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

      final buckets = await normalizer.normalize(source, maxReadings: 4);

      expect(buckets, hasLength(1));
      expect(buckets.single.value, 55);
    });
  });
}
