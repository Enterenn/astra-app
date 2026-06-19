import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite/sqflite.dart';
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
import '../../data/models/chart_day_aggregate.dart';
import '../../data/models/timeseries_sample_model.dart';
import '../../data/contracts/contracts.dart';
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

  final StepRepositoryContract stepRepository;
  final UserPreferencesRepositoryContract userPreferences;
  final TimeProvider clock;
  final ActivityPermissionChecker _activityPermissionGranted;
  final bool _isIos;
  final PostGoalUpdateCallback? postGoalUpdate;

  Future<void>? _refreshInFlight;
  StreamSubscription<int>? _liveStepsSubscription;
  LiveStepMonitor? _attachedMonitor;
  String? _lastAppliedLocalDay;
  bool _pauseLiveStepApplies = false;
  bool _hasUserSelectedLocalDay = false;
  int? _todaySteps;
  int? _todayGoal;
  ActivityMetricsSnapshot? _todayMetrics;

  /// Today's editable goal for Set goal — independent of display [TodayState.goal]
  /// when viewing a past day.
  Future<int> get todayEditableGoal async {
    if (_todayGoal != null) {
      return _todayGoal!;
    }
    return _resolveTodayGoal();
  }

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
        state.status != TodayStatus.noPermission &&
        _isViewingToday()) {
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
          if (!_isViewingToday()) {
            unawaited(_applyLiveSteps(steps));
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
    final currentTodayGoal = await todayEditableGoal;
    if (isClosed) {
      return false;
    }
    if (parsed == currentTodayGoal) {
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
    if (!state.lastDisplayedStepsLoaded) {
      // Cold bind / day switch: keep UI in loading until display prefs resolve.
      var goal = _todayGoal;
      if (goal == null) {
        goal = await _resolveTodayGoal();
        if (isClosed) {
          return;
        }
      }
      _todaySteps = steps;
      _todayGoal = goal;
      return;
    }

    if (foregroundCatchUp) {
      if (!_isViewingToday()) {
        return;
      }
      if (steps <= (_todaySteps ?? state.steps)) {
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

    var goal = _todayGoal;
    if (goal == null) {
      goal = await _resolveTodayGoal();
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

  /// Persists the settled GoalRing display count for the current display day.
  Future<void> recordLastDisplayedSteps(int steps) async {
    if (isClosed || steps < 0) {
      return;
    }
    if (state.lastDisplayedSteps == steps) {
      return;
    }
    if (!userPreferences.isDatabaseOpen) {
      return;
    }
    emit(
      state.copyWith(
        lastDisplayedSteps: steps,
        lastDisplayedStepsLoaded: true,
      ),
    );
    final localDayIso = _displayLocalDayIso();
    unawaited(_persistLastDisplayedSteps(localDayIso: localDayIso, steps: steps));
  }

  Future<void> _persistLastDisplayedSteps({
    required String localDayIso,
    required int steps,
  }) async {
    try {
      await userPreferences.setLastDisplayedSteps(
        localDayIso: localDayIso,
        steps: steps,
      );
    } on DatabaseException {
      return;
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

    if (!granted) {
      final weekDays = await _loadWeekDays();
      if (isClosed) {
        return;
      }
      emit(
        TodayState(
          status: TodayStatus.noPermission,
          weekDays: weekDays,
          activityMetrics: ActivityMetricsSnapshot.zero,
          selectedLocalDay: _resolveSelectedLocalDay(weekDays),
        ),
      );
      return;
    }

    final todaySteps = _todaySteps ?? state.steps;

    final results = await Future.wait<Object?>([
      _resolveTodayGoal(),
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

    final weekDays = await _loadWeekDays();
    if (isClosed) {
      return;
    }

    final metrics = _toMetricsSnapshot(
      DerivedActivityMetrics.compute(
        displaySteps: todaySteps,
        activeBuckets: buckets,
        heightCm: heightCm,
        weightKg: weightKg,
      ),
    );

    await _applyTodaySnapshot(
      steps: todaySteps,
      goal: goal,
      isStale: stale,
      lastIngestionUtc: lastUtc,
      weekDays: weekDays,
      activityMetrics: metrics,
      heightCm: heightCm,
      weightKg: weightKg,
      selectedLocalDay: _resolveSelectedLocalDay(weekDays),
    );

    if (_isViewingToday()) {
      return;
    }

    emit(
      state.copyWith(
        weekDays: weekDays,
        isStale: stale,
        lastIngestionUtc: lastUtc,
        heightCm: heightCm,
        weightKg: weightKg,
        selectedLocalDay: _resolveSelectedLocalDay(weekDays),
      ),
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
      final weekDays = await _loadWeekDays();
      if (isClosed) {
        return;
      }
      emit(
        TodayState(
          status: TodayStatus.noPermission,
          weekDays: weekDays,
          activityMetrics: ActivityMetricsSnapshot.zero,
          selectedLocalDay: _resolveSelectedLocalDay(weekDays),
        ),
      );
      return;
    }

    final todayIso = formatLocalDayIso(clock.snapshot());
    final results = await Future.wait<Object?>([
      stepRepository.getTodaySteps(),
      _resolveTodayGoal(),
      stepRepository.getLastIngestionUtc(),
      stepRepository.getTodayActiveBuckets(),
      userPreferences.getHeightCm(),
      userPreferences.getWeightKg(),
      userPreferences.getLastDisplayedSteps(todayIso),
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
    final lastDisplayedSteps = results[6] as int?;

    final stale = isStaleData(
      lastIngestionUtc: lastUtc,
      nowUtc: clock.nowUtc(),
      isIos: _isIos,
    );

    final weekDays = await _loadWeekDays();
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
      selectedLocalDay: _resolveSelectedLocalDay(weekDays),
      lastDisplayedSteps: lastDisplayedSteps,
      lastDisplayedStepsLoaded: true,
    );

    if (_isViewingToday()) {
      return;
    }

    emit(
      state.copyWith(
        weekDays: weekDays,
        isStale: stale,
        lastIngestionUtc: lastUtc,
        heightCm: heightCm,
        weightKg: weightKg,
        selectedLocalDay: _resolveSelectedLocalDay(weekDays),
      ),
    );
  }

  void selectLocalDay(DateTime day) {
    if (isClosed) {
      return;
    }
    final utcDay = day.toUtc();
    final normalizedDay = DateTime.utc(utcDay.year, utcDay.month, utcDay.day);
    WeekDayStatus? match;
    for (final weekDay in state.weekDays) {
      if (_isSameLocalDay(weekDay.localDay, normalizedDay)) {
        match = weekDay;
        break;
      }
    }
    if (match == null || match.isFuture) {
      return;
    }
    if (state.selectedLocalDay != null &&
        _isSameLocalDay(state.selectedLocalDay!, normalizedDay)) {
      return;
    }
    _hasUserSelectedLocalDay = true;
    emit(
      state.copyWith(
        status: TodayStatus.loading,
        selectedLocalDay: normalizedDay,
        lastDisplayedSteps: null,
        lastDisplayedStepsLoaded: false,
      ),
    );
    unawaited(_applySelectedDayDisplay());
  }

  bool _isViewingToday() {
    final selected = state.selectedLocalDay;
    if (selected == null) {
      return true;
    }
    final today = state.weekDays.cast<WeekDayStatus?>().firstWhere(
      (day) => day!.isToday,
      orElse: () => null,
    );
    if (today == null) {
      return true;
    }
    return _isSameLocalDay(today.localDay, selected);
  }

  Future<({int steps, int goal, ActivityMetricsSnapshot metrics})>
  _loadSnapshotForLocalDay(DateTime day) async {
    final utcDay = day.toUtc();
    final normalizedDay = DateTime.utc(utcDay.year, utcDay.month, utcDay.day);
    final aggregates = await stepRepository.getChartDailyAggregates(days: 7);
    final steps = aggregates
        .firstWhere(
          (aggregate) => _isSameLocalDay(aggregate.localDay, normalizedDay),
          orElse: () => ChartDayAggregate(
            localDay: normalizedDay,
            totalSteps: 0,
          ),
        )
        .totalSteps;
    final goal = await userPreferences.getGoalForLocalDay(
      localDayIsoFromDateOnly(normalizedDay),
    );
    final buckets = await stepRepository.getActiveBucketsForLocalDay(
      normalizedDay,
    );
    // Avoid extra async reads here: when height/weight are null, the metrics
    // engine falls back to defaults.
    final heightCm = state.heightCm;
    final weightKg = state.weightKg;
    final metrics = _toMetricsSnapshot(
      DerivedActivityMetrics.compute(
        displaySteps: steps,
        activeBuckets: buckets,
        heightCm: heightCm,
        weightKg: weightKg,
      ),
    );
    return (steps: steps, goal: goal, metrics: metrics);
  }

  Future<void> _applySelectedDayDisplay() async {
    if (isClosed) {
      return;
    }
    final intendedSelectedLocalDay = state.selectedLocalDay;
    if (_isViewingToday()) {
      final goal = _todayGoal ?? await _resolveTodayGoal();
      if (isClosed) {
        return;
      }
      final lastDisplayedSteps = await _loadLastDisplayedStepsForDisplayDay();
      if (isClosed) {
        return;
      }
      await _applyTodaySnapshot(
        steps: _todaySteps ?? state.steps,
        goal: goal,
        isStale: state.isStale,
        lastIngestionUtc: state.lastIngestionUtc,
        weekDays: state.weekDays,
        activityMetrics:
            _todayMetrics ??
            _liveMetricsForSteps(_todaySteps ?? state.steps),
        heightCm: state.heightCm,
        weightKg: state.weightKg,
        lastDisplayedSteps: lastDisplayedSteps,
        lastDisplayedStepsLoaded: true,
      );
      return;
    }

    final day = intendedSelectedLocalDay;
    if (day == null) {
      return;
    }
    final snapshot = await _loadSnapshotForLocalDay(day);
    if (isClosed) {
      return;
    }
    if (state.selectedLocalDay == null ||
        !_isSameLocalDay(state.selectedLocalDay!, day)) {
      // Selection changed while the async snapshot was loading.
      return;
    }
    final dayIso = localDayIsoFromDateOnly(day);
    final lastDisplayedSteps =
        await userPreferences.getLastDisplayedSteps(dayIso);
    if (isClosed) {
      return;
    }
    if (state.selectedLocalDay == null ||
        !_isSameLocalDay(state.selectedLocalDay!, day)) {
      return;
    }
    final displayState = TodayState.fromData(
      steps: snapshot.steps,
      goal: snapshot.goal,
      isStale: state.isStale,
      lastIngestionUtc: state.lastIngestionUtc,
      weekDays: state.weekDays,
      activityMetrics: snapshot.metrics,
      heightCm: state.heightCm,
      weightKg: state.weightKg,
      showCelebration: false,
      foregroundCatchUp: false,
      catchUpTargetSteps: null,
      selectedLocalDay: day,
      lastDisplayedSteps: lastDisplayedSteps,
      lastDisplayedStepsLoaded: true,
    );
    emit(displayState);
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

    var goal = _todayGoal;
    if (goal == null) {
      goal = await _resolveTodayGoal();
      if (isClosed) {
        return;
      }
    }
    final previous = _todaySteps ?? state.steps;
    final weekDays = _isViewingToday()
        ? _patchTodayGoalMetForLiveSteps(
            state.weekDays,
            liveSteps: steps,
            todayGoal: goal,
          )
        : state.weekDays;

    await _applyTodaySnapshot(
      steps: steps,
      goal: goal,
      isStale: state.isStale,
      lastIngestionUtc: state.lastIngestionUtc,
      weekDays: weekDays,
      activityMetrics: _liveMetricsForSteps(steps),
      heightCm: state.heightCm,
      weightKg: state.weightKg,
    );
    if (_isViewingToday() && steps != previous) {
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

  Future<int> _resolveTodayGoal() async {
    final todayIso = formatLocalDayIso(clock.snapshot());
    return userPreferences.getGoalForLocalDay(todayIso);
  }

  List<WeekDayStatus> _patchTodayGoalMetForLiveSteps(
    List<WeekDayStatus> weekDays, {
    required int liveSteps,
    required int todayGoal,
  }) {
    if (weekDays.isEmpty) {
      return weekDays;
    }
    final todayIndex = weekDays.indexWhere((day) => day.isToday);
    if (todayIndex == -1) {
      return weekDays;
    }
    final nextGoalMet = todayGoal > 0 && liveSteps >= todayGoal;
    final today = weekDays[todayIndex];
    if (today.goalMet == nextGoalMet) {
      return weekDays;
    }
    final updated = WeekDayStatus(
      localDay: today.localDay,
      weekdayLabel: today.weekdayLabel,
      dayNumber: today.dayNumber,
      isToday: today.isToday,
      isFuture: today.isFuture,
      goalMet: nextGoalMet,
    );
    return [
      for (var i = 0; i < weekDays.length; i++)
        if (i == todayIndex) updated else weekDays[i],
    ];
  }

  Future<List<WeekDayStatus>> _loadWeekDays() async {
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

    final goals = await Future.wait<int>([
      for (final day in weekDayKeys)
        userPreferences.getGoalForLocalDay(localDayIsoFromDateOnly(day)),
    ]);

    return [
      for (var i = 0; i < weekDayKeys.length; i++)
        WeekDayStatus(
          localDay: weekDayKeys[i],
          weekdayLabel: CalendarWeek.weekdayLabelFor(weekDayKeys[i]),
          dayNumber: weekDayKeys[i].day,
          isToday: weekDayKeys[i] == referenceToday,
          isFuture: weekDayKeys[i].isAfter(referenceToday),
          goalMet:
              goals[i] > 0 && (stepsByDay[weekDayKeys[i]] ?? 0) >= goals[i],
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
    if (isClosed) {
      return;
    }
    emit(
      state.copyWith(
        lastDisplayedSteps: truthSteps,
        lastDisplayedStepsLoaded: true,
      ),
    );
  }

  String _displayLocalDayIso() {
    final selected = state.selectedLocalDay;
    if (selected != null && !_isViewingToday()) {
      return localDayIsoFromDateOnly(selected);
    }
    return formatLocalDayIso(clock.snapshot());
  }

  Future<int?> _loadLastDisplayedStepsForDisplayDay() {
    return userPreferences.getLastDisplayedSteps(_displayLocalDayIso());
  }

  ActivityMetricsSnapshot _liveMetricsForSteps(int steps) {
    final bucketMetrics = _todayMetrics ?? state.activityMetrics;
    return ActivityMetricsSnapshot(
      distanceKm: DerivedActivityMetrics.computeDistanceKm(
        displaySteps: steps,
        heightCm: state.heightCm,
      ),
      walkingDuration: bucketMetrics.walkingDuration,
      kcal: bucketMetrics.kcal,
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
    DateTime? selectedLocalDay,
    int? lastDisplayedSteps,
    bool? lastDisplayedStepsLoaded,
  }) async {
    if (isClosed) {
      return;
    }

    final todayIso = formatLocalDayIso(clock.snapshot());
    var effectiveSteps = steps;
    if (!allowDecrease &&
        state.status != TodayStatus.noPermission &&
        _todaySteps != null &&
        steps < _todaySteps! &&
        (state.status == TodayStatus.loading ||
            _lastAppliedLocalDay == todayIso)) {
      effectiveSteps = _todaySteps!;
    } else if (!allowDecrease &&
        _lastAppliedLocalDay == todayIso &&
        state.status != TodayStatus.loading &&
        state.status != TodayStatus.noPermission &&
        _isViewingToday() &&
        _todaySteps == null &&
        steps < state.steps) {
      effectiveSteps = state.steps;
    }
    _lastAppliedLocalDay = todayIso;
    _todaySteps = effectiveSteps;
    _todayGoal = goal;

    final baseMetrics = activityMetrics ?? _todayMetrics ?? state.activityMetrics;
    final resolvedMetrics = ActivityMetricsSnapshot(
      distanceKm: DerivedActivityMetrics.computeDistanceKm(
        displaySteps: effectiveSteps,
        heightCm: heightCm ?? state.heightCm,
      ),
      walkingDuration: baseMetrics.walkingDuration,
      kcal: baseMetrics.kcal,
    );
    _todayMetrics = resolvedMetrics;

    if (!_isViewingToday()) {
      return;
    }

    final resolvedLoaded =
        lastDisplayedStepsLoaded ?? state.lastDisplayedStepsLoaded;
    if (!resolvedLoaded) {
      return;
    }

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
      selectedLocalDay: selectedLocalDay ?? state.selectedLocalDay,
      lastDisplayedSteps: lastDisplayedSteps ?? state.lastDisplayedSteps,
      lastDisplayedStepsLoaded:
          lastDisplayedStepsLoaded ?? state.lastDisplayedStepsLoaded,
    );
    await _maybeTriggerCelebration(
      steps: effectiveSteps,
      goal: goal,
      baseState: baseState,
    );
  }

  DateTime _resolveSelectedLocalDay(List<WeekDayStatus> weekDays) {
    final today =
        weekDays.firstWhere((day) => day.isToday, orElse: () => weekDays.first);
    final normalizedToday =
        DateTime.utc(
          today.localDay.toUtc().year,
          today.localDay.toUtc().month,
          today.localDay.toUtc().day,
        );
    if (!_hasUserSelectedLocalDay || state.selectedLocalDay == null) {
      return normalizedToday;
    }
    final selected = state.selectedLocalDay!;
    final normalizedSelected =
        DateTime.utc(selected.toUtc().year, selected.toUtc().month,
            selected.toUtc().day);
    final isInCurrentWeek = weekDays.any(
      (day) => _isSameLocalDay(day.localDay, normalizedSelected),
    );
    if (!isInCurrentWeek) {
      _hasUserSelectedLocalDay = false;
      return normalizedToday;
    }
    return normalizedSelected;
  }

  bool _isSameLocalDay(DateTime a, DateTime b) {
    final au = a.toUtc();
    final bu = b.toUtc();
    return au.year == bu.year && au.month == bu.month && au.day == bu.day;
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
    if (!_isViewingToday()) {
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
      if (!_isViewingToday()) {
        return;
      }
      emit(baseState.copyWith(showCelebration: state.showCelebration));
      return;
    }
    if (isClosed) {
      return;
    }
    if (!_isViewingToday()) {
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
