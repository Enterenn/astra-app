import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/health/stale_data_evaluator.dart';
import '../../core/permissions/activity_permission_resolver.dart';
import '../../core/time/local_day_formatter.dart';
import '../../core/time/time_provider.dart';
import '../../data/repositories/step_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import 'today_state.dart';

typedef ActivityPermissionChecker = Future<bool> Function();

class TodayCubit extends Cubit<TodayState> {
  TodayCubit({
    required this.stepRepository,
    required this.userPreferences,
    required this.clock,
    ActivityPermissionChecker? activityPermissionGranted,
    bool? isIos,
  }) : _activityPermissionGranted =
           activityPermissionGranted ?? _defaultActivityPermissionGranted,
       _isIos = isIos ?? Platform.isIOS,
       super(const TodayState.loading());

  final StepRepository stepRepository;
  final UserPreferencesRepository userPreferences;
  final TimeProvider clock;
  final ActivityPermissionChecker _activityPermissionGranted;
  final bool _isIos;

  Future<void>? _refreshInFlight;

  static Future<bool> _defaultActivityPermissionGranted() async {
    final permission = resolveActivityPermission();
    final status = await permission.status;
    return status.isGranted || status.isLimited || status.isProvisional;
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

  Future<void> _refreshImpl({required bool silent}) async {
    if (!silent && state.status != TodayStatus.loading) {
      emit(const TodayState.loading());
    }

    final granted = await _activityPermissionGranted();
    if (isClosed) {
      return;
    }
    if (!granted) {
      emit(const TodayState.noPermission());
      return;
    }

    final results = await Future.wait<Object?>([
      stepRepository.getTodaySteps(),
      userPreferences.getDailyStepGoal(),
      stepRepository.getLastIngestionUtc(),
    ]);
    if (isClosed) {
      return;
    }

    final steps = results[0]! as int;
    final goal = results[1]! as int;
    final lastUtc = results[2] as DateTime?;

    final stale = isStaleData(
      lastIngestionUtc: lastUtc,
      nowUtc: clock.nowUtc(),
      isIos: _isIos,
    );

    final baseState = TodayState.fromData(
      steps: steps,
      goal: goal,
      isStale: stale,
      lastIngestionUtc: lastUtc,
    );
    await _maybeTriggerCelebration(
      steps: steps,
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
    final shownDate = await userPreferences.getCelebrationShownDate();
    if (isClosed) {
      return;
    }
    if (shownDate == todayIso) {
      // Keep an in-flight celebration alive across silent refresh / ingestion.
      emit(baseState.copyWith(showCelebration: state.showCelebration));
      return;
    }

    await userPreferences.setCelebrationShownDate(todayIso);
    if (isClosed) {
      return;
    }
    emit(baseState.copyWith(showCelebration: true));
  }
}
