import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/astra_horizontal_ruler.dart';
import 'package:astra_app/presentation/widgets/astra_inset_shadow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Finder readoutText(String value) => find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.style?.fontSize == 52 &&
            widget.data == value,
      );

  Future<void> pumpRuler(
    WidgetTester tester, {
    double value = 70,
    ValueChanged<double>? onChanged,
    double min = kMinWeightKg,
    double max = kMaxWeightKg,
    double step = 1,
    String unitLabel = 'kg',
    double majorTickEvery = 10,
    RulerValueFormatter? valueFormatter,
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
                majorTickEvery: majorTickEvery,
                valueFormatter: valueFormatter,
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

      expect(readoutText('70'), findsOneWidget);
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
      expect(readoutText(changed!.round().toString()), findsOneWidget);
    });

    testWidgets('cannot scroll past min/max (clamp)', (tester) async {
      const min = kMinWeightKg;
      const max = kMinWeightKg + 4;

      await pumpRuler(
        tester,
        value: min,
        min: min,
        max: max,
      );

      await tester.drag(find.byType(ListView), const Offset(200, 0));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(readoutText(min.round().toString()), findsOneWidget);

      await pumpRuler(
        tester,
        value: max,
        min: min,
        max: max,
      );

      await tester.drag(find.byType(ListView), const Offset(-200, 0));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(readoutText(max.round().toString()), findsOneWidget);
    });

    testWidgets('semantics label includes value and unit', (tester) async {
      await pumpRuler(tester, value: 70, unitLabel: 'kg');

      final semantics = tester.getSemantics(find.byType(AstraHorizontalRuler));
      expect(semantics.label, '70 kg');
    });

    testWidgets('semantics increase steps value and calls onChanged',
        (WidgetTester tester) async {
      double? changed;
      await pumpRuler(
        tester,
        value: 70,
        min: 60,
        max: 80,
        onChanged: (v) => changed = v,
      );

      final handle = tester.ensureSemantics();
      tester.semantics.increase(find.semantics.byLabel('70 kg'));
      await tester.pump();
      await tester.pumpAndSettle();
      handle.dispose();

      expect(changed, 71);
      expect(readoutText('71'), findsOneWidget);
    });

    testWidgets('programmatic value update does not fire spurious onChanged',
        (tester) async {
      var onChangedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: AstraHorizontalRuler(
                  value: 70,
                  onChanged: (_) => onChangedCount++,
                  min: 60,
                  max: 80,
                  step: 1,
                  unitLabel: 'kg',
                  enableHaptics: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: AstraHorizontalRuler(
                  value: 75,
                  onChanged: (_) => onChangedCount++,
                  min: 60,
                  max: 80,
                  step: 1,
                  unitLabel: 'kg',
                  enableHaptics: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(readoutText('75'), findsOneWidget);
      expect(onChangedCount, 0);
    });

    testWidgets('valueFormatter customizes readout', (tester) async {
      await pumpRuler(
        tester,
        value: 70.5,
        min: 70,
        max: 72,
        step: 0.5,
        valueFormatter: (v) => '${v.toStringAsFixed(1)} lb',
      );

      expect(readoutText('70.5 lb'), findsOneWidget);
    });

    testWidgets('major tick labels render at majorTickEvery intervals',
        (tester) async {
      await pumpRuler(
        tester,
        value: 70,
        min: 50,
        max: 90,
        majorTickEvery: 10,
      );

      expect(find.text('60'), findsWidgets);
      expect(find.text('80'), findsWidgets);
    });

    testWidgets('uses elevated inset shadow card chrome', (tester) async {
      await pumpRuler(tester);

      expect(find.byType(AstraInsetShadowSurface), findsOneWidget);
    });
  });
}
