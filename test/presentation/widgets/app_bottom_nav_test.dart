import 'package:figma_squircle/figma_squircle.dart';
import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:astra_app/core/constants/astra_spacing.dart';
import 'package:astra_app/core/constants/astra_typography.dart';
import 'package:astra_app/presentation/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../helpers/astra_theme_test_helper.dart';

void main() {
  testWidgets('AppBottomNav shows four uppercase labels and active squircle', (
    WidgetTester tester,
  ) async {
    const preset = AstraAccentPreset.blue;
    final colors = AstraColors.light(preset: preset);

    await tester.pumpWidget(
      wrapWithAstraTheme(
        AppBottomNav(
          selectedIndex: 1,
          onSelected: (_) {},
        ),
        preset: preset,
      ),
    );

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('TRENDS'), findsOneWidget);
    expect(find.text('DATA'), findsOneWidget);
    expect(find.text('PROFILE'), findsOneWidget);

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

    final activeIcon = tester.widget<Icon>(
      find.byIcon(PhosphorIconsFill.chartBar),
    );
    expect(activeIcon.size, 20);
    expect(activeIcon.color, colors.accentPrimary);

    final inactiveIcon = tester.widget<Icon>(
      find.byIcon(PhosphorIconsRegular.sneakerMove),
    );
    expect(inactiveIcon.size, 20);
    expect(inactiveIcon.color, colors.accentSecondary);

    final trendsLabel = tester.widget<Text>(find.text('TRENDS'));
    expect(trendsLabel.style?.fontFamily, AstraTypography.figtree);
    expect(trendsLabel.style?.fontSize, 10);
    expect(trendsLabel.style?.fontWeight, FontWeight.w600);
  });
}
