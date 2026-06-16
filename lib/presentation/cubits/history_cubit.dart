import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/metrics/derived_activity_metrics.dart';
import '../../core/time/local_day_formatter.dart';
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
  List<TrendsDayMetrics> _cachedDayMetrics30d = const [];
  Map<String, int> _cachedGoalsByDay = const {};
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

  /// Re-reads daily goals from preferences and updates the current state without
  /// hitting the step repository (mirrors [TodayCubit.refreshMetadata] scope).
  Future<void> refreshGoal() async {
    if (isClosed || state.status == HistoryStatus.loading) {
      return;
    }

    try {
      final goalsByDay = await _resolveGoalsForAggregates(_cachedAggregates30d);
      if (isClosed) {
        return;
      }
      _cachedGoalsByDay = goalsByDay;
      final todayGoal = await _resolveTodayGoal();
      if (isClosed) {
        return;
      }
      _emitWithGoals(todayGoal: todayGoal, goalsByDay: goalsByDay);
    } catch (error, stackTrace) {
      // Keep last known goals on preference read failure.
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
      emit(
        HistoryState.empty(
          period: period,
          dailyGoal: state.dailyGoal,
          goalsByDay: state.goalsByDay,
        ),
      );
      return;
    }

    _emitReady(period: period);
  }

  Future<void> _refreshImpl({required bool silent}) async {
    if (!silent && state.status != HistoryStatus.loading) {
      emit(const HistoryState.loading());
    }

    try {
      final aggregates = await stepRepository.getChartDailyAggregates(days: 30);
      if (isClosed) {
        return;
      }

      final goalsByDay = await _resolveGoalsForAggregates(aggregates);
      if (isClosed) {
        return;
      }

      _cachedAggregates30d = aggregates;
      _cachedGoalsByDay = goalsByDay;
      final todayGoal = await _resolveTodayGoal();
      if (isClosed) {
        return;
      }

      final totalSteps = aggregates.fold<int>(
        0,
        (sum, entry) => sum + entry.totalSteps,
      );
      if (totalSteps == 0) {
        _cachedDayMetrics30d = const [];
        emit(
          HistoryState.empty(
            period: state.period,
            dailyGoal: todayGoal,
            goalsByDay: goalsByDay,
          ),
        );
        return;
      }

      final profileResults = await Future.wait<Object?>([
        userPreferences.getHeightCm(),
        userPreferences.getWeightKg(),
      ]);
      if (isClosed) {
        return;
      }

      final heightCm = profileResults[0] as int?;
      final weightKg = profileResults[1] as double?;
      _cachedDayMetrics30d = await _buildDayMetricsCache(
        aggregates,
        heightCm: heightCm,
        weightKg: weightKg,
      );
      if (isClosed) {
        return;
      }

      _emitReady(
        period: _resolveDisplayPeriod(state.period),
        dailyGoal: todayGoal,
        goalsByDay: goalsByDay,
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
        goalsByDay: state.goalsByDay,
      ),
    );
  }

  void _emitWithGoals({
    required int todayGoal,
    required Map<String, int> goalsByDay,
  }) {
    switch (state.status) {
      case HistoryStatus.loading:
        return;
      case HistoryStatus.empty:
        emit(
          HistoryState.empty(
            period: state.period,
            dailyGoal: todayGoal,
            goalsByDay: goalsByDay,
          ),
        );
      case HistoryStatus.ready:
        _emitReady(
          period: state.period,
          dailyGoal: todayGoal,
          goalsByDay: goalsByDay,
        );
    }
  }

  void _emitReady({
    required HistoryPeriod period,
    int? dailyGoal,
    Map<String, int>? goalsByDay,
    List<ChartDayAggregate>? aggregates,
  }) {
    final source = aggregates ?? _cachedAggregates30d;
    emit(
      HistoryState.ready(
        period: period,
        chartPoints: _sliceForPeriod(period),
        dailyGoal: dailyGoal ?? state.dailyGoal,
        goalsByDay: goalsByDay ?? _cachedGoalsByDay,
        trend: _computeTrend(source),
        periodAverages: _computeAveragesForPeriod(period),
      ),
    );
  }

  Future<List<TrendsDayMetrics>> _buildDayMetricsCache(
    List<ChartDayAggregate> aggregates, {
    required int? heightCm,
    required double? weightKg,
  }) async {
    final bucketLists = await Future.wait(
      aggregates.map(
        (aggregate) =>
            stepRepository.getActiveBucketsForLocalDay(aggregate.localDay),
      ),
    );

    return [
      for (var i = 0; i < aggregates.length; i++)
        TrendsDayMetrics(
          localDay: aggregates[i].localDay,
          totalSteps: aggregates[i].totalSteps,
          dailyKcal: DerivedActivityMetrics.compute(
            displaySteps: aggregates[i].totalSteps,
            activeBuckets: bucketLists[i],
            heightCm: heightCm,
            weightKg: weightKg,
          ).kcal,
        ),
    ];
  }

  TrendsPeriodAverages _computeAveragesForPeriod(HistoryPeriod period) {
    final dayCount = period.dayCount;
    final slice = _cachedDayMetrics30d.take(dayCount);
    final sumSteps = slice.fold<int>(0, (sum, day) => sum + day.totalSteps);
    final sumKcal = slice.fold<int>(0, (sum, day) => sum + day.dailyKcal);
    return TrendsPeriodAverages(
      averageSteps: (sumSteps / dayCount).round(),
      averageKcal: (sumKcal / dayCount).round(),
    );
  }

  Future<int> _resolveTodayGoal() async {
    final todayIso = formatLocalDayIso(stepRepository.clock.snapshot());
    return userPreferences.getGoalForLocalDay(todayIso);
  }

  Future<Map<String, int>> _resolveGoalsForAggregates(
    List<ChartDayAggregate> aggregates,
  ) async {
    final distinctIsos = {
      for (final aggregate in aggregates)
        localDayIsoFromDateOnly(aggregate.localDay),
    }.toList(growable: false);
    if (distinctIsos.isEmpty) {
      return const {};
    }

    final goals = await Future.wait<int>([
      for (final iso in distinctIsos)
        userPreferences.getGoalForLocalDay(iso),
    ]);
    return Map.fromIterables(distinctIsos, goals);
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
