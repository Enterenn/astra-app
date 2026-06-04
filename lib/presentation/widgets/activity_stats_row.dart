import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

/// Three-column activity stats (Epic 6 fills real values; Story 5.9 mock placeholders).
class ActivityStatsRow extends StatelessWidget {
  const ActivityStatsRow({super.key});

  /// Visual-only placeholders until Epic 6 derived metrics.
  static const _kMockKcal = '420';
  static const _kMockKm = '4.2';
  static const _kMockDuration = '00:37:20';

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatColumn(
              icon: PhosphorIconsRegular.fire,
              value: _kMockKcal,
              label: 'Kcal',
              colors: colors,
            ),
          ),
          _StatDivider(color: colors.accentPrimary),
          Expanded(
            child: _StatColumn(
              icon: PhosphorIconsRegular.mapPin,
              value: _kMockKm,
              label: 'Km',
              colors: colors,
            ),
          ),
          _StatDivider(color: colors.accentPrimary),
          Expanded(
            child: _StatColumn(
              icon: PhosphorIconsRegular.clock,
              value: _kMockDuration,
              colors: colors,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      color: color,
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.icon,
    required this.value,
    required this.colors,
    this.label,
  });

  final IconData icon;
  final String value;
  final String? label;
  final AstraColors colors;

  TextStyle get _dataStyle => AstraTypography.captionFor(colors).copyWith(
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: colors.neutralGray),
        const SizedBox(height: AstraSpacing.kSpaceXs),
        if (label != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: _dataStyle),
              const SizedBox(width: AstraSpacing.kSpaceXs),
              Text(label!, style: _dataStyle),
            ],
          )
        else
          Text(
            value,
            style: _dataStyle.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}
