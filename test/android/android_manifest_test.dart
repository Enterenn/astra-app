import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AndroidManifest background health permissions', () {
    late String manifest;

    setUpAll(() {
      manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
    });

    test('declares activity recognition and health foreground service permissions', () {
      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />',
        ),
      );
      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />',
        ),
      );
      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.FOREGROUND_SERVICE_HEALTH" />',
        ),
      );
    });

    test('does not use dataSync or network permission for health collection', () {
      expect(manifest, isNot(contains('foregroundServiceType="dataSync"')));
      expect(
        manifest,
        isNot(contains('android.permission.INTERNET')),
      );
    });
  });
}
