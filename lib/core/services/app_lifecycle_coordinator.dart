import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/step_reading.dart';
import '../../presentation/cubits/history_cubit.dart';
import '../../presentation/cubits/my_data_cubit.dart';
import '../../presentation/cubits/today_cubit.dart';
import '../../presentation/cubits/today_state.dart';
import '../debug/live_pipeline_log.dart';
import '../di/app_dependencies.dart';
import '../time/local_day_boundary.dart';
import '../time/local_day_formatter.dart';
import 'live_step_monitor.dart';

/// Safety net: persist at least this often during continuous walking.
const kMaxPersistStaleness = Duration(minutes: 5);

/// One-shot phone read after unlock when the live buffer had no pocket events.
const kResumePhoneCatchUpTimeout = Duration(seconds: 8);

/// Whether the staleness fallback should run a persist cycle.
@visibleForTesting
bool shouldTriggerStalenessPersist({
  required DateTime? lastPersistAt,
  required DateTime now,
  required Duration maxStaleness,
}) {
  return lastPersistAt == null ||
      now.difference(lastPersistAt) >= maxStaleness;
}

/// Whether resume should stop the monitor briefly for a one-shot phone peek.
@visibleForTesting
bool shouldRunResumePhoneCatchUp({
  required bool persistedNewSteps,
  required int upsertedFromDrain,
  required bool monitorAheadOfDb,
  required Duration pauseDuration,
  required Duration minPauseForPhoneCatchUp,
}) {
  return !persistedNewSteps &&
      upsertedFromDrain == 0 &&
      !monitorAheadOfDb &&
      pauseDuration >= minPauseForPhoneCatchUp;
}

