import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/l10n/app_localizations.dart';
import 'package:astra_app/presentation/widgets/status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('StatusBanner', () {
    testWidgets('staleCompact variant shows compact stale copy', (tester) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: const Scaffold(
            body: StatusBanner(variant: StatusBannerVariant.staleCompact),
          ),
        ),
      );

      expect(find.text(l10n.bannerStaleData), findsOneWidget);
    });

    testWidgets('staleCompact exposes full copy as semantics label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: StatusBanner(
              variant: StatusBannerVariant.staleCompact,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel(l10n.bannerStaleData), findsOneWidget);

      handle.dispose();
    });

    testWidgets('staleCompact invokes onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: StatusBanner(
              variant: StatusBannerVariant.staleCompact,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(StatusBanner));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('staleFull stub renders Android diagnostic copy', (tester) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: const Scaffold(
            body: StatusBanner(variant: StatusBannerVariant.staleFull),
          ),
        ),
      );

      expect(
        find.textContaining('No new steps in 12+ hours'),
        findsOneWidget,
      );
    });

    testWidgets('staleFull renders iOS diagnostic copy when isIos is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: const Scaffold(
            body: StatusBanner(
              variant: StatusBannerVariant.staleFull,
              isIos: true,
            ),
          ),
        ),
      );

      expect(
        find.textContaining('No new steps in 4+ hours'),
        findsOneWidget,
      );
    });

    testWidgets('info variant renders iOS backfill copy', (tester) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: const Scaffold(
            body: StatusBanner(variant: StatusBannerVariant.info),
          ),
        ),
      );

      expect(find.text(l10n.bannerInfoStepsSync), findsOneWidget);
    });
  });
}
