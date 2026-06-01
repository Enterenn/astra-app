import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/onboarding_cubit.dart';
import '../cubits/onboarding_state.dart';
import '../widgets/astra_button.dart';
import 'onboarding_progress_indicator.dart';

class OnboardingGoalPage extends StatefulWidget {
  const OnboardingGoalPage({
    super.key,
    required this.onComplete,
  });

  final Future<void> Function(int goal) onComplete;

  @override
  State<OnboardingGoalPage> createState() => _OnboardingGoalPageState();
}

class _OnboardingGoalPageState extends State<OnboardingGoalPage> {
  late final TextEditingController _goalController;
  var _didSyncGoal = false;

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController(text: '8000');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didSyncGoal) {
      _goalController.text = context.read<OnboardingCubit>().state.goalInput;
      _didSyncGoal = true;
    }
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final cubit = context.watch<OnboardingCubit>();
    final state = cubit.state;
    final isCompleting = state.status == OnboardingStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: isCompleting ? null : cubit.previousStep,
              icon: Icon(Icons.arrow_back, color: colors.textPrimary),
              tooltip: 'Back',
            ),
            const Expanded(
              child: OnboardingProgressIndicator(currentStep: 2, totalSteps: 3),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: AstraSpacing.kSpaceLg),
        Text(
          'Set a daily step goal',
          style: AstraTypography.titleFor(colors),
        ),
        const SizedBox(height: AstraSpacing.kSpaceMd),
        Text(
          'Change anytime in My Data.',
          style: AstraTypography.bodyFor(colors),
        ),
        const SizedBox(height: AstraSpacing.kSpaceXl),
        TextField(
          controller: _goalController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Daily step goal',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
              borderSide: BorderSide(color: colors.borderDefault),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
              borderSide: BorderSide(color: colors.borderDefault),
            ),
          ),
          onChanged: cubit.setGoalInput,
        ),
        const Spacer(),
        AstraButton(
          label: 'Start tracking',
          isLoading: isCompleting,
          onPressed: state.isGoalValid && !isCompleting
              ? () => widget.onComplete(state.resolvedGoal)
              : null,
        ),
        const SizedBox(height: AstraSpacing.kSpaceMd),
        AstraButton(
          label: 'Skip',
          variant: AstraButtonVariant.secondary,
          onPressed: isCompleting ? null : () => widget.onComplete(8000),
        ),
      ],
    );
  }
}
