import 'package:astra_app/core/health/background_health_capability_snapshot.dart';
import 'package:astra_app/core/health/background_health_manifest.dart';
import 'package:astra_app/core/services/background_health_capability_evaluator.dart';
import 'package:astra_app/core/services/platform_capability_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackgroundHealthCapabilityEvaluator', () {
    test('maps all snapshot fields from injected checkers', () async {
      final evaluator = BackgroundHealthCapabilityEvaluator(
        activityRecognitionGranted: () async => true,
        notificationGranted: () async => false,
        platformProbe: _FakeProbe(
          batteryExempt: true,
          manufacturer: 'Google',
        ),
        isAndroidPlatform: () => true,
      );

      final snapshot = await evaluator.evaluate();

      expect(snapshot.activityRecognitionGranted, isTrue);
      expect(snapshot.notificationGranted, isFalse);
      expect(snapshot.batteryOptimizationExempt, isTrue);
      expect(snapshot.fgsHealthDeclared, isTrue);
      expect(snapshot.manufacturer, 'Google');
      expect(snapshot.likelyOemBatteryDeferral, isFalse);
    });

    test('iOS uses battery exempt true and no OEM deferral', () async {
      final evaluator = BackgroundHealthCapabilityEvaluator(
        activityRecognitionGranted: () async => true,
        notificationGranted: () async => true,
        platformProbe: _FakeProbe(
          batteryExempt: false,
          manufacturer: 'Apple',
        ),
        isAndroidPlatform: () => false,
        fgsHealthDeclaredOnAndroid: true,
      );

      final snapshot = await evaluator.evaluate();

      expect(snapshot.batteryOptimizationExempt, isTrue);
      expect(snapshot.fgsHealthDeclared, isFalse);
      expect(snapshot.manufacturer, isNull);
      expect(snapshot.likelyOemBatteryDeferral, isFalse);
    });

    test('fgsHealthDeclared false when manifest flag disabled on Android', () async {
      final evaluator = BackgroundHealthCapabilityEvaluator(
        activityRecognitionGranted: () async => true,
        notificationGranted: () async => true,
        platformProbe: const _FakeProbe(batteryExempt: true),
        isAndroidPlatform: () => true,
        fgsHealthDeclaredOnAndroid: false,
      );

      final snapshot = await evaluator.evaluate();

      expect(snapshot.fgsHealthDeclared, isFalse);
    });

    group('likelyOemBatteryDeferral matrix', () {
      Future<BackgroundHealthCapabilitySnapshot> evaluateWith({
        required String manufacturer,
        required bool batteryExempt,
      }) {
        final evaluator = BackgroundHealthCapabilityEvaluator(
          activityRecognitionGranted: () async => true,
          notificationGranted: () async => true,
          platformProbe: _FakeProbe(
            batteryExempt: batteryExempt,
            manufacturer: manufacturer,
          ),
          isAndroidPlatform: () => true,
        );
        return evaluator.evaluate();
      }

      test('Samsung + not exempt → true', () async {
        final snapshot = await evaluateWith(
          manufacturer: 'samsung',
          batteryExempt: false,
        );
        expect(snapshot.likelyOemBatteryDeferral, isTrue);
      });

      test('Samsung + exempt → false', () async {
        final snapshot = await evaluateWith(
          manufacturer: 'Samsung',
          batteryExempt: true,
        );
        expect(snapshot.likelyOemBatteryDeferral, isFalse);
      });

      test('Google + not exempt → false', () async {
        final snapshot = await evaluateWith(
          manufacturer: 'Google',
          batteryExempt: false,
        );
        expect(snapshot.likelyOemBatteryDeferral, isFalse);
      });

      test('Xiaomi + not exempt → true', () async {
        final snapshot = await evaluateWith(
          manufacturer: 'Xiaomi',
          batteryExempt: false,
        );
        expect(snapshot.likelyOemBatteryDeferral, isTrue);
      });
    });
  });

  test('manifest constant aligns with evaluator Android FGS flag', () {
    expect(kAndroidFgsHealthManifestDeclared, isTrue);
  });
}

class _FakeProbe extends PlatformCapabilityProbe {
  const _FakeProbe({
    required this.batteryExempt,
    this.manufacturer,
  });

  final bool batteryExempt;
  final String? manufacturer;

  @override
  Future<bool> isBatteryOptimizationExempt() async => batteryExempt;

  @override
  Future<String?> getDeviceManufacturer() async => manufacturer;
}
