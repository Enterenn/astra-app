import 'package:flutter/foundation.dart';

/// Safety net: persist at least this often during continuous walking.
const kMaxPersistStaleness = Duration(minutes: 5);

/// One-shot phone read after unlock when the live buffer had no pocket events.
const kResumePhoneCatchUpTimeout = Duration(seconds: 8);

/// Whether the staleness fallback should run a persist cycle.
///
/// Exported for unit tests via [app_lifecycle_coordinator.dart] / `app.dart`.
bool shouldTriggerStalenessPersist({
  required DateTime? lastPersistAt,
  required DateTime now,
  required Duration maxStaleness,
}) {
  return lastPersistAt == null ||
      now.difference(lastPersistAt) >= maxStaleness;
}

/// Whether resume should stop the monitor briefly for a one-shot phone peek.
///
/// Exported for unit tests via [app_lifecycle_coordinator.dart] / `app.dart`.
bool shouldRunResumePhoneCatchUp({
  required bool persistedNewSteps,
  required int upsertedFromDrain,
  required bool monitorAheadOfDb,
  required Duration pauseDuration,
  required Duration minPauseForPhoneCatchUp,
}) {
  return !persistedNewSteps &&
      upsertedFromDrain == 0 &&
      !monitorAheadOfDb &&
      pauseDuration >= minPauseForPhoneCatchUp;
}

/// Serializes lifecycle pause/resume handlers so foreground recovery cannot
/// race background persist. Extracted for fast unit tests (Story 14-2).
///
/// Exported for unit tests via [app_lifecycle_coordinator.dart] / `app.dart`.
Future<void> runSerializedLifecycleTransition({
  required Future<void>? Function() readInFlight,
  required void Function(Future<void>?) writeInFlight,
  required Future<void> Function() operation,
}) async {
  while (readInFlight() != null) {
    try {
      await readInFlight();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'AppLifecycleCoordinator._enqueueLifecycleTransition: prior transition failed: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  late final Future<void> transition;
  transition = operation();
  writeInFlight(transition);
  try {
    await transition;
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint(
        'AppLifecycleCoordinator._enqueueLifecycleTransition: transition failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  } finally {
    if (readInFlight() == transition) {
      writeInFlight(null);
    }
  }
}

/// Whether resume should briefly stop the monitor for a one-shot phone peek.
///
/// Skips the destructive stop/peek cycle when background collection (pause
/// persist and/or FGS) already advanced SQLite during the lock — the Fairphone
/// long-walk scenario where peek would aggravate a zombie subscription.
///
/// Exported for unit tests via [app_lifecycle_coordinator.dart] / `app.dart`.
bool shouldRunResumePhonePeek({
  required bool likelyPocketWalk,
  required int stepsBeforeResumeCollect,
  required int? stepsAtBackground,
}) {
  if (!likelyPocketWalk) {
    return false;
  }
  if (stepsAtBackground != null &&
      stepsBeforeResumeCollect > stepsAtBackground) {
    return false;
  }
  return true;
}
