@Tags(['slow'])
library;

import 'dart:io';

import 'package:astra_app/core/health/background_health_manifest.dart';
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

    test('declares boot completed and battery optimization permissions', () {
      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />',
        ),
      );
      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />',
        ),
      );
    });

    test('declares boot receiver and health foreground service', () {
      expect(
        manifest,
        contains('android:name=".BootCompletedReceiver"'),
      );
      expect(
        manifest,
        contains('<action android:name="android.intent.action.BOOT_COMPLETED" />'),
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
      expect(kAndroidFgsHealthManifestDeclared, isTrue);
    });

  });
}
