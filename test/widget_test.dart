import 'package:astra_app/app.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/core/di/app_dependencies.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/sqflite_test_helper.dart';

void main() {
  late AppDependencies deps;

  setUpAll(() async {
    await setUpSqfliteFfi();
    final db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
    final userPreferences = UserPreferencesRepository(db);
    final initialTheme = await userPreferences.getThemeMode();
    deps = AppDependencies.test(
      userPreferences: userPreferences,
      initialTheme: initialTheme,
    );
  });

  testWidgets('AstraApp shows NavigationBar and switches tab placeholders', (
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
}
