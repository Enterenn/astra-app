import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/cubits/history_state.dart';
import 'package:astra_app/presentation/widgets/trend_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrendChip', () {
    Future<void> pumpChip(
      WidgetTester tester, {
      required TrendSnapshot trend,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: TrendChip(trend: trend),
          ),
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

    testWidgets('hidden direction renders nothing', (tester) async {
      await pumpChip(
        tester,
        trend: const TrendSnapshot(
          direction: TrendDirection.hidden,
          label: '',
        ),
      );

      expect(find.byType(TrendChip), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(Text), findsNothing);
    });
  });
}
