import 'package:astra_app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AstraApp shows NavigationBar and switches tab placeholders', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AstraApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('My Data'), findsOneWidget);

    expect(
      find.text('Step tracking and your goal ring will appear here.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('Your 7-day and 30-day charts will appear here.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('Data footprint, export, and settings will appear here.'),
      findsOneWidget,
    );
  });
}
