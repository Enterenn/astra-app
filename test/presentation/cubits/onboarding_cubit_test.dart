import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/onboarding_cubit.dart';
import 'package:astra_app/presentation/cubits/onboarding_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('OnboardingCubit', () {
    late Database db;
    late UserPreferencesRepository repository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      repository = UserPreferencesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('starts on trust step with default goal input', () {
      final cubit = OnboardingCubit(userPreferences: repository);

      expect(cubit.state.currentStep, 0);
      expect(cubit.state.goalInput, '8000');
      expect(cubit.state.isGoalValid, isTrue);

      cubit.close();
    });

    test('nextStep and previousStep respect boundaries', () {
      final cubit = OnboardingCubit(userPreferences: repository);

      cubit.nextStep();
      expect(cubit.state.currentStep, 1);

      cubit.previousStep();
      expect(cubit.state.currentStep, 0);

      cubit.previousStep();
      expect(cubit.state.currentStep, 0);

      cubit.nextStep();
      cubit.nextStep();
      cubit.nextStep();
      expect(cubit.state.currentStep, 2);

      cubit.close();
    });

    test('completeOnboarding persists goal and completion flag', () async {
      final cubit = OnboardingCubit(userPreferences: repository);

      await cubit.completeOnboarding(goal: 12000);

      expect(cubit.state.status, OnboardingStatus.completed);
      expect(await repository.getDailyStepGoal(), 12000);
      expect(await repository.getOnboardingComplete(), isTrue);

      cubit.close();
    });

    test('skip goal path persists default 8000', () async {
      final cubit = OnboardingCubit(userPreferences: repository);

      await cubit.completeOnboarding(goal: kDefaultStepGoal);

      expect(await repository.getDailyStepGoal(), kDefaultStepGoal);
      expect(await repository.getOnboardingComplete(), isTrue);

      cubit.close();
    });

    test('requestActivityPermission uses injected requester', () async {
      Permission? requestedPermission;
      final cubit = OnboardingCubit(
        userPreferences: repository,
        permissionRequester: (permission) async {
          requestedPermission = permission;
          return PermissionStatus.granted;
        },
      );

      await cubit.requestActivityPermission();

      expect(requestedPermission, isNotNull);
      expect(
        cubit.state.activityPermissionStatus,
        PermissionRequestStatus.granted,
      );

      cubit.close();
    });

    test('requestNotificationPermissionIfOptedIn skips when toggle off', () async {
      var requestCount = 0;
      final cubit = OnboardingCubit(
        userPreferences: repository,
        permissionRequester: (_) async {
          requestCount++;
          return PermissionStatus.granted;
        },
      );

      await cubit.requestNotificationPermissionIfOptedIn();

      expect(requestCount, 0);

      cubit.close();
    });

    test('requestNotificationPermissionIfOptedIn requests when toggle on', () async {
      Permission? requestedPermission;
      final cubit = OnboardingCubit(
        userPreferences: repository,
        permissionRequester: (permission) async {
          requestedPermission = permission;
          return PermissionStatus.granted;
        },
      )..setNotificationOptIn(true);

      await cubit.requestNotificationPermissionIfOptedIn();

      expect(requestedPermission, Permission.notification);
      expect(
        cubit.state.notificationPermissionStatus,
        PermissionRequestStatus.granted,
      );

      cubit.close();
    });

    test('invalid goal input disables isGoalValid', () {
      final cubit = OnboardingCubit(userPreferences: repository)
        ..setGoalInput('999');

      expect(cubit.state.isGoalValid, isFalse);
      expect(cubit.state.resolvedGoal, kDefaultStepGoal);

      cubit.close();
    });
  });
}
