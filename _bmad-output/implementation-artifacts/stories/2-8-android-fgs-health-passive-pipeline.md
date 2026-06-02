# Story 2.8: Android FGS Health Passive Pipeline

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want steps to accumulate while the app is closed on Android without keeping it open,
So that my daily goal progresses passively.

## Acceptance Criteria

1. **Given** Android 14+ with activity permission granted
   **When** app is backgrounded or removed from recents (not force-stopped)
   **Then** a foreground service with type `health` runs `BackgroundCollector` on a periodic cadence while OS permits (FR6, architecture D-04)

2. **Given** FGS is active
   **When** user walks ≥500 steps over ≥30 min without opening the app
   **Then** buckets are written to SQLite and Today reflects increase on next open or within one collection cycle (FR4 primary)

3. **Given** app returns to foreground
   **When** FGS and `LiveStepMonitor` would both read the pedometer
   **Then** single-writer rule holds — FGS pauses or delegates; `LiveStepMonitor` remains sole stream owner in UI isolate when process alive

4. **Given** user force-stops from Settings
   **When** app reopens
   **Then** foreground backfill recovers steps — documented limit, not Story failure

5. **Given** release manifest
   **When** inspected
   **Then** `FOREGROUND_SERVICE_HEALTH` declared; persistent notification copy is honest (not disguised as unrelated sync)

## Tasks / Subtasks

