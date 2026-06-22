import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/presentation/widgets/footprint_kpi_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

void main() {
  group('FootprintKpiRow', () {
    final nowUtc = DateTime.utc(2026, 6, 3, 12);
    final lastOptimizedUtc = DateTime.utc(2026, 6, 2, 8);

    Future<void> pumpRow(
      WidgetTester tester, {
      int sampleCount = 1234,
      int fileSizeBytes = 2516582,
      DateTime? lastOptimized,
      double width = 800,
    }) async {
      tester.view.physicalSize = Size(width, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        TestMaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: FootprintKpiRow(
              sampleCount: sampleCount,
              fileSizeBytes: fileSizeBytes,
              lastOptimizedUtc: lastOptimized,
              nowUtc: nowUtc,
            ),
          ),
        ),
      );
    }

    testWidgets('renders sample count, database size, and last optimized', (
      tester,
    ) async {
      await pumpRow(tester, lastOptimized: lastOptimizedUtc);

      expect(find.text('1\u2009234'), findsOneWidget);
      expect(find.text('samples stored'), findsOneWidget);
      expect(find.text('2.4 MB'), findsOneWidget);
      expect(find.text('database size'), findsOneWidget);
      expect(find.text('1 day ago'), findsOneWidget);
      expect(find.textContaining('optimized'), findsOneWidget);
    });

    testWidgets('null lastOptimized shows not optimized yet fallback', (
      tester,
    ) async {
      await pumpRow(tester, lastOptimized: null);

      expect(find.text('—'), findsOneWidget);
      expect(find.text('not optimized yet'), findsOneWidget);
    });

    testWidgets('exposes semantics labels for screen readers', (tester) async {
      final handle = tester.ensureSemantics();

      await pumpRow(
        tester,
        sampleCount: 42,
        fileSizeBytes: 2048,
        lastOptimized: null,
      );

      expect(find.bySemanticsLabel('42 samples stored'), findsOneWidget);
      expect(find.bySemanticsLabel('Database size 2 KB'), findsOneWidget);
      expect(find.bySemanticsLabel('not optimized yet'), findsOneWidget);

      handle.dispose();
    });
  });
}
