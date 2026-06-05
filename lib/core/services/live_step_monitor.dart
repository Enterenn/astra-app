import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../data/datasources/data_ingestion_source.dart';
import '../../data/datasources/phone_pedometer_source.dart';
import '../../data/datasources/step_increment_calculator.dart';
import '../../data/models/step_reading.dart';
import '../../data/repositories/ingestion_baseline_repository.dart';
import '../../data/repositories/step_repository.dart';
import '../debug/live_pipeline_log.dart';
import '../time/local_day_formatter.dart';
import '../time/time_provider.dart';

typedef ActivityPermissionChecker = Future<bool> Function();

/// Delay after the last processed step reading before [LiveStepMonitor.onActivityIdle] fires.
const kActivityIdleFlushDelay = Duration(seconds: 15);

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
    this.activityIdleFlushDelay = kActivityIdleFlushDelay,
    this.onActivityIdle,
  }) : _stepEventStreamFactory =
           stepEventStreamFactory ?? PhonePedometerSource.defaultStepEventStreamFactory;

  final StepRepository stepRepository;
  final IngestionBaselineRepository baselineRepository;
  final TimeProvider clock;
  final StepIncrementCalculator incrementCalculator;
  final PhoneStepEventStreamFactory _stepEventStreamFactory;
  final Duration emitThrottle;
  final int maxBufferedReadings;
  final Duration activityIdleFlushDelay;
  VoidCallback? onActivityIdle;

  final Queue<StepReading> _readingsBuffer = ListQueue<StepReading>();

  int _persistedTodaySteps = 0;
  int _pendingDelta = 0;
  int? _memoryBaseline;
  DateTime? _lastProcessedObservedAtUtc;
  String? _trackedLocalDay;
  bool _reconciling = false;
  bool _running = false;
  int _lastEmittedValue = 0;

  StreamSubscription<PhoneStepEvent>? _subscription;
  final StreamController<int> _stepsController =
      StreamController<int>.broadcast();
  Timer? _emitTimer;
  bool _emitScheduled = false;
  Timer? _activityIdleTimer;

  bool get isRunning => _running;

  int get currentTodaySteps => _persistedTodaySteps + _pendingDelta;

  /// Replays the latest count to new subscribers, then forwards live updates.
  Stream<int> watchTodaySteps({bool replayLatest = true}) async* {
    if (replayLatest) {
      yield _lastEmittedValue;
    }
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
    livePipelineLog(
      'monitor',
      'start',
      details: {
        'persisted': _persistedTodaySteps,
        'pendingDelta': _pendingDelta,
        'baseline': _memoryBaseline,
      },
    );
    _subscription = _stepEventStreamFactory().listen(
      _onPhoneEvent,
      onError: (Object error, StackTrace stackTrace) {
        livePipelineLog(
          'monitor',
          'stream ERROR',
          details: {'error': error},
        );
        if (kDebugMode) {
          debugPrintStack(stackTrace: stackTrace);
        }
      },
    );
  }

  Future<void> stop() async {
    if (!_running) {
      return;
    }
    livePipelineLog(
      'monitor',
      'stop',
      details: {
        'total': currentTodaySteps,
        'buffered': _readingsBuffer.length,
      },
    );
    _running = false;
    _emitTimer?.cancel();
    _emitTimer = null;
    _cancelActivityIdleTimer();
    await _subscription?.cancel();
    _subscription = null;
  }

  /// One-shot pedometer read while the monitor is stopped (no dual subscription).
  Future<PhoneStepEvent?> peekPhoneStepEvent({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final completer = Completer<PhoneStepEvent?>();
    StreamSubscription<PhoneStepEvent>? subscription;
    subscription = _stepEventStreamFactory().listen(
      (event) {
        unawaited(subscription?.cancel());
        if (!completer.isCompleted) {
          completer.complete(event);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        livePipelineLog(
          'monitor',
          'peek stream ERROR',
          details: {'error': error},
        );
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
      cancelOnError: true,
    );
    try {
      final event = await completer.future.timeout(timeout);
      livePipelineLog(
        'monitor',
        event == null ? 'peek timeout' : 'peek ok',
        details: {
          'timeoutMs': timeout.inMilliseconds,
          if (event != null) 'cumulative': event.steps,
        },
      );
      return event;
    } on TimeoutException {
      await subscription.cancel();
      livePipelineLog(
        'monitor',
        'peek timeout',
        details: {'timeoutMs': timeout.inMilliseconds},
      );
      return null;
    }
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
    livePipelineLog(
      'monitor',
      'reconcile',
      details: {
        'floor': floorDisplay,
        'persisted': _persistedTodaySteps,
        'pendingDelta': _pendingDelta,
        'total': currentTodaySteps,
      },
    );
    _emitNow(force: true);
  }

  /// Queues a reading for the next [drainReadingsForCollection] without live UI.
  void enqueueReadingForCollection(StepReading reading) {
    _bufferReading(reading);
  }

  /// Drains buffered readings for [BackgroundCollector], gated by ingestion baseline.
  ///
  /// Readings at or below the persisted cumulative baseline are removed from the
  /// buffer but not returned — they were already credited in a prior collect.
  Future<List<StepReading>> drainReadingsForCollectionGated() async {
    final baseline = await baselineRepository.getBaseline(
      provider: kInternalPhoneProvider,
      deviceId: kSmartphoneDeviceId,
    );
    return drainReadingsForCollection(sinceCumulative: baseline);
  }

  /// Drains buffered readings for [BackgroundCollector] normalization.
  ///
  /// When [sinceCumulative] is set, only readings with a higher cumulative counter
  /// are returned; the rest are discarded from the buffer.
  @visibleForTesting
  List<StepReading> drainReadingsForCollection({int? sinceCumulative}) {
    if (_readingsBuffer.isEmpty) {
      return const [];
    }
    final drained = List<StepReading>.generate(
      _readingsBuffer.length,
      (_) => _readingsBuffer.removeFirst(),
    );
    if (sinceCumulative == null) {
      return drained;
    }
    return drained
        .where((reading) => reading.cumulativeSteps > sinceCumulative)
        .toList(growable: false);
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
    livePipelineLog(
      'monitor',
      'hardware event',
      details: {
        'cumulative': event.steps,
        'reconciling': _reconciling,
        'buffered': _readingsBuffer.length,
      },
      minInterval: const Duration(seconds: 2),
    );
    if (_reconciling) {
      livePipelineLog(
        'monitor',
        'event buffered during reconcile',
        minInterval: const Duration(seconds: 5),
      );
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
      _lastProcessedObservedAtUtc = null;
      unawaited(reconcileFromDatabase());
    }
    _trackedLocalDay ??= todayIso;
  }

  void _applyReadingToDelta(StepReading reading) {
    final cumulative = reading.cumulativeSteps;
    if (_memoryBaseline == null) {
      _memoryBaseline = cumulative;
      _lastProcessedObservedAtUtc = reading.observedAtUtc;
      _resetActivityIdleTimer();
      return;
    }

    final elapsedSincePrevious = _lastProcessedObservedAtUtc == null
        ? null
        : reading.observedAtUtc.difference(_lastProcessedObservedAtUtc!);
    _lastProcessedObservedAtUtc = reading.observedAtUtc;

    final increment = incrementCalculator.calculate(
      current: cumulative,
      baseline: _memoryBaseline!,
      elapsedSincePrevious: elapsedSincePrevious,
    );
    if (increment == null) {
      livePipelineLog(
        'monitor',
        'increment rejected (noise/rollover)',
        details: {'cumulative': cumulative, 'baseline': _memoryBaseline},
        minInterval: const Duration(seconds: 5),
      );
      _resetActivityIdleTimer();
      return;
    }

    _memoryBaseline = cumulative;
    if (increment <= 0) {
      livePipelineLog(
        'monitor',
        'increment zero',
        details: {'cumulative': cumulative},
        minInterval: const Duration(seconds: 5),
      );
      _resetActivityIdleTimer();
      return;
    }

    livePipelineLog(
      'monitor',
      'delta +$increment',
      details: {
        'total': _persistedTodaySteps + _pendingDelta + increment,
        'cumulative': cumulative,
      },
    );
    _pendingDelta += increment;
    _scheduleEmit();
    _resetActivityIdleTimer();
  }

  void _resetActivityIdleTimer() {
    _activityIdleTimer?.cancel();
    if (!_running || onActivityIdle == null) {
      return;
    }
    _activityIdleTimer = Timer(activityIdleFlushDelay, () {
      _activityIdleTimer = null;
      onActivityIdle?.call();
    });
  }

  void _cancelActivityIdleTimer() {
    _activityIdleTimer?.cancel();
    _activityIdleTimer = null;
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
    livePipelineLog(
      'monitor',
      'emit',
      details: {
        'total': total,
        'persisted': _persistedTodaySteps,
        'pendingDelta': _pendingDelta,
        'listeners': _stepsController.hasListener,
      },
      minInterval: const Duration(milliseconds: 500),
    );
    _stepsController.add(total);
  }
}
