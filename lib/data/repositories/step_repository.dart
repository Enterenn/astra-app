import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/preference_keys.dart';
import '../../core/database/astra_database_session.dart';
import '../../core/lifecycle/sample_compaction_runner.dart';
import '../../core/time/local_day_formatter.dart';
import '../../core/time/local_day_calculator.dart';
import '../../core/time/time_provider.dart';
import '../../core/time/timestamp_codec.dart';
import '../csv/timeseries_csv_codec.dart';
import '../models/chart_day_aggregate.dart';
import '../models/database_footprint.dart';
import '../models/import_result.dart';
import '../models/normalized_step_bucket.dart';
import '../models/timeseries_sample_model.dart';
import 'ingestion_baseline_repository.dart';

class StepRepository {
  StepRepository({
    required this.clock,
    AstraDatabaseSession? session,
    Database? db,
    String databasePath = inMemoryDatabasePath,
    Uuid? uuid,
  }) : _session =
           session ??
           AstraDatabaseSession(
             databasePath: databasePath,
             initial: db!,
           ),
       _uuid = uuid ?? const Uuid(),
       assert(session != null || db != null);

  final AstraDatabaseSession _session;
  final TimeProvider clock;
  final Uuid _uuid;

  Database get db => _session.database;

  Future<T> _run<T>(Future<T> Function(Database db) action) =>
      _session.withRetry(action);

  /// Persists an ingestion bucket from the background collection pipeline only.
  ///
  /// On bucket identity conflict, [bucket.value] is **added** to the stored total
  /// (per-collect increment), not replaced. Production callers must be limited to
  /// `BackgroundCollector` once Story 2.4 wires that component. Tests may call
  /// this method directly.
  Future<void> upsertIngestionBucket(NormalizedStepBucket bucket) async {
    final model = TimeseriesSampleModel.fromNormalizedBucket(
      bucket: bucket,
      id: _uuid.v4(),
    );
    final row = model.toMap();

    await _run(
      (db) => db.rawInsert(
        '''
      INSERT INTO timeseries_samples (
        id,
        start_time,
        end_time,
        type,
        value,
        unit,
        resolution,
        provider,
        device_id,
        zone_offset
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(provider, device_id, type, start_time, end_time, resolution)
      DO UPDATE SET value = timeseries_samples.value + excluded.value
      ''',
        [
          row['id'],
          row['start_time'],
          row['end_time'],
          row['type'],
          row['value'],
          row['unit'],
          row['resolution'],
          row['provider'],
          row['device_id'],
          row['zone_offset'],
        ],
      ),
    );
  }

