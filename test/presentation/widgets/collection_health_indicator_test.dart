import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/l10n/app_localizations.dart';
import 'package:astra_app/presentation/helpers/collection_health_evaluator.dart';
import 'package:astra_app/presentation/widgets/collection_health_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final fixedNow = DateTime.utc(2026, 6, 3, 15);

  group('CollectionHealthIndicator', () {
    testWidgets('loading state renders nothing', (tester) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: CollectionHealthIndicator(
              display: CollectionHealthDisplay.loading,
              nowUtc: fixedNow,
            ),
          ),
        ),
      );

      expect(find.text(l10n.todayCollectionHealthActive), findsNothing);
      expect(find.text(l10n.todayCollectionHealthPermissionDenied), findsNothing);
      expect(find.byType(Row), findsNothing);
    });

    testWidgets('active state shows collection active copy', (tester) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: CollectionHealthIndicator(
              display: CollectionHealthDisplay.active,
              nowUtc: fixedNow,
            ),
          ),
        ),
      );

      expect(find.text(l10n.todayCollectionHealthActive), findsOneWidget);
    });

    testWidgets('stale state shows relative last sync copy', (tester) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: CollectionHealthIndicator(
              display: CollectionHealthDisplay.stale,
              lastIngestionUtc: fixedNow.subtract(const Duration(hours: 3)),
              nowUtc: fixedNow,
            ),
          ),
        ),
      );

      expect(
        find.text(l10n.todayCollectionHealthStale('3 hours ago')),
        findsOneWidget,
      );
    });

    testWidgets('permission denied state shows revoked copy', (tester) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: CollectionHealthIndicator(
              display: CollectionHealthDisplay.permissionDenied,
              nowUtc: fixedNow,
            ),
          ),
        ),
      );

      expect(find.text(l10n.todayCollectionHealthPermissionDenied), findsOneWidget);
    });

    testWidgets('exposes merged label as semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: CollectionHealthIndicator(
              display: CollectionHealthDisplay.active,
              nowUtc: fixedNow,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel(l10n.todayCollectionHealthActive), findsOneWidget);

      handle.dispose();
    });
  });
}
