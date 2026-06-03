import 'package:sqflite/sqflite.dart';

import '../../core/constants/preference_keys.dart';
import '../../core/time/timestamp_codec.dart';
import '../../presentation/cubits/theme_state.dart';

/// Sole writer to the `user_preferences` table.
class UserPreferencesRepository {
  UserPreferencesRepository(this._db);

  final Database _db;

  Future<int> getDailyStepGoal() async {
    final value = await _readValue(kDailyStepGoalKey);
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) {
      return kDefaultStepGoal;
    }
    return parsed;
  }

  Future<void> setDailyStepGoal(int goal) async {
    if (goal <= 0) {
      throw ArgumentError.value(goal, 'goal', 'must be a positive integer');
    }
    await _writeValue(kDailyStepGoalKey, goal.toString());
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

  Future<bool> getOnboardingComplete() async {
    final value = await _readValue(kOnboardingCompleteKey);
    return value == 'true';
  }

  Future<void> setOnboardingComplete(bool complete) async {
    await _writeValue(kOnboardingCompleteKey, complete ? 'true' : 'false');
  }

  /// Local calendar day (`YYYY-MM-DD`) when goal celebration was last shown.
  Future<String?> getCelebrationShownDate() async {
    return _readValue(kCelebrationShownDateKey);
  }

  Future<void> setCelebrationShownDate(String localDayIso) async {
    await _writeValue(kCelebrationShownDateKey, localDayIso);
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
  /// Returns `true` when this caller claimed the day (notification or
  /// celebration may proceed). Returns `false` when today was already claimed.
  Future<bool> tryClaimCelebrationShownDate(String localDayIso) async {
    return _db.transaction((txn) async {
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
    });
  }

  Future<String?> _readValue(String key) async {
    final rows = await _db.query(
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
  }

  Future<void> _writeValue(String key, String value) async {
    await _db.insert(
      'user_preferences',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  AstraThemePreference _parseThemeMode(String? raw) => switch (raw) {
    'light' => AstraThemePreference.light,
    'dark' => AstraThemePreference.dark,
    _ => AstraThemePreference.system,
  };
}
