import 'package:flutter/material.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../utils/display_name_initials.dart';

/// Tappable row showing the local display name with edit affordance.
class DisplayNameEditorRow extends StatelessWidget {
  const DisplayNameEditorRow({
    required this.displayName,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final String? displayName;
  final VoidCallback? onTap;
  final bool enabled;

  bool get _isEnabled => enabled && onTap != null;

  String get _valueLabel {
    if (!hasTrimmedDisplayName(displayName)) {
      return 'Not set';
    }
    return displayName!.trim();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final valueColor =
        _isEnabled ? colors.textPrimary : colors.textMuted;

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: _isEnabled
          ? 'Display name, $_valueLabel. Double tap to edit.'
          : 'Display name, $_valueLabel.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(AstraSpacing.kRadiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AstraSpacing.kSpaceXs),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Display name',
                        style: AstraTypography.body(context),
                      ),
                      const SizedBox(height: AstraSpacing.kSpaceXs),
                      Text(
                        _valueLabel,
                        style: AstraTypography.headline(context).copyWith(
                          color: valueColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: _isEnabled ? colors.textSecondary : colors.textMuted,
                  semanticLabel: 'Edit display name',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
