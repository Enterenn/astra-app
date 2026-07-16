import 'dart:async';

import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/time/time_provider.dart';
import 'package:astra_app/data/contracts/contracts.dart';
import 'package:astra_app/data/models/chart_day_aggregate.dart';
import 'package:astra_app/data/models/chart_month_aggregate.dart';
import 'package:astra_app/data/models/database_footprint.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:astra_app/presentation/cubits/today_cubit.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/time/fake_time_provider.dart';

// ---------------------------------------------------------------------------
// Basic fakes (original)
// ---------------------------------------------------------------------------

class _FakeStepAggregationRepository implements StepAggregationRepositoryContract {
  _FakeStepAggregationRepository(this.clock);

  @override
  final TimeProvider clock;

  @override
  Future<int> getTodaySteps() async => 0;

  @override
  Future<List<TimeseriesSampleModel>> getTodayActiveBuckets() async => [];

  @override
  Future<DateTime?> getLastIngestionUtc() async => null;

  @override
  Future<List<ChartDayAggregate>> getChartDailyAggregates({
    required int days,
  }) async {
    return List.generate(
      days,
      (index) => ChartDayAggregate(
        localDay: DateTime.utc(2026, 6, 2).subtract(Duration(days: index)),
        totalSteps: 0,
      ),
    );
  }

  @override
  Future<List<TimeseriesSampleModel>> getActiveBucketsForLocalDay(
    DateTime localDay,
  ) async =>
      [];

  @override
  Future<List<ChartMonthAggregate>> getChartMonthlyAggregates({
    required int months,
  }) async =>
      [];

  @override
  Future<int> countStepSamples() async => 0;

  @override
  Future<DatabaseFootprint> getFootprint({required String databasePath}) async =>
      const DatabaseFootprint(sampleCount: 0, fileSizeBytes: 0);
}

class _FakeUserSettingsRepository implements UserSettingsRepositoryContract {
  @override
  bool get isDatabaseOpen => true;

  @override
  Future<int?> getLastDisplayedSteps(String localDayIso) async => null;

  @override
  Future<String?> getAppLocale() async => null;

  @override
  Future<void> setAppLocale(String languageCode) async {}

