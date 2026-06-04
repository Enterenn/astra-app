import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/footprint_kpi_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FootprintKpiRow', () {
    Future<void> pumpRow(
      WidgetTester tester, {
      required int fileSizeBytes,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: FootprintKpiRow(fileSizeBytes: fileSizeBytes),
          ),
        ),
      );
    }

    testWidgets('renders file size on your phone', (tester) async {
      await pumpRow(tester, fileSizeBytes: 2516582);

      expect(find.text('2.4 MB'), findsOneWidget);
      expect(find.text('on your phone'), findsOneWidget);
    });

    testWidgets('exposes semantics label for screen readers', (tester) async {
      final handle = tester.ensureSemantics();

      await pumpRow(tester, fileSizeBytes: 2048);

      expect(find.bySemanticsLabel('2 KB on your phone'), findsOneWidget);

      handle.dispose();
    });
  });
}
