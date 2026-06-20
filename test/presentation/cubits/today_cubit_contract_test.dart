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
}
