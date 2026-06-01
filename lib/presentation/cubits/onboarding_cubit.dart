import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/repositories/user_preferences_repository.dart';
import 'onboarding_state.dart';

typedef PermissionRequester = Future<PermissionStatus> Function(Permission);

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({
    required this.userPreferences,
    PermissionRequester? permissionRequester,
  })  : _requestPermission = permissionRequester ?? _defaultRequestPermission,
        super(const OnboardingState());

  final UserPreferencesRepository userPreferences;
  final PermissionRequester _requestPermission;

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

  void setNotificationOptIn(bool value) {
    emit(state.copyWith(notificationOptIn: value));
  }

  void setGoalInput(String value) {
    emit(state.copyWith(goalInput: value));
  }

  Future<void> requestActivityPermission() async {
    emit(
      state.copyWith(
        activityPermissionStatus: PermissionRequestStatus.requesting,
      ),
    );

    final permission = Platform.isIOS
        ? Permission.sensors
        : Permission.activityRecognition;
    final status = await _requestPermission(permission);

    emit(
      state.copyWith(
        activityPermissionStatus: _mapPermissionStatus(status),
      ),
    );
  }

  Future<void> requestNotificationPermissionIfOptedIn() async {
    if (!state.notificationOptIn) return;

    emit(
      state.copyWith(
        notificationPermissionStatus: PermissionRequestStatus.requesting,
      ),
    );

    final status = await _requestPermission(Permission.notification);

    emit(
      state.copyWith(
        notificationPermissionStatus: _mapPermissionStatus(status),
      ),
    );
  }

  Future<void> completeOnboarding({int? goal}) async {
    final resolvedGoal = goal ?? state.resolvedGoal;
    await userPreferences.setDailyStepGoal(resolvedGoal);
    await userPreferences.setOnboardingComplete(true);
    emit(state.copyWith(status: OnboardingStatus.completed));
  }

  PermissionRequestStatus _mapPermissionStatus(PermissionStatus status) {
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return PermissionRequestStatus.granted;
    }
    return PermissionRequestStatus.denied;
  }
}
