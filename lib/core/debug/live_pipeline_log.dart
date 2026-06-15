import 'package:flutter/foundation.dart';

/// Debug-only structured logs for the Today live step pipeline.
///
/// Visible in `flutter run` / `adb logcat` when [enabled] is true.
/// Filter terminal output with: `[ASTRA:LIVE]`
const kLivePipelineLogTag = '[ASTRA:LIVE]';

/// Override at build time: `--dart-define=ASTRA_LIVE_LOG=true`
const bool _kLiveLogDefine = bool.fromEnvironment(
  'ASTRA_LIVE_LOG',
  defaultValue: false,
);

/// Test hook: force logging off regardless of kDebugMode and ASTRA_LIVE_LOG.
@visibleForTesting
bool livePipelineLogForceDisabled = false;

/// Test hook: force logging on regardless of ASTRA_LIVE_LOG dart-define.
@visibleForTesting
bool livePipelineLogForceEnabled = false;

bool get livePipelineLogEnabled =>
    (kDebugMode && _kLiveLogDefine || livePipelineLogForceEnabled) &&
    !livePipelineLogForceDisabled;

final Map<String, DateTime> _lastLoggedAt = {};

/// Logs a pipeline event. [phase] is a short subsystem id (app, monitor, cubit, ring).
void livePipelineLog(
  String phase,
  String message, {
  Map<String, Object?> details = const {},
  Duration minInterval = Duration.zero,
}) {
  if (!livePipelineLogEnabled) {
    return;
  }

  final throttleKey = '$phase::$message';
  if (minInterval > Duration.zero) {
    final last = _lastLoggedAt[throttleKey];
    final now = DateTime.now();
    if (last != null && now.difference(last) < minInterval) {
      return;
    }
    _lastLoggedAt[throttleKey] = now;
  }

  final detailText = details.isEmpty
      ? ''
      : ' ${details.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
  debugPrint('$kLivePipelineLogTag $phase: $message$detailText');
}

@visibleForTesting
void resetLivePipelineLogThrottleForTests() {
  _lastLoggedAt.clear();
}
