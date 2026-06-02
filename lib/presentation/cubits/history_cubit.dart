import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/chart_day_aggregate.dart';
import '../../data/repositories/step_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import 'history_state.dart';

class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit({
    required this.stepRepository,
    required this.userPreferences,
  }) : super(const HistoryState.loading());

  final StepRepository stepRepository;
  final UserPreferencesRepository userPreferences;

  List<ChartDayAggregate> _cachedAggregates30d = const [];
  Future<void>? _refreshInFlight;

  Future<void> refresh({bool silent = true}) async {
    if (isClosed) {
      return;
    }

    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }

    _refreshInFlight = _refreshImpl(silent: silent);
    try {
      await _refreshInFlight!;
    } finally {
      _refreshInFlight = null;
    }
  }

  void selectPeriod(HistoryPeriod period) {
    if (isClosed || period == state.period) {
      return;
    }

    if (state.status == HistoryStatus.loading) {
      emit(state.copyWith(period: period));
      return;
    }

    if (state.status == HistoryStatus.empty) {
      emit(HistoryState.empty(period: period, dailyGoal: state.dailyGoal));
      return;
    }

    emit(
      HistoryState.ready(
        period: period,
        chartPoints: _sliceForPeriod(period),
        dailyGoal: state.dailyGoal,
        trend: _computeTrend(_cachedAggregates30d),
      ),
    );
  }

  Future<void> _refreshImpl({required bool silent}) async {
    if (!silent && state.status != HistoryStatus.loading) {
      emit(const HistoryState.loading());
    }

    final results = await Future.wait<Object?>([
      stepRepository.getChartDailyAggregates(days: 30),
      userPreferences.getDailyStepGoal(),
    ]);
    if (isClosed) {
      return;
    }

    final aggregates = results[0]! as List<ChartDayAggregate>;
    final goal = results[1]! as int;
    _cachedAggregates30d = aggregates;

    final totalSteps = aggregates.fold<int>(
      0,
      (sum, entry) => sum + entry.totalSteps,
    );
    if (totalSteps == 0) {
      emit(
        HistoryState.empty(
          period: state.period,
          dailyGoal: goal,
        ),
      );
      return;
    }

    emit(
      HistoryState.ready(
        period: state.period,
        chartPoints: _sliceForPeriod(state.period),
        dailyGoal: goal,
        trend: _computeTrend(aggregates),
      ),
    );
  }

  List<ChartDayAggregate> _sliceForPeriod(HistoryPeriod period) {
    final count = period.dayCount;
    return _cachedAggregates30d
        .take(count)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
  }

  TrendSnapshot? _computeTrend(List<ChartDayAggregate> newestFirst) {
    if (newestFirst.length < 14) {
      return null;
    }

    final currentWeekSum = newestFirst
        .take(7)
        .fold<int>(0, (sum, entry) => sum + entry.totalSteps);
    final priorWeekSum = newestFirst
        .skip(7)
        .take(7)
        .fold<int>(0, (sum, entry) => sum + entry.totalSteps);

    if (priorWeekSum == 0 && currentWeekSum == 0) {
      return null;
    }

    if (priorWeekSum == 0 && currentWeekSum > 0) {
      return const TrendSnapshot(
        direction: TrendDirection.flat,
        label: 'No prior week data',
      );
    }

    final percent =
        ((currentWeekSum - priorWeekSum) / priorWeekSum * 100).round();

    if (percent > 0) {
      return TrendSnapshot(
        direction: TrendDirection.up,
        percent: percent,
        label: 'Up $percent% from last week',
      );
    }
    if (percent < 0) {
      final absPercent = percent.abs();
      return TrendSnapshot(
        direction: TrendDirection.down,
        percent: absPercent,
        label: 'Down $absPercent% from last week',
      );
    }

    return const TrendSnapshot(
      direction: TrendDirection.flat,
      percent: 0,
      label: 'Same as last week',
    );
  }
}
