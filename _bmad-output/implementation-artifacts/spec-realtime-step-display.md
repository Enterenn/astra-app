---
title: 'Real-time step display while app is running'
type: 'feature'
created: '2026-06-02'
status: 'in-review'
baseline_commit: 'dfc7c97'
context:
  - '_bmad-output/planning-artifacts/background-trust-and-movement-validation.md'
  - '_bmad-output/planning-artifacts/architecture.md'
  - '_bmad-output/implementation-artifacts/stories/2-4-background-collector-and-android-workmanager.md'
  - '_bmad-output/implementation-artifacts/stories/2-5-today-dashboard-with-goal-ring.md'
  - '_bmad-output/implementation-artifacts/stories/2-7-daily-goal-local-notification.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Today's step count only updates after `BackgroundCollector.collectOnce()` writes to SQLite. While walking with the app open, the UI stays stale for minutes because ingestion runs on cold start, resume, and WorkManager — not continuously during foreground use.

**Approach:** Add a `LiveStepMonitor` that owns the **single** phone pedometer subscription, computes `persisted DB steps + pending in-memory delta`, and pushes throttled updates to `TodayCubit`. `BackgroundCollector` reads bounded readings from the monitor hub (never opens a second `Pedometer.stepCountStream` listen). SQLite persistence stays batched via periodic `collectOnce` with a documented reconcile protocol.

## Boundaries & Constraints

**Always:**
- Only `BackgroundCollector` may call `StepRepository.upsertIngestionBucket()`.
- **Single pedometer stream owner:** `LiveStepMonitor` (or injected hub it owns) is the sole subscriber to `Pedometer.stepCountStream` while the app process is alive. Collector consumes bounded readings via monitor API — no second native listen.
- Increment math uses shared `StepIncrementCalculator` (extracted from `StepNormalizer`); never call `normalizeReadings()` per sensor event and never duplicate the `baseline ~/ 2` reset threshold.
- Today display total respects `LocalDayCalculator` via `clock.snapshot()` for "today"; pending delta applies only to the current local day.
- Live monitor runs at app lifecycle scope (`AstraApp`), not only when the Today tab is selected.
- Stale banner stays driven by `getLastIngestionUtc()`; live step updates must not clear or hide stale state.
- Permission gate is centralized: inject the same `ActivityPermissionChecker` into monitor and cubit; monitor never starts when permission is denied.
- **Architecture derogation (approved):** Phase 0 otherwise avoids reactive streams in presentation; exception added for Today live display — `LiveStepMonitor.watchTodaySteps()` → `TodayCubit`. Document in architecture.md refresh-triggers table after merge.

**Ask First:**
- Changing foreground DB persist interval from 60s default.
- Adding continuous Android FGS for process keep-alive.

