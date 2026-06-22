import 'package:astra_app/l10n/app_localizations.dart';
import 'package:astra_app/presentation/l10n/language_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

void main() {
  group('language_l10n', () {
    testWidgets('localizedLanguagePreferenceValueLabel uses automatic when unset', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestMaterialApp(
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              expect(
                localizedLanguagePreferenceValueLabel(l10n, null),
                l10n.settingsLanguageAutomatic,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('localizedLanguagePreferenceValueLabel uses French name', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestMaterialApp(
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              expect(
                localizedLanguagePreferenceValueLabel(l10n, 'fr'),
                l10n.settingsLanguageFrench,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });
}
