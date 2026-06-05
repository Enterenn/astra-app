# Story 6.3: Activity-Idle Persist Flush

Status: done

<!-- Baptiste 2026-06-05: Flush when user stops moving (15 s step-stream idle), not fixed 60 s timer. -->
<!-- Universal — not OEM-specific; addresses live vs SQLite gap on process kill (Story 6.2 field notes). -->
<!-- Shake drip mitigation (Nord 4) deferred — no 6.4 unless multi-device field data warrants it. -->

## Story

As a **user**,
I want my steps saved to local storage when I finish a bout of walking,
So that Today stays accurate after I close or kill the app, without relying on a fixed background timer.

## Acceptance Criteria

1. **Given** the live step pipeline is active (`enableLiveStepPipeline`)
   **When** no new phone pedometer reading is processed for **`kActivityIdleFlushDelay` (15 s)**
   **Then** the app runs the existing persist cycle (`beginReconcile` → `collectOnce` → `reconcileFromDatabase` → `endReconcile`)
   **And** each new processed reading **resets** the idle timer

2. **Given** continuous walking with readings arriving more often than every 15 s
   **When** the user does not pause long enough to trigger idle
   **Then** a **fallback** persist still runs at least every **`kMaxPersistStaleness` (5 min)** so long activities are not held only in `pendingDelta`

3. **Given** `AppLifecycleState.paused` (home / app backgrounded)
   **When** lifecycle fires
   **Then** `_persistOnPause` behavior is **unchanged** (immediate best-effort flush before FGS handoff)
   **And** idle timer does not duplicate a flush already in flight (`_backgroundPersistInFlight` / reconcile mutex respected)

4. **Given** `enablePeriodicPersist` is true in production `AstraApp`
   **When** idle-based persist ships
   **Then** the fixed **60 s** `Timer.periodic` persist is **removed or demoted** to fallback-only (no double persist every 60 s + idle)
   **And** tests / dev flags can disable idle persist for isolation

5. **Given** synthetic reading sequences in tests
   **When** readings stop for ≥ 15 s
   **Then** at least one test verifies SQLite `getTodaySteps()` reflects buffered increments without requiring lifecycle pause
   **And** a test verifies the 5 min fallback fires when readings never gap ≥ 15 s

6. **Given** implementation complete
   **When** `flutter analyze` and targeted tests run
   **Then** no regressions in `live_step_monitor_test.dart`, `background_collector_test.dart`, `app_live_pipeline_lifecycle_test.dart`

**Depends on:** Story 6.2 (increment math stable). Story 2.9 (Today Display Truth Model — `pendingDelta` + reconcile floor).  
**Out of scope:** OEM-specific tuning; accelerometer activity recognition; shake drip cap (Nord 4 — revisit only with multi-device evidence); changing bucket schema.

---

## Design — LOCKED (2026-06-05)

### Problem (from 6.2 field test)

| Observation | Cause |
|-------------|--------|
| Live 2063 → reopen 2052 after kill | `pendingDelta` lost; SQLite stale |
| Pause persist helps; kill does not | Async pause flush may not complete |
| 60 s periodic flush arbitrary | User sits at desk before timer → gap |

### Approach — activity idle, not OEM-specific

```
Each StepReading processed in LiveStepMonitor
  → reset idle Timer (15 s)

No reading for 15 s
  → onActivityIdle callback → AstraApp._runPersistCycle()

Parallel: max-staleness Timer (5 min) → flush if lastPersist older than cap
```

**Signal:** inter-arrival silence on the **processed** step stream (same timestamps as 6.2 rate-limit). No new hardware dependency — works on **all** `TYPE_STEP_COUNTER` devices.

### Placement

| Location | Verdict |
|----------|---------|
| `LiveStepMonitor` | ✅ Owns idle timer + `onActivityIdle` callback (last processed `observedAtUtc`) |
| `AstraApp` | ✅ Wires callback to `_runPersistCycle`; removes/replaces 60 s periodic |
| `BackgroundCollector` | ❌ Unchanged — still sole bucket writer |
| `PhonePedometerSource` | ❌ Unchanged |

### Constants — LOCKED

| Constant | Value | Rationale |
|----------|------:|-----------|
| `kActivityIdleFlushDelay` | **15 s** | Baptiste proposal; matches "sat at desk" without mid-walk flush on normal cadence |
| `kMaxPersistStaleness` | **5 min** | Safety net for treadmill / sparse OEM event cadence |

