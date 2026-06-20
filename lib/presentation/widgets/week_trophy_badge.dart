import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

/// Trophy badge showing how many days met the daily goal this calendar week.
class WeekTrophyBadge extends StatelessWidget {
  const WeekTrophyBadge({
    required this.goalsMetCount,
    this.totalDays = 7,
    super.key,
  });

  final int goalsMetCount;
  final int totalDays;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final l10n = AppLocalizations.of(context);
    final label = l10n.todayWeekGoalsMetSemantics(goalsMetCount, totalDays);

    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.trophy,
              size: 18,
              color: colors.textPrimary,
            ),
            const SizedBox(width: AstraSpacing.kSpaceXs),
            Text(
              '$goalsMetCount/$totalDays',
              style: AstraTypography.captionFor(colors).copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
