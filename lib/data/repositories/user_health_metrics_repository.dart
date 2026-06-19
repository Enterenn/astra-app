import 'package:sqflite/sqflite.dart';

import '../../core/constants/preference_keys.dart';
import '../../core/database/astra_database_session.dart';
import '../../core/time/local_day_formatter.dart';
import '../../core/time/system_time_provider.dart';
import '../../core/time/time_provider.dart';
import '../contracts/user_health_metrics_repository_contract.dart';
import '_user_preferences_kv_store.dart';

/// Body metrics, display name, and daily step goal journal APIs.
class UserHealthMetricsRepository implements UserHealthMetricsRepositoryContract {
  UserHealthMetricsRepository(
    Object sessionOrDatabase, {
    String databasePath = inMemoryDatabasePath,
    TimeProvider? clock,
  }) : _kv = UserPreferencesKvStore(
         sessionOrDatabase is AstraDatabaseSession
             ? sessionOrDatabase
             : AstraDatabaseSession(
                 databasePath: databasePath,
                 initial: sessionOrDatabase as Database,
               ),
       ),
       _clock = clock ?? const SystemTimeProvider();

  final UserPreferencesKvStore _kv;
  final TimeProvider _clock;

  Future<int> getDailyStepGoal() async {
    final value = await _kv.readValue(kDailyStepGoalKey);
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) {
      return kDefaultStepGoal;
    }
    return parsed;
  }

  @override
  Future<int> getGoalForLocalDay(String localDayIso) async {
    return _kv.session.withRetry((db) async {
      final rows = await db.rawQuery(
        '''
        SELECT goal
        FROM daily_goal_effective
        WHERE effective_from_local_day <= ?
        ORDER BY effective_from_local_day DESC
        LIMIT 1
        ''',
        [localDayIso],
      );
      if (rows.isEmpty) {
        return kDefaultStepGoal;
      }
      return _normalizeJournalGoal(rows.first['goal']);
    });
  }

  @override
  Future<Map<String, int>> getGoalsForLocalDays(
    List<String> localDayIsos,
  ) async {
    final days = localDayIsos.toSet().toList()..sort();
    if (days.isEmpty) {
      return const {};
    }

    return _kv.session.withRetry((db) async {
      final rows = await db.rawQuery(
        '''
        SELECT effective_from_local_day, goal
        FROM daily_goal_effective
        WHERE effective_from_local_day <= ?
        ORDER BY effective_from_local_day ASC
        ''',
        [days.last],
      );

      var journalIndex = 0;
      var currentGoal = kDefaultStepGoal;
      final result = <String, int>{};

      for (final day in days) {
        while (journalIndex < rows.length) {
          final effectiveDay =
              rows[journalIndex]['effective_from_local_day'] as String;
          if (effectiveDay.compareTo(day) > 0) {
            break;
          }
          currentGoal = _normalizeJournalGoal(rows[journalIndex]['goal']);
          journalIndex++;
        }
        result[day] = currentGoal;
      }

      return result;
    });
  }

  @override
  Future<void> setDailyStepGoal(int goal) async {
    if (goal <= 0) {
      throw ArgumentError.value(goal, 'goal', 'must be a positive integer');
    }
    final todayIso = formatLocalDayIso(_clock.snapshot());
    await _kv.session.withRetry(
      (db) => db.transaction((txn) async {
        final existing = await txn.query(
          'daily_goal_effective',
          columns: ['effective_from_local_day'],
          where: 'effective_from_local_day = ?',
          whereArgs: [todayIso],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          await txn.update(
            'daily_goal_effective',
            {'goal': goal},
            where: 'effective_from_local_day = ?',
            whereArgs: [todayIso],
          );
        } else {
          await txn.insert(
            'daily_goal_effective',
            {
              'effective_from_local_day': todayIso,
              'goal': goal,
            },
          );
        }
        await txn.insert(
          'user_preferences',
          {'key': kDailyStepGoalKey, 'value': goal.toString()},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }),
    );
  }

  Future<String?> getDisplayName() async {
    final value = await _kv.readValue(kDisplayNameKey);
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<int?> getHeightCm() async {
    final value = await _kv.readValue(kHeightCmKey);
    if (value == null) {
      return null;
    }
    return int.tryParse(value);
  }

  Future<void> setHeightCm(int? heightCm) async {
    if (heightCm == null) {
      await _kv.deleteValue(kHeightCmKey);
      return;
    }
    if (heightCm < kMinHeightCm || heightCm > kMaxHeightCm) {
      throw ArgumentError.value(
        heightCm,
        'heightCm',
        'must be between $kMinHeightCm and $kMaxHeightCm',
      );
    }
    await _kv.writeValue(kHeightCmKey, heightCm.toString());
  }

  @override
  Future<double?> getWeightKg() async {
    final value = await _kv.readValue(kWeightKgKey);
    if (value == null) {
      return null;
    }
    return double.tryParse(value);
  }

  Future<void> setWeightKg(double? weightKg) async {
    if (weightKg == null) {
      await _kv.deleteValue(kWeightKgKey);
      return;
    }
    if (weightKg < kMinWeightKg || weightKg > kMaxWeightKg) {
      throw ArgumentError.value(
        weightKg,
        'weightKg',
        'must be between $kMinWeightKg and $kMaxWeightKg',
      );
    }
    final rounded = (weightKg * 10).round() / 10;
    await _kv.writeValue(kWeightKgKey, rounded.toString());
  }

  @override
  Future<void> setDisplayName(String? name) async {
    if (name == null) {
      await _kv.deleteValue(kDisplayNameKey);
      return;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      await _kv.deleteValue(kDisplayNameKey);
      return;
    }
    if (trimmed.length > kMaxDisplayNameLength) {
      throw ArgumentError.value(
        name,
        'name',
        'must be at most $kMaxDisplayNameLength characters',
      );
    }
    await _kv.writeValue(kDisplayNameKey, trimmed);
  }

  static int _normalizeJournalGoal(dynamic raw) {
    final parsed = raw is int ? raw : (raw as num).toInt();
    return parsed > 0 ? parsed : kDefaultStepGoal;
  }
}
