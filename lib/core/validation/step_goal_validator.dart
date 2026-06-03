import '../constants/preference_keys.dart';

/// Result of validating raw daily step goal input.
class StepGoalValidationResult {
  const StepGoalValidationResult({
    required this.isValid,
    this.parsedGoal,
    this.errorMessage,
  });

  final bool isValid;
  final int? parsedGoal;
  final String? errorMessage;
}

const kStepGoalValidationErrorMessage =
    'Enter a value between 1,000 and 100,000.';

/// Validates free-text step goal input (onboarding + goal editor sheet).
StepGoalValidationResult validateStepGoalInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const StepGoalValidationResult(
      isValid: false,
      errorMessage: kStepGoalValidationErrorMessage,
    );
  }

  if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
    return const StepGoalValidationResult(
      isValid: false,
      errorMessage: kStepGoalValidationErrorMessage,
    );
  }

  final parsed = int.tryParse(trimmed);
  if (parsed == null) {
    return const StepGoalValidationResult(
      isValid: false,
      errorMessage: kStepGoalValidationErrorMessage,
    );
  }

  if (parsed < kMinStepGoal || parsed > kMaxStepGoal) {
    return const StepGoalValidationResult(
      isValid: false,
      errorMessage: kStepGoalValidationErrorMessage,
    );
  }

  return StepGoalValidationResult(isValid: true, parsedGoal: parsed);
}
