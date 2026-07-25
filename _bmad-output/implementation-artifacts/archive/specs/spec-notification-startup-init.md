---
title: 'NotificationService cold-start init timeout'
type: 'bugfix'
created: '2026-06-02'
status: 'done'
baseline_commit: '8a58a3ec973adf85a5f7e83ec560786728ef9038'
context:
  - 'docs/project-context.md'
  - '_bmad-output/implementation-artifacts/stories/2-7-daily-goal-local-notification.md'
  - '_bmad-output/implementation-artifacts/stories/2-10-workmanager-orchestration-and-oem-deferral-hardening.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Cold start on Android emulator logs `NotificationService init timed out: TimeoutException after 0:00:05.000000` and ~200 skipped frames. WorkManager’s background isolate spins up a second Flutter engine (`FlutterJNI.loadLibrary called more than once`) while `main()` is blocked awaiting `FlutterLocalNotificationsPlugin.initialize()`, causing a platform-channel race that hangs init for the full 5 s timeout.

**Approach:** Serialize cold-start initialization — cancel any in-flight WorkManager step-collection work before UI-isolate notification init, complete init quickly, then re-register periodic WM after dependencies are ready. Harden the WM isolate path with a bounded `initializeForBackground()` timeout so step collection still succeeds when notification init fails.

## Boundaries & Constraints

**Always:**
- Only `BackgroundCollector` writes step buckets to SQLite.
- Goal notifications remain local-only (FR25); no FCM.
- WorkManager remains the reconciliation fallback (D-04); foreground backfill on app open stays mandatory.
- Existing call-site policy for `enableGoalNotification` unchanged (Story 2.7 table).
- Follow project-context review-before-commit gate.

**Ask First:**
- Changing WM periodic frequency (currently 15 min).
- Removing the 5 s (or shorter) init timeout entirely.

**Never:**
- Blocking `runApp()` on WorkManager registration.
- Initializing notifications in both isolates concurrently without a cancel/defer guard.
- Adding FCM or scheduled nudge notifications.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| COLD_START_RACE | App launch; WM job from prior session fires concurrently | WM unique work cancelled before notification init; init completes < 1 s; WM re-registered after deps | Log timeout only if init still fails; app launches normally |
| WM_ISOLATE_INIT_FAIL | Background task runs; notification plugin init hangs | Step collection completes; goal notification skipped for that run | Debug log; no crash |
| NOTIFICATION_INIT_OK | Permission granted; init succeeds | `_initialized == true`; `showGoalReached` works from UI and WM paths | N/A |
| PERMISSION_DENIED | Notification permission denied | Init succeeds; `showGoalReached` no-ops (existing behavior) | N/A |
| NON_ANDROID | iOS/desktop | No WM cancel/register side effects | Existing platform guards |

</frozen-after-approval>

## Code Map

- `lib/main.dart` — startup order: cancel WM → notification init → deps → re-register WM → `runApp`
- `lib/core/services/notification_service.dart` — shared init completer per isolate; bounded `initializeForBackground()`
- `lib/core/services/workmanager_callback.dart` — export/call cancel helper; `registerStepCollectionWorkmanager` unchanged semantics
- `lib/core/services/workmanager_tasks.dart` — `kStepCollectionUniqueName` used for cancel-before-init
- `lib/core/services/background_collector_factory.dart` — propagate init failure so collector skips goal notification
- `test/core/services/notification_service_test.dart` — init timeout / concurrent-call behavior
- `test/core/services/workmanager_callback_test.dart` — cancel-before-register ordering

## Tasks & Acceptance

**Execution:**
- [x] `lib/core/services/workmanager_callback.dart` -- add `cancelStepCollectionWorkmanager()` using `cancelByUniqueName(kStepCollectionUniqueName)` behind Android guard -- prevents WM isolate racing UI init
- [x] `lib/main.dart` -- call cancel before `notificationService.initialize()`; reduce blocking timeout to 3 s; keep existing catch/log -- fixes observed 5 s stall
- [x] `lib/core/services/notification_service.dart` -- add in-isolate init `Completer` so duplicate `initialize()` calls share one future; add `initializeForBackground()` timeout (e.g. 2 s) returning `false` on failure -- hardens WM path
- [x] `lib/core/services/background_collector_factory.dart` -- when `initializeForBackground()` returns false, pass collector deps without notification evaluation path (or null notification service) -- collection must not fail
- [x] `test/core/services/notification_service_test.dart` -- test concurrent `initialize()` calls invoke platform init once; test background timeout returns false
- [x] `test/core/services/workmanager_callback_test.dart` -- test startup helper invokes cancel before register when Android

**Acceptance Criteria:**
- Given a cold start on Android emulator with a pending WM job, when the app launches, then no `NotificationService init timed out` log appears and first frame renders without ~200 skipped frames attributable to init blocking
- Given WM task runs in background isolate and notification init times out, when `collectOnce(enableGoalNotification: true)` executes, then step buckets are written and no notification is shown
- Given notification init succeeds in `main()`, when goal is reached via foreground backfill, then `showGoalReached` fires once per day (Story 2.7 AC #1 preserved)
- Given `flutter test test/core/services/notification_service_test.dart test/core/services/workmanager_callback_test.dart`, when tests run, then all pass

## Spec Change Log

## Design Notes

Startup sequence after fix:

```
ensureInitialized → cancel WM unique work → notification init (≤3 s)
→ AppDependencies.create → register WM → runApp
```

WM isolate keeps minimal init but must not block collection when notifications are unavailable.

## Verification

**Commands:**
- `flutter test test/core/services/notification_service_test.dart test/core/services/workmanager_callback_test.dart` -- expected: all pass
- `flutter analyze` -- expected: no issues
- `flutter run` on Android emulator -- expected: no init timeout log; WM re-registers after launch

**Manual checks (if no CLI):**
- Launch app twice on emulator; confirm logcat lacks `NotificationService init timed out` and Choreographer skipped-frame warnings are not dominated by init blocking

## Suggested Review Order

**Cold-start serialization**

- Cancel pending WM work before notification plugin init on Android
  [`main.dart:14`](../../lib/main.dart#L14)

- Shared cancel helper wired through injectable WM client
  [`workmanager_callback.dart:118`](../../lib/core/services/workmanager_callback.dart#L118)

**Notification init hardening**

- Single in-isolate init future + background timeout returning false
  [`notification_service.dart:51`](../../lib/core/services/notification_service.dart#L51)

- Skip goal-notification deps when background init fails
  [`background_collector_factory.dart:31`](../../lib/core/services/background_collector_factory.dart#L31)

**Tests**

- Concurrent init + background timeout unit coverage
  [`notification_service_test.dart:50`](../../test/core/services/notification_service_test.dart#L50)

- Cancel helper + WM collection without notifications on init timeout
  [`workmanager_callback_test.dart:236`](../../test/core/services/workmanager_callback_test.dart#L236)
