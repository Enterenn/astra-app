import '../../core/time/local_day_calculator.dart';
import '../../core/time/timestamp_codec.dart';
import '../../data/models/normalized_step_bucket.dart';
import '../../data/models/timeseries_sample_model.dart';

const kFiveMinuteBucketsPerHour = 12;
const kHourlyBucketsPerDay = 24;
const kFiveMinuteBucketsPerDay = 288;

/// FR11 tier 1: the 30 most recent local calendar days (age 0–29).
const kTierOneMaxAgeDays = 30;

/// FR11 tier 2 lower bound: compaction starts at age 30 (the 31st-most-recent day).
const kTierTwoMinAgeDays = 30;

/// FR11 tier 3 lower bound: daily compaction at age 365+.
const kTierThreeMinAgeDays = 365;

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
      kTierTwoMinAgeDays;
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
  return age >= kTierTwoMinAgeDays && age < kTierThreeMinAgeDays;
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
      kTierThreeMinAgeDays;
}

/// Catch-up for 5-minute rows that aged past tier 3 without prior hourly compaction.
bool isTierThreeFiveMinuteSample({
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
      kTierThreeMinAgeDays;
}

bool _sameSampleIdentity(TimeseriesSampleModel a, TimeseriesSampleModel b) {
  return a.provider == b.provider &&
      a.deviceId == b.deviceId &&
      a.zoneOffset == b.zoneOffset;
}

bool _areConsecutiveFiveMinuteBuckets(
  TimeseriesSampleModel previous,
  TimeseriesSampleModel next,
) {
  return next.startTimeUtc.difference(previous.startTimeUtc).inMinutes == 5;
}

bool _areConsecutiveHourlyBuckets(
  TimeseriesSampleModel previous,
  TimeseriesSampleModel next,
) {
  return next.startTimeUtc.difference(previous.startTimeUtc).inHours == 1;
}

/// Splits sorted 5-minute buckets into contiguous runs within the same local hour.
List<List<TimeseriesSampleModel>> contiguousFiveMinuteHourGroups(
  List<TimeseriesSampleModel> sortedBuckets,
) {
  if (sortedBuckets.isEmpty) {
    return const [];
  }

  final groups = <List<TimeseriesSampleModel>>[];
  var current = <TimeseriesSampleModel>[sortedBuckets.first];

  for (var index = 1; index < sortedBuckets.length; index++) {
    final previous = sortedBuckets[index - 1];
    final next = sortedBuckets[index];
    final sameHour =
        fiveMinuteGroupKey(previous) == fiveMinuteGroupKey(next) &&
        _sameSampleIdentity(previous, next);
    final consecutive = _areConsecutiveFiveMinuteBuckets(previous, next);

    if (sameHour && consecutive) {
      current.add(next);
    } else {
      groups.add(current);
      current = [next];
    }
  }

  groups.add(current);
  return groups;
}

/// Splits sorted hourly buckets into contiguous runs within the same local day.
List<List<TimeseriesSampleModel>> contiguousHourlyDayGroups(
  List<TimeseriesSampleModel> sortedBuckets,
) {
  if (sortedBuckets.isEmpty) {
    return const [];
  }

  final groups = <List<TimeseriesSampleModel>>[];
  var current = <TimeseriesSampleModel>[sortedBuckets.first];

  for (var index = 1; index < sortedBuckets.length; index++) {
    final previous = sortedBuckets[index - 1];
    final next = sortedBuckets[index];
    final sameDay =
        hourlyGroupKey(previous) == hourlyGroupKey(next) &&
        _sameSampleIdentity(previous, next);
    final consecutive = _areConsecutiveHourlyBuckets(previous, next);

    if (sameDay && consecutive) {
      current.add(next);
    } else {
      groups.add(current);
      current = [next];
    }
  }

  groups.add(current);
  return groups;
}

/// Splits sorted 5-minute buckets into contiguous runs within the same local day.
List<List<TimeseriesSampleModel>> contiguousFiveMinuteDayGroups(
  List<TimeseriesSampleModel> sortedBuckets,
) {
  if (sortedBuckets.isEmpty) {
    return const [];
  }

  final groups = <List<TimeseriesSampleModel>>[];
  var current = <TimeseriesSampleModel>[sortedBuckets.first];

  for (var index = 1; index < sortedBuckets.length; index++) {
    final previous = sortedBuckets[index - 1];
    final next = sortedBuckets[index];
    final sameDay =
        fiveMinuteDayGroupKey(previous) == fiveMinuteDayGroupKey(next) &&
        _sameSampleIdentity(previous, next);
    final consecutive = _areConsecutiveFiveMinuteBuckets(previous, next);

    if (sameDay && consecutive) {
      current.add(next);
    } else {
      groups.add(current);
      current = [next];
    }
  }

  groups.add(current);
  return groups;
}

bool isCompleteFiveMinuteHourGroup(List<TimeseriesSampleModel> buckets) {
  if (buckets.length != kFiveMinuteBucketsPerHour) {
    return false;
  }

  final sortedBuckets = [...buckets]
    ..sort((a, b) => a.startTimeUtc.compareTo(b.startTimeUtc));
  final first = sortedBuckets.first;

  for (var index = 1; index < sortedBuckets.length; index++) {
    final previous = sortedBuckets[index - 1];
    final next = sortedBuckets[index];
    if (!_sameSampleIdentity(previous, next)) {
      return false;
    }
    if (fiveMinuteGroupKey(previous) != fiveMinuteGroupKey(next)) {
      return false;
    }
    if (!_areConsecutiveFiveMinuteBuckets(previous, next)) {
      return false;
    }
  }

  return fiveMinuteGroupKey(first) ==
      fiveMinuteGroupKey(sortedBuckets.last);
}

bool isCompleteHourlyDayGroup(List<TimeseriesSampleModel> buckets) {
  if (buckets.length != kHourlyBucketsPerDay) {
    return false;
  }

  final sortedBuckets = [...buckets]
    ..sort((a, b) => a.startTimeUtc.compareTo(b.startTimeUtc));
  final first = sortedBuckets.first;

  for (var index = 1; index < sortedBuckets.length; index++) {
    final previous = sortedBuckets[index - 1];
    final next = sortedBuckets[index];
    if (!_sameSampleIdentity(previous, next)) {
      return false;
    }
    if (hourlyGroupKey(previous) != hourlyGroupKey(next)) {
      return false;
    }
    if (!_areConsecutiveHourlyBuckets(previous, next)) {
      return false;
    }
  }

  return hourlyGroupKey(first) == hourlyGroupKey(sortedBuckets.last);
}

bool isCompleteFiveMinuteDayGroup(List<TimeseriesSampleModel> buckets) {
  if (buckets.length != kFiveMinuteBucketsPerDay) {
    return false;
  }

  final sortedBuckets = [...buckets]
    ..sort((a, b) => a.startTimeUtc.compareTo(b.startTimeUtc));
  final first = sortedBuckets.first;

  for (var index = 1; index < sortedBuckets.length; index++) {
    final previous = sortedBuckets[index - 1];
    final next = sortedBuckets[index];
    if (!_sameSampleIdentity(previous, next)) {
      return false;
    }
    if (fiveMinuteDayGroupKey(previous) != fiveMinuteDayGroupKey(next)) {
      return false;
    }
    if (!_areConsecutiveFiveMinuteBuckets(previous, next)) {
      return false;
    }
  }

  return fiveMinuteDayGroupKey(first) ==
      fiveMinuteDayGroupKey(sortedBuckets.last);
}

TimeseriesSampleModel mergeFiveMinuteBucketsToHourly({
  required List<TimeseriesSampleModel> buckets,
  required String newId,
}) {
  if (!isCompleteFiveMinuteHourGroup(buckets)) {
    throw ArgumentError.value(
      buckets,
      'buckets',
      'must be 12 consecutive 5-minute buckets within one local hour',
    );
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
  if (!isCompleteHourlyDayGroup(buckets)) {
    throw ArgumentError.value(
      buckets,
      'buckets',
      'must be 24 consecutive hourly buckets within one local day',
    );
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

/// Direct catch-up merge for orphaned 5-minute rows aged past tier 3.
TimeseriesSampleModel mergeFiveMinuteBucketsToDaily({
  required List<TimeseriesSampleModel> buckets,
  required String newId,
}) {
  if (!isCompleteFiveMinuteDayGroup(buckets)) {
    throw ArgumentError.value(
      buckets,
      'buckets',
      'must be 288 consecutive 5-minute buckets within one local day',
    );
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

String fiveMinuteDayGroupKey(TimeseriesSampleModel sample) {
  final localDay = localDayBucketKey(
    startTimeUtc: sample.startTimeUtc,
    zoneOffset: sample.zoneOffset,
  );
  return '${sample.provider}|${sample.deviceId}|${sample.zoneOffset}|'
      '${localDay.toIso8601String()}';
}
