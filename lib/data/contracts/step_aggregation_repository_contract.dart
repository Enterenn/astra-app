import '../../core/time/time_provider.dart';
import '../models/chart_day_aggregate.dart';
import '../models/chart_month_aggregate.dart';
import '../models/database_footprint.dart';
import '../models/timeseries_sample_model.dart';

abstract class StepAggregationRepositoryContract {
  TimeProvider get clock;

  Future<int> getTodaySteps();

  Future<List<TimeseriesSampleModel>> getTodayActiveBuckets();

  Future<List<TimeseriesSampleModel>> getActiveBucketsForLocalDay(
    DateTime localDay,
  );

  Future<List<ChartDayAggregate>> getChartDailyAggregates({required int days});

  Future<List<ChartMonthAggregate>> getChartMonthlyAggregates({
    required int months,
  });

  Future<DateTime?> getLastIngestionUtc();

  Future<int> countStepSamples();

  Future<DatabaseFootprint> getFootprint({required String databasePath});
}
