import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/debug/live_pipeline_log.dart';
import '../../../core/health/stale_data_evaluator.dart';
import '../../../core/metrics/derived_activity_metrics.dart';
import '../../../core/time/local_day_formatter.dart';
import '../../../core/time/time_provider.dart';
import '../../../data/contracts/contracts.dart';
import '../../../core/permissions/activity_permission_resolver.dart'
    show ActivityPermissionStatusChecker;
import '../../../core/services/live_step_monitor.dart'
    show ActivityPermissionChecker;
import '../../../data/models/timeseries_sample_model.dart';
import '../../models/week_day_status.dart';
import '../today_state.dart';
import 'today_session_cache.dart';
import 'today_snapshot_applier.dart' show toMetricsSnapshot;

class TodayRefreshService {
  TodayRefreshService({
    required this.cache,
    required this.emit,
    required this.getState,
    required this.isClosed,
    required this.stepAggregation,
    required this.userHealthMetrics,
    required this.userSettings,
    required this.clock,
    required this.activityPermissionGranted,
    required this.activityPermissionStatus,
    required this.isIos,
  });

  final TodaySessionCache cache;
  final void Function(TodayState) emit;
  final TodayState Function() getState;
  final bool Function() isClosed;
  final StepAggregationRepositoryContract stepAggregation;
  final UserHealthMetricsRepositoryContract userHealthMetrics;
  final UserSettingsRepositoryContract userSettings;
  final TimeProvider clock;
  final ActivityPermissionChecker activityPermissionGranted;
  final ActivityPermissionStatusChecker activityPermissionStatus;
  final bool isIos;

  late Future<List<WeekDayStatus>> Function() loadWeekDays;
  late DateTime Function(List<WeekDayStatus>) resolveSelectedLocalDay;
  late ApplyTodaySnapshotFn applyTodaySnapshot;
  late ActivityMetricsSnapshot Function(int) liveMetricsForSteps;
  late bool Function() isViewingToday;

  bool _generationStillValid(int expectedGeneration) =>
      !isClosed() && expectedGeneration == cache.refreshGeneration;

  Future<void> refresh({bool silent = true}) async {
    if (isClosed()) return;
    if (cache.refreshInFlight != null) return cache.refreshInFlight!;

    cache.refreshInFlight = _refreshImpl(silent: silent);
    var succeeded = false;
    try {
      await cache.refreshInFlight!;
      succeeded = true;
    } finally {
      cache.refreshInFlight = null;
      if (succeeded) cache.refreshGeneration++;
    }
  }

  Future<void> refreshFastPath() async {
    if (isClosed()) return;
    final fastPathGeneration = ++cache.refreshGeneration;

    final granted = await activityPermissionGranted();
    if (!_generationStillValid(fastPathGeneration)) return;
    if (!granted) {
      final denial = await activityPermissionStatus();
      if (!_generationStillValid(fastPathGeneration)) return;
      emit(
        TodayState(
          status: TodayStatus.noPermission,
          activityPermissionDenial: denial,
          weekDays: [],
        ),
      );
      unawaited(_enrichAfterFastPath(fastPathGeneration));
      return;
    }

    final todayIso = formatLocalDayIso(clock.snapshot());
    final results = await Future.wait<Object?>([
      stepAggregation.getTodaySteps(),
      _resolveTodayGoalDirect(),
      userSettings.getLastDisplayedSteps(todayIso),
    ]);
    if (!_generationStillValid(fastPathGeneration)) return;

    final steps = results[0]! as int;
    final goal = results[1]! as int;
    final lastDisplayed = results[2] as int?;

    await applyTodaySnapshot(
      steps: steps,
      goal: goal,
      isStale: false,
      lastIngestionUtc: null,
      weekDays: const [],
      activityMetrics: liveMetricsForSteps(steps),
      lastDisplayedSteps: lastDisplayed,
      lastDisplayedStepsLoaded: true,
      skipCelebration: true,
    );
    if (!_generationStillValid(fastPathGeneration)) return;

    unawaited(_enrichAfterFastPath(fastPathGeneration));
  }

