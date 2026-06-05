import '../models/step_reading.dart';
import '../../core/services/live_step_monitor.dart';
import 'data_ingestion_source.dart';
import 'phone_pedometer_source.dart';

/// Phone ingestion for [BackgroundCollector].
///
/// While [LiveStepMonitor] is running, drains its buffered readings (single
/// native subscription). When the monitor is stopped briefly for a resume
/// phone catch-up, falls back to a one-shot [PhonePedometerSource] read.
class MonitorDrainSource implements DataIngestionSource {
  MonitorDrainSource(
    this._monitor, {
    PhonePedometerSource? phoneFallback,
  }) : _phoneFallback = phoneFallback ?? PhonePedometerSource();

  final LiveStepMonitor _monitor;
  final PhonePedometerSource _phoneFallback;

  @override
  String get providerId => kInternalPhoneProvider;

  @override
  String get deviceId => kSmartphoneDeviceId;

  @override
  Stream<StepReading> watchStepReadings() {
    if (_monitor.isRunning) {
      return Stream.fromIterable(_monitor.drainReadingsForCollection());
    }
    return _phoneFallback.watchStepReadings();
  }
}
