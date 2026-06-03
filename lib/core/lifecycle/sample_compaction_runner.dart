import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/normalized_step_bucket.dart';
import '../../data/models/timeseries_sample_model.dart';
import 'lifecycle_compaction.dart';

/// Result of a full FR11 downsampling pass (tiers 2 + 3).
class CompactionResult {
  const CompactionResult({
    required this.hourlyCreated,
    required this.dailyCreated,
    required this.fiveMinDeleted,
    required this.hourlyDeleted,
  });

  final int hourlyCreated;
  final int dailyCreated;
  final int fiveMinDeleted;
  final int hourlyDeleted;
}

/// Administrative write surface for compaction — implemented by [StepRepository].
abstract class CompactionWriter {
  Future<List<TimeseriesSampleModel>> loadStepSamples(String resolution);

  Future<void> insertCompactedSample(TimeseriesSampleModel sample);

  Future<void> deleteStepSample(String id);
}

/// [CompactionWriter] backed by an open sqflite [Transaction].
class TransactionCompactionWriter implements CompactionWriter {
  TransactionCompactionWriter(this._txn);

  final Transaction _txn;

  @override
  Future<List<TimeseriesSampleModel>> loadStepSamples(String resolution) async {
    final rows = await _txn.query(
      'timeseries_samples',
      where: 'type = ? AND resolution = ?',
      whereArgs: [kStepSampleType, resolution],
      orderBy: 'start_time ASC',
    );

    return rows.map(TimeseriesSampleModel.fromMap).toList();
  }

  @override
  Future<void> insertCompactedSample(TimeseriesSampleModel sample) {
    return _txn.insert('timeseries_samples', sample.toMap());
  }

