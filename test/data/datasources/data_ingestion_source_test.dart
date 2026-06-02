import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/step_reading.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeIngestionSource implements DataIngestionSource {
  _FakeIngestionSource(this._readings);

  final List<StepReading> _readings;

  @override
  String get providerId => kInternalPhoneProvider;

  @override
  String get deviceId => kSmartphoneDeviceId;

  @override
  Stream<StepReading> watchStepReadings() => Stream.fromIterable(_readings);
}

void main() {
  group('ingestion contract models', () {
    test('StepReading stores cumulative steps with UTC observation time', () {
      final reading = StepReading(
        cumulativeSteps: 1234,
        observedAtUtc: DateTime.parse('2026-06-02T09:00:00+02:00'),
      );

      expect(reading.cumulativeSteps, 1234);
      expect(reading.observedAtUtc.isUtc, isTrue);
      expect(
        reading.observedAtUtc.toIso8601String(),
        '2026-06-02T07:00:00.000Z',
      );
    });

    test('NormalizedStepBucket is storage-ready but does not own an id', () {
      final bucket = NormalizedStepBucket(
        startTimeUtc: DateTime.parse('2026-06-02T07:00:00Z'),
        endTimeUtc: DateTime.parse('2026-06-02T07:05:00Z'),
        value: 42,
        provider: kInternalPhoneProvider,
        deviceId: kSmartphoneDeviceId,
        zoneOffset: '+02:00',
      );

      expect(bucket.type, kStepSampleType);
      expect(bucket.unit, kStepSampleUnit);
      expect(bucket.resolution, kFiveMinuteResolution);
      expect(bucket.provider, kInternalPhoneProvider);
      expect(bucket.deviceId, kSmartphoneDeviceId);
      expect(bucket.value, 42);
    });

    test(
      'DataIngestionSource emits raw cumulative readings with metadata',
      () async {
        final reading = StepReading(
          cumulativeSteps: 10,
          observedAtUtc: DateTime.utc(2026, 6, 2, 7),
        );
        final source = _FakeIngestionSource([reading]);

        expect(source.providerId, kInternalPhoneProvider);
        expect(source.deviceId, kSmartphoneDeviceId);
        await expectLater(
          source.watchStepReadings(),
          emitsInOrder([reading, emitsDone]),
        );
      },
    );
  });
}
