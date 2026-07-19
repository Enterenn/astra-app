import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'core/di/app_dependencies.dart';
import 'core/preferences/goal_notification_migration.dart';
import 'core/services/notification_service.dart';
import 'core/services/workmanager_callback.dart';

@visibleForTesting
Future<void> registerWorkmanagerTasksForBoot({
  required String databasePath,
  Future<void> Function({String? databasePath}) registerStepCollection =
      registerStepCollectionWorkmanager,
  Future<void> Function({required String databasePath})
      registerMaintenance = registerDatabaseMaintenanceWorkmanager,
}) async {
  try {
    await registerStepCollection(databasePath: databasePath);
    await registerMaintenance(databasePath: databasePath);
  } catch (error, stackTrace) {
    debugPrint('WorkManager registration failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

@visibleForTesting
void schedulePostRunAppWorkmanagerRegistration(
  String databasePath, {
  Future<void> Function({required String databasePath})? registerBoot,
}) {
  final register = registerBoot ?? registerWorkmanagerTasksForBoot;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(register(databasePath: databasePath));
  });
}

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
    userSettings: deps.userSettings,
    notificationService: notificationService,
  );
  final databasePath = join(await getDatabasesPath(), 'astra_app.db');
  runApp(AstraApp(deps: deps));
  schedulePostRunAppWorkmanagerRegistration(databasePath);
}
