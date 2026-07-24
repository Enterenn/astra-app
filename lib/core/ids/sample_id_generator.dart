import '../time/time_provider.dart';

/// Local-first sample row id generation (base36 microsecond timestamp).
class SampleIdGenerator {
  SampleIdGenerator(this._clock);

  final TimeProvider _clock;
  int _sequence = 0;

  /// Next runtime id; monotonic sequence suffix when multiple calls share one microsecond.
  String nextId() {
    final micros = _clock.snapshot().nowUtc.microsecondsSinceEpoch;
    final seq = _sequence++;
    final base = micros.toRadixString(36);
    return seq == 0 ? base : '$base-${seq.toRadixString(36)}';
  }

  /// Deterministic id from bucket start time — safe for bulk inserts with unique starts.
  static String deterministicFromStartUtc(DateTime startTimeUtc) =>
      startTimeUtc.toUtc().microsecondsSinceEpoch.toRadixString(36);

  /// Compacted row id — resolution suffix avoids PK clash with finer-tier rows at same start.
  static String deterministicFromMergedBucket({
    required DateTime startTimeUtc,
    required String resolution,
  }) =>
      '${deterministicFromStartUtc(startTimeUtc)}-$resolution';

  /// Ingestion row id — provider/device/type/resolution aligned with [idx_bucket_identity].
  ///
  /// Phase 0 defaults (`steps` + `5min`) keep the legacy suffix-free formula so existing
  /// rows and upsert id preservation stay stable without a migration.
  static String deterministicFromIngestionBucket({
    required DateTime startTimeUtc,
    required String provider,
    required String deviceId,
    required String type,
    required String resolution,
  }) {
    final normalizedProvider = provider.toLowerCase();
    final normalizedDeviceId = deviceId.toLowerCase();
    final identity =
        '$normalizedProvider$normalizedDeviceId'.replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        );
    final startPart = deterministicFromStartUtc(startTimeUtc);
    final normalizedType = type.toLowerCase();
    final normalizedResolution = resolution.toLowerCase();
    if (normalizedType == 'steps' && normalizedResolution == '5min') {
      return '$startPart-$identity';
    }
    return '$startPart-$identity-$normalizedType-$normalizedResolution';
  }
}
