import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/my_data_state.dart';
import '../formatters/relative_time_formatter.dart';

class BackgroundStatusCard extends StatelessWidget {
  const BackgroundStatusCard({
    required this.status,
    required this.lastIngestionUtc,
    required this.nowUtc,
    this.onOpenSettings,
    super.key,
  });

  final BackgroundCollectionStatus status;
  final DateTime? lastIngestionUtc;
  final DateTime nowUtc;
  final VoidCallback? onOpenSettings;

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
        l10n.myDataBackgroundPermissionDenied,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Semantics(
                label: l10n.myDataStatusIndicator,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
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
        if (status == BackgroundCollectionStatus.permissionDenied) ...[
          const SizedBox(height: AstraSpacing.kSpaceSm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onOpenSettings,
              child: Text(l10n.myDataOpenSettings),
            ),
          ),
        ],
      ],
    );
  }
}
