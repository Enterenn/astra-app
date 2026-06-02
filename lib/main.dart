import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/app_dependencies.dart';
import 'core/services/workmanager_callback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await registerStepCollectionWorkmanager();
  final deps = await AppDependencies.create();
  runApp(AstraApp(deps: deps));
}
