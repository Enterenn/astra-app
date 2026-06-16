import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/widgets/trends_peak_day_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required TrendsPeakDay peakDay,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstraLightTheme(),
        home: Scaffold(
          body: TrendsPeakDayCard(peakDay: peakDay),
        ),
      ),
    );
  }

  group('TrendsPeakDayCard', () {
    testWidgets('renders date label, steps, and caption', (tester) async {
      await pumpCard(
        tester,
        peakDay: TrendsPeakDay(
          localDay: DateTime.utc(2026, 6, 4),
          totalSteps: 8500,
          dateLabel: 'WED 4',
        ),
      );

      expect(find.text('WED 4'), findsOneWidget);
      expect(find.text('8500'), findsOneWidget);
      expect(find.text('steps'), findsOneWidget);
      expect(find.text('peak day in this period'), findsOneWidget);
    });

    testWidgets('renders trophy icon', (tester) async {
      await pumpCard(
        tester,
        peakDay: TrendsPeakDay(
          localDay: DateTime.utc(2026, 6, 4),
          totalSteps: 5000,
          dateLabel: 'WED 4',
        ),
      );

      expect(find.byIcon(PhosphorIconsRegular.trophy), findsOneWidget);
    });

    testWidgets('exposes semantics label for screen readers', (tester) async {
      await pumpCard(
        tester,
        peakDay: TrendsPeakDay(
          localDay: DateTime.utc(2026, 6, 4),
          totalSteps: 8500,
          dateLabel: 'WED 4',
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Peak day WED 4 with 8500 steps in this period',
        ),
        findsOneWidget,
      );
    });
  });
}
