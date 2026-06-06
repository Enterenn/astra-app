import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _internetUsesPermission =
    '<uses-permission android:name="android.permission.INTERNET"/>';

final _internetUsesPermissionPattern = RegExp(
  r'<uses-permission\s+android:name="android\.permission\.INTERNET"\s*/>',
);

void main() {
  group('Release manifest network policy (FR-18)', () {
    test('main manifest does not declare INTERNET', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(_internetUsesPermissionPattern.hasMatch(manifest), isFalse);
    });

    test('debug manifest declares INTERNET for Flutter tooling', () {
      final manifest = File(
        'android/app/src/debug/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains(_internetUsesPermission));
    });

    test('profile manifest declares INTERNET for Flutter tooling', () {
      final manifest = File(
        'android/app/src/profile/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains(_internetUsesPermission));
    });
  });
}
