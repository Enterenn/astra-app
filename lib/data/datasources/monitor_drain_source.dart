import '../models/step_reading.dart';
import '../../core/services/live_step_monitor.dart';
import 'data_ingestion_source.dart';

/// Phone ingestion source that drains buffered readings from [LiveStepMonitor]
/// instead of opening a second native pedometer subscription.
class MonitorDrainSource implements DataIngestionSource {
  MonitorDrainSource(this._monitor);

  final LiveStepMonitor _monitor;

  @override
  String get providerId => kInternalPhoneProvider;

  @override
  String get deviceId => kSmartphoneDeviceId;

  @override
  Stream<StepReading> watchStepReadings() async* {
    for (final reading in _monitor.drainReadingsForCollection()) {
      yield reading;
    }
  }
}
