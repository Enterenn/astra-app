import 'package:astra_app/core/constants/preference_keys.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/repositories/user_health_metrics_repository.dart';
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

  group('UserHealthMetricsRepository', () {
    late Database db;
    late UserHealthMetricsRepository repository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      repository = UserHealthMetricsRepository(db);
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

      final freshDb = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      addTearDown(freshDb.close);
      final freshRepo = UserHealthMetricsRepository(freshDb);
      expect(
        await freshRepo.getGoalForLocalDay(todayIso),
        await freshRepo.getDailyStepGoal(),
      );

      expect(
        () => repository.setDailyStepGoal(0),
        throwsA(isA<ArgumentError>()),
      );

      await db.insert(
        'user_preferences',
        {'key': kDailyStepGoalKey, 'value': '-1'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      expect(await repository.getDailyStepGoal(), kDefaultStepGoal);
    });

    test('display name: null default, round-trips, trims, clears when empty/whitespace, rejects over max length, null for stored whitespace', () async {
      expect(await repository.getDisplayName(), isNull);

      await repository.setDisplayName('Alex');
      expect(await repository.getDisplayName(), 'Alex');

      await repository.setDisplayName('  Sam  ');
      expect(await repository.getDisplayName(), 'Sam');

      await repository.setDisplayName('Alex');
      await repository.setDisplayName('');
      expect(await repository.getDisplayName(), isNull);

      await repository.setDisplayName('Alex');
      await repository.setDisplayName('   ');
      expect(await repository.getDisplayName(), isNull);

      await db.insert(
        'user_preferences',
        {'key': kDisplayNameKey, 'value': '   '},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      expect(await repository.getDisplayName(), isNull);

      final tooLong = 'a' * (kMaxDisplayNameLength + 1);
      expect(
        () => repository.setDisplayName(tooLong),
        throwsA(isA<ArgumentError>()),
      );
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

  group('UserHealthMetricsRepository daily goal history', () {
    late Database db;
    late FakeTimeProvider clock;
    late UserHealthMetricsRepository repository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      await db.delete('daily_goal_effective');
      clock = FakeTimeProvider(
        fixedNowUtc: DateTime.utc(2026, 6, 11, 10),
        zoneOffset: const Duration(hours: 2),
      );
      repository = UserHealthMetricsRepository(db, clock: clock);
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

      expect(await repository.getGoalForLocalDay('2020-01-01'), kDefaultStepGoal);

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

      final fallback = await repository.getGoalsForLocalDays(['2020-01-01']);
      expect(fallback['2020-01-01'], kDefaultStepGoal);

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

      expect(
        () => repository.setDailyStepGoal(-1),
        throwsA(isA<ArgumentError>()),
      );
      expect(await db.query('daily_goal_effective'), hasLength(2));
    });
  });
}
