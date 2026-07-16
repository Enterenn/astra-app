import 'dart:async';

import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/profile_cubit.dart';
import '../cubits/profile_errors.dart';
import '../l10n/profile_error_messages.dart';
import 'astra_button.dart';

class ProfileLoadErrorPanel extends StatelessWidget {
  const ProfileLoadErrorPanel({required this.loadError, super.key});

  @visibleForTesting
  static const retryButtonKey = Key('profile_load_retry');

  final ProfileLoadError? loadError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AstraSpacing.kScreenHorizontalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              profileLoadErrorMessage(l10n, loadError),
              style: AstraTypography.body(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AstraSpacing.kSpaceMd),
            Semantics(
              button: true,
              label: l10n.commonRetry,
              child: AstraButton(
                key: retryButtonKey,
                label: l10n.commonRetry,
                variant: AstraButtonVariant.secondary,
                onPressed: () =>
                    unawaited(context.read<ProfileCubit>().refresh()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
