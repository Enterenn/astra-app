import 'package:flutter/foundation.dart';

/// Debug-only structured logs for FR11 downsampling / compaction.
///
/// Filter terminal output with: `[ASTRA:COMPACT]`
const kCompactionLogTag = '[ASTRA:COMPACT]';

/// Override at build time: `--dart-define=ASTRA_COMPACTION_LOG=true`
const bool _kCompactionLogDefine = bool.fromEnvironment(
  'ASTRA_COMPACTION_LOG',
  defaultValue: false,
);

@visibleForTesting
bool compactionLogForceDisabled = false;

@visibleForTesting
bool compactionLogForceEnabled = false;

bool get compactionLogEnabled =>
    (kDebugMode && _kCompactionLogDefine || compactionLogForceEnabled) &&
    !compactionLogForceDisabled;

void compactionLog(
  String phase,
  String message, {
  Map<String, Object?> details = const {},
}) {
  if (!compactionLogEnabled) {
    return;
  }

  final detailText = details.isEmpty
      ? ''
      : ' ${details.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
  debugPrint('$kCompactionLogTag $phase: $message$detailText');
}
