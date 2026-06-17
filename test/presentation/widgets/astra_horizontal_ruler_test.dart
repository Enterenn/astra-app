import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/astra_horizontal_ruler.dart';
import 'package:astra_app/presentation/widgets/astra_inset_shadow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpRuler(
    WidgetTester tester, {
    double value = 70,
    ValueChanged<double>? onChanged,
    double min = kMinWeightKg,
    double max = kMaxWeightKg,
    double step = 1,
    String unitLabel = 'kg',
    bool enableHaptics = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstraLightTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: AstraHorizontalRuler(
                value: value,
                onChanged: onChanged ?? (_) {},
                min: min,
                max: max,
                step: step,
                unitLabel: unitLabel,
                enableHaptics: enableHaptics,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('AstraHorizontalRuler', () {
    testWidgets('initial value renders in readout', (tester) async {
      await pumpRuler(tester, value: 70);

      final readout = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.style?.fontSize == 52 &&
            widget.data == '70',
      );
      expect(readout, findsOneWidget);
    });

    testWidgets('drag scroll updates snapped value and calls onChanged',
        (tester) async {
      double? changed;
      await pumpRuler(
        tester,
        value: 70,
        onChanged: (v) => changed = v,
      );

      await tester.drag(find.byType(ListView), const Offset(-100, 0));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(changed, isNotNull);
      expect(changed, isNot(70));
      expect(changed! >= kMinWeightKg && changed! <= kMaxWeightKg, isTrue);
      expect(changed!.roundToDouble(), changed);
    });

    testWidgets('cannot scroll past min/max (clamp)', (tester) async {
      double? changed;
      await pumpRuler(
        tester,
        value: kMinWeightKg,
        onChanged: (v) => changed = v,
        min: kMinWeightKg,
        max: kMinWeightKg + 4,
      );

      await tester.drag(find.byType(ListView), const Offset(200, 0));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(changed ?? kMinWeightKg, greaterThanOrEqualTo(kMinWeightKg));

      changed = null;
      await pumpRuler(
        tester,
        value: kMaxWeightKg,
        onChanged: (v) => changed = v,
        min: kMaxWeightKg - 4,
        max: kMaxWeightKg,
      );

      await tester.drag(find.byType(ListView), const Offset(-200, 0));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(changed ?? kMaxWeightKg, lessThanOrEqualTo(kMaxWeightKg));
    });

    testWidgets('semantics label includes value and unit', (tester) async {
      await pumpRuler(tester, value: 70, unitLabel: 'kg');

      final semantics = tester.getSemantics(find.byType(AstraHorizontalRuler));
      expect(semantics.label, '70 kg');
    });

    testWidgets('uses elevated inset shadow card chrome', (tester) async {
      await pumpRuler(tester);

      expect(find.byType(AstraInsetShadowSurface), findsOneWidget);
    });
  });
}
