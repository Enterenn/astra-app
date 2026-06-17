import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/history_state.dart';

/// Rounded caption pill used for trend deltas and period captions on Trends.
class CaptionPill extends StatelessWidget {
  const CaptionPill({
    required this.label,
    this.leading,
    this.textColor,
    super.key,
  });

  final String label;
  final Widget? leading;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Semantics(
      label: label,
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
            if (leading != null) ...[
              ExcludeSemantics(child: leading!),
              const SizedBox(width: AstraSpacing.kSpaceSm),
            ],
            ExcludeSemantics(
              child: Text(
                label,
                style: textColor == null
                    ? AstraTypography.captionFor(colors)
                    : AstraTypography.captionFor(colors).copyWith(
                        color: textColor,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

    return CaptionPill(
      label: trend.label,
      textColor: color,
      leading: Icon(icon, size: 16, color: color),
    );
  }
}
