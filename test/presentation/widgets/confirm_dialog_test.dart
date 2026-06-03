import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('import confirm dialog shows row count and actions', (tester) async {
    var result = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstraLightTheme(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showImportConfirmDialog(
                    context,
                    csvRowCount: 42,
                    existingSampleCount: 10,
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

    expect(find.text('Import data?'), findsOneWidget);
    expect(find.textContaining('42 samples'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
