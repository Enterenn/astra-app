import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/week_trophy_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

void main() {
  Future<void> pumpBadge(
    WidgetTester tester, {
    required int goalsMetCount,
    int totalDays = 7,
  }) async {
    await tester.pumpWidget(
      TestMaterialApp(
        theme: buildAstraLightTheme(),
        home: Scaffold(
          body: WeekTrophyBadge(
            goalsMetCount: goalsMetCount,
            totalDays: totalDays,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('WeekTrophyBadge', () {
    testWidgets('renders goals met count as X/7', (tester) async {
      await pumpBadge(tester, goalsMetCount: 3);

      expect(find.text('3/7'), findsOneWidget);
    });

    testWidgets('respects custom totalDays', (tester) async {
      await pumpBadge(tester, goalsMetCount: 2, totalDays: 5);

      expect(find.text('2/5'), findsOneWidget);
    });

    testWidgets('exposes semantics label for screen readers', (tester) async {
      final handle = tester.ensureSemantics();

      await pumpBadge(tester, goalsMetCount: 3);

      expect(
        find.bySemanticsLabel('Goals met 3 of 7 days this week'),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
