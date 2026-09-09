import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/database/astra_database_session.dart';
import '../../core/time/timestamp_codec.dart';

/// Last credited pedometer cumulative for one ingestion source.
class IngestionBaselineSnapshot {
  const IngestionBaselineSnapshot({
    required this.cumulative,
    this.recordedAtUtc,
  });

  final int cumulative;
  final DateTime? recordedAtUtc;
}

/// Persists the last seen cumulative step counter per ingestion source.
///
/// Used so a single pedometer reading in a short WorkManager window can still
/// produce a delta against the previous run's baseline.
class IngestionBaselineRepository {
  IngestionBaselineRepository(
    Object sessionOrDatabase, {
    String databasePath = inMemoryDatabasePath,
  }) : _session = sessionOrDatabase is AstraDatabaseSession
           ? sessionOrDatabase
           : AstraDatabaseSession(
               databasePath: databasePath,
               initial: sessionOrDatabase as Database,
             );

  final AstraDatabaseSession _session;

  static const baselineKeyPrefix = 'ingestion_baseline/';

  static String _encodeKeySegment(String segment) => Uri.encodeComponent(segment);

  /// Preference key for one ingestion source; segments are URI-encoded so `/`
  /// inside [provider] or [deviceId] cannot collide with the delimiter.
  static String preferenceKey({
    required String provider,
    required String deviceId,
  }) =>
      '$baselineKeyPrefix${_encodeKeySegment(provider)}/${_encodeKeySegment(deviceId)}';

  /// Removes all ingestion baseline keys inside an existing [txn] (purge path).
  static Future<void> clearAllBaselines(Transaction txn) async {
    await txn.delete(
      'user_preferences',
      where: 'key LIKE ?',
      whereArgs: ['$baselineKeyPrefix%'],
    );
  }

  static DateTime secondAlignedUtc(DateTime value) {
    final utc = value.toUtc();
    return DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
    );
  }

  static String encodeSnapshot(IngestionBaselineSnapshot snapshot) {
    final recordedAtUtc = snapshot.recordedAtUtc;
    if (recordedAtUtc == null) {
      return snapshot.cumulative.toString();
    }
    return jsonEncode({
      'v': snapshot.cumulative,
      'at': TimestampCodec.formatUtc(secondAlignedUtc(recordedAtUtc)),
    });
  }

  static IngestionBaselineSnapshot? decodeSnapshot(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final asInt = int.tryParse(raw);
    if (asInt != null) {
      return IngestionBaselineSnapshot(cumulative: asInt);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final cumulative = decoded['v'];
      if (cumulative is! int) {
        return null;
      }
      DateTime? recordedAtUtc;
      final at = decoded['at'];
      if (at is String) {
        try {
          recordedAtUtc = TimestampCodec.parseUtc(at);
        } on FormatException {
          recordedAtUtc = null;
        }
      }
      return IngestionBaselineSnapshot(
        cumulative: cumulative,
        recordedAtUtc: recordedAtUtc,
      );
    } on FormatException {
      return null;
    }
  }

  Future<int?> getBaseline({
    required String provider,
    required String deviceId,
  }) async {
    final snapshot = await getBaselineSnapshot(
      provider: provider,
      deviceId: deviceId,
    );
    return snapshot?.cumulative;
  }

  Future<IngestionBaselineSnapshot?> getBaselineSnapshot({
    required String provider,
    required String deviceId,
  }) {
    return _session.withRetry((db) async {
      final rows = await db.query(
        'user_preferences',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [preferenceKey(provider: provider, deviceId: deviceId)],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return decodeSnapshot(rows.first['value'] as String?);
    });
  }

  Future<void> setBaseline({
    required String provider,
    required String deviceId,
    required int cumulative,
    DateTime? recordedAtUtc,
    Transaction? txn,
  }) async {
    if (cumulative < 0) {
      throw ArgumentError.value(cumulative, 'cumulative', 'must be non-negative');
    }
    final row = {
      'key': preferenceKey(provider: provider, deviceId: deviceId),
      'value': encodeSnapshot(
        IngestionBaselineSnapshot(
          cumulative: cumulative,
          recordedAtUtc: recordedAtUtc ?? DateTime.now().toUtc(),
        ),
      ),
    };
    if (txn != null) {
      await txn.insert(
        'user_preferences',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }
    await _session.withRetry(
      (db) => db.insert(
        'user_preferences',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      ),
    );
  }
}
