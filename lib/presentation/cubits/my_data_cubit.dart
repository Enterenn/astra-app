import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
typedef TempDirectoryProvider = Future<String> Function();
typedef ShareCsvFileCallback =
    Future<void> Function(String filePath, {Rect? sharePositionOrigin});

class MyDataCubit extends Cubit<MyDataState> {
  MyDataCubit({
    required this.stepRepository,
    required this.userPreferences,
    required this.capabilityEvaluator,
    required this.clock,
    required this.databasePath,
    ActivityPermissionChecker? activityPermissionGranted,
    TempDirectoryProvider? tempDirectoryProvider,
    ShareCsvFileCallback? shareCsvFile,
    bool? isIos,
  }) : _activityPermissionGranted =
           activityPermissionGranted ?? isActivityRecognitionGranted,
       _tempDirectoryProvider =
           tempDirectoryProvider ?? _defaultTempDirectoryProvider,
       _shareCsvFile = shareCsvFile ?? _defaultShareCsvFile,
       _isIos = isIos ?? Platform.isIOS,
       super(const MyDataState.loading());

  final StepRepository stepRepository;
  final UserPreferencesRepository userPreferences;
  final BackgroundHealthCapabilityEvaluator capabilityEvaluator;
  final TimeProvider clock;
  final String databasePath;
  final ActivityPermissionChecker _activityPermissionGranted;
  final TempDirectoryProvider _tempDirectoryProvider;
  final ShareCsvFileCallback _shareCsvFile;
  final bool _isIos;

  Future<void>? _refreshInFlight;

  static Future<String> _defaultTempDirectoryProvider() async {
    final directory = await getTemporaryDirectory();
    return directory.path;
  }

  static Future<void> _defaultShareCsvFile(
    String filePath, {
    Rect? sharePositionOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        fileNameOverrides: [p.basename(filePath)],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<void> exportAndShare({Rect? sharePositionOrigin}) async {
    if (isClosed || state.isExporting) {
      return;
    }

    emit(
      state.copyWith(
        isExporting: true,
        exportErrorMessage: null,
      ),
    );

    try {
      final tempDirectory = await _tempDirectoryProvider();
      final filePath = await stepRepository.exportCsv(
        outputDirectory: tempDirectory,
      );
      await _shareCsvFile(
        filePath,
        sharePositionOrigin: sharePositionOrigin,
      );

      if (isClosed) {
        return;
      }

      emit(state.copyWith(isExporting: false, exportErrorMessage: null));
      unawaited(refresh(silent: true));
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('MyDataCubit.exportAndShare failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (isClosed) {
        return;
      }

      emit(
        state.copyWith(
          isExporting: false,
          exportErrorMessage: 'Export could not be completed. Try again.',
        ),
      );
    }
  }

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
    if (!silent &&
        state.status != MyDataStatus.loading &&
        !state.isExporting) {
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

      _emitReadySnapshot(
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
      );
    } catch (_) {
      if (isClosed) {
        return;
      }
      _recoverFromRefreshFailure();
    }
  }

  void _recoverFromRefreshFailure() {
    if (state.status == MyDataStatus.ready) {
      // Re-emit so listeners see a stable ready snapshot after a failed refresh.
      emit(state);
      return;
    }

    _emitReadySnapshot(
      sampleCount: 0,
      fileSizeBytes: 0,
      backgroundStatus: _isIos
          ? BackgroundCollectionStatus.iosBackfill
          : BackgroundCollectionStatus.healthy,
    );
  }

  void _emitReadySnapshot({
    required int sampleCount,
    required int fileSizeBytes,
    DateTime? lastOptimizedUtc,
    DateTime? lastIngestionUtc,
    required BackgroundCollectionStatus backgroundStatus,
    BackgroundHealthCapabilitySnapshot? capabilitySnapshot,
  }) {
    emit(
      MyDataState.ready(
        sampleCount: sampleCount,
        fileSizeBytes: fileSizeBytes,
        lastOptimizedUtc: lastOptimizedUtc,
        lastIngestionUtc: lastIngestionUtc,
        backgroundStatus: backgroundStatus,
        capabilitySnapshot: capabilitySnapshot,
        isIos: _isIos,
      ).copyWith(
        isExporting: state.isExporting,
        exportErrorMessage: state.exportErrorMessage,
      ),
    );
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
