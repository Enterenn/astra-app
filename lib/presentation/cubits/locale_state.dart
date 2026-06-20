import 'package:flutter/material.dart';

class LocaleState {
  const LocaleState({this.explicitLanguageCode});

  final String? explicitLanguageCode;

  Locale? get materialLocale =>
      explicitLanguageCode == null ? null : Locale(explicitLanguageCode!);
}
