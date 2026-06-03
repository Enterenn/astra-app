import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/datasources/data_ingestion_source.dart';
import '../database/isolate_database_factory.dart';
import '../time/time_provider.dart';
import '../../data/repositories/step_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../time/system_time_provider.dart';
import 'background_collector_factory.dart';
import 'data_lifecycle_service.dart';
import 'notification_service.dart';
import 'workmanager_tasks.dart';

typedef AstraDatabaseOpener = Future<Database> Function({String? databasePath});

abstract class StepCollectionWorkmanagerClient {
  Future<void> initialize(Function callbackDispatcher);

  Future<void> cancelByUniqueName(String uniqueName);

  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    required Duration frequency,
    required ExistingPeriodicWorkPolicy existingWorkPolicy,
    Map<String, dynamic>? inputData,
  });
}

class PluginStepCollectionWorkmanagerClient
    implements StepCollectionWorkmanagerClient {
  PluginStepCollectionWorkmanagerClient({Workmanager? workmanager})
    : _workmanager = workmanager ?? Workmanager();

  final Workmanager _workmanager;

  @override
  Future<void> initialize(Function callbackDispatcher) {
    return _workmanager.initialize(callbackDispatcher);
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) {
    return _workmanager.cancelByUniqueName(uniqueName);
  }

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    required Duration frequency,
    required ExistingPeriodicWorkPolicy existingWorkPolicy,
    Map<String, dynamic>? inputData,
  }) {
    return _workmanager.registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: frequency,
      existingWorkPolicy: existingWorkPolicy,
      inputData: inputData,
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask(handleWorkmanagerTask);
}

Future<bool> handleWorkmanagerTask(
  String task,
  Map<String, dynamic>? inputData,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final databasePath = inputData?['databasePath'] as String?;

  if (task == kStepCollectionTaskName) {
    return runStepCollectionWorkmanagerTask(databasePath: databasePath);
  }

  if (task == kDatabaseMaintenanceTaskName) {
    return runDatabaseMaintenanceWorkmanagerTask(databasePath: databasePath);
  }

  debugPrint('WorkManager ignored unknown task: $task');
  return true;
}

@visibleForTesting
Future<bool> runStepCollectionWorkmanagerTask({
  String? databasePath,
  List<DataIngestionSource>? sources,
  TimeProvider? clock,
  AstraDatabaseOpener openDatabase = openIsolateAstraDatabase,
  NotificationService? notificationService,
  Future<bool> Function()? notificationPermissionGranted,
}) async {
  Database? db;
  try {
    db = await openDatabase(databasePath: databasePath);
    final collector = await createIsolateBackgroundCollector(
      db: db,
      sources: sources,
      clock: clock,
      notificationService: notificationService,
      notificationPermissionGranted: notificationPermissionGranted,
    );

    await collector.collectOnce(enableGoalNotification: true);
    return true;
  } catch (error, stackTrace) {
    debugPrint('WorkManager step collection failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    return false;
  } finally {
    await db?.close();
  }
}

@visibleForTesting
Future<bool> runDatabaseMaintenanceWorkmanagerTask({
  String? databasePath,
  TimeProvider? clock,
  AstraDatabaseOpener openDatabase = openIsolateAstraDatabase,
  Future<LifecycleRunResult> Function(DataLifecycleService service)?
  runMaintenance,
}) async {
  if (databasePath == null) {
    debugPrint('WorkManager database maintenance skipped: missing databasePath');
    return false;
  }

  Database? db;
  try {
    db = await openDatabase(databasePath: databasePath);
    final timeProvider = clock ?? const SystemTimeProvider();
    final service = DataLifecycleService(
      db: db,
      databasePath: databasePath,
      repository: StepRepository(db: db, clock: timeProvider),
      userPreferences: UserPreferencesRepository(db),
      clock: timeProvider,
      optimizeAndVacuum: runPragmaOptimizeAndVacuumOnWorkerIsolate,
    );
    final maintenance =
        runMaintenance ?? ((svc) => svc.runMaintenance());
    await maintenance(service);
    return true;
  } catch (error, stackTrace) {
    debugPrint('WorkManager database maintenance failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    return false;
  } finally {
    await db?.close();
  }
}

/// Runs optimize/VACUUM on a worker isolate without spawning [compute].
///
/// Uses the caller's open [db] so preference writes after maintenance stay valid.
/// WorkManager and other background entry points are already off the UI thread.
Future<void> runPragmaOptimizeAndVacuumOnWorkerIsolate(
  Database db,
  String databasePath,
) async {
  await db.rawQuery('PRAGMA optimize');
  await db.execute('VACUUM');
}

/// Cancels any in-flight Android step-collection WM work before UI-isolate init.
///
/// Prevents a background isolate from racing [NotificationService.initialize].
Future<void> cancelStepCollectionWorkmanager({
  bool? isAndroid,
  StepCollectionWorkmanagerClient? client,
}) async {
  if (!(isAndroid ?? Platform.isAndroid)) {
    return;
  }

  final workmanager = client ?? PluginStepCollectionWorkmanagerClient();
  await workmanager.cancelByUniqueName(kStepCollectionUniqueName);
}

/// Registers Android periodic step collection (D-04).
///
/// WorkManager is the reconciliation fallback when FGS cannot run — not a
/// realtime 5-minute guarantee. Foreground backfill on app open remains mandatory.
Future<void> registerStepCollectionWorkmanager({
  bool? isAndroid,
  String? databasePath,
  StepCollectionWorkmanagerClient? client,
}) async {
  if (!(isAndroid ?? Platform.isAndroid)) {
    return;
  }

  final workmanager = client ?? PluginStepCollectionWorkmanagerClient();
  await workmanager.initialize(callbackDispatcher);
  final inputData = databasePath == null
      ? null
      : <String, dynamic>{'databasePath': databasePath};
  // UPDATE applies new inputData on upgrade; KEEP would leave pre-2.10 work without path.
  final existingWorkPolicy = databasePath == null
      ? ExistingPeriodicWorkPolicy.keep
      : ExistingPeriodicWorkPolicy.update;
  await workmanager.registerPeriodicTask(
    kStepCollectionUniqueName,
    kStepCollectionTaskName,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: existingWorkPolicy,
    inputData: inputData,
  );
}

/// Registers Android weekly database maintenance (FR12).
///
/// Call after [registerStepCollectionWorkmanager] so WorkManager is initialized.
Future<void> registerDatabaseMaintenanceWorkmanager({
  bool? isAndroid,
  required String databasePath,
  StepCollectionWorkmanagerClient? client,
}) async {
  if (!(isAndroid ?? Platform.isAndroid)) {
    return;
  }

  final workmanager = client ?? PluginStepCollectionWorkmanagerClient();
  await workmanager.registerPeriodicTask(
    kDatabaseMaintenanceUniqueName,
    kDatabaseMaintenanceTaskName,
    frequency: kDatabaseMaintenanceInterval,
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    inputData: <String, dynamic>{'databasePath': databasePath},
  );
}
