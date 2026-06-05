import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';

/// Shared elevated surface card (bgElevated, kRadiusMd, kCardPadding).
class ElevatedCard extends StatelessWidget {
  const ElevatedCard({
    required this.child,
    this.padding = AstraSpacing.kCardPadding,
    super.key,
  });

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: BorderRadius.circular(AstraSpacing.kRadiusMd),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: child,
      ),
    );
  }
}
