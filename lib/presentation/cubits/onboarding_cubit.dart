import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/display_unit_preferences.dart';
import '../../core/constants/preference_keys.dart';
import '../../core/permissions/activity_permission_resolver.dart';
import '../../data/contracts/contracts.dart';
import 'onboarding_state.dart';

typedef PermissionRequester = Future<PermissionStatus> Function(Permission);

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({
    required this.userSettings,
    required this.userHealthMetrics,
    PermissionRequester? permissionRequester,
    ActivityPermissionResolver? activityPermissionResolver,
  }) : _requestPermission = permissionRequester ?? _defaultRequestPermission,
       _activityPermissionResolver =
           activityPermissionResolver ?? resolveActivityPermission,
       super(const OnboardingState());

  final UserSettingsRepositoryContract userSettings;
  final UserHealthMetricsRepositoryContract userHealthMetrics;
  final PermissionRequester _requestPermission;
  final ActivityPermissionResolver _activityPermissionResolver;

  static Future<PermissionStatus> _defaultRequestPermission(
    Permission permission,
  ) {
    return permission.request();
  }

  void nextStep() {
    if (state.currentStep >= OnboardingState.totalSteps - 1) return;
    emit(state.copyWith(currentStep: state.currentStep + 1));
  }

  void previousStep() {
    if (state.currentStep <= 0) return;
    emit(state.copyWith(currentStep: state.currentStep - 1));
  }

  void setWeightKg(double kg) {
    emit(state.copyWith(weightKg: kg, weightSkipped: false));
  }

  void setHeightCm(int cm) {
    emit(state.copyWith(heightCm: cm, heightSkipped: false));
  }

  void setWeightDisplayUnit(WeightDisplayUnit unit) {
    emit(state.copyWith(weightDisplayUnit: unit));
  }

  void setHeightUsesInches(bool usesInches) {
    emit(state.copyWith(heightUsesInches: usesInches));
  }

  void skipWeight() {
    emit(state.copyWith(weightSkipped: true, clearWeightKg: true));
    nextStep();
  }

  Future<void> skipHeight() async {
    emit(state.copyWith(heightSkipped: true, clearHeightCm: true));
    await completeWithHeight();
  }

  void commitWeightAndContinue() {
    if (!state.weightSkipped) {
      emit(state.copyWith(weightKg: state.weightKg ?? 70.0));
    }
    nextStep();
  }

  Future<void> completeWithHeight() async {
    final weightToSave = state.weightSkipped ? null : state.weightKg;
    final heightToSave = state.heightSkipped ? null : (state.heightCm ?? 170);

    await userHealthMetrics.setDailyStepGoal(kDefaultStepGoal);
    await userHealthMetrics.setWeightKg(weightToSave);
    await userHealthMetrics.setHeightCm(heightToSave);
    await userSettings.setOnboardingComplete(true);
    emit(state.copyWith(status: OnboardingStatus.completed));
  }

  Future<void> requestActivityPermission() async {
    emit(
      state.copyWith(
        activityPermissionStatus: PermissionRequestStatus.requesting,
      ),
    );

    final permission = _activityPermissionResolver();
    final resolved = await _resolvePermission(permission);

    emit(state.copyWith(activityPermissionStatus: resolved));
  }

  Future<PermissionRequestStatus> _resolvePermission(
    Permission permission,
  ) async {
    try {
      final status = await _requestPermission(permission);
      return _mapPermissionStatus(status);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('OnboardingCubit._resolvePermission failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return PermissionRequestStatus.denied;
    }
  }

  PermissionRequestStatus _mapPermissionStatus(PermissionStatus status) {
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return PermissionRequestStatus.granted;
    }
    return PermissionRequestStatus.denied;
  }
}