  @override
  Future<void> clearAppLocale() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserHealthMetricsRepository
    implements UserHealthMetricsRepositoryContract {
  @override
  Future<int> getGoalForLocalDay(String localDayIso) async => kDefaultStepGoal;

  @override
  Future<int?> getHeightCm() async => null;

  @override
  Future<double?> getWeightKg() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Recording fakes for fast-path query-budget tests
// ---------------------------------------------------------------------------

class _RecordingStepAggregation implements StepAggregationRepositoryContract {
  _RecordingStepAggregation(
    this.clock, {
    this.fixedSteps = 0,
    this.chartGate,
    this.bucketsGate,
    this.stepsGate,
  });

  @override
  final TimeProvider clock;
  final int fixedSteps;

  final Future<void>? chartGate;
  final Future<void>? bucketsGate;
  final Future<void>? stepsGate;

  int getTodayStepsCallCount = 0;
  int getTodayActiveBucketsCallCount = 0;
  int getLastIngestionUtcCallCount = 0;
  int getChartDailyAggregatesCallCount = 0;

  @override
  Future<int> getTodaySteps() async {
    getTodayStepsCallCount++;
    if (stepsGate != null && getTodayStepsCallCount == 1) await stepsGate;
    return fixedSteps;
  }

  @override
  Future<List<TimeseriesSampleModel>> getTodayActiveBuckets() async {
    getTodayActiveBucketsCallCount++;
    if (bucketsGate != null) await bucketsGate;
    return [];
  }

  @override
  Future<DateTime?> getLastIngestionUtc() async {
    getLastIngestionUtcCallCount++;
    return null;
  }

  @override
  Future<List<ChartDayAggregate>> getChartDailyAggregates({
    required int days,
  }) async {
    getChartDailyAggregatesCallCount++;
    if (chartGate != null) await chartGate;
    return List.generate(
      days,
      (index) => ChartDayAggregate(
        localDay: DateTime.utc(2026, 6, 2).subtract(Duration(days: index)),
        totalSteps: 0,
      ),
    );
  }

  @override
  Future<List<TimeseriesSampleModel>> getActiveBucketsForLocalDay(
    DateTime localDay,
  ) async =>
      [];

  @override
  Future<List<ChartMonthAggregate>> getChartMonthlyAggregates({
    required int months,
  }) async =>
      [];

  @override
  Future<int> countStepSamples() async => 0;

  @override
  Future<DatabaseFootprint> getFootprint({required String databasePath}) async =>
      const DatabaseFootprint(sampleCount: 0, fileSizeBytes: 0);
}

class _RecordingUserSettings implements UserSettingsRepositoryContract {
  _RecordingUserSettings({this.tryClaimCelebrationResult = false});

  int getLastDisplayedStepsCallCount = 0;
  int tryClaimCelebrationShownDateCallCount = 0;
  final bool tryClaimCelebrationResult;

  @override
  bool get isDatabaseOpen => true;

  @override
  Future<int?> getLastDisplayedSteps(String localDayIso) async {
    getLastDisplayedStepsCallCount++;
    return null;
  }

  @override
  Future<bool> tryClaimCelebrationShownDate(String localDayIso) async {
    tryClaimCelebrationShownDateCallCount++;
    return tryClaimCelebrationResult;
  }

  @override
  Future<String?> getAppLocale() async => null;

  @override
  Future<void> setAppLocale(String languageCode) async {}

  @override
  Future<void> clearAppLocale() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TodayCubit (contract fakes — no SQLite)', () {
    late FakeTimeProvider clock;

    setUp(() {
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
    });

    test('refresh emits noPermission when activity permission denied', () async {
      final cubit = TodayCubit(
        stepAggregation: _FakeStepAggregationRepository(clock),
        userSettings: _FakeUserSettingsRepository(),
        userHealthMetrics: _FakeUserHealthMetricsRepository(),
        clock: clock,
        activityPermissionGranted: () async => false,
      );

      await cubit.refresh();

      expect(cubit.state.status, TodayStatus.noPermission);
      await cubit.close();
    });

    test('refresh emits empty when permission granted and mocked zero steps', () async {
      final cubit = TodayCubit(
        stepAggregation: _FakeStepAggregationRepository(clock),
        userSettings: _FakeUserSettingsRepository(),
        userHealthMetrics: _FakeUserHealthMetricsRepository(),
        clock: clock,
        activityPermissionGranted: () async => true,
      );

      await cubit.refresh();

      expect(cubit.state.status, TodayStatus.empty);
      expect(cubit.state.steps, 0);
      await cubit.close();
    });
  });

  // ── refreshFastPath ──────────────────────────────────────────────────────

  group('TodayCubit.refreshFastPath (recording fakes — no SQLite)', () {
    late FakeTimeProvider clock;

    setUp(() {
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 2, 12),
        zoneOffset: const Duration(hours: 2),
      );
    });

    TodayCubit _buildCubit({
      required _RecordingStepAggregation stepAgg,
      _RecordingUserSettings? settings,
      bool permissionGranted = true,
    }) {
      return TodayCubit(
        stepAggregation: stepAgg,
        userSettings: settings ?? _RecordingUserSettings(),
        userHealthMetrics: _FakeUserHealthMetricsRepository(),
        clock: clock,
        activityPermissionGranted: () async => permissionGranted,
      );
    }

    test(
      'fast path emits before buckets and chart enrichment complete',
      () async {
        final bucketsGate = Completer<void>();
        final chartGate = Completer<void>();
        final stepAgg = _RecordingStepAggregation(
          clock,
          fixedSteps: 3000,
          bucketsGate: bucketsGate.future,
          chartGate: chartGate.future,
        );
        final cubit = _buildCubit(stepAgg: stepAgg);

        await cubit.refreshFastPath();

        expect(cubit.state.lastDisplayedStepsLoaded, isTrue);
        expect(cubit.state.weekDays, isEmpty);
        expect(stepAgg.getChartDailyAggregatesCallCount, 0);
        expect(stepAgg.getLastIngestionUtcCallCount, lessThanOrEqualTo(1));

        bucketsGate.complete();
        chartGate.complete();
        await pumpEventQueue();
        await cubit.close();
      },
    );

