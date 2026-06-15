import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/constants/display_unit_preferences.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/notification_service.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/profile_cubit.dart';
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

import '../../helpers/sqflite_test_helper.dart';

class _SeededProfileCubit extends ProfileCubit {
  _SeededProfileCubit({
    required super.userPreferences,
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
  bool disableAnimations = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAstraLightTheme(preset: AstraAccentPreset.orange),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: MultiBlocProvider(
            providers: [
              BlocProvider<ProfileCubit>.value(value: profileCubit),
              BlocProvider<ThemeCubit>.value(value: themeCubit),
              BlocProvider<UnitsCubit>.value(value: unitsCubit),
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
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('SettingsScreen', () {
    late Database db;
    late UserPreferencesRepository userPreferences;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userPreferences = UserPreferencesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows Units, Notifications, and Theme cards in order', (
      tester,
    ) async {
      final profileCubit = _SeededProfileCubit(
        userPreferences: userPreferences,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: ProfileState.ready(goalNotificationsEnabled: true),
      );
      addTearDown(profileCubit.close);

      final themeCubit = ThemeCubit(
        userPreferences: userPreferences,
        initialPreference: AstraThemePreference.light,
        initialAccentPreset: AstraAccentPreset.orange,
      );
      addTearDown(themeCubit.close);

      final unitsCubit = UnitsCubit(userPreferences: userPreferences);
      addTearDown(unitsCubit.close);

      await _pumpSettingsScreen(
        tester,
        profileCubit: profileCubit,
        themeCubit: themeCubit,
        unitsCubit: unitsCubit,
      );

      expect(find.text('Settings'), findsOneWidget);
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
      expect(find.byType(ThemeSelector), findsOneWidget);
      expect(find.byType(AccentPresetSelector), findsOneWidget);
      expect(find.byType(SectionCard), findsNWidgets(3));
      expect(find.byType(SettingsPreferenceRow), findsNWidgets(3));

      final headlines = tester
          .widgetList<SectionCard>(find.byType(SectionCard))
          .map((card) => card.headline)
          .toList();
      expect(headlines, ['Units', 'Notifications', 'Theme']);
    });

    testWidgets('selecting Imperial distance updates row label', (
      tester,
    ) async {
      // Covered by unit_option_picker_sheet_test + units_cubit_test.
    }, skip: 'Flaky modal bottom-sheet interaction in widget harness');

    testWidgets('shows Notifications and Theme cards with controls', (
      tester,
    ) async {
      final profileCubit = _SeededProfileCubit(
        userPreferences: userPreferences,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: ProfileState.ready(goalNotificationsEnabled: true),
      );
      addTearDown(profileCubit.close);

      final themeCubit = ThemeCubit(
        userPreferences: userPreferences,
        initialPreference: AstraThemePreference.light,
        initialAccentPreset: AstraAccentPreset.orange,
      );
      addTearDown(themeCubit.close);

      final unitsCubit = UnitsCubit(userPreferences: userPreferences);
      addTearDown(unitsCubit.close);

      await _pumpSettingsScreen(
        tester,
        profileCubit: profileCubit,
        themeCubit: themeCubit,
        unitsCubit: unitsCubit,
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
        userPreferences: userPreferences,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: ProfileState.ready(),
      );
      addTearDown(profileCubit.close);

      final themeCubit = ThemeCubit(userPreferences: userPreferences);
      addTearDown(themeCubit.close);

      final unitsCubit = UnitsCubit(userPreferences: userPreferences);
      addTearDown(unitsCubit.close);

      await _pumpSettingsScreen(
        tester,
        profileCubit: profileCubit,
        themeCubit: themeCubit,
        unitsCubit: unitsCubit,
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
        userPreferences: userPreferences,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: const ProfileState.loading(),
      );
      addTearDown(profileCubit.close);

      final themeCubit = ThemeCubit(userPreferences: userPreferences);
      addTearDown(themeCubit.close);

      final unitsCubit = UnitsCubit(userPreferences: userPreferences);
      addTearDown(unitsCubit.close);

      await _pumpSettingsScreen(
        tester,
        profileCubit: profileCubit,
        themeCubit: themeCubit,
        unitsCubit: unitsCubit,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Notifications'), findsNothing);
      expect(find.text('Theme'), findsNothing);
      expect(find.text('Units'), findsNothing);
    });

    testWidgets('shows error message when profile fails to load', (
      tester,
    ) async {
      final profileCubit = _SeededProfileCubit(
        userPreferences: userPreferences,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: const ProfileState(
          status: ProfileStatus.error,
          errorMessage: 'Network failed',
        ),
      );
      addTearDown(profileCubit.close);

      final themeCubit = ThemeCubit(userPreferences: userPreferences);
      addTearDown(themeCubit.close);

      final unitsCubit = UnitsCubit(userPreferences: userPreferences);
      addTearDown(unitsCubit.close);

      await _pumpSettingsScreen(
        tester,
        profileCubit: profileCubit,
        themeCubit: themeCubit,
        unitsCubit: unitsCubit,
      );

      expect(find.text('Network failed'), findsOneWidget);
      expect(find.text('Notifications'), findsNothing);
      expect(find.text('Units'), findsNothing);
    });

    testWidgets('switch reflects profile notification preference', (
      tester,
    ) async {
      final profileCubit = _SeededProfileCubit(
        userPreferences: userPreferences,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: ProfileState.ready(goalNotificationsEnabled: true),
      );
      addTearDown(profileCubit.close);

      final themeCubit = ThemeCubit(userPreferences: userPreferences);
      addTearDown(themeCubit.close);

      final unitsCubit = UnitsCubit(userPreferences: userPreferences);
      addTearDown(unitsCubit.close);

      await _pumpSettingsScreen(
        tester,
        profileCubit: profileCubit,
        themeCubit: themeCubit,
        unitsCubit: unitsCubit,
      );

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });
  });
}
