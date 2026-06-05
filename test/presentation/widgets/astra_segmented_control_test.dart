import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/astra_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const options = [
    AstraSegmentOption(value: 'a', label: 'Alpha'),
    AstraSegmentOption(value: 'b', label: 'Beta'),
    AstraSegmentOption(value: 'c', label: 'Gamma'),
  ];

  Future<void> pumpControl(
    WidgetTester tester, {
    String selected = 'a',
    ValueChanged<String>? onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstraLightTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: AstraSegmentedControl<String>(
                options: options,
                selected: selected,
                onChanged: onChanged ?? (_) {},
                semanticsHint: 'Test hint',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder thumbFinder() => find.byType(AnimatedPositioned);

  group('AstraSegmentedControl', () {
    testWidgets('tap fires onChanged with segment value', (tester) async {
      String? changed;
      await pumpControl(tester, onChanged: (value) => changed = value);

      await tester.tap(find.text('Beta'));
      await tester.pump();

      expect(changed, 'b');
    });

    testWidgets('thumb slides when selection changes', (tester) async {
      await pumpControl(tester, selected: 'a');
      final initial = tester.getTopLeft(thumbFinder());

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: AstraSegmentedControl<String>(
                  options: options,
                  selected: 'c',
                  onChanged: (_) {},
                  semanticsHint: 'Test hint',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(AstraSegmentedControl.thumbDuration);

      final moved = tester.getTopLeft(thumbFinder());
      expect(moved.dx, greaterThan(initial.dx));
    });
  });
}
