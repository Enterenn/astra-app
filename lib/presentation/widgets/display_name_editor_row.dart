import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

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

  String _valueLabel(AppLocalizations l10n) {
    if (!hasTrimmedDisplayName(displayName)) {
      return l10n.commonNotSet;
    }
    return displayName!.trim();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.astraColors;
    final valueLabel = _valueLabel(l10n);
    final valueColor =
        _isEnabled ? colors.textPrimary : colors.textMuted;

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: _isEnabled
          ? l10n.profileDisplayNameSemantics(
              valueLabel,
              l10n.commonDoubleTapToEdit,
            )
          : l10n.profileDisplayNameReadOnlySemantics(valueLabel),
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
                        l10n.profileDisplayName,
                        style: AstraTypography.body(context),
                      ),
                      const SizedBox(height: AstraSpacing.kSpaceXs),
                      Text(
                        valueLabel,
                        style: AstraTypography.headline(context).copyWith(
                          color: valueColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  color: _isEnabled ? colors.neutralGray : colors.textMuted,
                  semanticLabel: l10n.profileDisplayNameEditSemantics,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
