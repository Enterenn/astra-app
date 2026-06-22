import '../../core/constants/preference_keys.dart';
import 'my_data_errors.dart';

enum MyDataStatus { loading, ready }

enum BackgroundCollectionStatus {
  healthy,
  stale,
  iosBackfill,
  permissionDenied,
}

class MyDataState {
  const MyDataState({
    required this.status,
    this.sampleCount = 0,
    this.fileSizeBytes = 0,
    this.lastOptimizedUtc,
    this.lastIngestionUtc,
    this.backgroundStatus = BackgroundCollectionStatus.healthy,
    this.isIos = false,
    this.isExporting = false,
    this.exportError,
    this.exportSuccessPending = false,
    this.isImporting = false,
    this.importError,
    this.importValidationDetail,
    this.importSuccessPending = false,
    this.isPurging = false,
    this.purgeError,
    this.purgeSuccessPending = false,
    this.dailyStepGoal = kDefaultStepGoal,
    this.displayName,
  });

  final MyDataStatus status;
  final int sampleCount;
  final int fileSizeBytes;
  final DateTime? lastOptimizedUtc;
  final DateTime? lastIngestionUtc;
  final BackgroundCollectionStatus backgroundStatus;
  final bool isIos;
  final bool isExporting;
  final MyDataExportError? exportError;
  /// True after successful CSV save; drives success snackbar once.
  final bool exportSuccessPending;
  final bool isImporting;
  final MyDataImportError? importError;
  /// Raw parser detail when [importError] is [MyDataImportError.validation].
  final String? importValidationDetail;
  /// True after import with at least one data row; drives success snackbar once.
  final bool importSuccessPending;
  final bool isPurging;
  final MyDataPurgeError? purgeError;
  /// True after successful purge; drives success snackbar once.
  final bool purgeSuccessPending;
  final int dailyStepGoal;
  final String? displayName;

  const MyDataState.loading() : this(status: MyDataStatus.loading);

  factory MyDataState.ready({
    required int sampleCount,
    required int fileSizeBytes,
    DateTime? lastOptimizedUtc,
    DateTime? lastIngestionUtc,
    required BackgroundCollectionStatus backgroundStatus,
    required bool isIos,
    int dailyStepGoal = kDefaultStepGoal,
    String? displayName,
  }) {
    return MyDataState(
      status: MyDataStatus.ready,
      sampleCount: sampleCount,
      fileSizeBytes: fileSizeBytes,
      lastOptimizedUtc: lastOptimizedUtc,
      lastIngestionUtc: lastIngestionUtc,
      backgroundStatus: backgroundStatus,
      isIos: isIos,
      dailyStepGoal: dailyStepGoal,
      displayName: displayName,
    );
  }

  bool get isStale => backgroundStatus == BackgroundCollectionStatus.stale;

  MyDataState copyWith({
    MyDataStatus? status,
    int? sampleCount,
    int? fileSizeBytes,
    DateTime? lastOptimizedUtc,
    DateTime? lastIngestionUtc,
    BackgroundCollectionStatus? backgroundStatus,
    bool? isIos,
    bool? isExporting,
    Object? exportError = _unset,
    bool? exportSuccessPending,
    bool? isImporting,
    Object? importError = _unset,
    Object? importValidationDetail = _unset,
    bool? importSuccessPending,
    bool? isPurging,
    Object? purgeError = _unset,
    bool? purgeSuccessPending,
    int? dailyStepGoal,
    Object? displayName = _unset,
  }) {
    return MyDataState(
      status: status ?? this.status,
      sampleCount: sampleCount ?? this.sampleCount,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      lastOptimizedUtc: lastOptimizedUtc ?? this.lastOptimizedUtc,
      lastIngestionUtc: lastIngestionUtc ?? this.lastIngestionUtc,
      backgroundStatus: backgroundStatus ?? this.backgroundStatus,
      isIos: isIos ?? this.isIos,
      isExporting: isExporting ?? this.isExporting,
      exportError: exportError == _unset
          ? this.exportError
          : exportError as MyDataExportError?,
      exportSuccessPending:
          exportSuccessPending ?? this.exportSuccessPending,
      isImporting: isImporting ?? this.isImporting,
      importError: importError == _unset
          ? this.importError
          : importError as MyDataImportError?,
      importValidationDetail: importValidationDetail == _unset
          ? this.importValidationDetail
          : importValidationDetail as String?,
      importSuccessPending:
          importSuccessPending ?? this.importSuccessPending,
      isPurging: isPurging ?? this.isPurging,
      purgeError: purgeError == _unset
          ? this.purgeError
          : purgeError as MyDataPurgeError?,
      purgeSuccessPending: purgeSuccessPending ?? this.purgeSuccessPending,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      displayName: displayName == _unset
          ? this.displayName
          : displayName as String?,
    );
  }
}

const _unset = Object();
