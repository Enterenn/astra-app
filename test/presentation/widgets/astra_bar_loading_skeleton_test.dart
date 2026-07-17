import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/astra_bar_loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

void main() {
  Future<void> pumpSkeleton(
    WidgetTester tester, {
    required int barCount,
    required double Function(int) barHeightAt,
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      TestMaterialApp(
        theme: buildAstraLightTheme(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              height: 200,
              child: AstraBarLoadingSkeleton(
                barCount: barCount,
                barHeightAt: barHeightAt,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Iterable<Container> _skeletonBars(WidgetTester tester) {
    return tester.widgetList<Container>(find.byType(Container)).where((c) {
      final d = c.decoration;
      if (d is! BoxDecoration) return false;
      final r = d.borderRadius;
      return r is BorderRadius && r.topLeft == const Radius.circular(4);
    });
  }

  group('AstraBarLoadingSkeleton', () {
    testWidgets('renders 7 skeleton bars for daily chart config', (
      tester,
    ) async {
      await pumpSkeleton(
        tester,
        barCount: 7,
        barHeightAt: (i) => 48 + (i % 3) * 24,
      );
      expect(_skeletonBars(tester).length, 7);
    });

    testWidgets('renders 12 skeleton bars for monthly chart config', (
      tester,
    ) async {
      await pumpSkeleton(
        tester,
        barCount: 12,
        barHeightAt: (i) => 40 + (i % 4) * 16,
      );
      expect(_skeletonBars(tester).length, 12);
    });

    testWidgets('bars use semi-transparent color (textMuted token, not solid)',
        (tester) async {
      await pumpSkeleton(
        tester,
        barCount: 7,
        barHeightAt: (i) => 48 + (i % 3) * 24,
        disableAnimations: true,
      );
      for (final bar in _skeletonBars(tester)) {
        final color = (bar.decoration! as BoxDecoration).color;
        expect(color, isNotNull);
        expect(color!.a, lessThan(1.0));
      }
    });

    testWidgets(
      'reduce-motion: renders static bars without AnimatedBuilder',
      (tester) async {
        await pumpSkeleton(
          tester,
          barCount: 7,
          barHeightAt: (i) => 48 + (i % 3) * 24,
          disableAnimations: true,
        );
        expect(_skeletonBars(tester).length, 7);
        expect(
          find.descendant(
            of: find.byType(AstraBarLoadingSkeleton),
            matching: find.byType(AnimatedBuilder),
          ),
          findsNothing,
        );
      },
    );
  });
}
