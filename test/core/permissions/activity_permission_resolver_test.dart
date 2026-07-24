import 'package:astra_app/core/permissions/activity_permission_resolver.dart';
import 'package:astra_app/presentation/cubits/onboarding_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('mapPermissionStatus', () {
    test('maps granted statuses to granted', () {
      expect(mapPermissionStatus(PermissionStatus.granted),
          PermissionRequestStatus.granted);
      expect(mapPermissionStatus(PermissionStatus.limited),
          PermissionRequestStatus.granted);
      expect(mapPermissionStatus(PermissionStatus.provisional),
          PermissionRequestStatus.granted);
    });

    test('maps permanentlyDenied to permanentlyDenied', () {
      expect(mapPermissionStatus(PermissionStatus.permanentlyDenied),
          PermissionRequestStatus.permanentlyDenied);
    });

    test('maps other statuses to denied', () {
      expect(mapPermissionStatus(PermissionStatus.denied),
          PermissionRequestStatus.denied);
      expect(mapPermissionStatus(PermissionStatus.restricted),
          PermissionRequestStatus.denied);
    });
  });
}
