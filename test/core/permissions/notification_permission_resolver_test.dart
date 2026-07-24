import 'package:astra_app/core/permissions/notification_permission_resolver.dart';
import 'package:astra_app/presentation/cubits/onboarding_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('isNotificationPermissionGranted', () {
    test('treats granted, limited, and provisional as granted', () {
      expect(isNotificationPermissionGranted(PermissionStatus.granted), isTrue);
      expect(isNotificationPermissionGranted(PermissionStatus.limited), isTrue);
      expect(
        isNotificationPermissionGranted(PermissionStatus.provisional),
        isTrue,
      );
    });

    test('treats denied and permanentlyDenied as not granted', () {
      expect(isNotificationPermissionGranted(PermissionStatus.denied), isFalse);
      expect(
        isNotificationPermissionGranted(PermissionStatus.permanentlyDenied),
        isFalse,
      );
    });
  });

  group('mapNotificationPermissionStatus', () {
    test('maps granted statuses to granted', () {
      expect(
        mapNotificationPermissionStatus(PermissionStatus.granted),
        PermissionRequestStatus.granted,
      );
      expect(
        mapNotificationPermissionStatus(PermissionStatus.limited),
        PermissionRequestStatus.granted,
      );
      expect(
        mapNotificationPermissionStatus(PermissionStatus.provisional),
        PermissionRequestStatus.granted,
      );
    });

    test('maps permanentlyDenied to permanentlyDenied', () {
      expect(
        mapNotificationPermissionStatus(PermissionStatus.permanentlyDenied),
        PermissionRequestStatus.permanentlyDenied,
      );
    });

    test('maps other statuses to denied', () {
      expect(
        mapNotificationPermissionStatus(PermissionStatus.denied),
        PermissionRequestStatus.denied,
      );
    });
  });
}
