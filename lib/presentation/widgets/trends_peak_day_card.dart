import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:astra_app/core/icons/phosphor_icons.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/history_state.dart';
import '../l10n/l10n_date_labels.dart';
import 'elevated_card.dart';

/// Full-width peak day stat card for the Trends screen.
class TrendsPeakDayCard extends StatelessWidget {
  const TrendsPeakDayCard({
    super.key,
    required this.peakDay,
    required this.period,
  });

  final TrendsPeakDay peakDay;
  final HistoryPeriod period;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.astraColors;
    final dateLabel = l10n.formatPeakDayLabel(peakDay.localDay, period);
    final semanticsLabel = l10n.trendsPeakDaySemantics(
      dateLabel,
      peakDay.totalSteps,
    );

    return Semantics(
      label: semanticsLabel,
      container: true,
      child: ElevatedCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              PhosphorIconsRegular.trophy,
              color: colors.accentPrimary,
              size: 20,
            ),
            const SizedBox(height: AstraSpacing.kSpaceSm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  dateLabel,
                  style: AstraTypography.dataFor(colors).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AstraSpacing.kSpaceSm),
                Text(
                  peakDay.totalSteps.toString(),
                  style: AstraTypography.dataFor(colors).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AstraSpacing.kSpaceXs),
                Text(
                  l10n.todayGoalRingStepsLabel,
                  style: AstraTypography.labelFor(colors).copyWith(
                    fontWeight: FontWeight.w400,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AstraSpacing.kSpaceXs),
            Text(
              l10n.trendsPeakDayCaption,
              style: AstraTypography.captionFor(colors),
            ),
          ],
        ),
      ),
    );
  }
}
