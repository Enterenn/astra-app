import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/widgets/trend_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/astra_theme_test_helper.dart';

void main() {
  group('TrendChip', () {
    Future<void> pumpChip(
      WidgetTester tester, {
      required TrendSnapshot trend,
    }) async {
      await tester.pumpWidget(
        wrapWithAstraTheme(
          TrendChip(trend: trend),
          preset: AstraAccentPreset.magenta,
        ),
      );
      await tester.pump();
    }

    testWidgets('renders up copy and positive color', (tester) async {
      await pumpChip(
        tester,
        trend: const TrendSnapshot(
          direction: TrendDirection.up,
          percent: 12,
          label: 'Up 12% from last week',
        ),
      );

      expect(find.text('Up 12% from last week'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('up and down trends use distinct preset-tinted colors', (
      tester,
    ) async {
      const preset = AstraAccentPreset.magenta;
      final colors = AstraColors.light(preset: preset);

      await pumpChip(
        tester,
        trend: const TrendSnapshot(
          direction: TrendDirection.up,
          percent: 5,
          label: 'Up 5%',
        ),
      );
      final upColor = tester.widget<Icon>(find.byIcon(Icons.arrow_upward)).color;

      await pumpChip(
        tester,
        trend: const TrendSnapshot(
          direction: TrendDirection.down,
          percent: 3,
          label: 'Down 3%',
        ),
      );
      final downColor =
          tester.widget<Icon>(find.byIcon(Icons.arrow_downward)).color;

      expect(upColor, colors.dataPositive);
      expect(downColor, colors.dataNegative);
      expect(upColor, isNot(equals(downColor)));
      expect(downColor!.a, lessThan(upColor!.a));
    });

    testWidgets('renders down copy and negative icon', (tester) async {
      await pumpChip(
        tester,
        trend: const TrendSnapshot(
          direction: TrendDirection.down,
          percent: 8,
          label: 'Down 8% from last week',
        ),
      );

      expect(find.text('Down 8% from last week'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('renders flat copy', (tester) async {
      await pumpChip(
        tester,
        trend: const TrendSnapshot(
          direction: TrendDirection.flat,
          percent: 0,
          label: 'Same as last week',
        ),
      );

      expect(find.text('Same as last week'), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

  });
}
