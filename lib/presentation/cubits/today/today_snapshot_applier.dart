import '../../../core/metrics/derived_activity_metrics.dart';
import '../../../core/time/local_day_formatter.dart';
import '../../../core/time/time_provider.dart';
import '../../../data/contracts/contracts.dart';
import '../../models/week_day_status.dart';
import '../today_state.dart';
import 'today_session_cache.dart';

ActivityMetricsSnapshot toMetricsSnapshot(DerivedActivityResult result) =>
    ActivityMetricsSnapshot(
      distanceKm: result.distanceKm,
      walkingDuration: result.walkingDuration,
      kcal: result.kcal,
    );

class TodaySnapshotApplier {
  TodaySnapshotApplier({
    required this.cache,
    required this.emit,
    required this.getState,
    required this.isClosed,
    required this.userHealthMetrics,
    required this.clock,
  });

  final TodaySessionCache cache;
  final void Function(TodayState) emit;
  final TodayState Function() getState;
  final bool Function() isClosed;
  final UserHealthMetricsRepositoryContract userHealthMetrics;
  final TimeProvider clock;

  late bool Function() isViewingToday;
  late Future<void> Function({
    required int steps,
    required int goal,
    required TodayState baseState,
  }) maybeTriggerCelebration;

  Future<int> resolveTodayGoal() async {
    final todayIso = formatLocalDayIso(clock.snapshot());
    return userHealthMetrics.getGoalForLocalDay(todayIso);
  }

  ActivityMetricsSnapshot liveMetricsForSteps(int steps) {
    final state = getState();
    final bucketMetrics = cache.todayMetrics ?? state.activityMetrics;
    return ActivityMetricsSnapshot(
      distanceKm: DerivedActivityMetrics.computeDistanceKm(
        displaySteps: steps,
        heightCm: state.heightCm,
      ),
      walkingDuration: bucketMetrics.walkingDuration,
      kcal: bucketMetrics.kcal,
    );
  }

  Future<void> applyTodaySnapshot({
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
  }) async {
    if (isClosed()) return;
    final effectiveAllowDecrease = allowDecrease ?? false;
    final effectiveSkipCelebration = skipCelebration ?? false;

    final state = getState();
    final todayIso = formatLocalDayIso(clock.snapshot());
    var effectiveSteps = steps;
    if (!effectiveAllowDecrease &&
        state.status != TodayStatus.noPermission &&
        cache.todaySteps != null &&
        steps < cache.todaySteps! &&
        (state.status == TodayStatus.loading ||
            cache.lastAppliedLocalDay == todayIso)) {
      effectiveSteps = cache.todaySteps!;
    } else if (!effectiveAllowDecrease &&
        cache.lastAppliedLocalDay == todayIso &&
        state.status != TodayStatus.loading &&
        state.status != TodayStatus.noPermission &&
        isViewingToday() &&
        cache.todaySteps == null &&
        steps < state.steps) {
      effectiveSteps = state.steps;
    }
    cache.lastAppliedLocalDay = todayIso;
    cache.todaySteps = effectiveSteps;
    cache.todayGoal = goal;

    final baseMetrics =
        activityMetrics ?? cache.todayMetrics ?? state.activityMetrics;
    final resolvedMetrics = ActivityMetricsSnapshot(
      distanceKm: DerivedActivityMetrics.computeDistanceKm(
        displaySteps: effectiveSteps,
        heightCm: heightCm ?? state.heightCm,
      ),
      walkingDuration: baseMetrics.walkingDuration,
      kcal: baseMetrics.kcal,
    );
    cache.todayMetrics = resolvedMetrics;

    if (!isViewingToday()) return;

    final resolvedLoaded =
        lastDisplayedStepsLoaded ?? state.lastDisplayedStepsLoaded;
    if (!resolvedLoaded) return;

    final baseState = TodayState.fromData(
      steps: effectiveSteps,
      goal: goal,
      isStale: isStale,
      lastIngestionUtc: lastIngestionUtc,
      weekDays: weekDays ?? state.weekDays,
      activityMetrics: resolvedMetrics,
      heightCm: heightCm ?? state.heightCm,
      weightKg: weightKg ?? state.weightKg,
      foregroundCatchUp: state.foregroundCatchUp,
      catchUpTargetSteps: state.catchUpTargetSteps,
      selectedLocalDay: selectedLocalDay ?? state.selectedLocalDay,
      lastDisplayedSteps: lastDisplayedSteps ?? state.lastDisplayedSteps,
      lastDisplayedStepsLoaded:
          lastDisplayedStepsLoaded ?? state.lastDisplayedStepsLoaded,
    );
    if (effectiveSkipCelebration) {
      emit(baseState);
      return;
    }
    await maybeTriggerCelebration(
      steps: effectiveSteps,
      goal: goal,
      baseState: baseState,
    );
  }
}
