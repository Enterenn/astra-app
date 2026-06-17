import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../core/constants/preference_keys.dart';
import '../cubits/onboarding_cubit.dart';
import '../cubits/onboarding_state.dart';
import '../formatters/display_unit_formatter.dart';
import '../widgets/astra_horizontal_ruler.dart';
import '../widgets/astra_segmented_control.dart';

class OnboardingHeightPage extends StatelessWidget {
  const OnboardingHeightPage({super.key});

  static const _defaultCm = 170;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      buildWhen: (previous, current) =>
          previous.heightCm != current.heightCm ||
          previous.heightUsesInches != current.heightUsesInches,
      builder: (context, state) {
        final cubit = context.read<OnboardingCubit>();
        final canonicalCm = state.heightCm ?? _defaultCm;
        final usesInches = state.heightUsesInches;

        final displayValue = usesInches
            ? heightCmToDisplayInches(canonicalCm).toDouble()
            : canonicalCm.toDouble();

        final min = usesInches
            ? heightCmToDisplayInches(kMinHeightCm).toDouble()
            : kMinHeightCm.toDouble();
        final max = usesInches
            ? heightCmToDisplayInches(kMaxHeightCm).toDouble()
            : kMaxHeightCm.toDouble();

        final colors = context.astraColors;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What is your height?',
              textAlign: TextAlign.center,
              style: AstraTypography.titleFor(colors),
            ),
            const SizedBox(height: AstraSpacing.kSpaceXl),
            AstraSegmentedControl<bool>(
              options: const [
                AstraSegmentOption(value: false, label: 'cm'),
                AstraSegmentOption(value: true, label: 'in'),
              ],
              selected: usesInches,
              onChanged: cubit.setHeightUsesInches,
              semanticsHint: 'Select height unit',
            ),
            const SizedBox(height: AstraSpacing.kSpaceXl),
            Expanded(
              child: Center(
                child: AstraHorizontalRuler(
                  key: ValueKey('height-ruler-$usesInches'),
                  value: displayValue,
                  onChanged: (value) {
                    if (usesInches) {
                      cubit.setHeightCm(displayInchesToHeightCm(value.round()));
                    } else {
                      cubit.setHeightCm(value.round());
                    }
                  },
                  min: min,
                  max: max,
                  step: 1,
                  unitLabel: usesInches ? 'in' : 'cm',
                  majorTickEvery: usesInches ? 12 : 10,
                  enableHaptics: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
