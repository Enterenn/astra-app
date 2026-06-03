import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/health/background_health_capability_snapshot.dart';
import '../../data/csv/import_validation_exception.dart';
import '../../core/health/stale_data_evaluator.dart';
import '../../core/permissions/activity_permission_resolver.dart'
    show isActivityRecognitionGranted;
import '../../core/services/background_health_capability_evaluator.dart';
import '../../core/time/time_provider.dart';
import '../../data/csv/timeseries_csv_codec.dart';
import '../../data/models/database_footprint.dart';
import '../../data/repositories/step_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import 'my_data_state.dart';

typedef ActivityPermissionChecker = Future<bool> Function();
typedef TempDirectoryProvider = Future<String> Function();
typedef ShareCsvFileCallback =
    Future<void> Function(String filePath, {Rect? sharePositionOrigin});
typedef PickCsvFileCallback = Future<String?> Function();
typedef ConfirmImportCallback =
    Future<bool> Function(int csvRowCount, int existingSampleCount);
typedef PostImportRefreshCallback = Future<void> Function();

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
    PickCsvFileCallback? pickCsvFile,
    ConfirmImportCallback? confirmImport,
    PostImportRefreshCallback? postImportRefresh,
    bool? isIos,
  }) : _activityPermissionGranted =
           activityPermissionGranted ?? isActivityRecognitionGranted,
       _tempDirectoryProvider =
           tempDirectoryProvider ?? _defaultTempDirectoryProvider,
       _shareCsvFile = shareCsvFile ?? _defaultShareCsvFile,
       _pickCsvFile = pickCsvFile ?? _defaultPickCsvFile,
       _confirmImport = confirmImport,
       _postImportRefresh = postImportRefresh,
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
  final PickCsvFileCallback _pickCsvFile;
  final ConfirmImportCallback? _confirmImport;
  final PostImportRefreshCallback? _postImportRefresh;
  final bool _isIos;

  Future<void>? _refreshInFlight;
  Future<void>? _importInFlight;

  static Future<String> _defaultTempDirectoryProvider() async {
    final directory = await getTemporaryDirectory();
    return directory.path;
  }

  static Future<String?> _defaultPickCsvFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    return file?.path;
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

  Future<void> pickAndImport({
    ConfirmImportCallback? confirmImport,
  }) async {
    if (isClosed || state.isImporting || state.isExporting) {
      return;
    }
    if (_importInFlight != null) {
      return _importInFlight!;
    }

    _importInFlight = _pickAndImportImpl(confirmImport: confirmImport);
    try {
      await _importInFlight!;
    } finally {
      _importInFlight = null;
    }
  }

  Future<void> _pickAndImportImpl({
    ConfirmImportCallback? confirmImport,
  }) async {
    final path = await _pickCsvFile();
    if (path == null || isClosed) {
      return;
    }

    emit(
      state.copyWith(
        isImporting: true,
        importErrorMessage: null,
        importSuccessPending: false,
      ),
    );

    try {
      final samples = await TimeseriesCsvCodec.parseImportFile(path);
      if (isClosed) {
        return;
      }

      final existingSampleCount = await stepRepository.countStepSamples();
      if (isClosed) {
        return;
      }

      if (existingSampleCount > 0) {
        final confirm = confirmImport ?? _confirmImport;
        if (confirm == null) {
          emit(
            state.copyWith(
              isImporting: false,
              importErrorMessage:
                  'Import could not be completed. Try again.',
            ),
          );
          return;
        }
        final approved = await confirm(samples.length, existingSampleCount);
        if (!approved || isClosed) {
          emit(state.copyWith(isImporting: false));
          return;
        }
      }

      final result = await stepRepository.importSamples(samples);
      if (isClosed) {
        return;
      }

      emit(
        state.copyWith(
          isImporting: false,
          importErrorMessage: null,
          importSuccessPending: result.totalRowsInFile > 0,
        ),
      );
      await _postImportRefresh?.call();
      if (!isClosed) {
        await refresh(silent: true);
      }
    } on ImportValidationException catch (error) {
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(
          isImporting: false,
          importErrorMessage: error.message,
        ),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('MyDataCubit.pickAndImport failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(
          isImporting: false,
          importErrorMessage: 'Import could not be completed. Try again.',
        ),
      );
    }
  }

  Future<void> exportAndShare({Rect? sharePositionOrigin}) async {
    if (isClosed || state.isExporting || state.isImporting) {
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
        !state.isExporting &&
        !state.isImporting) {
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
      await _recoverFromRefreshFailure();
    }
  }

  Future<void> _recoverFromRefreshFailure() async {
    if (state.status == MyDataStatus.ready) {
      // Re-emit so listeners see a stable ready snapshot after a failed refresh.
      emit(state);
      return;
    }

    var sampleCount = 0;
    try {
      sampleCount = await stepRepository.countStepSamples();
    } catch (_) {
      sampleCount = 0;
    }

    if (isClosed) {
      return;
    }

    _emitReadySnapshot(
      sampleCount: sampleCount,
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
        isImporting: state.isImporting,
        importErrorMessage: state.importErrorMessage,
        importSuccessPending: state.importSuccessPending,
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
