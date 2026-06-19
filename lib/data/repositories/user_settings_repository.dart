import 'package:sqflite/sqflite.dart';

import '../../core/constants/astra_accent_preset.dart';
import '../../core/constants/display_unit_preferences.dart';
import '../../core/constants/preference_keys.dart';
import '../../core/database/astra_database_session.dart';
import '../../core/time/timestamp_codec.dart';
import '../../presentation/cubits/theme_state.dart';
import '../contracts/user_settings_repository_contract.dart';
import '_user_preferences_kv_store.dart';

/// Settings, display units, notifications, onboarding, and GoalRing display persistence.
class UserSettingsRepository implements UserSettingsRepositoryContract {
  UserSettingsRepository(
    Object sessionOrDatabase, {
    String databasePath = inMemoryDatabasePath,
  }) : _kv = UserPreferencesKvStore(
         sessionOrDatabase is AstraDatabaseSession
             ? sessionOrDatabase
             : AstraDatabaseSession(
                 databasePath: databasePath,
                 initial: sessionOrDatabase as Database,
               ),
       );

  final UserPreferencesKvStore _kv;
  Future<void> _lastDisplayedWriteChain = Future<void>.value();

  @override
  bool get isDatabaseOpen => _kv.isDatabaseOpen;

  Future<void> _runSerializedLastDisplayedWrite(
    Future<void> Function() write,
  ) {
    final run = _lastDisplayedWriteChain.then((_) => write());
    _lastDisplayedWriteChain = run.catchError((_) {});
    return run;
  }

  Future<AstraThemePreference> getThemeMode() async {
    final value = await _kv.readValue(kThemeModeKey);
    return _parseThemeMode(value);
  }

  @override
  Future<void> setThemeMode(AstraThemePreference preference) async {
    final encoded = switch (preference) {
      AstraThemePreference.light => 'light',
      AstraThemePreference.dark => 'dark',
      AstraThemePreference.system => 'system',
    };
    await _kv.writeValue(kThemeModeKey, encoded);
  }

  Future<AstraAccentPreset> getAccentPreset() async {
    final value = await _kv.readValue(kAccentPresetKey);
    return parseAccentPreset(value);
  }

  @override
  Future<void> setAccentPreset(AstraAccentPreset preset) async {
    await _kv.writeValue(kAccentPresetKey, accentPresetToStorage(preset));
  }

  Future<bool> getOnboardingComplete() async {
    final value = await _kv.readValue(kOnboardingCompleteKey);
    return value == 'true';
  }

  @override
  Future<void> setOnboardingComplete(bool complete) async {
    await _kv.writeValue(kOnboardingCompleteKey, complete ? 'true' : 'false');
  }

  Future<bool> isGoalNotificationsPreferenceSet() async {
    return (await _kv.readValue(kGoalNotificationsEnabledKey)) != null;
  }

  @override
  Future<bool> getGoalNotificationsEnabled() async {
    final value = await _kv.readValue(kGoalNotificationsEnabledKey);
    return value == 'true';
  }

  @override
  Future<void> setGoalNotificationsEnabled(bool enabled) async {
    await _kv.writeValue(
      kGoalNotificationsEnabledKey,
      enabled ? 'true' : 'false',
    );
  }

  Future<DistanceDisplayUnit> getDistanceDisplayUnit() async {
    final value = await _kv.readValue(kDistanceDisplayUnitKey);
    return parseDistanceDisplayUnit(value);
  }

  @override
  Future<void> setDistanceDisplayUnit(DistanceDisplayUnit unit) async {
    await _kv.writeValue(kDistanceDisplayUnitKey, unit.storageValue);
  }

  Future<WeightDisplayUnit> getWeightDisplayUnit() async {
    final value = await _kv.readValue(kWeightDisplayUnitKey);
    return parseWeightDisplayUnit(value);
  }

