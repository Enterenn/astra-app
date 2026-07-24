import 'package:permission_handler/permission_handler.dart';

import '../../presentation/cubits/onboarding_state.dart';

bool isNotificationPermissionGranted(PermissionStatus status) =>
    status.isGranted || status.isLimited || status.isProvisional;

PermissionRequestStatus mapNotificationPermissionStatus(PermissionStatus status) {
  if (isNotificationPermissionGranted(status)) {
    return PermissionRequestStatus.granted;
  }
  if (status.isPermanentlyDenied) {
    return PermissionRequestStatus.permanentlyDenied;
  }
  return PermissionRequestStatus.denied;
}
