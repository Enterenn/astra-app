import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

String effectiveDeviceLanguageCode(BuildContext context) {
  final deviceLanguage =
      View.of(context).platformDispatcher.locale.languageCode;
  return deviceLanguage == 'fr' ? 'fr' : 'en';
}

String localizedLanguageName(AppLocalizations l10n, String languageCode) {
  return switch (languageCode) {
    'en' => l10n.settingsLanguageEnglish,
    'fr' => l10n.settingsLanguageFrench,
    _ => languageCode,
  };
}

String localizedLanguagePreferenceValueLabel(
  AppLocalizations l10n,
  String? explicitLanguageCode,
) {
  if (explicitLanguageCode == null) {
    return l10n.settingsLanguageAutomatic;
  }
  return localizedLanguageName(l10n, explicitLanguageCode);
}
