import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/astra_inset_shadow.dart';
import 'package:astra_app/presentation/widgets/astra_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

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
      TestMaterialApp(
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
        TestMaterialApp(
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

    testWidgets('uses inset shadow surface for gray track', (tester) async {
      await pumpControl(tester);

      expect(find.byType(AstraInsetShadowSurface), findsOneWidget);
    });

    testWidgets('InkWell has non-transparent keyboard focusColor', (tester) async {
      await pumpControl(tester);

      final inkWell = tester.widget<InkWell>(find.byType(InkWell).first);
      expect(inkWell.focusColor, isNotNull);
      expect(inkWell.focusColor, isNot(Colors.transparent));
      expect(inkWell.focusColor!.a, greaterThan(0));
    });

    testWidgets('focusColor uses theme borderDefault in light and dark', (tester) async {
      for (final theme in [buildAstraLightTheme(), buildAstraDarkTheme()]) {
        await tester.pumpWidget(
          TestMaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: AstraSegmentedControl<String>(
                    options: options,
                    selected: 'a',
                    onChanged: (_) {},
                    semanticsHint: 'Test hint',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final inkWell = tester.widget<InkWell>(find.byType(InkWell).first);
        expect(inkWell.focusColor, isNot(Colors.transparent));
        expect(inkWell.focusColor!.a, closeTo(0.35, 0.01));
      }
    });

    testWidgets('tab moves focus to a segment InkWell', (tester) async {
      await pumpControl(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final focusContext = FocusManager.instance.primaryFocus?.context;
      expect(focusContext, isNotNull);
      expect(focusContext!.findAncestorWidgetOfExactType<InkWell>(), isNotNull);
    });

    testWidgets('tab can focus selected segment when fireOnReselect is true',
        (tester) async {
      await pumpControl(tester, selected: 'a');

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final focusedInkWell =
          FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<InkWell>();
      expect(focusedInkWell, isNotNull);
      expect(focusedInkWell!.focusColor, isNot(Colors.transparent));
    });

    testWidgets('compact track segments have non-transparent focusColor',
        (tester) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: Center(
              child: AstraSegmentedControl<String>(
                options: options,
                selected: 'a',
                onChanged: (_) {},
                semanticsHint: 'Test hint',
                segmentHorizontalPadding: 12,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      for (final inkWell in tester.widgetList<InkWell>(find.byType(InkWell))) {
        expect(inkWell.focusColor, isNotNull);
        expect(inkWell.focusColor, isNot(Colors.transparent));
      }
    });
  });
}
