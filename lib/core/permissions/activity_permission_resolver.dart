import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

typedef ActivityPermissionResolver = Permission Function();

Permission resolveActivityPermission() {
  return Platform.isIOS ? Permission.sensors : Permission.activityRecognition;
}

/// Canonical activity gate for FGS, Today, and [BackgroundHealthCapabilityEvaluator].
Future<bool> isActivityRecognitionGranted() async {
  final permission = resolveActivityPermission();
  final status = await permission.status;
  return status.isGranted || status.isLimited || status.isProvisional;
}
