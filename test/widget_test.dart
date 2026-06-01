import 'package:astra_app/app.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/theme_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('AstraApp navigation shell', () {
    late Database db;
    late AppDependencies deps;

    setUpAll(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      final userPreferences = UserPreferencesRepository(db);
      await userPreferences.setOnboardingComplete(true);
      deps = await AppDependencies.test(userPreferences: userPreferences);
    });

    tearDownAll(() async {
      await db.close();
    });

    testWidgets('shows NavigationBar and switches tab placeholders', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(AstraApp(deps: deps));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Today'), findsWidgets);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('My Data'), findsOneWidget);

      expect(
        find.text('Step tracking and your goal ring will appear here.'),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.bar_chart_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.text('Your 7-day and 30-day charts will appear here.'),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.shield_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.text('Data footprint, export, and settings will appear here.'),
        findsOneWidget,
      );
    });
  });

  group('AstraApp cold-start theme', () {
    late Database db;
    late AppDependencies deps;

    setUpAll(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      final userPreferences = UserPreferencesRepository(db);
      await userPreferences.setThemeMode(AstraThemePreference.dark);
      await userPreferences.setOnboardingComplete(true);
      deps = await AppDependencies.test(userPreferences: userPreferences);
    });

    tearDownAll(() async {
      await db.close();
    });

    testWidgets(
      'MaterialApp themeMode reflects persisted theme on first frame',
      (WidgetTester tester) async {
        await tester.pumpWidget(AstraApp(deps: deps));

        final materialApp =
            tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.themeMode, ThemeMode.dark);
      },
    );
  });

  group('AstraApp onboarding gate', () {
    late Database db;
    late AppDependencies completeDeps;

    setUpAll(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      final userPreferences = UserPreferencesRepository(db);
      await userPreferences.setOnboardingComplete(true);
      completeDeps = await AppDependencies.test(userPreferences: userPreferences);
    });

    tearDownAll(() async {
      await db.close();
    });

    testWidgets('shows shell after onboarding complete flag', (tester) async {
      await tester.pumpWidget(AstraApp(deps: completeDeps));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Your steps stay on this device.'), findsNothing);
    });
  });
}