**Never:**
- Writing step buckets from monitor or cubit.
- Second concurrent listen on `Pedometer.stepCountStream`.
- Replacing WorkManager / resume backfill.
- Promising iOS parity when the app process is killed.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| HAPPY_PATH_FOREGROUND | User walks on Today | Step count updates within ~2s (throttled max 1 emit / 1s) | N/A |
| HAPPY_PATH_BACKGROUNDED | App backgrounded, process alive, user walks, returns | Count already current on return; resume runs reconcile protocol | N/A |
| PERSIST_BATCH | Monitor active 60s+ | `collectOnce(enableGoalNotification: false)`; DB grows; on-screen total unchanged (no backward jump) | Log + continue on collector error |
| RECONCILE_PROTOCOL | Persist or resume collect starts | **pause delta → collectOnce → reconcileFromDatabase() → resume delta** under shared mutex with collector `_collectInFlight` | Skip reconcile if collect returns 0 and baseline unchanged |
| COLLECT_DURING_MONITOR | Periodic collect while monitor streaming | Collector drains hub readings; monitor stays sole stream owner; no double-count | Test required |
| RESUME_RECONCILE | AppLifecycle resumed | Existing `_collectAndRefreshToday` enhanced: collect → monitor.reconcile → cubit `refreshMetadata()` (stale/goal only, not full step re-read) | N/A |
| NO_PERMISSION | Activity permission denied | Monitor never started; Today shows `noPermission` | N/A |
| SENSOR_RESET | Cumulative counter drops (reboot) | `StepIncrementCalculator` reset handling; no negative display | N/A |
| DAY_ROLLOVER | Local midnight, app open | Reset pending delta + memory baseline; re-read persisted total for new local day; cubit status recomputed (empty/progress, not yesterday's ring) | N/A |
| GOAL_CROSSED_LIVE | Steps cross daily goal via live stream | Celebration fires via shared apply path (same as refresh); `tryClaimCelebrationShownDate` honored | N/A |
| GOAL_NOTIFICATION | Periodic 60s collect | `enableGoalNotification: false` (Story 2.7 matrix: foreground/resume/periodic = false; cold start + WM = true) | N/A |
| LATE_CUBIT_SUBSCRIBE | Monitor emits before `TodayCubit` ready | Hub exposes current value on subscribe (replay latest count) | N/A |
| STALE_BANNER | Live updates before next persist | Steps update live; `isStale` remains true until `getLastIngestionUtc()` advances | Manual verify |

</frozen-after-approval>

## Code Map

- `lib/data/datasources/step_increment_calculator.dart` -- NEW: shared `_calculateIncrement` logic extracted from `StepNormalizer`
- `lib/data/datasources/step_normalizer.dart` -- delegate increment math to calculator; unchanged bucket aggregation
- `lib/core/services/live_step_monitor.dart` -- NEW: sole pedometer owner, pending delta, reconcile protocol, `watchTodaySteps()` with replay, `drainReadingsForCollection()`
- `lib/core/services/background_collector.dart` -- accept readings from monitor hub instead of direct `source.watchStepReadings()` when monitor active
- `lib/data/datasources/phone_pedometer_source.dart` -- refactor or bypass default factory so production uses monitor hub only
- `lib/data/repositories/step_repository.dart` -- `getTodaySteps()` at reconcile
- `lib/data/repositories/ingestion_baseline_repository.dart` -- baseline seed after reconcile
- `lib/presentation/cubits/today_cubit.dart` -- `_applyTodaySnapshot()` shared by refresh + live; `refreshMetadata()` for stale/goal without step re-read
- `lib/app.dart` -- lifecycle: start monitor after backfill + permission; periodic collect 60s; reconcile on ingestion complete
- `lib/presentation/screens/app_scaffold.dart` -- remove Today-only 60s poll; ingestion callback → monitor reconcile only
- `lib/core/di/app_dependencies.dart` -- wire monitor + inject shared permission checker
- `_bmad-output/planning-artifacts/architecture.md` -- add Today live-stream exception + refresh-triggers row
- `test/core/services/live_step_monitor_test.dart` -- delta, reset, rollover, reconcile, collect-during-monitor
- `test/presentation/cubits/today_cubit_test.dart` -- live stream, celebration on live, metadata-only refresh
- `test/core/services/background_collector_test.dart` -- collector via monitor hub, no double listen
- `test/app_astra_lifecycle_test.dart` -- start/stop/dispose, permission denied skips monitor

## Tasks & Acceptance

**Execution:**
- [x] `lib/data/datasources/step_increment_calculator.dart` -- extract shared increment + reboot reset logic from `StepNormalizer` -- single source of truth for delta math
- [x] `lib/core/services/live_step_monitor.dart` -- sole stream owner; pending delta; mutex reconcile protocol; `watchTodaySteps()` with replay; `drainReadingsForCollection()`; throttle UI emits (~1s); midnight rollover handler -- core engine
- [x] `lib/data/datasources/monitor_drain_source.dart` + `phone_pedometer_source.dart` -- phone ingestion drains monitor buffer in UI isolate; WM isolate unchanged -- prevents double pedometer listen
- [x] `lib/core/di/app_dependencies.dart` -- construct monitor; share `ActivityPermissionChecker` with cubit factory -- single permission truth
- [x] `lib/presentation/cubits/today_cubit.dart` -- `_applyTodaySnapshot(steps, goal, stale, lastUtc)` used by refresh + live subscription; `refreshMetadata()` for stale/goal/permission without overwriting live steps -- fixes celebration gap
- [x] `lib/app.dart` -- start monitor after foreground backfill + permission check; `Timer.periodic(60s, collectOnce(enableGoalNotification: false))` on all tabs; resume: collect → reconcile → `refreshMetadata()` -- lifecycle owner
- [x] `lib/presentation/screens/app_scaffold.dart` -- remove `_refreshTimer`; change `_onIngestionComplete` to cubit `refreshMetadata()` only -- avoids double SQLite work
- [x] `_bmad-output/planning-artifacts/architecture.md` -- document approved reactive exception for Today live display -- closes architecture gap
- [x] `test/...` -- live monitor, increment calculator, cubit live/celebration/metadata tests -- covers review gaps

**Acceptance Criteria:**
- Given permission granted and app on Today, when user walks 20+ steps, then count updates within 5s without tab switch or restart.
- Given app backgrounded (process alive) and user walks, when returning to Today, then count reflects background steps without force-stop.
- Given 2+ minutes of walking with periodic persist, when collect completes, then SQLite total increases and on-screen count does not jump backward.
- Given steps cross daily goal via live stream only, when threshold reached, then goal celebration triggers without waiting for refresh/ingestion.
- Given permission denied, when opening app, then monitor never starts and Today shows no-permission state.
- Given monitor active, when periodic `collectOnce` runs, then no second `Pedometer.stepCountStream` subscription is created (verified by test).
- Given `flutter analyze` and `flutter test`, when run, then all pass with no new issues.

## Design Notes

**Display formula:** `displaySteps = persistedTodaySteps + pendingDeltaSinceLastReconcile`.

**Reconcile protocol (mandatory order):**
1. Monitor enters `reconciling` — pauses delta accumulation, buffers no new increments into pending.
2. `await backgroundCollector.collectOnce(enableGoalNotification: per matrix)`.
3. `await monitor.reconcileFromDatabase()` — re-read `getTodaySteps()` + baseline from `IngestionBaselineRepository`; zero pending delta.
4. Resume live accumulation; emit current total (replay value updated).

Mutex: monitor reconcile waits on collector `_collectInFlight` (or shared lock) to prevent interleaved sensor events during persist.

**Pedometer ownership:** `LiveStepMonitor.start()` opens the one `Pedometer.stepCountStream` subscription. `BackgroundCollector` for phone source calls `monitor.drainReadingsForCollection(maxReadings: N)` which returns recent `StepReading`s from an internal ring buffer — never calls `PhonePedometerSource.watchStepReadings()` directly in production when monitor is running.

**Celebration path:** Live handler calls `_applyTodaySnapshot(steps: liveCount, ...)` which invokes existing `_maybeTriggerCelebration` — not a bare `emit(copyWith(steps:))`.

**Goal notification matrix (Story 2.7 aligned):**

| Call site | `enableGoalNotification` |
|-----------|---------------------------|
| Cold-start backfill | `true` |
| App resume collect | `false` |
| Periodic 60s collect | `false` |
| WorkManager callback | `true` |

**Start sequence:** `AstraApp` waits for initial `_foregroundBackfill` + permission granted → `monitor.start()` → first `reconcileFromDatabase()` → `TodayCubit` subscribes (gets replayed current value immediately).

**Throttle:** Coalesce sensor bursts to max one UI emit per second; satisfies AC without GoalRing rebuild spam.

**Midnight rollover:** On local day change detected via `clock.snapshot()`, reset pending delta, reload persisted total for new day, emit fresh snapshot through `_applyTodaySnapshot` (status may flip from progress to empty).

## Verification

**Commands:**
- `flutter analyze` -- expected: no issues
- `flutter test test/core/services/live_step_monitor_test.dart test/core/services/background_collector_test.dart test/presentation/cubits/today_cubit_test.dart` -- expected: all pass

**Manual checks:**
- Walk on Today: live tick-up; stale banner may remain until persist — steps still update.
- Cross goal while walking: celebration without leaving screen.
- Background 30s while walking: reopen, count current.
- History tab 60s+: persist still runs (check `getLastIngestionUtc()` advances).

## Spec Change Log

| Date | Trigger | Amendment | Avoids |
|------|---------|-----------|--------|
| 2026-06-02 | Adversarial code review (pre-impl) | Single pedometer owner + hub drain; reconcile mutex protocol; `StepIncrementCalculator`; celebration shared path; goal-notification matrix; replay on subscribe; permission centralization; ingestion → reconcile-only; expanded tests; architecture derogation note | Double listen crash, double-count on reconcile, celebration regression, notification dupes, cubit race on startup |
| 2026-06-02 | Field test: count drop 271→250, shake false steps | **A:** monotonic reconcile (`pendingDelta` floor when SQLite &lt; display). **B:** shared ingestion baseline at `beginReconcile`; drain full buffer; `maxReadingsPerSource: 250` on persist | Visible backward jump after 60s persist; lost buffered readings beyond 50 cap |
