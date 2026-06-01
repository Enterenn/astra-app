import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/theme_cubit.dart';
import 'package:astra_app/presentation/cubits/theme_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('ThemeCubit', () {
    late Database db;
    late UserPreferencesRepository repository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      repository = UserPreferencesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('defaults to system preference and ThemeMode', () {
      final cubit = ThemeCubit(userPreferences: repository);

      expect(cubit.state.preference, AstraThemePreference.system);
      expect(cubit.state.materialThemeMode, ThemeMode.system);

      cubit.close();
    });

    test('uses initialPreference from constructor', () {
      final cubit = ThemeCubit(
        userPreferences: repository,
        initialPreference: AstraThemePreference.dark,
      );

      expect(cubit.state.preference, AstraThemePreference.dark);
      expect(cubit.state.materialThemeMode, ThemeMode.dark);

      cubit.close();
    });

    test('setThemePreference persists and emits preference', () async {
      final cubit = ThemeCubit(userPreferences: repository);

      await cubit.setThemePreference(AstraThemePreference.light);

      expect(cubit.state.preference, AstraThemePreference.light);
      expect(cubit.state.materialThemeMode, ThemeMode.light);
      expect(await repository.getThemeMode(), AstraThemePreference.light);

      await cubit.close();
    });
  });
}
