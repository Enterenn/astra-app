import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/di/app_dependencies.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../cubits/onboarding_cubit.dart';
import '../cubits/onboarding_state.dart';
import 'onboarding_display_name_page.dart';
import 'onboarding_goal_page.dart';
import 'onboarding_permissions_page.dart';
import 'onboarding_trust_page.dart';

class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({
    super.key,
    required this.deps,
    required this.onComplete,
    this.createCubit,
  });

  final AppDependencies deps;
  final VoidCallback onComplete;
  final OnboardingCubit Function(UserPreferencesRepository userPreferences)?
      createCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          createCubit?.call(deps.userPreferences) ??
          OnboardingCubit(userPreferences: deps.userPreferences),
      child: BlocListener<OnboardingCubit, OnboardingState>(
        listenWhen: (previous, current) =>
            previous.status != current.status &&
            current.status == OnboardingStatus.completed,
        listener: (context, state) => onComplete(),
        child: const _OnboardingFlowView(),
      ),
    );
  }
}

class _OnboardingFlowView extends StatelessWidget {
  const _OnboardingFlowView();

  Future<void> _completeOnboarding(
    BuildContext context, {
    String? displayName,
  }) async {
    final cubit = context.read<OnboardingCubit>();
    await cubit.completeOnboarding(
      goal: cubit.state.resolvedGoal,
      displayName: displayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final step = context.watch<OnboardingCubit>().state.currentStep;

    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.read<OnboardingCubit>().previousStep();
      },
      child: Scaffold(
        backgroundColor: colors.bgBase,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AstraSpacing.kSpace2xl,
              vertical: AstraSpacing.kSpaceLg,
            ),
            child: IndexedStack(
              index: step,
              children: [
                OnboardingTrustPage(
                  onContinue: context.read<OnboardingCubit>().nextStep,
                ),
                const OnboardingPermissionsPage(),
                OnboardingGoalPage(
                  onContinue: context.read<OnboardingCubit>().nextStep,
                ),
                OnboardingDisplayNamePage(
                  onComplete: ({displayName}) =>
                      _completeOnboarding(context, displayName: displayName),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
