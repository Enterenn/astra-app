import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/time/time_provider.dart';
import 'package:astra_app/data/models/chart_day_aggregate.dart';
import 'package:astra_app/data/models/chart_month_aggregate.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/contracts/contracts.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import '../../dev/data_inject_service.dart';
import 'package:astra_app/presentation/cubits/history_cubit.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

class _BatchGoalSpyPreferencesRepository extends UserPreferencesRepository {
  _BatchGoalSpyPreferencesRepository(super.db, {super.clock});

  int getGoalsForLocalDaysCallCount = 0;
  int getGoalForLocalDayCallCount = 0;

  @override
  Future<Map<String, int>> getGoalsForLocalDays(
    List<String> localDayIsos,
  ) async {
    getGoalsForLocalDaysCallCount++;
    return super.getGoalsForLocalDays(localDayIsos);
  }

  @override
  Future<int> getGoalForLocalDay(String localDayIso) async {
    getGoalForLocalDayCallCount++;
    return super.getGoalForLocalDay(localDayIso);
  }
}

class _ChartAggregateSpyRepository implements StepRepositoryContract {
  _ChartAggregateSpyRepository(this._delegate);

  final StepRepositoryContract _delegate;
  int chartAggregateCallCount = 0;
  int chartMonthlyAggregateCallCount = 0;

  @override
  TimeProvider get clock => _delegate.clock;

  @override
  Future<List<ChartDayAggregate>> getChartDailyAggregates({
    required int days,
  }) async {
    chartAggregateCallCount++;
    return _delegate.getChartDailyAggregates(days: days);
  }

  @override
  Future<List<ChartMonthAggregate>> getChartMonthlyAggregates({
    required int months,
  }) async {
    chartMonthlyAggregateCallCount++;
    return _delegate.getChartMonthlyAggregates(months: months);
  }

