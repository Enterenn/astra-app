import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/preferences/goal_notification_migration.dart';
import 'package:astra_app/core/services/notification_service.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('migrateGoalNotificationPreferenceIfNeeded', () {
    late Database db;
    late UserPreferencesRepository repository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      repository = UserPreferencesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('enables notifications when OS permission granted and key unset', () async {
      final notifications = NotificationService(
        permissionChecker: () async => PermissionStatus.granted,
      );

      await migrateGoalNotificationPreferenceIfNeeded(
        userPreferences: repository,
        notificationService: notifications,
      );

      expect(await repository.getGoalNotificationsEnabled(), isTrue);
    });

    test('does not enable when OS permission denied and key unset', () async {
      final notifications = NotificationService(
        permissionChecker: () async => PermissionStatus.denied,
      );

      await migrateGoalNotificationPreferenceIfNeeded(
        userPreferences: repository,
        notificationService: notifications,
      );

      expect(await repository.getGoalNotificationsEnabled(), isFalse);
      expect(await repository.isGoalNotificationsPreferenceSet(), isFalse);
    });

    test('does not override explicit opt-out', () async {
      await repository.setGoalNotificationsEnabled(false);
      final notifications = NotificationService(
        permissionChecker: () async => PermissionStatus.granted,
      );

      await migrateGoalNotificationPreferenceIfNeeded(
        userPreferences: repository,
        notificationService: notifications,
      );

      expect(await repository.getGoalNotificationsEnabled(), isFalse);
    });
  });
}
