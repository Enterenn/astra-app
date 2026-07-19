import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../../core/debug/live_pipeline_log.dart';
import '../../../core/metrics/derived_activity_metrics.dart';
import '../../../core/services/live_step_monitor.dart';
import '../../../core/time/local_day_formatter.dart';
import '../../../core/time/time_provider.dart';
import '../../../data/contracts/contracts.dart';
import '../../models/week_day_status.dart';
import '../today_state.dart';
import 'today_session_cache.dart';

class TodayLivePipeline {
  TodayLivePipeline({
    required this.cache,
    required this.emit,
    required this.getState,
    required this.isClosed,
    required this.userSettings,
    required this.clock,
  });

  final TodaySessionCache cache;
  final void Function(TodayState) emit;
  final TodayState Function() getState;
  final bool Function() isClosed;
  final UserSettingsRepositoryContract userSettings;
  final TimeProvider clock;

  StreamSubscription<int>? _liveStepsSubscription;
  LiveStepMonitor? _attachedMonitor;
  bool _pauseLiveStepApplies = false;

  late bool Function() isViewingToday;
  late ApplyTodaySnapshotFn applyTodaySnapshot;
  late Future<int> Function() resolveTodayGoal;
  late List<WeekDayStatus> Function(
    List<WeekDayStatus>, {
    required int liveSteps,
    required int todayGoal,
  }) patchTodayGoalMetForLiveSteps;

  bool get liveStepAppliesPaused => _pauseLiveStepApplies;

  void setLiveStepAppliesPaused(bool paused) {
    if (_pauseLiveStepApplies == paused) return;
    _pauseLiveStepApplies = paused;
    final state = getState();
    livePipelineLog(
      'cubit',
      paused ? 'live applies PAUSED' : 'live applies RESUMED',
      details: {
        'stateSteps': state.steps,
        'foregroundCatchUp': state.foregroundCatchUp,
      },
    );
    if (!paused &&
        !state.foregroundCatchUp &&
        _attachedMonitor != null &&
        state.status != TodayStatus.noPermission &&
        isViewingToday()) {
      unawaited(_applyLiveSteps(_attachedMonitor!.currentTodaySteps));
    }
  }

  void attachLiveMonitor(LiveStepMonitor monitor, {bool replayLatest = true}) {
    _attachedMonitor = monitor;
    unawaited(_liveStepsSubscription?.cancel());
    final state = getState();
    livePipelineLog(
      'cubit',
      'attachLiveMonitor',
      details: {
        'replayLatest': replayLatest,
        'monitorRunning': monitor.isRunning,
        'monitorTotal': monitor.currentTodaySteps,
        'stateSteps': state.steps,
        'livePaused': _pauseLiveStepApplies,
        'foregroundCatchUp': state.foregroundCatchUp,
      },
    );
    _liveStepsSubscription = monitor
        .watchTodaySteps(replayLatest: replayLatest)
        .listen((steps) {
          if (_pauseLiveStepApplies) {
            livePipelineLog(
              'cubit',
              'live IGNORED reason=paused_applies',
              details: {'steps': steps, 'stateSteps': getState().steps},
              minInterval: const Duration(seconds: 3),
            );
            return;
          }
          if (getState().foregroundCatchUp) {
            livePipelineLog(
              'cubit',
              'live IGNORED reason=foreground_catch_up',
              details: {
                'steps': steps,
                'catchUpTarget': getState().catchUpTargetSteps,
              },
              minInterval: const Duration(seconds: 3),
            );
            return;
          }
          if (!isViewingToday()) {
            unawaited(_applyLiveSteps(steps));
            return;
          }
          unawaited(_applyLiveSteps(steps));
        });
  }

  Future<void> syncSteps(
    int steps, {
    bool foregroundCatchUp = false,
    bool clampStaleDisplay = false,
  }) async {
    if (isClosed()) return;
    final state = getState();
    if (state.status == TodayStatus.noPermission) return;
    if (!state.lastDisplayedStepsLoaded) {
      var goal = cache.todayGoal;
      if (goal == null) {
        goal = await resolveTodayGoal();
        if (isClosed()) return;
      }
      cache.todaySteps = steps;
      cache.todayGoal = goal;
      return;
    }

    if (foregroundCatchUp) {
      if (!isViewingToday()) return;
      if (steps <= (cache.todaySteps ?? getState().steps)) {
        livePipelineLog(
          'cubit',
          'syncSteps catch-up SKIPPED (already at target)',
          details: {'steps': steps, 'stateSteps': getState().steps},
        );
        return;
      }
      livePipelineLog(
        'cubit',
        'syncSteps catch-up START',
        details: {'from': getState().steps, 'to': steps},
      );
      emit(
        getState().copyWith(foregroundCatchUp: true, catchUpTargetSteps: steps),
      );
      return;
    }

    if (clampStaleDisplay) {
      await _clampStaleLastDisplayed(steps);
    }

    var goal = cache.todayGoal;
    if (goal == null) {
      goal = await resolveTodayGoal();
      if (isClosed()) return;
    }

    await applyTodaySnapshot(
      steps: steps,
      goal: goal,
      isStale: getState().isStale,
      lastIngestionUtc: getState().lastIngestionUtc,
      activityMetrics: _liveMetricsForSteps(steps),
      heightCm: getState().heightCm,
      weightKg: getState().weightKg,
      allowDecrease: clampStaleDisplay,
    );
  }

