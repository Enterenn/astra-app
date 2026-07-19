import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../presentation/cubits/history_cubit.dart';
import '../../presentation/cubits/my_data_cubit.dart';
import '../../presentation/cubits/today_cubit.dart';
import '../debug/live_pipeline_log.dart';
import '../di/app_dependencies.dart';
import 'lifecycle/lifecycle_day_boundary_service.dart';
import 'lifecycle/lifecycle_live_pipeline_service.dart';
import 'lifecycle/lifecycle_persist_service.dart';
import 'lifecycle/lifecycle_policy.dart';
import 'lifecycle/lifecycle_session_state.dart';

export 'lifecycle/lifecycle_policy.dart'
    show
        kMaxPersistStaleness,
        kResumePhoneCatchUpTimeout,
        runSerializedLifecycleTransition,
        shouldRunResumePhoneCatchUp,
        shouldRunResumePhonePeek,
        shouldTriggerStalenessPersist;

/// Live pipeline orchestration extracted from [AstraApp] (Story 18-1).
///
/// Façade over focused lifecycle collaborators (Story 25-2).
class AppLifecycleCoordinator {
  AppLifecycleCoordinator({
    required this.depsGetter,
    bool enablePeriodicPersist = true,
    bool enableLiveStepPipeline = true,
    Duration maxPersistStaleness = kMaxPersistStaleness,
    Duration minPauseForPhoneCatchUp = const Duration(seconds: 10),
  }) {
    _session = LifecycleSessionState()
      ..enablePeriodicPersist = enablePeriodicPersist
      ..enableLiveStepPipeline = enableLiveStepPipeline
      ..maxPersistStaleness = maxPersistStaleness
      ..minPauseForPhoneCatchUp = minPauseForPhoneCatchUp;

    _persist = LifecyclePersistService(
      depsGetter: depsGetter,
      session: _session,
    );
    _dayBoundary = LifecycleDayBoundaryService(
      depsGetter: depsGetter,
      session: _session,
    );
    _livePipeline = LifecycleLivePipelineService(
      depsGetter: depsGetter,
      session: _session,
    );

    _dayBoundary.enqueuePersistCycle = _persist.enqueuePersistCycle;
    _livePipeline.runLocalDayBoundaryIfNeeded =
        _dayBoundary.runLocalDayBoundaryIfNeeded;
    _livePipeline.enqueuePersistCycleReturningCount =
        _persist.enqueuePersistCycleReturningCount;
    _livePipeline.wireLiveMonitorDayBoundaryCallbacks =
        _dayBoundary.wireLiveMonitorDayBoundaryCallbacks;
    _livePipeline.startActivityBasedPersist = _persist.startActivityBasedPersist;
    _livePipeline.scheduleMidnightBoundaryTimer =
        _dayBoundary.scheduleMidnightBoundaryTimer;
  }

  final AppDependencies Function() depsGetter;

  AppDependencies get deps => depsGetter();

  late final LifecycleSessionState _session;
  late final LifecyclePersistService _persist;
  late final LifecycleDayBoundaryService _dayBoundary;
  late final LifecycleLivePipelineService _livePipeline;

  Future<void>? _lifecycleTransitionInFlight;

  bool get enablePeriodicPersist => _session.enablePeriodicPersist;
  set enablePeriodicPersist(bool value) =>
      _session.enablePeriodicPersist = value;

  bool get enableLiveStepPipeline => _session.enableLiveStepPipeline;
  set enableLiveStepPipeline(bool value) =>
      _session.enableLiveStepPipeline = value;

  Duration get maxPersistStaleness => _session.maxPersistStaleness;
  set maxPersistStaleness(Duration value) =>
      _session.maxPersistStaleness = value;

  Duration get minPauseForPhoneCatchUp => _session.minPauseForPhoneCatchUp;
  set minPauseForPhoneCatchUp(Duration value) =>
      _session.minPauseForPhoneCatchUp = value;

  /// Cold-start / resume backfill future passed to [AppScaffold].
  Future<int> get foregroundBackfill => _session.foregroundBackfill;

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
    _session.isMounted = isMounted;
    _session.showMainShell = showMainShell;
    this.enablePeriodicPersist = enablePeriodicPersist;
    this.enableLiveStepPipeline = enableLiveStepPipeline;
    this.maxPersistStaleness = maxPersistStaleness;
    this.minPauseForPhoneCatchUp = minPauseForPhoneCatchUp;

