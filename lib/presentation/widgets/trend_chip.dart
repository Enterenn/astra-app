import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/history_state.dart';

class TrendChip extends StatelessWidget {
  const TrendChip({
    required this.trend,
    super.key,
  });

  final TrendSnapshot trend;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final (icon, color) = switch (trend.direction) {
      TrendDirection.up => (PhosphorIconsRegular.arrowUp, colors.dataPositive),
      TrendDirection.down =>
        (PhosphorIconsRegular.arrowDown, colors.dataNegative),
      TrendDirection.flat => (PhosphorIconsRegular.minus, colors.textPrimary),
    };

    return Semantics(
      label: trend.label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AstraSpacing.kSpaceMd,
          vertical: AstraSpacing.kSpaceSm,
        ),
        decoration: BoxDecoration(
          color: colors.bgSubtle,
          borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AstraSpacing.kSpaceSm),
            Text(
              trend.label,
              style: AstraTypography.captionFor(colors).copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
