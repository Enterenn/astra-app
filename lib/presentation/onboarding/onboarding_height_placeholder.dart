import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_typography.dart';

/// Placeholder until Story 13.3 implements the height picker.
class OnboardingHeightPlaceholder extends StatelessWidget {
  const OnboardingHeightPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Center(
      child: Text(
        'Height',
        style: AstraTypography.headlineFor(colors),
      ),
    );
  }
}
