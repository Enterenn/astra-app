import 'dart:async';

import '../../../core/metrics/derived_activity_metrics.dart';
import '../../../core/time/calendar_week.dart';
import '../../../core/time/local_day_calculator.dart';
import '../../../core/time/local_day_formatter.dart';
import '../../../core/time/time_provider.dart';
import '../../../core/time/timestamp_codec.dart';
import '../../../data/contracts/contracts.dart';
import '../../../data/models/chart_day_aggregate.dart';
import '../../models/week_day_status.dart';
import '../today_state.dart';
import 'today_session_cache.dart';
import 'today_snapshot_applier.dart' show toMetricsSnapshot;

class TodayWeekSelection {
  TodayWeekSelection({
    required this.cache,
    required this.emit,
    required this.getState,
    required this.isClosed,
    required this.stepAggregation,
    required this.userHealthMetrics,
    required this.userSettings,
    required this.clock,
  });

  final TodaySessionCache cache;
  final void Function(TodayState) emit;
  final TodayState Function() getState;
  final bool Function() isClosed;
  final StepAggregationRepositoryContract stepAggregation;
  final UserHealthMetricsRepositoryContract userHealthMetrics;
  final UserSettingsRepositoryContract userSettings;
  final TimeProvider clock;

  late ApplyTodaySnapshotFn applyTodaySnapshot;
  late Future<int> Function() resolveTodayGoal;
  late Future<int?> Function() loadLastDisplayedStepsForDisplayDay;

  void selectLocalDay(DateTime day) {
    if (isClosed()) return;
    final state = getState();
    final utcDay = day.toUtc();
    final normalizedDay = DateTime.utc(utcDay.year, utcDay.month, utcDay.day);
    WeekDayStatus? match;
    for (final weekDay in state.weekDays) {
      if (isSameLocalDay(weekDay.localDay, normalizedDay)) {
        match = weekDay;
        break;
      }
    }
    if (match == null || match.isFuture) return;
    if (state.selectedLocalDay != null &&
        isSameLocalDay(state.selectedLocalDay!, normalizedDay)) {
      return;
    }
    cache.hasUserSelectedLocalDay = true;
    emit(
      state.copyWith(
        status: TodayStatus.loading,
        selectedLocalDay: normalizedDay,
        lastDisplayedSteps: null,
        lastDisplayedStepsLoaded: false,
      ),
    );
    unawaited(_applySelectedDayDisplay());
  }

  bool isViewingToday() {
    final state = getState();
    final selected = state.selectedLocalDay;
    if (selected == null) return true;
    final today = state.weekDays.cast<WeekDayStatus?>().firstWhere(
      (day) => day!.isToday,
      orElse: () => null,
    );
    if (today == null) return true;
    return isSameLocalDay(today.localDay, selected);
  }

  DateTime resolveSelectedLocalDay(List<WeekDayStatus> weekDays) {
    final state = getState();
    final today = weekDays.firstWhere(
      (day) => day.isToday,
      orElse: () => weekDays.first,
    );
    final normalizedToday = DateTime.utc(
      today.localDay.toUtc().year,
      today.localDay.toUtc().month,
      today.localDay.toUtc().day,
    );
    if (!cache.hasUserSelectedLocalDay || state.selectedLocalDay == null) {
      return normalizedToday;
    }
    final selected = state.selectedLocalDay!;
    final normalizedSelected = DateTime.utc(
      selected.toUtc().year,
      selected.toUtc().month,
      selected.toUtc().day,
    );
    final isInCurrentWeek = weekDays.any(
      (day) => isSameLocalDay(day.localDay, normalizedSelected),
    );
    if (!isInCurrentWeek) {
      cache.hasUserSelectedLocalDay = false;
      return normalizedToday;
    }
    return normalizedSelected;
  }

  Future<List<WeekDayStatus>> loadWeekDays() async {
    final timeSnapshot = clock.snapshot();
    final zoneOffset = TimestampCodec.formatZoneOffset(timeSnapshot.zoneOffset);
    final referenceToday = LocalDayCalculator.localDay(
      utc: timeSnapshot.nowUtc,
      zoneOffset: zoneOffset,
    );
    final weekDayKeys = CalendarWeek.daysContaining(referenceToday);
    final aggregates = await stepAggregation.getChartDailyAggregates(days: 7);
    final stepsByDay = {
      for (final aggregate in aggregates)
        aggregate.localDay: aggregate.totalSteps,
    };
    final weekDayIsos = [
      for (final day in weekDayKeys) localDayIsoFromDateOnly(day),
    ];
    final goalsByIso =
        await userHealthMetrics.getGoalsForLocalDays(weekDayIsos);
    return [
      for (var i = 0; i < weekDayKeys.length; i++)
        WeekDayStatus(
          localDay: weekDayKeys[i],
          weekdayLabel: CalendarWeek.weekdayLabelFor(weekDayKeys[i]),
          dayNumber: weekDayKeys[i].day,
          isToday: weekDayKeys[i] == referenceToday,
          isFuture: weekDayKeys[i].isAfter(referenceToday),
          goalMet: goalsByIso[weekDayIsos[i]]! > 0 &&
              (stepsByDay[weekDayKeys[i]] ?? 0) >=
                  goalsByIso[weekDayIsos[i]]!,
        ),
    ];
  }

