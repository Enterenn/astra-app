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

    test('starts on intro step', () {
      final cubit = OnboardingCubit(userPreferences: repository);

      expect(cubit.state.currentStep, 0);
      expect(cubit.state.status, OnboardingStatus.inProgress);

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
      expect(cubit.state.currentStep, 2);

      cubit.nextStep();
      expect(cubit.state.currentStep, 2);

      cubit.close();
    });

    test('requestActivityPermission uses injected requester', () async {
      Permission? requestedPermission;
      final cubit = OnboardingCubit(
        userPreferences: repository,
        activityPermissionResolver: () => Permission.activityRecognition,
        permissionRequester: (permission) async {
          requestedPermission = permission;
          return PermissionStatus.granted;
        },
      );

      await cubit.requestActivityPermission();

      expect(requestedPermission, isNotNull);
      expect(requestedPermission, Permission.activityRecognition);
      expect(
        cubit.state.activityPermissionStatus,
        PermissionRequestStatus.granted,
      );

      cubit.close();
    });

    test('requestActivityPermission uses injected platform resolver', () async {
      Permission? requestedPermission;
      final cubit = OnboardingCubit(
        userPreferences: repository,
        activityPermissionResolver: () => Permission.sensors,
        permissionRequester: (permission) async {
          requestedPermission = permission;
          return PermissionStatus.granted;
        },
      );

      await cubit.requestActivityPermission();

      expect(requestedPermission, Permission.sensors);
      expect(
        cubit.state.activityPermissionStatus,
        PermissionRequestStatus.granted,
      );

      cubit.close();
    });

    test('requestActivityPermission maps denied platform status', () async {
      final cubit = OnboardingCubit(
        userPreferences: repository,
        permissionRequester: (_) async => PermissionStatus.denied,
      );

      await cubit.requestActivityPermission();

      expect(
        cubit.state.activityPermissionStatus,
        PermissionRequestStatus.denied,
      );

      cubit.close();
    });

    test('requestActivityPermission recovers when requester throws', () async {
      final cubit = OnboardingCubit(
        userPreferences: repository,
        permissionRequester: (_) async {
          throw Exception('platform channel failure');
        },
      );

      await cubit.requestActivityPermission();

      expect(
        cubit.state.activityPermissionStatus,
        PermissionRequestStatus.denied,
      );

      cubit.close();
    });

    test('completeWithHeight persists default metrics and completion flag',
        () async {
      final cubit = OnboardingCubit(userPreferences: repository)
        ..commitWeightAndContinue();

      await cubit.completeWithHeight();

      expect(cubit.state.status, OnboardingStatus.completed);
      expect(await repository.getDailyStepGoal(), kDefaultStepGoal);
      expect(await repository.getWeightKg(), 70.0);
      expect(await repository.getHeightCm(), 170);
      expect(await repository.getOnboardingComplete(), isTrue);

      cubit.close();
    });

    test('skipWeight leaves null weight after completeWithHeight', () async {
      final cubit = OnboardingCubit(userPreferences: repository)
        ..skipWeight();

      await cubit.completeWithHeight();

      expect(await repository.getWeightKg(), isNull);
      expect(await repository.getHeightCm(), 170);

      cubit.close();
    });

    test('skipHeight leaves null height after completeWithHeight', () async {
      final cubit = OnboardingCubit(userPreferences: repository);
      cubit.commitWeightAndContinue();
      await cubit.skipHeight();

      expect(await repository.getWeightKg(), 70.0);
      expect(await repository.getHeightCm(), isNull);
      expect(await repository.getOnboardingComplete(), isTrue);

      cubit.close();
    });
  });
}
