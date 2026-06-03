import '../../core/constants/preference_keys.dart';
import '../../core/validation/step_goal_validator.dart';

enum OnboardingStatus { inProgress, completed }

enum PermissionRequestStatus { idle, requesting, granted, denied }

class OnboardingState {
  const OnboardingState({
    this.currentStep = 0,
    this.notificationOptIn = false,
    this.goalInput = '$kDefaultStepGoal',
    this.status = OnboardingStatus.inProgress,
    this.activityPermissionStatus = PermissionRequestStatus.idle,
    this.notificationPermissionStatus = PermissionRequestStatus.idle,
  });

  final int currentStep;
  final bool notificationOptIn;
  final String goalInput;
  final OnboardingStatus status;
  final PermissionRequestStatus activityPermissionStatus;
  final PermissionRequestStatus notificationPermissionStatus;

  static const int totalSteps = 4;

  bool get isGoalValid => validateStepGoalInput(goalInput).isValid;

  int get resolvedGoal {
    final result = validateStepGoalInput(goalInput);
    if (result.isValid && result.parsedGoal != null) {
      return result.parsedGoal!;
    }
    return kDefaultStepGoal;
  }

  OnboardingState copyWith({
    int? currentStep,
    bool? notificationOptIn,
    String? goalInput,
    OnboardingStatus? status,
    PermissionRequestStatus? activityPermissionStatus,
    PermissionRequestStatus? notificationPermissionStatus,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      notificationOptIn: notificationOptIn ?? this.notificationOptIn,
      goalInput: goalInput ?? this.goalInput,
      status: status ?? this.status,
      activityPermissionStatus:
          activityPermissionStatus ?? this.activityPermissionStatus,
      notificationPermissionStatus:
          notificationPermissionStatus ?? this.notificationPermissionStatus,
    );
  }
}
