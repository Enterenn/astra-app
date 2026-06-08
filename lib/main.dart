import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'core/di/app_dependencies.dart';
import 'core/preferences/goal_notification_migration.dart';
import 'core/services/notification_service.dart';
import 'core/services/workmanager_callback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await cancelStepCollectionWorkmanager();
  final notificationService = NotificationService();
  try {
    await notificationService.initialize().timeout(const Duration(seconds: 3));
  } on TimeoutException catch (error) {
    debugPrint('NotificationService init timed out: $error');
  } catch (error, stackTrace) {
    debugPrint('NotificationService init failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  final deps = await AppDependencies.create(
    notificationService: notificationService,
  );
  await migrateGoalNotificationPreferenceIfNeeded(
    userPreferences: deps.userPreferences,
    notificationService: notificationService,
  );
  // WM registers regardless of FGS — reconciliation fallback (D-04), not realtime cadence.
  final databasePath = join(await getDatabasesPath(), 'astra_app.db');
  await registerStepCollectionWorkmanager(databasePath: databasePath);
  await registerDatabaseMaintenanceWorkmanager(databasePath: databasePath);
  runApp(AstraApp(deps: deps));
}
