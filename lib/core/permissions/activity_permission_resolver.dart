import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

typedef ActivityPermissionResolver = Permission Function();

Permission resolveActivityPermission() {
  return Platform.isIOS ? Permission.sensors : Permission.activityRecognition;
}
