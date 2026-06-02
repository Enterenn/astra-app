import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/app_dependencies.dart';
import 'core/services/notification_service.dart';
import 'core/services/workmanager_callback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notificationService = NotificationService();
  try {
    await notificationService.initialize().timeout(const Duration(seconds: 5));
  } on TimeoutException catch (error) {
    debugPrint('NotificationService init timed out: $error');
  } catch (error, stackTrace) {
    debugPrint('NotificationService init failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  final deps = await AppDependencies.create(
    notificationService: notificationService,
  );
  await registerStepCollectionWorkmanager();
  runApp(AstraApp(deps: deps));
}
