import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/services/notification_service.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:astra_app/presentation/cubits/profile_cubit.dart';
import 'package:astra_app/presentation/cubits/profile_state.dart';
import 'package:astra_app/presentation/screens/profile_screen.dart';
import 'package:astra_app/presentation/widgets/accent_preset_selector.dart';
import 'package:astra_app/presentation/widgets/section_card.dart';
import 'package:astra_app/presentation/widgets/theme_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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

Future<void> _pumpProfileScreen(
  WidgetTester tester, {
  required ProfileCubit profileCubit,
  bool showInlineTitle = false,
  bool disableAnimations = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAstraLightTheme(preset: AstraAccentPreset.orange),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: BlocProvider<ProfileCubit>.value(
            value: profileCubit,
            child: ProfileScreen(showInlineTitle: showInlineTitle),
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

    testWidgets('uses ColoredBox shell without nested Scaffold', (
      tester,
    ) async {
      final cubit = _SeededProfileCubit(
        userPreferences: userPreferences,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: ProfileState.ready(),
      );
      addTearDown(cubit.close);

      await _pumpProfileScreen(tester, profileCubit: cubit);

      expect(
        find.descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(Scaffold),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(ColoredBox),
        ),
        findsWidgets,
      );
    });

    testWidgets('shows slim Informations section only in embedded mode', (
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
        ),
      );
      addTearDown(cubit.close);

      await _pumpProfileScreen(tester, profileCubit: cubit);

      expect(find.text('Profile'), findsNothing);
      expect(find.text('My Profile'), findsNothing);
      expect(find.text('Informations'), findsOneWidget);
      expect(find.byType(SectionCard), findsOneWidget);
      expect(find.text('Display name'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Height'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('Age'), findsNothing);
      expect(find.textContaining('ASTRA v'), findsNothing);
      expect(find.text('Notifications'), findsNothing);
      expect(find.text('Appearance'), findsNothing);
      expect(find.text('Receive Goal notifications'), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(ThemeSelector), findsNothing);
      expect(find.byType(AccentPresetSelector), findsNothing);
    });

    testWidgets('shows inline Profile title when showInlineTitle is true', (
      tester,
    ) async {
      final cubit = _SeededProfileCubit(
        userPreferences: userPreferences,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: ProfileState.ready(),
      );
      addTearDown(cubit.close);

      await _pumpProfileScreen(
        tester,
        profileCubit: cubit,
        showInlineTitle: true,
      );

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('My Profile'), findsNothing);
    });

    testWidgets('shows Not set for empty profile values', (tester) async {
      final cubit = _SeededProfileCubit(
        userPreferences: userPreferences,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: ProfileState.ready(),
      );
      addTearDown(cubit.close);

      await _pumpProfileScreen(tester, profileCubit: cubit);

      expect(find.text('Not set'), findsNWidgets(3));
    });

    testWidgets('shows loading indicator while profile is loading', (
      tester,
    ) async {
      final cubit = _SeededProfileCubit(
        userPreferences: userPreferences,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: const ProfileState.loading(),
      );
      addTearDown(cubit.close);

      await _pumpProfileScreen(tester, profileCubit: cubit);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Informations'), findsNothing);
    });

    testWidgets('shows error message when profile fails to load', (
      tester,
    ) async {
      final cubit = _SeededProfileCubit(
        userPreferences: userPreferences,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: const ProfileState(
          status: ProfileStatus.error,
          errorMessage: 'Network failed',
        ),
      );
      addTearDown(cubit.close);

      await _pumpProfileScreen(tester, profileCubit: cubit);

      expect(find.text('Network failed'), findsOneWidget);
      expect(find.text('Informations'), findsNothing);
    });

    testWidgets('shows default error message when errorMessage is null', (
      tester,
    ) async {
      final cubit = _SeededProfileCubit(
        userPreferences: userPreferences,
        notificationService: NotificationService(
          permissionChecker: () async => PermissionStatus.granted,
        ),
        seededState: const ProfileState(status: ProfileStatus.error),
      );
      addTearDown(cubit.close);

      await _pumpProfileScreen(tester, profileCubit: cubit);

      expect(find.text('Could not load profile'), findsOneWidget);
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
      addTearDown(cubit.close);

      await _pumpProfileScreen(tester, profileCubit: cubit);

      expect(find.text('180 cm'), findsOneWidget);
      expect(find.text('72.5 kg'), findsOneWidget);
    });
  });
}
