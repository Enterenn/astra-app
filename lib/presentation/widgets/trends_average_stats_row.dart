import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/history_state.dart';
import '../formatters/activity_metrics_formatter.dart';
import 'elevated_card.dart';

/// Side-by-side average kcal and steps cards for the Trends screen.
class TrendsAverageStatsRow extends StatelessWidget {
  const TrendsAverageStatsRow({
    super.key,
    required this.averages,
  });

  final TrendsPeriodAverages averages;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TrendsStatCard(
            icon: PhosphorIconsRegular.fire,
            value: formatKcal(averages.averageKcal),
            unit: 'kcal',
            caption: 'average calories burned per day',
            semanticsLabel:
                'Average ${averages.averageKcal} kilocalories burned per day',
          ),
        ),
        const SizedBox(width: AstraSpacing.kSpaceSm),
        Expanded(
          child: _TrendsStatCard(
            icon: PhosphorIconsRegular.footprints,
            value: averages.averageSteps.toString(),
            unit: 'steps',
            caption: 'average steps taken per day',
            semanticsLabel:
                'Average ${averages.averageSteps} steps taken per day',
          ),
        ),
      ],
    );
  }
}

class _TrendsStatCard extends StatelessWidget {
  const _TrendsStatCard({
    required this.icon,
    required this.value,
    required this.unit,
    required this.caption,
    required this.semanticsLabel,
  });

  final IconData icon;
  final String value;
  final String unit;
  final String caption;
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
            Icon(icon, color: colors.accentPrimary, size: 20),
            const SizedBox(height: AstraSpacing.kSpaceSm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: AstraTypography.dataFor(colors).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AstraSpacing.kSpaceXs),
                Text(
                  unit,
                  style: AstraTypography.labelFor(colors).copyWith(
                    fontWeight: FontWeight.w400,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AstraSpacing.kSpaceXs),
            Text(
              caption,
              style: AstraTypography.captionFor(colors),
            ),
          ],
        ),
      ),
    );
  }
}
