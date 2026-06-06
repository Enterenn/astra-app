import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/debug/live_pipeline_log.dart';
import '../../core/health/stale_data_evaluator.dart';
import '../../core/metrics/derived_activity_metrics.dart';
import '../../core/permissions/activity_permission_resolver.dart'
    show isActivityRecognitionGranted;
import '../../core/services/live_step_monitor.dart';
import '../../core/time/calendar_week.dart';
import '../../core/time/local_day_calculator.dart';
import '../../core/time/local_day_formatter.dart';
import '../../core/time/time_provider.dart';
import '../../core/time/timestamp_codec.dart';
import '../../core/validation/step_goal_validator.dart';
import '../../data/models/timeseries_sample_model.dart';
import '../../data/repositories/step_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../models/week_day_status.dart';
import 'today_state.dart';

typedef ActivityPermissionChecker = Future<bool> Function();
typedef PostGoalUpdateCallback = Future<void> Function();

class TodayCubit extends Cubit<TodayState> {
  TodayCubit({
    required this.stepRepository,
    required this.userPreferences,
    required this.clock,
    ActivityPermissionChecker? activityPermissionGranted,
    bool? isIos,
    this.postGoalUpdate,
  }) : _activityPermissionGranted =
           activityPermissionGranted ?? isActivityRecognitionGranted,
       _isIos = isIos ?? Platform.isIOS,
       super(const TodayState.loading());

  final StepRepository stepRepository;
  final UserPreferencesRepository userPreferences;
  final TimeProvider clock;
  final ActivityPermissionChecker _activityPermissionGranted;
  final bool _isIos;
  final PostGoalUpdateCallback? postGoalUpdate;

  Future<void>? _refreshInFlight;
  StreamSubscription<int>? _liveStepsSubscription;
  LiveStepMonitor? _attachedMonitor;
  String? _lastAppliedLocalDay;
  bool _pauseLiveStepApplies = false;

  /// While true, live monitor events do not update [TodayState] (screen off).
  @visibleForTesting
  bool get liveStepAppliesPaused => _pauseLiveStepApplies;

