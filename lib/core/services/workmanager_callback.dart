import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/datasources/data_ingestion_source.dart';
import '../database/isolate_database_factory.dart';
import '../time/time_provider.dart';
import 'background_collector_factory.dart';
import 'notification_service.dart';
import 'workmanager_tasks.dart';

typedef AstraDatabaseOpener = Future<Database> Function({String? databasePath});

abstract class StepCollectionWorkmanagerClient {
  Future<void> initialize(Function callbackDispatcher);

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

  if (task != kStepCollectionTaskName) {
    debugPrint('WorkManager ignored unknown task: $task');
    return true;
  }

  final databasePath = inputData?['databasePath'] as String?;
  return runStepCollectionWorkmanagerTask(databasePath: databasePath);
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
