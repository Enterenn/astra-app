import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/preference_keys.dart';
import '../../core/services/notification_service.dart';
import '../../data/repositories/user_preferences_repository.dart';
import 'profile_state.dart';

typedef NotificationPermissionRequester = Future<PermissionStatus> Function(
  Permission permission,
);

typedef PostDisplayNameUpdateCallback = Future<void> Function();

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required this.userPreferences,
    required this.notificationService,
    NotificationPermissionRequester? permissionRequester,
    PostDisplayNameUpdateCallback? postDisplayNameUpdate,
  }) : _requestPermission =
           permissionRequester ??
           ((permission) => permission.request()),
       _postDisplayNameUpdate = postDisplayNameUpdate,
       super(const ProfileState.loading());

  final UserPreferencesRepository userPreferences;
  final NotificationService notificationService;
  final NotificationPermissionRequester _requestPermission;
  final PostDisplayNameUpdateCallback? _postDisplayNameUpdate;

  Future<void>? _refreshInFlight;

  Future<void> refresh() async {
    if (isClosed) {
      return;
    }

    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }

    _refreshInFlight = _refreshImpl();
    try {
      await _refreshInFlight!;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<void> _refreshImpl() async {
    if (state.status != ProfileStatus.ready) {
      emit(const ProfileState.loading());
    }

    try {
      final displayName = await userPreferences.getDisplayName();
      final heightCm = await userPreferences.getHeightCm();
      final weightKg = await userPreferences.getWeightKg();
      final goalNotificationsEnabled =
          await userPreferences.getGoalNotificationsEnabled();

      if (isClosed) {
        return;
      }

      emit(
        ProfileState.ready(
          displayName: displayName,
          heightCm: heightCm,
          weightKg: weightKg,
          goalNotificationsEnabled: goalNotificationsEnabled,
        ),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('ProfileCubit.refresh failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!isClosed) {
        emit(
          ProfileState(
            status: ProfileStatus.error,
            errorMessage: 'Could not load profile settings',
          ),
        );
      }
    }
  }

  Future<bool> updateDisplayName(String name) async {
    if (isClosed || state.status != ProfileStatus.ready) {
      return false;
    }

    final trimmed = name.trim();
    final current = state.displayName?.trim();
    if (trimmed == (current ?? '')) {
      return false;
    }

    try {
      await userPreferences.setDisplayName(trimmed.isEmpty ? null : trimmed);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('ProfileCubit.updateDisplayName failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }

    if (isClosed) {
      return false;
    }

    emit(
      state.copyWith(
        displayName: trimmed.isEmpty ? null : trimmed,
        clearDisplayName: trimmed.isEmpty,
      ),
    );

    try {
      await _postDisplayNameUpdate?.call();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('ProfileCubit postDisplayNameUpdate failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }

    return true;
  }

  Future<bool> updateHeightCm(int? heightCm) async {
    if (isClosed || state.status != ProfileStatus.ready) {
      return false;
    }

    if (heightCm != null &&
        (heightCm < kMinHeightCm || heightCm > kMaxHeightCm)) {
      return false;
    }

    if (heightCm == state.heightCm) {
      return false;
    }

    try {
      await userPreferences.setHeightCm(heightCm);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('ProfileCubit.updateHeightCm failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }

    if (isClosed) {
      return false;
    }

    emit(
      state.copyWith(
        heightCm: heightCm,
        clearHeightCm: heightCm == null,
      ),
    );
    return true;
  }

  Future<bool> updateWeightKg(double? weightKg) async {
    if (isClosed || state.status != ProfileStatus.ready) {
      return false;
    }

    if (weightKg != null &&
        (weightKg < kMinWeightKg || weightKg > kMaxWeightKg)) {
      return false;
    }

    if (weightKg == state.weightKg) {
      return false;
    }

    try {
      await userPreferences.setWeightKg(weightKg);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('ProfileCubit.updateWeightKg failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }

    if (isClosed) {
      return false;
    }

    emit(
      state.copyWith(
        weightKg: weightKg,
        clearWeightKg: weightKg == null,
      ),
    );
    return true;
  }

  Future<bool> setGoalNotificationsEnabled(bool enabled) async {
    if (isClosed || state.status != ProfileStatus.ready) {
      return false;
    }

    if (enabled == state.goalNotificationsEnabled) {
      return false;
    }

    if (enabled) {
      final granted = await notificationService.hasNotificationPermission();
      if (!granted) {
        try {
          await _requestPermission(Permission.notification);
        } catch (error, stackTrace) {
          if (kDebugMode) {
            debugPrint(
              'ProfileCubit notification permission request failed: $error',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
        }
      }
    }

    try {
      await userPreferences.setGoalNotificationsEnabled(enabled);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('ProfileCubit.setGoalNotificationsEnabled failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }

    if (isClosed) {
      return false;
    }

    emit(state.copyWith(goalNotificationsEnabled: enabled));
    return true;
  }
}
