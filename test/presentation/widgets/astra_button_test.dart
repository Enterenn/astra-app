import 'package:astra_app/core/constants/astra_spacing.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/astra_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AstraButton', () {
    testWidgets('enforces minimum touch target height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: AstraButton(
              label: 'Continue',
              onPressed: () {},
            ),
          ),
        ),
      );

      final buttonBox = tester.getSize(find.byType(FilledButton));
      expect(buttonBox.height, greaterThanOrEqualTo(AstraSpacing.kMinTouchTarget));
    });

    testWidgets('primary variant uses accent fill styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: AstraButton(
              label: 'Continue',
              onPressed: () {},
            ),
          ),
        ),
      );

      final filledButton = tester.widget<FilledButton>(find.byType(FilledButton));
      final style = filledButton.style!;
      final context = tester.element(find.byType(FilledButton));
      final theme = Theme.of(context);

      expect(style.backgroundColor?.resolve({}), theme.colorScheme.primary);
      expect(style.foregroundColor?.resolve({}), theme.colorScheme.onPrimary);
    });

    testWidgets('ghost variant renders as TextButton', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: AstraButton(
              label: 'Skip notifications',
              variant: AstraButtonVariant.ghost,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(TextButton), findsOneWidget);
      expect(find.text('Skip notifications'), findsOneWidget);
    });

    testWidgets('secondary variant renders as OutlinedButton', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: AstraButton(
              label: 'Skip',
              variant: AstraButtonVariant.secondary,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(OutlinedButton), findsOneWidget);
    });
  });
}
