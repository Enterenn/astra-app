import 'package:astra_app/core/constants/astra_theme.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/onboarding_cubit.dart';
import 'package:astra_app/presentation/onboarding/onboarding_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('OnboardingFlow', () {
    late Database db;
    late UserPreferencesRepository userPreferences;
    late AppDependencies deps;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      userPreferences = UserPreferencesRepository(db);
      deps = await AppDependencies.test(
        userPreferences: userPreferences,
        initialOnboardingComplete: false,
      );
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows trust headline on first step', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: OnboardingFlow(
            deps: deps,
            onComplete: () {},
          ),
        ),
      );

      expect(find.text('Your steps stay on this device.'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('trust Continue does not request permissions', (tester) async {
      var permissionRequestCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAstraLightTheme(),
          home: OnboardingFlow(
            deps: deps,
            onComplete: () {},
            createCubit: (repo) => OnboardingCubit(
              userPreferences: repo,
              permissionRequester: (_) async {
                permissionRequestCount++;
                return PermissionStatus.granted;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(permissionRequestCount, 0);
      expect(find.text('Allow activity access'), findsOneWidget);
    });
  });
}
