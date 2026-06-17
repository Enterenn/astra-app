import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../core/constants/display_unit_preferences.dart';
import '../../core/constants/preference_keys.dart';
import '../cubits/onboarding_cubit.dart';
import '../cubits/onboarding_state.dart';
import '../formatters/display_unit_formatter.dart';
import '../widgets/astra_horizontal_ruler.dart';
import '../widgets/astra_segmented_control.dart';

class OnboardingWeightPage extends StatelessWidget {
  const OnboardingWeightPage({super.key});

  static const _defaultKg = 70.0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      buildWhen: (previous, current) =>
          previous.weightKg != current.weightKg ||
          previous.weightDisplayUnit != current.weightDisplayUnit,
      builder: (context, state) {
        final cubit = context.read<OnboardingCubit>();
        final canonicalKg = state.weightKg ?? _defaultKg;
        final isLb = state.weightDisplayUnit == WeightDisplayUnit.lb;

        final displayValue = isLb
            ? weightKgToDisplayLb(canonicalKg)
            : canonicalKg;

        final min = isLb
            ? weightKgToDisplayLb(kMinWeightKg)
            : kMinWeightKg;
        final max = isLb
            ? weightKgToDisplayLb(kMaxWeightKg)
            : kMaxWeightKg;

        final colors = context.astraColors;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What is your weight?',
              textAlign: TextAlign.center,
              style: AstraTypography.titleFor(colors),
            ),
            const SizedBox(height: AstraSpacing.kSpaceXl),
            AstraSegmentedControl<WeightDisplayUnit>(
              options: const [
                AstraSegmentOption(value: WeightDisplayUnit.kg, label: 'kg'),
                AstraSegmentOption(value: WeightDisplayUnit.lb, label: 'lb'),
              ],
              selected: state.weightDisplayUnit,
              onChanged: cubit.setWeightDisplayUnit,
              semanticsHint: 'Select weight unit',
            ),
            const SizedBox(height: AstraSpacing.kSpaceXl),
            Expanded(
              child: Center(
                child: AstraHorizontalRuler(
                  key: ValueKey('weight-ruler-${state.weightDisplayUnit.name}'),
                  value: displayValue,
                  onChanged: (value) {
                    if (isLb) {
                      cubit.setWeightKg(displayLbToWeightKg(value));
                    } else {
                      cubit.setWeightKg(value);
                    }
                  },
                  min: min,
                  max: max,
                  step: 1,
                  unitLabel: isLb ? 'lb' : 'kg',
                  majorTickEvery: 10,
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
