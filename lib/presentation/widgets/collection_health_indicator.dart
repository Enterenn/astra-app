import 'package:astra_app/l10n/app_localizations.dart';
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

  String _label(AppLocalizations l10n) => switch (display) {
        CollectionHealthDisplay.loading => '',
        CollectionHealthDisplay.active => l10n.todayCollectionHealthActive,
        CollectionHealthDisplay.stale => l10n.todayCollectionHealthStale(
            formatRelativeTimeLocalized(
              l10n,
              instantUtc: lastIngestionUtc,
              nowUtc: nowUtc,
            ),
          ),
        CollectionHealthDisplay.permissionDenied =>
          l10n.todayCollectionHealthPermissionDenied,
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
    final l10n = AppLocalizations.of(context);
    final label = _label(l10n);

    return Semantics(
      label: label,
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
              label,
              style: AstraTypography.captionFor(colors),
            ),
          ),
        ],
      ),
    );
  }
}
