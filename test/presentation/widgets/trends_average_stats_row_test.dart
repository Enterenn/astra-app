import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/widgets/trends_average_stats_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

void main() {
  Future<void> pumpRow(
    WidgetTester tester, {
    required TrendsPeriodAverages averages,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstraLightTheme(),
        home: Scaffold(
          body: TrendsAverageStatsRow(averages: averages),
        ),
      ),
    );
  }

  group('TrendsAverageStatsRow', () {
    testWidgets('renders kcal and steps values with units', (tester) async {
      await pumpRow(
        tester,
        averages: const TrendsPeriodAverages(
          averageKcal: 167,
          averageSteps: 3532,
        ),
      );

      expect(find.text('167'), findsOneWidget);
      expect(find.text('kcal'), findsOneWidget);
      expect(find.text('3532'), findsOneWidget);
      expect(find.text('steps'), findsOneWidget);
    });

    testWidgets('renders captions from mockup copy', (tester) async {
      await pumpRow(
        tester,
        averages: const TrendsPeriodAverages(
          averageKcal: 100,
          averageSteps: 2000,
        ),
      );

      expect(
        find.text('average calories burned per day'),
        findsOneWidget,
      );
      expect(find.text('average steps taken per day'), findsOneWidget);
    });

    testWidgets('renders flame and footprints icons', (tester) async {
      await pumpRow(
        tester,
        averages: const TrendsPeriodAverages(
          averageKcal: 50,
          averageSteps: 1000,
        ),
      );

      expect(find.byIcon(PhosphorIconsRegular.fire), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.footprints), findsOneWidget);
    });

    testWidgets('exposes semantics labels for screen readers', (tester) async {
      await pumpRow(
        tester,
        averages: const TrendsPeriodAverages(
          averageKcal: 167,
          averageSteps: 3532,
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Average 167 kilocalories burned per day',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Average 3532 steps taken per day',
        ),
        findsOneWidget,
      );
    });
  });
}
