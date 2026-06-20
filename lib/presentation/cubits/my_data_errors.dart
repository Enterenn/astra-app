/// Export failure codes emitted by [MyDataCubit] — map to l10n in UI.
enum MyDataExportError {
  generic,
}

/// Import failure codes emitted by [MyDataCubit] — map to l10n in UI.
enum MyDataImportError {
  generic,
  validation,
}

/// Purge failure codes emitted by [MyDataCubit] — map to l10n in UI.
enum MyDataPurgeError {
  generic,
  refreshFailedAfterPurge,
}
