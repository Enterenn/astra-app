import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/time/local_day_calculator.dart';
import '../../core/time/time_provider.dart';
import '../../core/time/timestamp_codec.dart';
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
    final referenceToday = LocalDayCalculator.localDay(
      utc: clock.nowUtc(),
      zoneOffset: TimestampCodec.formatZoneOffset(clock.currentZoneOffset()),
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
}
