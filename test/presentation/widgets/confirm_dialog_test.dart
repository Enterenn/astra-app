import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('import confirm dialog', () {
    testWidgets('shows row count and actions', (tester) async {
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
  });

  group('purge confirm dialog', () {
    testWidgets('shows three actions with UX copy', (tester) async {
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
      expect(
        find.textContaining('Export first if you want to keep a copy'),
        findsOneWidget,
      );
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

    testWidgets('delete anyway returns deleteConfirmed and closes dialog', (
      tester,
    ) async {
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
  });
}
