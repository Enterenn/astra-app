import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/time/local_day_calculator.dart';
import '../core/time/time_provider.dart';
import '../core/time/timestamp_codec.dart';
import '../data/datasources/data_ingestion_source.dart';
import '../data/models/normalized_step_bucket.dart';
import '../data/models/timeseries_sample_model.dart';
import '../data/repositories/step_repository.dart';

const kDevInjectDayCount = 90;
const kDevInjectBucketsPerDay = 288;
const kDevInjectExpectedRowCount = kDevInjectDayCount * kDevInjectBucketsPerDay;

class DataInjectResult {
  const DataInjectResult({
    required this.daysInjected,
    required this.bucketsInserted,
    required this.anchorUtc,
  });

  final int daysInjected;
  final int bucketsInserted;
  final DateTime anchorUtc;
}

/// Dev-only service that writes synthetic step history for chart benchmarks.
class DataInjectService {
  DataInjectService({
    required this.repository,
    Random? rng,
    Uuid? uuid,
  }) : _rng = rng ?? Random(42),
       _uuid = uuid ?? const Uuid();

  final StepRepository repository;
  final Random _rng;
  final Uuid _uuid;

  Future<DataInjectResult> inject90Days({required TimeProvider clock}) async {
    final snapshot = clock.snapshot();
    final anchorUtc = snapshot.nowUtc;
    final zoneOffset = TimestampCodec.formatZoneOffset(snapshot.zoneOffset);
    final anchorLocalDay = LocalDayCalculator.localDay(
      utc: anchorUtc,
      zoneOffset: zoneOffset,
    );

    final samples = <TimeseriesSampleModel>[];
    for (var dayIndex = 0; dayIndex < kDevInjectDayCount; dayIndex++) {
      final dayOffset = kDevInjectDayCount - 1 - dayIndex;
      final localDay = anchorLocalDay.subtract(Duration(days: dayOffset));
      final bucketValues = _generateDailyBucketValues(_rng);

      for (var bucketIndex = 0; bucketIndex < kDevInjectBucketsPerDay; bucketIndex++) {
        final minuteOffset = bucketIndex * 5;
        final startTimeUtc = _localBucketStartUtc(
          localDay: localDay,
          minuteFromMidnight: minuteOffset,
          zoneOffset: zoneOffset,
        );
        final endTimeUtc = startTimeUtc.add(const Duration(minutes: 5));

        samples.add(
          TimeseriesSampleModel(
            id: _uuid.v4(),
            startTimeUtc: startTimeUtc,
            endTimeUtc: endTimeUtc,
            type: kStepSampleType,
            value: bucketValues[bucketIndex],
            unit: kStepSampleUnit,
            resolution: kFiveMinuteResolution,
            provider: kInternalPhoneProvider,
            deviceId: kSmartphoneDeviceId,
            zoneOffset: zoneOffset,
          ),
        );
      }
    }

    await repository.insertDevSamplesBatch(
      samples,
      replaceExistingSteps: true,
    );

    return DataInjectResult(
      daysInjected: kDevInjectDayCount,
      bucketsInserted: samples.length,
      anchorUtc: anchorUtc,
    );
  }
}

Future<DataInjectResult> runDevInject({
  required StepRepository repository,
  required TimeProvider clock,
  Random? rng,
}) async {
  if (!kDebugMode) {
    throw StateError('Dev inject is only available in debug builds');
  }

  return DataInjectService(
    repository: repository,
    rng: rng,
  ).inject90Days(clock: clock);
}

DateTime floorToFiveMinuteUtc(DateTime value) {
  final utc = value.toUtc();
  return DateTime.utc(
    utc.year,
    utc.month,
    utc.day,
    utc.hour,
    utc.minute - (utc.minute % 5),
  );
}

DateTime _localBucketStartUtc({
  required DateTime localDay,
  required int minuteFromMidnight,
  required String zoneOffset,
}) {
  final hour = minuteFromMidnight ~/ 60;
  final minute = minuteFromMidnight % 60;
  final localInstant = DateTime.utc(
    localDay.year,
    localDay.month,
    localDay.day,
    hour,
    minute,
  );

  return floorToFiveMinuteUtc(
    localInstant.subtract(TimestampCodec.parseZoneOffset(zoneOffset)),
  );
}

List<int> _generateDailyBucketValues(Random rng) {
  final targetDaily = 4000 + rng.nextInt(8001);
  final rawValues = List<int>.generate(288, (_) => rng.nextInt(251));
  var rawSum = rawValues.fold<int>(0, (sum, value) => sum + value);
  if (rawSum == 0) {
    rawValues[0] = 1;
    rawSum = 1;
  }

  final scaledValues = rawValues
      .map((value) => (value * targetDaily / rawSum).floor())
      .toList();
  var scaledSum = scaledValues.fold<int>(0, (sum, value) => sum + value);

  var bucketIndex = 0;
  while (scaledSum < targetDaily) {
    scaledValues[bucketIndex % kDevInjectBucketsPerDay]++;
    scaledSum++;
    bucketIndex++;
  }

  return scaledValues;
}
