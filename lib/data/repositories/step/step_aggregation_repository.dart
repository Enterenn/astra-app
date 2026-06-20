import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../../../core/lifecycle/sample_compaction_runner.dart';
import '../../../core/time/local_day_calculator.dart';
import '../../../core/time/time_provider.dart';
import '../../../core/time/timestamp_codec.dart';
import '../../contracts/step_aggregation_repository_contract.dart';
import '../../models/chart_day_aggregate.dart';
import '../../models/chart_month_aggregate.dart';
import '../../models/database_footprint.dart';
import '../../models/normalized_step_bucket.dart';
import '../../models/timeseries_sample_model.dart';
import '_step_chart_queries.dart';
import '_step_repository_session.dart';
import '_step_sample_bounds.dart';

class StepAggregationRepository implements StepAggregationRepositoryContract {
  StepAggregationRepository(
    Object sessionOrDatabase, {
    required this.clock,
    String databasePath = inMemoryDatabasePath,
  }) : _session = StepRepositorySession(
         sessionOrDatabase,
         databasePath: databasePath,
       );

  final StepRepositorySession _session;
  @override
  final TimeProvider clock;

  @override
  Future<int> getTodaySteps() async {
    final bounds = todaySampleUtcBounds(clock);
    final rows = await _session.run(
      (db) => db.query(
        'timeseries_samples',
        where: 'type = ? AND start_time >= ? AND start_time < ?',
        whereArgs: [
          kStepSampleType,
          TimestampCodec.formatUtc(bounds.lowerInclusive),
          TimestampCodec.formatUtc(bounds.upperExclusive),
        ],
      ),
    );

    // Accumulate per resolution; use finest tier only to prevent
    // double-counting when mixed-resolution rows exist (e.g. bad import).
    final byResolution = <String, int>{};
    for (final row in rows) {
      final sample = TimeseriesSampleModel.fromMap(row);
      final rowLocalDay = LocalDayCalculator.localDay(
        utc: sample.startTimeUtc,
        zoneOffset: sample.zoneOffset,
      );
      if (rowLocalDay == bounds.referenceToday) {
        byResolution.update(
          sample.resolution,
          (v) => v + sample.value.toInt(),
          ifAbsent: () => sample.value.toInt(),
        );
      }
    }

    return finestResolutionTotal(byResolution);
  }

  /// Returns today's 5-minute step buckets with positive values for activity metrics.
  ///
  /// Only `resolution = '5min'` rows are included; coarser tiers for the same
  /// local day are excluded to prevent double-counting. The activity threshold
  /// (40 steps) is applied in [DerivedActivityMetrics], not in SQL.
  @override
  Future<List<TimeseriesSampleModel>> getTodayActiveBuckets() async {
    final bounds = todaySampleUtcBounds(clock);
    return getActiveBucketsForLocalDay(bounds.referenceToday);
  }

  /// Returns 5-minute step buckets with positive values for [localDay].
  ///
  /// Same SQL filters as [getTodayActiveBuckets]; per-row [LocalDayCalculator]
  /// filter uses the **parameter** day (not clock today).
  @override
  Future<List<TimeseriesSampleModel>> getActiveBucketsForLocalDay(
    DateTime localDay,
  ) async {
    final bounds = sampleUtcBoundsForLocalDay(localDay);
    final rows = await _session.run(
      (db) => db.query(
        'timeseries_samples',
        where:
            'type = ? AND resolution = ? AND value > 0 '
            'AND start_time >= ? AND start_time < ?',
        whereArgs: [
          kStepSampleType,
          kFiveMinuteResolution,
          TimestampCodec.formatUtc(bounds.lowerInclusive),
          TimestampCodec.formatUtc(bounds.upperExclusive),
        ],
      ),
    );

    final buckets = <TimeseriesSampleModel>[];
    for (final row in rows) {
      final sample = TimeseriesSampleModel.fromMap(row);
      final rowLocalDay = LocalDayCalculator.localDay(
        utc: sample.startTimeUtc,
        zoneOffset: sample.zoneOffset,
      );
      if (rowLocalDay == bounds.referenceLocalDay) {
        buckets.add(sample);
      }
    }

    return buckets;
  }

  /// Returns daily step totals for the History chart (7 or 30 day window).
  ///
  /// Aggregation runs in Dart using each row's stored [TimeseriesSampleModel.zoneOffset].
  /// Results are zero-filled for every calendar day in the window and sorted newest-first.
  @override
  Future<List<ChartDayAggregate>> getChartDailyAggregates({
    required int days,
  }) async {
    if (days != 7 && days != 30) {
      throw ArgumentError.value(days, 'days', 'Phase 0 supports 7 or 30 only');
    }

    final bounds = dailyChartQueryBounds(days: days, clock: clock);
    final rows = await _session.run(
      (db) => db.query(
        'timeseries_samples',
        where: chartSamplesWhereClause,
        whereArgs: chartSamplesWhereArgs(bounds.sqlLowerBoundUtc),
      ),
    );

    return chartDailyAggregatesFromRows(
      rows: rows,
      referenceToday: bounds.referenceToday,
      windowStart: bounds.windowStart,
      days: days,
    );
  }

