import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:astra_app/presentation/widgets/goal_celebration.dart';
import 'package:astra_app/presentation/widgets/goal_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoalCelebration', () {
    final celebrationState = TodayState.fromData(
      steps: 8000,
      goal: 8000,
      isStale: false,
    );

    Future<void> pumpCelebration(
      WidgetTester tester, {
      required VoidCallback onComplete,
      bool disableAnimations = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: disableAnimations,
            ),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  child: GoalCelebration(
                    state: celebrationState,
                    onComplete: onComplete,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('reduce motion shows micro-copy without glow animation', (
      tester,
    ) async {
      var completed = false;
      await pumpCelebration(
        tester,
        disableAnimations: true,
        onComplete: () => completed = true,
      );

      expect(find.text('Daily goal reached'), findsOneWidget);
      expect(find.byType(GoalRing), findsOneWidget);
      expect(find.byType(ImageFiltered), findsNothing);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1));

      expect(completed, isTrue);
    });

    testWidgets('semantics live region announces goal once', (tester) async {
      final handle = tester.ensureSemantics();
      var completed = false;

      await pumpCelebration(
        tester,
        disableAnimations: true,
        onComplete: () => completed = true,
      );

      expect(find.bySemanticsLabel('Daily goal reached'), findsOneWidget);
      final semanticsWidget = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(GoalCelebration),
          matching: find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.liveRegion == true,
          ),
        ),
      );
      expect(semanticsWidget.properties.liveRegion, isTrue);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1));
      expect(completed, isTrue);

      handle.dispose();
    });

    testWidgets('onComplete fires after celebration sequence', (
      tester,
    ) async {
      var completed = false;
      await pumpCelebration(
        tester,
        onComplete: () => completed = true,
      );

      expect(completed, isFalse);
      await tester.pump(GoalCelebration.celebrationSequenceDuration);
      await tester.pump(const Duration(milliseconds: 1));
      expect(completed, isTrue);
    });
  });
}
