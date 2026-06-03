import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.headline,
    required this.child,
    super.key,
  });

  final String headline;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: BorderRadius.circular(AstraSpacing.kRadiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AstraSpacing.kSpaceMd),
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
