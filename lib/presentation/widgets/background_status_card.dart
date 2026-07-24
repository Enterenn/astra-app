import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/my_data_state.dart';
import '../cubits/onboarding_state.dart' show PermissionRequestStatus;
import '../formatters/relative_time_formatter.dart';

class BackgroundStatusCard extends StatelessWidget {
  const BackgroundStatusCard({
    required this.status,
    required this.lastIngestionUtc,
    required this.nowUtc,
    this.activityPermissionDenial,
    this.onOpenSettings,
    this.onRetryPermission,
    super.key,
  });

  final BackgroundCollectionStatus status;
  final DateTime? lastIngestionUtc;
  final DateTime nowUtc;
  final PermissionRequestStatus? activityPermissionDenial;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onRetryPermission;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.astraColors;
    final lastSync = formatRelativeTimeLocalized(
      l10n,
      instantUtc: lastIngestionUtc,
      nowUtc: nowUtc,
    );

    final dotColor = switch (status) {
      BackgroundCollectionStatus.healthy => colors.statusOk,
      BackgroundCollectionStatus.stale => colors.statusStale,
      BackgroundCollectionStatus.iosBackfill => colors.statusInfo,
      BackgroundCollectionStatus.permissionDenied => colors.textMuted,
    };

    final primaryCopy = switch (status) {
      BackgroundCollectionStatus.healthy =>
        l10n.myDataBackgroundHealthy(lastSync),
      BackgroundCollectionStatus.stale =>
        l10n.myDataBackgroundStale(lastSync),
      BackgroundCollectionStatus.iosBackfill =>
        l10n.myDataBackgroundIosBackfill(lastSync),
      BackgroundCollectionStatus.permissionDenied =>
        _permissionDeniedCopy(l10n),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: primaryCopy,
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
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: AstraSpacing.kSpaceSm),
              Expanded(
                child: Text(
                  primaryCopy,
                  style: AstraTypography.bodyFor(colors),
                ),
              ),
            ],
          ),
        ),
        if (status == BackgroundCollectionStatus.permissionDenied) ...[
          const SizedBox(height: AstraSpacing.kSpaceSm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed:
                  activityPermissionDenial ==
                      PermissionRequestStatus.permanentlyDenied
                  ? onOpenSettings
                  : activityPermissionDenial == PermissionRequestStatus.denied
                  ? onRetryPermission
                  : onOpenSettings,
              child: Text(
                activityPermissionDenial ==
                        PermissionRequestStatus.permanentlyDenied ||
                    activityPermissionDenial == null
                    ? l10n.myDataOpenSettings
                    : l10n.commonRetry,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _permissionDeniedCopy(AppLocalizations l10n) {
    return switch (activityPermissionDenial) {
      PermissionRequestStatus.permanentlyDenied =>
        l10n.myDataBackgroundPermissionPermanentlyDenied,
      PermissionRequestStatus.denied =>
        l10n.myDataBackgroundPermissionDeniedRetry,
      _ => l10n.myDataBackgroundPermissionDenied,
    };
  }
}