  void setLiveStepAppliesPaused(bool paused) {
    if (_pauseLiveStepApplies == paused) {
      return;
    }
    _pauseLiveStepApplies = paused;
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
        state.status != TodayStatus.noPermission) {
      unawaited(_applyLiveSteps(_attachedMonitor!.currentTodaySteps));
    }
  }

  /// Subscribes to [monitor] live step stream (replays current value immediately).
  void attachLiveMonitor(
    LiveStepMonitor monitor, {
    bool replayLatest = true,
  }) {
    _attachedMonitor = monitor;
    _liveStepsSubscription?.cancel();
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
              details: {'steps': steps, 'stateSteps': state.steps},
              minInterval: const Duration(seconds: 3),
            );
            return;
          }
          if (state.foregroundCatchUp) {
            livePipelineLog(
              'cubit',
              'live IGNORED reason=foreground_catch_up',
              details: {
                'steps': steps,
                'catchUpTarget': state.catchUpTargetSteps,
              },
              minInterval: const Duration(seconds: 3),
            );
            return;
          }
          unawaited(_applyLiveSteps(steps));
        });
  }

  /// Persists a new daily step goal and refreshes ring + week strip.
  Future<bool> updateDailyStepGoal(int goal) async {
    if (isClosed) {
      return false;
    }

    final validation = validateStepGoalInput(goal.toString());
    if (!validation.isValid || validation.parsedGoal == null) {
      return false;
    }
    final parsed = validation.parsedGoal!;
    if (parsed == state.goal) {
      return false;
    }

    try {
      await userPreferences.setDailyStepGoal(parsed);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('TodayCubit.updateDailyStepGoal persist failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }

    if (isClosed) {
      return false;
    }

    try {
      await postGoalUpdate?.call();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('TodayCubit.updateDailyStepGoal refresh failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }

    if (isClosed) {
      return false;
    }

    await refresh(silent: true);
    return true;
  }

  /// Refreshes dashboard data from repositories (read-only).
  ///
  /// When [silent] is true (default), keeps the current UI while fetching so
  /// periodic, resume, and ingestion refreshes do not flash the skeleton or
  /// hide the stale banner.
  Future<void> refresh({bool silent = true}) async {
    if (isClosed) {
      return;
    }

    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }

    _refreshInFlight = _refreshImpl(silent: silent);
    try {
      await _refreshInFlight!;
    } finally {
      _refreshInFlight = null;
    }
  }

  /// Applies [steps] from the live monitor after resume or reconcile.
  ///
  /// Set [foregroundCatchUp] on app resume so [GoalRing] plays a full count-up
  /// from the last displayed value instead of live micro-ticks.
  ///
  /// [clampStaleDisplay] on live-pipeline bind lowers inflated
  /// [UserPreferencesRepository.getLastDisplayedSteps] when they exceed the
  /// monitor/SQLite truth so live increments are visible immediately.
  Future<void> syncSteps(
    int steps, {
    bool foregroundCatchUp = false,
    bool clampStaleDisplay = false,
  }) async {
    if (isClosed) {
      return;
    }
    if (state.status == TodayStatus.noPermission) {
      return;
    }

    if (foregroundCatchUp) {
      if (steps <= state.steps) {
        livePipelineLog(
          'cubit',
          'syncSteps catch-up SKIPPED (already at target)',
          details: {'steps': steps, 'stateSteps': state.steps},
        );
        return;
      }
      livePipelineLog(
        'cubit',
        'syncSteps catch-up START',
        details: {
          'from': state.steps,
          'to': steps,
        },
      );
      emit(
        state.copyWith(
          foregroundCatchUp: true,
          catchUpTargetSteps: steps,
        ),
      );
      return;
    }

    if (clampStaleDisplay) {
      await _clampStaleLastDisplayed(steps);
    }

    var goal = state.goal;
    if (state.status == TodayStatus.loading) {
      goal = await userPreferences.getDailyStepGoal();
      if (isClosed) {
        return;
      }
    }

    await _applyTodaySnapshot(
      steps: steps,
      goal: goal,
      isStale: state.isStale,
      lastIngestionUtc: state.lastIngestionUtc,
      activityMetrics: _liveMetricsForSteps(steps),
      heightCm: state.heightCm,
      weightKg: state.weightKg,
      allowDecrease: clampStaleDisplay,
    );
  }

  /// Clears [TodayState.foregroundCatchUp] after [GoalRing] finishes catch-up.
  void clearForegroundCatchUp() {
    if (isClosed || !state.foregroundCatchUp) {
      return;
    }
    final target =
        state.catchUpTargetSteps ?? _attachedMonitor?.currentTodaySteps;
    livePipelineLog(
      'cubit',
      'catch-up DONE',
      details: {
        'target': target,
        'stateSteps': state.steps,
      },
    );
    emit(
      state.copyWith(
        foregroundCatchUp: false,
        catchUpTargetSteps: null,
      ),
    );
    if (target != null) {
      unawaited(syncSteps(target));
    }
  }

  /// Updates Today after local midnight: SQLite truth, cleared catch-up/celebration.
  Future<void> refreshAfterDayRollover() async {
    if (isClosed) {
      return;
    }
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
    _lastAppliedLocalDay = null;
    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }
    _refreshInFlight = _refreshImpl(silent: true, allowDayDecrease: true);
    try {
      await _refreshInFlight!;
    } finally {
      _refreshInFlight = null;
    }
  }

  /// Updates goal, stale metadata, and permission without re-reading step count.
  Future<void> refreshMetadata() async {
    if (isClosed) {
      return;
    }

    final granted = await _activityPermissionGranted();
    if (isClosed) {
      return;
    }
    final goalForWeek = state.status == TodayStatus.loading
        ? await userPreferences.getDailyStepGoal()
        : state.goal;
    if (isClosed) {
      return;
    }

    if (!granted) {
      final weekDays = await _loadWeekDays(goal: goalForWeek);
      if (isClosed) {
        return;
      }
      emit(
        TodayState(
          status: TodayStatus.noPermission,
          weekDays: weekDays,
          activityMetrics: ActivityMetricsSnapshot.zero,
        ),
      );
      return;
    }

    final results = await Future.wait<Object?>([
      userPreferences.getDailyStepGoal(),
      stepRepository.getLastIngestionUtc(),
      stepRepository.getTodayActiveBuckets(),
      userPreferences.getHeightCm(),
      userPreferences.getWeightKg(),
    ]);
    if (isClosed) {
      return;
    }

    final goal = results[0]! as int;
    final lastUtc = results[1] as DateTime?;
    final buckets = results[2]! as List<TimeseriesSampleModel>;
    final heightCm = results[3] as int?;
    final weightKg = results[4] as double?;
    final stale = isStaleData(
      lastIngestionUtc: lastUtc,
      nowUtc: clock.nowUtc(),
      isIos: _isIos,
    );

    final weekDays = await _loadWeekDays(goal: goal);
    if (isClosed) {
      return;
    }

    final metrics = _toMetricsSnapshot(
      DerivedActivityMetrics.compute(
        displaySteps: state.steps,
        activeBuckets: buckets,
        heightCm: heightCm,
        weightKg: weightKg,
      ),
    );

    await _applyTodaySnapshot(
      steps: state.steps,
      goal: goal,
      isStale: stale,
      lastIngestionUtc: lastUtc,
      weekDays: weekDays,
      activityMetrics: metrics,
      heightCm: heightCm,
      weightKg: weightKg,
    );
  }

  Future<void> _refreshImpl({
    required bool silent,
    bool allowDayDecrease = false,
  }) async {
    if (!silent && state.status != TodayStatus.loading) {
      emit(const TodayState.loading());
    }

    final granted = await _activityPermissionGranted();
    if (isClosed) {
      return;
    }
    if (!granted) {
      final goal = await userPreferences.getDailyStepGoal();
      if (isClosed) {
        return;
      }
      final weekDays = await _loadWeekDays(goal: goal);
      if (isClosed) {
        return;
      }
      emit(
        TodayState(
          status: TodayStatus.noPermission,
          weekDays: weekDays,
          activityMetrics: ActivityMetricsSnapshot.zero,
        ),
      );
      return;
    }

    final results = await Future.wait<Object?>([
      stepRepository.getTodaySteps(),
      userPreferences.getDailyStepGoal(),
      stepRepository.getLastIngestionUtc(),
      stepRepository.getTodayActiveBuckets(),
      userPreferences.getHeightCm(),
      userPreferences.getWeightKg(),
    ]);
    if (isClosed) {
      return;
    }

    final stepsFromDb = results[0]! as int;
    // SQLite is authoritative on refresh; stale-high lastDisplayed prefs are
    // reconciled on live-pipeline bind via [syncSteps] + [clampStaleDisplay].
    final steps = stepsFromDb;
    final goal = results[1]! as int;
    final lastUtc = results[2] as DateTime?;
    final buckets = results[3]! as List<TimeseriesSampleModel>;
    final heightCm = results[4] as int?;
    final weightKg = results[5] as double?;

    final stale = isStaleData(
      lastIngestionUtc: lastUtc,
      nowUtc: clock.nowUtc(),
      isIos: _isIos,
    );

    final weekDays = await _loadWeekDays(goal: goal);
    if (isClosed) {
      return;
    }

    final metrics = _toMetricsSnapshot(
      DerivedActivityMetrics.compute(
        displaySteps: steps,
        activeBuckets: buckets,
        heightCm: heightCm,
        weightKg: weightKg,
      ),
    );

    await _applyTodaySnapshot(
      steps: steps,
      goal: goal,
      isStale: stale,
      lastIngestionUtc: lastUtc,
      weekDays: weekDays,
      activityMetrics: metrics,
      heightCm: heightCm,
      weightKg: weightKg,
      allowDecrease: allowDayDecrease,
    );
  }

  Future<void> _applyLiveSteps(int steps) async {
    if (isClosed) {
      return;
    }

    if (state.status == TodayStatus.noPermission) {
      livePipelineLog(
        'cubit',
        'applyLiveSteps SKIPPED reason=no_permission',
        details: {'steps': steps},
      );
      return;
    }

    var goal = state.goal;
    if (state.status == TodayStatus.loading) {
      goal = await userPreferences.getDailyStepGoal();
      if (isClosed) {
        return;
      }
    }
    final previous = state.steps;
    await _applyTodaySnapshot(
      steps: steps,
      goal: goal,
      isStale: state.isStale,
      lastIngestionUtc: state.lastIngestionUtc,
      weekDays: state.weekDays,
      activityMetrics: _liveMetricsForSteps(steps),
      heightCm: state.heightCm,
      weightKg: state.weightKg,
    );
    if (steps != previous) {
      livePipelineLog(
        'cubit',
        'applyLiveSteps',
        details: {
          'from': previous,
          'to': steps,
          'status': state.status.name,
        },
        minInterval: const Duration(milliseconds: 400),
      );
    }
  }

  Future<List<WeekDayStatus>> _loadWeekDays({required int goal}) async {
    final timeSnapshot = clock.snapshot();
    final zoneOffset = TimestampCodec.formatZoneOffset(timeSnapshot.zoneOffset);
    final referenceToday = LocalDayCalculator.localDay(
      utc: timeSnapshot.nowUtc,
      zoneOffset: zoneOffset,
    );
    final weekDayKeys = CalendarWeek.daysContaining(referenceToday);

    final aggregates = await stepRepository.getChartDailyAggregates(days: 7);
    final stepsByDay = {
      for (final aggregate in aggregates)
        aggregate.localDay: aggregate.totalSteps,
    };

    return [
      for (final day in weekDayKeys)
        WeekDayStatus(
          localDay: day,
          weekdayLabel: CalendarWeek.weekdayLabelFor(day),
          dayNumber: day.day,
          isToday: day == referenceToday,
          isFuture: day.isAfter(referenceToday),
          goalMet: goal > 0 && (stepsByDay[day] ?? 0) >= goal,
        ),
    ];
  }

  Future<void> _clampStaleLastDisplayed(int truthSteps) async {
    final todayIso = formatLocalDayIso(clock.snapshot());
    final lastDisplayed = await userPreferences.getLastDisplayedSteps(todayIso);
    if (lastDisplayed == null || lastDisplayed <= truthSteps) {
      return;
    }
    livePipelineLog(
      'cubit',
      'clamp stale lastDisplayed',
      details: {
        'from': lastDisplayed,
        'to': truthSteps,
      },
    );
    await userPreferences.setLastDisplayedSteps(
      localDayIso: todayIso,
      steps: truthSteps,
    );
  }

  ActivityMetricsSnapshot _liveMetricsForSteps(int steps) {
    return ActivityMetricsSnapshot(
      distanceKm: DerivedActivityMetrics.computeDistanceKm(
        displaySteps: steps,
        heightCm: state.heightCm,
      ),
      walkingDuration: state.activityMetrics.walkingDuration,
      kcal: state.activityMetrics.kcal,
    );
  }

  ActivityMetricsSnapshot _toMetricsSnapshot(DerivedActivityResult result) {
    return ActivityMetricsSnapshot(
      distanceKm: result.distanceKm,
      walkingDuration: result.walkingDuration,
      kcal: result.kcal,
    );
  }

  Future<void> _applyTodaySnapshot({
    required int steps,
    required int goal,
    required bool isStale,
    DateTime? lastIngestionUtc,
    List<WeekDayStatus>? weekDays,
    ActivityMetricsSnapshot? activityMetrics,
    int? heightCm,
    double? weightKg,
    bool allowDecrease = false,
  }) async {
    if (isClosed) {
      return;
    }

    final todayIso = formatLocalDayIso(clock.snapshot());
    var effectiveSteps = steps;
    if (!allowDecrease &&
        _lastAppliedLocalDay == todayIso &&
        state.status != TodayStatus.loading &&
        state.status != TodayStatus.noPermission &&
        steps < state.steps) {
      effectiveSteps = state.steps;
    }
    _lastAppliedLocalDay = todayIso;

    final baseMetrics = activityMetrics ?? state.activityMetrics;
    final resolvedMetrics = ActivityMetricsSnapshot(
      distanceKm: DerivedActivityMetrics.computeDistanceKm(
        displaySteps: effectiveSteps,
        heightCm: heightCm ?? state.heightCm,
      ),
      walkingDuration: baseMetrics.walkingDuration,
      kcal: baseMetrics.kcal,
    );

    final baseState = TodayState.fromData(
      steps: effectiveSteps,
      goal: goal,
      isStale: isStale,
      lastIngestionUtc: lastIngestionUtc,
      weekDays: weekDays ?? state.weekDays,
      activityMetrics: resolvedMetrics,
      heightCm: heightCm ?? state.heightCm,
      weightKg: weightKg ?? state.weightKg,
      foregroundCatchUp: state.foregroundCatchUp,
      catchUpTargetSteps: state.catchUpTargetSteps,
    );
    await _maybeTriggerCelebration(
      steps: effectiveSteps,
      goal: goal,
      baseState: baseState,
    );
  }

  void dismissCelebration() {
    if (state.showCelebration) {
      emit(state.copyWith(showCelebration: false));
    }
  }

  Future<void> _maybeTriggerCelebration({
    required int steps,
    required int goal,
    required TodayState baseState,
  }) async {
    if (isClosed) {
      return;
    }
    if (goal <= 0 || steps < goal) {
      emit(baseState.copyWith(showCelebration: false));
      return;
    }

    final todayIso = formatLocalDayIso(clock.snapshot());
    if (isClosed) {
      return;
    }
    if (!await userPreferences.tryClaimCelebrationShownDate(todayIso)) {
      // Keep an in-flight celebration alive across silent refresh / ingestion.
      emit(baseState.copyWith(showCelebration: state.showCelebration));
      return;
    }
    if (isClosed) {
      return;
    }
    emit(baseState.copyWith(showCelebration: true));
  }

  @override
  Future<void> close() {
    unawaited(_liveStepsSubscription?.cancel());
    _liveStepsSubscription = null;
    _attachedMonitor = null;
    return super.close();
  }
}
