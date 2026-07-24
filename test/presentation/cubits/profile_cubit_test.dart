@Tags(['slow'])
library;

import 'dart:io';

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/database/astra_database_session.dart';
import 'package:astra_app/core/services/notification_service.dart';
import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:astra_app/presentation/cubits/profile_cubit.dart';
import 'package:astra_app/presentation/cubits/profile_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';

import '../../helpers/sqflite_test_helper.dart';

class _ThrowingDisplayNameHealthMetrics extends UserHealthMetricsRepository {
  _ThrowingDisplayNameHealthMetrics(super.db);

  @override
  Future<String?> getDisplayName() async {
    throw StateError('read failed');
  }
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('ProfileCubit', () {
    late Database db;
    late UserSettingsRepository userSettings;
    late UserHealthMetricsRepository userHealthMetrics;
    late NotificationService notificationService;
    var permissionRequestCount = 0;

    // Simulates OS permission: starts denied, flips to granted after request.
    var permissionGrantedByOs = false;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userSettings = UserSettingsRepository(db);
      userHealthMetrics = UserHealthMetricsRepository(db);
      permissionRequestCount = 0;
      permissionGrantedByOs = false;
      notificationService = NotificationService(
        permissionChecker: () async =>
            permissionGrantedByOs ? PermissionStatus.granted : PermissionStatus.denied,
      );
    });

    tearDown(() async {
      await db.close();
    });

    ProfileCubit buildCubit({
      PostDisplayNameUpdateCallback? postDisplayNameUpdate,
    }) {
      return ProfileCubit(
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        notificationService: notificationService,
        permissionRequester: (permission) async {
          permissionRequestCount++;
          permissionGrantedByOs = true;
          return PermissionStatus.granted;
        },
        postDisplayNameUpdate: postDisplayNameUpdate,
      );
    }

    test('refresh loads persisted profile fields', () async {
      await userHealthMetrics.setDisplayName('Alex');
      await userHealthMetrics.setHeightCm(180);
      await userHealthMetrics.setWeightKg(75.0);
      await userSettings.setGoalNotificationsEnabled(true);

      final cubit = buildCubit();
      await cubit.refresh();

      expect(cubit.state.status, ProfileStatus.ready);
      expect(cubit.state.displayName, 'Alex');
      expect(cubit.state.heightCm, 180);
      expect(cubit.state.weightKg, 75.0);
      expect(cubit.state.goalNotificationsEnabled, isTrue);

      await cubit.close();
    });

    test('refresh recovers when the database connection was closed', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'astra_profile_recovery_',
      );

      final databasePath = p.join(tempDir.path, 'test.db');
      final fileDb = await openAstraDatabase(databasePath: databasePath);
      final session = AstraDatabaseSession(
        databasePath: databasePath,
        initial: fileDb,
      );
      final settings = UserSettingsRepository(session);
      final health = UserHealthMetricsRepository(session);
      addTearDown(() async {
        if (session.database.isOpen) {
          await session.database.close();
        }
        await tempDir.delete(recursive: true);
      });
      await health.setDisplayName('Jordan');
      await session.database.close();

      final cubit = ProfileCubit(
        userSettings: settings,
        userHealthMetrics: health,
        notificationService: notificationService,
        permissionRequester: (permission) async {
          permissionRequestCount++;
          return PermissionStatus.granted;
        },
      );
      await cubit.refresh();

      expect(cubit.state.status, ProfileStatus.ready);
      expect(cubit.state.displayName, 'Jordan');

