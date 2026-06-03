import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('purge confirm dialog shows three actions with UX copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstraLightTheme(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showPurgeConfirmDialog(
                    context,
                    onExportFirst: () {},
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

    expect(find.text('Delete all local data?'), findsOneWidget);
    expect(find.textContaining('Export first if you want to keep a copy'), findsOneWidget);
    expect(find.text('Export first'), findsOneWidget);
    expect(find.text('Delete anyway'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('export first does not close the dialog', (tester) async {
    var exportFirstTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstraLightTheme(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showPurgeConfirmDialog(
                    context,
                    onExportFirst: () => exportFirstTapped = true,
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

    await tester.tap(find.text('Export first'));
    await tester.pumpAndSettle();

    expect(exportFirstTapped, isTrue);
    expect(find.text('Delete all local data?'), findsOneWidget);
  });

  testWidgets('delete anyway returns deleteConfirmed and closes dialog', (tester) async {
    PurgeConfirmAction? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAstraLightTheme(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showPurgeConfirmDialog(
                    context,
                    onExportFirst: () {},
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
    await tester.tap(find.text('Delete anyway'));
    await tester.pumpAndSettle();

    expect(result, PurgeConfirmAction.deleteConfirmed);
    expect(find.text('Delete all local data?'), findsNothing);
  });
}