  @override
  Future<List<TimeseriesSampleModel>> getActiveBucketsForLocalDay(
    DateTime localDay,
  ) {
    return _delegate.getActiveBucketsForLocalDay(localDay);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _ThrowingChartRepository implements StepRepositoryContract {
  _ThrowingChartRepository(this._fallback);

  final StepRepositoryContract _fallback;
  int callCount = 0;

  @override
  TimeProvider get clock => _fallback.clock;

  @override
  Future<List<ChartDayAggregate>> getChartDailyAggregates({
    required int days,
  }) async {
    callCount++;
    if (callCount > 1) {
      throw StateError('database unavailable');
    }
    return _fallback.getChartDailyAggregates(days: days);
  }

  @override
  Future<List<TimeseriesSampleModel>> getActiveBucketsForLocalDay(
    DateTime localDay,
  ) {
    return _fallback.getActiveBucketsForLocalDay(localDay);
  }

  @override
  Future<List<ChartMonthAggregate>> getChartMonthlyAggregates({
    required int months,
  }) {
    return _fallback.getChartMonthlyAggregates(months: months);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _AlwaysThrowingChartRepository implements StepRepositoryContract {
  @override
  Future<List<ChartDayAggregate>> getChartDailyAggregates({
    required int days,
  }) async {
    throw StateError('database unavailable');
  }

  @override
  Future<List<ChartMonthAggregate>> getChartMonthlyAggregates({
    required int months,
  }) async {
    throw StateError('database unavailable');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _ThrowingBucketOnSecondRefreshRepository implements StepRepositoryContract {
  _ThrowingBucketOnSecondRefreshRepository(this._delegate);

  final StepRepositoryContract _delegate;
  int refreshCount = 0;

  @override
  TimeProvider get clock => _delegate.clock;

  @override
  Future<List<ChartDayAggregate>> getChartDailyAggregates({
    required int days,
  }) async {
    refreshCount++;
    return _delegate.getChartDailyAggregates(days: days);
  }

  @override
  Future<List<TimeseriesSampleModel>> getActiveBucketsForLocalDay(
    DateTime localDay,
  ) {
    if (refreshCount > 1) {
      throw StateError('buckets unavailable');
    }
    return _delegate.getActiveBucketsForLocalDay(localDay);
  }

  @override
  Future<List<ChartMonthAggregate>> getChartMonthlyAggregates({
    required int months,
  }) {
    return _delegate.getChartMonthlyAggregates(months: months);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('HistoryCubit', () {
    late Database db;
    late UserPreferencesRepository userPreferences;
    late FakeTimeProvider clock;
    late StepRepository stepRepository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
      userPreferences = UserPreferencesRepository(db, clock: clock);
      stepRepository = StepRepository(db: db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    HistoryCubit buildCubit({
      StepRepositoryContract? repository,
      UserPreferencesRepositoryContract? preferences,
    }) {
      return HistoryCubit(
        stepRepository: repository ?? stepRepository,
        userPreferences: preferences ?? userPreferences,
      );
    }

    // ── Empty state ──────────────────────────────────────────────────────────

    test('empty DB: loading initial state, empty status, null trend/peakDay/periodAverages', () async {
      // initial state is loading before any refresh
      final c0 = buildCubit();
      expect(c0.state.status, HistoryStatus.loading);
      c0.close();

      // after refresh: empty status with sensible zero-state
      final cubit = buildCubit();
      await cubit.refresh();
      expect(cubit.state.status, HistoryStatus.empty);
      expect(cubit.state.chartPoints, isEmpty);
      expect(cubit.state.trend, isNull);
      expect(cubit.state.dailyGoal, kDefaultStepGoal);
      expect(cubit.state.periodAverages, isNull);
      expect(cubit.state.peakDay, isNull);
      cubit.close();
    });

    // ── Ready with data ──────────────────────────────────────────────────────

    test('refresh emits ready: 7 chart points oldest-first with non-null trend after inject', () async {
      await DataInjectService(repository: stepRepository).inject90Days(
        clock: clock,
      );
      final cubit = buildCubit();
      await cubit.refresh();

      expect(cubit.state.status, HistoryStatus.ready);
      expect(cubit.state.chartPoints, hasLength(7));
      expect(cubit.state.chartPoints.first.totalSteps, greaterThan(0));
      expect(cubit.state.trend, isNotNull);
      expect(
        cubit.state.chartPoints.first.localDay.isBefore(
          cubit.state.chartPoints.last.localDay,
        ),
        isTrue,
      );
      cubit.close();
    });

    test('selectPeriod switches to 30-day slice without extra DB call', () async {
      await DataInjectService(repository: stepRepository).inject90Days(
        clock: clock,
      );
      final spy = _ChartAggregateSpyRepository(stepRepository);
      final cubit = buildCubit(repository: spy);

      await cubit.refresh();
      expect(spy.chartAggregateCallCount, 1);

      cubit.selectPeriod(HistoryPeriod.days30);
      expect(spy.chartAggregateCallCount, 1);
      expect(cubit.state.period, HistoryPeriod.days30);
      expect(cubit.state.chartPoints, hasLength(30));

      cubit.selectPeriod(HistoryPeriod.days7);
      expect(spy.chartAggregateCallCount, 1);
      expect(cubit.state.chartPoints, hasLength(7));
      cubit.close();
    });

    // ── Trend ────────────────────────────────────────────────────────────────

    test('trend direction: up, down, and flat based on week-over-week comparison', () async {
      // up: current week > prior week
      await _seedTwoWeekPattern(stepRepository);
      final c1 = buildCubit();
      await c1.refresh();
      expect(c1.state.trend?.direction, TrendDirection.up);
      expect(c1.state.trend?.label, contains('Up'));
      c1.close();

      // down: current week < prior week
      await db.delete('timeseries_samples');
      await _seedTwoWeekPattern(stepRepository, invert: true);
      final c2 = buildCubit();
      await c2.refresh();
      expect(c2.state.trend?.direction, TrendDirection.down);
      expect(c2.state.trend?.label, contains('Down'));
      c2.close();

      // flat: both weeks equal
      await db.delete('timeseries_samples');
      await _seedTwoWeekPattern(stepRepository, equalWeeks: true);
      final c3 = buildCubit();
      await c3.refresh();
      expect(c3.state.trend?.direction, TrendDirection.flat);
      expect(c3.state.trend?.label, 'Same as last week');
      c3.close();
    });

    test('trend shows no prior week copy when prior week is empty', () async {
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 5000,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit();
      await cubit.refresh();

      expect(cubit.state.trend?.direction, TrendDirection.flat);
      expect(cubit.state.trend?.label, 'No prior week data');
      cubit.close();
    });

    // ── Concurrency & error resilience ───────────────────────────────────────

    test('concurrent refresh calls share one repository read', () async {
      await DataInjectService(repository: stepRepository).inject90Days(
        clock: clock,
      );
      final spy = _ChartAggregateSpyRepository(stepRepository);
      final cubit = buildCubit(repository: spy);

      await Future.wait([cubit.refresh(), cubit.refresh()]);

      expect(spy.chartAggregateCallCount, 1);
      cubit.close();
    });

    test('refresh recovers from cache when repository throws', () async {
      await DataInjectService(repository: stepRepository).inject90Days(
        clock: clock,
      );
      final throwing = _ThrowingChartRepository(stepRepository);
      final cubit = buildCubit(repository: throwing);

      await cubit.refresh();
      expect(cubit.state.status, HistoryStatus.ready);
      final averagesBefore = cubit.state.periodAverages;
      final peakDayBefore = cubit.state.peakDay;

      await cubit.refresh(silent: true);

      expect(cubit.state.status, HistoryStatus.ready);
      expect(cubit.state.chartPoints, isNotEmpty);
      expect(cubit.state.periodAverages?.averageSteps, averagesBefore?.averageSteps);
      expect(cubit.state.periodAverages?.averageKcal, averagesBefore?.averageKcal);
      expect(cubit.state.peakDay?.totalSteps, peakDayBefore?.totalSteps);
      expect(cubit.state.peakDay?.localDay, peakDayBefore?.localDay);
      expect(cubit.state.peakDay?.dateLabel, peakDayBefore?.dateLabel);
      cubit.close();
    });

    test(
      'refresh keeps chart and periodAverages consistent when bucket fetch fails',
      () async {
        await DataInjectService(repository: stepRepository).inject90Days(
          clock: clock,
        );
        final throwing = _ThrowingBucketOnSecondRefreshRepository(stepRepository);
        final cubit = buildCubit(repository: throwing);

        await cubit.refresh();
        expect(cubit.state.status, HistoryStatus.ready);
        final averagesBefore = cubit.state.periodAverages;
        final peakDayBefore = cubit.state.peakDay;
        expect(averagesBefore, isNotNull);
        expect(peakDayBefore, isNotNull);

        await cubit.refresh(silent: true);

        expect(cubit.state.status, HistoryStatus.ready);
        expect(cubit.state.periodAverages?.averageSteps, averagesBefore?.averageSteps);
        expect(cubit.state.periodAverages?.averageKcal, averagesBefore?.averageKcal);
        expect(cubit.state.peakDay?.totalSteps, peakDayBefore?.totalSteps);
        expect(cubit.state.peakDay?.localDay, peakDayBefore?.localDay);
        expect(cubit.state.peakDay?.dateLabel, peakDayBefore?.dateLabel);
        cubit.close();
      },
    );

    test('refresh leaves empty state when repository throws with no cache', () async {
      final cubit = buildCubit(repository: _AlwaysThrowingChartRepository());

      await cubit.refresh();

      expect(cubit.state.status, HistoryStatus.empty);
      cubit.close();
    });

    // ── refreshGoal ──────────────────────────────────────────────────────────

    test('refreshGoal updates daily goal without chart repository call', () async {
      await DataInjectService(repository: stepRepository).inject90Days(
        clock: clock,
      );
      final spy = _ChartAggregateSpyRepository(stepRepository);
      final cubit = buildCubit(repository: spy);

      await cubit.refresh();
      expect(spy.chartAggregateCallCount, 1);

      await userPreferences.setDailyStepGoal(12_000);
      await cubit.refreshGoal();

      expect(spy.chartAggregateCallCount, 1);
      expect(cubit.state.dailyGoal, 12_000);
      expect(cubit.state.status, HistoryStatus.ready);
      cubit.close();
    });

    // ── goalsByDay ───────────────────────────────────────────────────────────

    test('refresh resolves goalsByDay for chart window', () async {
      await db.insert('daily_goal_effective', {
        'effective_from_local_day': '2026-05-20',
        'goal': 8000,
      });
      await db.insert('daily_goal_effective', {
        'effective_from_local_day': '2026-06-01',
        'goal': 10000,
      });
      for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2 - dayOffset, 10),
            value: 5000,
            zoneOffset: '+02:00',
          ),
        );
      }
      final cubit = buildCubit();
      await cubit.refresh();

      expect(cubit.state.goalsByDay['2026-05-27'], 8000);
      expect(cubit.state.goalsByDay['2026-06-01'], 10_000);
      expect(cubit.state.goalsByDay['2026-06-02'], 10_000);
      cubit.close();
    });

    test('refreshGoal updates goalsByDay without re-querying steps', () async {
      await db.insert('daily_goal_effective', {
        'effective_from_local_day': '2026-06-01',
        'goal': 8000,
      });
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 1, 10),
          value: 5000,
          zoneOffset: '+02:00',
        ),
      );
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 5000,
          zoneOffset: '+02:00',
        ),
      );
      final spy = _ChartAggregateSpyRepository(stepRepository);
      final cubit = buildCubit(repository: spy);

      await cubit.refresh();
      expect(cubit.state.goalsByDay['2026-06-01'], 8000);
      expect(cubit.state.goalsByDay['2026-06-02'], 8000);

      await userPreferences.setDailyStepGoal(12_000);
      await cubit.refreshGoal();

      expect(spy.chartAggregateCallCount, 1);
      expect(cubit.state.dailyGoal, 12_000);
      expect(cubit.state.goalsByDay['2026-06-02'], 12_000);
      expect(cubit.state.goalsByDay['2026-06-01'], 8000);
      cubit.close();
    });

    test('batch goal resolution: single getGoalsForLocalDays call on refresh and refreshGoal', () async {
      await DataInjectService(repository: stepRepository).inject90Days(
        clock: clock,
      );
      final prefsSpy = _BatchGoalSpyPreferencesRepository(db, clock: clock);
      final cubit = buildCubit(preferences: prefsSpy);

      await cubit.refresh();
      expect(prefsSpy.getGoalsForLocalDaysCallCount, 1);
      expect(
        prefsSpy.getGoalForLocalDayCallCount,
        1,
        reason: 'only _resolveTodayGoal should call getGoalForLocalDay',
      );
      expect(cubit.state.status, HistoryStatus.ready);

      // reset counters and verify refreshGoal also uses batch resolution
      prefsSpy.getGoalsForLocalDaysCallCount = 0;
      prefsSpy.getGoalForLocalDayCallCount = 0;
      await prefsSpy.setDailyStepGoal(12_000);
      await cubit.refreshGoal();

      expect(prefsSpy.getGoalsForLocalDaysCallCount, 1);
      expect(prefsSpy.getGoalForLocalDayCallCount, 1);
      expect(cubit.state.dailyGoal, 12_000);
      cubit.close();
    });

    // ── Auto-period selection ────────────────────────────────────────────────

    test('refresh defaults to 30d when last 7 days are empty but older days have steps', () async {
      for (var dayOffset = 14; dayOffset < 21; dayOffset++) {
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2 - dayOffset, 10),
            value: 3000,
            zoneOffset: '+02:00',
          ),
        );
      }
      final cubit = buildCubit();
      await cubit.refresh();

