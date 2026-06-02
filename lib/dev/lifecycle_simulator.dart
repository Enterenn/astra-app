import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/time/time_provider.dart';
import '../core/time/timestamp_codec.dart';
import '../data/models/normalized_step_bucket.dart';
import '../data/models/timeseries_sample_model.dart';
import '../data/repositories/step_repository.dart';
import 'lifecycle_compaction.dart';

class LifecycleSimResult {
  const LifecycleSimResult({
    required this.rowsBefore,
    required this.rowsAfter,
    required this.fiveMinRemaining,
    required this.hourlyCreated,
    required this.dailyCreated,
  });

  final int rowsBefore;
  final int rowsAfter;
  final int fiveMinRemaining;
  final int hourlyCreated;
  final int dailyCreated;
}

/// Dev-only FR11 downsampling preview for chart benchmark datasets.
class LifecycleSimulator {
  LifecycleSimulator({
    required this.db,
    required this.repository,
    required this.clock,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final Database db;
  final StepRepository repository;
  final TimeProvider clock;
  final Uuid _uuid;

  Future<LifecycleSimResult> simulateDownsampling() async {
    final referenceNowUtc = clock.snapshot().nowUtc;
    final referenceZoneOffset = TimestampCodec.formatZoneOffset(
      clock.snapshot().zoneOffset,
    );
    final rowsBefore = await repository.countStepSamples();
    var hourlyCreated = 0;
    var dailyCreated = 0;

    await db.transaction((txn) async {
      hourlyCreated += await _compactTierTwoFiveMinuteToHourly(
        txn: txn,
        referenceNowUtc: referenceNowUtc,
        referenceZoneOffset: referenceZoneOffset,
      );

      dailyCreated += await _compactTierThreeHourlyToDaily(
        txn: txn,
        referenceNowUtc: referenceNowUtc,
        referenceZoneOffset: referenceZoneOffset,
      );

      dailyCreated += await _compactTierThreeFiveMinuteCatchUpToDaily(
        txn: txn,
        referenceNowUtc: referenceNowUtc,
        referenceZoneOffset: referenceZoneOffset,
      );
    });

    final countsByResolution = await repository.countStepSamplesByResolution();
    final rowsAfter = await repository.countStepSamples();

    return LifecycleSimResult(
      rowsBefore: rowsBefore,
      rowsAfter: rowsAfter,
      fiveMinRemaining: countsByResolution[kFiveMinuteResolution] ?? 0,
      hourlyCreated: hourlyCreated,
      dailyCreated: dailyCreated,
    );
  }

  Future<int> _compactTierTwoFiveMinuteToHourly({
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

  Future<int> _compactTierThreeHourlyToDaily({
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

  Future<int> _compactTierThreeFiveMinuteCatchUpToDaily({
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

Future<LifecycleSimResult> runDevLifecycleSimulate({
  required Database db,
  required StepRepository repository,
  required TimeProvider clock,
}) async {
  if (!kDebugMode) {
    throw StateError('Dev lifecycle simulate is only available in debug builds');
  }

  return LifecycleSimulator(
    db: db,
    repository: repository,
    clock: clock,
  ).simulateDownsampling();
}
