import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/l10n/app_localizations.dart';
import 'package:astra_app/presentation/cubits/my_data_state.dart';
import 'package:astra_app/presentation/cubits/onboarding_state.dart';
import 'package:astra_app/presentation/widgets/background_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helper.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final nowUtc = DateTime.utc(2026, 6, 2, 12);

  Future<void> pumpCard(
    WidgetTester tester, {
    required BackgroundCollectionStatus status,
    PermissionRequestStatus? denial,
    VoidCallback? onOpenSettings,
    VoidCallback? onRetryPermission,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: buildAstraLightTheme(preset: AstraAccentPreset.orange),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BackgroundStatusCard(
            status: status,
            lastIngestionUtc: null,
            nowUtc: nowUtc,
            activityPermissionDenial: denial,
            onOpenSettings: onOpenSettings,
            onRetryPermission: onRetryPermission,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('permissionDenied permanent shows Open settings copy and label',
      (tester) async {
    await pumpCard(
      tester,
      status: BackgroundCollectionStatus.permissionDenied,
      denial: PermissionRequestStatus.permanentlyDenied,
    );

    expect(
      find.text(l10n.myDataBackgroundPermissionPermanentlyDenied),
      findsOneWidget,
    );
    expect(find.text(l10n.myDataOpenSettings), findsOneWidget);
    expect(find.text(l10n.commonRetry), findsNothing);
  });

  testWidgets('permissionDenied reversible shows Retry copy and label',
      (tester) async {
    var retryCount = 0;
    await pumpCard(
      tester,
      status: BackgroundCollectionStatus.permissionDenied,
      denial: PermissionRequestStatus.denied,
      onRetryPermission: () => retryCount++,
    );

    expect(
      find.text(l10n.myDataBackgroundPermissionDeniedRetry),
      findsOneWidget,
    );
    expect(find.text(l10n.commonRetry), findsOneWidget);
    await tester.tap(find.text(l10n.commonRetry));
    expect(retryCount, 1);
  });
}
