import 'package:astra_app/core/constants/astra_accent_preset.dart';
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

    test('defaults to system preference and orange accent', () {
      final cubit = ThemeCubit(userPreferences: repository);

      expect(cubit.state.preference, AstraThemePreference.system);
      expect(cubit.state.materialThemeMode, ThemeMode.system);
      expect(cubit.state.accentPreset, AstraAccentPreset.orange);

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

    test('setThemePreference no-ops when preference unchanged', () async {
      final cubit = ThemeCubit(
        userPreferences: repository,
        initialPreference: AstraThemePreference.dark,
      );
      await repository.setThemeMode(AstraThemePreference.light);

      await cubit.setThemePreference(AstraThemePreference.dark);

      expect(cubit.state.preference, AstraThemePreference.dark);
      expect(await repository.getThemeMode(), AstraThemePreference.light);

      await cubit.close();
    });

    test('setAccentPreset persists and emits preset', () async {
      final cubit = ThemeCubit(userPreferences: repository);

      await cubit.setAccentPreset(AstraAccentPreset.magenta);

      expect(cubit.state.accentPreset, AstraAccentPreset.magenta);
      expect(await repository.getAccentPreset(), AstraAccentPreset.magenta);

      await cubit.close();
    });

    test('getAccentPreset maps legacy cyan and purple storage values', () async {
      final txn = db;
      await txn.insert(
        'user_preferences',
        {'key': 'accent_preset', 'value': 'cyan'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      expect(await repository.getAccentPreset(), AstraAccentPreset.blue);

      await txn.insert(
        'user_preferences',
        {'key': 'accent_preset', 'value': 'purple'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      expect(await repository.getAccentPreset(), AstraAccentPreset.magenta);
    });

    test('setAccentPreset no-ops when preset unchanged', () async {
      final cubit = ThemeCubit(
        userPreferences: repository,
        initialAccentPreset: AstraAccentPreset.green,
      );
      await repository.setAccentPreset(AstraAccentPreset.blue);

      await cubit.setAccentPreset(AstraAccentPreset.green);

      expect(cubit.state.accentPreset, AstraAccentPreset.green);
      expect(await repository.getAccentPreset(), AstraAccentPreset.blue);

      await cubit.close();
    });

    test('rapid changes end on last preference in DB and state', () async {
      final cubit = ThemeCubit(userPreferences: repository);

      await Future.wait([
        cubit.setThemePreference(AstraThemePreference.dark),
        cubit.setThemePreference(AstraThemePreference.light),
        cubit.setThemePreference(AstraThemePreference.dark),
      ]);

      expect(cubit.state.preference, AstraThemePreference.dark);
      expect(await repository.getThemeMode(), AstraThemePreference.dark);

      await cubit.close();
    });
  });
}
