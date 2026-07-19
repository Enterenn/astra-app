import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/preference_keys.dart';
import '../../core/services/notification_service.dart';
import '../../data/contracts/contracts.dart';
import 'profile_errors.dart';
import 'profile_state.dart';

typedef NotificationPermissionRequester = Future<PermissionStatus> Function(
  Permission permission,
);

typedef PostDisplayNameUpdateCallback = Future<void> Function();

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required this.userSettings,
    required this.userHealthMetrics,
    required this.notificationService,
    NotificationPermissionRequester? permissionRequester,
    this._postDisplayNameUpdate,
  }) : _requestPermission =
           permissionRequester ??
           ((permission) => permission.request()),
       super(const ProfileState.loading()) {
    unawaited(_bootstrapNotificationPref());
  }

  final UserSettingsRepositoryContract userSettings;
  final UserHealthMetricsRepositoryContract userHealthMetrics;
  final NotificationService notificationService;
  final NotificationPermissionRequester _requestPermission;
  final PostDisplayNameUpdateCallback? _postDisplayNameUpdate;

  Future<void>? _refreshInFlight;

  Future<void> _bootstrapNotificationPref() async {
    try {
      final enabled = await userSettings.getGoalNotificationsEnabled();
      if (isClosed || state.status == ProfileStatus.ready) {
        return;
      }
      emit(state.copyWith(goalNotificationsEnabled: enabled));
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('ProfileCubit._bootstrapNotificationPref failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

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
      emit(state.copyWith(status: ProfileStatus.loading));
    }

    try {
      final displayName = await userHealthMetrics.getDisplayName();
      final heightCm = await userHealthMetrics.getHeightCm();
      final weightKg = await userHealthMetrics.getWeightKg();
      final goalNotificationsEnabled =
          await userSettings.getGoalNotificationsEnabled();

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
          state.copyWith(
            status: ProfileStatus.error,
            loadError: ProfileLoadError.generic,
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
      await userHealthMetrics.setDisplayName(trimmed.isEmpty ? null : trimmed);
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
      await userHealthMetrics.setHeightCm(heightCm);
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
      await userHealthMetrics.setWeightKg(weightKg);
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
    if (isClosed) {
      return false;
    }
    if (state.status != ProfileStatus.ready &&
        state.status != ProfileStatus.loading &&
        state.status != ProfileStatus.error) {
      return false;
    }

    final currentEnabled = state.status == ProfileStatus.ready
        ? state.goalNotificationsEnabled
        : await userSettings.getGoalNotificationsEnabled();
    if (enabled == currentEnabled) {
      if (state.goalNotificationsEnabled != enabled) {
        emit(state.copyWith(goalNotificationsEnabled: enabled));
      }
      return true;
    }

    if (enabled && !await notificationService.hasNotificationPermission()) {
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
      if (!await notificationService.hasNotificationPermission()) {
        return false;
      }
    }

    if (isClosed) {
      return false;
    }

    try {
      await userSettings.setGoalNotificationsEnabled(enabled);
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
