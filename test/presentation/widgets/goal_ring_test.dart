import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:astra_app/presentation/widgets/goal_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoalRing', () {
    Future<void> pumpGoalRing(
      WidgetTester tester, {
      required TodayState state,
      double width = 400,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: GoalRing(state: state),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    test('ringProgressFor caps overflow at 100%', () {
      final state = TodayState.fromData(
        steps: 10_847,
        goal: 8000,
        isStale: false,
      );

      expect(state.status, TodayStatus.overflow);
      expect(GoalRing.ringProgressFor(state), 1);
    });

    testWidgets('progress state shows formatted step count and goal label', (
      tester,
    ) async {
      await pumpGoalRing(
        tester,
        state: TodayState.fromData(
          steps: 3200,
          goal: 8000,
          isStale: false,
        ),
      );

      expect(find.text('3\u2009200'), findsOneWidget);
      expect(find.text('steps today'), findsOneWidget);
      expect(find.text('goal 8\u2009000'), findsOneWidget);
    });

    testWidgets('overflow state shows actual step count with full arc progress', (
      tester,
    ) async {
      await pumpGoalRing(
        tester,
        state: TodayState.fromData(
          steps: 10_847,
          goal: 8000,
          isStale: false,
        ),
      );

      expect(find.text('10\u2009847'), findsOneWidget);

      final painter = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(GoalRing),
          matching: find.byType(CustomPaint),
        ),
      );
      final delegate = painter.painter! as GoalRingPainter;
      expect(delegate.progress, 1);
    });

    testWidgets('no-permission state shows dashed placeholder center', (
      tester,
    ) async {
      await pumpGoalRing(
        tester,
        state: const TodayState.noPermission(),
      );

      expect(find.text('--'), findsOneWidget);

      final painter = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(GoalRing),
          matching: find.byType(CustomPaint),
        ),
      );
      final delegate = painter.painter! as GoalRingPainter;
      expect(delegate.dashedTrack, isTrue);
      expect(delegate.progress, 0);
    });

    testWidgets('empty state shows zero count', (tester) async {
      await pumpGoalRing(
        tester,
        state: TodayState.fromData(steps: 0, goal: 8000, isStale: false),
      );

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('semantics label describes steps versus goal', (tester) async {
      final handle = tester.ensureSemantics();

      await pumpGoalRing(
        tester,
        state: TodayState.fromData(
          steps: 4200,
          goal: 8000,
          isStale: false,
        ),
      );

      expect(
        find.bySemanticsLabel('Steps today: 4200 of 8000'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('no-permission semantics describe permission requirement', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await pumpGoalRing(
        tester,
        state: const TodayState.noPermission(),
      );

      expect(
        find.bySemanticsLabel('Steps today: permission required'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('ring diameter clamps between 220 and 260 logical pixels', (
      tester,
    ) async {
      await pumpGoalRing(
        tester,
        state: const TodayState.loading(),
        width: 1000,
      );

      final ringSize = tester.getSize(
        find.descendant(
          of: find.byType(GoalRing),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(ringSize.width, 260);
      expect(ringSize.height, 260);
    });
  });
}
