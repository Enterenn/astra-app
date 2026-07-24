@Tags(['critical'])
library;

import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/time/local_day_formatter.dart';
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

  group('MyDataCubit refresh daily goal', () {
    late Database db;
    late UserSettingsRepository userSettings;
    late UserHealthMetricsRepository userHealthMetrics;
    late FakeTimeProvider clock;
    late StepTestRepos stepRepos;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 3, 12),
        zoneOffset: const Duration(hours: 2),
      );
      userSettings = UserSettingsRepository(db);
      userHealthMetrics = UserHealthMetricsRepository(db, clock: clock);
      stepRepos = StepTestFixtures.create(db: db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    test('refresh loads journal goal when prefs cache drifted', () async {
      await userHealthMetrics.setDailyStepGoal(8000);
      final todayIso = formatLocalDayIso(clock.snapshot());
      await db.update(
        'daily_goal_effective',
        {'goal': 12000},
        where: 'effective_from_local_day = ?',
        whereArgs: [todayIso],
      );

      final cubit = MyDataCubit(
        stepAggregation: stepRepos.aggregation,
        csvService: stepRepos.csv,
        stepIngestion: stepRepos.ingestion,
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        clock: clock,
        databasePath: inMemoryDatabasePath,
        activityPermissionGranted: () async => true,
        saveCsvFile: (_) async => true,
        pickCsvFile: () async => null,
        isIos: false,
      );

      await cubit.refresh();
      expect(cubit.state.status, MyDataStatus.ready);
      expect(cubit.state.dailyStepGoal, 12000);

      await cubit.close();
    });
  });
}
