import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../formatters/file_size_formatter.dart';
import '../formatters/relative_time_formatter.dart';
import '../formatters/step_count_formatter.dart';

class FootprintKpiRow extends StatelessWidget {
  const FootprintKpiRow({
    required this.sampleCount,
    required this.fileSizeBytes,
    required this.lastOptimizedUtc,
    required this.nowUtc,
    super.key,
  });

  final int sampleCount;
  final int fileSizeBytes;
  final DateTime? lastOptimizedUtc;
  final DateTime nowUtc;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.astraColors;
    final formattedCount = formatStepCount(sampleCount);
    final formattedSize = formatFileSize(fileSizeBytes);
    final relativeTime = lastOptimizedUtc == null
        ? null
        : formatRelativeTimeLocalized(
            l10n,
            instantUtc: lastOptimizedUtc,
            nowUtc: nowUtc,
          );
    final optimizedLabel = lastOptimizedUtc == null
        ? l10n.myDataFootprintNotOptimizedYet
        : l10n.myDataFootprintOptimized(relativeTime!);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRow = constraints.maxWidth >= 480;

        final sampleKpi = _KpiItem(
          value: formattedCount,
          label: l10n.myDataFootprintSamplesStored,
          semanticsLabel: l10n.myDataFootprintSamplesStoredSemantics(
            formattedCount,
          ),
          colors: colors,
        );
        final sizeKpi = _KpiItem(
          value: formattedSize,
          label: l10n.myDataFootprintDatabaseSize,
          semanticsLabel: l10n.myDataFootprintDatabaseSizeSemantics(
            formattedSize,
          ),
          colors: colors,
        );
        final optimizedKpi = _KpiItem(
          value: lastOptimizedUtc == null ? '—' : relativeTime!,
          label: optimizedLabel,
          semanticsLabel: optimizedLabel,
          colors: colors,
        );

        if (useRow) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: sampleKpi),
              const SizedBox(width: AstraSpacing.kSpaceMd),
              Expanded(child: sizeKpi),
              const SizedBox(width: AstraSpacing.kSpaceMd),
              Expanded(child: optimizedKpi),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            sampleKpi,
            const SizedBox(height: AstraSpacing.kSpaceMd),
            sizeKpi,
            const SizedBox(height: AstraSpacing.kSpaceMd),
            optimizedKpi,
          ],
        );
      },
    );
  }
}

class _KpiItem extends StatelessWidget {
  const _KpiItem({
    required this.value,
    required this.label,
    required this.semanticsLabel,
    required this.colors,
  });

  final String value;
  final String label;
  final String semanticsLabel;
  final AstraColors colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AstraTypography.dataFor(colors)),
            const SizedBox(height: AstraSpacing.kSpaceXs),
            Text(label, style: AstraTypography.captionFor(colors)),
          ],
        ),
      ),
    );
  }
}
