import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:astra_app/presentation/widgets/goal_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/astra_theme_test_helper.dart';

void main() {
  group('GoalRing', () {
    setUp(() {
      GoalRing.disableStepPersistence = true;
    });

    tearDown(() {
      GoalRing.disableStepPersistence = false;
    });
    Future<void> pumpGoalRing(
      WidgetTester tester, {
      required TodayState state,
      double width = 400,
      AstraAccentPreset preset = AstraAccentPreset.orange,
    }) async {
      await tester.pumpWidget(
        wrapWithAstraTheme(
          Center(
            child: SizedBox(
              width: width,
              child: GoalRing(state: state),
            ),
          ),
          preset: preset,
        ),
      );
      await tester.pump();
    }

    GoalRingPainter ringPainter(WidgetTester tester) {
      final painters = tester.widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(GoalRing),
          matching: find.byType(CustomPaint),
        ),
      );
      for (final painter in painters) {
        if (painter.painter is GoalRingPainter) {
          return painter.painter! as GoalRingPainter;
        }
      }
      throw StateError('GoalRingPainter not found');
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
      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('/8\u2009000'), findsOneWidget);
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

      expect(ringPainter(tester).progress, 1);
    });

    testWidgets('progress arc uses accent primary at 66% opacity before goal met',
        (tester) async {
      await pumpGoalRing(
        tester,
        preset: AstraAccentPreset.blue,
        state: TodayState.fromData(
          steps: 3200,
          goal: 8000,
          isStale: false,
        ),
      );

      final colors = AstraColors.light(preset: AstraAccentPreset.blue);
      final delegate = ringPainter(tester);
      expect(delegate.trackColor, colors.bgSubtle);
      expect(
        delegate.progressColor,
        colors.accentPrimary.withValues(alpha: 0.66),
      );
    });

    testWidgets('progress arc uses accent primary at 100% opacity when goal met',
        (tester) async {
      await pumpGoalRing(
        tester,
        preset: AstraAccentPreset.blue,
        state: TodayState.fromData(
          steps: 8000,
          goal: 8000,
          isStale: false,
        ),
      );

      expect(TodayState.fromData(
        steps: 8000,
        goal: 8000,
        isStale: false,
      ).status, TodayStatus.goalMet);

      final colors = AstraColors.light(preset: AstraAccentPreset.blue);
      final delegate = ringPainter(tester);
      expect(delegate.trackColor, colors.bgSubtle);
      expect(delegate.progressColor, colors.accentPrimary);
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

      final delegate = ringPainter(tester);
      expect(delegate.dashedTrack, isTrue);
      expect(delegate.progress, 0);
    });

    testWidgets('preview count-up fills arc while steps are still empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithAstraTheme(
          Center(
            child: SizedBox(
              width: 400,
              child: GoalRing(
                state: TodayState.fromData(
                  steps: 0,
                  goal: 2500,
                  isStale: false,
                ),
                previewCountUpTarget: 2500,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();

      final delegate = ringPainter(tester);
      expect(delegate.progress, greaterThan(0.1));
      expect(delegate.progress, lessThan(1.0));
    });

    testWidgets('empty state shows zero count', (tester) async {
      await pumpGoalRing(
        tester,
        state: TodayState.fromData(steps: 0, goal: 8000, isStale: false),
      );

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('overflow semantics use goal-reached copy', (tester) async {
      final handle = tester.ensureSemantics();

      await pumpGoalRing(
        tester,
        state: TodayState.fromData(
          steps: 10_847,
          goal: 8000,
          isStale: false,
        ),
      );

      expect(
        find.bySemanticsLabel(
          'Steps today: 10847. Daily goal 8000 reached.',
        ),
        findsOneWidget,
      );

      handle.dispose();
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
