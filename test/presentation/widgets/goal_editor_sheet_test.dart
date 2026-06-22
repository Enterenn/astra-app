import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/goal_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

Future<int?> _openSheet(WidgetTester tester, {required int currentGoal}) async {
  int? result;
  await tester.pumpWidget(
    TestMaterialApp(
      theme: buildAstraLightTheme(),
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showGoalEditorSheet(
                  context,
                  currentGoal: currentGoal,
                );
              },
              child: const Text('Open'),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('opens with current goal pre-filled', (tester) async {
    await _openSheet(tester, currentGoal: 8000);

    expect(find.text('Daily step goal'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, '8000');
  });

  testWidgets('invalid input disables Save', (tester) async {
    await _openSheet(tester, currentGoal: 8000);

    await tester.enterText(find.byType(TextField), '999');
    await tester.pump();

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(saveButton.onPressed, isNull);
    expect(
      find.text('Enter a value between 1,000 and 100,000.'),
      findsOneWidget,
    );
  });

  testWidgets('unchanged valid value disables Save', (tester) async {
    await _openSheet(tester, currentGoal: 8000);

    await tester.enterText(find.byType(TextField), '8000');
    await tester.pump();

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('valid change returns new goal on Save', (tester) async {
    int? result;
    await tester.pumpWidget(
      TestMaterialApp(
        theme: buildAstraLightTheme(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showGoalEditorSheet(
                    context,
                    currentGoal: 8000,
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '12000');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 12000);
  });

  testWidgets('Cancel returns null', (tester) async {
    final result = await _openSheet(tester, currentGoal: 8000);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
