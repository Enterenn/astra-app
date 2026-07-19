import 'dart:async';

import '../../di/app_dependencies.dart';
import 'lifecycle_policy.dart' show shouldTriggerStalenessPersist;
import 'lifecycle_session_state.dart';

/// Persist cycle serialization + activity/staleness timers (Story 25-2).
class LifecyclePersistService {
  LifecyclePersistService({
    required this.depsGetter,
    required this.session,
  });

  final AppDependencies Function() depsGetter;
  final LifecycleSessionState session;

  AppDependencies get deps => depsGetter();

  Timer? _stalenessPersistTimer;
  DateTime? _lastPersistAt;
  Future<void>? _persistInFlight;

  /// Must cover [LiveStepMonitor.maxBufferedReadings] so activity-idle persist
  /// normalizes every buffered phone reading in one collect.
  static const persistMaxReadingsPerSource = 250;

  /// Flushes buffered steps to SQLite when the app leaves the foreground.
  ///
  /// Best-effort before a possible process kill — no UI updates (user cannot see
  /// Today). [AppLifecycleState.resumed] still reconciles and syncs the cubit.
  Future<void> persistOnPause() async {
    if (!session.shellVisible()) {
      return;
    }
    await enqueuePersistCycle(enableGoalNotification: false);
  }

  /// Persists buffered phone readings via [BackgroundCollector] (sole bucket writer),
  /// then reconciles [LiveStepMonitor] from SQLite without lowering the overlay.
  Future<int> runPersistCycle({
    required bool enableGoalNotification,
    Duration? sourceTimeout,
  }) async {
    final monitor = deps.liveStepMonitor;
    final collector = deps.backgroundCollector;
    await monitor.beginReconcile();
    try {
      final upserted = await collector.collectOnce(
        maxReadingsPerSource: persistMaxReadingsPerSource,
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

  Future<void> runPersistIfNotInFlight() async {
    if (!session.shellVisible() || !session.livePipelineStarted) {
      return;
    }
    await enqueuePersistCycle(
      enableGoalNotification: session.appInBackground,
      syncTodayAfter: true,
    );
  }

  /// Serializes pause, idle, staleness, and resume persist cycles.
  Future<void> enqueuePersistCycle({
    required bool enableGoalNotification,
    bool syncTodayAfter = false,
  }) async {
    while (_persistInFlight != null) {
      await _persistInFlight;
    }

    late final Future<void> operation;
    operation = persistCycleWithOptionalSync(
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

  Future<void> persistCycleWithOptionalSync({
    required bool enableGoalNotification,
    required bool syncTodayAfter,
  }) async {
    if (session.enableLiveStepPipeline) {
      if (!session.livePipelineStarted && !enableGoalNotification) {
        return;
      }
      await runPersistCycle(enableGoalNotification: enableGoalNotification);
      if (syncTodayAfter) {
        await session.todayCubit?.syncSteps(
          deps.liveStepMonitor.currentTodaySteps,
        );
      }
      return;
    }

    await deps.backgroundCollector.collectOnce(
      enableGoalNotification: enableGoalNotification,
    );
    if (syncTodayAfter) {
      await session.todayCubit?.refresh(silent: true);
    }
  }

  Future<int> enqueuePersistCycleReturningCount({
    required bool enableGoalNotification,
    Duration? sourceTimeout,
  }) async {
    while (_persistInFlight != null) {
      await _persistInFlight;
    }

    late final Future<void> operation;
    var upserted = 0;
    operation = () async {
      if (session.enableLiveStepPipeline) {
        if (!session.livePipelineStarted && !enableGoalNotification) {
          return;
        }
        upserted = await runPersistCycle(
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

  void startActivityBasedPersist() {
    if (!session.enablePeriodicPersist) {
      return;
    }
    final monitor = deps.liveStepMonitor;
    monitor.onActivityIdle = () {
      unawaited(runPersistIfNotInFlight());
    };

    final maxStaleness = session.maxPersistStaleness;
    _stalenessPersistTimer?.cancel();
    _stalenessPersistTimer = Timer.periodic(maxStaleness, (_) {
      if (shouldTriggerStalenessPersist(
        lastPersistAt: _lastPersistAt,
        now: DateTime.now(),
        maxStaleness: maxStaleness,
      )) {
        unawaited(runPersistIfNotInFlight());
      }
    });
  }

  void stopStalenessPersistTimer() {
    _stalenessPersistTimer?.cancel();
    _stalenessPersistTimer = null;
  }

  void stopActivityBasedPersist() {
    stopStalenessPersistTimer();
    deps.liveStepMonitor.onActivityIdle = null;
  }
}
