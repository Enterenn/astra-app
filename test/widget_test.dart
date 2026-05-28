import 'package:astra_app/app.dart';
import 'package:astra_app/core/constants/astra_spacing.dart';
import 'package:astra_app/presentation/screens/theme_preview_screen.dart';
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

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    final padding = scrollView.padding as EdgeInsets;
    expect(padding.left, AstraSpacing.kScreenHorizontalPadding);
    expect(padding.right, AstraSpacing.kScreenHorizontalPadding);

    final touchTarget = tester.widget<SizedBox>(
      find.byKey(ThemePreviewScreen.primaryTouchTargetKey),
    );
    expect(touchTarget.height, AstraSpacing.kMinTouchTarget);
  });
}
