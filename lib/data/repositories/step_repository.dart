import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/time/local_day_calculator.dart';
import '../../core/time/time_provider.dart';
import '../../core/time/timestamp_codec.dart';
import '../models/chart_day_aggregate.dart';
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
}
