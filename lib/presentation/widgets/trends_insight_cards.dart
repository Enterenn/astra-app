import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/history_state.dart';
import '../l10n/l10n_date_labels.dart';
import 'elevated_card.dart';

/// Local insight cards below the Trends chart (weekly, weekday, streak).
class TrendsInsightCardsSection extends StatelessWidget {
  const TrendsInsightCardsSection({
    super.key,
    required this.trend,
    required this.mostActiveWeekday,
    required this.goalStreak,
    required this.insightAvailability,
  });

  final TrendSnapshot? trend;
  final TrendsMostActiveWeekday? mostActiveWeekday;
  final TrendsGoalStreak? goalStreak;
  final TrendsInsightAvailability insightAvailability;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TrendsInsightCard(
          icon: PhosphorIconsRegular.chartLineUp,
          title: l10n.trendsInsightWeeklyTitle,
          body: _weeklyBody(l10n),
          semanticsLabel: l10n.trendsInsightWeeklySemantics(_weeklyBody(l10n)),
        ),
        const SizedBox(height: AstraSpacing.kSpaceMd),
        _TrendsInsightCard(
          icon: PhosphorIconsRegular.calendar,
          title: l10n.trendsInsightWeekdayTitle,
          body: _weekdayBody(l10n),
          semanticsLabel: l10n.trendsInsightWeekdaySemantics(_weekdayBody(l10n)),
        ),
        const SizedBox(height: AstraSpacing.kSpaceMd),
        _TrendsInsightCard(
          icon: PhosphorIconsRegular.target,
          title: l10n.trendsInsightStreakTitle,
          body: _streakBody(l10n),
          semanticsLabel: l10n.trendsInsightStreakSemantics(_streakBody(l10n)),
        ),
      ],
    );
  }

  String _weeklyBody(AppLocalizations l10n) {
    if (!insightAvailability.hasMinimumHistory) {
      return l10n.trendsInsightInsufficientData;
    }
    if (!insightAvailability.hasWeeklyComparison) {
      return l10n.trendsInsightWeeklyInsufficientData;
    }
    if (trend == null) {
      return l10n.trendsInsightWeeklyInsufficientData;
    }
    return l10n.weeklyInsightBody(trend!);
  }

  String _weekdayBody(AppLocalizations l10n) {
    if (!insightAvailability.hasMinimumHistory) {
      return l10n.trendsInsightInsufficientData;
    }
    final weekday = mostActiveWeekday;
    if (weekday == null) {
      return l10n.trendsInsightInsufficientData;
    }
    return l10n.formatMostActiveWeekdayInsight(weekday.weekday);
  }

  String _streakBody(AppLocalizations l10n) {
    if (!insightAvailability.hasMinimumHistory) {
      return l10n.trendsInsightInsufficientData;
    }
    final streak = goalStreak;
    if (streak == null || streak.consecutiveDays == 0) {
      return l10n.trendsInsightInsufficientData;
    }
    return l10n.formatGoalStreakInsight(streak.consecutiveDays);
  }
}

class _TrendsInsightCard extends StatelessWidget {
  const _TrendsInsightCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.semanticsLabel,
  });

  final IconData icon;
  final String title;
  final String body;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Semantics(
      label: semanticsLabel,
      container: true,
      child: ElevatedCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: colors.accentPrimary,
              size: 20,
            ),
            const SizedBox(height: AstraSpacing.kSpaceSm),
            Text(
              title,
              style: AstraTypography.labelFor(colors),
            ),
            const SizedBox(height: AstraSpacing.kSpaceXs),
            Text(
              body,
              style: AstraTypography.captionFor(colors),
            ),
          ],
        ),
      ),
    );
  }
}
