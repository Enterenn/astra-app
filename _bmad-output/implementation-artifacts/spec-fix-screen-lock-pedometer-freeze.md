---
title: 'Fix pedometer freeze after screen lock'
type: 'bugfix'
created: '2026-06-05'
status: 'done'
baseline_commit: '164cd591af4957c9ddc49587dd4db19359ef00f0'
context:
  - '_bmad-output/implementation-artifacts/spec-step-lifecycle-hardening.md'
  - '_bmad-output/implementation-artifacts/stories/6-3-activity-idle-persist-flush.md'
  - '_bmad-output/planning-artifacts/architecture.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Field test (2026-06-05): steps count live correctly on open, but after locking the screen and walking several minutes, unlocking shows no step increase and live updates stop. Only killing and reopening the app recovers.

**Approach:** Serialize app lifecycle transitions so background `stop()` and foreground `restart()` cannot race, always recover the live pipeline on resume (unconditional `restart()` + cubit re-attach), and add regression tests for screen-lock and rapid pause/resume scenarios.

## Boundaries & Constraints

**Always:**
- Only `BackgroundCollector` writes step buckets to SQLite.
- `LiveStepMonitor` remains sole `Pedometer.stepCountStream` owner while UI is foreground-active.
- Reconcile protocol unchanged: pause delta → collectOnce → reconcileFromDatabase → resume delta.
- Monotonic display: UI step count never decreases within the local day.
- FGS handoff on pause unchanged (stop monitor → start FGS).

**Ask First:**
- Adding a second concurrent pedometer subscription.
- Changing FGS collection interval or native service architecture.

**Never:**
- Writing buckets from monitor or cubit.
- Removing pause persist or FGS background collection.
- OEM-specific sensor workarounds in this fix.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| SCREEN_LOCK_WALK | App open, live steps flowing, screen locked, user walks 3+ min, unlock | Today shows steps ≥ pre-lock + walk delta; live stream resumes incrementing | Log persist/restart errors; still attempt bind + sync |
| RAPID_PAUSE_RESUME | `paused` then `resumed` before `_onAppBackgrounded` completes | Monitor restarted; cubit re-attached; live updates work | Serialized lifecycle prevents zombie stopped state |
| ZOMBIE_RUNNING | `monitor.isRunning == true` but platform stream silent after screen-off | Resume still calls `restart()` and re-attaches cubit | N/A |
| FGS_HANDOFF | Steps collected by FGS while screen off | Resume persist + reconcile reflects SQLite total in UI | Existing persist error logging |
| NO_PERMISSION | Activity recognition denied | No monitor restart; existing no-permission UI | Unchanged |

</frozen-after-approval>

## Code Map

- `lib/app.dart` -- lifecycle observer; serialize `_onAppBackgrounded` / `_onAppForegrounded`; unconditional resume recovery via `_bindLiveMonitorToToday()`
- `lib/core/services/live_step_monitor.dart` -- `restart()` already exists; no API change expected
- `lib/presentation/cubits/today_cubit.dart` -- `attachLiveMonitor` re-subscription on resume
- `test/app_live_pipeline_lifecycle_test.dart` -- regression: rapid pause/resume race + post-resume live increment
- `_bmad-output/implementation-artifacts/sprint-status.yaml` -- register story `6-4-screen-lock-pedometer-freeze` under epic-6

## Tasks & Acceptance

**Execution:**
- [x] `lib/app.dart` -- add `_lifecycleTransitionInFlight` mutex so pause/resume handlers run strictly sequentially (await prior transition before next) -- prevents resume skipping `restart()` while background `stop()` is in flight
- [x] `lib/app.dart` -- on foreground: after FGS stop and persist cycle, call `_bindLiveMonitorToToday()` (or equivalent) with unconditional `monitor.restart()` when `_livePipelineStarted` -- recovers frozen stream and re-attaches cubit subscription
- [x] `test/app_live_pipeline_lifecycle_test.dart` -- add test: emit steps → paused → resumed before background `stop()` completes (simulated delay) → new events still update cubit -- regression for race
- [x] `test/app_live_pipeline_lifecycle_test.dart` -- add test: after resume with monitor left `isRunning`, forced restart path still delivers live increments -- zombie-running guard
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- add `6-4-screen-lock-pedometer-freeze: in-progress` under epic-6 (reopen epic-6)

**Acceptance Criteria:**
- Given the app is open with live steps incrementing, when the user locks the screen, walks several minutes, and unlocks, then Today shows accumulated steps and live counting resumes without killing the app
- Given `paused` and `resumed` fire in quick succession, when lifecycle handlers run, then the live monitor is running and the cubit receives post-resume step events
- Given `flutter test test/app_live_pipeline_lifecycle_test.dart` and `flutter analyze`, when run after the fix, then all tests pass with no new analyzer issues

## Design Notes

Current resume path in `_collectAndRefreshToday` only calls `monitor.restart()` when `!monitor.isRunning`. Two failure modes:

1. **Race:** `_onAppBackgrounded` and `_onAppForegrounded` are both `unawaited`. Resume can observe `isRunning == true`, skip restart, then background `stop()` completes — monitor left stopped with a dead subscription.
2. **Zombie running:** If `paused` is delayed or the OS suspends the sensor while `_running` stays true, conditional restart never runs.

Kill/reopen works because `_bindLiveMonitorToToday()` always runs on cold attach. Resume must mirror that path.

```dart
// Target resume sequence (conceptual)
await _enqueueLifecycleTransition(() async {
  await stopFgs();
  await setUiActive(true);
  await persistAndSync();
  if (_livePipelineStarted) {
    await monitor.restart();
    await _bindLiveMonitorToToday();
  }
});
```

## Verification

**Commands:**
- `flutter analyze` -- expected: no issues
- `flutter test test/app_live_pipeline_lifecycle_test.dart` -- expected: all pass including new race/zombie tests

**Manual checks:**
- Open release APK → walk with screen on (steps live) → lock screen → walk 3 min → unlock → steps increased and continue live without app restart

## Suggested Review Order

**Lifecycle serialization**

- Mutex queues pause/resume so stop and restart never interleave
  [`app.dart:108`](../../lib/app.dart#L108)

- Test hook delays monitor.stop to reproduce the race in CI
  [`app.dart:142`](../../lib/app.dart#L142)

**Resume recovery**

- Unconditional restart + cubit re-bind mirrors cold-start attach path
  [`app.dart:251`](../../lib/app.dart#L251)

**Regression tests**

- Rapid pause→resume while stop is blocked must keep live increments
  [`app_live_pipeline_lifecycle_test.dart:282`](../../test/app_live_pipeline_lifecycle_test.dart#L282)

- Resume must restart even when monitor already reports running
  [`app_live_pipeline_lifecycle_test.dart:358`](../../test/app_live_pipeline_lifecycle_test.dart#L358)
