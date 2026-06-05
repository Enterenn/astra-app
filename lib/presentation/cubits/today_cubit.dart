import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/health/stale_data_evaluator.dart';
import '../../core/permissions/activity_permission_resolver.dart'
    show isActivityRecognitionGranted;
import '../../core/services/live_step_monitor.dart';
import '../../core/time/calendar_week.dart';
import '../../core/time/local_day_calculator.dart';
import '../../core/time/local_day_formatter.dart';
import '../../core/time/time_provider.dart';
import '../../core/time/timestamp_codec.dart';
import '../../core/validation/step_goal_validator.dart';
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
  String? _lastAppliedLocalDay;

  /// Subscribes to [monitor] live step stream (replays current value immediately).
  void attachLiveMonitor(LiveStepMonitor monitor) {
    _liveStepsSubscription?.cancel();
    _liveStepsSubscription = monitor.watchTodaySteps().listen((steps) {
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
  Future<void> syncSteps(int steps) async {
    if (isClosed) {
      return;
    }
    if (state.status == TodayStatus.noPermission) {
      return;
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
      displayName: state.displayName,
      isStale: state.isStale,
      lastIngestionUtc: state.lastIngestionUtc,
    );
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
      emit(TodayState(status: TodayStatus.noPermission, weekDays: weekDays));
      return;
    }

    final results = await Future.wait<Object?>([
      userPreferences.getDailyStepGoal(),
      userPreferences.getDisplayName(),
      stepRepository.getLastIngestionUtc(),
    ]);
    if (isClosed) {
      return;
    }

    final goal = results[0]! as int;
    final displayName = results[1] as String?;
    final lastUtc = results[2] as DateTime?;
    final stale = isStaleData(
      lastIngestionUtc: lastUtc,
      nowUtc: clock.nowUtc(),
      isIos: _isIos,
    );

    final weekDays = await _loadWeekDays(goal: goal);
    if (isClosed) {
      return;
    }

    await _applyTodaySnapshot(
      steps: state.steps,
      goal: goal,
      displayName: displayName,
      isStale: stale,
      lastIngestionUtc: lastUtc,
      weekDays: weekDays,
    );
  }

  Future<void> _refreshImpl({required bool silent}) async {
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
      emit(TodayState(status: TodayStatus.noPermission, weekDays: weekDays));
      return;
    }

    final results = await Future.wait<Object?>([
      stepRepository.getTodaySteps(),
      userPreferences.getDailyStepGoal(),
      userPreferences.getDisplayName(),
      stepRepository.getLastIngestionUtc(),
    ]);
    if (isClosed) {
      return;
    }

    final steps = results[0]! as int;
    final goal = results[1]! as int;
    final displayName = results[2] as String?;
    final lastUtc = results[3] as DateTime?;

    final stale = isStaleData(
      lastIngestionUtc: lastUtc,
      nowUtc: clock.nowUtc(),
      isIos: _isIos,
    );

    final weekDays = await _loadWeekDays(goal: goal);
    if (isClosed) {
      return;
    }

    await _applyTodaySnapshot(
      steps: steps,
      goal: goal,
      displayName: displayName,
      isStale: stale,
      lastIngestionUtc: lastUtc,
      weekDays: weekDays,
    );
  }

  Future<void> _applyLiveSteps(int steps) async {
    if (isClosed) {
      return;
    }

    if (state.status == TodayStatus.noPermission) {
      return;
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
      displayName: state.displayName,
      isStale: state.isStale,
      lastIngestionUtc: state.lastIngestionUtc,
      weekDays: state.weekDays,
    );
  }

  Future<List<WeekDayStatus>> _loadWeekDays({required int goal}) async {
    final timeSnapshot = clock.snapshot();
    final zoneOffset = TimestampCodec.formatZoneOffset(timeSnapshot.zoneOffset);
    final referenceToday = LocalDayCalculator.localDay(
      utc: timeSnapshot.nowUtc,
      zoneOffset: zoneOffset,
    );
    final weekDayKeys = CalendarWeek.daysContaining(referenceToday);

    final aggregates = await stepRepository.getChartDailyAggregates(days: 30);
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

  /// Applies step count with monotonic same-day merge: display never drops within
  /// the local day except on rollover (Today Display Truth Model — see
  /// `_bmad-output/planning-artifacts/architecture.md`).
  Future<void> _applyTodaySnapshot({
    required int steps,
    required int goal,
    String? displayName,
    required bool isStale,
    DateTime? lastIngestionUtc,
    List<WeekDayStatus>? weekDays,
  }) async {
    if (isClosed) {
      return;
    }

    final todayIso = formatLocalDayIso(clock.snapshot());
    var effectiveSteps = steps;
    if (_lastAppliedLocalDay == todayIso &&
        state.status != TodayStatus.loading &&
        state.status != TodayStatus.noPermission &&
        steps < state.steps) {
      effectiveSteps = state.steps;
    }
    _lastAppliedLocalDay = todayIso;

    final baseState = TodayState.fromData(
      steps: effectiveSteps,
      goal: goal,
      displayName: displayName,
      isStale: isStale,
      lastIngestionUtc: lastIngestionUtc,
      weekDays: weekDays ?? state.weekDays,
    );
    await _maybeTriggerCelebration(
      steps: effectiveSteps,
      goal: goal,
      baseState: baseState,
    );
  }

  void dismissCelebration() {
    if (state.showCelebration || state.isGoalPreviewActive) {
      emit(
        state.copyWith(
          showCelebration: false,
          goalPreviewNonce: 0,
        ),
      );
    }
  }

  /// Debug-only: count-up from last displayed steps → goal, then celebration.
  /// Does not claim [celebration_shown_date] or mutate persisted step truth.
  void previewCelebration() {
    if (isClosed || state.goal <= 0) {
      return;
    }
    emit(
      state.copyWith(
        showCelebration: false,
        goalPreviewNonce: state.goalPreviewNonce + 1,
      ),
    );
  }

  /// Called when the debug preview count-up reaches the daily goal.
  void completeGoalPreviewCountUp() {
    if (isClosed || !state.isGoalPreviewActive) {
      return;
    }
    emit(
      state.copyWith(
        showCelebration: true,
        celebrationPreviewNonce: state.celebrationPreviewNonce + 1,
      ),
    );
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
      emit(
        baseState.copyWith(
          showCelebration: state.isGoalPreviewActive
              ? state.showCelebration
              : false,
        ),
      );
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
    return super.close();
  }
}
