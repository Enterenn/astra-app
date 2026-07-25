import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/di/app_dependencies.dart';
import '../../data/csv/csv_platform_file_picker.dart';
import '../cubits/history_cubit.dart';
import '../cubits/my_data_cubit.dart';
import '../cubits/profile_cubit.dart';
import '../cubits/today_cubit.dart';

/// Owns and wires together the four app-level cubits, resolving their
/// cross-cubit refresh callbacks in one place instead of inline in the
/// widget tree. Not a Widget: testable without mounting anything.
class AppCubitCoordinator {
  AppCubitCoordinator({
    required this.deps,
    TodayCubit Function(AppDependencies deps)? createTodayCubit,
    HistoryCubit Function(AppDependencies deps)? createHistoryCubit,
    MyDataCubit Function(AppDependencies deps)? createMyDataCubit,
    ProfileCubit Function(AppDependencies deps)? createProfileCubit,
    ValueChanged<HistoryCubit>? onHistoryFirstCreated,
  }) : _createHistoryCubit = createHistoryCubit,
       _onHistoryFirstCreated = onHistoryFirstCreated {
    today = createTodayCubit?.call(deps) ??
        TodayCubit(
          stepAggregation: deps.stepAggregation,
          userSettings: deps.userSettings,
          userHealthMetrics: deps.userHealthMetrics,
          clock: deps.timeProvider,
          activityPermissionGranted: deps.activityPermissionGranted,
          postGoalUpdate: _onTodayGoalUpdate,
        );
    myData = createMyDataCubit?.call(deps) ??
        MyDataCubit(
          stepAggregation: deps.stepAggregation,
          csvService: deps.csvService,
          stepIngestion: deps.stepIngestion,
          userSettings: deps.userSettings,
          userHealthMetrics: deps.userHealthMetrics,
          clock: deps.timeProvider,
          databasePath: deps.databasePath,
          activityPermissionGranted: deps.activityPermissionGranted,
          pickCsvFile: pickCsvFileForImport,
          saveCsvFile: saveCsvExportFile,
          saveFieldLogFile: saveFieldLogExportFile,
          postImportRefresh: _onImportComplete,
          postPurgeRefresh: refreshAfterPurge,
          postGoalUpdate: _onMyDataGoalUpdate,
        );
    profile = createProfileCubit?.call(deps) ??
        ProfileCubit(
          userSettings: deps.userSettings,
          userHealthMetrics: deps.userHealthMetrics,
          notificationService: deps.notificationService,
          postDisplayNameUpdate: _onDisplayNameUpdate,
        );
  }

  final AppDependencies deps;
  final HistoryCubit Function(AppDependencies deps)? _createHistoryCubit;
  final ValueChanged<HistoryCubit>? _onHistoryFirstCreated;

  late final TodayCubit today;
  late final MyDataCubit myData;
  late final ProfileCubit profile;

  HistoryCubit? _history;
  bool _disposed = false;

  HistoryCubit? get historyIfCreated => _history;

  /// Lazily creates the History cubit on first access (e.g. first time the
  /// Trends tab is opened). Mirrors the previous AppScaffold behaviour.
  HistoryCubit ensureHistory() {
    if (_history != null) {
      return _history!;
    }
    final created = _createHistoryCubit?.call(deps) ??
        HistoryCubit(
          stepAggregation: deps.stepAggregation,
          userHealthMetrics: deps.userHealthMetrics,
        );
    _history = created;
    _onHistoryFirstCreated?.call(created);
    return created;
  }

  Future<void> _onTodayGoalUpdate() async {
    await _history?.refreshGoal();
    await myData.refresh(silent: true);
  }

  Future<void> _onMyDataGoalUpdate() async {
    await today.refreshMetadata();
    await _history?.refreshGoal();
  }

  Future<void> _onImportComplete() async {
    await today.refreshMetadata();
    await ensureHistory().refresh(silent: true);
    await myData.refresh(silent: true);
  }

  Future<void> _onDisplayNameUpdate() async {
    await today.refreshMetadata();
  }

  /// Called after a data purge. Each phase checks [_disposed] instead of a
  /// widget [mounted] flag, since this class has no widget lifecycle.
  Future<void> refreshAfterPurge() async {
    var phase = '';
    try {
      phase = 'clearLastDisplayedSteps';
      await deps.userSettings.clearLastDisplayedSteps();
      if (_disposed) return;

      phase = 'reconcileFromDatabase';
      await deps.liveStepMonitor.reconcileFromDatabase();
      if (_disposed) return;

      phase = 'todayRefresh';
      await today.refresh(silent: true);
      if (_disposed) return;

      phase = 'todaySyncSteps';
      await today.syncSteps(deps.liveStepMonitor.currentTodaySteps);
      if (_disposed) return;

      phase = 'todayRefreshMetadata';
      await today.refreshMetadata();
      if (_disposed) return;

      phase = 'historyRefresh';
      await ensureHistory().refresh(silent: true);
      if (_disposed) return;

      phase = 'myDataRefresh';
      await myData.refresh(silent: true);
      if (_disposed) return;

      unawaited(deps.dataLifecycleService.runMaintenance(force: true));
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'AppCubitCoordinator.refreshAfterPurge failed at $phase: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  /// Called when the background collector reports new ingested steps.
  void onIngestionComplete({required bool historyTabActive}) {
    unawaited(today.refreshMetadata());
    if (historyTabActive) {
      unawaited(_history?.refresh(silent: true));
    }
    unawaited(myData.refresh(silent: true));
  }

  /// Called when the user navigates back to the Today tab.
  void onReturnToToday() {
    unawaited(today.refreshMetadata());
    unawaited(_history?.refreshGoal());
  }

  void dispose() {
    _disposed = true;
    unawaited(today.close());
    unawaited(_history?.close());
    unawaited(myData.close());
    unawaited(profile.close());
  }
}
