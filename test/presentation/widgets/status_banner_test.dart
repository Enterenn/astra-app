import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StatusBanner', () {
    testWidgets('staleCompact variant shows compact stale copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: const Scaffold(
            body: StatusBanner(variant: StatusBannerVariant.staleCompact),
          ),
        ),
      );

      expect(
        find.text('Steps may be delayed — tap to refresh'),
        findsOneWidget,
      );
    });

    testWidgets('staleCompact exposes full copy as semantics label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: StatusBanner(
              variant: StatusBannerVariant.staleCompact,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Steps may be delayed — tap to refresh'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('staleCompact invokes onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
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
        MaterialApp(
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
        MaterialApp(
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
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: const Scaffold(
            body: StatusBanner(variant: StatusBannerVariant.info),
          ),
        ),
      );

      expect(
        find.text('Steps update when you open the app on this device.'),
        findsOneWidget,
      );
    });
  });
}
