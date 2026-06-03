import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/health/background_health_capability_snapshot.dart';
import 'package:astra_app/core/services/background_health_capability_evaluator.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/my_data_cubit.dart';
import 'package:astra_app/presentation/cubits/my_data_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

class _FixedCapabilityEvaluator extends BackgroundHealthCapabilityEvaluator {
  _FixedCapabilityEvaluator()
    : super(
        activityRecognitionGranted: () async => true,
        notificationGranted: () async => true,
        isAndroidPlatform: () => true,
      );

  @override
  Future<BackgroundHealthCapabilitySnapshot> evaluate() async {
    return const BackgroundHealthCapabilitySnapshot(
      activityRecognitionGranted: true,
      notificationGranted: true,
      batteryOptimizationExempt: true,
      fgsHealthDeclared: true,
      likelyOemBatteryDeferral: false,
    );
  }
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('MyDataCubit daily step goal', () {
    late Database db;
    late UserPreferencesRepository userPreferences;
    late FakeTimeProvider clock;
    late StepRepository stepRepository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userPreferences = UserPreferencesRepository(db);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      stepRepository = StepRepository(db: db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    MyDataCubit buildCubit({PostGoalUpdateCallback? postGoalUpdate}) {
      return MyDataCubit(
        stepRepository: stepRepository,
        userPreferences: userPreferences,
        capabilityEvaluator: _FixedCapabilityEvaluator(),
        clock: clock,
        databasePath: inMemoryDatabasePath,
        activityPermissionGranted: () async => true,
        isIos: false,
        postGoalUpdate: postGoalUpdate,
        shareCsvFile: (_, {sharePositionOrigin}) async {},
      );
    }

    test('refresh loads daily step goal from preferences', () async {
      await userPreferences.setDailyStepGoal(12000);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();

      expect(cubit.state.status, MyDataStatus.ready);
      expect(cubit.state.dailyStepGoal, 12000);
    });

    test('updateDailyStepGoal persists and updates state', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      await cubit.updateDailyStepGoal(15000);

      expect(cubit.state.dailyStepGoal, 15000);
      expect(await userPreferences.getDailyStepGoal(), 15000);
    });

    test('invokes postGoalUpdate on successful update', () async {
      var callbackCalled = false;
      final cubit = buildCubit(
        postGoalUpdate: () async {
          callbackCalled = true;
        },
      );
      addTearDown(cubit.close);

      await cubit.refresh();
      await cubit.updateDailyStepGoal(9000);

      expect(callbackCalled, isTrue);
    });

    test('rejects invalid goal', () async {
      await userPreferences.setDailyStepGoal(8000);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      await cubit.updateDailyStepGoal(999);

      expect(cubit.state.dailyStepGoal, 8000);
      expect(await userPreferences.getDailyStepGoal(), 8000);
    });

    test('no-op when goal unchanged', () async {
      var callbackCalled = false;
      await userPreferences.setDailyStepGoal(8000);
      final cubit = buildCubit(
        postGoalUpdate: () async {
          callbackCalled = true;
        },
      );
      addTearDown(cubit.close);

      await cubit.refresh();
      await cubit.updateDailyStepGoal(8000);

      expect(callbackCalled, isFalse);
    });

    test('blocked while purge in flight', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      cubit.emit(cubit.state.copyWith(isPurging: true));
      await cubit.updateDailyStepGoal(10000);

      expect(cubit.state.dailyStepGoal, isNot(10000));
      expect(await userPreferences.getDailyStepGoal(), isNot(10000));
    });
  });
}
