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
    this.displayName,
    this.isStale = false,
    this.lastIngestionUtc,
    this.showCelebration = false,
  });

  final TodayStatus status;
  final int steps;
  final int goal;
  final String? displayName;
  final bool isStale;
  final DateTime? lastIngestionUtc;
  final bool showCelebration;

  const TodayState.loading() : this(status: TodayStatus.loading);

  const TodayState.noPermission() : this(status: TodayStatus.noPermission);

  factory TodayState.fromData({
    required int steps,
    required int goal,
    String? displayName,
    required bool isStale,
    DateTime? lastIngestionUtc,
    bool showCelebration = false,
  }) {
    return TodayState(
      status: _resolveStatus(steps: steps, goal: goal),
      steps: steps,
      goal: goal,
      displayName: displayName,
      isStale: isStale,
      lastIngestionUtc: lastIngestionUtc,
      showCelebration: showCelebration,
    );
  }

  TodayState copyWith({
    TodayStatus? status,
    int? steps,
    int? goal,
    Object? displayName = _unset,
    bool? isStale,
    DateTime? lastIngestionUtc,
    bool? showCelebration,
  }) {
    return TodayState(
      status: status ?? this.status,
      steps: steps ?? this.steps,
      goal: goal ?? this.goal,
      displayName: displayName == _unset
          ? this.displayName
          : displayName as String?,
      isStale: isStale ?? this.isStale,
      lastIngestionUtc: lastIngestionUtc ?? this.lastIngestionUtc,
      showCelebration: showCelebration ?? this.showCelebration,
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