/// Serializes lifecycle pause/resume handlers so foreground recovery cannot
/// race background persist. Extracted for fast unit tests (Story 14-2).
@visibleForTesting
Future<void> runSerializedLifecycleTransition({
  required Future<void>? Function() readInFlight,
  required void Function(Future<void>?) writeInFlight,
  required Future<void> Function() operation,
}) async {
  while (readInFlight() != null) {
    try {
      await readInFlight();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'AppLifecycleCoordinator._enqueueLifecycleTransition: prior transition failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  late final Future<void> transition;
  transition = operation();
  writeInFlight(transition);
  try {
    await transition;
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint(
        'AppLifecycleCoordinator._enqueueLifecycleTransition: transition failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  } finally {
    if (readInFlight() == transition) {
      writeInFlight(null);
    }
  }
}

/// Whether resume should briefly stop the monitor for a one-shot phone peek.
///
/// Skips the destructive stop/peek cycle when background collection (pause
/// persist and/or FGS) already advanced SQLite during the lock — the Fairphone
/// long-walk scenario where peek would aggravate a zombie subscription.
@visibleForTesting
bool shouldRunResumePhonePeek({
  required bool likelyPocketWalk,
  required int stepsBeforeResumeCollect,
  required int? stepsAtBackground,
}) {
  if (!likelyPocketWalk) {
    return false;
  }
  if (stepsAtBackground != null &&
      stepsBeforeResumeCollect > stepsAtBackground) {
    return false;
  }
  return true;
}

/// Live pipeline orchestration extracted from [AstraApp] (Story 18-1).
class AppLifecycleCoordinator {
  AppLifecycleCoordinator({
    required this.depsGetter,
    this.enablePeriodicPersist = true,
    this.enableLiveStepPipeline = true,
    this.maxPersistStaleness = kMaxPersistStaleness,
    this.minPauseForPhoneCatchUp = const Duration(seconds: 10),
  });

  final AppDependencies Function() depsGetter;

  AppDependencies get deps => depsGetter();

  bool enablePeriodicPersist;
  bool enableLiveStepPipeline;
  Duration maxPersistStaleness;
  Duration minPauseForPhoneCatchUp;

  bool Function()? _isMounted;
  bool Function()? _showMainShell;

  TodayCubit? _todayCubit;
  HistoryCubit? _historyCubit;
  MyDataCubit? _myDataCubit;

  late Future<int> _foregroundBackfill;
  Timer? _stalenessPersistTimer;
  Timer? _midnightBoundaryTimer;
  String? _activeLocalDayIso;
  Future<void>? _dayBoundaryInFlight;
  DateTime? _lastPersistAt;
  bool _livePipelineStarted = false;
  DateTime? _backgroundedAt;
  int? _stepsAtBackground;
  Future<void>? _persistInFlight;
  Future<void>? _lifecycleTransitionInFlight;
  Stopwatch? _coldStartStopwatch;
  bool _coldStartReadyLogged = false;

  /// True after [AppLifecycleState.paused] until [AppLifecycleState.resumed].
  bool _appInBackground = false;

  /// Must cover [LiveStepMonitor.maxBufferedReadings] so activity-idle persist
  /// normalizes every buffered phone reading in one collect.
  static const _persistMaxReadingsPerSource = 250;

  /// Cold-start / resume backfill future passed to [AppScaffold].
  Future<int> get foregroundBackfill => _foregroundBackfill;

  /// Binds widget lifecycle callbacks and test knobs from [AstraApp].
  void bindToWidget({
    required bool Function() isMounted,
    required bool Function() showMainShell,
    required bool enablePeriodicPersist,
    required bool enableLiveStepPipeline,
    required Duration maxPersistStaleness,
    required Duration minPauseForPhoneCatchUp,
    required bool initialShowMainShell,
  }) {
    _isMounted = isMounted;
    _showMainShell = showMainShell;
    this.enablePeriodicPersist = enablePeriodicPersist;
    this.enableLiveStepPipeline = enableLiveStepPipeline;
    this.maxPersistStaleness = maxPersistStaleness;
    this.minPauseForPhoneCatchUp = minPauseForPhoneCatchUp;

    if (initialShowMainShell) {
      _coldStartStopwatch = Stopwatch()..start();
      livePipelineLog('app', 'cold start START', details: {'elapsedMs': 0});
    }
    _foregroundBackfill = enableLiveStepPipeline
        ? _runPersistCycle(enableGoalNotification: false)
        : deps.backgroundCollector.collectOnce(
            enableGoalNotification: false,
          );
  }

  void bindTodayCubit(TodayCubit? cubit) => _todayCubit = cubit;

  void bindHistoryCubit(HistoryCubit? cubit) => _historyCubit = cubit;

  void bindMyDataCubit(MyDataCubit? cubit) => _myDataCubit = cubit;

  void onTodayCubitReady(TodayCubit cubit) {
    _todayCubit = cubit;
    if (enableLiveStepPipeline) {
      unawaited(_ensureLivePipelineAttached());
    } else {
      unawaited(_initialTodayRefresh());
    }
  }

  void onHistoryCubitReady(HistoryCubit cubit) {
    _historyCubit = cubit;
  }

  void onMyDataCubitReady(MyDataCubit cubit) {
    _myDataCubit = cubit;
  }

  Future<void> onLifecycleStatePaused() {
    return _enqueueLifecycleTransition(_onAppBackgrounded);
  }

  Future<void> onLifecycleStateResumed() {
    return _enqueueLifecycleTransition(_onAppForegrounded);
  }

  /// Test hook — exercises persist serialization without a widget harness.
  @visibleForTesting
  Future<void> enqueuePersistCycleForTest({
    required bool enableGoalNotification,
    bool syncTodayAfter = false,
  }) {
    return _enqueuePersistCycle(
      enableGoalNotification: enableGoalNotification,
      syncTodayAfter: syncTodayAfter,
    );
  }

  /// Test hook — day-boundary gate without midnight timer.
  @visibleForTesting
  Future<void> runLocalDayBoundaryIfNeededForTest() {
    return _runLocalDayBoundaryIfNeeded();
  }

  void dispose() {
    _stopActivityBasedPersist();
    _cancelMidnightBoundaryTimer();
    unawaited(deps.liveStepMonitor.stop());
  }

  bool _mounted() => _isMounted?.call() ?? false;

  bool _shellVisible() => _showMainShell?.call() ?? false;

  /// Serializes pause/resume handlers so foreground recovery cannot race background persist.
  Future<void> _enqueueLifecycleTransition(
    Future<void> Function() operation,
  ) {
    return runSerializedLifecycleTransition(
      readInFlight: () => _lifecycleTransitionInFlight,
      writeInFlight: (future) => _lifecycleTransitionInFlight = future,
      operation: operation,
    );
  }

  Future<void> _onAppBackgrounded() async {
    _backgroundedAt = DateTime.now();
    livePipelineLog(
      'app',
      'lifecycle PAUSED',
      details: {
        'monitorRunning': deps.liveStepMonitor.isRunning,
        'monitorTotal': deps.liveStepMonitor.currentTodaySteps,
        'cubitSteps': _todayCubit?.state.steps,
      },
    );
    await _persistOnPause();
    if (!_shellVisible()) {
      return;
    }
    _stepsAtBackground = await deps.stepRepository.getTodaySteps();
    _stopStalenessPersistTimer();
    _appInBackground = true;
    _todayCubit?.setLiveStepAppliesPaused(true);
    final healthFgs = deps.healthForegroundCoordinator;
    await healthFgs.setUiActive(false);
    await healthFgs.startHealthCollectionService();
    await deps.backgroundCollector.maybeNotifyGoalReachedIfGoalMet();
  }

  Future<void> _onAppForegrounded() async {
    _appInBackground = false;
    livePipelineLog('app', 'lifecycle RESUMED');
    await deps.databaseSession.ensureOpen();
    final healthFgs = deps.healthForegroundCoordinator;
    await healthFgs.stopHealthCollectionService();
    await healthFgs.setUiActive(true);
    // Heavy DB maintenance (downsample + VACUUM) must not run here — it can
    // invalidate the UI SQLite connection while _resumeLivePipeline reads/writes.
    // Android: WorkManager; manual: My Data purge/optimize flows.
    if (enableLiveStepPipeline && _shellVisible()) {
      await _resumeLivePipeline();
    } else {
      await _enqueuePersistCycle(
        enableGoalNotification: false,
        syncTodayAfter: true,
      );
      await _todayCubit?.refreshMetadata();
      await _historyCubit?.refresh(silent: true);
      await _myDataCubit?.refresh(silent: true);
    }
    if (_livePipelineStarted && enablePeriodicPersist) {
      _startActivityBasedPersist();
    }
    if (_livePipelineStarted) {
      _wireLiveMonitorDayBoundaryCallbacks();
      _scheduleMidnightBoundaryTimer();
    }
  }

  /// Flushes buffered steps to SQLite when the app leaves the foreground.
  ///
  /// Best-effort before a possible process kill — no UI updates (user cannot see
  /// Today). [AppLifecycleState.resumed] still reconciles and syncs the cubit.
  Future<void> _persistOnPause() async {
    if (!_shellVisible()) {
      return;
    }
    await _enqueuePersistCycle(enableGoalNotification: false);
  }

  /// Persists buffered phone readings via [BackgroundCollector] (sole bucket writer),
  /// then reconciles [LiveStepMonitor] from SQLite without lowering the overlay.
  Future<int> _runPersistCycle({
    required bool enableGoalNotification,
    Duration? sourceTimeout,
  }) async {
    final monitor = deps.liveStepMonitor;
    final collector = deps.backgroundCollector;
    await monitor.beginReconcile();
    try {
      final upserted = await collector.collectOnce(
        maxReadingsPerSource: _persistMaxReadingsPerSource,
        enableGoalNotification: enableGoalNotification,
        sourceTimeout: sourceTimeout,
      );
      await monitor.reconcileFromDatabase();
      _lastPersistAt = DateTime.now();
      return upserted;
    } finally {
      monitor.endReconcile();
    }
  }

  Future<void> _runPersistIfNotInFlight() async {
    if (!_shellVisible() || !_livePipelineStarted) {
      return;
    }
    await _enqueuePersistCycle(
      enableGoalNotification: _appInBackground,
      syncTodayAfter: true,
    );
  }

  /// Serializes pause, idle, staleness, and resume persist cycles.
  Future<void> _enqueuePersistCycle({
    required bool enableGoalNotification,
    bool syncTodayAfter = false,
  }) async {
    while (_persistInFlight != null) {
      await _persistInFlight;
    }

    late final Future<void> operation;
    operation = _persistCycleWithOptionalSync(
      enableGoalNotification: enableGoalNotification,
      syncTodayAfter: syncTodayAfter,
    );
    _persistInFlight = operation;
    try {
      await operation;
    } finally {
      if (_persistInFlight == operation) {
        _persistInFlight = null;
      }
    }
  }

  Future<void> _persistCycleWithOptionalSync({
    required bool enableGoalNotification,
    required bool syncTodayAfter,
  }) async {
    if (enableLiveStepPipeline) {
      if (!_livePipelineStarted && !enableGoalNotification) {
        return;
      }
      await _runPersistCycle(enableGoalNotification: enableGoalNotification);
      if (syncTodayAfter) {
        await _todayCubit?.syncSteps(
          deps.liveStepMonitor.currentTodaySteps,
        );
      }
      return;
    }

    await deps.backgroundCollector.collectOnce(
      enableGoalNotification: enableGoalNotification,
    );
    if (syncTodayAfter) {
      await _todayCubit?.refresh(silent: true);
    }
  }

  /// Foreground resume: keep the pedometer subscription alive, drain pocket
  /// buffer, then one-shot phone catch-up only when SQLite did not advance.
  Future<void> _resumeLivePipeline() async {
    try {
      await _runLocalDayBoundaryIfNeeded();
      final monitor = deps.liveStepMonitor;
      final repo = deps.stepRepository;
      final stepsBeforeCollect = await repo.getTodaySteps();

      final upsertedFromDrain = await _enqueuePersistCycleReturningCount(
        enableGoalNotification: false,
      );

      final stepsAfterDrain = await repo.getTodaySteps();
      final persistedNewSteps = stepsAfterDrain > stepsBeforeCollect;
      final monitorAheadOfDb = monitor.currentTodaySteps > stepsAfterDrain;
      final pauseDuration = _backgroundedAt == null
          ? Duration.zero
          : DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      final likelyPocketWalk = shouldRunResumePhoneCatchUp(
        persistedNewSteps: persistedNewSteps,
        upsertedFromDrain: upsertedFromDrain,
        monitorAheadOfDb: monitorAheadOfDb,
        pauseDuration: pauseDuration,
        minPauseForPhoneCatchUp: minPauseForPhoneCatchUp,
      );
      final needsPhonePeek = shouldRunResumePhonePeek(
        likelyPocketWalk: likelyPocketWalk,
        stepsBeforeResumeCollect: stepsBeforeCollect,
        stepsAtBackground: _stepsAtBackground,
      );
      _stepsAtBackground = null;

      if (needsPhonePeek) {
        final wasRunning = monitor.isRunning;
        if (wasRunning) {
          await monitor.stop();
        }
        final pocketEvent = await monitor.peekPhoneStepEvent(
          timeout: kResumePhoneCatchUpTimeout,
        );
        if (pocketEvent != null) {
          monitor.enqueueReadingForCollection(
            StepReading(
              cumulativeSteps: pocketEvent.steps,
              observedAtUtc: pocketEvent.timeStamp,
            ),
          );
          if (!monitor.isRunning) {
            await monitor.start();
          }
          await _enqueuePersistCycleReturningCount(
            enableGoalNotification: false,
          );
        } else if (wasRunning && !monitor.isRunning) {
          await monitor.start();
        }
      }

      if (monitor.isRunning) {
        await monitor.reconcileFromDatabase();
      } else {
        await monitor.start();
        await monitor.reconcileFromDatabase();
      }

      await _bindLiveMonitorToToday(foregroundCatchUp: true);
      _livePipelineStarted = true;
      livePipelineLog(
        'app',
        'resume pipeline DONE',
        details: {
          'pauseSec': pauseDuration.inSeconds,
          'upsertedDrain': upsertedFromDrain,
          'stepsBefore': stepsBeforeCollect,
          'stepsAfterDrain': stepsAfterDrain,
          'phonePeek': needsPhonePeek,
          'monitorRunning': monitor.isRunning,
          'monitorTotal': monitor.currentTodaySteps,
          'cubitSteps': _todayCubit?.state.steps,
          'catchUp': _todayCubit?.state.foregroundCatchUp ?? false,
        },
      );
      await _todayCubit?.refreshMetadata();
      await _historyCubit?.refresh(silent: true);
      await _myDataCubit?.refresh(silent: true);
    } catch (error, stackTrace) {
      livePipelineLog(
        'app',
        'resume pipeline ERROR',
        details: {'error': error},
      );
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    } finally {
      _todayCubit?.setLiveStepAppliesPaused(false);
    }
  }

  Future<int> _enqueuePersistCycleReturningCount({
    required bool enableGoalNotification,
    Duration? sourceTimeout,
  }) async {
    while (_persistInFlight != null) {
      await _persistInFlight;
    }

    late final Future<void> operation;
    var upserted = 0;
    operation = () async {
      if (enableLiveStepPipeline) {
        if (!_livePipelineStarted && !enableGoalNotification) {
          return;
        }
        upserted = await _runPersistCycle(
          enableGoalNotification: enableGoalNotification,
          sourceTimeout: sourceTimeout,
        );
        return;
      }
      upserted = await deps.backgroundCollector.collectOnce(
        enableGoalNotification: enableGoalNotification,
        sourceTimeout: sourceTimeout,
      );
    }();
    _persistInFlight = operation;
    try {
      await operation;
      return upserted;
    } finally {
      if (_persistInFlight == operation) {
        _persistInFlight = null;
      }
    }
  }

  Future<void> _initialTodayRefresh() async {
    await _foregroundBackfill;
    _logColdStartPhase('cold start backfill DONE');
    if (!_mounted()) {
      return;
    }
    await _todayCubit?.refresh();
    _logColdStartReadyIfNeeded();
  }

  void _logColdStartPhase(
    String phase, {
    Map<String, Object?> details = const {},
  }) {
    final stopwatch = _coldStartStopwatch;
    if (stopwatch == null) {
      return;
    }
    livePipelineLog(
      'app',
      phase,
      details: {
        'elapsedMs': stopwatch.elapsedMilliseconds,
        ...details,
      },
    );
  }

  void _logColdStartReadyIfNeeded() {
    if (_coldStartReadyLogged || _coldStartStopwatch == null) {
      return;
    }
    final cubit = _todayCubit;
    if (cubit == null || cubit.state.status == TodayStatus.loading) {
      return;
    }
    _coldStartReadyLogged = true;
    _coldStartStopwatch!.stop();
    _logColdStartPhase(
      'cold start UI READY',
      details: {
        'steps': cubit.state.steps,
        'status': cubit.state.status.name,
      },
    );
  }

  /// First launch or hot-reload cubit recreate — never overwrite live total with
  /// a stale SQLite-only [TodayCubit.refresh].
  Future<void> _ensureLivePipelineAttached() async {
    if (!_livePipelineStarted) {
      await _startLivePipelineFirstTime();
      return;
    }
    await _reattachLivePipeline();
  }

  /// Cold-start live pipeline (permission granted):
  /// foreground backfill → SQLite baseline via [TodayCubit.refresh] → live attach.
  ///
  /// See Today Display Truth Model in
  /// `_bmad-output/planning-artifacts/architecture.md`.
  Future<void> _startLivePipelineFirstTime() async {
    if (!enableLiveStepPipeline) {
      return;
    }
    await _foregroundBackfill;
    _logColdStartPhase('cold start backfill DONE');
    if (!_mounted()) {
      return;
    }
    await _bindLiveMonitorToToday();
    if (!_mounted()) {
      return;
    }
    _livePipelineStarted = true;
    _logColdStartPhase(
      'cold start pipeline DONE',
      details: {
        'monitorRunning': deps.liveStepMonitor.isRunning,
        'monitorTotal': deps.liveStepMonitor.currentTodaySteps,
        'cubitSteps': _todayCubit?.state.steps,
      },
    );
    _logColdStartReadyIfNeeded();
    _wireLiveMonitorDayBoundaryCallbacks();
    _startActivityBasedPersist();
    _scheduleMidnightBoundaryTimer();
  }

  Future<void> _reattachLivePipeline() async {
    if (!_mounted()) {
      return;
    }
    await _bindLiveMonitorToToday();
  }

  Future<void> _bindLiveMonitorToToday({bool foregroundCatchUp = false}) async {
    if (!await deps.activityPermissionGranted()) {
      livePipelineLog('app', 'bind SKIPPED reason=no_permission');
      await _todayCubit?.refresh();
      return;
    }

    final monitor = deps.liveStepMonitor;
    if (!monitor.isRunning) {
      await monitor.start();
      await monitor.reconcileFromDatabase();
    }

    // SQLite daily sum before live overlay (Today Display Truth Model).
    if (!foregroundCatchUp) {
      await _todayCubit?.refresh(silent: true);
    }

    if (foregroundCatchUp) {
      await _todayCubit?.syncSteps(
        monitor.currentTodaySteps,
        foregroundCatchUp: true,
      );
      // When catch-up was skipped (already aligned), replayLatest re-attaches
      // the stream without triggering a redundant GoalRing count-up animation.
      final catchUpActive = _todayCubit?.state.foregroundCatchUp ?? false;
      _todayCubit?.attachLiveMonitor(
        monitor,
        replayLatest: !catchUpActive,
      );
    } else {
      _todayCubit?.attachLiveMonitor(monitor);
      await _todayCubit?.syncSteps(
        monitor.currentTodaySteps,
        clampStaleDisplay: true,
      );
    }
    livePipelineLog(
      'app',
      'bindLiveMonitor',
      details: {
        'foregroundCatchUp': foregroundCatchUp,
        'monitorRunning': monitor.isRunning,
        'monitorTotal': monitor.currentTodaySteps,
        'cubitSteps': _todayCubit?.state.steps,
        'catchUp': _todayCubit?.state.foregroundCatchUp ?? false,
      },
    );
    // Cold-start bind already ran refresh(silent); resume catch-up skips it.
    if (foregroundCatchUp) {
      await _todayCubit?.refreshMetadata();
    } else {
      _logColdStartReadyIfNeeded();
    }
  }

  void _wireLiveMonitorDayBoundaryCallbacks() {
    final monitor = deps.liveStepMonitor;
    monitor.onLocalDayBoundary = () {
      unawaited(_runLocalDayBoundaryIfNeeded());
    };
    _activeLocalDayIso ??= formatLocalDayIso(deps.timeProvider.snapshot());
  }

  void _startActivityBasedPersist() {
    if (!enablePeriodicPersist) {
      return;
    }
    final monitor = deps.liveStepMonitor;
    monitor.onActivityIdle = () {
      unawaited(_runPersistIfNotInFlight());
    };

    final maxStaleness = maxPersistStaleness;
    _stalenessPersistTimer?.cancel();
    _stalenessPersistTimer = Timer.periodic(maxStaleness, (_) {
      if (shouldTriggerStalenessPersist(
        lastPersistAt: _lastPersistAt,
        now: DateTime.now(),
        maxStaleness: maxStaleness,
      )) {
        unawaited(_runPersistIfNotInFlight());
      }
    });
  }

  void _stopStalenessPersistTimer() {
    _stalenessPersistTimer?.cancel();
    _stalenessPersistTimer = null;
  }

  void _stopActivityBasedPersist() {
    _stopStalenessPersistTimer();
    _cancelMidnightBoundaryTimer();
    deps.liveStepMonitor.onActivityIdle = null;
  }

  void _cancelMidnightBoundaryTimer() {
    _midnightBoundaryTimer?.cancel();
    _midnightBoundaryTimer = null;
  }

  void _scheduleMidnightBoundaryTimer() {
    if (!enableLiveStepPipeline || !_shellVisible()) {
      return;
    }
    _cancelMidnightBoundaryTimer();
    final snapshot = deps.timeProvider.snapshot();
    final delay = untilNextLocalMidnight(snapshot);
    _midnightBoundaryTimer = Timer(delay, () {
      unawaited(_onMidnightBoundaryTimerFired());
    });
    livePipelineLog(
      'app',
      'dayBoundary timer scheduled',
      details: {'delaySec': delay.inSeconds},
    );
  }

  Future<void> _onMidnightBoundaryTimerFired() async {
    livePipelineLog('app', 'dayBoundary timer FIRED');
    await _runLocalDayBoundaryIfNeeded();
    if (_mounted() && _livePipelineStarted) {
      _scheduleMidnightBoundaryTimer();
    }
  }

  Future<void> _runLocalDayBoundaryIfNeeded() async {
    if (!_shellVisible() || !enableLiveStepPipeline) {
      return;
    }
    final snapshot = deps.timeProvider.snapshot();
    _activeLocalDayIso ??= formatLocalDayIso(snapshot);
    if (!hasLocalDayChanged(
      previousDayIso: _activeLocalDayIso,
      snapshot: snapshot,
    )) {
      return;
    }
    await _runLocalDayBoundary();
  }

  Future<void> _runLocalDayBoundary() async {
    while (_dayBoundaryInFlight != null) {
      await _dayBoundaryInFlight;
    }

    final snapshot = deps.timeProvider.snapshot();
    _activeLocalDayIso ??= formatLocalDayIso(snapshot);
    if (!hasLocalDayChanged(
      previousDayIso: _activeLocalDayIso,
      snapshot: snapshot,
    )) {
      return;
    }

    late final Future<void> operation;
    operation = _runLocalDayBoundaryImpl();
    _dayBoundaryInFlight = operation;
    try {
      await operation;
    } finally {
      if (_dayBoundaryInFlight == operation) {
        _dayBoundaryInFlight = null;
      }
    }
  }

  Future<void> _runLocalDayBoundaryImpl() async {
    final snapshot = deps.timeProvider.snapshot();
    final fromDay =
        deps.liveStepMonitor.trackedLocalDay ?? _activeLocalDayIso;
    final toDay = localDayIsoFromSnapshot(snapshot);
    livePipelineLog(
      'app',
      'dayBoundary START',
      details: {'fromDay': fromDay, 'toDay': toDay},
    );

    if (_livePipelineStarted) {
      await _enqueuePersistCycle(
        enableGoalNotification: false,
        syncTodayAfter: false,
      );
    }
    await deps.liveStepMonitor.resetForNewLocalDay();
    _activeLocalDayIso = toDay;

    await _todayCubit?.refreshAfterDayRollover();
    await _historyCubit?.refresh(silent: true);
    await _myDataCubit?.refresh(silent: true);

    if (_livePipelineStarted && _todayCubit != null) {
      await _todayCubit!.syncSteps(
        deps.liveStepMonitor.currentTodaySteps,
      );
    }

    livePipelineLog(
      'app',
      'dayBoundary DONE',
      details: {
        'monitorTotal': deps.liveStepMonitor.currentTodaySteps,
        'cubitSteps': _todayCubit?.state.steps,
        'catchUp': _todayCubit?.state.foregroundCatchUp ?? false,
      },
    );
  }
}
