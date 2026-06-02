import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/dev/chart_benchmark.dart';
import 'package:astra_app/dev/data_inject_service.dart';
import 'package:astra_app/dev/lifecycle_simulator.dart';
import 'package:astra_app/data/models/chart_day_aggregate.dart';
import 'package:astra_app/presentation/cubits/history_cubit.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../core/time/fake_time_provider.dart';
import '../helpers/sqflite_test_helper.dart';
import 'chart_benchmark_pump.dart';

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
      expect(result.profile, ChartBenchmarkProfile.fullStack);
      expect(result.includesChartRender, isFalse);
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

    test('runChartBenchmark injects when skipDatasetSetup is false', () async {
      final emptyDb = await openAstraDatabase(
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(emptyDb.close);

      final emptyRepo = StepRepository(db: emptyDb, clock: clock);
      final emptyPrefs = UserPreferencesRepository(emptyDb);

      final result = await runChartBenchmark(
        repository: emptyRepo,
        clock: clock,
        userPreferences: emptyPrefs,
        iterations: 1,
      );

      expect(result.rowCount, kDevInjectExpectedRowCount);
      expect(result.datasetLabel, kDatasetLabelRaw25920);
    });

    test('toggle-only profile skips per-iteration query', () async {
      final result = await runChartBenchmark(
        repository: repository,
        clock: clock,
        userPreferences: userPreferences,
        iterations: 3,
        profile: ChartBenchmarkProfile.toggleOnly,
        skipDatasetSetup: true,
      );

      expect(result.profile, ChartBenchmarkProfile.toggleOnly);
      expect(result.queryP50Ms, 0);
      expect(result.queryP95Ms, 0);
      expect(result.toggleP95Ms, greaterThan(0));
    });

    test('assertPassGate throws when p95 exceeds threshold', () async {
      await expectLater(
        runChartBenchmark(
          repository: repository,
          clock: clock,
          userPreferences: userPreferences,
          iterations: 1,
          skipDatasetSetup: true,
          assertPassGate: true,
          passThresholdMs: -1,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects non-positive iterations', () async {
      await expectLater(
        runChartBenchmark(
          repository: repository,
          clock: clock,
          iterations: 0,
          skipDatasetSetup: true,
        ),
        throwsArgumentError,
      );
    });

    test('runDevChartBenchmark mirrors debug guard', () async {
      final result = await runDevChartBenchmark(
        repository: repository,
        clock: clock,
        userPreferences: userPreferences,
        iterations: 1,
        skipDatasetSetup: true,
      );

      expect(result.iterations, 1);
    });

    test('with pumpChart sets includesChartRender and invokes callback', () async {
      var pumpInvoked = false;

      final result = await runChartBenchmark(
        repository: repository,
        clock: clock,
        userPreferences: userPreferences,
        iterations: 1,
        skipDatasetSetup: true,
        pumpChart: ({
          required points7d,
          required points30d,
          required dailyGoal,
        }) async {
          pumpInvoked = true;
          expect(points7d, hasLength(7));
          expect(points30d, hasLength(30));
          expect(dailyGoal, greaterThan(0));
        },
      );

      expect(pumpInvoked, isTrue);
      expect(result.includesChartRender, isTrue);
    });

    testWidgets('createTestStepBarChartPump builds 7d chart', (tester) async {
      final points7d = [
        for (var i = 0; i < 7; i++)
          ChartDayAggregate(
            localDay: DateTime.utc(2026, 5, 26 + i),
            totalSteps: 1000 + i * 100,
          ),
      ];
      final pump = createTestStepBarChartPump(tester);

      await pump(
        points7d: points7d,
        points30d: points7d,
        dailyGoal: 8000,
      );

      expect(tester.takeException(), isNull);
    });

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

    test('rejects lifecycle compaction with skipDatasetSetup', () async {
      await expectLater(
        runChartBenchmark(
          repository: repository,
          clock: clock,
          runLifecycleCompaction: true,
          skipDatasetSetup: true,
        ),
        throwsArgumentError,
      );
    });
  });
}
