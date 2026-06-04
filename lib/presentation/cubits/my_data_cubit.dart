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
import '../../core/validation/step_goal_validator.dart';
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
import '../widgets/confirm_dialog.dart';
import 'my_data_state.dart';

typedef ActivityPermissionChecker = Future<bool> Function();
typedef TempDirectoryProvider = Future<String> Function();
typedef ShareCsvFileCallback =
    Future<void> Function(String filePath, {Rect? sharePositionOrigin});
/// Returns true when the user saved to a chosen on-device location.
typedef SaveCsvFileCallback = Future<bool> Function(String filePath);
typedef PickCsvFileCallback = Future<String?> Function();
typedef ConfirmImportCallback =
    Future<bool> Function(int csvRowCount, int existingSampleCount);
typedef PostImportRefreshCallback = Future<void> Function();
typedef ConfirmPurgeCallback = Future<PurgeConfirmAction> Function();
typedef PostPurgeRefreshCallback = Future<void> Function();
typedef PostGoalUpdateCallback = Future<void> Function();
typedef PostDisplayNameUpdateCallback = Future<void> Function();

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
    SaveCsvFileCallback? saveCsvFile,
    PickCsvFileCallback? pickCsvFile,
    this._confirmImport,
    this._postImportRefresh,
    this._postPurgeRefresh,
    this._postGoalUpdate,
    this._postDisplayNameUpdate,
    bool? isIos,
  }) : _activityPermissionGranted =
           activityPermissionGranted ?? isActivityRecognitionGranted,
       _tempDirectoryProvider =
           tempDirectoryProvider ?? _defaultTempDirectoryProvider,
       _shareCsvFile = shareCsvFile ?? _defaultShareCsvFile,
       _saveCsvFile = saveCsvFile ?? _defaultSaveCsvFile,
       _pickCsvFile = pickCsvFile ?? _defaultPickCsvFile,
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
  final SaveCsvFileCallback _saveCsvFile;
  final PickCsvFileCallback _pickCsvFile;
  final ConfirmImportCallback? _confirmImport;
  final PostImportRefreshCallback? _postImportRefresh;
  final PostPurgeRefreshCallback? _postPurgeRefresh;
  final PostGoalUpdateCallback? _postGoalUpdate;
  final PostDisplayNameUpdateCallback? _postDisplayNameUpdate;
  final bool _isIos;

  Future<void>? _refreshInFlight;
  Future<void>? _exportInFlight;
  Future<void>? _importInFlight;
  Future<void>? _purgeInFlight;

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

  static Future<bool> _defaultSaveCsvFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final savedPath = await FilePicker.saveFile(
      dialogTitle: 'Save CSV export',
      fileName: p.basename(filePath),
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    return savedPath != null;
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
    if (isClosed || state.isImporting || state.isExporting || state.isPurging) {
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
      try {
        await _postImportRefresh?.call();
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('MyDataCubit.postImportRefresh failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
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
    if (isClosed ||
        state.isExporting ||
        state.isImporting ||
        state.isPurging) {
      return;
    }
    if (_exportInFlight != null) {
      return _exportInFlight!;
    }

    _exportInFlight = _exportAndShareImpl(
      sharePositionOrigin: sharePositionOrigin,
    );
    try {
      await _exportInFlight!;
    } finally {
      _exportInFlight = null;
    }
  }

  Future<void> _exportAndShareImpl({Rect? sharePositionOrigin}) async {
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
      final savedOnDevice = await _saveCsvFile(filePath);
      if (!savedOnDevice && !isClosed) {
        await _shareCsvFile(
          filePath,
          sharePositionOrigin: sharePositionOrigin,
        );
      }

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

  /// Clears [MyDataState.importSuccessPending] after the UI shows the snackbar.
  void ackImportSuccess() {
    if (isClosed || !state.importSuccessPending) {
      return;
    }
    emit(state.copyWith(importSuccessPending: false));
  }

  /// Clears [MyDataState.purgeSuccessPending] after the UI shows the snackbar.
  void ackPurgeSuccess() {
    if (isClosed || !state.purgeSuccessPending) {
      return;
    }
    emit(state.copyWith(purgeSuccessPending: false));
  }

  Future<void> confirmAndPurge({
    ConfirmPurgeCallback? confirmPurge,
    PurgeConfirmAction? confirmedAction,
  }) async {
    final deleteAlreadyConfirmed =
        confirmedAction == PurgeConfirmAction.deleteConfirmed;

    if (isClosed || state.isPurging || state.isImporting) {
      return;
    }
    if (state.isExporting && !deleteAlreadyConfirmed) {
      return;
    }
    if (_purgeInFlight != null) {
      return _purgeInFlight!;
    }

    _purgeInFlight = _confirmAndPurgeImpl(
      confirmPurge: confirmPurge,
      confirmedAction: confirmedAction,
    );
    try {
      await _purgeInFlight!;
    } finally {
      _purgeInFlight = null;
    }
  }

  Future<void> _confirmAndPurgeImpl({
    ConfirmPurgeCallback? confirmPurge,
    PurgeConfirmAction? confirmedAction,
  }) async {
    final action = confirmedAction ??
        (confirmPurge != null
            ? await confirmPurge()
            : PurgeConfirmAction.cancelled);

    if (action == PurgeConfirmAction.cancelled || isClosed) {
      return;
    }
    if (action == PurgeConfirmAction.exportFirst) {
      await exportAndShare();
      return;
    }

    emit(
      state.copyWith(
        isPurging: true,
        purgeErrorMessage: null,
        purgeSuccessPending: false,
      ),
    );

    var purged = false;
    try {
      await stepRepository.purge();
      purged = true;
      if (isClosed) {
        return;
      }

      await _postPurgeRefresh?.call();
      if (!isClosed) {
        await refresh(silent: true);
      }
      if (isClosed) {
        return;
      }

      emit(
        state.copyWith(
          isPurging: false,
          purgeErrorMessage: null,
          purgeSuccessPending: true,
        ),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('MyDataCubit.confirmAndPurge failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(
          isPurging: false,
          purgeErrorMessage: purged
              ? 'All local data was removed, but the app could not refresh. Try again.'
              : 'Purge could not be completed. Try again.',
        ),
      );
    }
  }

  /// Persists a new daily step goal and refreshes dependent tabs.
  ///
  /// Returns `false` when blocked, invalid, unchanged, persist fails, or
  /// [postGoalUpdate] fails (goal may still be saved in that last case).
  Future<bool> updateDailyStepGoal(int goal) async {
    if (isClosed ||
        state.isExporting ||
        state.isImporting ||
        state.isPurging) {
      return false;
    }

    final validation = validateStepGoalInput(goal.toString());
    if (!validation.isValid || validation.parsedGoal == null) {
      return false;
    }
    final parsed = validation.parsedGoal!;
    if (parsed == state.dailyStepGoal) {
      return false;
    }

    try {
      await userPreferences.setDailyStepGoal(parsed);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('MyDataCubit.updateDailyStepGoal persist failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }

    if (isClosed) {
      return false;
    }

    if (state.status == MyDataStatus.ready) {
      emit(state.copyWith(dailyStepGoal: parsed));
    }

    try {
      await _postGoalUpdate?.call();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('MyDataCubit.updateDailyStepGoal refresh failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }

    return true;
  }

  /// Persists display name and refreshes Today greeting metadata.
  ///
  /// [name] is trimmed; empty clears the stored name.
  Future<bool> updateDisplayName(String name) async {
    if (isClosed ||
        state.isExporting ||
        state.isImporting ||
        state.isPurging) {
      return false;
    }

    final trimmed = name.trim();
    final current = state.displayName?.trim();
    if (trimmed == (current ?? '')) {
      return false;
    }

    try {
      await userPreferences.setDisplayName(trimmed.isEmpty ? null : trimmed);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('MyDataCubit.updateDisplayName persist failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }

    if (isClosed) {
      return false;
    }

    if (state.status == MyDataStatus.ready) {
      emit(
        state.copyWith(
          displayName: trimmed.isEmpty ? null : trimmed,
        ),
      );
    }

    try {
      await _postDisplayNameUpdate?.call();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('MyDataCubit.updateDisplayName refresh failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }

    return true;
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
        !state.isImporting &&
        !state.isPurging) {
      emit(const MyDataState.loading());
    }

    try {
      final results = await Future.wait<Object?>([
        stepRepository.getFootprint(databasePath: databasePath),
        stepRepository.getLastIngestionUtc(),
        _activityPermissionGranted(),
      ]);

      if (isClosed) {
        return;
      }

      final footprint = results[0]! as DatabaseFootprint;
      final lastIngestionUtc = results[1] as DateTime?;
      final activityGranted = results[2]! as bool;
      final nowUtc = clock.nowUtc();

      if (isClosed) {
        return;
      }

      _emitReadySnapshot(
        sampleCount: footprint.sampleCount,
        fileSizeBytes: footprint.fileSizeBytes,
        lastIngestionUtc: lastIngestionUtc,
        backgroundStatus: _deriveBackgroundStatus(
          activityGranted: activityGranted,
          lastIngestionUtc: lastIngestionUtc,
          nowUtc: nowUtc,
        ),
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
    int? dailyStepGoal,
    String? displayName,
  }) {
    emit(
      MyDataState.ready(
        sampleCount: sampleCount,
        fileSizeBytes: fileSizeBytes,
        lastOptimizedUtc: lastOptimizedUtc ?? state.lastOptimizedUtc,
        lastIngestionUtc: lastIngestionUtc,
        backgroundStatus: backgroundStatus,
        capabilitySnapshot: capabilitySnapshot ?? state.capabilitySnapshot,
        isIos: _isIos,
        dailyStepGoal: dailyStepGoal ?? state.dailyStepGoal,
        displayName: displayName ?? state.displayName,
      ).copyWith(
        isExporting: state.isExporting,
        exportErrorMessage: state.exportErrorMessage,
        isImporting: state.isImporting,
        importErrorMessage: state.importErrorMessage,
        importSuccessPending: state.importSuccessPending,
        isPurging: state.isPurging,
        purgeErrorMessage: state.purgeErrorMessage,
        purgeSuccessPending: state.purgeSuccessPending,
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
