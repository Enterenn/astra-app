import '../../core/constants/display_unit_preferences.dart';
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
    this.weightKg,
    this.heightCm,
    this.weightSkipped = false,
    this.heightSkipped = false,
    this.weightDisplayUnit = WeightDisplayUnit.kg,
    this.heightUsesInches = false,
  });

  final int currentStep;
  final bool notificationOptIn;
  final String goalInput;
  final OnboardingStatus status;
  final PermissionRequestStatus activityPermissionStatus;
  final PermissionRequestStatus notificationPermissionStatus;
  final double? weightKg;
  final int? heightCm;
  final bool weightSkipped;
  final bool heightSkipped;
  final WeightDisplayUnit weightDisplayUnit;
  final bool heightUsesInches;

  static const int totalSteps = 3;

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
    double? weightKg,
    int? heightCm,
    bool? weightSkipped,
    bool? heightSkipped,
    WeightDisplayUnit? weightDisplayUnit,
    bool? heightUsesInches,
    bool clearWeightKg = false,
    bool clearHeightCm = false,
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
      weightKg: clearWeightKg ? null : (weightKg ?? this.weightKg),
      heightCm: clearHeightCm ? null : (heightCm ?? this.heightCm),
      weightSkipped: weightSkipped ?? this.weightSkipped,
      heightSkipped: heightSkipped ?? this.heightSkipped,
      weightDisplayUnit: weightDisplayUnit ?? this.weightDisplayUnit,
      heightUsesInches: heightUsesInches ?? this.heightUsesInches,
    );
  }
}
