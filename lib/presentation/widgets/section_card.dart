import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.headline,
    required this.child,
    this.padding = AstraSpacing.kCardPadding,
    super.key,
  });

  final String headline;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(headline, style: AstraTypography.headline(context)),
            const SizedBox(height: AstraSpacing.kSpaceMd),
            child,
          ],
        ),
      ),
    );
  }
}
