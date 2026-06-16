import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/data/models/chart_month_aggregate.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/widgets/trends_monthly_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrendsMonthlyBarChart', () {
    Future<void> pumpChart(
      WidgetTester tester, {
      required List<ChartMonthAggregate> points,
      required HistoryStatus status,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: SizedBox(
              height: 240,
              width: 400,
              child: TrendsMonthlyBarChart(
                points: points,
                status: status,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('loading skeleton renders twelve bars', (tester) async {
      await pumpChart(
        tester,
        points: const [],
        status: HistoryStatus.loading,
      );

      expect(find.byType(Container), findsWidgets);
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(TrendsMonthlyBarChart),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).borderRadius ==
                    const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
      );
      expect(containers.length, 12);
    });

    testWidgets('ready chart shows month labels', (tester) async {
      final points = List.generate(
        12,
        (i) => ChartMonthAggregate(
          monthStart: DateTime.utc(2025, 7 + i, 1),
          averageDailySteps: 1000 + i * 100,
          totalSteps: 30_000,
          dayCount: 30,
        ),
      );

      await pumpChart(
        tester,
        points: points,
        status: HistoryStatus.ready,
      );

      expect(find.text('Jul'), findsOneWidget);
      expect(find.text('Jun'), findsOneWidget);
    });

    testWidgets('empty state shows shared history copy', (tester) async {
      await pumpChart(
        tester,
        points: const [],
        status: HistoryStatus.empty,
      );

      expect(
        find.textContaining('No history yet'),
        findsOneWidget,
      );
    });

    test('formatPeriodRange returns oldest–newest month year caption', () {
      final points = [
        ChartMonthAggregate(
          monthStart: DateTime.utc(2025, 7, 1),
          averageDailySteps: 1000,
          totalSteps: 31_000,
          dayCount: 31,
        ),
        ChartMonthAggregate(
          monthStart: DateTime.utc(2026, 6, 1),
          averageDailySteps: 1200,
          totalSteps: 18_000,
          dayCount: 15,
        ),
      ];

      expect(
        TrendsMonthlyBarChart.formatPeriodRange(points),
        'Jul 2025 – Jun 2026',
      );
    });

    test('formatPeriodRange returns null when points are empty', () {
      expect(TrendsMonthlyBarChart.formatPeriodRange(const []), isNull);
    });
  });
}
