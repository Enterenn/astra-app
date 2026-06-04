import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../core/health/background_health_capability_snapshot.dart';
import '../cubits/my_data_state.dart';
import '../formatters/relative_time_formatter.dart';

class BackgroundStatusCard extends StatelessWidget {
  const BackgroundStatusCard({
    required this.status,
    required this.lastIngestionUtc,
    required this.nowUtc,
    this.capabilities,
    this.onOpenSettings,
    super.key,
  });

  final BackgroundCollectionStatus status;
  final DateTime? lastIngestionUtc;
  final DateTime nowUtc;
  final BackgroundHealthCapabilitySnapshot? capabilities;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final lastUpdated = formatRelativeTime(
      instantUtc: lastIngestionUtc,
      nowUtc: nowUtc,
    );

    final dotColor = switch (status) {
      BackgroundCollectionStatus.healthy => colors.statusOk,
      BackgroundCollectionStatus.stale => colors.statusStale,
      BackgroundCollectionStatus.iosBackfill => colors.statusInfo,
      BackgroundCollectionStatus.permissionDenied => colors.textMuted,
    };

    final statusCopy = switch (status) {
      BackgroundCollectionStatus.healthy => 'Steps are updating',
      BackgroundCollectionStatus.stale => 'Steps may be delayed',
      BackgroundCollectionStatus.iosBackfill =>
        'Updates when you open the app',
      BackgroundCollectionStatus.permissionDenied => 'Step access is off',
    };

    final showLastUpdated =
        status != BackgroundCollectionStatus.permissionDenied;

    final showOemHint =
        status == BackgroundCollectionStatus.stale &&
        capabilities?.likelyOemBatteryDeferral == true &&
        capabilities?.manufacturer != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Semantics(
                label: 'Status indicator',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusCopy,
                    style: AstraTypography.bodyFor(colors),
                  ),
                  if (showLastUpdated) ...[
                    const SizedBox(height: AstraSpacing.kSpaceXs),
                    Text(
                      'Last updated $lastUpdated',
                      style: AstraTypography.captionFor(colors),
                    ),
                  ],
                ],
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
              child: const Text('Turn on in Settings'),
            ),
          ),
        ],
        if (showOemHint) ...[
          const SizedBox(height: AstraSpacing.kSpaceSm),
          Text(
            'Battery settings on ${capabilities!.manufacturer} devices can delay updates.',
            style: AstraTypography.captionFor(colors),
          ),
        ],
      ],
    );
  }
}