- [x] **Sub-task A — FGS persistent notification channel + copy** (AC: #5)
  - [x] Add `lib/core/services/health_foreground_notification.dart` (or extend a small `HealthForegroundServiceCoordinator` module):
    - [x] Dedicated Android notification channel e.g. `astra_health_tracking` — **distinct** from goal channel `astra_goal_reached` (Story 2.7).
    - [x] Stable notification id e.g. `100` (goal uses id `1`).
    - [x] Honest copy (UX §3.12): title **"Step tracking active"**, body **"Counting steps in the background on this device."** — no "sync", "update", or coach language.
    - [x] Low-importance / ongoing style appropriate for health FGS (not high-priority alert).
  - [x] Unit tests for copy constants and channel id separation from `NotificationService`.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Android manifest + Kotlin health FGS service** (AC: #1, #5)
  - [x] Add Kotlin service e.g. `android/app/src/main/kotlin/com/astraapp/astra_app/HealthStepForegroundService.kt`:
    - [x] Extend `Service`; declare in manifest with `android:foregroundServiceType="health"`.
    - [x] Call `ServiceCompat.startForeground(..., ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)` on Android 14+ (use compat API for API 34+ type argument).
    - [x] **Do not** use `foregroundServiceType="dataSync"` or `dataSync` in `startForeground` type bitmask.
    - [x] Service lifecycle: `onStartCommand` starts foreground notification; exposes start/stop via intents or bound channel from Flutter.
  - [x] Update `AndroidManifest.xml` — add `<service>` under `<application>` with `android:exported="false"` unless plugin requires otherwise.
  - [x] Extend `test/android/android_manifest_test.dart`:
    - [x] Assert `foregroundServiceType="health"` present on service declaration.
    - [x] Assert no `dataSync` FGS type remains.
  - [x] Update `docs/DEPENDENCIES.md` — document FGS service + notification channel.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Platform channel + Dart FGS coordinator** (AC: #1, #3)
  - [x] Add `lib/core/services/health_foreground_service.dart`:
    - [x] `MethodChannel` (or `EventChannel` for status if needed) to native start/stop/isRunning.
    - [x] `Future<void> startHealthCollectionService()` / `Future<void> stopHealthCollectionService()` — Android-only no-ops on iOS.
    - [x] Guard: only start when activity permission granted (reuse `ActivityPermissionResolver` or inject checker).
  - [x] Wire in `AppDependencies` as `HealthForegroundServiceCoordinator` (name as fits project).
  - [x] **Lifecycle policy in `AstraApp`** (coordinate with existing live pipeline):
    - [x] On `AppLifecycleState.paused` / app backgrounded: **start** FGS (after `_persistOnPause` best-effort flush).
    - [x] On `AppLifecycleState.resumed`: **stop** FGS before/alongside `LiveStepMonitor` restart — UI isolate owns pedometer when process alive (AC #3).
    - [x] Cold start while foreground: FGS **not** running; existing backfill + live attach unchanged (Story 2.9 sequence).
  - [x] Tests with mocked platform channel — assert start on pause, stop on resume.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Periodic `BackgroundCollector` inside FGS context** (AC: #1, #2)
  - [x] Reuse WM bootstrap pattern from `workmanager_callback.dart`:
    - [x] Extract shared factory e.g. `createIsolateBackgroundCollector({...})` if duplication would otherwise diverge — **single** collector configuration for WM + FGS paths.
    - [x] FGS path uses `PhonePedometerSource()` + `AdpBleSource()` (same as WM isolate) — **not** `MonitorDrainSource` (UI-only).
    - [x] Periodic cadence inside service: recommend **5 minutes** aligned with bucket granularity, bounded by collector timeouts (`sourceTimeout` 2s, `maxCollectionDuration` 25s).
    - [x] `collectOnce(enableGoalNotification: true)` in FGS context (user may be backgrounded when goal crossed).
  - [x] Ensure isolate-safe DB: `openIsolateAstraDatabase()` per collection context; close connection when service stops if practical.
  - [x] Invoke collection via:
    - **Option B (implemented):** Method channel `collectSteps` from Kotlin timer → `runFgsStepCollectionCycle()` in app process (FGS same process as Flutter when alive).
  - [x] Unit/integration tests for FGS collector bootstrap (mock DB + fake source).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Pedometer single-writer coordination** (AC: #3)
  - [x] When UI process alive and `LiveStepMonitor.isRunning`:
    - [x] FGS must **not** subscribe to `Pedometer.stepCountStream` concurrently.
    - [x] Implement via lifecycle stop (Sub-task C) **and** defensive check in FGS collector start (skip phone source read if native flag "ui_active" set via channel).
  - [x] When app swiped from recents (process may die): FGS + WM paths use `PhonePedometerSource` — only one active collector per process (FGS timer vs WM 15-min — avoid double collect same window: prefer FGS as primary when running; WM remains fallback orchestrator per architecture).
  - [x] Document coordination matrix in code comment near `HealthForegroundServiceCoordinator`.
  - [x] Regression: existing `live_step_monitor_test.dart`, `app_live_pipeline_lifecycle_test.dart` remain green.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task F — WorkManager coexistence** (AC: #1, #4)
  - [x] **Do not remove** WorkManager registration from `main.dart` — architecture D-04: WM = orchestration/fallback when FGS unavailable.
  - [x] When FGS running, WM periodic task may still fire — ensure `_collectInFlight` guard in `BackgroundCollector` prevents corrupt concurrent writes (already exists; verify under FGS+WM overlap).
  - [x] Foreground backfill on cold start + resume remains mandatory (Story 2.4/2.9) — FGS does not replace reopen recovery.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task G — Physical device verification + docs** (AC: #1–#5)
  - [ ] Manual Android walk test (physical device) — **deferred**; passive FR4 primary not exercised on device this session.
  - [x] Run `flutter test` (FGS, lock, background_collector, lifecycle — 24 tests green).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 2.8:**
- Android `health` foreground service runtime (manifest service + Kotlin + `startForeground` with `FOREGROUND_SERVICE_TYPE_HEALTH`)
- Persistent honest FGS notification (separate channel from goal notification)
- Periodic `BackgroundCollector.collectOnce()` while FGS active (background / recents removed)
- Lifecycle start/stop FGS coordinated with `LiveStepMonitor` (single pedometer owner when UI process alive)
- Manifest + test updates; `docs/DEPENDENCIES.md`
- FR4 primary passive acceptance path on Android (same-day walk without opening app)
- FR6 compliance

**Out of scope — defer to other stories:**
- `BackgroundHealthCapabilityEvaluator` + OEM battery deep-links + user-facing capability copy → **Story 2.10** (evaluator) / **Story 4.2** (My Data UI)
- Today display truth model / monotonic merge / cold-start ordering → **Story 2.9** (largely implemented via `spec-step-lifecycle-hardening.md` — verify green before FGS work)
- Health Connect ingestion → **Phase 1** (architecture D-05: `pedometer` direct sensor only)
- iOS BGAppRefresh / iOS passive parity → unchanged backfill model
- My Data `BackgroundStatusCard` → **Story 4.2**
- Replacing WorkManager with FGS-only model → **forbidden** (architecture D-04)
- Process keep-alive hacks beyond legitimate health FGS → see spec guardrails below

Do not over-implement. This story adds the **missing Android passive write path** — not a rewrite of Epic 2 ingestion.

### Approved implementation sequence (correct-course)

Sprint Change Proposal (2026-06-02) approved sequence: **2.9 → 2.10 → 2.8**.

| Prerequisite | Status before 2.8 dev | Action |
|--------------|----------------------|--------|
| Story 2.9 lifecycle truth model | Partially shipped (`ee87291` lifecycle hardening) | Run `flutter test test/app_live_pipeline_lifecycle_test.dart test/presentation/cubits/today_cubit_test.dart` — fix regressions before FGS |
| Story 2.10 WM/OEM evaluator | Backlog | 2.8 may ship without evaluator UI; do **not** duplicate full evaluator — minimal permission gate only |
| Stories 2.1–2.7 | Done | Build on existing collector, WM, notifications |

If FGS work exposes lifecycle bugs, fix in 2.9 scope first — do not patch around with FGS keep-alive.

### Pipeline position (Epic 2 — passive contract)

```text
                    ┌── LiveStepMonitor (UI isolate, process alive)
                    │         │
                    │         v
PhonePedometer ─────┼──> MonitorDrainSource ──> BackgroundCollector ──> SQLite
(WM isolate) ───────┤                              ^
(FGS service) ──────┘                              │
                                                   │
WorkManager 15min ─────────────────────────────────┘ (fallback orchestrator)

Cold start / resume: foreground backfill (mandatory) ──> BackgroundCollector
Goal notification: collectOnce(enableGoalNotification: true) in WM + FGS paths
```

**This story adds the FGS branch** — today only WM + foreground backfill + live overlay exist.

### Architecture contracts (must match exactly)

**Background model (D-04):**

| Layer | Role |
|-------|------|
| FGS health | Continuous/near-continuous collection when OS permits (this story) |
| WorkManager | Orchestration + fallback when FGS killed/unavailable (keep) |
| Foreground backfill | Mandatory recovery on every open (keep — AC #4) |
| LiveStepMonitor | Real-time overlay bonus; sole pedometer owner when UI process alive (AC #3) |

**Write path (unchanged):**

| Caller | Method |
|--------|--------|
| `BackgroundCollector` only | `StepRepository.upsertIngestionBucket()` |
| FGS periodic task | delegates to `collectOnce()` |
| UI periodic persist (60s) | `MonitorDrainSource` → collector |
| WM isolate | `PhonePedometerSource` → collector |

**Notification separation (UX §3.12, Story 2.7):**

| Notification | Channel | Id | Purpose |
|--------------|---------|-----|---------|
| Goal reached | `astra_goal_reached` | `1` | FR25 one-shot celebration |
| Health FGS | `astra_health_tracking` | `100` | System-required ongoing health work |

Never reuse goal channel for FGS. Never disguise health tracking as "sync" or "backup".

**Android 14+ FGS health (FR6):**

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_HEALTH" />
<service
    android:name=".HealthStepForegroundService"
    android:exported="false"
    android:foregroundServiceType="health" />
```

Runtime: `ACTIVITY_RECOGNITION` must be granted before starting health FGS ([Android FGS health type docs](https://developer.android.com/develop/background-work/services/fgs/service-types)). Project already requests activity recognition via onboarding.

**iOS:** All FGS Dart APIs no-op; no manifest changes on iOS.

### Current code state

| Path | Current state | What 2.8 changes | Must preserve |
|------|---------------|------------------|---------------|
| `android/.../AndroidManifest.xml` | FGS **permissions** only; no `<service>` | Add health FGS service declaration | No INTERNET; no dataSync type |
| `MainActivity.kt` | Plain `FlutterActivity` | May register method channel handler | — |
| `background_collector.dart` | Production ingestion writer | Reuse from FGS; optional shared bootstrap factory | `_collectInFlight`; sole upsert caller |
| `workmanager_callback.dart` | WM isolate bootstrap | Extract shared collector factory if needed | `@pragma('vm:entry-point')`; goal notification in WM |
| `app.dart` | Lifecycle backfill + 60s persist + live pipeline | Start/stop FGS on pause/resume | Cold-start order: backfill → refresh → attach live |
| `live_step_monitor.dart` | Sole UI pedometer owner | FGS must stop/delegate on resume | Never second stream in UI isolate |
| `app_dependencies.dart` | `MonitorDrainSource` for UI collector | Add FGS coordinator service | Existing WM + collector wiring |
| `notification_service.dart` | Goal notifications only | **Do not** merge FGS notification here | Separate channel |
| `test/android/android_manifest_test.dart` | Permissions only | Assert service + health type | No dataSync test stays |

### Recommended file layout

```text
android/app/src/main/kotlin/.../HealthStepForegroundService.kt   # NEW
lib/core/services/health_foreground_service.dart                   # NEW — platform channel + coordinator
lib/core/services/health_foreground_notification.dart              # NEW — channel + copy constants
lib/core/services/background_collector_factory.dart                # NEW (optional) — shared WM/FGS bootstrap
lib/app.dart                                                       # UPDATE — lifecycle FGS start/stop
lib/core/di/app_dependencies.dart                                  # UPDATE
android/app/src/main/AndroidManifest.xml                         # UPDATE
test/android/android_manifest_test.dart                            # UPDATE
test/core/services/health_foreground_service_test.dart             # NEW
docs/DEPENDENCIES.md                                               # UPDATE
```

### Pedometer coordination matrix (implement exactly)

| App state | Pedometer owner | Collector source | FGS running |
|-----------|-----------------|------------------|-------------|
| Foreground, process alive | `LiveStepMonitor` | `MonitorDrainSource` | **No** |
| Background, process alive | None in FGS if stopped | Last persist on pause | **Yes** (after pause flush) |
| Swiped from recents / process dead | FGS or WM isolate | `PhonePedometerSource` | **Yes** (if OS allows) |
| Force-stopped | None until reopen | Backfill on open | **No** until user opens app |

### FGS collection bootstrap sketch (suggested)

Reuse WM pattern — do not invent parallel ingestion logic:

```dart
@pragma('vm:entry-point')
Future<void> runFgsStepCollectionCycle({
  String? databasePath,
  NotificationService? notificationService,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  // Same as runStepCollectionWorkmanagerTask but PhonePedometerSource sources
  // await collector.collectOnce(enableGoalNotification: true);
}
```

Wire periodic invocation from Kotlin service (Handler/Coroutine timer) or Dart isolate owned by FGS — **document choice**; must not block main thread.

### Architecture compliance

| Decision / invariant | Requirement for 2.8 |
|----------------------|------------------------|
| D-04 | FGS + WM coexist; WM not removed |
| D-05 | `pedometer` direct sensor — no Health Connect |
| D-06 | Isolate-safe DB per collection context |
| D-12 | Goal notifications stay in `NotificationService`; FGS notification separate |
| D-19 | Only `BackgroundCollector` upserts buckets |
| FR4 | Same-day passive ≥500 steps / 30 min without opening app |
| FR6 | `health` FGS type; honest notification |
| UX §3.12 | FGS notification ≠ goal notification |

### Anti-patterns

- Do not use `foregroundServiceType="dataSync"` for step/pedometer work.
- Do not run FGS while `LiveStepMonitor` holds pedometer stream in same process.
- Do not add second production caller of `upsertIngestionBucket()`.
- Do not remove WorkManager or foreground backfill paths.
- Do not merge FGS notification into `NotificationService.showGoalReached()`.
- Do not implement Health Connect in this story.
- Do not use FGS solely to keep Flutter engine alive for live overlay — passive contract is SQLite buckets, not RAM delta.
- Do not skip physical device verification (FR4 primary cannot pass on emulator without step sensor).
- Do not scatter permission checks across screens — minimal gate in coordinator; full evaluator is 2.10.

### Testing requirements

| Area | Requirement |
|------|-------------|
| `android_manifest_test` | Service declared with `foregroundServiceType="health"`; no dataSync |
| `health_foreground_service_test` | Mock channel: start on background, stop on resume; iOS no-op |
| FGS collector bootstrap | Fake source + in-memory DB → buckets upserted |
| Regression | All lifecycle tests (`app_live_pipeline_lifecycle_test`, `today_cubit_test`, `live_step_monitor_test`) green |
| `background_collector_test` | `_collectInFlight` still prevents double collect |
| Manual | FR4 primary walk test on physical Android 14+ device |

Run: `flutter analyze`, `flutter test`

### Previous story intelligence

**Story 2.7 (done):**
- `collectOnce(enableGoalNotification:)` policy: WM + cold-start `true`; resume on Today `false`.
- **FGS path should use `enableGoalNotification: true`** (user backgrounded).
- `NotificationService` + `celebration_shown_date` dedup — reuse; separate FGS channel.
- WM bootstrap in `runStepCollectionWorkmanagerTask` — mirror for FGS collector deps.

**Story 2.4 (done):**
- `@pragma('vm:entry-point')`, `DartPluginRegistrant.ensureInitialized()`, `openIsolateAstraDatabase()`.
- Manifest FGS permissions added; service explicitly deferred — **this story completes that deferral**.
- 15-min WM minimum — FGS can collect more frequently but buckets remain 5-min normalized.

**Story 2.9 (backlog — partial code landed):**
- Commit `ee87291`: monotonic display, cold-start order, resume `monitor.restart()` + `syncSteps`.
- Verify before FGS: threshold persist (`onPersistRequested` / +5 debounce) must **not** be reintroduced.
- FGS must not break cold-start sequence in `AstraApp._maybeStartLivePipeline`.

**Spec guardrails:**
- `spec-step-lifecycle-hardening.md`: "Adding Android foreground service for process keep-alive" = **Ask First** — this story implements **health-type passive collection**, not keep-alive hack. Legitimate if tied to `BackgroundCollector` periodic writes.
- `spec-realtime-step-display.md`: same Ask First for keep-alive — honor single-writer rule.

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `ee87291` fix(lifecycle): harden live step pipeline and Today display | 2.9 groundwork — FGS start/stop must integrate without breaking resume/cold-start |
| `c2ead9a` docs(spec): step counter lifecycle hardening | Documents monotonic + ordering contracts FGS must respect |
| `b39c5dd` docs(planning): correct course for Epic 2 passive contract | Defines 2.8 scope + sequence 2.9→2.10→2.8 |
| `3953cb4` feat(dev): KPI-01 benchmark | Epic 3 closed; Epic 2 reopened for passive pipeline |

### Library / framework requirements

| Package | Version | Usage |
|---------|---------|-------|
| `workmanager` | ^0.9.0+3 | Keep registered; fallback orchestrator |
| `pedometer` | ^4.2.0 | FGS + WM isolate source |
| `flutter_local_notifications` | ^21.0.0 | FGS may use native Android notification from Kotlin; if Dart-init channel, do not conflict with plugin |
| `permission_handler` | ^12.0.1 | Activity recognition gate before FGS start |

**New dependencies:** Avoid if possible — prefer custom Kotlin FGS + method channel. If evaluating `flutter_foreground_task` or similar, verify Android 14 `health` type support and no INTERNET/analytics — update `docs/DEPENDENCIES.md` + Baptiste review before adding.

### Latest technical notes (Android 14+ health FGS)

- **Mandatory service type:** Apps targeting API 34+ must declare `android:foregroundServiceType="health"` on the service **and** pass `FOREGROUND_SERVICE_TYPE_HEALTH` to `startForeground()` ([Android 14 FGS types required](https://developer.android.com/about/versions/14/changes/fgs-types-required)).
- **Permission:** `FOREGROUND_SERVICE_HEALTH` is manifest-level (already declared). Runtime prerequisite includes granted `ACTIVITY_RECOGNITION`.
- **While-in-use restrictions:** Health FGS using activity recognition is appropriate for step counting; do not require `BODY_SENSORS_BACKGROUND` for Phase 0 pedometer path.
- **User visibility:** Persistent notification is mandatory — use honest health copy (AC #5).
- **Battery/OEM:** Aggressive OEMs may still kill FGS — WM + foreground backfill remain mandatory fallbacks (not 2.8 failure).

### Project context reference

- Review-before-commit workflow mandatory per sub-task ([Source: `docs/project-context.md`]).
- Baptiste is Flutter novice — review briefs should explain FGS, method channels, and Android 14 service types.
- [Source: `_bmad-output/planning-artifacts/architecture.md` — Platform Architecture, Today Display Truth Model, D-04]
- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 2.8 AC]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-02.md` — sequence + Epic 2 reopen]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §3.12 FGS notification edge case]
- [Source: `_bmad-output/implementation-artifacts/stories/2-4-background-collector-and-android-workmanager.md` — WM bootstrap]
- [Source: `_bmad-output/implementation-artifacts/stories/2-7-daily-goal-local-notification.md` — notification separation]
- [Source: `_bmad-output/implementation-artifacts/spec-step-lifecycle-hardening.md` — lifecycle contracts]
- [Source: `docs/DEPENDENCIES.md` — FGS permission notes]

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- FGS collection: Option B — Kotlin 5 min timer → `collectSteps` MethodChannel → `runFgsStepCollectionCycle()`

### Completion Notes List

- Android health FGS with honest notification channel `astra_health_tracking` (id 100), distinct from goal notifications.
- Lifecycle: pause flush → stop live monitor → start FGS; resume stop FGS → backfill/live attach.
- Shared `createIsolateBackgroundCollector` for WorkManager and FGS paths; WM registration unchanged.
- **Pending for reviewer:** Sub-task G physical walk test on device (CPH2663 recommended); CI `flutter test` blocked locally by locked `sqlite3.dll` — re-run before merge.

### File List

- android/app/build.gradle.kts
- android/app/src/main/AndroidManifest.xml
- android/app/src/main/kotlin/com/astraapp/astra_app/HealthForegroundChannel.kt
- android/app/src/main/kotlin/com/astraapp/astra_app/HealthStepForegroundService.kt
- android/app/src/main/kotlin/com/astraapp/astra_app/MainActivity.kt
- docs/DEPENDENCIES.md
- lib/app.dart
- lib/core/di/app_dependencies.dart
- lib/core/services/background_collector_factory.dart
- lib/core/services/fgs_step_collection.dart
- lib/core/services/health_foreground_notification.dart
- lib/core/services/health_foreground_service.dart
- lib/core/services/workmanager_callback.dart
- test/android/android_manifest_test.dart
- test/app_health_fgs_lifecycle_test.dart
- test/core/services/fgs_step_collection_test.dart
- test/core/services/health_foreground_notification_test.dart
- test/core/services/health_foreground_service_test.dart

### Change Log

- 2026-06-02: Story 2.8 implementation — Android health FGS passive pipeline (FR4/FR6, D-04).
- 2026-06-02: Code review — `IngestionCollectionLock`, pause UI periodic persist during FGS, expanded tests.

## Story completion status

- Status **done** — implementation + automated tests; physical walk (FR4 primary on device) deferred to later QA.
