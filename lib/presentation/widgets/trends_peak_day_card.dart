import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/history_state.dart';
import 'elevated_card.dart';

/// Full-width peak day stat card for the Trends screen.
class TrendsPeakDayCard extends StatelessWidget {
  const TrendsPeakDayCard({
    super.key,
    required this.peakDay,
  });

  final TrendsPeakDay peakDay;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final semanticsLabel =
        'Peak day ${peakDay.dateLabel} with ${peakDay.totalSteps} steps in this period';

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
                  peakDay.dateLabel,
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
                  'steps',
                  style: AstraTypography.labelFor(colors).copyWith(
                    fontWeight: FontWeight.w400,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AstraSpacing.kSpaceXs),
            Text(
              'peak day in this period',
              style: AstraTypography.captionFor(colors),
            ),
          ],
        ),
      ),
    );
  }
}
