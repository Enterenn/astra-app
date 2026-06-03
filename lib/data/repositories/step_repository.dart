import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/lifecycle/sample_compaction_runner.dart';
import '../../core/time/local_day_formatter.dart';
import '../../core/time/local_day_calculator.dart';
import '../../core/time/time_provider.dart';
import '../../core/time/timestamp_codec.dart';
import '../csv/timeseries_csv_codec.dart';
import '../models/chart_day_aggregate.dart';
import '../models/database_footprint.dart';
import '../models/normalized_step_bucket.dart';
import '../models/timeseries_sample_model.dart';

class StepRepository {
  StepRepository({required this.db, required this.clock, Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final Database db;
  final TimeProvider clock;
  final Uuid _uuid;

  /// Persists an ingestion bucket from the background collection pipeline only.
  ///
  /// Production callers must be limited to `BackgroundCollector` once Story 2.4
  /// wires that component. Tests may call this method directly.
  Future<void> upsertIngestionBucket(NormalizedStepBucket bucket) async {
    final model = TimeseriesSampleModel.fromNormalizedBucket(
      bucket: bucket,
      id: _uuid.v4(),
    );
    final row = model.toMap();

    await db.rawInsert(
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
      DO UPDATE SET value = excluded.value
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
    );
  }

  Future<int> getTodaySteps() async {
    final timeSnapshot = clock.snapshot();
    final referenceToday = LocalDayCalculator.localDay(
      utc: timeSnapshot.nowUtc,
      zoneOffset: TimestampCodec.formatZoneOffset(timeSnapshot.zoneOffset),
    );
    final rows = await db.query(
      'timeseries_samples',
      where: 'type = ?',
      whereArgs: [kStepSampleType],
    );

    var total = 0;
    for (final row in rows) {
      final sample = TimeseriesSampleModel.fromMap(row);
      final rowLocalDay = LocalDayCalculator.localDay(
        utc: sample.startTimeUtc,
        zoneOffset: sample.zoneOffset,
      );
      if (rowLocalDay == referenceToday) {
        total += sample.value.toInt();
      }
    }

    return total;
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
    final rows = await db.query(
      'timeseries_samples',
      where: 'type = ? AND start_time >= ?',
      whereArgs: [
        kStepSampleType,
        TimestampCodec.formatUtc(sqlLowerBoundUtc),
      ],
    );

    final totals = <DateTime, int>{};
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
      totals[rowLocalDay] = (totals[rowLocalDay] ?? 0) + sample.value.toInt();
    }

    final results = <ChartDayAggregate>[];
    for (var i = 0; i < days; i++) {
      final day = referenceToday.subtract(Duration(days: i));
      results.add(
        ChartDayAggregate(localDay: day, totalSteps: totals[day] ?? 0),
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

    await db.transaction((txn) async {
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
    });
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
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM timeseries_samples
      WHERE type = ?
      ''',
      [kStepSampleType],
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
    await db.transaction((transaction) async {
      result = await run(transaction);
    });
    return result;
  }

  /// Returns step sample counts grouped by resolution.
  Future<Map<String, int>> countStepSamplesByResolution() async {
    final rows = await db.rawQuery(
      '''
      SELECT resolution, COUNT(*) AS count
      FROM timeseries_samples
      WHERE type = ?
      GROUP BY resolution
      ''',
      [kStepSampleType],
    );

    return {
      for (final row in rows)
        row['resolution']! as String: (row['count']! as num).toInt(),
    };
  }

  /// Latest step sample end time in UTC, or null when no step samples exist.
  Future<DateTime?> getLastIngestionUtc() async {
    final rows = await db.rawQuery(
      '''
      SELECT MAX(end_time) AS last_end_time
      FROM timeseries_samples
      WHERE type = ?
      ''',
      [kStepSampleType],
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
        final rows = await db.query(
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
}
