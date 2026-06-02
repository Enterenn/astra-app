import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/widgets/period_toggle.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PeriodToggle', () {
    Future<void> pumpToggle(
      WidgetTester tester, {
      HistoryPeriod selected = HistoryPeriod.days7,
      ValueChanged<HistoryPeriod>? onChanged,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: PeriodToggle(
              selected: selected,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('tap 30 days segment fires callback', (tester) async {
      HistoryPeriod? changed;
      await pumpToggle(
        tester,
        onChanged: (period) => changed = period,
      );

      await tester.tap(find.text('30 days'));
      await tester.pump();

      expect(changed, HistoryPeriod.days30);
    });

    testWidgets('semantics labels are present on each segment', (tester) async {
      await pumpToggle(tester, selected: HistoryPeriod.days7);

      final sevenDays = tester.getSemantics(find.text('7 days'));
      expect(sevenDays.label, contains('7 days'));
      expect(sevenDays.hint, 'Chart range');
      expect(sevenDays.flagsCollection.isSelected, Tristate.isTrue);

      final thirtyDays = tester.getSemantics(find.text('30 days'));
      expect(thirtyDays.label, contains('30 days'));
      expect(thirtyDays.hint, 'Chart range');
      expect(thirtyDays.flagsCollection.isSelected, Tristate.isFalse);
    });
  });
}
