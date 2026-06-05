import '../../core/constants/preference_keys.dart';
import '../models/week_day_status.dart';

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
    this.celebrationPreviewNonce = 0,
    this.goalPreviewNonce = 0,
    this.weekDays = const [],
  });

  final TodayStatus status;
  final int steps;
  final int goal;
  final String? displayName;
  final bool isStale;
  final DateTime? lastIngestionUtc;
  final bool showCelebration;
  final int celebrationPreviewNonce;
  /// Debug preview: increments while count-up → celebration sequence is active.
  final int goalPreviewNonce;
  final List<WeekDayStatus> weekDays;

  bool get isGoalPreviewActive => goalPreviewNonce > 0;

  const TodayState.loading() : this(status: TodayStatus.loading);

  const TodayState.noPermission() : this(status: TodayStatus.noPermission);

  factory TodayState.fromData({
    required int steps,
    required int goal,
    String? displayName,
    required bool isStale,
    DateTime? lastIngestionUtc,
    bool showCelebration = false,
    int celebrationPreviewNonce = 0,
    int goalPreviewNonce = 0,
    List<WeekDayStatus> weekDays = const [],
  }) {
    return TodayState(
      status: _resolveStatus(steps: steps, goal: goal),
      steps: steps,
      goal: goal,
      displayName: displayName,
      isStale: isStale,
      lastIngestionUtc: lastIngestionUtc,
      showCelebration: showCelebration,
      celebrationPreviewNonce: celebrationPreviewNonce,
      goalPreviewNonce: goalPreviewNonce,
      weekDays: weekDays,
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
    int? celebrationPreviewNonce,
    int? goalPreviewNonce,
    List<WeekDayStatus>? weekDays,
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
      celebrationPreviewNonce:
          celebrationPreviewNonce ?? this.celebrationPreviewNonce,
      goalPreviewNonce: goalPreviewNonce ?? this.goalPreviewNonce,
      weekDays: weekDays ?? this.weekDays,
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
