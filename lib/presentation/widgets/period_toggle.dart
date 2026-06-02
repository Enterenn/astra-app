import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/history_state.dart';

class PeriodToggle extends StatelessWidget {
  const PeriodToggle({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final HistoryPeriod selected;
  final ValueChanged<HistoryPeriod> onChanged;

  static const _options = [
    (HistoryPeriod.days7, '7 days'),
    (HistoryPeriod.days30, '30 days'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgSubtle,
        borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AstraSpacing.kSpaceXs),
        child: Row(
          children: [
            for (final (period, label) in _options)
              Expanded(
                child: _SegmentButton(
                  label: label,
                  selected: selected == period,
                  colors: colors,
                  disableAnimations: disableAnimations,
                  onTap: () => onChanged(period),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.colors,
    required this.disableAnimations,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AstraColors colors;
  final bool disableAnimations;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textStyle = AstraTypography.labelFor(colors).copyWith(
      color: selected ? colors.textPrimary : colors.textMuted,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      hint: 'Chart range',
      child: Material(
        color: selected ? colors.bgElevated : Colors.transparent,
        borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AstraSpacing.kMinTouchTarget,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: textStyle),
                AnimatedContainer(
                  duration: disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                  height: 2,
                  width: selected ? 32 : 0,
                  margin: const EdgeInsets.only(top: AstraSpacing.kSpaceXs),
                  decoration: BoxDecoration(
                    color: colors.accentPrimary,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
