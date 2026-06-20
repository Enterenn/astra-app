import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/display_name_editor_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

void main() {
  group('DisplayNameEditorRow', () {
    Future<void> pumpRow(
      WidgetTester tester, {
      String? displayName,
    }) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: DisplayNameEditorRow(
              displayName: displayName,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows Not set when display name is null', (tester) async {
      await pumpRow(tester);

      expect(find.text('Not set'), findsOneWidget);
    });

    testWidgets('shows Not set when display name is whitespace-only', (
      tester,
    ) async {
      await pumpRow(tester, displayName: '   ');

      expect(find.text('Not set'), findsOneWidget);
    });

    testWidgets('shows trimmed display name when set', (tester) async {
      await pumpRow(tester, displayName: '  Alex  ');

      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Not set'), findsNothing);
    });
  });
}
