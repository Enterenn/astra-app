import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/notification_service.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:astra_app/presentation/cubits/profile_cubit.dart';
import 'package:astra_app/presentation/cubits/profile_state.dart';
import 'package:astra_app/presentation/cubits/theme_cubit.dart';
import 'package:astra_app/presentation/cubits/theme_state.dart';
import 'package:astra_app/presentation/screens/profile_screen.dart';
import 'package:astra_app/presentation/widgets/accent_preset_selector.dart';
import 'package:astra_app/presentation/widgets/theme_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../helpers/sqflite_test_helper.dart';

class _RecordingProfileCubit extends ProfileCubit {
  _RecordingProfileCubit({
    required super.userPreferences,
    required super.notificationService,
    required ProfileState seededState,
  }) : _seededState = seededState {
    emit(seededState);
  }

  final ProfileState _seededState;
  var setGoalNotificationsEnabledCalls = 0;
  bool? lastEnabledArg;

  @override
  Future<void> refresh() async {
    if (isClosed) {
      return;
    }
    emit(_seededState);
  }

  @override
  Future<bool> setGoalNotificationsEnabled(bool enabled) async {
    setGoalNotificationsEnabledCalls++;
    lastEnabledArg = enabled;
    emit(_seededState.copyWith(goalNotificationsEnabled: enabled));
    return true;
  }
}

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

Future<void> _pumpProfileScreen(
  WidgetTester tester, {
  required ProfileCubit profileCubit,
  AstraThemePreference themePreference = AstraThemePreference.system,
  AstraAccentPreset accentPreset = AstraAccentPreset.orange,
  bool disableAnimations = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAstraLightTheme(preset: accentPreset),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<ProfileCubit>.value(value: profileCubit),
              BlocProvider(
                create: (_) => ThemeCubit(
                  userPreferences: profileCubit.userPreferences,
                  initialPreference: themePreference,
                  initialAccentPreset: accentPreset,
                ),
              ),
            ],
            child: const ProfileScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('ProfileScreen', () {
    late Database db;
    late UserPreferencesRepository userPreferences;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userPreferences = UserPreferencesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows title and three section cards without Age row', (
      WidgetTester tester,
    ) async {
      final cubit = _SeededProfileCubit(
        userPreferences: userPreferences,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: ProfileState.ready(
          displayName: 'Alex',
          heightCm: 180,
          weightKg: 72.5,
          goalNotificationsEnabled: true,
        ),
      );

      await _pumpProfileScreen(tester, profileCubit: cubit);

      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Informations'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Display name'), findsOneWidget);
      expect(find.text('Height'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('Age'), findsNothing);
      expect(find.text('Receive Goal notifications'), findsOneWidget);
      expect(find.byType(ThemeSelector), findsOneWidget);
      expect(find.byType(AccentPresetSelector), findsOneWidget);

      await cubit.close();
    });

    testWidgets('shows Not set for empty profile values', (tester) async {
      final cubit = _SeededProfileCubit(
        userPreferences: userPreferences,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: ProfileState.ready(),
      );

      await _pumpProfileScreen(tester, profileCubit: cubit);

      expect(find.text('Not set'), findsNWidgets(3));

      await cubit.close();
    });

    testWidgets('formats height and weight values', (tester) async {
      final cubit = _SeededProfileCubit(
        userPreferences: userPreferences,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: ProfileState.ready(
          heightCm: 180,
          weightKg: 72.5,
        ),
      );

      await _pumpProfileScreen(tester, profileCubit: cubit);

      expect(find.text('180 cm'), findsOneWidget);
      expect(find.text('72.5 kg'), findsOneWidget);

      await cubit.close();
    });

    testWidgets('notification switch calls cubit enable when toggled on', (
      tester,
    ) async {
      final cubit = _RecordingProfileCubit(
        userPreferences: userPreferences,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: ProfileState.ready(goalNotificationsEnabled: false),
      );
      addTearDown(cubit.close);

      await _pumpProfileScreen(tester, profileCubit: cubit);

      expect(find.byType(Switch), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      await tester.tap(find.byType(Switch));
      await _pumpAsync(tester);

      expect(cubit.setGoalNotificationsEnabledCalls, 1);
      expect(cubit.lastEnabledArg, isTrue);
      expect(cubit.state.goalNotificationsEnabled, isTrue);
    });
  });
}
