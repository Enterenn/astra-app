import 'package:sqflite/sqflite.dart';

import '../../core/constants/astra_accent_preset.dart';
import '../../core/constants/display_unit_preferences.dart';
import '../../core/constants/preference_keys.dart';
import '../../core/database/astra_database_session.dart';
import '../../core/time/local_day_formatter.dart';
import '../../core/time/system_time_provider.dart';
import '../../core/time/time_provider.dart';
import '../../core/time/timestamp_codec.dart';
import '../../presentation/cubits/theme_state.dart';
import '../contracts/user_preferences_repository_contract.dart';

/// Sole writer to the `user_preferences` table.
class UserPreferencesRepository implements UserPreferencesRepositoryContract {
  UserPreferencesRepository(
    Object sessionOrDatabase, {
    String databasePath = inMemoryDatabasePath,
    TimeProvider? clock,
  }) : _session = sessionOrDatabase is AstraDatabaseSession
           ? sessionOrDatabase
           : AstraDatabaseSession(
               databasePath: databasePath,
               initial: sessionOrDatabase as Database,
             ),
       _clock = clock ?? const SystemTimeProvider();

  final AstraDatabaseSession _session;
  final TimeProvider _clock;

  bool get isDatabaseOpen => _session.database.isOpen;

  Future<int> getDailyStepGoal() async {
    final value = await _readValue(kDailyStepGoalKey);
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) {
      return kDefaultStepGoal;
    }
    return parsed;
  }

  /// Resolves the step goal effective on [localDayIso] (`YYYY-MM-DD`).
  ///
  /// Returns the latest journal row where `effective_from_local_day ≤ localDayIso`,
  /// or [kDefaultStepGoal] when no row applies.
  Future<int> getGoalForLocalDay(String localDayIso) async {
    return _session.withRetry((db) async {
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

  /// Resolves step goals for multiple local days (`YYYY-MM-DD`) in one SQL round-trip.
  ///
  /// Returns a map keyed by each requested ISO day. Semantics match [getGoalForLocalDay]
  /// for every day in [localDayIsos].
  Future<Map<String, int>> getGoalsForLocalDays(
    List<String> localDayIsos,
  ) async {
    final days = localDayIsos.toSet().toList()..sort();
    if (days.isEmpty) {
      return const {};
    }

    return _session.withRetry((db) async {
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

  Future<void> setDailyStepGoal(int goal) async {
    if (goal <= 0) {
      throw ArgumentError.value(goal, 'goal', 'must be a positive integer');
    }
    final todayIso = formatLocalDayIso(_clock.snapshot());
    await _session.withRetry(
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

  Future<AstraThemePreference> getThemeMode() async {
    final value = await _readValue(kThemeModeKey);
    return _parseThemeMode(value);
  }

  Future<void> setThemeMode(AstraThemePreference preference) async {
    final encoded = switch (preference) {
      AstraThemePreference.light => 'light',
      AstraThemePreference.dark => 'dark',
      AstraThemePreference.system => 'system',
    };
    await _writeValue(kThemeModeKey, encoded);
  }

  Future<AstraAccentPreset> getAccentPreset() async {
    final value = await _readValue(kAccentPresetKey);
    return parseAccentPreset(value);
  }

  Future<void> setAccentPreset(AstraAccentPreset preset) async {
    await _writeValue(kAccentPresetKey, accentPresetToStorage(preset));
  }

  Future<bool> getOnboardingComplete() async {
    final value = await _readValue(kOnboardingCompleteKey);
    return value == 'true';
  }

  Future<void> setOnboardingComplete(bool complete) async {
    await _writeValue(kOnboardingCompleteKey, complete ? 'true' : 'false');
  }

  /// Optional first name for Today greeting; null when unset or blank after trim.
  Future<String?> getDisplayName() async {
    final value = await _readValue(kDisplayNameKey);
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<int?> getHeightCm() async {
    final value = await _readValue(kHeightCmKey);
    if (value == null) {
      return null;
    }
    return int.tryParse(value);
  }

  Future<void> setHeightCm(int? heightCm) async {
    if (heightCm == null) {
      await _deleteValue(kHeightCmKey);
      return;
    }
    if (heightCm < kMinHeightCm || heightCm > kMaxHeightCm) {
      throw ArgumentError.value(
        heightCm,
        'heightCm',
        'must be between $kMinHeightCm and $kMaxHeightCm',
      );
    }
    await _writeValue(kHeightCmKey, heightCm.toString());
  }

  Future<double?> getWeightKg() async {
    final value = await _readValue(kWeightKgKey);
    if (value == null) {
      return null;
    }
    return double.tryParse(value);
  }

  Future<void> setWeightKg(double? weightKg) async {
    if (weightKg == null) {
      await _deleteValue(kWeightKgKey);
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
    await _writeValue(kWeightKgKey, rounded.toString());
  }

  Future<bool> isGoalNotificationsPreferenceSet() async {
    return (await _readValue(kGoalNotificationsEnabledKey)) != null;
  }

  Future<bool> getGoalNotificationsEnabled() async {
    final value = await _readValue(kGoalNotificationsEnabledKey);
    return value == 'true';
  }

  Future<void> setGoalNotificationsEnabled(bool enabled) async {
    await _writeValue(
      kGoalNotificationsEnabledKey,
      enabled ? 'true' : 'false',
    );
  }

  Future<DistanceDisplayUnit> getDistanceDisplayUnit() async {
    final value = await _readValue(kDistanceDisplayUnitKey);
    return parseDistanceDisplayUnit(value);
  }

  Future<void> setDistanceDisplayUnit(DistanceDisplayUnit unit) async {
    await _writeValue(kDistanceDisplayUnitKey, unit.storageValue);
  }

  Future<WeightDisplayUnit> getWeightDisplayUnit() async {
    final value = await _readValue(kWeightDisplayUnitKey);
    return parseWeightDisplayUnit(value);
  }

  Future<void> setWeightDisplayUnit(WeightDisplayUnit unit) async {
    await _writeValue(kWeightDisplayUnitKey, unit.storageValue);
  }

  Future<HeightDisplayUnit> getHeightDisplayUnit() async {
    final value = await _readValue(kHeightDisplayUnitKey);
    return parseHeightDisplayUnit(value);
  }

  Future<void> setHeightDisplayUnit(HeightDisplayUnit unit) async {
    await _writeValue(kHeightDisplayUnitKey, unit.storageValue);
  }

  Future<void> setDisplayName(String? name) async {
    if (name == null) {
      await _deleteValue(kDisplayNameKey);
      return;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      await _deleteValue(kDisplayNameKey);
      return;
    }
    if (trimmed.length > kMaxDisplayNameLength) {
      throw ArgumentError.value(
        name,
        'name',
        'must be at most $kMaxDisplayNameLength characters',
      );
    }
    await _writeValue(kDisplayNameKey, trimmed);
  }

  /// Local calendar day (`YYYY-MM-DD`) when goal celebration was last shown.
  Future<String?> getCelebrationShownDate() async {
    return _readValue(kCelebrationShownDateKey);
  }

  Future<void> setCelebrationShownDate(String localDayIso) async {
    await _writeValue(kCelebrationShownDateKey, localDayIso);
  }

  /// Local calendar day when the goal local notification was last shown (FR-25).
  Future<String?> getGoalNotificationShownDate() async {
    return _readValue(kGoalNotificationShownDateKey);
  }

  Future<void> setGoalNotificationShownDate(String localDayIso) async {
    await _writeValue(kGoalNotificationShownDateKey, localDayIso);
  }

  /// Clears notification dedup when [showGoalReached] fails after an optimistic claim.
  Future<void> clearGoalNotificationShownDateIfMatches(String localDayIso) async {
    final current = await getGoalNotificationShownDate();
    if (current == localDayIso) {
      await _deleteValue(kGoalNotificationShownDateKey);
    }
  }

  /// Atomically records [localDayIso] for goal notification dedup (separate from celebration).
  Future<bool> tryClaimGoalNotificationShownDate(String localDayIso) async {
    return _session.withRetry(
      (db) => db.transaction((txn) async {
        final rows = await txn.query(
          'user_preferences',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: [kGoalNotificationShownDateKey],
          limit: 1,
        );
        final current = rows.isEmpty ? null : rows.first['value'] as String?;
        if (current == localDayIso) {
          return false;
        }
        await txn.insert(
          'user_preferences',
          {'key': kGoalNotificationShownDateKey, 'value': localDayIso},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return true;
      }),
    );
  }

  /// Last step count displayed on Today for the given local day, or null when unset.
  Future<int?> getLastDisplayedSteps(String localDayIso) async {
    final storedDay = await _readValue(kLastDisplayedStepsLocalDayKey);
    if (storedDay != localDayIso) {
      return null;
    }
    final value = await _readValue(kLastDisplayedStepsKey);
    return int.tryParse(value ?? '');
  }

  Future<void> setLastDisplayedSteps({
    required String localDayIso,
    required int steps,
  }) async {
    if (steps < 0) {
      throw ArgumentError.value(steps, 'steps', 'must be non-negative');
    }
    await _writeValue(kLastDisplayedStepsLocalDayKey, localDayIso);
    await _writeValue(kLastDisplayedStepsKey, steps.toString());
  }

  Future<void> clearLastDisplayedSteps() async {
    await _deleteValue(kLastDisplayedStepsKey);
    await _deleteValue(kLastDisplayedStepsLocalDayKey);
  }

  /// UTC instant of the last successful `PRAGMA optimize` / `VACUUM` run.
  Future<DateTime?> getLastDatabaseOptimizedAt() async {
    final value = await _readValue(kLastDatabaseOptimizedAtKey);
    if (value == null) {
      return null;
    }
    return TimestampCodec.parseUtc(value);
  }

  Future<void> setLastDatabaseOptimizedAt(DateTime optimizedAtUtc) async {
    await _writeValue(
      kLastDatabaseOptimizedAtKey,
      TimestampCodec.formatUtc(optimizedAtUtc.toUtc()),
    );
  }

  /// Atomically records [localDayIso] when not already set for that day.
  ///
  /// Returns `true` when this caller claimed the day (celebration may proceed).
  /// Returns `false` when today was already claimed.
  Future<bool> tryClaimCelebrationShownDate(String localDayIso) async {
    return _session.withRetry(
      (db) => db.transaction((txn) async {
        final rows = await txn.query(
          'user_preferences',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: [kCelebrationShownDateKey],
          limit: 1,
        );
        final current = rows.isEmpty ? null : rows.first['value'] as String?;
        if (current == localDayIso) {
          return false;
        }
        await txn.insert(
          'user_preferences',
          {'key': kCelebrationShownDateKey, 'value': localDayIso},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return true;
      }),
    );
  }

  Future<String?> _readValue(String key) {
    return _session.withRetry((db) async {
      final rows = await db.query(
        'user_preferences',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return rows.first['value'] as String?;
    });
  }

  Future<void> _writeValue(String key, String value) {
    return _session.withRetry(
      (db) => db.insert(
        'user_preferences',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      ),
    );
  }

  Future<void> _deleteValue(String key) {
    return _session.withRetry(
      (db) => db.delete(
        'user_preferences',
        where: 'key = ?',
        whereArgs: [key],
      ),
    );
  }

  AstraThemePreference _parseThemeMode(String? raw) => switch (raw) {
    'light' => AstraThemePreference.light,
    'dark' => AstraThemePreference.dark,
    _ => AstraThemePreference.system,
  };

  static int _normalizeJournalGoal(dynamic raw) {
    final parsed = raw is int ? raw : (raw as num).toInt();
    return parsed > 0 ? parsed : kDefaultStepGoal;
  }
}
