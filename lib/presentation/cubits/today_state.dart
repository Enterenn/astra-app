import '../../core/constants/preference_keys.dart';

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
  });

  final TodayStatus status;
  final int steps;
  final int goal;
  final bool isStale;
  final DateTime? lastIngestionUtc;

  const TodayState.loading() : this(status: TodayStatus.loading);

  const TodayState.noPermission() : this(status: TodayStatus.noPermission);

  factory TodayState.fromData({
    required int steps,
    required int goal,
    required bool isStale,
    DateTime? lastIngestionUtc,
  }) {
    return TodayState(
      status: _resolveStatus(steps: steps, goal: goal),
      steps: steps,
      goal: goal,
      isStale: isStale,
      lastIngestionUtc: lastIngestionUtc,
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