  Future<void> refreshMetadata() async {
    if (isClosed()) return;

    final granted = await activityPermissionGranted();
    if (isClosed()) return;

    if (!granted) {
      final weekDays = await loadWeekDays();
      if (isClosed()) return;
      final denial = await activityPermissionStatus();
      if (isClosed()) return;
      emit(
        TodayState(
          status: TodayStatus.noPermission,
          activityPermissionDenial: denial,
          weekDays: weekDays,
          activityMetrics: ActivityMetricsSnapshot.zero,
          selectedLocalDay: resolveSelectedLocalDay(weekDays),
        ),
      );
      return;
    }

    final todaySteps = cache.todaySteps ?? getState().steps;
    final results = await Future.wait<Object?>([
      _resolveTodayGoalDirect(),
      stepAggregation.getLastIngestionUtc(),
      stepAggregation.getTodayActiveBuckets(),
      userHealthMetrics.getHeightCm(),
      userHealthMetrics.getWeightKg(),
    ]);
    if (isClosed()) return;

    final goal = results[0]! as int;
    final lastUtc = results[1] as DateTime?;
    final buckets = results[2]! as List<TimeseriesSampleModel>;
    final heightCm = results[3] as int?;
    final weightKg = results[4] as double?;
    final stale = isStaleData(
      lastIngestionUtc: lastUtc,
      nowUtc: clock.nowUtc(),
      isIos: isIos,
    );

    final weekDays = await loadWeekDays();
    if (isClosed()) return;

    final metrics = toMetricsSnapshot(
      DerivedActivityMetrics.compute(
        displaySteps: todaySteps,
        activeBuckets: buckets,
        heightCm: heightCm,
        weightKg: weightKg,
      ),
    );

    await applyTodaySnapshot(
      steps: todaySteps,
      goal: goal,
      isStale: stale,
      lastIngestionUtc: lastUtc,
      weekDays: weekDays,
      activityMetrics: metrics,
      heightCm: heightCm,
      weightKg: weightKg,
      selectedLocalDay: resolveSelectedLocalDay(weekDays),
    );

    if (isViewingToday()) return;

    emit(
      getState().copyWith(
        weekDays: weekDays,
        isStale: stale,
        lastIngestionUtc: lastUtc,
        heightCm: heightCm,
        weightKg: weightKg,
        selectedLocalDay: resolveSelectedLocalDay(weekDays),
      ),
    );
  }

  Future<void> refreshAfterDayRollover() async {
    if (isClosed()) return;
    final state = getState();
    livePipelineLog(
      'cubit',
      'dayBoundary refresh',
      details: {
        'stateSteps': state.steps,
        'foregroundCatchUp': state.foregroundCatchUp,
        'showCelebration': state.showCelebration,
      },
    );
    if (state.foregroundCatchUp || state.showCelebration) {
      emit(
        state.copyWith(
          foregroundCatchUp: false,
          catchUpTargetSteps: null,
          showCelebration: false,
        ),
      );
    }
    cache.lastAppliedLocalDay = null;
    if (cache.refreshInFlight != null) return cache.refreshInFlight!;

    cache.refreshInFlight =
        _refreshImpl(silent: true, allowDayDecrease: true);
    var succeeded = false;
    try {
      await cache.refreshInFlight!;
      succeeded = true;
    } finally {
      cache.refreshInFlight = null;
      if (succeeded) cache.refreshGeneration++;
    }
  }

