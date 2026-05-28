import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

/// Temporary screen until Story 1.3 (tab shell). Proves tokens + theme wiring.
class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({super.key});

  static const primaryTouchTargetKey = Key('primaryTouchTarget');

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        title: Text(
          'ASTRA Theme Preview',
          style: AstraTypography.title(context),
        ),
        backgroundColor: colors.bgElevated,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AstraSpacing.kScreenHorizontalPadding,
          vertical: AstraSpacing.kSpaceLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Display', style: AstraTypography.display(context)),
            const SizedBox(height: AstraSpacing.kSpaceSm),
            Text('Title', style: AstraTypography.title(context)),
            const SizedBox(height: AstraSpacing.kSpaceSm),
            Text('Headline', style: AstraTypography.headline(context)),
            const SizedBox(height: AstraSpacing.kSpaceSm),
            Text(
              'Body — trust copy and labels.',
              style: AstraTypography.body(context),
            ),
            const SizedBox(height: AstraSpacing.kSpaceSm),
            Text('Label', style: AstraTypography.label(context)),
            const SizedBox(height: AstraSpacing.kSpaceSm),
            Text(
              'Caption · source tag',
              style: AstraTypography.caption(context),
            ),
            const SizedBox(height: AstraSpacing.kSpaceSm),
            Text('12 450', style: AstraTypography.data(context)),
            const SizedBox(height: AstraSpacing.kSpaceLg),
            Text('Color swatches', style: AstraTypography.headline(context)),
            const SizedBox(height: AstraSpacing.kSpaceMd),
            _SwatchRow(
              colors: [
                _Swatch('Accent', colors.accentPrimary),
                _Swatch('OK', colors.statusOk),
                _Swatch('Stale', colors.statusStale),
                _Swatch('Danger', colors.statusDanger),
                _Swatch('Data +', colors.dataPositive),
                _Swatch('Goal', colors.dataGoalLine),
              ],
            ),
            const SizedBox(height: AstraSpacing.kSpaceXl),
            SizedBox(
              key: primaryTouchTargetKey,
              width: double.infinity,
              height: AstraSpacing.kMinTouchTarget,
              child: FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accentPrimary,
                  foregroundColor: colors.textInverse,
                ),
                child: Text(
                  'Primary action',
                  style: AstraTypography.label(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch {
  const _Swatch(this.label, this.color);
  final String label;
  final Color color;
}

class _SwatchRow extends StatelessWidget {
  const _SwatchRow({required this.colors});

  final List<_Swatch> colors;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AstraSpacing.kSpaceSm,
      runSpacing: AstraSpacing.kSpaceSm,
      children: colors
          .map(
            (s) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
                    border: Border.all(
                      color: context.astraColors.borderDefault,
                    ),
                  ),
                ),
                const SizedBox(height: AstraSpacing.kSpaceXs),
                Text(s.label, style: AstraTypography.caption(context)),
              ],
            ),
          )
          .toList(),
    );
  }
}
