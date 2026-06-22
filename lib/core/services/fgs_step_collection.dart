import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/datasources/data_ingestion_source.dart';
import '../database/isolate_database_factory.dart';
import '../time/time_provider.dart';
import 'background_collector_factory.dart';
import 'notification_service.dart';
import 'workmanager_callback.dart';

/// Periodic health FGS collection — same ingestion path as WorkManager isolate.
@pragma('vm:entry-point')
Future<bool> runFgsStepCollectionCycle({
  String? databasePath,
  List<DataIngestionSource>? sources,
  TimeProvider? clock,
  AstraDatabaseOpener openDatabase = openIsolateAstraDatabase,
  NotificationService? notificationService,
  Future<bool> Function()? notificationPermissionGranted,
  bool skipPhoneSourceWhenUiActive = false,
  bool closeDatabaseOnComplete = true,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  Database? db;
  try {
    db = await openDatabase(databasePath: databasePath);
    final collector = await createIsolateBackgroundCollector(
      db: db,
      databasePath: databasePath,
      sources: sources,
      clock: clock,
      notificationService: notificationService,
      notificationPermissionGranted: notificationPermissionGranted,
      includePhonePedometerSource:
          sources == null && !skipPhoneSourceWhenUiActive,
    );
    await collector.collectOnce(enableGoalNotification: true);
    return true;
  } catch (error, stackTrace) {
    debugPrint('FGS step collection failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    return false;
  } finally {
    if (closeDatabaseOnComplete) {
      await db?.close();
    }
  }
}
