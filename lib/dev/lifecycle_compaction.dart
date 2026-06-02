import '../../core/time/local_day_calculator.dart';
import '../../core/time/timestamp_codec.dart';
import '../../data/models/normalized_step_bucket.dart';
import '../../data/models/timeseries_sample_model.dart';

/// Local calendar-day age between reference now and a sample start time.
int ageInDays({
  required DateTime referenceNowUtc,
  required String referenceZoneOffset,
  required DateTime startTimeUtc,
  required String sampleZoneOffset,
}) {
  final referenceLocalDay = LocalDayCalculator.localDay(
    utc: referenceNowUtc,
    zoneOffset: referenceZoneOffset,
  );
  final sampleLocalDay = LocalDayCalculator.localDay(
    utc: startTimeUtc,
    zoneOffset: sampleZoneOffset,
  );
  return referenceLocalDay.difference(sampleLocalDay).inDays;
}

/// Local clock-hour bucket used to group 5-minute rows before compaction.
DateTime localHourBucketKey({
  required DateTime startTimeUtc,
  required String zoneOffset,
}) {
  final localInstant = startTimeUtc.toUtc().add(
    TimestampCodec.parseZoneOffset(zoneOffset),
  );
  return DateTime.utc(
    localInstant.year,
    localInstant.month,
    localInstant.day,
    localInstant.hour,
  );
}

/// Local calendar day bucket used to group hourly rows before daily compaction.
DateTime localDayBucketKey({
  required DateTime startTimeUtc,
  required String zoneOffset,
}) {
  final localInstant = startTimeUtc.toUtc().add(
    TimestampCodec.parseZoneOffset(zoneOffset),
  );
  return DateTime.utc(localInstant.year, localInstant.month, localInstant.day);
}

DateTime localBucketStartUtc({
  required DateTime localBucket,
  required String zoneOffset,
}) {
  return localBucket.subtract(TimestampCodec.parseZoneOffset(zoneOffset));
}

bool isTierOneSample({
  required DateTime referenceNowUtc,
  required String referenceZoneOffset,
  required DateTime startTimeUtc,
  required String sampleZoneOffset,
}) {
  return ageInDays(
        referenceNowUtc: referenceNowUtc,
        referenceZoneOffset: referenceZoneOffset,
        startTimeUtc: startTimeUtc,
        sampleZoneOffset: sampleZoneOffset,
      ) <
      30;
}

bool isTierTwoFiveMinuteSample({
  required DateTime referenceNowUtc,
  required String referenceZoneOffset,
  required DateTime startTimeUtc,
  required String sampleZoneOffset,
}) {
  final age = ageInDays(
    referenceNowUtc: referenceNowUtc,
    referenceZoneOffset: referenceZoneOffset,
    startTimeUtc: startTimeUtc,
    sampleZoneOffset: sampleZoneOffset,
  );
  return age >= 30 && age < 365;
}

bool isTierThreeHourlySample({
  required DateTime referenceNowUtc,
  required String referenceZoneOffset,
  required DateTime startTimeUtc,
  required String sampleZoneOffset,
}) {
  return ageInDays(
        referenceNowUtc: referenceNowUtc,
        referenceZoneOffset: referenceZoneOffset,
        startTimeUtc: startTimeUtc,
        sampleZoneOffset: sampleZoneOffset,
      ) >=
      365;
}

TimeseriesSampleModel mergeFiveMinuteBucketsToHourly({
  required List<TimeseriesSampleModel> buckets,
  required String newId,
}) {
  if (buckets.isEmpty) {
    throw ArgumentError.value(buckets, 'buckets', 'must not be empty');
  }

  final sortedBuckets = [...buckets]
    ..sort((a, b) => a.startTimeUtc.compareTo(b.startTimeUtc));
  final first = sortedBuckets.first;
  final localHour = localHourBucketKey(
    startTimeUtc: first.startTimeUtc,
    zoneOffset: first.zoneOffset,
  );
  final startTimeUtc = localBucketStartUtc(
    localBucket: localHour,
    zoneOffset: first.zoneOffset,
  );
  final endTimeUtc = startTimeUtc.add(const Duration(hours: 1));
  final totalValue = sortedBuckets.fold<int>(
    0,
    (sum, bucket) => sum + bucket.value.toInt(),
  );

  return TimeseriesSampleModel(
    id: newId,
    startTimeUtc: startTimeUtc,
    endTimeUtc: endTimeUtc,
    type: first.type,
    value: totalValue,
    unit: first.unit,
    resolution: kHourlyResolution,
    provider: first.provider,
    deviceId: first.deviceId,
    zoneOffset: first.zoneOffset,
  );
}

TimeseriesSampleModel mergeHourlyBucketsToDaily({
  required List<TimeseriesSampleModel> buckets,
  required String newId,
}) {
  if (buckets.isEmpty) {
    throw ArgumentError.value(buckets, 'buckets', 'must not be empty');
  }

  final sortedBuckets = [...buckets]
    ..sort((a, b) => a.startTimeUtc.compareTo(b.startTimeUtc));
  final first = sortedBuckets.first;
  final localDay = localDayBucketKey(
    startTimeUtc: first.startTimeUtc,
    zoneOffset: first.zoneOffset,
  );
  final startTimeUtc = localBucketStartUtc(
    localBucket: localDay,
    zoneOffset: first.zoneOffset,
  );
  final endTimeUtc = startTimeUtc.add(const Duration(days: 1));
  final totalValue = sortedBuckets.fold<int>(
    0,
    (sum, bucket) => sum + bucket.value.toInt(),
  );

  return TimeseriesSampleModel(
    id: newId,
    startTimeUtc: startTimeUtc,
    endTimeUtc: endTimeUtc,
    type: first.type,
    value: totalValue,
    unit: first.unit,
    resolution: kDailyResolution,
    provider: first.provider,
    deviceId: first.deviceId,
    zoneOffset: first.zoneOffset,
  );
}

String fiveMinuteGroupKey(TimeseriesSampleModel sample) {
  final localHour = localHourBucketKey(
    startTimeUtc: sample.startTimeUtc,
    zoneOffset: sample.zoneOffset,
  );
  return '${sample.provider}|${sample.deviceId}|${sample.zoneOffset}|'
      '${localHour.toIso8601String()}';
}

String hourlyGroupKey(TimeseriesSampleModel sample) {
  final localDay = localDayBucketKey(
    startTimeUtc: sample.startTimeUtc,
    zoneOffset: sample.zoneOffset,
  );
  return '${sample.provider}|${sample.deviceId}|${sample.zoneOffset}|'
      '${localDay.toIso8601String()}';
}
