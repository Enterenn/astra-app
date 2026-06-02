import 'package:astra_app/data/datasources/step_increment_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StepIncrementCalculator', () {
    const calculator = StepIncrementCalculator();

    test('returns positive delta when current exceeds baseline', () {
      expect(
        calculator.calculate(current: 15, baseline: 10),
        5,
      );
    });

    test('returns null for small negative drop (noise)', () {
      expect(
        calculator.calculate(current: 9, baseline: 10),
        isNull,
      );
    });

    test('returns current on reboot-sized drop', () {
      expect(
        calculator.calculate(current: 3, baseline: 100),
        3,
      );
    });
  });
}