### Known limitations (document, do not block ship)

- Kill **during** walking (before idle) can still drop `pendingDelta` — shorter window than 60 s if user stops before kill.
- Idle flush **persists** shake steps already credited live — does not filter phantom steps (not 6.4).
- FGS / WorkManager paths when UI monitor stopped rely on existing pause/background collectors — unchanged.

---

## Tasks / Subtasks

- [x] **A — Idle timer in `LiveStepMonitor`** (AC: #1)
  - [x] Track last processed reading time; reset timer on each `_applyReadingToDelta` (and after flush replay)
  - [x] Expose `VoidCallback? onActivityIdle` or `Future<void> Function()?`
  - [x] Cancel timer on `stop()` / `dispose`
  - [x] Unit tests: idle fires after delay; new reading cancels pending idle

- [x] **B — Wire `AstraApp` persist policy** (AC: #2–#4)
  - [x] Replace 60 s periodic with idle callback + 5 min staleness fallback
  - [x] Guard against concurrent persist (`_persistInFlight` mutex + `syncTodayAfter`)
  - [x] Unit test: idle → SQLite via monitor + collector (widget idle/staleness tests skipped — Timer.periodic hang)

- [x] **C — Verification** (AC: #5–#6)
  - [x] `flutter analyze` + targeted test suites (17 tests green)
  - [x] Manual: sit 20 s → idle snackbar → kill → reopen → same step count (Baptiste 2026-06-05)

---

## Dev Notes

### Architecture compliance

- Single bucket writer: `BackgroundCollector` only [architecture D-20]
- `LiveStepMonitor` never writes SQLite [Story 2.9]
- Reconcile floor: `reconcileFromDatabase` must not lower display after idle flush [Story 2.9]

### Files to update (expected)

| File | Change |
|------|--------|
| `lib/core/services/live_step_monitor.dart` | Idle timer + callback |
| `lib/app.dart` | Persist policy wiring |
| `test/core/services/live_step_monitor_test.dart` | Idle timer tests |
| `test/app_live_pipeline_lifecycle_test.dart` | Optional idle → persist path |

### Files to NOT change

| File | Reason |
|------|--------|
| `lib/data/datasources/step_increment_calculator.dart` | 6.2 scope |
| Native Kotlin / `pedometer` fork | Out of scope |

### References

- Story 6.2 — rate-limit + Nord field notes (pendingDelta gap)
- `lib/app.dart` — `_runPersistCycle`, `_persistOnPause`, `_persistInterval`
- `lib/core/services/live_step_monitor.dart` — buffer drain, reconcile
- `_bmad-output/planning-artifacts/architecture.md` — Today Display Truth Model

---

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Field: 2102→2082 drop after idle — fixed via `_persistInFlight` mutex + `syncTodayAfter` on idle flush
- Widget tests with `enablePeriodicPersist: true` hang on `Timer.periodic` + `runAsync` — removed; unit coverage retained

### Completion Notes List

- Idle 15s flush + staleness fallback 5min replace 60s periodic persist
- Staleness timer ticks every 5min but flushes only if no persist in last 5min (not blind flush)
- Idle/staleness inactive when app backgrounded (`_stopActivityBasedPersist` on pause)
- Manual validation: kill after idle flush preserves step count

### File List

- lib/core/services/live_step_monitor.dart
- lib/app.dart
- lib/presentation/widgets/goal_ring.dart
- lib/data/repositories/user_preferences_repository.dart
- test/core/services/live_step_monitor_test.dart
- test/app_live_pipeline_lifecycle_test.dart
- test/app_persist_policy_test.dart

### Review Findings

- [x] [Review][Patch] AC #5 staleness fallback test — `shouldTriggerStalenessPersist` + `app_persist_policy_test.dart`
- [x] [Review][Defer] `enablePeriodicPersist` rename — deferred, low value vs churn
- [x] [Review][Defer] AstraApp widget test for idle wiring — deferred, manual validation + unit coverage

### Change Log

- 2026-06-05: Story 6.3 implemented — activity-idle persist, staleness fallback, persist mutex, field-validated
- 2026-06-05: Code review patches — staleness testability, story marked done
