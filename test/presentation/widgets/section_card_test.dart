import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SectionCard', () {
    testWidgets('shows headline only when trailing is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: const Scaffold(
            body: SectionCard(
              headline: 'This week',
              child: Text('content'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('This week'), findsOneWidget);
      expect(find.text('trailing'), findsNothing);
    });

    testWidgets('shows trailing widget in header row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: const Scaffold(
            body: SectionCard(
              headline: 'This week',
              trailing: Text('trailing'),
              child: Text('content'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('This week'), findsOneWidget);
      expect(find.text('trailing'), findsOneWidget);
      expect(find.text('content'), findsOneWidget);
    });
  });
}
