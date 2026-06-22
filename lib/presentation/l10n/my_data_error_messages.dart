import 'package:astra_app/l10n/app_localizations.dart';

import '../cubits/my_data_errors.dart';
import '../cubits/my_data_state.dart';

String? myDataExportErrorMessage(
  AppLocalizations l10n,
  MyDataExportError? error,
) {
  return switch (error) {
    null => null,
    MyDataExportError.generic => l10n.myDataExportErrorGeneric,
  };
}

String? myDataImportErrorMessage(
  AppLocalizations l10n,
  MyDataState state,
) {
  return switch (state.importError) {
    null => null,
    MyDataImportError.generic => l10n.myDataImportErrorGeneric,
    MyDataImportError.validation =>
      state.importValidationDetail ?? l10n.myDataImportErrorGeneric,
  };
}

String? myDataPurgeErrorMessage(
  AppLocalizations l10n,
  MyDataPurgeError? error,
) {
  return switch (error) {
    null => null,
    MyDataPurgeError.generic => l10n.myDataPurgeErrorGeneric,
    MyDataPurgeError.refreshFailedAfterPurge => l10n.myDataPurgeRefreshError,
  };
}