  Future<({int steps, int goal, ActivityMetricsSnapshot metrics})>
      loadSnapshotForLocalDay(DateTime day) async {
    final state = getState();
    final utcDay = day.toUtc();
    final normalizedDay = DateTime.utc(utcDay.year, utcDay.month, utcDay.day);
    final aggregates =
        await stepAggregation.getChartDailyAggregates(days: 7);
    final steps = aggregates
        .firstWhere(
          (a) => isSameLocalDay(a.localDay, normalizedDay),
          orElse: () =>
              ChartDayAggregate(localDay: normalizedDay, totalSteps: 0),
        )
        .totalSteps;
    final goal = await userHealthMetrics.getGoalForLocalDay(
      localDayIsoFromDateOnly(normalizedDay),
    );
    final buckets =
        await stepAggregation.getActiveBucketsForLocalDay(normalizedDay);
    final metrics = toMetricsSnapshot(
      DerivedActivityMetrics.compute(
        displaySteps: steps,
        activeBuckets: buckets,
        heightCm: state.heightCm,
        weightKg: state.weightKg,
      ),
    );
    return (steps: steps, goal: goal, metrics: metrics);
  }

  List<WeekDayStatus> patchTodayGoalMetForLiveSteps(
    List<WeekDayStatus> weekDays, {
    required int liveSteps,
    required int todayGoal,
  }) {
    if (weekDays.isEmpty) return weekDays;
    final todayIndex = weekDays.indexWhere((day) => day.isToday);
    if (todayIndex == -1) return weekDays;
    final nextGoalMet = todayGoal > 0 && liveSteps >= todayGoal;
    final today = weekDays[todayIndex];
    if (today.goalMet == nextGoalMet) return weekDays;
    final updated = WeekDayStatus(
      localDay: today.localDay,
      weekdayLabel: today.weekdayLabel,
      dayNumber: today.dayNumber,
      isToday: today.isToday,
      isFuture: today.isFuture,
      goalMet: nextGoalMet,
    );
    return [
      for (var i = 0; i < weekDays.length; i++)
        if (i == todayIndex) updated else weekDays[i],
    ];
  }

  bool isSameLocalDay(DateTime a, DateTime b) {
    final au = a.toUtc();
    final bu = b.toUtc();
    return au.year == bu.year && au.month == bu.month && au.day == bu.day;
  }

  Future<void> _applySelectedDayDisplay() async {
    if (isClosed()) return;
    final intendedSelectedLocalDay = getState().selectedLocalDay;
    if (isViewingToday()) {
      final goal = cache.todayGoal ?? await resolveTodayGoal();
      if (isClosed()) return;
      final lastDisplayedSteps = await loadLastDisplayedStepsForDisplayDay();
      if (isClosed()) return;
      final s = getState();
      final steps = cache.todaySteps ?? s.steps;
      final activityMetrics = cache.todayMetrics ??
          ActivityMetricsSnapshot(
            distanceKm: DerivedActivityMetrics.computeDistanceKm(
              displaySteps: steps,
              heightCm: s.heightCm,
            ),
            walkingDuration: s.activityMetrics.walkingDuration,
            kcal: s.activityMetrics.kcal,
          );
      await applyTodaySnapshot(
        steps: steps,
        goal: goal,
        isStale: s.isStale,
        lastIngestionUtc: s.lastIngestionUtc,
        weekDays: s.weekDays,
        activityMetrics: activityMetrics,
        heightCm: s.heightCm,
        weightKg: s.weightKg,
        lastDisplayedSteps: lastDisplayedSteps,
        lastDisplayedStepsLoaded: true,
      );
      return;
    }

    final day = intendedSelectedLocalDay;
    if (day == null) return;
    final snapshot = await loadSnapshotForLocalDay(day);
    if (isClosed()) return;
    if (getState().selectedLocalDay == null ||
        !isSameLocalDay(getState().selectedLocalDay!, day)) {
      return;
    }
    final dayIso = localDayIsoFromDateOnly(day);
    final lastDisplayedSteps =
        await userSettings.getLastDisplayedSteps(dayIso);
    if (isClosed()) return;
    if (getState().selectedLocalDay == null ||
        !isSameLocalDay(getState().selectedLocalDay!, day)) {
      return;
    }
    final s = getState();
    emit(
      TodayState.fromData(
        steps: snapshot.steps,
        goal: snapshot.goal,
        isStale: s.isStale,
        lastIngestionUtc: s.lastIngestionUtc,
        weekDays: s.weekDays,
        activityMetrics: snapshot.metrics,
        heightCm: s.heightCm,
        weightKg: s.weightKg,
        showCelebration: false,
        foregroundCatchUp: false,
        catchUpTargetSteps: null,
        selectedLocalDay: day,
        lastDisplayedSteps: lastDisplayedSteps,
        lastDisplayedStepsLoaded: true,
      ),
    );
  }
}