  @override
  Future<void> deleteStepSample(String id) {
    return _txn.delete(
      'timeseries_samples',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

/// Shared FR11 compaction orchestration for dev preview and production downsample.
class SampleCompactionRunner {
  SampleCompactionRunner({
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  /// Runs tier 2 (5min→1hour), tier 3 (hourly→daily), and tier 3 catch-up passes.
  Future<CompactionResult> runAllTiers({
    required CompactionWriter writer,
    required DateTime referenceNowUtc,
    required String referenceZoneOffset,
  }) async {
    final tierTwo = await compactTierTwoFiveMinuteToHourly(
      writer: writer,
      referenceNowUtc: referenceNowUtc,
      referenceZoneOffset: referenceZoneOffset,
    );

    final tierThreeHourly = await compactTierThreeHourlyToDaily(
      writer: writer,
      referenceNowUtc: referenceNowUtc,
      referenceZoneOffset: referenceZoneOffset,
    );

    final tierThreeCatchUp = await compactTierThreeFiveMinuteCatchUpToDaily(
      writer: writer,
      referenceNowUtc: referenceNowUtc,
      referenceZoneOffset: referenceZoneOffset,
    );

    return CompactionResult(
      hourlyCreated: tierTwo.hourlyCreated,
      dailyCreated: tierThreeHourly.dailyCreated + tierThreeCatchUp.dailyCreated,
      fiveMinDeleted: tierTwo.fiveMinDeleted + tierThreeCatchUp.fiveMinDeleted,
      hourlyDeleted: tierThreeHourly.hourlyDeleted,
    );
  }

  Future<({int hourlyCreated, int fiveMinDeleted})>
  compactTierTwoFiveMinuteToHourly({
    required CompactionWriter writer,
    required DateTime referenceNowUtc,
    required String referenceZoneOffset,
  }) async {
    final fiveMinuteRows = await writer.loadStepSamples(kFiveMinuteResolution);
    final groupedFiveMinute = <String, List<TimeseriesSampleModel>>{};

    for (final sample in fiveMinuteRows) {
      if (!isTierTwoFiveMinuteSample(
        referenceNowUtc: referenceNowUtc,
        referenceZoneOffset: referenceZoneOffset,
        startTimeUtc: sample.startTimeUtc,
        sampleZoneOffset: sample.zoneOffset,
      )) {
        continue;
      }

      groupedFiveMinute
          .putIfAbsent(fiveMinuteGroupKey(sample), () => [])
          .add(sample);
    }

    var hourlyCreated = 0;
    var fiveMinDeleted = 0;
    for (final buckets in groupedFiveMinute.values) {
      buckets.sort((a, b) => a.startTimeUtc.compareTo(b.startTimeUtc));
      for (final hourBuckets in contiguousFiveMinuteHourGroups(buckets)) {
        if (!isCompleteFiveMinuteHourGroup(hourBuckets)) {
          continue;
        }

        final hourlySample = mergeFiveMinuteBucketsToHourly(
          buckets: hourBuckets,
          newId: _uuid.v4(),
        );
        await writer.insertCompactedSample(hourlySample);
        hourlyCreated++;

        for (final bucket in hourBuckets) {
          await writer.deleteStepSample(bucket.id);
          fiveMinDeleted++;
        }
      }
    }

    return (hourlyCreated: hourlyCreated, fiveMinDeleted: fiveMinDeleted);
  }

  Future<({int dailyCreated, int hourlyDeleted})> compactTierThreeHourlyToDaily({
    required CompactionWriter writer,
    required DateTime referenceNowUtc,
    required String referenceZoneOffset,
  }) async {
    final hourlyRows = await writer.loadStepSamples(kHourlyResolution);
    final groupedHourly = <String, List<TimeseriesSampleModel>>{};

    for (final sample in hourlyRows) {
      if (!isTierThreeHourlySample(
        referenceNowUtc: referenceNowUtc,
        referenceZoneOffset: referenceZoneOffset,
        startTimeUtc: sample.startTimeUtc,
        sampleZoneOffset: sample.zoneOffset,
      )) {
        continue;
      }

      groupedHourly.putIfAbsent(hourlyGroupKey(sample), () => []).add(sample);
    }

    var dailyCreated = 0;
    var hourlyDeleted = 0;
    for (final buckets in groupedHourly.values) {
      buckets.sort((a, b) => a.startTimeUtc.compareTo(b.startTimeUtc));
      for (final dayBuckets in contiguousHourlyDayGroups(buckets)) {
        if (!isCompleteHourlyDayGroup(dayBuckets)) {
          continue;
        }

        final dailySample = mergeHourlyBucketsToDaily(
          buckets: dayBuckets,
          newId: _uuid.v4(),
        );
        await writer.insertCompactedSample(dailySample);
        dailyCreated++;

        for (final bucket in dayBuckets) {
          await writer.deleteStepSample(bucket.id);
          hourlyDeleted++;
        }
      }
    }

    return (dailyCreated: dailyCreated, hourlyDeleted: hourlyDeleted);
  }

  Future<({int dailyCreated, int fiveMinDeleted})>
  compactTierThreeFiveMinuteCatchUpToDaily({
    required CompactionWriter writer,
    required DateTime referenceNowUtc,
    required String referenceZoneOffset,
  }) async {
    final fiveMinuteRows = await writer.loadStepSamples(kFiveMinuteResolution);
    final groupedFiveMinute = <String, List<TimeseriesSampleModel>>{};

    for (final sample in fiveMinuteRows) {
      if (!isTierThreeFiveMinuteSample(
        referenceNowUtc: referenceNowUtc,
        referenceZoneOffset: referenceZoneOffset,
        startTimeUtc: sample.startTimeUtc,
        sampleZoneOffset: sample.zoneOffset,
      )) {
        continue;
      }

      groupedFiveMinute
          .putIfAbsent(fiveMinuteDayGroupKey(sample), () => [])
          .add(sample);
    }

    var dailyCreated = 0;
    var fiveMinDeleted = 0;
    for (final buckets in groupedFiveMinute.values) {
      buckets.sort((a, b) => a.startTimeUtc.compareTo(b.startTimeUtc));
      for (final dayBuckets in contiguousFiveMinuteDayGroups(buckets)) {
        if (!isCompleteFiveMinuteDayGroup(dayBuckets)) {
          continue;
        }

        final dailySample = mergeFiveMinuteBucketsToDaily(
          buckets: dayBuckets,
          newId: _uuid.v4(),
        );
        await writer.insertCompactedSample(dailySample);
        dailyCreated++;

        for (final bucket in dayBuckets) {
          await writer.deleteStepSample(bucket.id);
          fiveMinDeleted++;
        }
      }
    }

    return (dailyCreated: dailyCreated, fiveMinDeleted: fiveMinDeleted);
  }
}
