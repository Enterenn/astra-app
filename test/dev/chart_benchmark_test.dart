import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/dev/chart_benchmark.dart';
import 'package:astra_app/dev/data_inject_service.dart';
import 'package:astra_app/dev/lifecycle_simulator.dart';
import 'package:astra_app/presentation/cubits/history_cubit.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../core/time/fake_time_provider.dart';
import '../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('ChartBenchmark smoke (shared 90d inject)', () {
    late Database db;
    late StepRepository repository;
    late UserPreferencesRepository userPreferences;
    late FakeTimeProvider clock;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
      repository = StepRepository(db: db, clock: clock);
      userPreferences = UserPreferencesRepository(db);
      await DataInjectService(repository: repository).inject90Days(clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    test('raw profile completes with finite percentiles', () async {
      final result = await runChartBenchmark(
        repository: repository,
        clock: clock,
        userPreferences: userPreferences,
        iterations: 1,
        skipDatasetSetup: true,
      );

      expect(result.iterations, 1);
      expect(result.datasetLabel, kDatasetLabelRaw25920);
      expect(result.rowCount, kDevInjectExpectedRowCount);
      expect(result.queryP50Ms.isFinite, isTrue);
      expect(result.queryP95Ms.isFinite, isTrue);
      expect(result.toggleP50Ms.isFinite, isTrue);
      expect(result.toggleP95Ms.isFinite, isTrue);
      expect(result.totalP50Ms.isFinite, isTrue);
      expect(result.totalP95Ms.isFinite, isTrue);

      // CI hosts vary widely — do not assert p95 < 100ms here (KPI-01 device gate).
    });

    // Widget pump covered by step_bar_chart_test.dart; fl_chart + 30 bars hangs
    // some Windows test hosts. Toggle slice path is validated here (device KPI path).
    test('benchmarkToggleRender toggles 7d and 30d on warmed cubit', () async {
      final cubit = HistoryCubit(
        stepRepository: repository,
        userPreferences: userPreferences,
      );
      addTearDown(cubit.close);

      await cubit.refresh();
      expect(cubit.state.status, HistoryStatus.ready);

      await benchmarkToggleRender(cubit: cubit);

      expect(cubit.state.period, HistoryPeriod.days30);
      expect(cubit.state.chartPoints, hasLength(30));
    });
  });

  group('ChartBenchmark compacted profile', () {
    late Database db;
    late StepRepository repository;
    late UserPreferencesRepository userPreferences;
    late FakeTimeProvider clock;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
      repository = StepRepository(db: db, clock: clock);
      userPreferences = UserPreferencesRepository(db);
      await DataInjectService(repository: repository).inject90Days(clock: clock);
      await LifecycleSimulator(
        db: db,
        repository: repository,
        clock: clock,
      ).simulateDownsampling();
    });

    tearDown(() async {
      await db.close();
    });

    test('uses lifecycle dataset label', () async {
      final result = await runChartBenchmark(
        repository: repository,
        clock: clock,
        userPreferences: userPreferences,
        iterations: 1,
        skipDatasetSetup: true,
      );

      expect(result.datasetLabel, kDatasetLabelCompacted10080);
      expect(result.rowCount, 10080);
    });
  });
}