  void clearForegroundCatchUp() {
    if (isClosed() || !getState().foregroundCatchUp) return;
    final state = getState();
    final target =
        state.catchUpTargetSteps ?? _attachedMonitor?.currentTodaySteps;
    livePipelineLog(
      'cubit',
      'catch-up DONE',
      details: {'target': target, 'stateSteps': state.steps},
    );
    emit(state.copyWith(foregroundCatchUp: false, catchUpTargetSteps: null));
    if (target != null) {
      unawaited(syncSteps(target));
    }
  }

  Future<void> recordLastDisplayedSteps(int steps) async {
    if (isClosed() || steps < 0) return;
    final state = getState();
    if (state.lastDisplayedSteps == steps) return;
    if (!userSettings.isDatabaseOpen) return;
    emit(
      state.copyWith(
        lastDisplayedSteps: steps,
        lastDisplayedStepsLoaded: true,
      ),
    );
    final localDayIso = _displayLocalDayIso();
    unawaited(
      _persistLastDisplayedSteps(localDayIso: localDayIso, steps: steps),
    );
  }

  Future<int?> loadLastDisplayedStepsForDisplayDay() {
    return userSettings.getLastDisplayedSteps(_displayLocalDayIso());
  }

  String _displayLocalDayIso() {
    final selected = getState().selectedLocalDay;
    if (selected != null && !isViewingToday()) {
      return localDayIsoFromDateOnly(selected);
    }
    return formatLocalDayIso(clock.snapshot());
  }

  Future<void> _persistLastDisplayedSteps({
    required String localDayIso,
    required int steps,
  }) async {
    try {
      await userSettings.setLastDisplayedSteps(
        localDayIso: localDayIso,
        steps: steps,
      );
    } on DatabaseException {
      return;
    }
  }

  Future<void> _applyLiveSteps(int steps) async {
    if (isClosed()) return;
    final state = getState();
    if (state.status == TodayStatus.noPermission) {
      livePipelineLog(
        'cubit',
        'applyLiveSteps SKIPPED reason=no_permission',
        details: {'steps': steps},
      );
      return;
    }

    var goal = cache.todayGoal;
    if (goal == null) {
      goal = await resolveTodayGoal();
      if (isClosed()) return;
    }
    final previous = cache.todaySteps ?? getState().steps;
    final s = getState();
    final weekDays = isViewingToday()
        ? patchTodayGoalMetForLiveSteps(
            s.weekDays,
            liveSteps: steps,
            todayGoal: goal,
          )
        : s.weekDays;

    await applyTodaySnapshot(
      steps: steps,
      goal: goal,
      isStale: s.isStale,
      lastIngestionUtc: s.lastIngestionUtc,
      weekDays: weekDays,
      activityMetrics: _liveMetricsForSteps(steps),
      heightCm: s.heightCm,
      weightKg: s.weightKg,
    );
    if (isViewingToday() && steps != previous) {
      livePipelineLog(
        'cubit',
        'applyLiveSteps',
        details: {
          'from': previous,
          'to': steps,
          'status': getState().status.name,
        },
        minInterval: const Duration(milliseconds: 400),
      );
    }
  }

  Future<void> _clampStaleLastDisplayed(int truthSteps) async {
    final todayIso = formatLocalDayIso(clock.snapshot());
    final lastDisplayed =
        await userSettings.getLastDisplayedSteps(todayIso);
    if (lastDisplayed == null || lastDisplayed <= truthSteps) return;
    livePipelineLog(
      'cubit',
      'clamp stale lastDisplayed',
      details: {'from': lastDisplayed, 'to': truthSteps},
    );
    await userSettings.setLastDisplayedSteps(
      localDayIso: todayIso,
      steps: truthSteps,
    );
    if (isClosed()) return;
    emit(
      getState().copyWith(
        lastDisplayedSteps: truthSteps,
        lastDisplayedStepsLoaded: true,
      ),
    );
  }

  ActivityMetricsSnapshot _liveMetricsForSteps(int steps) {
    final state = getState();
    final bucketMetrics = cache.todayMetrics ?? state.activityMetrics;
    return ActivityMetricsSnapshot(
      distanceKm: DerivedActivityMetrics.computeDistanceKm(
        displaySteps: steps,
        heightCm: state.heightCm,
      ),
      walkingDuration: bucketMetrics.walkingDuration,
      kcal: bucketMetrics.kcal,
    );
  }

  Future<void> close() async {
    unawaited(_liveStepsSubscription?.cancel());
    _liveStepsSubscription = null;
    _attachedMonitor = null;
  }
}
