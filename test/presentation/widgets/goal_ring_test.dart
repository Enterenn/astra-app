import 'dart:ui' show PictureRecorder;

import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:astra_app/presentation/cubits/today_state.dart';
import 'package:astra_app/presentation/widgets/animated_step_count.dart';
import 'package:astra_app/presentation/widgets/goal_ring.dart';
import 'package:astra_app/presentation/widgets/goal_ring_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/astra_theme_test_helper.dart';

class _LoadingToReadyHarness extends StatefulWidget {
  const _LoadingToReadyHarness({super.key});

  @override
  State<_LoadingToReadyHarness> createState() => _LoadingToReadyHarnessState();
}

class _LoadingToReadyHarnessState extends State<_LoadingToReadyHarness> {
  TodayState ringState = const TodayState.loading();

  void resolveLoading() {
    setState(() {
      ringState = TodayState.fromData(
        steps: 520,
        goal: 8000,
        isStale: false,
        lastDisplayedSteps: 470,
        lastDisplayedStepsLoaded: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GoalRing(state: ringState);
  }
}

class _LiveCoalesceHarness extends StatefulWidget {
  const _LiveCoalesceHarness({super.key});

  @override
  State<_LiveCoalesceHarness> createState() => _LiveCoalesceHarnessState();
}

class _LiveCoalesceHarnessState extends State<_LiveCoalesceHarness> {
  late TodayState ringState;

  @override
  void initState() {
    super.initState();
    ringState = TodayState.fromData(
      steps: 100,
      goal: 8000,
      isStale: false,
      lastDisplayedSteps: 100,
      lastDisplayedStepsLoaded: true,
    );
  }

  void bumpByMicroTickDelta() {
    setState(() {
      ringState = ringState.copyWith(steps: ringState.steps + 5);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GoalRing(state: ringState);
  }
}

class _ForegroundCatchUpHarness extends StatefulWidget {
  const _ForegroundCatchUpHarness({super.key});

  @override
  State<_ForegroundCatchUpHarness> createState() =>
      _ForegroundCatchUpHarnessState();
}

class _ForegroundCatchUpHarnessState extends State<_ForegroundCatchUpHarness> {
  bool catchUpHandled = false;
  late TodayState ringState;

  @override
  void initState() {
    super.initState();
    ringState = TodayState.fromData(
      steps: 100,
      goal: 8000,
      isStale: false,
      lastDisplayedSteps: 100,
      lastDisplayedStepsLoaded: true,
    );
  }

  void triggerForegroundCatchUp() {
    setState(() {
      ringState = ringState.copyWith(
        foregroundCatchUp: true,
        catchUpTargetSteps: 105,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GoalRing(
      state: ringState,
      onForegroundCatchUpHandled: () {
        catchUpHandled = true;
        setState(() {
          ringState = ringState.copyWith(foregroundCatchUp: false);
        });
      },
    );
  }
}

void main() {
  group('GoalRing', () {
    TodayState _displayReady(TodayState state) {
      if (state.lastDisplayedStepsLoaded) {
        return state;
      }
      return state.copyWith(
        lastDisplayedSteps: state.steps,
        lastDisplayedStepsLoaded: true,
      );
    }

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
              child: GoalRing(state: _displayReady(state)),
            ),
          ),
          preset: preset,
        ),
      );
      await tester.pump();
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

    bool hasOverflowAmbientPainter(WidgetTester tester) {
      return tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(GoalRing),
              matching: find.byType(CustomPaint),
            ),
          )
          .any((p) => p.painter is GoalRingOverflowAmbientPainter);
    }

    Future<void> unmountGoalRingAndAssertNoLateTimers(
      WidgetTester tester,
    ) async {
      expect(find.byType(GoalRing), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(find.byType(GoalRing), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
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

    test('useMicroTickForLiveDelta micro-tick up to 15 steps', () {
      expect(useMicroTickForLiveDelta(1), isTrue);
      expect(useMicroTickForLiveDelta(15), isTrue);
      expect(useMicroTickForLiveDelta(16), isFalse);
      expect(useMicroTickForLiveDelta(200), isFalse);
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

      expect(find.byType(AnimatedStepCount), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
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

      expect(find.byType(AnimatedStepCount), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);

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

    testWidgets('overflow state renders ambient shimmer layer', (tester) async {
      await pumpGoalRing(
        tester,
        state: TodayState.fromData(
          steps: 10_847,
          goal: 8000,
          isStale: false,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final painters = tester.widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(GoalRing),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(
        painters.any((p) => p.painter is GoalRingOverflowAmbientPainter),
        isTrue,
      );
    });

    testWidgets('overflow reduce motion skips ambient shimmer layer', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithAstraTheme(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Center(
              child: SizedBox(
                width: 400,
                child: GoalRing(
                  state: _displayReady(
                    TodayState.fromData(
                      steps: 10_847,
                      goal: 8000,
                      isStale: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final painters = tester.widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(GoalRing),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(
        painters.any((p) => p.painter is GoalRingOverflowAmbientPainter),
        isFalse,
      );
    });

    testWidgets('loading to ready triggers cold-start count-up', (
      tester,
    ) async {
      final harnessKey = GlobalKey<_LoadingToReadyHarnessState>();

      await tester.pumpWidget(
        wrapWithAstraTheme(
          Center(
            child: SizedBox(
              width: 400,
              child: _LoadingToReadyHarness(key: harnessKey),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('goal_ring_loading_skeleton')), findsOneWidget);

      harnessKey.currentState!.resolveLoading();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('goal_ring_loading_skeleton')), findsNothing);
      expect(find.textContaining('/'), findsOneWidget);

      final initialProgress = ringPainter(tester).progress;
      expect(initialProgress, closeTo(470 / 8000, 0.02));
      expect(initialProgress, lessThan(520 / 8000));

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(ringPainter(tester).progress, greaterThan(initialProgress));
    });

    testWidgets('cold start shows stored count before animating to target', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithAstraTheme(
          Center(
            child: SizedBox(
              width: 400,
              child: GoalRing(
                state: TodayState.fromData(
                  steps: 1024,
                  goal: 8000,
                  isStale: false,
                  lastDisplayedSteps: 470,
                  lastDisplayedStepsLoaded: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final initialProgress = ringPainter(tester).progress;
      expect(initialProgress, closeTo(470 / 8000, 0.02));
      expect(initialProgress, lessThan(1024 / 8000));

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final delegate = ringPainter(tester);
      expect(delegate.progress, greaterThan(initialProgress));
      expect(delegate.progress, lessThan(1.0));
    });

    testWidgets('semantics report target steps during count-up animation', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        wrapWithAstraTheme(
          Center(
            child: SizedBox(
              width: 400,
              child: GoalRing(
                state: TodayState.fromData(
                  steps: 1024,
                  goal: 8000,
                  isStale: false,
                  lastDisplayedSteps: 470,
                  lastDisplayedStepsLoaded: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.bySemanticsLabel('Steps today: 1024 of 8000'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('foreground catch-up plays count-up for small deltas', (
      tester,
    ) async {
      final harnessKey = GlobalKey<_ForegroundCatchUpHarnessState>();

      await tester.pumpWidget(
        wrapWithAstraTheme(
          Center(
            child: SizedBox(
              width: 400,
              child: _ForegroundCatchUpHarness(key: harnessKey),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      harnessKey.currentState!.triggerForegroundCatchUp();
      await tester.pump();

      expect(harnessKey.currentState!.catchUpHandled, isFalse);
      await tester.pump(kForegroundCatchUpDelay);
      await tester.pump();

      expect(harnessKey.currentState!.catchUpHandled, isFalse);
      await tester.pump(const Duration(milliseconds: 50));
      final midPainter = ringPainter(tester);
      expect(midPainter.progress, greaterThan(100 / 8000));
      expect(midPainter.progress, lessThan(105 / 8000));
      await tester.pumpAndSettle();
      expect(harnessKey.currentState!.catchUpHandled, isTrue);
      expect(ringPainter(tester).progress, closeTo(105 / 8000, 0.001));
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

    testWidgets('build returns RepaintBoundary as direct render root', (
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

      late Widget firstBuiltChild;
      var visited = false;
      tester.element(find.byType(GoalRing)).visitChildren((element) {
        if (!visited) {
          firstBuiltChild = element.widget;
          visited = true;
        }
      });
      expect(visited, isTrue);
      expect(firstBuiltChild, isA<RepaintBoundary>());
      expect(
        (firstBuiltChild as RepaintBoundary).child,
        isA<LayoutBuilder>(),
      );
    });

    testWidgets('dispose releases pulse animation without pending timers', (
      tester,
    ) async {
      await pumpGoalRing(
        tester,
        state: const TodayState.loading(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.descendant(
          of: find.byType(GoalRing),
          matching: find.byType(FadeTransition),
        ),
        findsOneWidget,
      );

      await unmountGoalRingAndAssertNoLateTimers(tester);
    });

    testWidgets('dispose releases overflow animation without pending timers', (
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
      await tester.pump(const Duration(milliseconds: 100));

      expect(hasOverflowAmbientPainter(tester), isTrue);

      await unmountGoalRingAndAssertNoLateTimers(tester);
    });

    testWidgets('dispose cancels live coalesce timer before it fires', (
      tester,
    ) async {
      final harnessKey = GlobalKey<_LiveCoalesceHarnessState>();

      await tester.pumpWidget(
        wrapWithAstraTheme(
          Center(
            child: SizedBox(
              width: 400,
              child: _LiveCoalesceHarness(key: harnessKey),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(ringPainter(tester).progress, closeTo(100 / 8000, 0.001));

      harnessKey.currentState!.bumpByMicroTickDelta();
      await tester.pump(const Duration(milliseconds: 50));

      expect(ringPainter(tester).progress, closeTo(100 / 8000, 0.001));

      await unmountGoalRingAndAssertNoLateTimers(tester);
    });

    testWidgets('dispose cancels foreground catch-up timer before it fires', (
      tester,
    ) async {
      final harnessKey = GlobalKey<_ForegroundCatchUpHarnessState>();

      await tester.pumpWidget(
        wrapWithAstraTheme(
          Center(
            child: SizedBox(
              width: 400,
              child: _ForegroundCatchUpHarness(key: harnessKey),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      harnessKey.currentState!.triggerForegroundCatchUp();
      await tester.pump(const Duration(milliseconds: 500));

      expect(harnessKey.currentState!.catchUpHandled, isFalse);

      await unmountGoalRingAndAssertNoLateTimers(tester);
    });

    testWidgets('ring diameter clamps to kGoalRingMaxDiameter', (
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
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.painter is GoalRingPainter,
          ),
        ),
      );
      expect(ringSize.width, kGoalRingMaxDiameter);
      expect(ringSize.height, kGoalRingMaxDiameter);
    });
  });

  group('paintGoalRingTrackInnerShadow', () {
    late GoalRingInsetShadowCache cache;
    const size = Size.square(280);
    const devicePixelRatio = 1.0;

    setUp(() => cache = GoalRingInsetShadowCache());
    tearDown(() => cache.dispose());

    Path _annulusFor(Size canvasSize) {
      final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
      const strokeWidth = kGoalRingStrokeWidth;
      final radius = (canvasSize.width - strokeWidth) / 2;
      final innerRadius = radius - strokeWidth / 2;
      final outerRadius = radius + strokeWidth / 2;
      return Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: center, radius: outerRadius))
        ..addOval(Rect.fromCircle(center: center, radius: innerRadius));
    }

    test('paints without error on first call', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final center = Offset(size.width / 2, size.height / 2);
      const strokeWidth = kGoalRingStrokeWidth;
      final radius = (size.width - strokeWidth) / 2;
      final innerRadius = radius - strokeWidth / 2;
      final outerRadius = radius + strokeWidth / 2;
      final annulus = _annulusFor(size);

      paintGoalRingTrackInnerShadow(
        canvas,
        annulus,
        center,
        innerRadius,
        outerRadius,
        size,
        devicePixelRatio,
        cache,
      );

      expect(cache.isValid(size, devicePixelRatio), isTrue);
    });

    test('cache hit on second call with same size', () {
      final center = Offset(size.width / 2, size.height / 2);
      const strokeWidth = kGoalRingStrokeWidth;
      final radius = (size.width - strokeWidth) / 2;
      final innerRadius = radius - strokeWidth / 2;
      final outerRadius = radius + strokeWidth / 2;
      final annulus = _annulusFor(size);

      final recorder = PictureRecorder();
      paintGoalRingTrackInnerShadow(
        Canvas(recorder),
        annulus,
        center,
        innerRadius,
        outerRadius,
        size,
        devicePixelRatio,
        cache,
      );
      expect(cache.isValid(size, devicePixelRatio), isTrue);

      final recorder2 = PictureRecorder();
      paintGoalRingTrackInnerShadow(
        Canvas(recorder2),
        annulus,
        center,
        innerRadius,
        outerRadius,
        size,
        devicePixelRatio,
        cache,
      );
      expect(cache.isValid(size, devicePixelRatio), isTrue);
    });

    test('cache invalidates on size change', () {
      final center = Offset(size.width / 2, size.height / 2);
      const strokeWidth = kGoalRingStrokeWidth;
      final radius = (size.width - strokeWidth) / 2;
      final innerRadius = radius - strokeWidth / 2;
      final outerRadius = radius + strokeWidth / 2;
      final annulus = _annulusFor(size);

      paintGoalRingTrackInnerShadow(
        Canvas(PictureRecorder()),
        annulus,
        center,
        innerRadius,
        outerRadius,
        size,
        devicePixelRatio,
        cache,
      );
      expect(cache.isValid(size, devicePixelRatio), isTrue);

      const newSize = Size.square(320);
      expect(cache.isValid(newSize, devicePixelRatio), isFalse);
    });
  });
}
