import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/cubits/theme_state.dart';
import 'package:astra_app/presentation/widgets/theme_selector.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThemeSelector', () {
    Future<void> pumpSelector(
      WidgetTester tester, {
      AstraThemePreference selected = AstraThemePreference.system,
      ValueChanged<AstraThemePreference>? onChanged,
      bool enabled = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: ThemeSelector(
              selected: selected,
              enabled: enabled,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders System, Light, and Dark segments', (tester) async {
      await pumpSelector(tester);

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('tap Light segment fires callback', (tester) async {
      AstraThemePreference? changed;
      await pumpSelector(
        tester,
        onChanged: (preference) => changed = preference,
      );

      await tester.tap(find.text('Light'));
      await tester.pump();

      expect(changed, AstraThemePreference.light);
    });

    testWidgets('semantics labels and selected state per segment', (tester) async {
      await pumpSelector(tester, selected: AstraThemePreference.light);

      final system = tester.getSemantics(find.text('System'));
      expect(system.label, contains('System appearance'));
      expect(system.hint, 'App theme');
      expect(system.flagsCollection.isSelected, Tristate.isFalse);

      final light = tester.getSemantics(find.text('Light'));
      expect(light.label, contains('Light appearance'));
      expect(light.hint, 'App theme');
      expect(light.flagsCollection.isSelected, Tristate.isTrue);

      final dark = tester.getSemantics(find.text('Dark'));
      expect(dark.label, contains('Dark appearance'));
      expect(dark.hint, 'App theme');
      expect(dark.flagsCollection.isSelected, Tristate.isFalse);
    });

    testWidgets('does not fire onChanged when disabled', (tester) async {
      var tapCount = 0;
      await pumpSelector(
        tester,
        enabled: false,
        onChanged: (_) => tapCount++,
      );

      await tester.tap(find.text('Dark'));
      await tester.pump();

      expect(tapCount, 0);
    });
  });
}
