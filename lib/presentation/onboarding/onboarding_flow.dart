import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/di/app_dependencies.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../cubits/onboarding_cubit.dart';
import '../cubits/onboarding_state.dart';
import 'onboarding_height_placeholder.dart';
import 'onboarding_intro_page.dart';
import 'onboarding_shell.dart';
import 'onboarding_weight_placeholder.dart';

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

  Future<void> _onIntroContinue(BuildContext context) async {
    final cubit = context.read<OnboardingCubit>();
    await cubit.requestActivityPermission();
    cubit.nextStep();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final cubit = context.watch<OnboardingCubit>();
    final state = cubit.state;
    final step = state.currentStep;
    final isRequestingActivity =
        state.activityPermissionStatus == PermissionRequestStatus.requesting;

    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        cubit.previousStep();
      },
      child: Scaffold(
        backgroundColor: colors.bgBase,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AstraSpacing.kSpaceLg,
              vertical: AstraSpacing.kSpaceLg,
            ),
            child: IndexedStack(
              index: step,
              children: [
                OnboardingShell(
                  key: const ValueKey('onboarding-step-0'),
                  currentStep: 0,
                  showBack: false,
                  showPrimaryTrailingArrow: true,
                  primaryLabel: 'Continue',
                  primaryLoading: isRequestingActivity,
                  onPrimary: isRequestingActivity
                      ? null
                      : () => _onIntroContinue(context),
                  content: const OnboardingIntroPage(),
                ),
                OnboardingShell(
                  key: const ValueKey('onboarding-step-1'),
                  currentStep: 1,
                  showBack: true,
                  primaryLabel: 'Continue',
                  onBack: cubit.previousStep,
                  onPrimary: cubit.nextStep,
                  content: const OnboardingWeightPlaceholder(),
                ),
                OnboardingShell(
                  key: const ValueKey('onboarding-step-2'),
                  currentStep: 2,
                  showBack: true,
                  primaryLabel: 'Continue',
                  onBack: cubit.previousStep,
                  onPrimary: () {},
                  content: const OnboardingHeightPlaceholder(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
