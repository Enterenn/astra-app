import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/screens/menu_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MenuHubScreen', () {
    Future<void> pumpMenuHub(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: const Scaffold(body: MenuHubScreen()),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows Menu title and section headlines', (tester) async {
      await pumpMenuHub(tester);

      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('Informations'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('shows menu hub rows and excludes deferred entries', (
      tester,
    ) async {
      await pumpMenuHub(tester);

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Data'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Achievements'), findsNothing);
      expect(find.text('Help'), findsNothing);
    });

    testWidgets('does not show sovereignty screen content', (tester) async {
      await pumpMenuHub(tester);

      expect(find.text('Storage on this device'), findsNothing);
      expect(find.text('Export CSV'), findsNothing);
    });

    testWidgets('screen semantics label is Menu', (tester) async {
      await pumpMenuHub(tester);

      expect(find.text('Menu'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MenuHubScreen),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Menu',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('row taps do not crash when navigation is deferred', (
      tester,
    ) async {
      await pumpMenuHub(tester);

      for (final label in ['Profile', 'Data', 'Settings', 'About']) {
        await tester.tap(find.text(label));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
