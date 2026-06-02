import '../models/step_reading.dart';
import 'data_ingestion_source.dart';

/// Phase 0 placeholder for future ASTRA wearable ingestion.
///
/// ADP BLE activation belongs to Phase 1; until then this source is wired as
/// a no-op so the ingestion pipeline can treat phone and wearable sources
/// uniformly.
class AdpBleSource implements DataIngestionSource {
  const AdpBleSource();

  @override
  String get providerId => kAstraWearableProvider;

  @override
  String get deviceId => kAstraWearableDeviceId;

  @override
  Stream<StepReading> watchStepReadings() => const Stream.empty();
}
