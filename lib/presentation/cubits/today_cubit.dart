import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/health/stale_data_evaluator.dart';
import '../../core/permissions/activity_permission_resolver.dart';
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

  static Future<bool> _defaultActivityPermissionGranted() async {
    final permission = resolveActivityPermission();
    final status = await permission.status;
    return status.isGranted || status.isLimited || status.isProvisional;
  }

  Future<void> refresh() async {
    emit(const TodayState.loading());

    final granted = await _activityPermissionGranted();
    if (!granted) {
      emit(const TodayState.noPermission());
      return;
    }

    final results = await Future.wait<Object?>([
      stepRepository.getTodaySteps(),
      userPreferences.getDailyStepGoal(),
      stepRepository.getLastIngestionUtc(),
    ]);

    final steps = results[0]! as int;
    final goal = results[1]! as int;
    final lastUtc = results[2] as DateTime?;

    final stale = isStaleData(
      lastIngestionUtc: lastUtc,
      nowUtc: clock.nowUtc(),
      isIos: _isIos,
    );

    emit(
      TodayState.fromData(
        steps: steps,
        goal: goal,
        isStale: stale,
        lastIngestionUtc: lastUtc,
      ),
    );
  }
}
