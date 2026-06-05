import 'package:sqflite/sqflite.dart';

import '../../core/constants/astra_accent_preset.dart';
import '../../core/constants/preference_keys.dart';
import '../../core/time/timestamp_codec.dart';
import '../../presentation/cubits/theme_state.dart';

/// Sole writer to the `user_preferences` table.
class UserPreferencesRepository {
  UserPreferencesRepository(this._db);

  final Database _db;

  bool get isDatabaseOpen => _db.isOpen;

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

  Future<void> _deleteValue(String key) async {
    await _db.delete(
      'user_preferences',
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  AstraThemePreference _parseThemeMode(String? raw) => switch (raw) {
    'light' => AstraThemePreference.light,
    'dark' => AstraThemePreference.dark,
    _ => AstraThemePreference.system,
  };
}
