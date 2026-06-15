import 'package:astra_app/core/constants/astra_theme.dart';
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
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: Scaffold(
            body: BackgroundStatusCard(
              status: status,
              lastIngestionUtc: lastIngestionUtc,
              nowUtc: nowUtc,
              onOpenSettings: onOpenSettings,
            ),
          ),
        ),
      );
    }

    testWidgets('healthy variant shows active collection copy', (tester) async {
      await pumpCard(tester, status: BackgroundCollectionStatus.healthy);

      expect(
        find.textContaining('Background collection active'),
        findsOneWidget,
      );
      expect(find.textContaining('Last sync 30 minutes ago'), findsOneWidget);
    });

    testWidgets('stale variant shows delayed copy with last sync', (tester) async {
      await pumpCard(tester, status: BackgroundCollectionStatus.stale);

      expect(
        find.textContaining('Background collection delayed'),
        findsOneWidget,
      );
    });

    testWidgets('iosBackfill variant shows sync-on-open copy', (tester) async {
      await pumpCard(tester, status: BackgroundCollectionStatus.iosBackfill);

      expect(
        find.textContaining('Steps sync when you open the app'),
        findsOneWidget,
      );
    });

    testWidgets('permissionDenied variant shows settings button', (tester) async {
      var settingsOpened = false;

      await pumpCard(
        tester,
        status: BackgroundCollectionStatus.permissionDenied,
        onOpenSettings: () => settingsOpened = true,
      );

      expect(find.text('Activity permission off'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);

      await tester.tap(find.text('Open settings'));
      await tester.pump();

      expect(settingsOpened, isTrue);
    });
  });
}
