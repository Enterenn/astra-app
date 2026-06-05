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

  static const _options = [
    AstraSegmentOption(
      value: AstraThemePreference.system,
      label: 'System',
      semanticsLabel: 'System appearance',
    ),
    AstraSegmentOption(
      value: AstraThemePreference.light,
      label: 'Light',
      semanticsLabel: 'Light appearance',
    ),
    AstraSegmentOption(
      value: AstraThemePreference.dark,
      label: 'Dark',
      semanticsLabel: 'Dark appearance',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AstraSegmentedControl<AstraThemePreference>(
      options: _options,
      selected: selected,
      onChanged: onChanged,
      enabled: enabled,
      fireOnReselect: false,
      semanticsHint: 'App theme',
    );
  }
}
