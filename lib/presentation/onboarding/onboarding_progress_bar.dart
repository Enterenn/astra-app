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

  static const _segmentHeight = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Row(
      children: [
        for (var i = 0; i < totalSteps; i++) ...[
          if (i > 0) const SizedBox(width: AstraSpacing.kSpaceSm),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              height: _segmentHeight,
              decoration: BoxDecoration(
                color: i == currentStep
                    ? colors.accentPrimary
                    : colors.borderDefault.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
