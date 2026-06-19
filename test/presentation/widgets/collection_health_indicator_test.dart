import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/health/collection_health_display.dart';
import 'package:astra_app/presentation/widgets/collection_health_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 6, 3, 15);

  group('CollectionHealthIndicator', () {
    testWidgets('active state shows collection active copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: CollectionHealthIndicator(
              display: CollectionHealthDisplay.active,
              nowUtc: fixedNow,
            ),
          ),
        ),
      );

      expect(find.text('Collection active ●'), findsOneWidget);
    });

    testWidgets('stale state shows relative last sync copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: CollectionHealthIndicator(
              display: CollectionHealthDisplay.stale,
              lastIngestionUtc: fixedNow.subtract(const Duration(hours: 3)),
              nowUtc: fixedNow,
            ),
          ),
        ),
      );

      expect(find.text('Last sync 3 hours ago ⚠'), findsOneWidget);
    });

    testWidgets('permission denied state shows revoked copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: CollectionHealthIndicator(
              display: CollectionHealthDisplay.permissionDenied,
              nowUtc: fixedNow,
            ),
          ),
        ),
      );

      expect(find.text('Sensor access revoked ✕'), findsOneWidget);
    });

    testWidgets('exposes label as semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: CollectionHealthIndicator(
              display: CollectionHealthDisplay.active,
              nowUtc: fixedNow,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Collection active ●'), findsOneWidget);
      expect(find.bySemanticsLabel('Collection health status'), findsOneWidget);

      handle.dispose();
    });
  });
}
