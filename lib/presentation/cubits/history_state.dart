import '../../core/constants/preference_keys.dart';
import '../../data/models/chart_day_aggregate.dart';
import '../../data/models/chart_month_aggregate.dart';

enum HistoryStatus { loading, empty, ready }

enum HistoryPeriod {
  days7,
  days30,
  /// Twelve calendar months — [dayCount] is not applicable; use monthly cache.
  months12;

  int get dayCount => switch (this) {
    HistoryPeriod.days7 => 7,
    HistoryPeriod.days30 => 30,
    HistoryPeriod.months12 =>
      throw StateError('dayCount is not defined for months12'),
  };
}

enum TrendDirection { up, down, flat }

/// Per-day metrics cached for Trends period averages (newest-first order).
class TrendsDayMetrics {
  const TrendsDayMetrics({
    required this.localDay,
    required this.totalSteps,
    required this.dailyKcal,
  });

  final DateTime localDay;
  final int totalSteps;
  final int dailyKcal;
}

/// Peak step day in the active 7d/30d window.
class TrendsPeakDay {
  const TrendsPeakDay({
    required this.localDay,
    required this.totalSteps,
  });

  final DateTime localDay;
  final int totalSteps;
}

/// Arithmetic mean kcal and steps for the active 7d/30d window.
class TrendsPeriodAverages {
  const TrendsPeriodAverages({
    required this.averageKcal,
    required this.averageSteps,
  });

  final int averageKcal;
  final int averageSteps;
}

class TrendSnapshot {
  const TrendSnapshot({
    required this.direction,
    this.percent,
  });

  final TrendDirection direction;
  final int? percent;
}

/// Weekday with the highest average steps in the 30-day insight window.
class TrendsMostActiveWeekday {
  const TrendsMostActiveWeekday({
    required this.weekday,
    required this.averageSteps,
  });

  /// `DateTime.monday` … `DateTime.sunday`.
  final int weekday;
  final int averageSteps;
}

/// Consecutive calendar days at or above the resolved daily goal (newest-first).
class TrendsGoalStreak {
  const TrendsGoalStreak({required this.consecutiveDays});

  /// Zero means no active streak.
  final int consecutiveDays;
}

/// Drives calm empty states for local Trends insight cards.
class TrendsInsightAvailability {
  const TrendsInsightAvailability({
    required this.hasMinimumHistory,
    required this.hasWeeklyComparison,
  });

  final bool hasMinimumHistory;
  final bool hasWeeklyComparison;
}

class HistoryState {
  const HistoryState({
    required this.status,
    this.period = HistoryPeriod.days7,
    this.chartPoints = const [],
    this.monthlyChartPoints = const [],
    this.dailyGoal = kDefaultStepGoal,
    this.goalsByDay = const {},
    this.trend,
    this.periodAverages,
    this.peakDay,
    this.mostActiveWeekday,
    this.goalStreak,
    this.insightAvailability,
  });

  final HistoryStatus status;
  final HistoryPeriod period;
  final List<ChartDayAggregate> chartPoints;
  /// Monthly averages for 12-month view (oldest-first); empty when not months12.
  final List<ChartMonthAggregate> monthlyChartPoints;
  /// Today's resolved goal — empty-state fallback and goal-line default.
  final int dailyGoal;
  /// Resolved goal per local day (`YYYY-MM-DD`) for chart bar semantics.
  final Map<String, int> goalsByDay;
  final TrendSnapshot? trend;
  /// Average kcal/steps for active period; null when loading or empty.
  final TrendsPeriodAverages? periodAverages;
  /// Peak step day for active period; null when loading, empty, or zero-step window.
  final TrendsPeakDay? peakDay;
  final TrendsMostActiveWeekday? mostActiveWeekday;
  final TrendsGoalStreak? goalStreak;
  final TrendsInsightAvailability? insightAvailability;

  const HistoryState.loading() : this(status: HistoryStatus.loading);

  factory HistoryState.empty({
    HistoryPeriod period = HistoryPeriod.days7,
    int dailyGoal = kDefaultStepGoal,
    Map<String, int> goalsByDay = const {},
  }) {
    return HistoryState(
      status: HistoryStatus.empty,
      period: period,
      dailyGoal: dailyGoal,
      goalsByDay: goalsByDay,
    );
  }

  factory HistoryState.ready({
    HistoryPeriod period = HistoryPeriod.days7,
    required List<ChartDayAggregate> chartPoints,
    List<ChartMonthAggregate> monthlyChartPoints = const [],
    required int dailyGoal,
    Map<String, int> goalsByDay = const {},
    TrendSnapshot? trend,
    TrendsPeriodAverages? periodAverages,
    TrendsPeakDay? peakDay,
    TrendsMostActiveWeekday? mostActiveWeekday,
    TrendsGoalStreak? goalStreak,
    TrendsInsightAvailability? insightAvailability,
  }) {
    return HistoryState(
      status: HistoryStatus.ready,
      period: period,
      chartPoints: chartPoints,
      monthlyChartPoints: monthlyChartPoints,
      dailyGoal: dailyGoal,
      goalsByDay: goalsByDay,
      trend: trend,
      periodAverages: periodAverages,
      peakDay: peakDay,
      mostActiveWeekday: mostActiveWeekday,
      goalStreak: goalStreak,
      insightAvailability: insightAvailability,
    );
  }

  HistoryState copyWith({
    HistoryStatus? status,
    HistoryPeriod? period,
    List<ChartDayAggregate>? chartPoints,
    List<ChartMonthAggregate>? monthlyChartPoints,
    int? dailyGoal,
    Map<String, int>? goalsByDay,
    TrendSnapshot? trend,
    TrendsPeriodAverages? periodAverages,
    TrendsPeakDay? peakDay,
    TrendsMostActiveWeekday? mostActiveWeekday,
    TrendsGoalStreak? goalStreak,
    TrendsInsightAvailability? insightAvailability,
  }) {
    return HistoryState(
      status: status ?? this.status,
      period: period ?? this.period,
      chartPoints: chartPoints ?? this.chartPoints,
      monthlyChartPoints: monthlyChartPoints ?? this.monthlyChartPoints,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      goalsByDay: goalsByDay ?? this.goalsByDay,
      trend: trend ?? this.trend,
      periodAverages: periodAverages ?? this.periodAverages,
      peakDay: peakDay ?? this.peakDay,
      mostActiveWeekday: mostActiveWeekday ?? this.mostActiveWeekday,
      goalStreak: goalStreak ?? this.goalStreak,
      insightAvailability: insightAvailability ?? this.insightAvailability,
    );
  }
}