  @override
  Future<void> setWeightDisplayUnit(WeightDisplayUnit unit) async {
    await _kv.writeValue(kWeightDisplayUnitKey, unit.storageValue);
  }

  Future<HeightDisplayUnit> getHeightDisplayUnit() async {
    final value = await _kv.readValue(kHeightDisplayUnitKey);
    return parseHeightDisplayUnit(value);
  }

  @override
  Future<void> setHeightDisplayUnit(HeightDisplayUnit unit) async {
    await _kv.writeValue(kHeightDisplayUnitKey, unit.storageValue);
  }

  Future<String?> getCelebrationShownDate() async {
    return _kv.readValue(kCelebrationShownDateKey);
  }

  Future<void> setCelebrationShownDate(String localDayIso) async {
    await _kv.writeValue(kCelebrationShownDateKey, localDayIso);
  }

  Future<String?> getGoalNotificationShownDate() async {
    return _kv.readValue(kGoalNotificationShownDateKey);
  }

  Future<void> setGoalNotificationShownDate(String localDayIso) async {
    await _kv.writeValue(kGoalNotificationShownDateKey, localDayIso);
  }

  Future<void> clearGoalNotificationShownDateIfMatches(String localDayIso) async {
    final current = await getGoalNotificationShownDate();
    if (current == localDayIso) {
      await _kv.deleteValue(kGoalNotificationShownDateKey);
    }
  }

  Future<bool> tryClaimGoalNotificationShownDate(String localDayIso) async {
    return _kv.session.withRetry(
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

  @override
  Future<int?> getLastDisplayedSteps(String localDayIso) async {
    final storedDay = await _kv.readValue(kLastDisplayedStepsLocalDayKey);
    if (storedDay != localDayIso) {
      return null;
    }
    final value = await _kv.readValue(kLastDisplayedStepsKey);
    return int.tryParse(value ?? '');
  }

  @override
  Future<void> setLastDisplayedSteps({
    required String localDayIso,
    required int steps,
  }) async {
    if (steps < 0) {
      throw ArgumentError.value(steps, 'steps', 'must be non-negative');
    }
    await _runSerializedLastDisplayedWrite(() async {
      await _kv.session.withRetry((db) async {
        final batch = db.batch();
        batch.insert(
          'user_preferences',
          {'key': kLastDisplayedStepsLocalDayKey, 'value': localDayIso},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        batch.insert(
          'user_preferences',
          {'key': kLastDisplayedStepsKey, 'value': steps.toString()},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await batch.commit(noResult: true);
      });
    });
  }

  Future<void> clearLastDisplayedSteps() async {
    await _runSerializedLastDisplayedWrite(() async {
      await _kv.session.withRetry((db) async {
        final batch = db.batch();
        batch.delete(
          'user_preferences',
          where: 'key = ?',
          whereArgs: [kLastDisplayedStepsKey],
        );
        batch.delete(
          'user_preferences',
          where: 'key = ?',
          whereArgs: [kLastDisplayedStepsLocalDayKey],
        );
        await batch.commit(noResult: true);
      });
    });
  }

  @override
  Future<DateTime?> getLastDatabaseOptimizedAt() async {
    final value = await _kv.readValue(kLastDatabaseOptimizedAtKey);
    if (value == null) {
      return null;
    }
    return TimestampCodec.parseUtc(value);
  }

  Future<void> setLastDatabaseOptimizedAt(DateTime optimizedAtUtc) async {
    await _kv.writeValue(
      kLastDatabaseOptimizedAtKey,
      TimestampCodec.formatUtc(optimizedAtUtc.toUtc()),
    );
  }

  @override
  Future<bool> tryClaimCelebrationShownDate(String localDayIso) async {
    return _kv.session.withRetry(
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

  AstraThemePreference _parseThemeMode(String? raw) => switch (raw) {
    'light' => AstraThemePreference.light,
    'dark' => AstraThemePreference.dark,
    _ => AstraThemePreference.system,
  };
}
