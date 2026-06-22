import '../../data/models/chart_day_aggregate.dart';
import '../../core/time/local_day_formatter.dart';
import '../../presentation/cubits/history_state.dart';

/// Counts calendar days in [aggregates] with at least one step.
int countDaysWithSteps(List<ChartDayAggregate> aggregates) {
  return aggregates.where((entry) => entry.totalSteps > 0).length;
}

TrendsInsightAvailability computeInsightAvailability(
  List<ChartDayAggregate> aggregates,
) {
  final daysWithSteps = countDaysWithSteps(aggregates);
  return TrendsInsightAvailability(
    hasMinimumHistory: daysWithSteps >= 7,
    hasWeeklyComparison: daysWithSteps >= 14,
  );
}

/// Weekday with highest average steps across the 30-day window (days with steps only).
TrendsMostActiveWeekday? computeMostActiveWeekday(
  List<ChartDayAggregate> aggregates,
) {
  final sums = List<int>.filled(8, 0);
  final counts = List<int>.filled(8, 0);
  final mostRecentIndex = List<int?>.filled(8, null);

  for (var i = 0; i < aggregates.length; i++) {
    final aggregate = aggregates[i];
    if (aggregate.totalSteps <= 0) {
      continue;
    }
    final weekday = aggregate.localDay.weekday;
    sums[weekday] += aggregate.totalSteps;
    counts[weekday]++;
    mostRecentIndex[weekday] = i;
  }

  int? bestWeekday;
  var bestAverage = -1.0;
  var bestSum = -1;
  var bestRecentIndex = 999999;

  for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
    if (counts[weekday] == 0) {
      continue;
    }
    final average = sums[weekday] / counts[weekday];
    final sum = sums[weekday];
    final recentIndex = mostRecentIndex[weekday]!;

    final winsAverage = average > bestAverage;
    final tiesAverageHigherSum =
        average == bestAverage && sum > bestSum;
    final tiesAverageSumMoreRecent =
        average == bestAverage &&
        sum == bestSum &&
        recentIndex < bestRecentIndex;

    if (winsAverage || tiesAverageHigherSum || tiesAverageSumMoreRecent) {
      bestAverage = average;
      bestSum = sum;
      bestRecentIndex = recentIndex;
      bestWeekday = weekday;
    }
  }

  if (bestWeekday == null) {
    return null;
  }

  return TrendsMostActiveWeekday(
    weekday: bestWeekday,
    averageSteps: bestAverage.round(),
  );
}

/// Consecutive days at or above resolved goal, walking newest-first from today.
TrendsGoalStreak computeGoalStreak({
  required List<ChartDayAggregate> newestFirst,
  required Map<String, int> goalsByDay,
  required int fallbackGoal,
}) {
  var streak = 0;
  for (final aggregate in newestFirst) {
    if (aggregate.totalSteps <= 0) {
      break;
    }
    final iso = localDayIsoFromDateOnly(aggregate.localDay);
    final goal = goalsByDay[iso] ?? fallbackGoal;
    if (aggregate.totalSteps >= goal) {
      streak++;
    } else {
      break;
    }
  }
  return TrendsGoalStreak(consecutiveDays: streak);
}
