import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_typography.dart';

/// Placeholder until Story 13.3 implements the weight picker.
class OnboardingWeightPlaceholder extends StatelessWidget {
  const OnboardingWeightPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Center(
      child: Text(
        'Weight',
        style: AstraTypography.headlineFor(colors),
      ),
    );
  }
}
