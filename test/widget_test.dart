import 'package:astra_app/app.dart';
import 'package:astra_app/core/constants/astra_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AstraApp shows theme preview with 48dp primary button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AstraApp());

    expect(find.text('Hello World!'), findsNothing);
    expect(find.text('ASTRA Theme Preview'), findsOneWidget);
    expect(find.text('Primary action'), findsOneWidget);

    final touchTarget = tester.widget<SizedBox>(
      find.ancestor(
        of: find.text('Primary action'),
        matching: find.byType(SizedBox),
      ),
    );
    expect(touchTarget.height, AstraSpacing.kMinTouchTarget);
  });
}
