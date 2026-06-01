import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/screens/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tab switch with reduce motion completes without hanging', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstraLightTheme(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AppScaffold(),
        ),
      ),
    );

    expect(
      find.text('Step tracking and your goal ring will appear here.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pump();

    expect(
      find.text('Your 7-day and 30-day charts will appear here.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pump();

    expect(
      find.text('Data footprint, export, and settings will appear here.'),
      findsOneWidget,
    );
  });
}
