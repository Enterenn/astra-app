import 'package:astra_app/core/constants/astra_colors.dart';
import 'package:astra_app/core/constants/astra_spacing.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/screens/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppScaffold', () {
    testWidgets(
      'tab switch with reduce motion completes without hanging',
      (WidgetTester tester) async {
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
      },
    );

    testWidgets('placeholder layout survives large text scale', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(2.5),
            ),
            child: const AppScaffold(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('NavigationBar uses Astra navigation theme tokens', (
      WidgetTester tester,
    ) async {
      final colors = AstraColors.light();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: const AppScaffold(),
        ),
      );

      final navContext = tester.element(find.byType(NavigationBar));
      final navTheme = Theme.of(navContext).navigationBarTheme;

      expect(navTheme.height, AstraSpacing.kBottomTabBarHeight);
      expect(navTheme.backgroundColor, colors.bgElevated);
      expect(navTheme.indicatorColor, Colors.transparent);

      final selectedIconStyle = navTheme.iconTheme!.resolve({
        WidgetState.selected,
      });
      final unselectedIconStyle = navTheme.iconTheme!.resolve({});
      expect(selectedIconStyle?.color, colors.accentPrimary);
      expect(unselectedIconStyle?.color, colors.textMuted);

      final selectedLabelStyle = navTheme.labelTextStyle!.resolve({
        WidgetState.selected,
      });
      final unselectedLabelStyle = navTheme.labelTextStyle!.resolve({});
      expect(selectedLabelStyle?.color, colors.accentPrimary);
      expect(unselectedLabelStyle?.color, colors.textMuted);

      final decoratedBox = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      final topBorder = decoration.border?.top;
      expect(topBorder, isNotNull);
      expect(topBorder!.color, colors.borderDefault);
    });
  });
}
