import 'package:astra_app/presentation/widgets/astra_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPressable(
    WidgetTester tester, {
    bool enabled = true,
    double pressedScale = AstraPressable.defaultPressedScale,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AstraPressable(
              enabled: enabled,
              pressedScale: pressedScale,
              child: GestureDetector(
                onTap: () {},
                child: const SizedBox(
                  width: 120,
                  height: 48,
                  child: Center(child: Text('Tap')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  double readScale(WidgetTester tester) {
    final transition = tester.widget<ScaleTransition>(
      find.descendant(
        of: find.byType(AstraPressable),
        matching: find.byType(ScaleTransition),
      ),
    );
    return transition.scale.value;
  }

  group('AstraPressable', () {
    testWidgets('scales to 94% while pressed and bounces 103% then 100%', (
      tester,
    ) async {
      await pumpPressable(tester);

      expect(readScale(tester), closeTo(1, 0.001));

      final gesture = await tester.createGesture();
      await gesture.down(tester.getCenter(find.text('Tap')));
      await tester.pump();
      await tester.pump(AstraPressable.pressDuration);
      expect(readScale(tester), closeTo(0.94, 0.02));

      await gesture.up();
      await tester.pump();
      await tester.pump(AstraPressable.releaseOvershootDuration);
      expect(readScale(tester), closeTo(1.03, 0.02));

      await tester.pumpAndSettle();
      expect(readScale(tester), closeTo(1, 0.02));
    });

    testWidgets('stays at full scale when disabled', (tester) async {
      await pumpPressable(tester, enabled: false);

      final gesture = await tester.createGesture();
      await gesture.down(tester.getCenter(find.text('Tap')));
      await tester.pump(AstraPressable.pressDuration);
      expect(readScale(tester), closeTo(1, 0.001));

      await gesture.up();
      await tester.pump(AstraPressable.releaseDuration);
      expect(readScale(tester), closeTo(1, 0.001));
    });
  });
}
