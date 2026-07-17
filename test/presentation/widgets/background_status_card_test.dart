import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/l10n/app_localizations.dart';
import 'package:astra_app/presentation/cubits/my_data_state.dart';
import 'package:astra_app/presentation/widgets/background_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('BackgroundStatusCard', () {
    final nowUtc = DateTime.utc(2026, 6, 3, 12);
    final lastIngestionUtc = DateTime.utc(2026, 6, 3, 11, 30);

    Future<void> pumpCard(
      WidgetTester tester, {
      required BackgroundCollectionStatus status,
      VoidCallback? onOpenSettings,
    }) async {
      await tester.pumpWidget(
        TestMaterialApp(
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

    testWidgets('healthy status exposes live region semantics label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await pumpCard(tester, status: BackgroundCollectionStatus.healthy);

      final expectedLabel = l10n.myDataBackgroundHealthy('30 minutes ago');
      expect(find.bySemanticsLabel(expectedLabel), findsOneWidget);

      final semanticsWidget = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(BackgroundStatusCard),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.liveRegion == true,
          ),
        ),
      );
      expect(semanticsWidget.properties.liveRegion, isTrue);
      expect(semanticsWidget.properties.label, expectedLabel);

      handle.dispose();
    });

    testWidgets('status transition updates live region semantics label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await pumpCard(tester, status: BackgroundCollectionStatus.stale);

      final staleLabel = l10n.myDataBackgroundStale('30 minutes ago');
      expect(find.bySemanticsLabel(staleLabel), findsOneWidget);

      await pumpCard(tester, status: BackgroundCollectionStatus.healthy);

      final healthyLabel = l10n.myDataBackgroundHealthy('30 minutes ago');
      expect(find.bySemanticsLabel(staleLabel), findsNothing);
      expect(find.bySemanticsLabel(healthyLabel), findsOneWidget);

      handle.dispose();
    });

    testWidgets('permissionDenied keeps settings button outside live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await pumpCard(
        tester,
        status: BackgroundCollectionStatus.permissionDenied,
      );

      expect(
        find.bySemanticsLabel(l10n.myDataBackgroundPermissionDenied),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(l10n.myDataOpenSettings), findsOneWidget);

      handle.dispose();
    });
  });
}
