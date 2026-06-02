import '../models/step_reading.dart';

const kInternalPhoneProvider = 'internal_phone';
const kSmartphoneDeviceId = 'smartphone';
const kAstraWearableProvider = 'astra_wearable_v1';
const kAstraWearableDeviceId = 'astra_wearable_v1';

abstract class DataIngestionSource {
  String get providerId;
  String get deviceId;
  Stream<StepReading> watchStepReadings();
}
