import 'package:flutter/material.dart';
import 'package:astra_app/core/icons/phosphor_icons.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';

/// Two-option bottom sheet picker for display unit preferences (Story 10.6).
Future<T?> showUnitOptionPickerSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required String Function(T option) labelFor,
  required T selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) {
      final colors = sheetContext.astraColors;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AstraSpacing.kScreenHorizontalPadding,
            AstraSpacing.kSpaceMd,
            AstraSpacing.kScreenHorizontalPadding,
            AstraSpacing.kSpaceLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AstraTypography.headline(sheetContext)),
              const SizedBox(height: AstraSpacing.kSpaceMd),
              for (final option in options) ...[
                _UnitOptionTile<T>(
                  label: labelFor(option),
                  selected: option == selected,
                  accentColor: colors.accentPrimary,
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
                if (option != options.last)
                  const SizedBox(height: AstraSpacing.kSpaceXs),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _UnitOptionTile<T> extends StatelessWidget {
  const _UnitOptionTile({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AstraSpacing.kSpaceSm,
              vertical: AstraSpacing.kSpaceSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AstraTypography.body(context).copyWith(
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? accentColor : colors.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    PhosphorIconsRegular.check,
                    color: accentColor,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
