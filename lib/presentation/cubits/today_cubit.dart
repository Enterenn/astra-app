import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/permissions/activity_permission_resolver.dart'
    show isActivityRecognitionGranted;
import '../../core/services/live_step_monitor.dart' show LiveStepMonitor;
import '../../core/time/time_provider.dart';
import '../../core/validation/step_goal_validator.dart';
import '../../data/contracts/contracts.dart';
import 'today/today_celebration_controller.dart';
import 'today/today_live_pipeline.dart';
import 'today/today_refresh_service.dart';
import 'today/today_session_cache.dart';
import 'today/today_snapshot_applier.dart';
import 'today/today_week_selection.dart';
import 'today_state.dart';

typedef ActivityPermissionChecker = Future<bool> Function();
typedef PostGoalUpdateCallback = Future<void> Function();

class TodayCubit extends Cubit<TodayState> {
  TodayCubit({
    required StepAggregationRepositoryContract stepAggregation,
    required UserSettingsRepositoryContract userSettings,
    required UserHealthMetricsRepositoryContract userHealthMetrics,
    required TimeProvider clock,
    ActivityPermissionChecker? activityPermissionGranted,
    bool? isIos,
    this.postGoalUpdate,
  }) : super(const TodayState.loading()) {
    final permissionChecker =
        activityPermissionGranted ?? isActivityRecognitionGranted;
    final ios = isIos ?? Platform.isIOS;
    _cache = TodaySessionCache();
    _userHealthMetrics = userHealthMetrics;

    _snapshot = TodaySnapshotApplier(
      cache: _cache,
      emit: emit,
      getState: () => state,
      isClosed: () => isClosed,
      userHealthMetrics: userHealthMetrics,
      clock: clock,
    );
    _celebration = TodayCelebrationController(
      emit: emit,
      getState: () => state,
      isClosed: () => isClosed,
      userSettings: userSettings,
      clock: clock,
    );
    _week = TodayWeekSelection(
      cache: _cache,
      emit: emit,
      getState: () => state,
      isClosed: () => isClosed,
      stepAggregation: stepAggregation,
      userHealthMetrics: userHealthMetrics,
      userSettings: userSettings,
      clock: clock,
    );
    _live = TodayLivePipeline(
      cache: _cache,
      emit: emit,
      getState: () => state,
      isClosed: () => isClosed,
      userSettings: userSettings,
      clock: clock,
    );
    _refresh = TodayRefreshService(
      cache: _cache,
      emit: emit,
      getState: () => state,
      isClosed: () => isClosed,
      stepAggregation: stepAggregation,
      userHealthMetrics: userHealthMetrics,
      userSettings: userSettings,
      clock: clock,
      activityPermissionGranted: permissionChecker,
      isIos: ios,
    );

    _snapshot.isViewingToday = _week.isViewingToday;
    _snapshot.maybeTriggerCelebration = _celebration.maybeTriggerCelebration;
    _celebration.isViewingToday = _week.isViewingToday;
    _week.applyTodaySnapshot = _snapshot.applyTodaySnapshot;
    _week.resolveTodayGoal = _snapshot.resolveTodayGoal;
    _week.loadLastDisplayedStepsForDisplayDay =
        _live.loadLastDisplayedStepsForDisplayDay;
    _live.isViewingToday = _week.isViewingToday;
    _live.applyTodaySnapshot = _snapshot.applyTodaySnapshot;
    _live.resolveTodayGoal = _snapshot.resolveTodayGoal;
    _live.patchTodayGoalMetForLiveSteps = _week.patchTodayGoalMetForLiveSteps;
    _refresh.loadWeekDays = _week.loadWeekDays;
    _refresh.resolveSelectedLocalDay = _week.resolveSelectedLocalDay;
    _refresh.applyTodaySnapshot = _snapshot.applyTodaySnapshot;
    _refresh.liveMetricsForSteps = _snapshot.liveMetricsForSteps;
    _refresh.isViewingToday = _week.isViewingToday;
  }

  final PostGoalUpdateCallback? postGoalUpdate;

  late final TodaySessionCache _cache;
  late final UserHealthMetricsRepositoryContract _userHealthMetrics;
  late final TodaySnapshotApplier _snapshot;
  late final TodayCelebrationController _celebration;
  late final TodayWeekSelection _week;
  late final TodayLivePipeline _live;
  late final TodayRefreshService _refresh;

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<int> get todayEditableGoal async {
    if (_cache.todayGoal != null) return _cache.todayGoal!;
    return _snapshot.resolveTodayGoal();
  }

  @visibleForTesting
  bool get liveStepAppliesPaused => _live.liveStepAppliesPaused;

  void setLiveStepAppliesPaused(bool paused) =>
      _live.setLiveStepAppliesPaused(paused);

  void attachLiveMonitor(
    LiveStepMonitor monitor, {
    bool replayLatest = true,
  }) =>
      _live.attachLiveMonitor(monitor, replayLatest: replayLatest);

  Future<void> refresh({bool silent = true}) =>
      _refresh.refresh(silent: silent);

  Future<void> refreshFastPath() => _refresh.refreshFastPath();

  Future<void> refreshMetadata() => _refresh.refreshMetadata();

  Future<void> refreshAfterDayRollover() =>
      _refresh.refreshAfterDayRollover();

  Future<void> syncSteps(
    int steps, {
    bool foregroundCatchUp = false,
    bool clampStaleDisplay = false,
  }) =>
      _live.syncSteps(
        steps,
        foregroundCatchUp: foregroundCatchUp,
        clampStaleDisplay: clampStaleDisplay,
      );

  void selectLocalDay(DateTime day) => _week.selectLocalDay(day);

  void clearForegroundCatchUp() => _live.clearForegroundCatchUp();

  Future<void> recordLastDisplayedSteps(int steps) =>
      _live.recordLastDisplayedSteps(steps);

  void dismissCelebration() => _celebration.dismissCelebration();

  Future<bool> updateDailyStepGoal(int goal) async {
    if (isClosed) return false;

    final validation = validateStepGoalInput(goal.toString());
    if (!validation.isValid || validation.parsedGoal == null) return false;
    final parsed = validation.parsedGoal!;
    final currentTodayGoal = await todayEditableGoal;
    if (isClosed) return false;
    if (parsed == currentTodayGoal) return false;

    try {
      await _userHealthMetrics.setDailyStepGoal(parsed);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('TodayCubit.updateDailyStepGoal persist failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }

    if (isClosed) return false;

    try {
      await postGoalUpdate?.call();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('TodayCubit.updateDailyStepGoal refresh failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }

    if (isClosed) return false;

    await refresh(silent: true);
    return true;
  }

  @override
  Future<void> close() async {
    await _live.close();
    return super.close();
  }
}
