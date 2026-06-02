import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:astra_app/dev/lifecycle_compaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ageInDays tier boundaries', () {
    const referenceZoneOffset = '+02:00';
    final referenceNowUtc = DateTime.utc(2026, 6, 2, 12);

    test('age 29 is tier 1, age 30 is tier 2, age 365 is tier 3', () {
      final age29Start = DateTime.utc(2026, 5, 4, 10);
      final age30Start = DateTime.utc(2026, 5, 3, 10);
      final age365Start = DateTime.utc(2025, 6, 2, 10);

      expect(
        isTierOneSample(
          referenceNowUtc: referenceNowUtc,
          referenceZoneOffset: referenceZoneOffset,
          startTimeUtc: age29Start,
          sampleZoneOffset: referenceZoneOffset,
        ),
        isTrue,
      );
      expect(
        isTierTwoFiveMinuteSample(
          referenceNowUtc: referenceNowUtc,
          referenceZoneOffset: referenceZoneOffset,
          startTimeUtc: age30Start,
          sampleZoneOffset: referenceZoneOffset,
        ),
        isTrue,
      );
      expect(
        isTierThreeFiveMinuteSample(
          referenceNowUtc: referenceNowUtc,
          referenceZoneOffset: referenceZoneOffset,
          startTimeUtc: age365Start,
          sampleZoneOffset: referenceZoneOffset,
        ),
        isTrue,
      );
    });
  });

  group('merge validation', () {
    test('mergeFiveMinuteBucketsToHourly rejects gapped buckets', () {
      final buckets = List.generate(
        12,
        (index) => _sample(
          id: 'hour-$index',
          start: DateTime.utc(2026, 6, 2, 8, index * 5),
        ),
      );
      buckets[6] = _sample(
        id: 'gap',
        start: DateTime.utc(2026, 6, 2, 8, 40),
      );

      expect(isCompleteFiveMinuteHourGroup(buckets), isFalse);
      expect(
        () => mergeFiveMinuteBucketsToHourly(
          buckets: buckets,
          newId: 'merged',
        ),
        throwsArgumentError,
      );
    });

    test('mergeFiveMinuteBucketsToHourly accepts 12 consecutive buckets', () {
      final buckets = List.generate(
        12,
        (index) => _sample(
          id: 'hour-$index',
          start: DateTime.utc(2026, 6, 2, 6, index * 5),
        ),
      );

      expect(isCompleteFiveMinuteHourGroup(buckets), isTrue);

      final merged = mergeFiveMinuteBucketsToHourly(
        buckets: buckets,
        newId: 'merged-hour',
      );

      expect(merged.resolution, kHourlyResolution);
      expect(merged.value, 120);
      expect(merged.startTimeUtc, DateTime.utc(2026, 6, 2, 6));
      expect(merged.endTimeUtc, DateTime.utc(2026, 6, 2, 7));
    });

    test('contiguousFiveMinuteHourGroups splits at temporal gaps', () {
      final buckets = [
        _sample(id: 'a', start: DateTime.utc(2026, 6, 2, 8, 0)),
        _sample(id: 'b', start: DateTime.utc(2026, 6, 2, 8, 5)),
        _sample(id: 'c', start: DateTime.utc(2026, 6, 2, 8, 20)),
      ];

      final groups = contiguousFiveMinuteHourGroups(buckets);

      expect(groups, hasLength(2));
      expect(groups[0], hasLength(2));
      expect(groups[1], hasLength(1));
    });

    test('mergeFiveMinuteBucketsToDaily requires 288 consecutive buckets', () {
      final buckets = List.generate(
        287,
        (index) => _sample(
          id: 'day-$index',
          start: DateTime.utc(2026, 6, 2, 0, 0).add(Duration(minutes: index * 5)),
        ),
      );

      expect(isCompleteFiveMinuteDayGroup(buckets), isFalse);
      expect(
        () => mergeFiveMinuteBucketsToDaily(
          buckets: buckets,
          newId: 'merged-day',
        ),
        throwsArgumentError,
      );
    });
  });
}

TimeseriesSampleModel _sample({
  required String id,
  required DateTime start,
}) {
  return TimeseriesSampleModel(
    id: id,
    startTimeUtc: start,
    endTimeUtc: start.add(const Duration(minutes: 5)),
    type: kStepSampleType,
    value: 10,
    unit: kStepSampleUnit,
    resolution: kFiveMinuteResolution,
    provider: kInternalPhoneProvider,
    deviceId: kSmartphoneDeviceId,
    zoneOffset: '+02:00',
  );
}
