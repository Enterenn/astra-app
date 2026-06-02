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

    test('declares health foreground service without dataSync type', () {
      expect(
        manifest,
        contains('android:name=".HealthStepForegroundService"'),
      );
      expect(
        manifest,
        contains('android:foregroundServiceType="health"'),
      );
      expect(manifest, isNot(contains('foregroundServiceType="dataSync"')));
    });

    test('does not use network permission for health collection', () {
      expect(
        manifest,
        isNot(contains('android.permission.INTERNET')),
      );
    });
  });
}
