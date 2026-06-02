import 'dart:async';
import 'dart:collection';

import '../../data/datasources/data_ingestion_source.dart';
import '../../data/datasources/phone_pedometer_source.dart';
import '../../data/datasources/step_increment_calculator.dart';
import '../../data/models/step_reading.dart';
import '../../data/repositories/ingestion_baseline_repository.dart';
import '../../data/repositories/step_repository.dart';
import '../time/local_day_formatter.dart';
import '../time/time_provider.dart';

typedef ActivityPermissionChecker = Future<bool> Function();

/// Foreground owner of the phone pedometer stream and live today-step display.
///
/// Persists via [BackgroundCollector]; this class never writes buckets.
class LiveStepMonitor {
  LiveStepMonitor({
    required this.stepRepository,
    required this.baselineRepository,
    required this.clock,
    this.incrementCalculator = const StepIncrementCalculator(),
    PhoneStepEventStreamFactory? stepEventStreamFactory,
    this.emitThrottle = const Duration(milliseconds: 500),
    this.maxBufferedReadings = 200,
  }) : _stepEventStreamFactory =
           stepEventStreamFactory ?? PhonePedometerSource.defaultStepEventStreamFactory;

  final StepRepository stepRepository;
  final IngestionBaselineRepository baselineRepository;
  final TimeProvider clock;
  final StepIncrementCalculator incrementCalculator;
  final PhoneStepEventStreamFactory _stepEventStreamFactory;
  final Duration emitThrottle;
  final int maxBufferedReadings;

  final Queue<StepReading> _readingsBuffer = ListQueue<StepReading>();

  int _persistedTodaySteps = 0;
  int _pendingDelta = 0;
  int? _memoryBaseline;
  String? _trackedLocalDay;
  bool _reconciling = false;
  bool _running = false;
  int _lastEmittedValue = 0;

  StreamSubscription<PhoneStepEvent>? _subscription;
  final StreamController<int> _stepsController =
      StreamController<int>.broadcast();
  Timer? _emitTimer;
  bool _emitScheduled = false;

  bool get isRunning => _running;

  int get currentTodaySteps => _persistedTodaySteps + _pendingDelta;

  /// Replays the latest count to new subscribers, then forwards live updates.
  Stream<int> watchTodaySteps() async* {
    yield _lastEmittedValue;
    yield* _stepsController.stream;
  }

  Future<void> start() async {
    if (_running) {
      return;
    }
    await _syncMemoryBaselineFromRepository();
    _persistedTodaySteps = await stepRepository.getTodaySteps();
    _trackedLocalDay = formatLocalDayIso(clock.snapshot());
    _running = true;
    _subscription = _stepEventStreamFactory().listen(
      _onPhoneEvent,
      onError: (_) {},
    );
  }

  Future<void> stop() async {
    if (!_running) {
      return;
    }
    _running = false;
    _emitTimer?.cancel();
    _emitTimer = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Re-subscribes to the pedometer stream and re-syncs from SQLite.
  ///
  /// Used on app resume when the platform stream may have stalled in background.
  Future<void> restart() async {
    await stop();
    await start();
    await reconcileFromDatabase();
  }

  /// Pauses pending-delta accumulation and aligns memory baseline with SQLite.
  Future<void> beginReconcile() async {
    _reconciling = true;
    await _syncMemoryBaselineFromRepository();
  }

  void endReconcile() {
    _reconciling = false;
    _flushBufferedReadingsToDelta();
  }

  /// Applies buffered sensor readings to [ _pendingDelta] after a persist cycle.
  ///
  /// Readings that arrived after [drainReadingsForCollection] during reconcile
  /// were buffered but not shown live; this catches the UI up without waiting
  /// for the next platform event.
  void _flushBufferedReadingsToDelta() {
    if (_readingsBuffer.isEmpty) {
      return;
    }
    for (final reading in _readingsBuffer) {
      _handleLocalDayRollover();
      _applyReadingToDelta(reading);
    }
  }

  /// Re-reads persisted totals and baseline; never lowers the displayed total.
  Future<void> reconcileFromDatabase() async {
    final floorDisplay = currentTodaySteps;
    _persistedTodaySteps = await stepRepository.getTodaySteps();
    await _syncMemoryBaselineFromRepository();

    final syncedTotal = _persistedTodaySteps;
    if (syncedTotal >= floorDisplay) {
      _pendingDelta = 0;
    } else {
      _pendingDelta = floorDisplay - syncedTotal;
    }

    _trackedLocalDay = formatLocalDayIso(clock.snapshot());
    _emitNow(force: true);
  }

  /// Drains all buffered readings for [BackgroundCollector] normalization.
  List<StepReading> drainReadingsForCollection() {
    if (_readingsBuffer.isEmpty) {
      return const [];
    }
    final drained = List<StepReading>.generate(
      _readingsBuffer.length,
      (_) => _readingsBuffer.removeFirst(),
    );
    return drained;
  }

  void dispose() {
    unawaited(stop());
    _stepsController.close();
  }

  Future<void> _syncMemoryBaselineFromRepository() async {
    _memoryBaseline = await baselineRepository.getBaseline(
      provider: kInternalPhoneProvider,
      deviceId: kSmartphoneDeviceId,
    );
  }

  void _onPhoneEvent(PhoneStepEvent event) {
    final reading = StepReading(
      cumulativeSteps: event.steps,
      observedAtUtc: event.timeStamp,
    );
    _bufferReading(reading);
    if (_reconciling) {
      return;
    }
    _handleLocalDayRollover();
    _applyReadingToDelta(reading);
  }

  void _bufferReading(StepReading reading) {
    _readingsBuffer.addLast(reading);
    while (_readingsBuffer.length > maxBufferedReadings) {
      _readingsBuffer.removeFirst();
    }
  }

  void _handleLocalDayRollover() {
    final todayIso = formatLocalDayIso(clock.snapshot());
    if (_trackedLocalDay != null && _trackedLocalDay != todayIso) {
      _pendingDelta = 0;
      _memoryBaseline = null;
      unawaited(reconcileFromDatabase());
    }
    _trackedLocalDay ??= todayIso;
  }

  void _applyReadingToDelta(StepReading reading) {
    final cumulative = reading.cumulativeSteps;
    if (_memoryBaseline == null) {
      _memoryBaseline = cumulative;
      return;
    }

    final increment = incrementCalculator.calculate(
      current: cumulative,
      baseline: _memoryBaseline!,
    );
    if (increment == null) {
      return;
    }

    _memoryBaseline = cumulative;
    if (increment <= 0) {
      return;
    }

    _pendingDelta += increment;
    _scheduleEmit();
  }

  void _scheduleEmit() {
    if (emitThrottle == Duration.zero) {
      _emitNow();
      return;
    }
    if (_emitScheduled) {
      return;
    }
    _emitScheduled = true;
    _emitTimer ??= Timer(emitThrottle, () {
      _emitScheduled = false;
      _emitTimer = null;
      _emitNow();
      if (_pendingDelta > 0 && !_reconciling) {
        _scheduleEmit();
      }
    });
  }

  void _emitNow({bool force = false}) {
    final total = currentTodaySteps;
    if (!force && total == _lastEmittedValue) {
      return;
    }
    _lastEmittedValue = total;
    _stepsController.add(total);
  }
}
