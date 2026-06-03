import '../../core/health/background_health_capability_snapshot.dart';

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
    this.capabilitySnapshot,
    this.isIos = false,
    this.isExporting = false,
    this.exportErrorMessage,
    this.isImporting = false,
    this.importErrorMessage,
    this.importSuccessPending = false,
  });

  final MyDataStatus status;
  final int sampleCount;
  final int fileSizeBytes;
  final DateTime? lastOptimizedUtc;
  final DateTime? lastIngestionUtc;
  final BackgroundCollectionStatus backgroundStatus;
  final BackgroundHealthCapabilitySnapshot? capabilitySnapshot;
  final bool isIos;
  final bool isExporting;
  final String? exportErrorMessage;
  final bool isImporting;
  final String? importErrorMessage;
  /// True after import with at least one data row; drives success snackbar once.
  final bool importSuccessPending;

  const MyDataState.loading() : this(status: MyDataStatus.loading);

  factory MyDataState.ready({
    required int sampleCount,
    required int fileSizeBytes,
    DateTime? lastOptimizedUtc,
    DateTime? lastIngestionUtc,
    required BackgroundCollectionStatus backgroundStatus,
    BackgroundHealthCapabilitySnapshot? capabilitySnapshot,
    required bool isIos,
  }) {
    return MyDataState(
      status: MyDataStatus.ready,
      sampleCount: sampleCount,
      fileSizeBytes: fileSizeBytes,
      lastOptimizedUtc: lastOptimizedUtc,
      lastIngestionUtc: lastIngestionUtc,
      backgroundStatus: backgroundStatus,
      capabilitySnapshot: capabilitySnapshot,
      isIos: isIos,
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
    BackgroundHealthCapabilitySnapshot? capabilitySnapshot,
    bool? isIos,
    bool? isExporting,
    Object? exportErrorMessage = _unset,
    bool? isImporting,
    Object? importErrorMessage = _unset,
    bool? importSuccessPending,
  }) {
    return MyDataState(
      status: status ?? this.status,
      sampleCount: sampleCount ?? this.sampleCount,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      lastOptimizedUtc: lastOptimizedUtc ?? this.lastOptimizedUtc,
      lastIngestionUtc: lastIngestionUtc ?? this.lastIngestionUtc,
      backgroundStatus: backgroundStatus ?? this.backgroundStatus,
      capabilitySnapshot: capabilitySnapshot ?? this.capabilitySnapshot,
      isIos: isIos ?? this.isIos,
      isExporting: isExporting ?? this.isExporting,
      exportErrorMessage: exportErrorMessage == _unset
          ? this.exportErrorMessage
          : exportErrorMessage as String?,
      isImporting: isImporting ?? this.isImporting,
      importErrorMessage: importErrorMessage == _unset
          ? this.importErrorMessage
          : importErrorMessage as String?,
      importSuccessPending:
          importSuccessPending ?? this.importSuccessPending,
    );
  }
}

const _unset = Object();
