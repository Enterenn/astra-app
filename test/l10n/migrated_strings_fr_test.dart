import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/l10n/app_localizations.dart';
import 'package:astra_app/presentation/widgets/status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/l10n_test_helper.dart';

void main() {
  group('Migrated strings (fr)', () {
    testWidgets('StatusBanner staleCompact shows French bannerStaleData', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('fr'));

      await tester.pumpWidget(
        TestMaterialApp(
          locale: const Locale('fr'),
          theme: buildAstraLightTheme(),
          home: const Scaffold(
            body: StatusBanner(variant: StatusBannerVariant.staleCompact),
          ),
        ),
      );

      expect(find.text(l10n.bannerStaleData), findsOneWidget);
      expect(
        find.text('Données obsolètes. Toucher pour actualiser.'),
        findsOneWidget,
      );
    });
  });
}
