import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/notification_service.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/profile_cubit.dart';
import 'package:astra_app/presentation/cubits/profile_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';

import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('ProfileCubit', () {
    late Database db;
    late UserPreferencesRepository userPreferences;
    late NotificationService notificationService;
    var permissionRequestCount = 0;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userPreferences = UserPreferencesRepository(db);
      permissionRequestCount = 0;
      notificationService = NotificationService(
        permissionChecker: () async => PermissionStatus.denied,
      );
    });

    tearDown(() async {
      await db.close();
    });

    ProfileCubit buildCubit({
      PostDisplayNameUpdateCallback? postDisplayNameUpdate,
    }) {
      return ProfileCubit(
        userPreferences: userPreferences,
        notificationService: notificationService,
        permissionRequester: (permission) async {
          permissionRequestCount++;
          return PermissionStatus.granted;
        },
        postDisplayNameUpdate: postDisplayNameUpdate,
      );
    }

    test('refresh loads persisted profile fields', () async {
      await userPreferences.setDisplayName('Alex');
      await userPreferences.setHeightCm(180);
      await userPreferences.setWeightKg(75.0);
      await userPreferences.setGoalNotificationsEnabled(true);

      final cubit = buildCubit();
      await cubit.refresh();

      expect(cubit.state.status, ProfileStatus.ready);
      expect(cubit.state.displayName, 'Alex');
      expect(cubit.state.heightCm, 180);
      expect(cubit.state.weightKg, 75.0);
      expect(cubit.state.goalNotificationsEnabled, isTrue);

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
      expect(await userPreferences.getDisplayName(), 'Sam');
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
      expect(await userPreferences.getHeightCm(), 175);

      await cubit.close();
    });

    test('updateWeightKg persists one-decimal weight', () async {
      final cubit = buildCubit();
      await cubit.refresh();

      expect(await cubit.updateWeightKg(72.5), isTrue);
      expect(await userPreferences.getWeightKg(), 72.5);

      await cubit.close();
    });

    test('updateWeightKg rejects out-of-range values', () async {
      final cubit = buildCubit();
      await cubit.refresh();

      expect(await cubit.updateWeightKg(29), isFalse);
      expect(await cubit.updateWeightKg(301), isFalse);

      await cubit.close();
    });

    test('enabling goal notifications requests permission when denied', () async {
      final cubit = buildCubit();
      await cubit.refresh();

      final saved = await cubit.setGoalNotificationsEnabled(true);

      expect(saved, isTrue);
      expect(permissionRequestCount, 1);
      expect(await userPreferences.getGoalNotificationsEnabled(), isTrue);
      expect(cubit.state.goalNotificationsEnabled, isTrue);

      await cubit.close();
    });

    test('disabling goal notifications does not request permission', () async {
      await userPreferences.setGoalNotificationsEnabled(true);
      final cubit = buildCubit();
      await cubit.refresh();

      final saved = await cubit.setGoalNotificationsEnabled(false);

      expect(saved, isTrue);
      expect(permissionRequestCount, 0);
      expect(await userPreferences.getGoalNotificationsEnabled(), isFalse);

      await cubit.close();
    });
  });
}
