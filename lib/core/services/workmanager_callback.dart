import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/datasources/adp_ble_source.dart';
import '../../data/datasources/data_ingestion_source.dart';
import '../../data/datasources/phone_pedometer_source.dart';
import '../../data/datasources/step_normalizer.dart';
import '../../data/repositories/ingestion_baseline_repository.dart';
import '../../data/repositories/step_repository.dart';
import '../database/isolate_database_factory.dart';
import '../time/system_time_provider.dart';
import '../time/time_provider.dart';
import 'background_collector.dart';
import 'workmanager_tasks.dart';

typedef AstraDatabaseOpener = Future<Database> Function({String? databasePath});

abstract class StepCollectionWorkmanagerClient {
  Future<void> initialize(Function callbackDispatcher);

  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    required Duration frequency,
    required ExistingPeriodicWorkPolicy existingWorkPolicy,
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
  }) {
    return _workmanager.registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: frequency,
      existingWorkPolicy: existingWorkPolicy,
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
}) async {
  Database? db;
  try {
    db = await openDatabase(databasePath: databasePath);
    final timeProvider = clock ?? const SystemTimeProvider();
    final repository = StepRepository(db: db, clock: timeProvider);
    final normalizer = StepNormalizer(clock: timeProvider);
    final collector = BackgroundCollector(
      sources: sources ?? [PhonePedometerSource(), const AdpBleSource()],
      normalizer: normalizer,
      repository: repository,
      baselineRepository: IngestionBaselineRepository(db),
    );

    await collector.collectOnce();
    return true;
  } catch (error, stackTrace) {
    debugPrint('WorkManager step collection failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    return false;
  } finally {
    await db?.close();
  }
}

Future<void> registerStepCollectionWorkmanager({
  bool? isAndroid,
  StepCollectionWorkmanagerClient? client,
}) async {
  if (!(isAndroid ?? Platform.isAndroid)) {
    return;
  }

  final workmanager = client ?? PluginStepCollectionWorkmanagerClient();
  await workmanager.initialize(callbackDispatcher);
  await workmanager.registerPeriodicTask(
    kStepCollectionUniqueName,
    kStepCollectionTaskName,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
