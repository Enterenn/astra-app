import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/activity_stats_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

void main() {
  Future<void> pumpRow(
    WidgetTester tester, {
    required ThemeData theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: ActivityStatsRow()),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows mock values without dividers in light theme', (tester) async {
    await pumpRow(tester, theme: buildAstraLightTheme());

    expect(find.text('420'), findsOneWidget);
    expect(find.text('Kcal'), findsOneWidget);
    expect(find.text('4.2'), findsOneWidget);
    expect(find.text('Km'), findsOneWidget);
    expect(find.text('00:37:20'), findsOneWidget);
    expect(find.text('HH:MM:SS'), findsNothing);
    expect(find.text('—'), findsNothing);
    expect(find.byType(VerticalDivider), findsNothing);
    expect(find.byIcon(PhosphorIcons.fire), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.mapPin), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.clock), findsOneWidget);
  });

  testWidgets('renders in dark theme', (tester) async {
    await pumpRow(tester, theme: buildAstraDarkTheme());

    expect(find.byType(ActivityStatsRow), findsOneWidget);
    expect(find.text('00:37:20'), findsOneWidget);
  });
}
