import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../core/constants/astra_typography.dart';
import 'astra_segmented_control.dart';

String effectiveDeviceLanguageCode(BuildContext context) {
  final deviceLanguage =
      View.of(context).platformDispatcher.locale.languageCode;
  return deviceLanguage == 'fr' ? 'fr' : 'en';
}

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({
    required this.explicitLanguageCode,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  static const frenchSegmentKey = Key('language_selector_french');
  static const englishSegmentKey = Key('language_selector_english');

  final String? explicitLanguageCode;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = explicitLanguageCode ?? effectiveDeviceLanguageCode(context);
    final options = [
      AstraSegmentOption(
        value: 'en',
        label: l10n.settingsLanguageEnglish,
        semanticsLabel: l10n.settingsLanguageEnglish,
        segmentKey: LanguageSelector.englishSegmentKey,
      ),
      AstraSegmentOption(
        value: 'fr',
        label: l10n.settingsLanguageFrench,
        semanticsLabel: l10n.settingsLanguageFrench,
        segmentKey: LanguageSelector.frenchSegmentKey,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (explicitLanguageCode == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.settingsLanguageAutomatic,
              style: AstraTypography.caption(context),
            ),
          ),
        AstraSegmentedControl<String>(
          options: options,
          selected: selected,
          onChanged: onChanged,
          enabled: enabled,
          fireOnReselect: explicitLanguageCode == null,
          semanticsHint: l10n.settingsLanguage,
        ),
      ],
    );
  }
}
