import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../../presentation/cubits/onboarding_state.dart';

typedef ActivityPermissionResolver = Permission Function();

Permission resolveActivityPermission() {
  return Platform.isIOS ? Permission.sensors : Permission.activityRecognition;
}

bool isActivityPermissionGranted(PermissionStatus status) => status.isGranted;

PermissionRequestStatus mapActivityPermissionStatus(PermissionStatus status) {
  if (status.isGranted) {
    return PermissionRequestStatus.granted;
  }
  if (status.isPermanentlyDenied) {
    return PermissionRequestStatus.permanentlyDenied;
  }
  return PermissionRequestStatus.denied;
}

Future<PermissionRequestStatus> resolveActivityPermissionStatus() async {
  final status = await resolveActivityPermission().status;
  return mapActivityPermissionStatus(status);
}

typedef ActivityPermissionStatusChecker =
    Future<PermissionRequestStatus> Function();

/// Canonical activity gate for FGS and Today screens.
Future<bool> isActivityRecognitionGranted() async {
  final status = await resolveActivityPermission().status;
  return isActivityPermissionGranted(status);
}
