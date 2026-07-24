import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../../presentation/cubits/onboarding_state.dart';

typedef ActivityPermissionResolver = Permission Function();

Permission resolveActivityPermission() {
  return Platform.isIOS ? Permission.sensors : Permission.activityRecognition;
}

PermissionRequestStatus mapPermissionStatus(PermissionStatus status) {
  if (status.isGranted || status.isLimited || status.isProvisional) {
    return PermissionRequestStatus.granted;
  }
  if (status.isPermanentlyDenied) {
    return PermissionRequestStatus.permanentlyDenied;
  }
  return PermissionRequestStatus.denied;
}

Future<PermissionRequestStatus> resolveActivityPermissionStatus() async {
  final status = await resolveActivityPermission().status;
  return mapPermissionStatus(status);
}

typedef ActivityPermissionStatusChecker =
    Future<PermissionRequestStatus> Function();

/// Canonical activity gate for FGS and Today screens.
Future<bool> isActivityRecognitionGranted() async {
  final permission = resolveActivityPermission();
  final status = await permission.status;
  return status.isGranted || status.isLimited || status.isProvisional;
}
