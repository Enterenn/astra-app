import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/footprint_kpi_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FootprintKpiRow', () {
    final nowUtc = DateTime.utc(2026, 6, 3, 12);

    Future<void> pumpRow(
      WidgetTester tester, {
      required int sampleCount,
      required int fileSizeBytes,
      DateTime? lastOptimizedUtc,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: FootprintKpiRow(
              sampleCount: sampleCount,
              fileSizeBytes: fileSizeBytes,
              lastOptimizedUtc: lastOptimizedUtc,
              nowUtc: nowUtc,
            ),
          ),
        ),
      );
    }

    testWidgets('renders sample count and file size', (tester) async {
      await pumpRow(
        tester,
        sampleCount: 10847,
        fileSizeBytes: 2516582,
        lastOptimizedUtc: nowUtc.subtract(const Duration(hours: 2)),
      );

      expect(find.text('10\u2009847'), findsOneWidget);
      expect(find.text('samples stored'), findsOneWidget);
      expect(find.text('2.4 MB'), findsOneWidget);
      expect(find.text('database size'), findsOneWidget);
    });

    testWidgets('shows not optimized yet when lastOptimized is null', (
      tester,
    ) async {
      await pumpRow(
        tester,
        sampleCount: 0,
        fileSizeBytes: 0,
      );

      expect(find.text('not optimized yet'), findsOneWidget);
      expect(find.text('last optimized'), findsOneWidget);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('exposes semantics labels for screen readers', (tester) async {
      final handle = tester.ensureSemantics();

      await pumpRow(
        tester,
        sampleCount: 42,
        fileSizeBytes: 2048,
        lastOptimizedUtc: nowUtc.subtract(const Duration(days: 1)),
      );

      expect(find.bySemanticsLabel('42 samples stored'), findsOneWidget);
      expect(find.bySemanticsLabel('Database size 2 KB'), findsOneWidget);

      handle.dispose();
    });
  });
}