  /// Returns monthly average daily steps for the Trends twelve-month chart.
  ///
  /// Aggregation runs in Dart using each row's stored [TimeseriesSampleModel.zoneOffset].
  /// Results include every calendar month in the rolling window and are sorted newest-first.
  @override
  Future<List<ChartMonthAggregate>> getChartMonthlyAggregates({
    required int months,
  }) async {
    if (months != 12) {
      throw ArgumentError.value(months, 'months', 'Phase 0 supports 12 only');
    }

    final bounds = monthlyChartQueryBounds(months: months, clock: clock);
    final rows = await _session.run(
      (db) => db.query(
        'timeseries_samples',
        where: chartSamplesWhereClause,
        whereArgs: chartSamplesWhereArgs(bounds.sqlLowerBoundUtc),
      ),
    );

    return chartMonthlyAggregatesFromRows(
      rows: rows,
      referenceToday: bounds.referenceToday,
      windowStart: bounds.windowStart,
      months: months,
    );
  }

  /// Read-only footprint snapshot for My Data display (FR13).
  ///
  /// Does not trigger VACUUM or any write operations.
  @override
  Future<DatabaseFootprint> getFootprint({required String databasePath}) async {
    final sampleCount = await countStepSamples();
    final fileSizeBytes = _readDatabaseFileSize(databasePath);
    return DatabaseFootprint(
      sampleCount: sampleCount,
      fileSizeBytes: fileSizeBytes,
    );
  }

  int _readDatabaseFileSize(String databasePath) {
    if (databasePath == inMemoryDatabasePath) {
      return 0;
    }

    final file = File(databasePath);
    if (!file.existsSync()) {
      return 0;
    }

    return file.lengthSync();
  }

  /// Returns the total number of step samples in the database.
  @override
  Future<int> countStepSamples() async {
    final rows = await _session.run(
      (db) => db.rawQuery(
        '''
      SELECT COUNT(*) AS count
      FROM timeseries_samples
      WHERE type = ?
      ''',
        [kStepSampleType],
      ),
    );

    return (rows.single['count']! as num).toInt();
  }

  /// FR11 administrative downsampling — merges aged tiers and deletes finer rows.
  ///
  /// Owns [db.transaction] when [txn] is null. Pass [txn] to batch with other
  /// admin writes in the same transaction (D-24).
  Future<CompactionResult> downsampleStepSamples({Transaction? txn}) async {
    final timeSnapshot = clock.snapshot();
    final referenceNowUtc = timeSnapshot.nowUtc;
    final referenceZoneOffset = TimestampCodec.formatZoneOffset(
      timeSnapshot.zoneOffset,
    );
    final runner = SampleCompactionRunner();

    Future<CompactionResult> run(Transaction transaction) {
      final writer = TransactionCompactionWriter(transaction);
      return runner.runAllTiers(
        writer: writer,
        referenceNowUtc: referenceNowUtc,
        referenceZoneOffset: referenceZoneOffset,
      );
    }

    if (txn != null) {
      return run(txn);
    }

    late final CompactionResult result;
    await _session.run((db) async {
      await db.transaction((transaction) async {
        result = await run(transaction);
      });
    });
    return result;
  }

  /// Returns step sample counts grouped by resolution.
  Future<Map<String, int>> countStepSamplesByResolution() async {
    final rows = await _session.run(
      (db) => db.rawQuery(
        '''
      SELECT resolution, COUNT(*) AS count
      FROM timeseries_samples
      WHERE type = ?
      GROUP BY resolution
      ''',
        [kStepSampleType],
      ),
    );

    return {
      for (final row in rows)
        row['resolution']! as String: (row['count']! as num).toInt(),
    };
  }

  /// Latest step sample end time in UTC, or null when no step samples exist.
  @override
  Future<DateTime?> getLastIngestionUtc() async {
    final rows = await _session.run(
      (db) => db.rawQuery(
        '''
      SELECT MAX(end_time) AS last_end_time
      FROM timeseries_samples
      WHERE type = ?
      ''',
        [kStepSampleType],
      ),
    );
    final value = rows.single['last_end_time'] as String?;

    return value == null ? null : TimestampCodec.parseUtc(value);
  }
}
