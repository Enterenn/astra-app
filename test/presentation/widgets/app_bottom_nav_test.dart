import 'package:figma_squircle/figma_squircle.dart';
import 'package:astra_app/core/constants/astra_spacing.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

void main() {
  testWidgets('AppBottomNav shows four uppercase labels and active squircle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstraLightTheme(),
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            selectedIndex: 1,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('TRENDS'), findsOneWidget);
    expect(find.text('DATA'), findsOneWidget);
    expect(find.text('PROFIL'), findsOneWidget);

    expect(find.byIcon(PhosphorIconsFill.chartBar), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.sneakerMove), findsOneWidget);

    final squircleFinder = find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is ShapeDecoration &&
            (w.decoration as ShapeDecoration).shape is SmoothRectangleBorder,
      ),
    );
    expect(squircleFinder, findsOneWidget);
    final squircle = tester.widget<DecoratedBox>(squircleFinder);
    final border =
        (squircle.decoration as ShapeDecoration).shape
            as SmoothRectangleBorder;
    final radius = border.borderRadius;
    expect(radius.topLeft.cornerRadius, AstraSpacing.kBottomNavSquircleRadius);
    expect(
      radius.topLeft.cornerSmoothing,
      AstraSpacing.kBottomNavSquircleSmoothing,
    );

  });
}
