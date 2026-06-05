import '../../core/constants/preference_keys.dart';
import '../models/week_day_status.dart';

/// Raw derived activity metrics for the Today stats row (format in widget).
class ActivityMetricsSnapshot {
  const ActivityMetricsSnapshot({
    required this.distanceKm,
    required this.walkingDuration,
    required this.kcal,
  });

  final double distanceKm;
  final Duration walkingDuration;
  final int kcal;

  static const zero = ActivityMetricsSnapshot(
    distanceKm: 0,
    walkingDuration: Duration.zero,
    kcal: 0,
  );
}

enum TodayStatus {
  loading,
  noPermission,
  empty,
  progress,
  goalMet,
  overflow,
}

class TodayState {
  const TodayState({
    required this.status,
    this.steps = 0,
    this.goal = kDefaultStepGoal,
    this.isStale = false,
    this.lastIngestionUtc,
    this.showCelebration = false,
    this.weekDays = const [],
    this.activityMetrics = ActivityMetricsSnapshot.zero,
    this.heightCm,
    this.weightKg,
    this.foregroundCatchUp = false,
    this.catchUpTargetSteps,
  });

  final TodayStatus status;
  final int steps;
  final int goal;
  final bool isStale;
  final DateTime? lastIngestionUtc;
  final bool showCelebration;
  final List<WeekDayStatus> weekDays;
  final ActivityMetricsSnapshot activityMetrics;
  final int? heightCm;
  final double? weightKg;

  /// When true, [GoalRing] plays a full count-up after returning from background.
  final bool foregroundCatchUp;

  /// Resume target while [foregroundCatchUp] is true — [steps] stays at the
  /// last in-session value until the catch-up animation completes.
  final int? catchUpTargetSteps;

  const TodayState.loading() : this(status: TodayStatus.loading);

  const TodayState.noPermission() : this(status: TodayStatus.noPermission);

  factory TodayState.fromData({
    required int steps,
    required int goal,
    required bool isStale,
    DateTime? lastIngestionUtc,
    bool showCelebration = false,
    List<WeekDayStatus> weekDays = const [],
    ActivityMetricsSnapshot activityMetrics = ActivityMetricsSnapshot.zero,
    int? heightCm,
    double? weightKg,
    bool foregroundCatchUp = false,
    int? catchUpTargetSteps,
  }) {
    return TodayState(
      status: _resolveStatus(steps: steps, goal: goal),
      steps: steps,
      goal: goal,
      isStale: isStale,
      lastIngestionUtc: lastIngestionUtc,
      showCelebration: showCelebration,
      weekDays: weekDays,
      activityMetrics: activityMetrics,
      heightCm: heightCm,
      weightKg: weightKg,
      foregroundCatchUp: foregroundCatchUp,
      catchUpTargetSteps: catchUpTargetSteps,
    );
  }

  TodayState copyWith({
    TodayStatus? status,
    int? steps,
    int? goal,
    bool? isStale,
    DateTime? lastIngestionUtc,
    bool? showCelebration,
    List<WeekDayStatus>? weekDays,
    ActivityMetricsSnapshot? activityMetrics,
    Object? heightCm = _unset,
    Object? weightKg = _unset,
    bool? foregroundCatchUp,
    Object? catchUpTargetSteps = _unset,
  }) {
    return TodayState(
      status: status ?? this.status,
      steps: steps ?? this.steps,
      goal: goal ?? this.goal,
      isStale: isStale ?? this.isStale,
      lastIngestionUtc: lastIngestionUtc ?? this.lastIngestionUtc,
      showCelebration: showCelebration ?? this.showCelebration,
      weekDays: weekDays ?? this.weekDays,
      activityMetrics: activityMetrics ?? this.activityMetrics,
      heightCm: heightCm == _unset ? this.heightCm : heightCm as int?,
      weightKg: weightKg == _unset ? this.weightKg : weightKg as double?,
      foregroundCatchUp: foregroundCatchUp ?? this.foregroundCatchUp,
      catchUpTargetSteps: catchUpTargetSteps == _unset
          ? this.catchUpTargetSteps
          : catchUpTargetSteps as int?,
    );
  }

  static TodayStatus _resolveStatus({required int steps, required int goal}) {
    if (steps > goal) {
      return TodayStatus.overflow;
    }
    if (steps == goal && goal > 0) {
      return TodayStatus.goalMet;
    }
    if (steps > 0) {
      return TodayStatus.progress;
    }
    return TodayStatus.empty;
  }

  /// Arc sweep ratio for the goal ring, capped at 100%.
  double get progressRatio {
    if (goal <= 0) {
      return 0;
    }
    return (steps / goal).clamp(0.0, 1.0);
  }
}

const _unset = Object();