  Future<int> getTodaySteps() async {
    final bounds = _todaySampleUtcBounds();
    final rows = await _run(
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

    return _finestResolutionTotal(byResolution);
  }

  /// Returns today's 5-minute step buckets with positive values for activity metrics.
  ///
  /// Only `resolution = '5min'` rows are included; coarser tiers for the same
  /// local day are excluded to prevent double-counting. The activity threshold
  /// (40 steps) is applied in [DerivedActivityMetrics], not in SQL.
  Future<List<TimeseriesSampleModel>> getTodayActiveBuckets() async {
    final bounds = _todaySampleUtcBounds();
    return getActiveBucketsForLocalDay(bounds.referenceToday);
  }

  /// Returns 5-minute step buckets with positive values for [localDay].
  ///
  /// Same SQL filters as [getTodayActiveBuckets]; per-row [LocalDayCalculator]
  /// filter uses the **parameter** day (not clock today).
  Future<List<TimeseriesSampleModel>> getActiveBucketsForLocalDay(
    DateTime localDay,
  ) async {
    final bounds = _sampleUtcBoundsForLocalDay(localDay);
    final rows = await _run(
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

  /// Returns the total steps for the finest resolution present in [byResolution].
  ///
  /// Resolution priority (finest first): 5min → hourly → daily.
  /// Prevents double-counting when mixed-resolution rows exist for the same period.
  static int _finestResolutionTotal(Map<String, int> byResolution) {
    for (final resolution in const [
      kFiveMinuteResolution,
      kHourlyResolution,
      kDailyResolution,
    ]) {
      final total = byResolution[resolution];
      if (total != null) {
        return total;
      }
    }
    return 0;
  }

  /// Conservative UTC window for today's rows before per-row [zone_offset] filtering.
  ///
  /// Uses reference local day ±1 day so extreme offsets (+14/−12) still match
  /// [LocalDayCalculator] semantics while excluding aged history via
  /// [idx_timeseries_query].
  ({DateTime referenceToday, DateTime lowerInclusive, DateTime upperExclusive})
  _todaySampleUtcBounds() {
    final timeSnapshot = clock.snapshot();
    final referenceToday = LocalDayCalculator.localDay(
      utc: timeSnapshot.nowUtc,
      zoneOffset: TimestampCodec.formatZoneOffset(timeSnapshot.zoneOffset),
    );
    final bounds = _sampleUtcBoundsForLocalDay(referenceToday);
    return (
      referenceToday: bounds.referenceLocalDay,
      lowerInclusive: bounds.lowerInclusive,
      upperExclusive: bounds.upperExclusive,
    );
  }

  /// UTC query window for [localDay] before per-row [zone_offset] filtering.
  ({DateTime referenceLocalDay, DateTime lowerInclusive, DateTime upperExclusive})
  _sampleUtcBoundsForLocalDay(DateTime localDay) {
    // Keep the same UTC semantics as [LocalDayCalculator.localDay], otherwise
    // equality checks (DateTime.utc) will fail.
    final referenceLocalDay =
        DateTime.utc(localDay.year, localDay.month, localDay.day);
    return (
      referenceLocalDay: referenceLocalDay,
      lowerInclusive: referenceLocalDay.subtract(const Duration(days: 1)),
      upperExclusive: referenceLocalDay.add(const Duration(days: 2)),
    );
  }

  /// Returns daily step totals for the History chart (7 or 30 day window).
  ///
  /// Aggregation runs in Dart using each row's stored [TimeseriesSampleModel.zoneOffset].
  /// Results are zero-filled for every calendar day in the window and sorted newest-first.
  Future<List<ChartDayAggregate>> getChartDailyAggregates({
    required int days,
  }) async {
    if (days != 7 && days != 30) {
      throw ArgumentError.value(days, 'days', 'Phase 0 supports 7 or 30 only');
    }

    final timeSnapshot = clock.snapshot();
    final referenceToday = LocalDayCalculator.localDay(
      utc: timeSnapshot.nowUtc,
      zoneOffset: TimestampCodec.formatZoneOffset(timeSnapshot.zoneOffset),
    );
    final windowStart = referenceToday.subtract(Duration(days: days - 1));

    final sqlLowerBoundUtc = windowStart.subtract(const Duration(days: 1));
    final rows = await _run(
      (db) => db.query(
        'timeseries_samples',
        where: 'type = ? AND start_time >= ?',
        whereArgs: [
          kStepSampleType,
          TimestampCodec.formatUtc(sqlLowerBoundUtc),
        ],
      ),
    );

    // Accumulate per (day, resolution) then use finest tier per day to prevent
    // double-counting when mixed-resolution rows exist (e.g. bad import).
    final byDayAndResolution = <DateTime, Map<String, int>>{};
    for (final row in rows) {
      final sample = TimeseriesSampleModel.fromMap(row);
      final rowLocalDay = LocalDayCalculator.localDay(
        utc: sample.startTimeUtc,
        zoneOffset: sample.zoneOffset,
      );
      if (rowLocalDay.isBefore(windowStart) ||
          rowLocalDay.isAfter(referenceToday)) {
        continue;
      }
      byDayAndResolution
          .putIfAbsent(rowLocalDay, () => {})
          .update(
            sample.resolution,
            (v) => v + sample.value.toInt(),
            ifAbsent: () => sample.value.toInt(),
          );
    }

    final results = <ChartDayAggregate>[];
    for (var i = 0; i < days; i++) {
      final day = referenceToday.subtract(Duration(days: i));
      results.add(
        ChartDayAggregate(
          localDay: day,
          totalSteps: _finestResolutionTotal(byDayAndResolution[day] ?? {}),
        ),
      );
    }
    return results;
  }

  /// Inserts pre-built sample rows in a single transaction.
  ///
  /// **Dev/test only** — only [DataInjectService] and unit tests may call this
  /// method. Production ingestion must use [upsertIngestionBucket].
  ///
  /// When [replaceExistingSteps] is true, existing `type='steps'` rows are
  /// deleted in the same transaction before inserts (atomic clear-and-replace).
  Future<void> insertDevSamplesBatch(
    List<TimeseriesSampleModel> samples, {
    bool replaceExistingSteps = false,
  }) async {
    assert(() {
      if (!kDebugMode) {
        throw StateError(
          'insertDevSamplesBatch is only available in debug builds',
        );
      }
      return true;
    }());

    await _run(
      (db) => db.transaction((txn) async {
        if (replaceExistingSteps) {
          await txn.delete(
            'timeseries_samples',
            where: 'type = ?',
            whereArgs: [kStepSampleType],
          );
        }

        for (final sample in samples) {
          final row = sample.toMap();
          await txn.insert('timeseries_samples', row);
        }
      }),
    );
  }

  /// Read-only footprint snapshot for My Data display (FR13).
  ///
  /// Does not trigger VACUUM or any write operations.
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
  Future<int> countStepSamples() async {
    final rows = await _run(
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
    final runner = SampleCompactionRunner(uuid: _uuid);

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
    await _run((db) async {
      await db.transaction((transaction) async {
        result = await run(transaction);
      });
    });
    return result;
  }

  /// Returns step sample counts grouped by resolution.
  Future<Map<String, int>> countStepSamplesByResolution() async {
    final rows = await _run(
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
  Future<DateTime?> getLastIngestionUtc() async {
    final rows = await _run(
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

  /// Exports all step samples to an OW-aligned CSV file (FR-19).
  ///
  /// Writes to [outputDirectory] with filename `astra-export-{yyyy-MM-dd}.csv`
  /// using the local calendar date from [clock]. Returns the absolute file path.
  /// Empty databases produce a header-only CSV.
  Future<String> exportCsv({required String outputDirectory}) async {
    // Yield so synchronous IO errors surface through the returned Future.
    await Future<void>.value();

    final dateStr = formatLocalDayIso(clock.snapshot());
    final filePath = p.join(outputDirectory, 'astra-export-$dateStr.csv');
    final file = File(filePath);
    final sink = file.openWrite();
    var succeeded = false;

    try {
      sink.writeln(TimeseriesCsvCodec.headerRow);

      const batchSize = 500;
      String? afterStartTime;
      String? afterId;
      while (true) {
        final rows = await _run(
          (db) => db.query(
            'timeseries_samples',
            where: afterStartTime == null
                ? 'type = ?'
                : 'type = ? AND (start_time > ? OR (start_time = ? AND id > ?))',
            whereArgs: afterStartTime == null
                ? [kStepSampleType]
                : [
                    kStepSampleType,
                    afterStartTime,
                    afterStartTime,
                    afterId,
                  ],
            orderBy: 'start_time ASC, id ASC',
            limit: batchSize,
          ),
        );

        if (rows.isEmpty) {
          break;
        }

        for (final row in rows) {
          final sample = TimeseriesSampleModel.fromMap(row);
          sink.writeln(TimeseriesCsvCodec.serializeRow(sample));
        }

        final lastRow = rows.last;
        afterStartTime = lastRow['start_time']! as String;
        afterId = lastRow['id']! as String;
        if (rows.length < batchSize) {
          break;
        }
      }
      succeeded = true;
    } finally {
      await sink.close();
      if (!succeeded && file.existsSync()) {
        await file.delete();
      }
    }

    return file.absolute.path;
  }

  /// Imports OW-aligned CSV rows in a single transaction (FR-30, D-16/D-24).
  ///
  /// Validates the entire file before any write. Merge-only: existing rows are
  /// not deleted; duplicate `id` or bucket identity increments [ImportResult.skippedCount].
  Future<ImportResult> importCsv({required String filePath}) async {
    await Future<void>.value();
    final samples = await TimeseriesCsvCodec.parseImportFile(filePath);
    return importSamples(samples);
  }

  /// Persists pre-validated samples in a single transaction (used after parse/confirm).
  Future<ImportResult> importSamples(List<TimeseriesSampleModel> samples) async {
    if (samples.isEmpty) {
      return const ImportResult(
        totalRowsInFile: 0,
        insertedCount: 0,
        skippedCount: 0,
      );
    }

    var insertedCount = 0;
    var skippedCount = 0;

    await _run(
      (db) => db.transaction((txn) async {
        for (final sample in samples) {
          final rowId = await txn.insert(
            'timeseries_samples',
            sample.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          if (rowId == 0) {
            skippedCount++;
          } else {
            insertedCount++;
          }
        }
      }),
    );

    return ImportResult(
      totalRowsInFile: samples.length,
      insertedCount: insertedCount,
      skippedCount: skippedCount,
    );
  }

  /// Wipes all health data and derived collection state in a single transaction (FR-20, D-24).
  ///
  /// Preserves setup preferences: daily goal, theme, onboarding, and future non-health keys.
  /// VACUUM / file shrink is the caller's responsibility via [DataLifecycleService].
  Future<void> purge({
    @visibleForTesting Future<void> Function(Transaction txn)? testHookAfterDeleteSamples,
  }) async {
    await _run(
      (db) => db.transaction((txn) async {
        await txn.delete('timeseries_samples');
        if (testHookAfterDeleteSamples != null) {
          await testHookAfterDeleteSamples(txn);
        }
        await IngestionBaselineRepository.clearAllBaselines(txn);
        for (final key in [
          kCelebrationShownDateKey,
          kGoalNotificationShownDateKey,
          kIngestionCollectLockKey,
          kLastDatabaseOptimizedAtKey,
        ]) {
          await txn.delete(
            'user_preferences',
            where: 'key = ?',
            whereArgs: [key],
          );
        }
      }),
    );
  }
}
