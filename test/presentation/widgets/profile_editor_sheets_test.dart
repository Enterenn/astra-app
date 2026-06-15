import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/constants/display_unit_preferences.dart';
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

    testWidgets('returns height in cm from ft+in on Save', (tester) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await showHeightEditorSheet(
                      context,
                      heightUnit: HeightDisplayUnit.ftIn,
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
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '5');
      await tester.enterText(fields.at(1), '11');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, 180);
    });

    testWidgets('returns -1 when ft+in fields cleared on Save', (tester) async {
      int? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await showHeightEditorSheet(
                      context,
                      currentHeightCm: 180,
                      heightUnit: HeightDisplayUnit.ftIn,
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
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '');
      await tester.enterText(fields.at(1), '');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, -1);
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

    testWidgets('returns weight in kg from lb on Save', (tester) async {
      double? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await showWeightEditorSheet(
                      context,
                      weightUnit: WeightDisplayUnit.lb,
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
      await tester.enterText(find.byType(TextField), '159.8');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, 72.5);
    });

    testWidgets('accepts displayed min lb boundary and returns kg', (tester) async {
      double? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await showWeightEditorSheet(
                      context,
                      weightUnit: WeightDisplayUnit.lb,
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
      await tester.enterText(find.byType(TextField), '66.1');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, 30.0);
    });

    testWidgets('accepts displayed max lb boundary and returns kg', (tester) async {
      double? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await showWeightEditorSheet(
                      context,
                      weightUnit: WeightDisplayUnit.lb,
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
      await tester.enterText(find.byType(TextField), '661.4');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, 300.0);
    });

    testWidgets('returns -1.0 when lb field cleared on Save', (tester) async {
      double? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await showWeightEditorSheet(
                      context,
                      currentWeightKg: 72.5,
                      weightUnit: WeightDisplayUnit.lb,
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
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, -1.0);
    });
  });
}
