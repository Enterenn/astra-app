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

    test('reboot reset path ignores elapsed and rate cap', () {
      expect(
        calculator.calculate(
          current: 3,
          baseline: 100,
          elapsedSincePrevious: const Duration(milliseconds: 200),
        ),
        3,
      );
    });

    test('shake burst credits at most one step per 200 ms', () {
      final credited = calculator.calculate(
        current: 60,
        baseline: 10,
        elapsedSincePrevious: const Duration(milliseconds: 200),
      );
      expect(credited, lessThanOrEqualTo(2));
      expect(credited, greaterThanOrEqualTo(1));
    });

    test('normal walk credits full delta within rate limit', () {
      expect(
        calculator.calculate(
          current: 15,
          baseline: 10,
          elapsedSincePrevious: const Duration(seconds: 1),
        ),
        5,
      );
    });

    test('fast run credits capped delta at max steps per second', () {
      expect(
        calculator.calculate(
          current: 18,
          baseline: 10,
          elapsedSincePrevious: const Duration(seconds: 1),
        ),
        StepIncrementCalculator.kMaxStepsPerSecond,
      );
    });

    test('long gap credits full large delta when gap exceeds cap window', () {
      expect(
        calculator.calculate(
          current: 110,
          baseline: 10,
          elapsedSincePrevious: const Duration(minutes: 2),
        ),
        100,
      );
    });

    test('first increment without elapsed applies no rate cap', () {
      expect(
        calculator.calculate(
          current: 60,
          baseline: 10,
        ),
        50,
      );
    });
  });
}
