import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';

/// Horizontal segment progress for the 3-step onboarding flow.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  }) : assert(totalSteps > 0),
       assert(currentStep >= 0 && currentStep < totalSteps);

  final int currentStep;
  final int totalSteps;

  static const _segmentWidth = 48.0;
  static const _segmentHeight = 5.0;
  static const _segmentGap = AstraSpacing.kSpaceSm;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < totalSteps; i++) ...[
          if (i > 0) const SizedBox(width: _segmentGap),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: _segmentWidth,
            height: _segmentHeight,
            decoration: BoxDecoration(
              color: i == currentStep
                  ? colors.accentPrimary
                  : colors.bgSubtle,
              borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
            ),
          ),
        ],
      ],
    );
  }
}
