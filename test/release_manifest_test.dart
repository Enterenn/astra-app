import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Release manifest network policy (FR-18)', () {
    test('main manifest does not declare INTERNET', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, isNot(contains('android.permission.INTERNET')));
    });

    test('debug manifest declares INTERNET for Flutter tooling', () {
      final manifest = File(
        'android/app/src/debug/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android.permission.INTERNET'));
    });

    test('profile manifest declares INTERNET for Flutter tooling', () {
      final manifest = File(
        'android/app/src/profile/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android.permission.INTERNET'));
    });
  });
}