      await cubit.close();
    });

    test('updateDisplayName persists and calls post hook', () async {
      var hookCount = 0;
      final cubit = buildCubit(
        postDisplayNameUpdate: () async {
          hookCount++;
        },
      );
      await cubit.refresh();

      final saved = await cubit.updateDisplayName('Sam');
      expect(saved, isTrue);
      expect(await userHealthMetrics.getDisplayName(), 'Sam');
      expect(cubit.state.displayName, 'Sam');
      expect(hookCount, 1);

      await cubit.close();
    });

    test('updateHeightCm rejects out-of-range values', () async {
      final cubit = buildCubit();
      await cubit.refresh();

      expect(await cubit.updateHeightCm(99), isFalse);
      expect(await cubit.updateHeightCm(251), isFalse);
      expect(await cubit.updateHeightCm(175), isTrue);
      expect(await userHealthMetrics.getHeightCm(), 175);

      await cubit.close();
    });

    test('updateWeightKg persists one-decimal weight', () async {
      final cubit = buildCubit();
      await cubit.refresh();

      expect(await cubit.updateWeightKg(72.5), isTrue);
      expect(await userHealthMetrics.getWeightKg(), 72.5);

      await cubit.close();
    });

    test('updateWeightKg rejects out-of-range values', () async {
      final cubit = buildCubit();
      await cubit.refresh();

      expect(await cubit.updateWeightKg(29), isFalse);
      expect(await cubit.updateWeightKg(301), isFalse);

      await cubit.close();
    });

    test('bootstraps goal notification pref before refresh completes', () async {
      await userSettings.setGoalNotificationsEnabled(true);

      final cubit = buildCubit();
      await cubit.stream.firstWhere((state) => state.goalNotificationsEnabled);

      expect(cubit.state.status, ProfileStatus.loading);
      expect(cubit.state.goalNotificationsEnabled, isTrue);

      await cubit.close();
    });

    test('setGoalNotificationsEnabled persists during loading state', () async {
      permissionGrantedByOs = true;
      final cubit = buildCubit();

      final saved = await cubit.setGoalNotificationsEnabled(true);

      expect(saved, NotificationToggleResult.success);
      expect(cubit.state.status, ProfileStatus.loading);
      expect(cubit.state.goalNotificationsEnabled, isTrue);
      expect(await userSettings.getGoalNotificationsEnabled(), isTrue);

      await cubit.close();
    });

    test('refresh preserves goalNotificationsEnabled on loading transition', () async {
      await userSettings.setGoalNotificationsEnabled(true);
      final cubit = buildCubit();
      await cubit.stream.firstWhere((state) => state.goalNotificationsEnabled);

      final refreshFuture = cubit.refresh();
      expect(cubit.state.goalNotificationsEnabled, isTrue);

      await refreshFuture;
      expect(cubit.state.goalNotificationsEnabled, isTrue);

      await cubit.close();
    });

    test('refresh error preserves goalNotificationsEnabled', () async {
      await userSettings.setGoalNotificationsEnabled(true);
      final cubit = ProfileCubit(
        userSettings: userSettings,
        userHealthMetrics: _ThrowingDisplayNameHealthMetrics(db),
        notificationService: notificationService,
      );
      if (!cubit.state.goalNotificationsEnabled) {
        await cubit.stream.firstWhere((state) => state.goalNotificationsEnabled);
      }
      await cubit.refresh();

      expect(cubit.state.status, ProfileStatus.error);
      expect(cubit.state.goalNotificationsEnabled, isTrue);

      await cubit.close();
    });

    test('setGoalNotificationsEnabled syncs stale switch without error when already enabled', () async {
      await userSettings.setGoalNotificationsEnabled(true);
      final cubit = buildCubit();

      final saved = await cubit.setGoalNotificationsEnabled(true);

      expect(saved, NotificationToggleResult.success);
      expect(cubit.state.goalNotificationsEnabled, isTrue);

      await cubit.close();
    });

    test('enabling goal notifications requests permission when denied', () async {
      final cubit = buildCubit();
      await cubit.refresh();

      final saved = await cubit.setGoalNotificationsEnabled(true);

      expect(saved, NotificationToggleResult.success);
      expect(permissionRequestCount, 1);
      expect(await userSettings.getGoalNotificationsEnabled(), isTrue);
      expect(cubit.state.goalNotificationsEnabled, isTrue);

      await cubit.close();
    });

    test('does not re-request OS permission when already granted', () async {
      final cubit = buildCubit();
      await cubit.refresh();

      // First enable: permission denied → triggers request → granted.
      expect(await cubit.setGoalNotificationsEnabled(true), NotificationToggleResult.success);
      expect(permissionRequestCount, 1);

      expect(await cubit.setGoalNotificationsEnabled(false), NotificationToggleResult.success);
      expect(permissionRequestCount, 1);

      // Second enable: permission already granted → no new request.
      expect(await cubit.setGoalNotificationsEnabled(true), NotificationToggleResult.success);
      expect(permissionRequestCount, 1);

      await cubit.close();
    });

    test('enabling goal notifications returns deniedReversible when permission denied', () async {
      final cubit = ProfileCubit(
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.denied,
        ),
        permissionRequester: (permission) async {
          permissionRequestCount++;
          return PermissionStatus.denied;
        },
      );
      await cubit.refresh();

      final saved = await cubit.setGoalNotificationsEnabled(true);

      expect(saved, NotificationToggleResult.deniedReversible);
      expect(permissionRequestCount, 1);
      expect(await userSettings.getGoalNotificationsEnabled(), isFalse);
      expect(cubit.state.goalNotificationsEnabled, isFalse);

      await cubit.close();
    });

    test('enabling goal notifications returns deniedPermanent when permanently denied', () async {
      final cubit = ProfileCubit(
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.permanentlyDenied,
        ),
        permissionRequester: (permission) async {
          permissionRequestCount++;
          return PermissionStatus.permanentlyDenied;
        },
      );
      await cubit.refresh();

      final saved = await cubit.setGoalNotificationsEnabled(true);

      expect(saved, NotificationToggleResult.deniedPermanent);
      expect(permissionRequestCount, 1);
      expect(await userSettings.getGoalNotificationsEnabled(), isFalse);
      expect(cubit.state.goalNotificationsEnabled, isFalse);

      await cubit.close();
    });

    test('disabling goal notifications does not request permission', () async {
      await userSettings.setGoalNotificationsEnabled(true);
      final cubit = buildCubit();
      await cubit.refresh();

      final saved = await cubit.setGoalNotificationsEnabled(false);

      expect(saved, NotificationToggleResult.success);
      expect(permissionRequestCount, 0);
      expect(await userSettings.getGoalNotificationsEnabled(), isFalse);

      await cubit.close();
    });
  });
}
