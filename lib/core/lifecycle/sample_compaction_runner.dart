import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/normalized_step_bucket.dart';
import '../../data/models/timeseries_sample_model.dart';
import 'lifecycle_compaction.dart';

/// Result of a full FR11 downsampling pass (tiers 2 + 3).
class CompactionRunResult {
  const CompactionRunResult({
    required this.hourlyCreated,
    required this.dailyCreated,
  });

  final int hourlyCreated;
  final int dailyCreated;
}

/// Shared FR11 compaction orchestration for dev preview and production downsample.
class SampleCompactionRunner {
  SampleCompactionRunner({
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  /// Runs tier 2 (5min→1hour), tier 3 (hourly→daily), and tier 3 catch-up passes.
  Future<CompactionRunResult> runAllTiers({
    required Transaction txn,
    required DateTime referenceNowUtc,
    required String referenceZoneOffset,
  }) async {
    final hourlyCreated = await compactTierTwoFiveMinuteToHourly(
      txn: txn,
      referenceNowUtc: referenceNowUtc,
      referenceZoneOffset: referenceZoneOffset,
    );

    var dailyCreated = await compactTierThreeHourlyToDaily(
      txn: txn,
      referenceNowUtc: referenceNowUtc,
      referenceZoneOffset: referenceZoneOffset,
    );

    dailyCreated += await compactTierThreeFiveMinuteCatchUpToDaily(
      txn: txn,
      referenceNowUtc: referenceNowUtc,
      referenceZoneOffset: referenceZoneOffset,
    );

    return CompactionRunResult(
      hourlyCreated: hourlyCreated,
      dailyCreated: dailyCreated,
    );
  }

  Future<int> compactTierTwoFiveMinuteToHourly({
    required Transaction txn,
    required DateTime referenceNowUtc,
    required String referenceZoneOffset,
  }) async {
    final fiveMinuteRows = await _loadStepSamples(
      txn: txn,
      resolution: kFiveMinuteResolution,
    );
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
        await txn.insert('timeseries_samples', hourlySample.toMap());
        hourlyCreated++;

        for (final bucket in hourBuckets) {
          await txn.delete(
            'timeseries_samples',
            where: 'id = ?',
            whereArgs: [bucket.id],
          );
        }
      }
    }

    return hourlyCreated;
  }

  Future<int> compactTierThreeHourlyToDaily({
    required Transaction txn,
    required DateTime referenceNowUtc,
    required String referenceZoneOffset,
  }) async {
    final hourlyRows = await _loadStepSamples(
      txn: txn,
      resolution: kHourlyResolution,
    );
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
        await txn.insert('timeseries_samples', dailySample.toMap());
        dailyCreated++;

        for (final bucket in dayBuckets) {
          await txn.delete(
            'timeseries_samples',
            where: 'id = ?',
            whereArgs: [bucket.id],
          );
        }
      }
    }

    return dailyCreated;
  }

  Future<int> compactTierThreeFiveMinuteCatchUpToDaily({
    required Transaction txn,
    required DateTime referenceNowUtc,
    required String referenceZoneOffset,
  }) async {
    final fiveMinuteRows = await _loadStepSamples(
      txn: txn,
      resolution: kFiveMinuteResolution,
    );
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
        await txn.insert('timeseries_samples', dailySample.toMap());
        dailyCreated++;

        for (final bucket in dayBuckets) {
          await txn.delete(
            'timeseries_samples',
            where: 'id = ?',
            whereArgs: [bucket.id],
          );
        }
      }
    }

    return dailyCreated;
  }

  Future<List<TimeseriesSampleModel>> _loadStepSamples({
    required Transaction txn,
    required String resolution,
  }) async {
    final rows = await txn.query(
      'timeseries_samples',
      where: 'type = ? AND resolution = ?',
      whereArgs: [kStepSampleType, resolution],
      orderBy: 'start_time ASC',
    );

    return rows.map(TimeseriesSampleModel.fromMap).toList();
  }
}
