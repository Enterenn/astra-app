import 'package:astra_app/core/metrics/derived_activity_metrics.dart';
import 'package:astra_app/data/datasources/data_ingestion_source.dart';
import 'package:astra_app/data/models/normalized_step_bucket.dart';
import 'package:astra_app/data/models/timeseries_sample_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DerivedActivityMetrics.compute', () {
    test('uses default stride 0.76 m and weight 70 kg when profile unset', () {
      final result = DerivedActivityMetrics.compute(
        displaySteps: 10000,
        activeBuckets: const [],
      );

      expect(result.distanceKm, closeTo(7.6, 0.001));
      expect(result.walkingDuration, Duration.zero);
      expect(result.kcal, 0);
    });

    test('uses custom height for stride', () {
      final result = DerivedActivityMetrics.compute(
        displaySteps: 10000,
        activeBuckets: const [],
        heightCm: 175,
      );

      // 175/100 * 0.414 = 0.7245 m → 7.245 km
      expect(result.distanceKm, closeTo(7.245, 0.001));
    });

    test('zero buckets yields zero duration and kcal', () {
      final result = DerivedActivityMetrics.compute(
        displaySteps: 5000,
        activeBuckets: const [],
        weightKg: 80,
      );

      expect(result.walkingDuration, Duration.zero);
      expect(result.kcal, 0);
      expect(result.distanceKm, closeTo(3.8, 0.001));
    });

    test('ignores bucket below threshold (35 steps)', () {
      final buckets = [_bucket(value: 35)];
      final result = DerivedActivityMetrics.compute(
        displaySteps: 100,
        activeBuckets: buckets,
      );

      expect(result.walkingDuration, Duration.zero);
      expect(result.kcal, 0);
    });

    test('proportional bucket: 50 steps → 30 seconds', () {
      final buckets = [_bucket(value: 50)];
      final result = DerivedActivityMetrics.compute(
        displaySteps: 50,
        activeBuckets: buckets,
        weightKg: 70,
      );

      expect(result.walkingDuration, const Duration(seconds: 30));
      // 0.5 min × (3.5×3.5×70/200) = 0.5 × 4.2875 ≈ 2
      expect(result.kcal, 2);
    });

    test('capped bucket: 800 steps → 5 minutes', () {
      final buckets = [_bucket(value: 800)];
      final result = DerivedActivityMetrics.compute(
        displaySteps: 800,
        activeBuckets: buckets,
        weightKg: 70,
      );

      expect(result.walkingDuration, const Duration(minutes: 5));
      // 5 min × 4.2875 ≈ 21
      expect(result.kcal, 21);
    });

    test('multi-bucket sum', () {
      final buckets = [
        _bucket(value: 500),
        _bucket(value: 500),
        _bucket(value: 35), // ignored
        _bucket(value: 50),
      ];
      final result = DerivedActivityMetrics.compute(
        displaySteps: 1085,
        activeBuckets: buckets,
        weightKg: 70,
      );

      // 5 + 5 + 0 + 0.5 = 10.5 min → 630 s
      expect(result.walkingDuration, const Duration(seconds: 630));
    });

    test('corrected kcal differs from old 3.5×weight×hours formula', () {
      final buckets = [_bucket(value: 300)]; // 3 min
      final result = DerivedActivityMetrics.compute(
        displaySteps: 300,
        activeBuckets: buckets,
        weightKg: 70,
      );

      final oldWrong = (3.5 * 70 * (3 / 60)).round(); // 12
      final corrected = result.kcal; // 13
      expect(corrected, greaterThan(oldWrong));
      expect(corrected, 13);
    });

    test('60 min walking at 70 kg matches locked example (~257 kcal)', () {
      // 12 buckets × 500 steps = 12 × 5 min = 60 min
      final buckets = List.generate(12, (_) => _bucket(value: 500));
      final result = DerivedActivityMetrics.compute(
        displaySteps: 6000,
        activeBuckets: buckets,
        weightKg: 70,
      );

      expect(result.walkingDuration, const Duration(hours: 1));
      expect(result.kcal, 257);
    });
  });

  group('DerivedActivityMetrics.computeDistanceKm', () {
    test('live-step distance-only recompute without buckets', () {
      final defaultKm = DerivedActivityMetrics.computeDistanceKm(
        displaySteps: 10000,
      );
      expect(defaultKm, closeTo(7.6, 0.001));

      final customKm = DerivedActivityMetrics.computeDistanceKm(
        displaySteps: 8000,
        heightCm: 160,
      );
      // stride = 0.6624 → 5.2992 km
      expect(customKm, closeTo(5.2992, 0.001));
    });
  });
}

TimeseriesSampleModel _bucket({required int value}) {
  final start = DateTime.utc(2026, 6, 2, 10);
  return TimeseriesSampleModel.fromNormalizedBucket(
    bucket: NormalizedStepBucket(
      startTimeUtc: start,
      endTimeUtc: start.add(const Duration(minutes: 5)),
      value: value,
      provider: kInternalPhoneProvider,
      deviceId: kSmartphoneDeviceId,
      zoneOffset: '+02:00',
      resolution: kFiveMinuteResolution,
    ),
    id: 'test-$value',
  );
}