      expect(cubit.state.period, HistoryPeriod.days30);
      expect(cubit.state.chartPoints, hasLength(30));
      expect(cubit.state.chartPoints.any((p) => p.totalSteps > 0), isTrue);
      cubit.close();
    });

    // ── periodAverages ───────────────────────────────────────────────────────

    test('periodAverages: arithmetic mean across 7 days, includes zero-step days in denominator', () async {
      // 7 equal days → mean = 1000
      for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2 - dayOffset, 10),
            value: 1000,
            zoneOffset: '+02:00',
          ),
        );
      }
      final c1 = buildCubit();
      await c1.refresh();
      expect(c1.state.periodAverages?.averageSteps, 1000);
      c1.close();

      // 1 day × 7000 over 7-day window also averages to 1000 (zero days counted)
      await db.delete('timeseries_samples');
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 7000,
          zoneOffset: '+02:00',
        ),
      );
      final c2 = buildCubit();
      await c2.refresh();
      expect(c2.state.periodAverages?.averageSteps, 1000);
      c2.close();
    });

    test('periodAverages kcal uses bucket-based DerivedActivityMetrics', () async {
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 100,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit();
      await cubit.refresh();

      expect(cubit.state.periodAverages?.averageKcal, greaterThan(0));
      cubit.close();
    });

    test(
      'selectPeriod updates periodAverages from cache without extra chart query',
      () async {
        for (var dayOffset = 0; dayOffset < 10; dayOffset++) {
          await stepRepository.upsertIngestionBucket(
            _bucket(
              startTimeUtc: DateTime.utc(2026, 6, 2 - dayOffset, 10),
              value: 1000,
              zoneOffset: '+02:00',
            ),
          );
        }
        final spy = _ChartAggregateSpyRepository(stepRepository);
        final cubit = buildCubit(repository: spy);

        await cubit.refresh();
        expect(spy.chartAggregateCallCount, 1);
        final average7d = cubit.state.periodAverages?.averageSteps;

        cubit.selectPeriod(HistoryPeriod.days30);
        expect(spy.chartAggregateCallCount, 1);
        expect(cubit.state.periodAverages?.averageSteps, isNot(equals(average7d)));
        expect(cubit.state.periodAverages?.averageSteps, 333);

        cubit.selectPeriod(HistoryPeriod.days7);
        expect(spy.chartAggregateCallCount, 1);
        expect(cubit.state.periodAverages?.averageSteps, average7d);
        cubit.close();
      },
    );

    // ── peakDay ──────────────────────────────────────────────────────────────

    test('peakDay: selects max-step day, tie-breaks to most recent', () async {
      final maxValues = [3000, 5000, 2000, 8000, 1000, 4000, 6000];
      for (var i = 0; i < 7; i++) {
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2 - i, 10),
            value: maxValues[i],
            zoneOffset: '+02:00',
          ),
        );
      }
      final c1 = buildCubit();
      await c1.refresh();
      expect(c1.state.peakDay?.totalSteps, 8000);
      expect(c1.state.peakDay?.localDay, DateTime.utc(2026, 5, 30));
      expect(c1.state.peakDay?.dateLabel, 'Sat 30');
      c1.close();

      // tie-break: most recent day wins
      await db.delete('timeseries_samples');
      final tieValues = [8000, 5000, 8000, 3000, 2000, 1000, 4000];
      for (var i = 0; i < 7; i++) {
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2 - i, 10),
            value: tieValues[i],
            zoneOffset: '+02:00',
          ),
        );
      }
      final c2 = buildCubit();
      await c2.refresh();
      expect(c2.state.peakDay?.totalSteps, 8000);
      expect(c2.state.peakDay?.localDay, DateTime.utc(2026, 6, 2));
      c2.close();
    });

    test(
      'selectPeriod updates peakDay from cache without extra chart query',
      () async {
        for (var dayOffset = 0; dayOffset < 10; dayOffset++) {
          await stepRepository.upsertIngestionBucket(
            _bucket(
              startTimeUtc: DateTime.utc(2026, 6, 2 - dayOffset, 10),
              value: dayOffset == 9 ? 9000 : 1000,
              zoneOffset: '+02:00',
            ),
          );
        }
        final spy = _ChartAggregateSpyRepository(stepRepository);
        final cubit = buildCubit(repository: spy);

        await cubit.refresh();
        expect(spy.chartAggregateCallCount, 1);
        expect(cubit.state.peakDay?.totalSteps, 1000);

        cubit.selectPeriod(HistoryPeriod.days30);
        expect(spy.chartAggregateCallCount, 1);
        expect(cubit.state.peakDay?.totalSteps, 9000);
        expect(cubit.state.peakDay?.dateLabel, '24/5');

        cubit.selectPeriod(HistoryPeriod.days7);
        expect(spy.chartAggregateCallCount, 1);
        expect(cubit.state.peakDay?.totalSteps, 1000);
        cubit.close();
      },
    );

    test('7d window with no steps: null peakDay and null periodAverages after selectPeriod', () async {
      for (var dayOffset = 14; dayOffset < 21; dayOffset++) {
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2 - dayOffset, 10),
            value: 3000,
            zoneOffset: '+02:00',
          ),
        );
      }
      final cubit = buildCubit();
      await cubit.refresh();
      expect(cubit.state.period, HistoryPeriod.days30);
      expect(cubit.state.peakDay, isNotNull);
      expect(cubit.state.periodAverages, isNotNull);

      cubit.selectPeriod(HistoryPeriod.days7);
      expect(cubit.state.peakDay, isNull);
      expect(cubit.state.periodAverages, isNull);
      cubit.close();
    });

    // ── Monthly chart ────────────────────────────────────────────────────────

    test('monthly chart: parallel fetch, cache on period toggle, oldest-first ordering', () async {
      await DataInjectService(repository: stepRepository).inject90Days(
        clock: clock,
      );
      final spy = _ChartAggregateSpyRepository(stepRepository);
      final cubit = buildCubit(repository: spy);

      await cubit.refresh();
      expect(spy.chartAggregateCallCount, 1);
      expect(spy.chartMonthlyAggregateCallCount, 1);
      expect(cubit.state.monthlyChartPoints, isEmpty);

      cubit.selectPeriod(HistoryPeriod.months12);
      expect(spy.chartAggregateCallCount, 1);
      expect(spy.chartMonthlyAggregateCallCount, 1);
      expect(cubit.state.period, HistoryPeriod.months12);
      expect(cubit.state.monthlyChartPoints, hasLength(12));
      expect(cubit.state.chartPoints, isEmpty);
      expect(cubit.state.trend, isNull);
      expect(cubit.state.periodAverages, isNull);
      expect(cubit.state.peakDay, isNull);

      // oldest-first ordering
      final points = cubit.state.monthlyChartPoints;
      expect(points.first.monthStart.isBefore(points.last.monthStart), isTrue);

      cubit.selectPeriod(HistoryPeriod.days7);
      expect(spy.chartAggregateCallCount, 1);
      expect(spy.chartMonthlyAggregateCallCount, 1);
      cubit.close();
    });

    test(
      'refresh emits ready when 30d sum is zero but twelve-month window has steps',
      () async {
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 4, 15, 10),
            value: 5000,
            zoneOffset: '+02:00',
          ),
        );
        final cubit = buildCubit();
        await cubit.refresh();

        expect(cubit.state.status, HistoryStatus.ready);
        cubit.selectPeriod(HistoryPeriod.months12);
        expect(cubit.state.monthlyChartPoints.any((m) => m.totalSteps > 0), isTrue);
        cubit.close();
      },
    );
  });
}