    if (initialShowMainShell) {
      _session.coldStartStopwatch = Stopwatch()..start();
      livePipelineLog('app', 'cold start START', details: {'elapsedMs': 0});
    }
    _session.foregroundBackfill = enableLiveStepPipeline
        ? _persist.runPersistCycle(
            enableGoalNotification: false,
            sourceTimeout: Duration.zero,
          )
        : deps.backgroundCollector.collectOnce(
            enableGoalNotification: false,
          );
  }

  void bindTodayCubit(TodayCubit? cubit) => _session.todayCubit = cubit;

  void bindHistoryCubit(HistoryCubit? cubit) => _session.historyCubit = cubit;

  void bindMyDataCubit(MyDataCubit? cubit) => _session.myDataCubit = cubit;

  void onTodayCubitReady(TodayCubit cubit) {
    _session.todayCubit = cubit;
    if (enableLiveStepPipeline) {
      unawaited(_livePipeline.ensureLivePipelineAttached());
    } else {
      unawaited(_livePipeline.initialTodayRefresh());
    }
  }

  void onHistoryCubitReady(HistoryCubit cubit) {
    _session.historyCubit = cubit;
  }

  void onMyDataCubitReady(MyDataCubit cubit) {
    _session.myDataCubit = cubit;
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
    return _persist.enqueuePersistCycle(
      enableGoalNotification: enableGoalNotification,
      syncTodayAfter: syncTodayAfter,
    );
  }

  /// Test hook — day-boundary gate without midnight timer.
  @visibleForTesting
  Future<void> runLocalDayBoundaryIfNeededForTest() {
    return _dayBoundary.runLocalDayBoundaryIfNeeded();
  }

  void dispose() {
    _persist.stopActivityBasedPersist();
    _dayBoundary.cancelMidnightBoundaryTimer();
    unawaited(deps.liveStepMonitor.stop());
  }

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
    _session.backgroundedAt = DateTime.now();
    livePipelineLog(
      'app',
      'lifecycle PAUSED',
      details: {
        'monitorRunning': deps.liveStepMonitor.isRunning,
        'monitorTotal': deps.liveStepMonitor.currentTodaySteps,
        'cubitSteps': _session.todayCubit?.state.steps,
      },
    );
    await _persist.persistOnPause();
    if (!_session.shellVisible()) {
      return;
    }
    _session.stepsAtBackground = await deps.stepAggregation.getTodaySteps();
    _persist.stopStalenessPersistTimer();
    _session.appInBackground = true;
    _session.todayCubit?.setLiveStepAppliesPaused(true);
    final healthFgs = deps.healthForegroundCoordinator;
    await healthFgs.setUiActive(false);
    await healthFgs.startHealthCollectionService();
    await deps.backgroundCollector.maybeNotifyGoalReachedIfGoalMet();
  }

  Future<void> _onAppForegrounded() async {
    _session.appInBackground = false;
    livePipelineLog('app', 'lifecycle RESUMED');
    await deps.databaseSession.ensureOpen();
    final healthFgs = deps.healthForegroundCoordinator;
    await healthFgs.stopHealthCollectionService();
    await healthFgs.setUiActive(true);
    // Heavy DB maintenance (downsample + VACUUM) must not run here — it can
    // invalidate the UI SQLite connection while _resumeLivePipeline reads/writes.
    // Android: WorkManager; manual: My Data purge/optimize flows.
    if (enableLiveStepPipeline && _session.shellVisible()) {
      await _livePipeline.resumeLivePipeline();
    } else {
      await _persist.enqueuePersistCycle(
        enableGoalNotification: false,
        syncTodayAfter: true,
      );
      await _session.todayCubit?.refreshMetadata();
      await _session.historyCubit?.refresh(silent: true);
      await _session.myDataCubit?.refresh(silent: true);
    }
    if (_session.livePipelineStarted && enablePeriodicPersist) {
      _persist.startActivityBasedPersist();
    }
    if (_session.livePipelineStarted) {
      _dayBoundary.wireLiveMonitorDayBoundaryCallbacks();
      _dayBoundary.scheduleMidnightBoundaryTimer();
    }
  }
}
