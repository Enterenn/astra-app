import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../cubits/theme_state.dart';
import 'astra_segmented_control.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = [
      AstraSegmentOption(
        value: AstraThemePreference.system,
        label: l10n.settingsThemeSystem,
        semanticsLabel: l10n.settingsThemeSystemSemantics,
      ),
      AstraSegmentOption(
        value: AstraThemePreference.light,
        label: l10n.settingsThemeLight,
        semanticsLabel: l10n.settingsThemeLightSemantics,
      ),
      AstraSegmentOption(
        value: AstraThemePreference.dark,
        label: l10n.settingsThemeDark,
        semanticsLabel: l10n.settingsThemeDarkSemantics,
      ),
    ];

    return AstraSegmentedControl<AstraThemePreference>(
      options: options,
      selected: selected,
      onChanged: onChanged,
      enabled: enabled,
      fireOnReselect: false,
      semanticsHint: l10n.settingsThemeSemanticsHint,
    );
  }
}
