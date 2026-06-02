import 'package:pedometer/pedometer.dart';

import '../models/step_reading.dart';
import 'data_ingestion_source.dart';

typedef PhoneStepEventStreamFactory = Stream<PhoneStepEvent> Function();

class PhoneStepEvent {
  PhoneStepEvent({required this.steps, required DateTime timeStamp})
    : timeStamp = timeStamp.toUtc();

  factory PhoneStepEvent.fromStepCount(StepCount stepCount) {
    return PhoneStepEvent(
      steps: stepCount.steps,
      timeStamp: stepCount.timeStamp,
    );
  }

  final int steps;
  final DateTime timeStamp;
}

class PhonePedometerSource implements DataIngestionSource {
  PhonePedometerSource({PhoneStepEventStreamFactory? stepEventStreamFactory})
    : _stepEventStreamFactory =
          stepEventStreamFactory ?? _defaultStepEventStreamFactory;

  final PhoneStepEventStreamFactory _stepEventStreamFactory;

  @override
  String get providerId => kInternalPhoneProvider;

  @override
  String get deviceId => kSmartphoneDeviceId;

  @override
  Stream<StepReading> watchStepReadings() {
    return _stepEventStreamFactory().map(
      (event) => StepReading(
        cumulativeSteps: event.steps,
        observedAtUtc: event.timeStamp,
      ),
    );
  }

  static Stream<PhoneStepEvent> _defaultStepEventStreamFactory() {
    return Pedometer.stepCountStream.map(PhoneStepEvent.fromStepCount);
  }

  /// Exposed for [LiveStepMonitor] — sole production subscriber in UI isolate.
  static PhoneStepEventStreamFactory get defaultStepEventStreamFactory =>
      _defaultStepEventStreamFactory;
}
