import 'package:astra_app/core/constants/preference_keys.dart';
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
  _FixedCapabilityEvaluator({this.evaluateDelay = Duration.zero})
    : super(
        activityRecognitionGranted: () async => true,
        notificationGranted: () async => true,
        isAndroidPlatform: () => true,
      );

  final Duration evaluateDelay;

  @override
  Future<BackgroundHealthCapabilitySnapshot> evaluate() async {
    if (evaluateDelay > Duration.zero) {
      await Future<void>.delayed(evaluateDelay);
    }
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

    MyDataCubit buildCubit({
      PostGoalUpdateCallback? postGoalUpdate,
      BackgroundHealthCapabilityEvaluator? capabilityEvaluator,
    }) {
      return MyDataCubit(
        stepRepository: stepRepository,
        userPreferences: userPreferences,
        capabilityEvaluator:
            capabilityEvaluator ?? _FixedCapabilityEvaluator(),
        clock: clock,
        databasePath: inMemoryDatabasePath,
        activityPermissionGranted: () async => true,
        isIos: false,
        postGoalUpdate: postGoalUpdate,
        shareCsvFile: (_, {sharePositionOrigin}) async {},
      );
    }

    test('refresh keeps dailyStepGoal from cubit state not preferences', () async {
      await userPreferences.setDailyStepGoal(12000);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();

      expect(cubit.state.status, MyDataStatus.ready);
      expect(cubit.state.dailyStepGoal, kDefaultStepGoal);

      expect(await cubit.updateDailyStepGoal(12000), isTrue);
      await cubit.refresh(silent: true);

      expect(cubit.state.dailyStepGoal, 12000);
      expect(await userPreferences.getDailyStepGoal(), 12000);
    });

    test('updateDailyStepGoal persists and updates state', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      expect(await cubit.updateDailyStepGoal(15000), isTrue);

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
      expect(await cubit.updateDailyStepGoal(9000), isTrue);

      expect(callbackCalled, isTrue);
    });

    test('rejects invalid goal', () async {
      await userPreferences.setDailyStepGoal(8000);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      expect(await cubit.updateDailyStepGoal(999), isFalse);

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
      expect(await cubit.updateDailyStepGoal(8000), isFalse);

      expect(callbackCalled, isFalse);
    });

    test('returns false when postGoalUpdate throws', () async {
      final cubit = buildCubit(
        postGoalUpdate: () async {
          throw StateError('refresh failed');
        },
      );
      addTearDown(cubit.close);

      await cubit.refresh();
      expect(await cubit.updateDailyStepGoal(12000), isFalse);

      expect(cubit.state.dailyStepGoal, 12000);
      expect(await userPreferences.getDailyStepGoal(), 12000);
    });

    test('blocked while purge in flight', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      cubit.emit(cubit.state.copyWith(isPurging: true));
      expect(await cubit.updateDailyStepGoal(10000), isFalse);

      expect(cubit.state.dailyStepGoal, isNot(10000));
      expect(await userPreferences.getDailyStepGoal(), isNot(10000));
    });

    test('blocked while export in flight', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      cubit.emit(cubit.state.copyWith(isExporting: true));
      expect(await cubit.updateDailyStepGoal(10000), isFalse);

      expect(await userPreferences.getDailyStepGoal(), isNot(10000));
    });

    test('blocked while import in flight', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      cubit.emit(cubit.state.copyWith(isImporting: true));
      expect(await cubit.updateDailyStepGoal(10000), isFalse);

      expect(await userPreferences.getDailyStepGoal(), isNot(10000));
    });

    test('refresh completing after goal save keeps new dailyStepGoal', () async {
      final cubit = buildCubit(
        capabilityEvaluator: _FixedCapabilityEvaluator(
          evaluateDelay: const Duration(milliseconds: 80),
        ),
      );
      addTearDown(cubit.close);

      await cubit.refresh();
      final refreshFuture = cubit.refresh(silent: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await cubit.updateDailyStepGoal(15000), isTrue);
      await refreshFuture;

      expect(cubit.state.dailyStepGoal, 15000);
      expect(await userPreferences.getDailyStepGoal(), 15000);
    });
  });
}
