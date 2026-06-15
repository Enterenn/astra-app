import '../../core/constants/preference_keys.dart';
import '../../data/models/chart_day_aggregate.dart';

enum HistoryStatus { loading, empty, ready }

enum HistoryPeriod {
  days7,
  days30;

  int get dayCount => switch (this) {
    HistoryPeriod.days7 => 7,
    HistoryPeriod.days30 => 30,
  };
}

enum TrendDirection { up, down, flat }

class TrendSnapshot {
  const TrendSnapshot({
    required this.direction,
    this.percent,
    required this.label,
  });

  final TrendDirection direction;
  final int? percent;
  final String label;
}

class HistoryState {
  const HistoryState({
    required this.status,
    this.period = HistoryPeriod.days7,
    this.chartPoints = const [],
    this.dailyGoal = kDefaultStepGoal,
    this.goalsByDay = const {},
    this.trend,
  });

  final HistoryStatus status;
  final HistoryPeriod period;
  final List<ChartDayAggregate> chartPoints;
  /// Today's resolved goal — empty-state fallback and goal-line default.
  final int dailyGoal;
  /// Resolved goal per local day (`YYYY-MM-DD`) for chart bar semantics.
  final Map<String, int> goalsByDay;
  final TrendSnapshot? trend;

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
    required int dailyGoal,
    Map<String, int> goalsByDay = const {},
    TrendSnapshot? trend,
  }) {
    return HistoryState(
      status: HistoryStatus.ready,
      period: period,
      chartPoints: chartPoints,
      dailyGoal: dailyGoal,
      goalsByDay: goalsByDay,
      trend: trend,
    );
  }

  HistoryState copyWith({
    HistoryStatus? status,
    HistoryPeriod? period,
    List<ChartDayAggregate>? chartPoints,
    int? dailyGoal,
    Map<String, int>? goalsByDay,
    TrendSnapshot? trend,
  }) {
    return HistoryState(
      status: status ?? this.status,
      period: period ?? this.period,
      chartPoints: chartPoints ?? this.chartPoints,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      goalsByDay: goalsByDay ?? this.goalsByDay,
      trend: trend ?? this.trend,
    );
  }
}
