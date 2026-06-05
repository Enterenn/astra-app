import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'dart:ui' show Tristate;
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/accent_preset_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccentPresetSelector', () {
    Future<void> pumpSelector(
      WidgetTester tester, {
      AstraAccentPreset selected = AstraAccentPreset.orange,
      ValueChanged<AstraAccentPreset>? onSelected,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(preset: selected),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: AccentPresetSelector(
                selected: selected,
                onSelected: onSelected ?? (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders six preset chips', (tester) async {
      await pumpSelector(tester);

      expect(find.byType(AccentPresetSelector), findsOneWidget);
      expect(
        find.bySemanticsLabel('Accent color, Orange'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Accent color, Pink'), findsOneWidget);
    });

    testWidgets('selection callback fires when tapping another preset', (
      tester,
    ) async {
      AstraAccentPreset? changed;
      await pumpSelector(
        tester,
        onSelected: (preset) => changed = preset,
      );

      await tester.tap(find.bySemanticsLabel('Accent color, Blue'));
      await tester.pump();

      expect(changed, AstraAccentPreset.blue);
    });

    testWidgets('does not overflow at narrow card width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 264,
                child: AccentPresetSelector(
                  selected: AstraAccentPreset.orange,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('selected chip has selected semantics state', (tester) async {
      await pumpSelector(tester, selected: AstraAccentPreset.green);

      final green = tester.getSemantics(
        find.bySemanticsLabel('Accent color, Green'),
      );
      expect(green.flagsCollection.isSelected, Tristate.isTrue);

      final orange = tester.getSemantics(
        find.bySemanticsLabel('Accent color, Orange'),
      );
      expect(orange.flagsCollection.isSelected, Tristate.isFalse);
    });
  });
}
