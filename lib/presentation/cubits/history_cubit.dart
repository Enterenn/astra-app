import 'package:flutter/foundation.dart';
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

  /// Re-reads daily goal from preferences and updates the current state without
  /// hitting the step repository (mirrors [TodayCubit.refreshMetadata] scope).
  Future<void> refreshGoal() async {
    if (isClosed || state.status == HistoryStatus.loading) {
      return;
    }

    try {
      final goal = await userPreferences.getDailyStepGoal();
      if (isClosed) {
        return;
      }
      _emitWithGoal(goal);
    } catch (error, stackTrace) {
      // Keep last known goal on preference read failure.
      if (kDebugMode) {
        debugPrint('HistoryCubit.refreshGoal failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
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

    _emitReady(period: period);
  }

  Future<void> _refreshImpl({required bool silent}) async {
    if (!silent && state.status != HistoryStatus.loading) {
      emit(const HistoryState.loading());
    }

    try {
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

      _emitReady(
        period: _resolveDisplayPeriod(state.period),
        dailyGoal: goal,
        aggregates: aggregates,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('HistoryCubit._refreshImpl failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (isClosed) {
        return;
      }
      _recoverFromRefreshFailure();
    }
  }

  void _recoverFromRefreshFailure() {
    if (_cachedAggregates30d.isNotEmpty) {
      _emitReady(period: state.period);
      return;
    }

    if (state.status != HistoryStatus.loading) {
      return;
    }

    emit(
      HistoryState.empty(
        period: state.period,
        dailyGoal: state.dailyGoal,
      ),
    );
  }

  void _emitWithGoal(int goal) {
    switch (state.status) {
      case HistoryStatus.loading:
        return;
      case HistoryStatus.empty:
        emit(HistoryState.empty(period: state.period, dailyGoal: goal));
      case HistoryStatus.ready:
        _emitReady(period: state.period, dailyGoal: goal);
    }
  }

  void _emitReady({
    required HistoryPeriod period,
    int? dailyGoal,
    List<ChartDayAggregate>? aggregates,
  }) {
    final source = aggregates ?? _cachedAggregates30d;
    emit(
      HistoryState.ready(
        period: period,
        chartPoints: _sliceForPeriod(period),
        dailyGoal: dailyGoal ?? state.dailyGoal,
        trend: _computeTrend(source),
      ),
    );
  }

  /// When 7d is selected but the last 7 days have no steps while older days do,
  /// default to 30d so the chart is not a flat zero view on first load.
  HistoryPeriod _resolveDisplayPeriod(HistoryPeriod requested) {
    if (requested != HistoryPeriod.days7) {
      return requested;
    }

    final recentSum = _cachedAggregates30d
        .take(7)
        .fold<int>(0, (sum, entry) => sum + entry.totalSteps);
    if (recentSum > 0) {
      return requested;
    }

    final totalSum = _cachedAggregates30d.fold<int>(
      0,
      (sum, entry) => sum + entry.totalSteps,
    );
    return totalSum > 0 ? HistoryPeriod.days30 : requested;
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
