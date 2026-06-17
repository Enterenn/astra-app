import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/onboarding_cubit.dart';
import '../cubits/onboarding_state.dart';
import '../widgets/astra_button.dart';
import 'onboarding_progress_bar.dart';

class OnboardingPermissionsPage extends StatelessWidget {
  const OnboardingPermissionsPage({super.key});

  Future<void> _onAllowActivityAccess(BuildContext context) async {
    final cubit = context.read<OnboardingCubit>();
    await cubit.requestActivityPermission();
    await cubit.requestNotificationPermissionIfOptedIn();
    cubit.nextStep();
  }

  Future<void> _onSkipNotifications(BuildContext context) async {
    final cubit = context.read<OnboardingCubit>();
    cubit.setNotificationOptIn(false);
    await cubit.requestActivityPermission();
    cubit.nextStep();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final cubit = context.watch<OnboardingCubit>();
    final state = cubit.state;
    final isRequesting =
        state.activityPermissionStatus == PermissionRequestStatus.requesting ||
        state.notificationPermissionStatus ==
            PermissionRequestStatus.requesting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: isRequesting ? null : cubit.previousStep,
              icon: Icon(PhosphorIconsRegular.arrowLeft, color: colors.textPrimary),
              tooltip: 'Back',
            ),
            const Expanded(
              child: OnboardingProgressBar(currentStep: 1, totalSteps: 4),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: AstraSpacing.kSpaceLg),
        Text(
          'To count steps, ASTRA needs activity access on this phone.',
          style: AstraTypography.bodyFor(colors),
        ),
        const SizedBox(height: AstraSpacing.kSpaceXl),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Notify when daily goal is reached',
            style: AstraTypography.labelFor(colors),
          ),
          value: state.notificationOptIn,
          onChanged: isRequesting ? null : cubit.setNotificationOptIn,
        ),
        const Spacer(),
        AstraButton(
          label: 'Allow activity access',
          isLoading: isRequesting,
          onPressed: isRequesting
              ? null
              : () async => _onAllowActivityAccess(context),
        ),
        const SizedBox(height: AstraSpacing.kSpaceMd),
        AstraButton(
          label: 'Skip notifications',
          variant: AstraButtonVariant.ghost,
          onPressed: isRequesting
              ? null
              : () async => _onSkipNotifications(context),
        ),
      ],
    );
  }
}
