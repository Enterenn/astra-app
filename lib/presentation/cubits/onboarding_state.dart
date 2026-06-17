import '../../core/constants/display_unit_preferences.dart';

enum OnboardingStatus { inProgress, completed }

enum PermissionRequestStatus { idle, requesting, granted, denied }

class OnboardingState {
  const OnboardingState({
    this.currentStep = 0,
    this.status = OnboardingStatus.inProgress,
    this.activityPermissionStatus = PermissionRequestStatus.idle,
    this.weightKg,
    this.heightCm,
    this.weightSkipped = false,
    this.heightSkipped = false,
    this.weightDisplayUnit = WeightDisplayUnit.kg,
    this.heightUsesInches = false,
  });

  final int currentStep;
  final OnboardingStatus status;
  final PermissionRequestStatus activityPermissionStatus;
  final double? weightKg;
  final int? heightCm;
  final bool weightSkipped;
  final bool heightSkipped;
  final WeightDisplayUnit weightDisplayUnit;
  final bool heightUsesInches;

  static const int totalSteps = 3;

  OnboardingState copyWith({
    int? currentStep,
    OnboardingStatus? status,
    PermissionRequestStatus? activityPermissionStatus,
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
      status: status ?? this.status,
      activityPermissionStatus:
          activityPermissionStatus ?? this.activityPermissionStatus,
      weightKg: clearWeightKg ? null : (weightKg ?? this.weightKg),
      heightCm: clearHeightCm ? null : (heightCm ?? this.heightCm),
      weightSkipped: weightSkipped ?? this.weightSkipped,
      heightSkipped: heightSkipped ?? this.heightSkipped,
      weightDisplayUnit: weightDisplayUnit ?? this.weightDisplayUnit,
      heightUsesInches: heightUsesInches ?? this.heightUsesInches,
    );
  }
}
