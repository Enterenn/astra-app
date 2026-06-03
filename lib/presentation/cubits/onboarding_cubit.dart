import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/permissions/activity_permission_resolver.dart';
import '../../data/repositories/user_preferences_repository.dart';
import 'onboarding_state.dart';

typedef PermissionRequester = Future<PermissionStatus> Function(Permission);

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({
    required this.userPreferences,
    PermissionRequester? permissionRequester,
    ActivityPermissionResolver? activityPermissionResolver,
  }) : _requestPermission = permissionRequester ?? _defaultRequestPermission,
       _activityPermissionResolver =
           activityPermissionResolver ?? resolveActivityPermission,
       super(const OnboardingState());

  final UserPreferencesRepository userPreferences;
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

    final permission = _activityPermissionResolver();
    final resolved = await _resolvePermission(permission);

    emit(state.copyWith(activityPermissionStatus: resolved));
  }

  Future<void> requestNotificationPermissionIfOptedIn() async {
    if (!state.notificationOptIn) return;

    emit(
      state.copyWith(
        notificationPermissionStatus: PermissionRequestStatus.requesting,
      ),
    );

    final resolved = await _resolvePermission(Permission.notification);

    emit(state.copyWith(notificationPermissionStatus: resolved));
  }

  Future<PermissionRequestStatus> _resolvePermission(
    Permission permission,
  ) async {
    try {
      final status = await _requestPermission(permission);
      return _mapPermissionStatus(status);
    } catch (_) {
      return PermissionRequestStatus.denied;
    }
  }

  Future<void> completeOnboarding({int? goal, String? displayName}) async {
    final resolvedGoal = goal ?? state.resolvedGoal;
    await userPreferences.setDailyStepGoal(resolvedGoal);
    await userPreferences.setDisplayName(displayName);
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
