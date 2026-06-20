import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/animated_step_count.dart';
import 'package:astra_app/presentation/widgets/goal_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

void main() {
  group('AnimatedStepCount', () {
    const style = TextStyle(fontSize: 32, fontWeight: FontWeight.w900);

    Future<void> pumpCount(
      WidgetTester tester, {
      required int value,
      int? previousValue,
      double microTickProgress = 0,
      bool disableAnimations = false,
    }) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: Scaffold(
              body: Center(
                child: AnimatedStepCount(
                  value: value,
                  previousValue: previousValue,
                  microTickProgress: microTickProgress,
                  style: style,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders formatted step count via segment row', (tester) async {
      await pumpCount(tester, value: 10_847);
      expect(find.byType(AnimatedStepCount), findsOneWidget);
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('micro-tick renders digit cells when value changes', (
      tester,
    ) async {
      await pumpCount(
        tester,
        value: 1024,
        previousValue: 1021,
        microTickProgress: 1,
      );
      expect(find.byType(AnimatedStepCount), findsOneWidget);
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('static state uses same segment row layout as micro-tick', (
      tester,
    ) async {
      await pumpCount(tester, value: 3200);
      expect(find.byType(Row), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
    });
  });

  group('countUpDurationMs', () {
    test('clamps cold start duration between 600 and 1800ms', () {
      expect(countUpDurationMs(100), 600);
      expect(countUpDurationMs(554), 831);
      expect(countUpDurationMs(2000), 1800);
    });
  });

  group('tabReturnDurationMs', () {
    test('enforces 100ms minimum for small deltas', () {
      expect(tabReturnDurationMs(10), 100);
      expect(tabReturnDurationMs(63), 100);
    });
  });
}
