import 'package:astra_app/l10n/app_localizations.dart';

import '../cubits/history_state.dart';

/// Localized weekday, month, and trend label helpers for presentation widgets.
extension AppLocalizationsDateLabels on AppLocalizations {
  String weekdayShort(DateTime day) {
    return switch (day.weekday) {
      DateTime.monday => commonWeekdayMon,
      DateTime.tuesday => commonWeekdayTue,
      DateTime.wednesday => commonWeekdayWed,
      DateTime.thursday => commonWeekdayThu,
      DateTime.friday => commonWeekdayFri,
      DateTime.saturday => commonWeekdaySat,
      DateTime.sunday => commonWeekdaySun,
      _ => '',
    };
  }

  /// Uppercase three-letter labels for the Today week progress pills.
  String weekdayPillLabel(DateTime day) {
    return switch (day.weekday) {
      DateTime.monday => todayWeekPillMon,
      DateTime.tuesday => todayWeekPillTue,
      DateTime.wednesday => todayWeekPillWed,
      DateTime.thursday => todayWeekPillThu,
      DateTime.friday => todayWeekPillFri,
      DateTime.saturday => todayWeekPillSat,
      DateTime.sunday => todayWeekPillSun,
      _ => '',
    };
  }

  String monthShort(int month) {
    return switch (month) {
      1 => commonMonthJan,
      2 => commonMonthFeb,
      3 => commonMonthMar,
      4 => commonMonthApr,
      5 => commonMonthMay,
      6 => commonMonthJun,
      7 => commonMonthJul,
      8 => commonMonthAug,
      9 => commonMonthSep,
      10 => commonMonthOct,
      11 => commonMonthNov,
      12 => commonMonthDec,
      _ => '',
    };
  }

  String monthFull(int month) {
    return switch (month) {
      1 => commonMonthJanuary,
      2 => commonMonthFebruary,
      3 => commonMonthMarch,
      4 => commonMonthApril,
      5 => commonMonthMayFull,
      6 => commonMonthJune,
      7 => commonMonthJuly,
      8 => commonMonthAugust,
      9 => commonMonthSeptember,
      10 => commonMonthOctober,
      11 => commonMonthNovember,
      12 => commonMonthDecember,
      _ => '',
    };
  }

  String formatChartTooltipDate(DateTime localDay, {required bool includeYear}) {
    final month = monthFull(localDay.month);
    if (includeYear) {
      return '${localDay.day} $month ${localDay.year}';
    }
    return '${localDay.day} $month';
  }

  String formatMonthYearShort(DateTime monthStart) {
    return '${monthShort(monthStart.month)} ${monthStart.year}';
  }

  String formatMonthYearFull(DateTime monthStart) {
    return '${monthFull(monthStart.month)} ${monthStart.year}';
  }

  String formatPeakDayLabel(DateTime localDay, HistoryPeriod period) {
    return switch (period) {
      HistoryPeriod.days7 => '${weekdayShort(localDay)} ${localDay.day}',
      HistoryPeriod.days30 => '${localDay.day}/${localDay.month}',
      HistoryPeriod.months12 =>
        throw StateError('peak day labels are not defined for months12'),
    };
  }

  String trendLabel(TrendSnapshot trend) {
    if (trend.direction == TrendDirection.flat && trend.percent == null) {
      return trendsNoPriorWeek;
    }
    return switch (trend.direction) {
      TrendDirection.up => trendsWeeklyGrowth(trend.percent!),
      TrendDirection.down => trendsWeeklyDecline(trend.percent!),
      TrendDirection.flat => trendsWeeklyFlat,
    };
  }

  String weeklyInsightBody(TrendSnapshot trend) {
    if (trend.direction == TrendDirection.flat && trend.percent == null) {
      return trendsInsightWeeklyNoPrior;
    }
    return switch (trend.direction) {
      TrendDirection.up => trendsInsightWeeklyUp(trend.percent!),
      TrendDirection.down => trendsInsightWeeklyDown(trend.percent!),
      TrendDirection.flat => trendsInsightWeeklyFlat,
    };
  }

  String formatMostActiveWeekdayInsight(int weekday) {
    final day = DateTime(2024, 1, weekday);
    return trendsInsightMostActiveWeekday(weekdayShort(day));
  }

  String formatGoalStreakInsight(int consecutiveDays) {
    if (consecutiveDays == 1) {
      return trendsInsightGoalStreakOne;
    }
    return trendsInsightGoalStreak(consecutiveDays);
  }

  String chartGoalStatus({required int steps, required int goal}) {
    if (goal <= 0) {
      return chartGoalStatusNoGoal;
    }
    if (steps > goal) {
      return chartGoalStatusOverGoal(steps - goal);
    }
    if (steps < goal) {
      return chartGoalStatusBelowGoal(goal - steps);
    }
    return chartGoalStatusMet;
  }
}
