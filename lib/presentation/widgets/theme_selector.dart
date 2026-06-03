import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../cubits/theme_state.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final AstraThemePreference selected;
  final ValueChanged<AstraThemePreference> onChanged;
  final bool enabled;

  static const _options = [
    (AstraThemePreference.system, 'System', 'System appearance'),
    (AstraThemePreference.light, 'Light', 'Light appearance'),
    (AstraThemePreference.dark, 'Dark', 'Dark appearance'),
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
            for (final (preference, label, semanticsLabel) in _options)
              Expanded(
                child: _SegmentButton(
                  label: label,
                  semanticsLabel: semanticsLabel,
                  selected: selected == preference,
                  enabled: enabled,
                  colors: colors,
                  disableAnimations: disableAnimations,
                  onTap: enabled && selected != preference
                      ? () => onChanged(preference)
                      : null,
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
    required this.semanticsLabel,
    required this.selected,
    required this.enabled,
    required this.colors,
    required this.disableAnimations,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final bool selected;
  final bool enabled;
  final AstraColors colors;
  final bool disableAnimations;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textStyle = AstraTypography.labelFor(colors).copyWith(
      color: selected ? colors.textPrimary : colors.textMuted,
    );

    final interactionEnabled = enabled && onTap != null;

    return Semantics(
      button: interactionEnabled,
      enabled: interactionEnabled,
      selected: selected,
      label: semanticsLabel,
      hint: 'App theme',
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
