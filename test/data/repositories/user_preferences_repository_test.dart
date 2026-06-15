import 'package:astra_app/core/constants/astra_accent_preset.dart';
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

    test('round-trips daily step goal', () async {
      await repository.setDailyStepGoal(12000);
      expect(await repository.getDailyStepGoal(), 12000);

      final todayIso = formatLocalDayIso(const SystemTimeProvider().snapshot());
      expect(await repository.getGoalForLocalDay(todayIso), 12000);
      final rows = await db.query('daily_goal_effective');
      expect(rows.length, 1);
      expect(rows.single['goal'], 12000);
    });

    test('migration seed aligns journal with prefs cache for today', () async {
      final todayIso = formatLocalDayIso(const SystemTimeProvider().snapshot());
      expect(
        await repository.getGoalForLocalDay(todayIso),
        await repository.getDailyStepGoal(),
      );
    });

    test('rejects non-positive daily step goal on write', () async {
      expect(
        () => repository.setDailyStepGoal(0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('round-trips theme mode', () async {
      await repository.setThemeMode(AstraThemePreference.dark);
      expect(await repository.getThemeMode(), AstraThemePreference.dark);
    });

    test('defaults accent preset to orange when absent', () async {
      expect(await repository.getAccentPreset(), AstraAccentPreset.orange);
    });

    test('round-trips accent preset using English storage IDs', () async {
      await repository.setAccentPreset(AstraAccentPreset.pink);
      expect(await repository.getAccentPreset(), AstraAccentPreset.pink);

      final rows = await db.query(
        'user_preferences',
        where: 'key = ?',
        whereArgs: [kAccentPresetKey],
      );
      expect(rows.single['value'], 'pink');
    });

    test('falls back to orange for invalid stored accent preset', () async {
      await db.insert(
        'user_preferences',
        {'key': kAccentPresetKey, 'value': 'lavender'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      expect(await repository.getAccentPreset(), AstraAccentPreset.orange);
    });

    test('falls back to system for invalid stored theme', () async {
      await db.insert(
        'user_preferences',
        {'key': kThemeModeKey, 'value': 'invalid'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      expect(await repository.getThemeMode(), AstraThemePreference.system);
    });

    test('falls back to default goal for invalid stored goal', () async {
      await db.insert(
        'user_preferences',
        {'key': kDailyStepGoalKey, 'value': '-1'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      expect(await repository.getDailyStepGoal(), kDefaultStepGoal);
    });

    test('onboarding complete defaults to false when absent', () async {
      expect(await repository.getOnboardingComplete(), isFalse);
    });

    test('round-trips onboarding complete flag', () async {
      await repository.setOnboardingComplete(true);
      expect(await repository.getOnboardingComplete(), isTrue);
    });

    test('celebration shown date is null when unset', () async {
      expect(await repository.getCelebrationShownDate(), isNull);
    });

    test('round-trips celebration shown date', () async {
      await repository.setCelebrationShownDate('2026-06-02');
      expect(await repository.getCelebrationShownDate(), '2026-06-02');
    });

    test('tryClaimCelebrationShownDate returns true on first claim for a day', () async {
      expect(await repository.tryClaimCelebrationShownDate('2026-06-02'), isTrue);
      expect(await repository.getCelebrationShownDate(), '2026-06-02');
    });

    test('tryClaimCelebrationShownDate returns false when already claimed', () async {
      await repository.setCelebrationShownDate('2026-06-02');
      expect(await repository.tryClaimCelebrationShownDate('2026-06-02'), isFalse);
    });

    test('tryClaimCelebrationShownDate allows claim when stored day differs', () async {
      await repository.setCelebrationShownDate('2026-06-01');
      expect(await repository.tryClaimCelebrationShownDate('2026-06-02'), isTrue);
      expect(await repository.getCelebrationShownDate(), '2026-06-02');
    });

    test('goal notification shown date is independent from celebration', () async {
      await repository.setCelebrationShownDate('2026-06-02');
      expect(await repository.tryClaimGoalNotificationShownDate('2026-06-02'), isTrue);
      expect(await repository.getGoalNotificationShownDate(), '2026-06-02');
      expect(await repository.getCelebrationShownDate(), '2026-06-02');
    });

    test('clearGoalNotificationShownDateIfMatches only clears matching day', () async {
      await repository.setGoalNotificationShownDate('2026-06-02');
      await repository.clearGoalNotificationShownDateIfMatches('2026-06-01');
      expect(await repository.getGoalNotificationShownDate(), '2026-06-02');
      await repository.clearGoalNotificationShownDateIfMatches('2026-06-02');
      expect(await repository.getGoalNotificationShownDate(), isNull);
    });

    test('display name is null when unset', () async {
      expect(await repository.getDisplayName(), isNull);
    });

    test('round-trips display name', () async {
      await repository.setDisplayName('Alex');
      expect(await repository.getDisplayName(), 'Alex');
    });

    test('trims display name on write and read', () async {
      await repository.setDisplayName('  Sam  ');
      expect(await repository.getDisplayName(), 'Sam');
    });

    test('clears display name when empty or whitespace-only', () async {
      await repository.setDisplayName('Alex');
      await repository.setDisplayName('');
      expect(await repository.getDisplayName(), isNull);

      await repository.setDisplayName('Alex');
      await repository.setDisplayName('   ');
      expect(await repository.getDisplayName(), isNull);
    });

    test('rejects display name over max length', () async {
      final tooLong = 'a' * (kMaxDisplayNameLength + 1);
      expect(
        () => repository.setDisplayName(tooLong),
        throwsA(isA<ArgumentError>()),
      );
      expect(await repository.getDisplayName(), isNull);
    });

    test('returns null for whitespace-only stored value', () async {
      await db.insert(
        'user_preferences',
        {'key': kDisplayNameKey, 'value': '   '},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      expect(await repository.getDisplayName(), isNull);
    });

    test('goal notifications default to false when absent', () async {
      expect(await repository.getGoalNotificationsEnabled(), isFalse);
    });

    test('isGoalNotificationsPreferenceSet is false when key absent', () async {
      expect(await repository.isGoalNotificationsPreferenceSet(), isFalse);
    });

    test('isGoalNotificationsPreferenceSet is true after write', () async {
      await repository.setGoalNotificationsEnabled(false);
      expect(await repository.isGoalNotificationsPreferenceSet(), isTrue);
    });

    test('round-trips goal notifications flag', () async {
      await repository.setGoalNotificationsEnabled(true);
      expect(await repository.getGoalNotificationsEnabled(), isTrue);
      await repository.setGoalNotificationsEnabled(false);
      expect(await repository.getGoalNotificationsEnabled(), isFalse);
    });

    test('round-trips height in cm', () async {
      await repository.setHeightCm(175);
      expect(await repository.getHeightCm(), 175);
      await repository.setHeightCm(null);
      expect(await repository.getHeightCm(), isNull);
    });

    test('rejects height outside allowed range', () async {
      expect(
        () => repository.setHeightCm(99),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repository.setHeightCm(251),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('round-trips weight in kg with one decimal', () async {
      await repository.setWeightKg(72.5);
      expect(await repository.getWeightKg(), 72.5);
      await repository.setWeightKg(null);
      expect(await repository.getWeightKg(), isNull);
    });

    test('rejects weight outside allowed range', () async {
      expect(
        () => repository.setWeightKg(29.9),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => repository.setWeightKg(300.1),
        throwsA(isA<ArgumentError>()),
      );
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

    test('resolves goal from latest effective row on or before local day', () async {
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
    });

    test('falls back to default goal when no row applies', () async {
      expect(await repository.getGoalForLocalDay('2020-01-01'), kDefaultStepGoal);
    });

    test('getGoalForLocalDay for today matches getDailyStepGoal after write', () async {
      await repository.setDailyStepGoal(8800);
      final todayIso = formatLocalDayIso(clock.snapshot());
      expect(await repository.getGoalForLocalDay(todayIso), 8800);
      expect(await repository.getDailyStepGoal(), 8800);
    });

    test('same-day update does not create second row', () async {
      await repository.setDailyStepGoal(9000);
      await repository.setDailyStepGoal(9500);

      final rows = await db.query('daily_goal_effective');
      expect(rows.length, 1);
      expect(rows.single['goal'], 9500);
      expect(rows.single['effective_from_local_day'], '2026-06-11');
      expect(await repository.getDailyStepGoal(), 9500);
    });

    test('new calendar day insert creates new row', () async {
      await repository.setDailyStepGoal(8000);
      clock.setNowUtc(DateTime.utc(2026, 6, 12, 10));

      await repository.setDailyStepGoal(8000);

      final rows = await db.query(
        'daily_goal_effective',
        orderBy: 'effective_from_local_day',
      );
      expect(rows.length, 2);
      expect(rows[0]['effective_from_local_day'], '2026-06-11');
      expect(rows[1]['effective_from_local_day'], '2026-06-12');
      expect(rows[0]['goal'], 8000);
      expect(rows[1]['goal'], 8000);
    });

    test('rejects non-positive goal on journal write', () async {
      expect(
        () => repository.setDailyStepGoal(-1),
        throwsA(isA<ArgumentError>()),
      );
      expect(await db.query('daily_goal_effective'), isEmpty);
    });
  });
}
