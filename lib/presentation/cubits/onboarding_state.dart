enum OnboardingStatus { inProgress, completed }

enum PermissionRequestStatus { idle, requesting, granted, denied }

class OnboardingState {
  const OnboardingState({
    this.currentStep = 0,
    this.notificationOptIn = false,
    this.goalInput = '8000',
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

  static const int totalSteps = 3;

  bool get isGoalValid {
    final parsed = int.tryParse(goalInput.trim());
    if (parsed == null) return false;
    return parsed >= 1000 && parsed <= 100000;
  }

  int get resolvedGoal {
    if (isGoalValid) {
      return int.parse(goalInput.trim());
    }
    return 8000;
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
