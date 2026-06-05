import 'package:flutter/material.dart';

import '../../core/constants/astra_accent_palette.dart';
import '../../core/constants/astra_accent_preset.dart';
import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';

/// Six bi-tone accent preset chips (FR-32, Story 5.11).
class AccentPresetSelector extends StatelessWidget {
  const AccentPresetSelector({
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    super.key,
  });

  final AstraAccentPreset selected;
  final ValueChanged<AstraAccentPreset> onSelected;
  final bool enabled;

  static const _presets = AstraAccentPreset.values;

  static String presetSemanticsLabel(AstraAccentPreset preset) =>
      switch (preset) {
        AstraAccentPreset.orange => 'Accent color, Orange',
        AstraAccentPreset.red => 'Accent color, Red',
        AstraAccentPreset.green => 'Accent color, Green',
        AstraAccentPreset.blue => 'Accent color, Blue',
        AstraAccentPreset.magenta => 'Accent color, Magenta',
        AstraAccentPreset.pink => 'Accent color, Pink',
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final baseColor = colors.bgElevated;

    return Row(
      children: [
        for (final preset in _presets)
          Expanded(
            child: _AccentChip(
              preset: preset,
              baseColor: baseColor,
              accentColor: accentPaletteFor(preset).primary,
              selected: selected == preset,
              enabled: enabled,
              borderColor: colors.neutralGray,
              selectedBorderColor: colors.accentPrimary,
              onTap: enabled && selected != preset
                  ? () => onSelected(preset)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _AccentChip extends StatelessWidget {
  const _AccentChip({
    required this.preset,
    required this.baseColor,
    required this.accentColor,
    required this.selected,
    required this.borderColor,
    required this.selectedBorderColor,
    required this.enabled,
    required this.onTap,
  });

  final AstraAccentPreset preset;
  final Color baseColor;
  final Color accentColor;
  final bool selected;
  final Color borderColor;
  final Color selectedBorderColor;
  final bool enabled;
  final VoidCallback? onTap;

  static const double _chipSize = AstraSpacing.kSpaceXl;

  @override
  Widget build(BuildContext context) {
    final borderWidth = selected ? 3.0 : 1.0;
    final effectiveBorderColor =
        selected ? selectedBorderColor : borderColor;

    return Semantics(
      button: enabled && onTap != null,
      enabled: enabled,
      selected: selected,
      label: AccentPresetSelector.presetSemanticsLabel(preset),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: double.infinity,
            height: AstraSpacing.kMinTouchTarget,
            child: Center(
              child: SizedBox(
                width: _chipSize,
                height: _chipSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: effectiveBorderColor,
                      width: borderWidth,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(borderWidth),
                    child: ClipOval(
                      child: CustomPaint(
                        painter: _BiToneChipPainter(
                          baseColor: baseColor,
                          accentColor: accentColor,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BiToneChipPainter extends CustomPainter {
  _BiToneChipPainter({
    required this.baseColor,
    required this.accentColor,
  });

  final Color baseColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final basePath = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(basePath, Paint()..color = baseColor);

    final accentPath = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(accentPath, Paint()..color = accentColor);
  }

  @override
  bool shouldRepaint(_BiToneChipPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor ||
        oldDelegate.accentColor != accentColor;
  }
}