Future<void> _seedTwoWeekPattern(
  StepRepository repository, {
  bool invert = false,
  bool equalWeeks = false,
}) async {
  final currentWeekSteps = equalWeeks ? 1000 : (invert ? 500 : 2000);
  final priorWeekSteps = equalWeeks ? 1000 : (invert ? 2000 : 500);

  for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
    await repository.upsertIngestionBucket(
      _bucket(
        startTimeUtc: DateTime.utc(2026, 6, 2 - dayOffset, 10),
        value: currentWeekSteps,
        zoneOffset: '+02:00',
      ),
    );
  }

  for (var dayOffset = 7; dayOffset < 14; dayOffset++) {
    await repository.upsertIngestionBucket(
      _bucket(
        startTimeUtc: DateTime.utc(2026, 6, 2 - dayOffset, 10),
        value: priorWeekSteps,
        zoneOffset: '+02:00',
      ),
    );
  }
}

NormalizedStepBucket _bucket({
  required DateTime startTimeUtc,
  required int value,
  required String zoneOffset,
}) {
  return NormalizedStepBucket(
    startTimeUtc: startTimeUtc,
    endTimeUtc: startTimeUtc.add(const Duration(minutes: 5)),
    value: value,
    provider: kInternalPhoneProvider,
    deviceId: kSmartphoneDeviceId,
    zoneOffset: zoneOffset,
  );
}
