import 'package:astra_app/data/datasources/adp_ble_source.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdpBleSource', () {
    test(
      'implements ingestion contract and emits no Phase 0 readings',
      () async {
        final source = AdpBleSource();

        expect(source, isA<DataIngestionSource>());
        expect(source.providerId, kAstraWearableProvider);
        expect(source.deviceId, kAstraWearableDeviceId);
        await expectLater(source.watchStepReadings(), emitsDone);
      },
    );
  });
}
