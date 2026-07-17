import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/chart/astra_bar_chart_core.dart';
import 'package:astra_app/presentation/widgets/chart/astra_bar_chart_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helper.dart';

void main() {
  group('AstraBarChartCore keyboard', () {
    Future<void> pumpCore(
      WidgetTester tester, {
      required List<double> values,
      int? selectedIndex,
      ValueChanged<int?>? onSelectedIndexChanged,
    }) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                height: 200,
                child: AstraBarChartCore(
                  values: values,
                  maxY: 100,
                  barWidth: 12,
                  yTicks: const [0, 50, 100],
                  colors: AstraColors.light(preset: AstraAccentPreset.blue),
                  selectedIndex: selectedIndex,
                  onSelectedIndexChanged: onSelectedIndexChanged ?? (_) {},
                  barColor: (_, __) => Colors.blue,
                  bottomLabelBuilder: (index) => '${index + 1}',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    AstraBarChartPainter chartPainter(WidgetTester tester) {
      return tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<AstraBarChartPainter>()
          .first;
    }

    Future<void> focusChart(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }

    testWidgets('tab moves focus to chart plot', (tester) async {
      await pumpCore(tester, values: const [40, 60, 80]);

      await focusChart(tester);

      final focusContext = FocusManager.instance.primaryFocus?.context;
      expect(focusContext, isNotNull);
      expect(
        focusContext!.findAncestorWidgetOfExactType<FocusableActionDetector>(),
        isNotNull,
      );
    });

    testWidgets('arrow keys move focused bar without selecting', (tester) async {
      await pumpCore(tester, values: const [40, 60, 80]);

      await focusChart(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(chartPainter(tester).focusedIndex, 1);
      expect(
        tester.widget<AstraBarChartCore>(find.byType(AstraBarChartCore)).selectedIndex,
        isNull,
      );
    });

    testWidgets('home and end jump focused bar', (tester) async {
      await pumpCore(tester, values: const [40, 60, 80]);

      await focusChart(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(chartPainter(tester).focusedIndex, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(chartPainter(tester).focusedIndex, 0);
    });

    testWidgets('enter toggles selection on focused bar', (tester) async {
      int? selected;
      await pumpCore(
        tester,
        values: const [40, 60, 80],
        onSelectedIndexChanged: (index) => selected = index,
      );

      await focusChart(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(selected, 1);
    });

    testWidgets('re-activate focused bar clears selection', (tester) async {
      int? selected;
      await pumpCore(
        tester,
        values: const [40, 60, 80],
        selectedIndex: 1,
        onSelectedIndexChanged: (index) => selected = index,
      );

      await focusChart(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(selected, isNull);
    });

    testWidgets('escape clears selection', (tester) async {
      int? selected = 1;
      await pumpCore(
        tester,
        values: const [40, 60, 80],
        selectedIndex: 1,
        onSelectedIndexChanged: (index) => selected = index,
      );

      await focusChart(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(selected, isNull);
    });
  });
}
