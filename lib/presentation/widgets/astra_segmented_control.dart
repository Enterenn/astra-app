import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import 'astra_pressable.dart';

/// One segment in [AstraSegmentedControl].
class AstraSegmentOption<T> {
  const AstraSegmentOption({
    required this.value,
    required this.label,
    this.semanticsLabel,
  });

  final T value;
  final String label;
  final String? semanticsLabel;

  String get effectiveSemanticsLabel => semanticsLabel ?? label;
}

/// Shared segmented pill with sliding thumb, press scale, and active/inactive typography.
class AstraSegmentedControl<T> extends StatelessWidget {
  const AstraSegmentedControl({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.semanticsHint,
    this.enabled = true,
    this.fireOnReselect = true,
    super.key,
  });

  final List<AstraSegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String semanticsHint;
  final bool enabled;
  final bool fireOnReselect;

  static const thumbDuration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final selectedIndex = options.indexWhere((option) => option.value == selected);
    final safeSelectedIndex = selectedIndex < 0 ? 0 : selectedIndex;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgSubtle,
        borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AstraSpacing.kSpaceXs),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / options.length;

            return Stack(
              children: [
                AnimatedPositioned(
                  duration:
                      disableAnimations ? Duration.zero : thumbDuration,
                  curve: Curves.easeInOutCubic,
                  left: safeSelectedIndex * segmentWidth,
                  width: segmentWidth,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.bgElevated,
                      borderRadius: BorderRadius.circular(
                        AstraSpacing.kRadiusFull,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final option in options)
                      Expanded(
                        child: _SegmentTarget<T>(
                          option: option,
                          selected: option.value == selected,
                          enabled: enabled,
                          semanticsHint: semanticsHint,
                          colors: colors,
                          fireOnReselect: fireOnReselect,
                          onChanged: onChanged,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SegmentTarget<T> extends StatelessWidget {
  const _SegmentTarget({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.semanticsHint,
    required this.colors,
    required this.fireOnReselect,
    required this.onChanged,
  });

  final AstraSegmentOption<T> option;
  final bool selected;
  final bool enabled;
  final String semanticsHint;
  final AstraColors colors;
  final bool fireOnReselect;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final canSelect = enabled && (fireOnReselect || !selected);
    final textStyle = AstraTypography.labelFor(colors).copyWith(
      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
      color: selected ? colors.textPrimary : colors.neutralGray,
    );

    return Semantics(
      button: canSelect,
      enabled: canSelect,
      selected: selected,
      label: option.effectiveSemanticsLabel,
      hint: semanticsHint,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AstraPressable(
          enabled: canSelect,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
            child: InkWell(
              onTap: canSelect ? () => onChanged(option.value) : null,
              borderRadius: BorderRadius.circular(AstraSpacing.kRadiusFull),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AstraSpacing.kMinTouchTarget,
                ),
                child: Center(
                  child: Text(
                    option.label,
                    style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
