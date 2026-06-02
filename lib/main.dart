import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/app_dependencies.dart';
import 'core/services/workmanager_callback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final deps = await AppDependencies.create();
  await registerStepCollectionWorkmanager();
  runApp(AstraApp(deps: deps));
}
