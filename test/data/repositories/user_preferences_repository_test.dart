import 'package:astra_app/core/constants/astra_accent_preset.dart';
import 'package:astra_app/core/constants/display_unit_preferences.dart';
import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/theme_state.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astra_app/core/time/local_day_formatter.dart';
import 'package:astra_app/core/time/system_time_provider.dart';

import '../../core/time/fake_time_provider.dart';
import '../../helpers/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('UserPreferencesRepository', () {
    late Database db;
    late UserPreferencesRepository repository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      repository = UserPreferencesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('daily step goal: round-trips, migration seed alignment, rejects non-positive, falls back on invalid stored', () async {
      await repository.setDailyStepGoal(12000);
      expect(await repository.getDailyStepGoal(), 12000);

      final todayIso = formatLocalDayIso(const SystemTimeProvider().snapshot());
      expect(await repository.getGoalForLocalDay(todayIso), 12000);
      final rows = await db.query('daily_goal_effective');
      expect(rows.length, 1);
      expect(rows.single['goal'], 12000);

      // fresh DB: migration seed aligns journal with prefs cache for today
      final freshDb = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      addTearDown(freshDb.close);
      final freshRepo = UserPreferencesRepository(freshDb);
      expect(
        await freshRepo.getGoalForLocalDay(todayIso),
        await freshRepo.getDailyStepGoal(),
      );

      // rejects non-positive goal
      expect(
        () => repository.setDailyStepGoal(0),
        throwsA(isA<ArgumentError>()),
      );

      // falls back to default goal for invalid stored value
      await db.insert(
        'user_preferences',
        {'key': kDailyStepGoalKey, 'value': '-1'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      expect(await repository.getDailyStepGoal(), kDefaultStepGoal);
    });

    test('theme mode and accent preset: round-trips, defaults, and invalid fallbacks', () async {
      // theme round-trip
      await repository.setThemeMode(AstraThemePreference.dark);
      expect(await repository.getThemeMode(), AstraThemePreference.dark);

      // invalid stored theme falls back to system
      await db.insert(
        'user_preferences',
        {'key': kThemeModeKey, 'value': 'invalid'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      expect(await repository.getThemeMode(), AstraThemePreference.system);

      // accent preset defaults to orange before any write
      expect(await repository.getAccentPreset(), AstraAccentPreset.orange);

      // accent preset round-trip and storage key
      await repository.setAccentPreset(AstraAccentPreset.pink);
      expect(await repository.getAccentPreset(), AstraAccentPreset.pink);
      final accentRows = await db.query(
        'user_preferences',
        where: 'key = ?',
        whereArgs: [kAccentPresetKey],
      );
      expect(accentRows.single['value'], 'pink');

      // invalid stored accent falls back to orange
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
      // null when unset
      expect(await repository.getCelebrationShownDate(), isNull);

      // first claim succeeds
      expect(await repository.tryClaimCelebrationShownDate('2026-06-02'), isTrue);
      expect(await repository.getCelebrationShownDate(), '2026-06-02');

      // second claim for same day returns false
      expect(await repository.tryClaimCelebrationShownDate('2026-06-02'), isFalse);

      // claim allowed when stored day differs
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

    test('display name: null default, round-trips, trims, clears when empty/whitespace, rejects over max length, null for stored whitespace', () async {
      expect(await repository.getDisplayName(), isNull);

      await repository.setDisplayName('Alex');
      expect(await repository.getDisplayName(), 'Alex');

      // trims surrounding whitespace
      await repository.setDisplayName('  Sam  ');
      expect(await repository.getDisplayName(), 'Sam');

      // clears when empty string
      await repository.setDisplayName('Alex');
      await repository.setDisplayName('');
      expect(await repository.getDisplayName(), isNull);

      // clears when whitespace-only
      await repository.setDisplayName('Alex');
      await repository.setDisplayName('   ');
      expect(await repository.getDisplayName(), isNull);

      // whitespace-only stored value reads back as null
      await db.insert(
        'user_preferences',
        {'key': kDisplayNameKey, 'value': '   '},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      expect(await repository.getDisplayName(), isNull);

      // rejects name over max length
      final tooLong = 'a' * (kMaxDisplayNameLength + 1);
      expect(
        () => repository.setDisplayName(tooLong),
        throwsA(isA<ArgumentError>()),
      );
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

    test('height and weight: round-trips, null clear, and rejects out-of-range values', () async {
      await repository.setHeightCm(175);
      expect(await repository.getHeightCm(), 175);
      await repository.setHeightCm(null);
      expect(await repository.getHeightCm(), isNull);

      expect(() => repository.setHeightCm(99), throwsA(isA<ArgumentError>()));
      expect(() => repository.setHeightCm(251), throwsA(isA<ArgumentError>()));

      await repository.setWeightKg(72.5);
      expect(await repository.getWeightKg(), 72.5);
      await repository.setWeightKg(null);
      expect(await repository.getWeightKg(), isNull);

      expect(() => repository.setWeightKg(29.9), throwsA(isA<ArgumentError>()));
      expect(() => repository.setWeightKg(300.1), throwsA(isA<ArgumentError>()));
    });
  });

  group('UserPreferencesRepository daily goal history', () {
    late Database db;
    late FakeTimeProvider clock;
    late UserPreferencesRepository repository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      await db.delete('daily_goal_effective');
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 11, 10),
        zoneOffset: const Duration(hours: 2),
      );
      repository = UserPreferencesRepository(db, clock: clock);
    });

    tearDown(() async {
      await db.close();
    });

    test('getGoalForLocalDay: resolves effective row, falls back to default, matches getDailyStepGoal after write', () async {
      await db.insert('daily_goal_effective', {
        'effective_from_local_day': '2026-06-08',
        'goal': 8000,
      });
      await db.insert('daily_goal_effective', {
        'effective_from_local_day': '2026-06-11',
        'goal': 10000,
      });

      expect(await repository.getGoalForLocalDay('2026-06-08'), 8000);
      expect(await repository.getGoalForLocalDay('2026-06-09'), 8000);
      expect(await repository.getGoalForLocalDay('2026-06-10'), 8000);
      expect(await repository.getGoalForLocalDay('2026-06-11'), 10000);
      expect(await repository.getGoalForLocalDay('2026-06-12'), 10000);

      // no row applies → default goal
      expect(await repository.getGoalForLocalDay('2020-01-01'), kDefaultStepGoal);

      // today matches getDailyStepGoal after write
      await repository.setDailyStepGoal(8800);
      final todayIso = formatLocalDayIso(clock.snapshot());
      expect(await repository.getGoalForLocalDay(todayIso), 8800);
      expect(await repository.getDailyStepGoal(), 8800);
    });

    test('getGoalsForLocalDays: batch resolution, fallback, and empty input guard', () async {
      await db.insert('daily_goal_effective', {
        'effective_from_local_day': '2026-06-08',
        'goal': 8000,
      });
      await db.insert('daily_goal_effective', {
        'effective_from_local_day': '2026-06-11',
        'goal': 10000,
      });

      const days = [
        '2026-06-08',
        '2026-06-09',
        '2026-06-10',
        '2026-06-11',
        '2026-06-12',
      ];
      final batch = await repository.getGoalsForLocalDays(days);
      for (final day in days) {
        expect(batch[day], await repository.getGoalForLocalDay(day));
      }

      // falls back to default when no row applies
      final fallback = await repository.getGoalsForLocalDays(['2020-01-01']);
      expect(fallback['2020-01-01'], kDefaultStepGoal);

      // returns empty map without querying for empty input
      expect(await repository.getGoalsForLocalDays([]), isEmpty);
      expect(await repository.getGoalsForLocalDays(const []), isEmpty);
    });

    test('journal insert semantics: same-day upsert, new-day creates row, rejects non-positive', () async {
      await repository.setDailyStepGoal(9000);
      await repository.setDailyStepGoal(9500);

      var rows = await db.query('daily_goal_effective');
      expect(rows.length, 1);
      expect(rows.single['goal'], 9500);
      expect(rows.single['effective_from_local_day'], '2026-06-11');
      expect(await repository.getDailyStepGoal(), 9500);

      // new calendar day creates a new row
      clock.setNowUtc(DateTime.utc(2026, 6, 12, 10));
      await repository.setDailyStepGoal(8000);
      rows = await db.query(
        'daily_goal_effective',
        orderBy: 'effective_from_local_day',
      );
      expect(rows.length, 2);
      expect(rows[0]['effective_from_local_day'], '2026-06-11');
      expect(rows[1]['effective_from_local_day'], '2026-06-12');
      expect(rows[0]['goal'], 9500);
      expect(rows[1]['goal'], 8000);

      // rejects non-positive on journal write
      expect(
        () => repository.setDailyStepGoal(-1),
        throwsA(isA<ArgumentError>()),
      );
      expect(await db.query('daily_goal_effective'), hasLength(2));
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

      // invalid stored values fall back to metric defaults
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
