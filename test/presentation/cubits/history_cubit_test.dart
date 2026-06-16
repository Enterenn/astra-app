import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/time/time_provider.dart';
import 'package:astra_app/data/models/chart_day_aggregate.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/dev/data_inject_service.dart';
import 'package:astra_app/presentation/cubits/history_cubit.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

class _ChartAggregateSpyRepository implements StepRepository {
  _ChartAggregateSpyRepository(this._delegate);

  final StepRepository _delegate;
  int chartAggregateCallCount = 0;

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

class _ThrowingChartRepository implements StepRepository {
  _ThrowingChartRepository(this._fallback);

  final StepRepository _fallback;
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
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _AlwaysThrowingChartRepository implements StepRepository {
  @override
  Future<List<ChartDayAggregate>> getChartDailyAggregates({
    required int days,
  }) async {
    throw StateError('database unavailable');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _ThrowingBucketOnSecondRefreshRepository implements StepRepository {
  _ThrowingBucketOnSecondRefreshRepository(this._delegate);

  final StepRepository _delegate;
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

    HistoryCubit buildCubit({StepRepository? repository}) {
      return HistoryCubit(
        stepRepository: repository ?? stepRepository,
        userPreferences: userPreferences,
      );
    }

    test('starts in loading state', () {
      final cubit = buildCubit();
      expect(cubit.state.status, HistoryStatus.loading);
      cubit.close();
    });

    test('refresh emits empty when database has no steps', () async {
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.status, HistoryStatus.empty);
      expect(cubit.state.chartPoints, isEmpty);
      expect(cubit.state.trend, isNull);
      expect(cubit.state.dailyGoal, kDefaultStepGoal);
      cubit.close();
    });

    test('refresh emits ready with 7 chart points by default after inject', () async {
      await DataInjectService(repository: stepRepository).inject90Days(
        clock: clock,
      );
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.status, HistoryStatus.ready);
      expect(cubit.state.chartPoints, hasLength(7));
      expect(cubit.state.chartPoints.first.totalSteps, greaterThan(0));
      expect(cubit.state.trend, isNotNull);
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

    test('chart points are oldest-first for chart axis', () async {
      await DataInjectService(repository: stepRepository).inject90Days(
        clock: clock,
      );
      final cubit = buildCubit();

      await cubit.refresh();

      final points = cubit.state.chartPoints;
      expect(points.first.localDay.isBefore(points.last.localDay), isTrue);
      cubit.close();
    });

    test('trend is hidden when both weeks have zero steps', () async {
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.trend, isNull);
      cubit.close();
    });

    test('trend shows up when current week exceeds prior week', () async {
      await _seedTwoWeekPattern(stepRepository);
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.trend?.direction, TrendDirection.up);
      expect(cubit.state.trend?.label, contains('Up'));
      cubit.close();
    });

    test('trend shows down when current week is below prior week', () async {
      await _seedTwoWeekPattern(stepRepository, invert: true);
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.trend?.direction, TrendDirection.down);
      expect(cubit.state.trend?.label, contains('Down'));
      cubit.close();
    });

    test('trend shows flat when weeks match', () async {
      await _seedTwoWeekPattern(stepRepository, equalWeeks: true);
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.trend?.direction, TrendDirection.flat);
      expect(cubit.state.trend?.label, 'Same as last week');
      cubit.close();
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

      await cubit.refresh(silent: true);

      expect(cubit.state.status, HistoryStatus.ready);
      expect(cubit.state.chartPoints, isNotEmpty);
      expect(cubit.state.periodAverages?.averageSteps, averagesBefore?.averageSteps);
      expect(cubit.state.periodAverages?.averageKcal, averagesBefore?.averageKcal);
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
        expect(averagesBefore, isNotNull);

        await cubit.refresh(silent: true);

        expect(cubit.state.status, HistoryStatus.ready);
        expect(
          cubit.state.periodAverages?.averageSteps,
          averagesBefore?.averageSteps,
        );
        expect(
          cubit.state.periodAverages?.averageKcal,
          averagesBefore?.averageKcal,
        );
        cubit.close();
      },
    );

    test('refresh leaves empty state when repository throws with no cache', () async {
      final cubit = buildCubit(repository: _AlwaysThrowingChartRepository());

      await cubit.refresh();

      expect(cubit.state.status, HistoryStatus.empty);
      cubit.close();
    });

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

    test(
      'refresh defaults to 30d when last 7 days are empty but older days have steps',
      () async {
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
        expect(
          cubit.state.chartPoints.any((p) => p.totalSteps > 0),
          isTrue,
        );
        cubit.close();
      },
    );

    test('periodAverages reflects arithmetic mean of steps in 7d window', () async {
      for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
        await stepRepository.upsertIngestionBucket(
          _bucket(
            startTimeUtc: DateTime.utc(2026, 6, 2 - dayOffset, 10),
            value: 1000,
            zoneOffset: '+02:00',
          ),
        );
      }
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.periodAverages?.averageSteps, 1000);
      cubit.close();
    });

    test('periodAverages includes zero-step days in denominator', () async {
      await stepRepository.upsertIngestionBucket(
        _bucket(
          startTimeUtc: DateTime.utc(2026, 6, 2, 10),
          value: 7000,
          zoneOffset: '+02:00',
        ),
      );
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.periodAverages?.averageSteps, 1000);
      cubit.close();
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

    test('refresh emits null periodAverages when empty', () async {
      final cubit = buildCubit();

      await cubit.refresh();

      expect(cubit.state.periodAverages, isNull);
      cubit.close();
    });

    test(
      'selectPeriod to 7d with zero-step window emits null periodAverages',
      () async {
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
        expect(cubit.state.periodAverages, isNotNull);

        cubit.selectPeriod(HistoryPeriod.days7);
        expect(cubit.state.period, HistoryPeriod.days7);
        expect(cubit.state.periodAverages, isNull);
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
