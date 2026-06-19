import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/display_unit_preferences.dart';
import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:astra_app/presentation/cubits/theme_state.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('UserSettingsRepository', () {
    late Database db;
    late UserSettingsRepository repository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      repository = UserSettingsRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('theme mode and accent preset: round-trips, defaults, and invalid fallbacks', () async {
      await repository.setThemeMode(AstraThemePreference.dark);
      expect(await repository.getThemeMode(), AstraThemePreference.dark);

      await db.insert(
        'user_preferences',
        {'key': kThemeModeKey, 'value': 'invalid'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      expect(await repository.getThemeMode(), AstraThemePreference.system);

      expect(await repository.getAccentPreset(), AstraAccentPreset.orange);

      await repository.setAccentPreset(AstraAccentPreset.pink);
      expect(await repository.getAccentPreset(), AstraAccentPreset.pink);
      final accentRows = await db.query(
        'user_preferences',
        where: 'key = ?',
        whereArgs: [kAccentPresetKey],
      );
      expect(accentRows.single['value'], 'pink');

      await db.insert(
        'user_preferences',
        {'key': kAccentPresetKey, 'value': 'lavender'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      expect(await repository.getAccentPreset(), AstraAccentPreset.orange);
    });

    test('onboarding complete: defaults false and round-trips', () async {
      expect(await repository.getOnboardingComplete(), isFalse);
      await repository.setOnboardingComplete(true);
      expect(await repository.getOnboardingComplete(), isTrue);
    });

    test('celebration shown date: null default, round-trips, tryClaimCelebrationShownDate logic', () async {
      expect(await repository.getCelebrationShownDate(), isNull);

      expect(await repository.tryClaimCelebrationShownDate('2026-06-02'), isTrue);
      expect(await repository.getCelebrationShownDate(), '2026-06-02');

      expect(await repository.tryClaimCelebrationShownDate('2026-06-02'), isFalse);

      await repository.setCelebrationShownDate('2026-06-01');
      expect(await repository.tryClaimCelebrationShownDate('2026-06-02'), isTrue);
      expect(await repository.getCelebrationShownDate(), '2026-06-02');
    });

    test('goal notification shown date: independent from celebration, clearIfMatches only clears matching day', () async {
      await repository.setCelebrationShownDate('2026-06-02');
      expect(await repository.tryClaimGoalNotificationShownDate('2026-06-02'), isTrue);
      expect(await repository.getGoalNotificationShownDate(), '2026-06-02');
      expect(await repository.getCelebrationShownDate(), '2026-06-02');

      await repository.setGoalNotificationShownDate('2026-06-02');
      await repository.clearGoalNotificationShownDateIfMatches('2026-06-01');
      expect(await repository.getGoalNotificationShownDate(), '2026-06-02');
      await repository.clearGoalNotificationShownDateIfMatches('2026-06-02');
      expect(await repository.getGoalNotificationShownDate(), isNull);
    });

    test('goal notifications: defaults, isPreferenceSet, and round-trips flag', () async {
      expect(await repository.getGoalNotificationsEnabled(), isFalse);
      expect(await repository.isGoalNotificationsPreferenceSet(), isFalse);

      await repository.setGoalNotificationsEnabled(false);
      expect(await repository.isGoalNotificationsPreferenceSet(), isTrue);

      await repository.setGoalNotificationsEnabled(true);
      expect(await repository.getGoalNotificationsEnabled(), isTrue);
      await repository.setGoalNotificationsEnabled(false);
      expect(await repository.getGoalNotificationsEnabled(), isFalse);
    });

    test('display units: defaults, round-trips all three, and invalid stored fallbacks', () async {
      expect(await repository.getDistanceDisplayUnit(), DistanceDisplayUnit.metric);
      expect(await repository.getWeightDisplayUnit(), WeightDisplayUnit.kg);
      expect(await repository.getHeightDisplayUnit(), HeightDisplayUnit.cm);

      await repository.setDistanceDisplayUnit(DistanceDisplayUnit.imperial);
      expect(await repository.getDistanceDisplayUnit(), DistanceDisplayUnit.imperial);
      final distRows = await db.query(
        'user_preferences',
        where: 'key = ?',
        whereArgs: [kDistanceDisplayUnitKey],
      );
      expect(distRows.single['value'], 'imperial');

      await repository.setWeightDisplayUnit(WeightDisplayUnit.lb);
      expect(await repository.getWeightDisplayUnit(), WeightDisplayUnit.lb);
      final weightRows = await db.query(
        'user_preferences',
        where: 'key = ?',
        whereArgs: [kWeightDisplayUnitKey],
      );
      expect(weightRows.single['value'], 'lb');

      await repository.setHeightDisplayUnit(HeightDisplayUnit.ftIn);
      expect(await repository.getHeightDisplayUnit(), HeightDisplayUnit.ftIn);
      final heightRows = await db.query(
        'user_preferences',
        where: 'key = ?',
        whereArgs: [kHeightDisplayUnitKey],
      );
      expect(heightRows.single['value'], 'ft_in');

      await db.insert(
        'user_preferences',
        {'key': kDistanceDisplayUnitKey, 'value': 'yards'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        'user_preferences',
        {'key': kWeightDisplayUnitKey, 'value': 'stone'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        'user_preferences',
        {'key': kHeightDisplayUnitKey, 'value': 'meters'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      expect(await repository.getDistanceDisplayUnit(), DistanceDisplayUnit.metric);
      expect(await repository.getWeightDisplayUnit(), WeightDisplayUnit.kg);
      expect(await repository.getHeightDisplayUnit(), HeightDisplayUnit.cm);
    });
  });
}
