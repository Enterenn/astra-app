import 'package:astra_app/l10n/app_localizations.dart';

import '../../core/constants/astra_accent_preset.dart';
import '../../core/constants/display_unit_preferences.dart';

String localizedDistanceUnitPreferenceLabel(
  AppLocalizations l10n,
  DistanceDisplayUnit unit,
) {
  return switch (unit) {
    DistanceDisplayUnit.metric => l10n.unitDistanceMetric,
    DistanceDisplayUnit.imperial => l10n.unitDistanceImperial,
  };
}

String localizedWeightUnitPreferenceLabel(
  AppLocalizations l10n,
  WeightDisplayUnit unit,
) {
  return switch (unit) {
    WeightDisplayUnit.kg => l10n.unitWeightKg,
    WeightDisplayUnit.lb => l10n.unitWeightLb,
  };
}

String localizedHeightUnitPreferenceLabel(
  AppLocalizations l10n,
  HeightDisplayUnit unit,
) {
  return switch (unit) {
    HeightDisplayUnit.cm => l10n.unitHeightCm,
    HeightDisplayUnit.ftIn => l10n.unitHeightFtIn,
  };
}

String localizedAccentPresetSemanticsLabel(
  AppLocalizations l10n,
  AstraAccentPreset preset,
) {
  return switch (preset) {
    AstraAccentPreset.orange => l10n.settingsAccentOrange,
    AstraAccentPreset.red => l10n.settingsAccentRed,
    AstraAccentPreset.green => l10n.settingsAccentGreen,
    AstraAccentPreset.blue => l10n.settingsAccentBlue,
    AstraAccentPreset.magenta => l10n.settingsAccentMagenta,
    AstraAccentPreset.pink => l10n.settingsAccentPink,
  };
}
