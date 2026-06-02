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

enum TrendDirection { up, down, flat, hidden }

class TrendSnapshot {
  const TrendSnapshot({
    required this.direction,
    this.percent,
    required this.label,
  });

  final TrendDirection direction;
  final int? percent;
  final String label;

  bool get isVisible => direction != TrendDirection.hidden;
}

class HistoryState {
  const HistoryState({
    required this.status,
    this.period = HistoryPeriod.days7,
    this.chartPoints = const [],
    this.dailyGoal = kDefaultStepGoal,
    this.trend,
  });

  final HistoryStatus status;
  final HistoryPeriod period;
  final List<ChartDayAggregate> chartPoints;
  final int dailyGoal;
  final TrendSnapshot? trend;

  const HistoryState.loading() : this(status: HistoryStatus.loading);

  factory HistoryState.empty({
    HistoryPeriod period = HistoryPeriod.days7,
    int dailyGoal = kDefaultStepGoal,
  }) {
    return HistoryState(
      status: HistoryStatus.empty,
      period: period,
      dailyGoal: dailyGoal,
    );
  }

  factory HistoryState.ready({
    HistoryPeriod period = HistoryPeriod.days7,
    required List<ChartDayAggregate> chartPoints,
    required int dailyGoal,
    TrendSnapshot? trend,
  }) {
    return HistoryState(
      status: HistoryStatus.ready,
      period: period,
      chartPoints: chartPoints,
      dailyGoal: dailyGoal,
      trend: trend,
    );
  }

  HistoryState copyWith({
    HistoryStatus? status,
    HistoryPeriod? period,
    List<ChartDayAggregate>? chartPoints,
    int? dailyGoal,
    TrendSnapshot? trend,
    bool clearTrend = false,
  }) {
    return HistoryState(
      status: status ?? this.status,
      period: period ?? this.period,
      chartPoints: chartPoints ?? this.chartPoints,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      trend: clearTrend ? null : (trend ?? this.trend),
    );
  }
}
