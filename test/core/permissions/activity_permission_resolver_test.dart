import 'package:astra_app/core/permissions/activity_permission_resolver.dart';
import 'package:astra_app/presentation/cubits/onboarding_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('mapActivityPermissionStatus', () {
    test('maps granted to granted', () {
      expect(
        mapActivityPermissionStatus(PermissionStatus.granted),
        PermissionRequestStatus.granted,
      );
    });

    test('maps limited and provisional to denied', () {
      expect(
        mapActivityPermissionStatus(PermissionStatus.limited),
        PermissionRequestStatus.denied,
      );
      expect(
        mapActivityPermissionStatus(PermissionStatus.provisional),
        PermissionRequestStatus.denied,
      );
    });

    test('maps permanentlyDenied to permanentlyDenied', () {
      expect(
        mapActivityPermissionStatus(PermissionStatus.permanentlyDenied),
        PermissionRequestStatus.permanentlyDenied,
      );
    });

    test('maps other statuses to denied', () {
      expect(
        mapActivityPermissionStatus(PermissionStatus.denied),
        PermissionRequestStatus.denied,
      );
      expect(
        mapActivityPermissionStatus(PermissionStatus.restricted),
        PermissionRequestStatus.denied,
      );
    });
  });

  group('isActivityPermissionGranted', () {
    test('returns true only for granted', () {
      expect(isActivityPermissionGranted(PermissionStatus.granted), isTrue);
      expect(isActivityPermissionGranted(PermissionStatus.limited), isFalse);
      expect(isActivityPermissionGranted(PermissionStatus.provisional), isFalse);
      expect(isActivityPermissionGranted(PermissionStatus.denied), isFalse);
    });
  });
}
