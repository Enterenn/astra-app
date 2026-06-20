import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/notification_service.dart';
import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:astra_app/l10n/app_localizations.dart';
import 'package:astra_app/presentation/cubits/locale_cubit.dart';
import 'package:astra_app/presentation/cubits/profile_cubit.dart';
import 'package:astra_app/presentation/cubits/profile_errors.dart';
import 'package:astra_app/presentation/cubits/profile_state.dart';
import 'package:astra_app/presentation/cubits/theme_cubit.dart';
import 'package:astra_app/presentation/cubits/theme_state.dart';
import 'package:astra_app/presentation/cubits/units_cubit.dart';
import 'package:astra_app/presentation/screens/settings_screen.dart';
import 'package:astra_app/presentation/widgets/accent_preset_selector.dart';
import 'package:astra_app/presentation/widgets/section_card.dart';
import 'package:astra_app/presentation/widgets/settings_preference_row.dart';
import 'package:astra_app/presentation/widgets/theme_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';

import '../../helpers/l10n_test_helper.dart';
import '../../helpers/sqflite_test_helper.dart';

class _SeededProfileCubit extends ProfileCubit {
  _SeededProfileCubit({
    required super.userSettings,
    required super.userHealthMetrics,
    required super.notificationService,
    required ProfileState seededState,
  }) : _seededState = seededState {
    emit(seededState);
  }

  final ProfileState _seededState;

  @override
  Future<void> refresh() async {
    if (isClosed) {
      return;
    }
    emit(_seededState);
  }
}

