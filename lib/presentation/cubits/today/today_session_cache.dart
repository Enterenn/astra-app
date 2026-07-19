import 'dart:async';
import '../../models/week_day_status.dart';
import '../today_state.dart';

typedef ApplyTodaySnapshotFn = Future<void> Function({
  required int steps,
  required int goal,
  required bool isStale,
  DateTime? lastIngestionUtc,
  List<WeekDayStatus>? weekDays,
  ActivityMetricsSnapshot? activityMetrics,
  int? heightCm,
  double? weightKg,
  bool? allowDecrease,
  DateTime? selectedLocalDay,
  int? lastDisplayedSteps,
  bool? lastDisplayedStepsLoaded,
  bool? skipCelebration,
});

class TodaySessionCache {
  int? todaySteps;
  int? todayGoal;
  ActivityMetricsSnapshot? todayMetrics;
  String? lastAppliedLocalDay;
  bool hasUserSelectedLocalDay = false;
  int refreshGeneration = 0;
  Future<void>? refreshInFlight;
}
