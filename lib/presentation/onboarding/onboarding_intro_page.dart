import 'dart:async';

import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/onboarding_cubit.dart';
import '../cubits/onboarding_state.dart';
import '../widgets/trend_chip.dart';

class OnboardingIntroPage extends StatelessWidget {
  const OnboardingIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.astraColors;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.onboardingIntroHeadline,
            textAlign: TextAlign.center,
            style: AstraTypography.onboardingIntroTitleFor(colors),
          ),
          const SizedBox(height: AstraSpacing.kSpaceMd),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AstraSpacing.kSpaceSm,
            runSpacing: AstraSpacing.kSpaceSm,
            children: [
              CaptionPill(label: l10n.onboardingTrustOfflineBadge),
              CaptionPill(label: l10n.onboardingTrustNoAccountBadge),
            ],
          ),
          const SizedBox(height: AstraSpacing.kSpaceLg),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.bgElevated,
              borderRadius: BorderRadius.circular(AstraSpacing.kRadiusLg),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AstraSpacing.kCardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.onboardingIntroParagraphOne,
                    style: AstraTypography.bodyFor(colors),
                  ),
                  const SizedBox(height: AstraSpacing.kSpaceMd),
                  Text(
                    l10n.onboardingIntroParagraphTwo,
                    style: AstraTypography.bodyFor(colors),
                  ),
                ],
              ),
            ),
          ),
          const _IntroPermissionFeedback(),
        ],
      ),
    );
  }
}

class _IntroPermissionFeedback extends StatelessWidget {
  const _IntroPermissionFeedback();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<OnboardingCubit, OnboardingState, PermissionRequestStatus?>(
      selector: (state) {
        return switch (state.activityPermissionStatus) {
          PermissionRequestStatus.denied ||
          PermissionRequestStatus.permanentlyDenied =>
            state.activityPermissionStatus,
          _ => null,
        };
      },
      builder: (context, denial) {
        if (denial == null) {
          return const SizedBox.shrink();
        }

        final colors = context.astraColors;
        final l10n = AppLocalizations.of(context);
        final message = switch (denial) {
          PermissionRequestStatus.permanentlyDenied =>
            l10n.onboardingIntroPermissionPermanentlyDenied,
          PermissionRequestStatus.denied =>
            l10n.onboardingIntroPermissionDenied,
          _ => '',
        };
        final isPermanent =
            denial == PermissionRequestStatus.permanentlyDenied;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AstraSpacing.kSpaceLg),
            Semantics(
              liveRegion: true,
              label: message,
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: AstraSpacing.kSpaceSm),
                  Expanded(
                    child: Text(
                      message,
                      style: AstraTypography.bodyFor(colors),
                    ),
                  ),
                ],
              ),
            ),
            if (isPermanent) ...[
              const SizedBox(height: AstraSpacing.kSpaceSm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => unawaited(openAppSettings()),
                  child: Text(l10n.myDataOpenSettings),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