    test(
      '≤3 data queries at first emit; enrichment queries run after return',
      () async {
        final stepAgg = _RecordingStepAggregation(clock, fixedSteps: 1000);
        final settings = _RecordingUserSettings();
        final cubit = _buildCubit(stepAgg: stepAgg, settings: settings);

        await cubit.refreshFastPath();

        expect(stepAgg.getTodayStepsCallCount, 1);
        expect(settings.getLastDisplayedStepsCallCount, 1);
        expect(settings.tryClaimCelebrationShownDateCallCount, 0);
        expect(stepAgg.getChartDailyAggregatesCallCount, 0);

        await pumpEventQueue();

        expect(stepAgg.getTodayActiveBucketsCallCount, 1);
        expect(stepAgg.getChartDailyAggregatesCallCount, 1);
        expect(stepAgg.getLastIngestionUtcCallCount, 1);

        await cubit.close();
      },
    );

    test(
      'goal-met fast path skips celebration prefs on critical path',
      () async {
        final stepAgg = _RecordingStepAggregation(clock, fixedSteps: 9000);
        final settings = _RecordingUserSettings();
        final cubit = _buildCubit(stepAgg: stepAgg, settings: settings);

        await cubit.refreshFastPath();

        expect(settings.tryClaimCelebrationShownDateCallCount, 0);

        await pumpEventQueue();

        expect(settings.tryClaimCelebrationShownDateCallCount, 1);
        await cubit.close();
      },
    );

    test(
      'fast path aborts emit when refresh completes during critical path',
      () async {
        final stepsGate = Completer<void>();
        final stepAgg = _RecordingStepAggregation(
          clock,
          fixedSteps: 1500,
          stepsGate: stepsGate.future,
        );
        final cubit = _buildCubit(stepAgg: stepAgg);

        final fastPathFuture = cubit.refreshFastPath();
        await cubit.refresh();
        expect(cubit.state.weekDays, hasLength(7));

        stepsGate.complete();
        await fastPathFuture;

        expect(cubit.state.weekDays, hasLength(7));
        expect(stepAgg.getTodayStepsCallCount, 2);
        await cubit.close();
      },
    );

    test(
      'after enrichment settles, weekDays has 7 entries and '
      'lastDisplayedStepsLoaded stays true',
      () async {
        final stepAgg = _RecordingStepAggregation(clock, fixedSteps: 2000);
        final cubit = _buildCubit(stepAgg: stepAgg);

        await cubit.refreshFastPath();
        // Drain the unawaited enrichment future.
        await pumpEventQueue();

        expect(cubit.state.weekDays, hasLength(7));
        expect(cubit.state.lastDisplayedStepsLoaded, isTrue);
        await cubit.close();
      },
    );

    test(
      'concurrent refresh() after refreshFastPath() completes without hang '
      'and does not clobber lastDisplayedStepsLoaded',
      () async {
        final stepAgg = _RecordingStepAggregation(clock, fixedSteps: 500);
        final cubit = _buildCubit(stepAgg: stepAgg);

        // Start both concurrently; neither should deadlock.
        await Future.wait([
          cubit.refreshFastPath(),
          cubit.refresh(),
        ]);
        await pumpEventQueue();

        expect(cubit.state.status, isNot(TodayStatus.loading));
        expect(cubit.state.lastDisplayedStepsLoaded, isTrue);
        await cubit.close();
      },
    );

    test(
      'refreshFastPath emits noPermission promptly and still populates '
      'weekDays after enrichment when permission is denied',
      () async {
        final stepAgg = _RecordingStepAggregation(clock);
        final cubit = _buildCubit(stepAgg: stepAgg, permissionGranted: false);

        await cubit.refreshFastPath();

        // Immediate emit: noPermission, no step-data queries.
        expect(cubit.state.status, TodayStatus.noPermission);
        expect(stepAgg.getTodayStepsCallCount, 0);

        await pumpEventQueue();

        expect(cubit.state.weekDays, hasLength(7));
        await cubit.close();
      },
    );
  });
}
