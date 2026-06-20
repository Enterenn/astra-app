import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/database/app_database.dart';

import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:astra_app/presentation/cubits/my_data_cubit.dart';
import 'package:astra_app/presentation/cubits/my_data_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';
import '../../helpers/step_test_fixtures.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('MyDataCubit daily step goal', () {
    late Database db;
    late UserSettingsRepository userSettings;
    late UserHealthMetricsRepository userHealthMetrics;
    late FakeTimeProvider clock;
    late StepTestRepos stepRepos;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userSettings = UserSettingsRepository(db);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      userHealthMetrics = UserHealthMetricsRepository(db, clock: clock);
      stepRepos = StepTestFixtures.create(db: db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    MyDataCubit buildCubit({
      PostGoalUpdateCallback? postGoalUpdate,
    }) {
      return MyDataCubit(
        stepAggregation: stepRepos.aggregation,
        csvService: stepRepos.csv,
        stepIngestion: stepRepos.ingestion,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        clock: clock,
        databasePath: inMemoryDatabasePath,
        activityPermissionGranted: () async => true,
        isIos: false,
        postGoalUpdate: postGoalUpdate,
      );
    }

    test('refresh keeps dailyStepGoal from cubit state not preferences', () async {
      await userHealthMetrics.setDailyStepGoal(12000);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();

      expect(cubit.state.status, MyDataStatus.ready);
      expect(cubit.state.dailyStepGoal, kDefaultStepGoal);

      expect(await cubit.updateDailyStepGoal(12000), isTrue);
      await cubit.refresh(silent: true);

      expect(cubit.state.dailyStepGoal, 12000);
      expect(await userHealthMetrics.getDailyStepGoal(), 12000);
    });

    test('updateDailyStepGoal persists and updates state', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      expect(await cubit.updateDailyStepGoal(15000), isTrue);

      expect(cubit.state.dailyStepGoal, 15000);
      expect(await userHealthMetrics.getDailyStepGoal(), 15000);
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
      await userHealthMetrics.setDailyStepGoal(8000);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      expect(await cubit.updateDailyStepGoal(999), isFalse);

      expect(cubit.state.dailyStepGoal, 8000);
      expect(await userHealthMetrics.getDailyStepGoal(), 8000);
    });

    test('no-op when goal unchanged', () async {
      var callbackCalled = false;
      await userHealthMetrics.setDailyStepGoal(8000);
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
      expect(await userHealthMetrics.getDailyStepGoal(), 12000);
    });

    test('blocked while purge in flight', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      cubit.emit(cubit.state.copyWith(isPurging: true));
      expect(await cubit.updateDailyStepGoal(10000), isFalse);

      expect(cubit.state.dailyStepGoal, isNot(10000));
      expect(await userHealthMetrics.getDailyStepGoal(), isNot(10000));
    });

    test('blocked while export in flight', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      cubit.emit(cubit.state.copyWith(isExporting: true));
      expect(await cubit.updateDailyStepGoal(10000), isFalse);

      expect(await userHealthMetrics.getDailyStepGoal(), isNot(10000));
    });

    test('blocked while import in flight', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      cubit.emit(cubit.state.copyWith(isImporting: true));
      expect(await cubit.updateDailyStepGoal(10000), isFalse);

      expect(await userHealthMetrics.getDailyStepGoal(), isNot(10000));
    });

    test('refresh completing after goal save keeps new dailyStepGoal', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();
      final refreshFuture = cubit.refresh(silent: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await cubit.updateDailyStepGoal(15000), isTrue);
      await refreshFuture;

      expect(cubit.state.dailyStepGoal, 15000);
      expect(await userHealthMetrics.getDailyStepGoal(), 15000);
    });
  });
}
