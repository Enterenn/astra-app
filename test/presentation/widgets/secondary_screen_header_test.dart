import 'package:astra_app/presentation/widgets/secondary_screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astra_app/core/icons/phosphor_icons.dart';

import '../../helpers/astra_theme_test_helper.dart';

void main() {
  group('SecondaryScreenHeader', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(
        wrapWithAstraTheme(
          const SecondaryScreenHeader(title: 'Profile'),
        ),
      );
      await tester.pump();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.arrowLeft), findsOneWidget);
    });

    testWidgets('back tap pops nested route', (tester) async {
      var popped = false;

      await tester.pumpWidget(
        wrapWithAstraTheme(
          Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    const SecondaryScreenHeader(title: 'Data'),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (context) => const Scaffold(
                              body: SecondaryScreenHeader(title: 'Nested'),
                            ),
                          ),
                        );
                      },
                      child: const Text('Push'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Push'));
      await tester.pumpAndSettle();

      expect(find.text('Nested'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Data'), findsOneWidget);
      expect(find.text('Nested'), findsNothing);
      popped = true;
      expect(popped, isTrue);
    });
  });
}