Future<void> _pumpSettingsScreen(
  WidgetTester tester, {
  required ProfileCubit profileCubit,
  required ThemeCubit themeCubit,
  required UnitsCubit unitsCubit,
  required LocaleCubit localeCubit,
  bool disableAnimations = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      theme: buildAstraLightTheme(preset: AstraAccentPreset.orange),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: MultiBlocProvider(
            providers: [
              BlocProvider<ProfileCubit>.value(value: profileCubit),
              BlocProvider<ThemeCubit>.value(value: themeCubit),
              BlocProvider<UnitsCubit>.value(value: unitsCubit),
              BlocProvider<LocaleCubit>.value(value: localeCubit),
            ],
            child: const SettingsScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('SettingsScreen', () {
    late Database db;
    late UserSettingsRepository userSettings;
    late UserHealthMetricsRepository userHealthMetrics;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userSettings = UserSettingsRepository(db);
      userHealthMetrics = UserHealthMetricsRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows Language, Units, Notifications, and Theme cards in order', (
      tester,
    ) async {
      final profileCubit = _SeededProfileCubit(
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: ProfileState.ready(goalNotificationsEnabled: true),
      );
      addTearDown(profileCubit.close);

      final themeCubit = ThemeCubit(
        userSettings: userSettings,
        initialPreference: AstraThemePreference.light,
        initialAccentPreset: AstraAccentPreset.orange,
      );
      addTearDown(themeCubit.close);

      final unitsCubit = UnitsCubit(userSettings: userSettings);
      addTearDown(unitsCubit.close);

      final localeCubit = LocaleCubit(userSettings: userSettings);
      addTearDown(localeCubit.close);

      await _pumpSettingsScreen(
        tester,
        profileCubit: profileCubit,
        themeCubit: themeCubit,
        unitsCubit: unitsCubit,
        localeCubit: localeCubit,
      );

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Units'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('Height'), findsOneWidget);
      expect(find.text('Metric'), findsOneWidget);
      expect(find.text('Kg'), findsOneWidget);
      expect(find.text('cm'), findsOneWidget);
      expect(find.text('Receive Goal notifications'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byType(SettingsPreferenceRow), findsNWidgets(4));
      expect(find.byType(ThemeSelector), findsOneWidget);
      expect(find.byType(AccentPresetSelector), findsOneWidget);
      expect(find.byType(SectionCard), findsNWidgets(4));

      final headlines = tester
          .widgetList<SectionCard>(find.byType(SectionCard))
          .map((card) => card.headline)
          .toList();
      expect(headlines, ['Language', 'Units', 'Notifications', 'Theme']);
    });

    // Tap→sheet integration: covered by unit_option_picker_sheet_test + units_cubit_test.
    // (Flaky modal bottom-sheet in widget harness — no dedicated test here.)

    testWidgets('shows Notifications and Theme cards with controls', (
      tester,
    ) async {
      final profileCubit = _SeededProfileCubit(
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: ProfileState.ready(goalNotificationsEnabled: true),
      );
      addTearDown(profileCubit.close);

      final themeCubit = ThemeCubit(
        userSettings: userSettings,
        initialPreference: AstraThemePreference.light,
        initialAccentPreset: AstraAccentPreset.orange,
      );
      addTearDown(themeCubit.close);

      final unitsCubit = UnitsCubit(userSettings: userSettings);
      addTearDown(unitsCubit.close);

      final localeCubit = LocaleCubit(userSettings: userSettings);
      addTearDown(localeCubit.close);

      await _pumpSettingsScreen(
        tester,
        profileCubit: profileCubit,
        themeCubit: themeCubit,
        unitsCubit: unitsCubit,
        localeCubit: localeCubit,
      );

      expect(find.text('Receive Goal notifications'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byType(ThemeSelector), findsOneWidget);
      expect(find.byType(AccentPresetSelector), findsOneWidget);
    });

    testWidgets('excludes Profile-only and other deferred sections', (
      tester,
    ) async {
      final profileCubit = _SeededProfileCubit(
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: ProfileState.ready(),
      );
      addTearDown(profileCubit.close);

      final themeCubit = ThemeCubit(userSettings: userSettings);
      addTearDown(themeCubit.close);

      final unitsCubit = UnitsCubit(userSettings: userSettings);
      addTearDown(unitsCubit.close);

      final localeCubit = LocaleCubit(userSettings: userSettings);
      addTearDown(localeCubit.close);

      await _pumpSettingsScreen(
        tester,
        profileCubit: profileCubit,
        themeCubit: themeCubit,
        unitsCubit: unitsCubit,
        localeCubit: localeCubit,
      );

      expect(find.text('Informations'), findsNothing);
      expect(find.textContaining('ASTRA v'), findsNothing);
      expect(find.text('Display name'), findsNothing);
      expect(find.text('Appearance'), findsNothing);
    });

    testWidgets('shows loading indicator while profile is loading', (
      tester,
    ) async {
      final profileCubit = _SeededProfileCubit(
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: const ProfileState.loading(),
      );
      addTearDown(profileCubit.close);

      final themeCubit = ThemeCubit(userSettings: userSettings);
      addTearDown(themeCubit.close);

      final unitsCubit = UnitsCubit(userSettings: userSettings);
      addTearDown(unitsCubit.close);

      final localeCubit = LocaleCubit(userSettings: userSettings);
      addTearDown(localeCubit.close);

      await _pumpSettingsScreen(
        tester,
        profileCubit: profileCubit,
        themeCubit: themeCubit,
        unitsCubit: unitsCubit,
        localeCubit: localeCubit,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Notifications'), findsNothing);
      expect(find.text('Theme'), findsNothing);
      expect(find.text('Units'), findsNothing);
      expect(find.text('Language'), findsNothing);
    });

    testWidgets('shows error message when profile fails to load', (
      tester,
    ) async {
      final profileCubit = _SeededProfileCubit(
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: const ProfileState(
          status: ProfileStatus.error,
          loadError: ProfileLoadError.generic,
        ),
      );
      addTearDown(profileCubit.close);

      final themeCubit = ThemeCubit(userSettings: userSettings);
      addTearDown(themeCubit.close);

      final unitsCubit = UnitsCubit(userSettings: userSettings);
      addTearDown(unitsCubit.close);

      final localeCubit = LocaleCubit(userSettings: userSettings);
      addTearDown(localeCubit.close);

      await _pumpSettingsScreen(
        tester,
        profileCubit: profileCubit,
        themeCubit: themeCubit,
        unitsCubit: unitsCubit,
        localeCubit: localeCubit,
      );

      expect(find.text(l10n.profileLoadErrorGeneric), findsOneWidget);
      expect(find.text(l10n.settingsNotifications), findsNothing);
      expect(find.text(l10n.settingsUnits), findsNothing);
    });

    testWidgets('switch reflects profile notification preference', (
      tester,
    ) async {
      final profileCubit = _SeededProfileCubit(
        userSettings: userSettings,
        userHealthMetrics: userHealthMetrics,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: ProfileState.ready(goalNotificationsEnabled: true),
      );
      addTearDown(profileCubit.close);

      final themeCubit = ThemeCubit(userSettings: userSettings);
      addTearDown(themeCubit.close);

      final unitsCubit = UnitsCubit(userSettings: userSettings);
      addTearDown(unitsCubit.close);

      final localeCubit = LocaleCubit(userSettings: userSettings);
      addTearDown(localeCubit.close);

      await _pumpSettingsScreen(
        tester,
        profileCubit: profileCubit,
        themeCubit: themeCubit,
        unitsCubit: unitsCubit,
        localeCubit: localeCubit,
      );

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });
  });
}
