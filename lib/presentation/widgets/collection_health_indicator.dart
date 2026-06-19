import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../../core/health/collection_health_display.dart';
import '../formatters/relative_time_formatter.dart';

class CollectionHealthIndicator extends StatelessWidget {
  const CollectionHealthIndicator({
    required this.display,
    required this.nowUtc,
    this.lastIngestionUtc,
    super.key,
  });

  final CollectionHealthDisplay display;
  final DateTime? lastIngestionUtc;
  final DateTime nowUtc;

  String get _label => switch (display) {
        CollectionHealthDisplay.active => 'Collection active ●',
        CollectionHealthDisplay.stale =>
          'Last sync ${formatRelativeTime(instantUtc: lastIngestionUtc, nowUtc: nowUtc)} ⚠',
        CollectionHealthDisplay.permissionDenied => 'Sensor access revoked ✕',
      };

  Color _dotColor(AstraColors colors) => switch (display) {
        CollectionHealthDisplay.active => colors.statusOk,
        CollectionHealthDisplay.stale => colors.statusStale,
        CollectionHealthDisplay.permissionDenied => colors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Semantics(
            label: 'Collection health status',
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _dotColor(colors),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: AstraSpacing.kSpaceSm),
        Expanded(
          child: Text(
            _label,
            style: AstraTypography.captionFor(colors),
          ),
        ),
      ],
    );
  }
}
