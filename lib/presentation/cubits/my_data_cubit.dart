import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/health/background_health_capability_snapshot.dart';
import '../../core/health/stale_data_evaluator.dart';
import '../../core/permissions/activity_permission_resolver.dart'
    show isActivityRecognitionGranted;
import '../../core/services/background_health_capability_evaluator.dart';
import '../../core/time/time_provider.dart';
import '../../data/models/database_footprint.dart';
import '../../data/repositories/step_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import 'my_data_state.dart';

typedef ActivityPermissionChecker = Future<bool> Function();

class MyDataCubit extends Cubit<MyDataState> {
  MyDataCubit({
    required this.stepRepository,
    required this.userPreferences,
    required this.capabilityEvaluator,
    required this.clock,
    required this.databasePath,
    ActivityPermissionChecker? activityPermissionGranted,
    bool? isIos,
  }) : _activityPermissionGranted =
           activityPermissionGranted ?? isActivityRecognitionGranted,
       _isIos = isIos ?? Platform.isIOS,
       super(const MyDataState.loading());

  final StepRepository stepRepository;
  final UserPreferencesRepository userPreferences;
  final BackgroundHealthCapabilityEvaluator capabilityEvaluator;
  final TimeProvider clock;
  final String databasePath;
  final ActivityPermissionChecker _activityPermissionGranted;
  final bool _isIos;

  Future<void>? _refreshInFlight;

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
    if (!silent && state.status != MyDataStatus.loading) {
      emit(const MyDataState.loading());
    }

    try {
      final results = await Future.wait<Object?>([
        stepRepository.getFootprint(databasePath: databasePath),
        userPreferences.getLastDatabaseOptimizedAt(),
        stepRepository.getLastIngestionUtc(),
        capabilityEvaluator.evaluate(),
        _activityPermissionGranted(),
      ]);

      if (isClosed) {
        return;
      }

      final footprint = results[0]! as DatabaseFootprint;
      final lastOptimizedUtc = results[1] as DateTime?;
      final lastIngestionUtc = results[2] as DateTime?;
      final capabilitySnapshot =
          results[3]! as BackgroundHealthCapabilitySnapshot;
      final activityGranted = results[4]! as bool;
      final nowUtc = clock.nowUtc();

      emit(
        MyDataState.ready(
          sampleCount: footprint.sampleCount,
          fileSizeBytes: footprint.fileSizeBytes,
          lastOptimizedUtc: lastOptimizedUtc,
          lastIngestionUtc: lastIngestionUtc,
          backgroundStatus: _deriveBackgroundStatus(
            activityGranted: activityGranted,
            lastIngestionUtc: lastIngestionUtc,
            nowUtc: nowUtc,
          ),
          capabilitySnapshot: capabilitySnapshot,
          isIos: _isIos,
        ),
      );
    } catch (_) {
      if (isClosed || silent) {
        return;
      }
      emit(const MyDataState.loading());
    }
  }

  BackgroundCollectionStatus _deriveBackgroundStatus({
    required bool activityGranted,
    required DateTime? lastIngestionUtc,
    required DateTime nowUtc,
  }) {
    if (!activityGranted) {
      return BackgroundCollectionStatus.permissionDenied;
    }

    if (isStaleData(
      lastIngestionUtc: lastIngestionUtc,
      nowUtc: nowUtc,
      isIos: _isIos,
    )) {
      return BackgroundCollectionStatus.stale;
    }

    if (_isIos) {
      return BackgroundCollectionStatus.iosBackfill;
    }

    return BackgroundCollectionStatus.healthy;
  }
}
