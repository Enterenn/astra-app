import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/display_name_editor_sheet.dart';
import 'package:astra_app/presentation/widgets/height_editor_sheet.dart';
import 'package:astra_app/presentation/widgets/weight_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('showDisplayNameEditorSheet', () {
    testWidgets('returns trimmed name on Save', (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await showDisplayNameEditorSheet(context);
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
      await tester.enterText(find.byType(TextField), 'Alex');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, 'Alex');
    });
  });

  group('showHeightEditorSheet', () {
    testWidgets('returns height in cm on Save', (tester) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await showHeightEditorSheet(context);
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
      await tester.enterText(find.byType(TextField), '180');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, 180);
    });
  });

  group('showWeightEditorSheet', () {
    testWidgets('returns weight in kg on Save', (tester) async {
      double? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await showWeightEditorSheet(context);
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
      await tester.enterText(find.byType(TextField), '72.5');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, 72.5);
    });
  });
}
