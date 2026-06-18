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

  /// Ingestion row id — provider/device suffix when multiple sources share a start window.
  static String deterministicFromIngestionBucket({
    required DateTime startTimeUtc,
    required String provider,
    required String deviceId,
  }) {
    final identity = '$provider$deviceId'.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '${deterministicFromStartUtc(startTimeUtc)}-$identity';
  }
}
