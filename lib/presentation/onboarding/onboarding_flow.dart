import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/di/app_dependencies.dart';
import '../cubits/onboarding_cubit.dart';
import '../cubits/onboarding_state.dart';
import 'onboarding_height_page.dart';
import 'onboarding_intro_page.dart';
import 'onboarding_shell.dart';
import 'onboarding_weight_page.dart';

class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({
    super.key,
    required this.deps,
    required this.onComplete,
    this.createCubit,
  });

  final AppDependencies deps;
  final VoidCallback onComplete;
  final OnboardingCubit Function(AppDependencies deps)? createCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          createCubit?.call(deps) ??
          OnboardingCubit(
            userSettings: deps.userSettings,
            userHealthMetrics: deps.userHealthMetrics,
          ),
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

  Future<void> _onHeightLetsGo(BuildContext context) async {
    await context.read<OnboardingCubit>().completeWithHeight();
  }

  Future<void> _onHeightSkip(BuildContext context) async {
    await context.read<OnboardingCubit>().skipHeight();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                  primaryLabel: l10n.onboardingStartBtn,
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
                  primaryLabel: l10n.onboardingContinueBtn,
                  secondaryLabel: l10n.onboardingSkipBtn,
                  onBack: cubit.previousStep,
                  onSecondary: cubit.skipWeight,
                  onPrimary: cubit.commitWeightAndContinue,
                  content: const OnboardingWeightPage(),
                ),
                OnboardingShell(
                  key: const ValueKey('onboarding-step-2'),
                  currentStep: 2,
                  showBack: true,
                  primaryLabel: l10n.onboardingLetsGoBtn,
                  secondaryLabel: l10n.onboardingSkipBtn,
                  onBack: cubit.previousStep,
                  onSecondary: () => _onHeightSkip(context),
                  onPrimary: () => _onHeightLetsGo(context),
                  content: const OnboardingHeightPage(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