  Future<void> _enrichAfterFastPath(int expectedGeneration) async {
    try {
      if (!_generationStillValid(expectedGeneration)) return;

      if (getState().status == TodayStatus.noPermission) {
        final weekDays = await loadWeekDays();
        if (!_generationStillValid(expectedGeneration)) return;
        emit(
          getState().copyWith(
            weekDays: weekDays,
            selectedLocalDay: resolveSelectedLocalDay(weekDays),
          ),
        );
        return;
      }

      final results = await Future.wait<Object?>([
        stepAggregation.getTodayActiveBuckets(),
        userHealthMetrics.getHeightCm(),
        userHealthMetrics.getWeightKg(),
        stepAggregation.getLastIngestionUtc(),
      ]);
      if (!_generationStillValid(expectedGeneration)) return;

      final buckets = results[0]! as List<TimeseriesSampleModel>;
      final heightCm = results[1] as int?;
      final weightKg = results[2] as double?;
      final lastUtc = results[3] as DateTime?;

      final weekDays = await loadWeekDays();
      if (!_generationStillValid(expectedGeneration)) return;

      final stale = isStaleData(
        lastIngestionUtc: lastUtc,
        nowUtc: clock.nowUtc(),
        isIos: isIos,
      );

      final currentSteps = cache.todaySteps ?? getState().steps;
      final metrics = toMetricsSnapshot(
        DerivedActivityMetrics.compute(
          displaySteps: currentSteps,
          activeBuckets: buckets,
          heightCm: heightCm,
          weightKg: weightKg,
        ),
      );

      await applyTodaySnapshot(
        steps: currentSteps,
        goal: cache.todayGoal ?? getState().goal,
        isStale: stale,
        lastIngestionUtc: lastUtc,
        weekDays: weekDays,
        activityMetrics: metrics,
        heightCm: heightCm,
        weightKg: weightKg,
        selectedLocalDay: resolveSelectedLocalDay(weekDays),
      );
      if (!_generationStillValid(expectedGeneration)) return;

      if (!isViewingToday()) {
        emit(
          getState().copyWith(
            weekDays: weekDays,
            isStale: stale,
            lastIngestionUtc: lastUtc,
            heightCm: heightCm,
            weightKg: weightKg,
            selectedLocalDay: resolveSelectedLocalDay(weekDays),
          ),
        );
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('TodayCubit._enrichAfterFastPath error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (_generationStillValid(expectedGeneration)) {
        unawaited(refresh());
      }
    }
  }

  Future<void> _refreshImpl({
    required bool silent,
    bool allowDayDecrease = false,
  }) async {
    final state = getState();
    if (!silent && state.status != TodayStatus.loading) {
      emit(const TodayState.loading());
    }

    final granted = await activityPermissionGranted();
    if (isClosed()) return;
    if (!granted) {
      final weekDays = await loadWeekDays();
      if (isClosed()) return;
      final denial = await activityPermissionStatus();
      if (isClosed()) return;
      emit(
        TodayState(
          status: TodayStatus.noPermission,
          activityPermissionDenial: denial,
          weekDays: weekDays,
          activityMetrics: ActivityMetricsSnapshot.zero,
          selectedLocalDay: resolveSelectedLocalDay(weekDays),
        ),
      );
      return;
    }

    final todayIso = formatLocalDayIso(clock.snapshot());
    final results = await Future.wait<Object?>([
      stepAggregation.getTodaySteps(),
      _resolveTodayGoalDirect(),
      stepAggregation.getLastIngestionUtc(),
      stepAggregation.getTodayActiveBuckets(),
      userHealthMetrics.getHeightCm(),
      userHealthMetrics.getWeightKg(),
      userSettings.getLastDisplayedSteps(todayIso),
    ]);
    if (isClosed()) return;

    final steps = results[0]! as int;
    final goal = results[1]! as int;
    final lastUtc = results[2] as DateTime?;
    final buckets = results[3]! as List<TimeseriesSampleModel>;
    final heightCm = results[4] as int?;
    final weightKg = results[5] as double?;
    final lastDisplayedSteps = results[6] as int?;

    final stale = isStaleData(
      lastIngestionUtc: lastUtc,
      nowUtc: clock.nowUtc(),
      isIos: isIos,
    );

    final weekDays = await loadWeekDays();
    if (isClosed()) return;

    final metrics = toMetricsSnapshot(
      DerivedActivityMetrics.compute(
        displaySteps: steps,
        activeBuckets: buckets,
        heightCm: heightCm,
        weightKg: weightKg,
      ),
    );

    await applyTodaySnapshot(
      steps: steps,
      goal: goal,
      isStale: stale,
      lastIngestionUtc: lastUtc,
      weekDays: weekDays,
      activityMetrics: metrics,
      heightCm: heightCm,
      weightKg: weightKg,
      allowDecrease: allowDayDecrease,
      selectedLocalDay: resolveSelectedLocalDay(weekDays),
      lastDisplayedSteps: lastDisplayedSteps,
      lastDisplayedStepsLoaded: true,
    );

    if (isViewingToday()) return;

    emit(
      getState().copyWith(
        weekDays: weekDays,
        isStale: stale,
        lastIngestionUtc: lastUtc,
        heightCm: heightCm,
        weightKg: weightKg,
        selectedLocalDay: resolveSelectedLocalDay(weekDays),
      ),
    );
  }

  Future<int> _resolveTodayGoalDirect() async {
    final todayIso = formatLocalDayIso(clock.snapshot());
    return userHealthMetrics.getGoalForLocalDay(todayIso);
  }
}
