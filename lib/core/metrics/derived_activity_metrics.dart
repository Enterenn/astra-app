/// Derived activity metrics from step count and optional profile inputs.
///
/// Formulas locked 2026-06-05 (supersedes PRD FR-33 raw bucket-sum and
/// simplified kcal coefficient). See Story 6.1 calculation design review.
///
/// - **Distance:** `displaySteps × stride_m / 1000` — stride from height or 0.76 m default.
/// - **Walking time:** threshold 40 steps/bucket + proportional `min(5, steps/100)` min.
/// - **Kcal:** ACSM MET `(MET×3.5×weight/200) × walking_minutes`.
library;

import '../../data/models/timeseries_sample_model.dart';

/// Immutable snapshot of computed activity metrics (raw values; format in UI).
class DerivedActivityResult {
  const DerivedActivityResult({
    required this.distanceKm,
    required this.walkingDuration,
    required this.kcal,
  });

  final double distanceKm;
  final Duration walkingDuration;
  final int kcal;

  static const zero = DerivedActivityResult(
    distanceKm: 0,
    walkingDuration: Duration.zero,
    kcal: 0,
  );
}

/// Pure-Dart metrics engine — no Flutter imports.
abstract final class DerivedActivityMetrics {
  static const double kDefaultStrideM = 0.76;
  static const double kStrideHeightFactor = 0.414;
  static const double kDefaultWeightKg = 70.0;
  static const double kWalkingMet = 3.5;
  static const int kMinActiveBucketSteps = 40;
  static const double kWalkingCadenceSpm = 100.0;
  static const double kMaxBucketMinutes = 5.0;
  static const double kMetOxygenFactor = 3.5;
  static const double kMetCalorieDivisor = 200.0;

  /// Full compute: distance from [displaySteps], time/kcal from [activeBuckets].
  static DerivedActivityResult compute({
    required int displaySteps,
    required List<TimeseriesSampleModel> activeBuckets,
    int? heightCm,
    double? weightKg,
  }) {
    final distanceKm = computeDistanceKm(
      displaySteps: displaySteps,
      heightCm: heightCm,
    );
    final walkingMinutes = _walkingMinutes(activeBuckets);
    final walkingDuration = Duration(
      seconds: (walkingMinutes * 60).round(),
    );
    final effectiveWeight = weightKg ?? kDefaultWeightKg;
    final kcalPerMinute =
        (kWalkingMet * kMetOxygenFactor * effectiveWeight) / kMetCalorieDivisor;
    final kcal = (kcalPerMinute * walkingMinutes).round();

    return DerivedActivityResult(
      distanceKm: distanceKm,
      walkingDuration: walkingDuration,
      kcal: kcal,
    );
  }

  /// Distance-only recompute for live step overlay (no bucket fetch).
  static double computeDistanceKm({
    required int displaySteps,
    int? heightCm,
  }) {
    final strideM = _strideMeters(heightCm);
    return displaySteps * strideM / 1000.0;
  }

  static double _strideMeters(int? heightCm) {
    if (heightCm != null && heightCm > 0) {
      return (heightCm / 100.0) * kStrideHeightFactor;
    }
    return kDefaultStrideM;
  }

  static double _walkingMinutes(List<TimeseriesSampleModel> activeBuckets) {
    var totalMinutes = 0.0;
    for (final bucket in activeBuckets) {
      final steps = bucket.value.toDouble();
      if (steps < kMinActiveBucketSteps) {
        continue;
      }
      final bucketMinutes = (steps / kWalkingCadenceSpm).clamp(
        0.0,
        kMaxBucketMinutes,
      );
      totalMinutes += bucketMinutes;
    }
    return totalMinutes;
  }
}
