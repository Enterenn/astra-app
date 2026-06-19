import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../formatters/relative_time_formatter.dart';
import '../helpers/collection_health_evaluator.dart';

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
        CollectionHealthDisplay.loading => '',
        CollectionHealthDisplay.active => 'Collection active ●',
        CollectionHealthDisplay.stale =>
          'Last sync ${formatRelativeTime(instantUtc: lastIngestionUtc, nowUtc: nowUtc)} ⚠',
        CollectionHealthDisplay.permissionDenied => 'Sensor access revoked ✕',
      };

  Color _dotColor(AstraColors colors) => switch (display) {
        CollectionHealthDisplay.loading => colors.textMuted,
        CollectionHealthDisplay.active => colors.statusOk,
        CollectionHealthDisplay.stale => colors.statusStale,
        CollectionHealthDisplay.permissionDenied => colors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    if (display == CollectionHealthDisplay.loading) {
      return const SizedBox.shrink();
    }

    final colors = context.astraColors;

    return Semantics(
      label: _label,
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
                color: _dotColor(colors),
                shape: BoxShape.circle,
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
      ),
    );
  }
}
