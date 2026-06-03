import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/repositories/user_preferences_repository.dart';
import 'package:astra_app/presentation/cubits/theme_state.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}
