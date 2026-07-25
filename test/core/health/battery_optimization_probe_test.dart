@Tags(['critical'])
library;

import 'package:astra_app/core/health/battery_optimization_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('likelyOemBatteryDeferral', () {
    test('false when battery exempt', () {
      expect(
        likelyOemBatteryDeferral(
          manufacturer: 'Xiaomi',
          batteryOptimizationExempt: true,
        ),
        isFalse,
      );
    });

    test('true for known aggressive OEM when not exempt', () {
      expect(
        likelyOemBatteryDeferral(
          manufacturer: 'samsung',
          batteryOptimizationExempt: false,
        ),
        isTrue,
      );
    });

    test('false for unknown manufacturer', () {
      expect(
        likelyOemBatteryDeferral(
          manufacturer: 'Google',
          batteryOptimizationExempt: false,
        ),
        isFalse,
      );
    });
  });
}
