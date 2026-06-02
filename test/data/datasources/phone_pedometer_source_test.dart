import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/datasources/phone_pedometer_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhonePedometerSource', () {
    test('implements ingestion contract with phone metadata', () {
      final source = PhonePedometerSource(
        stepEventStreamFactory: () => const Stream<PhoneStepEvent>.empty(),
      );

      expect(source, isA<DataIngestionSource>());
      expect(source.providerId, kInternalPhoneProvider);
      expect(source.deviceId, kSmartphoneDeviceId);
    });

    test('maps injected pedometer events to UTC step readings', () async {
      final source = PhonePedometerSource(
        stepEventStreamFactory: () => Stream.fromIterable([
          PhoneStepEvent(
            steps: 1234,
            timeStamp: DateTime.parse('2026-06-02T09:00:00+02:00'),
          ),
        ]),
      );

      final readings = await source.watchStepReadings().toList();

      expect(readings, hasLength(1));
      expect(readings.single.cumulativeSteps, 1234);
      expect(readings.single.observedAtUtc.isUtc, isTrue);
      expect(
        readings.single.observedAtUtc.toIso8601String(),
        '2026-06-02T07:00:00.000Z',
      );
    });
  });
}
