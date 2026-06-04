import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/health/background_health_capability_snapshot.dart';
import 'package:astra_app/presentation/cubits/my_data_state.dart';
import 'package:astra_app/presentation/widgets/background_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackgroundStatusCard', () {
    final nowUtc = DateTime.utc(2026, 6, 3, 12);
    final lastIngestionUtc = DateTime.utc(2026, 6, 3, 11, 30);

    Future<void> pumpCard(
      WidgetTester tester, {
      required BackgroundCollectionStatus status,
      VoidCallback? onOpenSettings,
      BackgroundHealthCapabilitySnapshot? capabilities,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: BackgroundStatusCard(
              status: status,
              lastIngestionUtc: lastIngestionUtc,
              nowUtc: nowUtc,
              capabilities: capabilities,
              onOpenSettings: onOpenSettings,
            ),
          ),
        ),
      );
    }

    testWidgets('healthy variant shows updating copy', (tester) async {
      await pumpCard(tester, status: BackgroundCollectionStatus.healthy);

      expect(find.text('Steps are updating'), findsOneWidget);
      expect(find.text('Last updated 30 minutes ago'), findsOneWidget);
    });

    testWidgets('stale variant shows delayed copy with last updated', (
      tester,
    ) async {
      await pumpCard(tester, status: BackgroundCollectionStatus.stale);

      expect(find.text('Steps may be delayed'), findsOneWidget);
      expect(find.text('Last updated 30 minutes ago'), findsOneWidget);
    });

    testWidgets('iosBackfill variant shows sync-on-open copy', (tester) async {
      await pumpCard(tester, status: BackgroundCollectionStatus.iosBackfill);

      expect(find.text('Updates when you open the app'), findsOneWidget);
      expect(find.text('Last updated 30 minutes ago'), findsOneWidget);
    });

    testWidgets('permissionDenied variant shows settings button', (
      tester,
    ) async {
      var settingsOpened = false;

      await pumpCard(
        tester,
        status: BackgroundCollectionStatus.permissionDenied,
        onOpenSettings: () => settingsOpened = true,
      );

      expect(find.text('Step access is off'), findsOneWidget);
      expect(find.text('Turn on in Settings'), findsOneWidget);

      await tester.tap(find.text('Turn on in Settings'));
      await tester.pump();

      expect(settingsOpened, isTrue);
    });

    testWidgets('stale with OEM deferral shows manufacturer hint', (
      tester,
    ) async {
      await pumpCard(
        tester,
        status: BackgroundCollectionStatus.stale,
        capabilities: const BackgroundHealthCapabilitySnapshot(
          activityRecognitionGranted: true,
          notificationGranted: true,
          batteryOptimizationExempt: false,
          fgsHealthDeclared: true,
          likelyOemBatteryDeferral: true,
          manufacturer: 'Samsung',
        ),
      );

      expect(
        find.textContaining(
          'Battery settings on Samsung devices can delay updates.',
        ),
        findsOneWidget,
      );
    });
  });
}
