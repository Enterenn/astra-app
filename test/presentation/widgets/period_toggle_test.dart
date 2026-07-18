import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/widgets/period_toggle.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

void main() {
  group('PeriodToggle', () {
    Future<void> pumpToggle(
      WidgetTester tester, {
      HistoryPeriod selected = HistoryPeriod.days7,
      ValueChanged<HistoryPeriod>? onChanged,
      bool enabled = true,
    }) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: PeriodToggle(
              selected: selected,
              onChanged: onChanged ?? (_) {},
              enabled: enabled,
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

    testWidgets('tap 12 months segment fires callback', (tester) async {
      HistoryPeriod? changed;
      await pumpToggle(
        tester,
        onChanged: (period) => changed = period,
      );

      await tester.tap(find.text('12 months'));
      await tester.pump();

      expect(changed, HistoryPeriod.months12);
    });

    testWidgets('disabled: tap does not fire onChanged', (tester) async {
      var tapCount = 0;
      await pumpToggle(
        tester,
        enabled: false,
        onChanged: (_) => tapCount++,
      );

      await tester.tap(find.text('30 days'));
      await tester.pump();

      expect(tapCount, 0);
    });

    testWidgets('disabled: segments expose isEnabled=false in semantics', (tester) async {
      await pumpToggle(tester, enabled: false);

      for (final label in ['7 days', '30 days', '12 months']) {
        final node = tester.getSemantics(find.text(label));
        expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      }
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

      final twelveMonths = tester.getSemantics(find.text('12 months'));
      expect(twelveMonths.label, contains('12 months'));
      expect(twelveMonths.hint, 'Chart range');
      expect(twelveMonths.flagsCollection.isSelected, Tristate.isFalse);
    });
  });
}
