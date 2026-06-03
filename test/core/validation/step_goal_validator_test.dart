import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/validation/step_goal_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateStepGoalInput', () {
    test('accepts minimum bound', () {
      final result = validateStepGoalInput('1000');
      expect(result.isValid, isTrue);
      expect(result.parsedGoal, 1000);
      expect(result.errorMessage, isNull);
    });

    test('accepts maximum bound', () {
      final result = validateStepGoalInput('100000');
      expect(result.isValid, isTrue);
      expect(result.parsedGoal, 100000);
    });

    test('accepts leading zeros', () {
      final result = validateStepGoalInput('08000');
      expect(result.isValid, isTrue);
      expect(result.parsedGoal, 8000);
    });

    test('trims whitespace', () {
      final result = validateStepGoalInput('  5000  ');
      expect(result.isValid, isTrue);
      expect(result.parsedGoal, 5000);
    });

    test('rejects empty input', () {
      final result = validateStepGoalInput('');
      expect(result.isValid, isFalse);
      expect(result.parsedGoal, isNull);
      expect(result.errorMessage, kStepGoalValidationErrorMessage);
    });

    test('rejects whitespace-only input', () {
      final result = validateStepGoalInput('   ');
      expect(result.isValid, isFalse);
    });

    test('rejects non-numeric input', () {
      final result = validateStepGoalInput('abc');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, kStepGoalValidationErrorMessage);
    });

    test('rejects decimal input', () {
      final result = validateStepGoalInput('5000.5');
      expect(result.isValid, isFalse);
    });

    test('rejects below minimum', () {
      final result = validateStepGoalInput('999');
      expect(result.isValid, isFalse);
      expect(result.parsedGoal, isNull);
    });

    test('rejects above maximum', () {
      final result = validateStepGoalInput('100001');
      expect(result.isValid, isFalse);
    });

    test('uses preference_keys bounds', () {
      expect(kMinStepGoal, 1000);
      expect(kMaxStepGoal, 100000);
    });
  });
}
