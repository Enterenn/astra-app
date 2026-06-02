import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/app_dependencies.dart';
import 'core/services/notification_service.dart';
import 'core/services/workmanager_callback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notificationService = NotificationService();
  await notificationService.initialize();
  final deps = await AppDependencies.create(
    notificationService: notificationService,
  );
  await registerStepCollectionWorkmanager();
  runApp(AstraApp(deps: deps));
}
