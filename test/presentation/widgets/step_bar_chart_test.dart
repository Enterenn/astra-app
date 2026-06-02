import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/data/models/chart_day_aggregate.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/widgets/step_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StepBarChart', () {
    Future<void> pumpChart(
      WidgetTester tester, {
      required HistoryStatus status,
      List<ChartDayAggregate> points = const [],
      int dailyGoal = 8000,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: SizedBox(
              height: 240,
              child: StepBarChart(
                points: points,
                dailyGoal: dailyGoal,
                status: status,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('empty state shows exact copy', (tester) async {
      await pumpChart(tester, status: HistoryStatus.empty);

      expect(find.text(StepBarChart.emptyCopy), findsOneWidget);
    });

    testWidgets('loading state shows seven skeleton bars', (tester) async {
      await pumpChart(tester, status: HistoryStatus.loading);

      expect(find.byType(Container), findsWidgets);
      final containers = tester.widgetList<Container>(find.byType(Container));
      final skeletonBars = containers.where((container) {
        final decoration = container.decoration;
        if (decoration is! BoxDecoration) {
          return false;
        }
        final radius = decoration.borderRadius;
        return radius is BorderRadius &&
            radius.topLeft == const Radius.circular(4);
      });
      expect(skeletonBars.length, 7);
    });

    testWidgets('semantics label is present', (tester) async {
      await pumpChart(tester, status: HistoryStatus.empty);

      final semantics = tester.getSemantics(find.byType(StepBarChart));
      expect(semantics.label, contains('Step history bar chart'));
    });

    testWidgets('ready state builds without throw', (tester) async {
      final points = [
        for (var i = 0; i < 7; i++)
          ChartDayAggregate(
            localDay: DateTime.utc(2026, 5, 26 + i),
            totalSteps: 1000 + i * 100,
          ),
      ];

      await pumpChart(
        tester,
        status: HistoryStatus.ready,
        points: points,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(StepBarChart), findsOneWidget);
    });
  });
}
