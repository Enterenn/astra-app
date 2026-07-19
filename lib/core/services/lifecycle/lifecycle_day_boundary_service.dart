import 'dart:async';

import '../../di/app_dependencies.dart';
import '../../debug/live_pipeline_log.dart';
import '../../time/local_day_boundary.dart';
import '../../time/local_day_formatter.dart';
import 'lifecycle_session_state.dart';

/// Midnight timer + local-day rollover (Story 25-2).
class LifecycleDayBoundaryService {
  LifecycleDayBoundaryService({
    required this.depsGetter,
    required this.session,
  });

  final AppDependencies Function() depsGetter;
  final LifecycleSessionState session;

  AppDependencies get deps => depsGetter();

  /// Wired by façade after [LifecyclePersistService] is constructed.
  late Future<void> Function({
    required bool enableGoalNotification,
    bool syncTodayAfter,
  }) enqueuePersistCycle;

  Timer? _midnightBoundaryTimer;
  String? _activeLocalDayIso;
  Future<void>? _dayBoundaryInFlight;

  void wireLiveMonitorDayBoundaryCallbacks() {
    final monitor = deps.liveStepMonitor;
    monitor.onLocalDayBoundary = () {
      unawaited(runLocalDayBoundaryIfNeeded());
    };
    _activeLocalDayIso ??= formatLocalDayIso(deps.timeProvider.snapshot());
  }

  void cancelMidnightBoundaryTimer() {
    _midnightBoundaryTimer?.cancel();
    _midnightBoundaryTimer = null;
  }

  void scheduleMidnightBoundaryTimer() {
    if (!session.enableLiveStepPipeline || !session.shellVisible()) {
      return;
    }
    cancelMidnightBoundaryTimer();
    final snapshot = deps.timeProvider.snapshot();
    final delay = untilNextLocalMidnight(snapshot);
    _midnightBoundaryTimer = Timer(delay, () {
      unawaited(onMidnightBoundaryTimerFired());
    });
    livePipelineLog(
      'app',
      'dayBoundary timer scheduled',
      details: {'delaySec': delay.inSeconds},
    );
  }

  Future<void> onMidnightBoundaryTimerFired() async {
    livePipelineLog('app', 'dayBoundary timer FIRED');
    await runLocalDayBoundaryIfNeeded();
    if (session.mounted() && session.livePipelineStarted) {
      scheduleMidnightBoundaryTimer();
    }
  }

  Future<void> runLocalDayBoundaryIfNeeded() async {
    if (!session.shellVisible() || !session.enableLiveStepPipeline) {
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
    await runLocalDayBoundary();
  }

  Future<void> runLocalDayBoundary() async {
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
    operation = runLocalDayBoundaryImpl();
    _dayBoundaryInFlight = operation;
    try {
      await operation;
    } finally {
      if (_dayBoundaryInFlight == operation) {
        _dayBoundaryInFlight = null;
      }
    }
  }

  Future<void> runLocalDayBoundaryImpl() async {
    final snapshot = deps.timeProvider.snapshot();
    final fromDay =
        deps.liveStepMonitor.trackedLocalDay ?? _activeLocalDayIso;
    final toDay = localDayIsoFromSnapshot(snapshot);
    livePipelineLog(
      'app',
      'dayBoundary START',
      details: {'fromDay': fromDay, 'toDay': toDay},
    );

    if (session.livePipelineStarted) {
      await enqueuePersistCycle(
        enableGoalNotification: false,
        syncTodayAfter: false,
      );
    }
    await deps.liveStepMonitor.resetForNewLocalDay();
    _activeLocalDayIso = toDay;

    await session.todayCubit?.refreshAfterDayRollover();
    await session.historyCubit?.refresh(silent: true);
    await session.myDataCubit?.refresh(silent: true);

    if (session.livePipelineStarted && session.todayCubit != null) {
      await session.todayCubit!.syncSteps(
        deps.liveStepMonitor.currentTodaySteps,
      );
    }

    livePipelineLog(
      'app',
      'dayBoundary DONE',
      details: {
        'monitorTotal': deps.liveStepMonitor.currentTodaySteps,
        'cubitSteps': session.todayCubit?.state.steps,
        'catchUp': session.todayCubit?.state.foregroundCatchUp ?? false,
      },
    );
  }
}
