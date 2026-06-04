import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

class SourceChip extends StatelessWidget {
  const SourceChip({
    this.label = 'Phone sensor',
    this.showIcon = true,
    super.key,
  });

  final String label;
  final bool showIcon;

  static const _kIconSize = 14.0;
  static const _kHorizontalPadding = 10.0;
  static const _kVerticalPadding = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _kHorizontalPadding,
        vertical: _kVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: colors.bgSubtle,
        borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              Icons.smartphone_outlined,
              size: _kIconSize,
              color: colors.neutralGray,
            ),
            const SizedBox(width: AstraSpacing.kSpaceXs),
          ],
          Text(label, style: AstraTypography.captionFor(colors)),
        ],
      ),
    );
  }
}
