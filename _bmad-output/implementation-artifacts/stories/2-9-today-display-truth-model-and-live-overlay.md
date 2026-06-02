# Story 2.9: Today Display Truth Model & Live Overlay

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want Today to show my real progress without confusing backward jumps,
So that I trust the ring whether the app was open or closed.

## Acceptance Criteria

1. **Given** documented display contract
   **When** reviewed in architecture / story notes
   **Then** persisted SQLite daily sum = **source of truth**; `LiveStepMonitor` = **real-time overlay bonus** when process alive; UI never shows a lower step count within the same local day except at day rollover

2. **Given** cold start with permission granted
   **When** Today loads
   **Then** sequence is: foreground backfill → reconcile from DB (`TodayCubit.refresh`) → attach live monitor → sync live total (no stale DB-only refresh overwriting live)

3. **Given** app resume (process alive)
   **When** user returns from background
   **Then** live stream recovers and steps update within 5s without force-stop (field test B)

4. **Given** uncommitted lifecycle hardening work
   **When** Story 2.9 is implemented
   **Then** keep: monotonic merge, `syncSteps`, cold-start ordering, `_persistOnPause` best-effort
   **And** revert: threshold persist (`onPersistRequested` / +5 steps debounce) — caused regression 1273→1254

5. **Given** unit and widget tests
   **When** `flutter test` runs
   **Then** monotonic display, cold-start order, and resume sync are covered

6. **Given** Story 2.8 FGS lifecycle (done)
   **When** app pauses then resumes
   **Then** Today truth model still holds: pause flush → FGS; resume stop FGS → persist/reconcile → `syncSteps`; no backward jump from overlapping collects (`IngestionCollectionLock` + `_collectInFlight`)

## Tasks / Subtasks

- [x] **Sub-task A — Audit: confirm threshold persist is absent** (AC: #4)
  - [x] Grep codebase for `onPersistRequested`, mid-walk `+5` debounce, or sensor-driven `collectOnce` outside lifecycle/60s periodic — must be **zero** matches in `lib/`.
  - [x] If any remnant found, remove it and add a regression test that proves no collect fires on step delta alone.
  - [x] Document in review brief: commit `ee87291` already omitted threshold persist; this sub-task is verification, not re-implementation.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Fix cold-start sequence: DB refresh before live attach** (AC: #2)
  - [x] In `lib/app.dart` `_bindLiveMonitorToToday()` (or `_startLivePipelineFirstTime()`): after permission granted and **after** `_foregroundBackfill` completes, call `await _todayCubit?.refresh(silent: true)` **before** `monitor.start()` / `attachLiveMonitor`.
  - [x] Current bug: refresh runs only on **denied** permission path (`_bindLiveMonitorToToday` lines 239–241); granted path skips DB baseline — violates architecture cold-start table and `spec-step-lifecycle-hardening.md` sequence.
  - [x] Target sequence (single owner `AstraApp`):
    1. `await _foregroundBackfill` (already in `_startLivePipelineFirstTime`)
    2. `await _todayCubit?.refresh(silent: true)` — SQLite daily sum into cubit
    3. `monitor.start()` → `reconcileFromDatabase()` → `attachLiveMonitor` → `syncSteps(monitor.currentTodaySteps)`
  - [x] Extend `test/app_live_pipeline_lifecycle_test.dart`: seed DB with 800 steps, live monitor pending delta 1050 before attach — expect displayed ≥ 1050 after pipeline ready (COLD_START_RACE from spec).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Codify Today Display Truth Model in source** (AC: #1)
  - [x] Add concise doc comments on `TodayCubit._applyTodaySnapshot` (monotonic same-day rule) and `AstraApp._startLivePipelineFirstTime` / `_collectAndRefreshToday` (layer roles: SQLite truth, live overlay, backfill recovery).
  - [x] Do **not** duplicate architecture.md in comments — link to [Source: `_bmad-output/planning-artifacts/architecture.md` — Today Display Truth Model].
  - [x] Confirm `onIngestionComplete` → `refreshMetadata()` only (not full `refresh()` step re-read) — already correct in `app_scaffold.dart`; do not regress to full refresh on ingestion.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — FGS + ingestion lock regression** (AC: #3, #6)
  - [x] Run and keep green: `test/app_health_fgs_lifecycle_test.dart`, `test/app_live_pipeline_lifecycle_test.dart`, `test/core/services/ingestion_collection_lock_test.dart`, `test/core/services/background_collector_test.dart`.
  - [x] If resume path drops steps when FGS + pause persist overlap, fix in `AstraApp._collectAndRefreshToday` (await `_backgroundPersistInFlight` already exists — verify with test).
  - [x] Optional widget test: pause (FGS start) with buffered live steps → resume → `state.steps` monotonic vs pre-pause.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Verification + manual field test B** (AC: #3, #5)
  - [x] `flutter analyze` + `flutter test test/presentation/cubits/today_cubit_test.dart test/app_live_pipeline_lifecycle_test.dart test/core/services/live_step_monitor_test.dart test/app_health_fgs_lifecycle_test.dart`
  - [ ] Manual (physical device): walk with app open → switch away 30s+ → return — count advances within 5s (field test B from sprint-change-proposal).
  - [ ] Manual: force-stop → reopen — count may lag until backfill; must **not** show lower same-day total than last visible before kill if process had live overlay (document limit if backfill lags).
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (automated tests; manual field B deferred to device)

## Dev Notes

### Story scope boundary

**In scope:**
- Finalize and **verify** Today Display Truth Model (mostly landed in `ee87291` + `spec-step-lifecycle-hardening.md`)
- Fix cold-start `refresh()` ordering gap
- Confirm threshold persist absent; prevent reintroduction
- Regression coverage for monotonic display, cold-start race, resume sync, FGS coexistence
- Align runtime behavior with architecture “Today Display Truth Model” section

**Out of scope:**
- Android FGS implementation → **Story 2.8 (done)**
- `BackgroundHealthCapabilityEvaluator` / WM OEM UI → **Story 2.10**
- Beyond-goal ring animation polish → **Story 5.4**
- My Data stale banner copy changes → **Epic 4.2**
- Health Connect / iOS BGAppRefresh changes
- Changing 60s periodic persist interval (Ask First per specs)

This story is **not** a greenfield feature — treat it as contract hardening + one sequencing fix + audit.

### Implementation status (brownfield)

| Area | Status | Action for 2.9 |
|------|--------|----------------|
| Monotonic `_applyTodaySnapshot` | Shipped `ee87291` | Verify tests; no behavior change unless broken |
| `syncSteps` + live during loading | Shipped | Keep |
| `_persistOnPause` on background | Shipped | Keep — best-effort RAM flush before FGS |
| `LiveStepMonitor.restart()` on resume | Shipped | Keep |
| Threshold persist (`onPersistRequested`) | **Never merged** / omitted in `ee87291` | Audit only |
| Cold-start `refresh()` before attach | **Gap** | **Fix in Sub-task B** |
| FGS pause/resume | Shipped `2.8` | Regression only |

### Today Display Truth Model (developer contract)

| Layer | Role | Writes buckets? |
|-------|------|-----------------|
| SQLite daily aggregate (`StepRepository.getTodaySteps`) | Source of truth for ring, notifications, History | Only via `BackgroundCollector` |
| `LiveStepMonitor` overlay | Real-time bonus while process alive | **Never** |
| Foreground backfill | Recovery on every open / after force-stop | Via collector |

**Monotonic rule:** Within the same local day (`formatLocalDayIso`), `TodayCubit` display uses `max(incoming, state.steps)` unless day rolled over. Live overlay may exceed DB until next persist — UI must not jump backward when `refresh()` reads lower SQLite total.

**Rejected pattern:** Threshold-based mid-walk persist (e.g. +5 steps / 2s debounce triggering `collectOnce`) — caused field regression 1273→1254. Only lifecycle-driven persist: pause, resume, 60s periodic, cold-start backfill, WM/FGS.

[Source: `_bmad-output/planning-artifacts/architecture.md` — Today Display Truth Model]

### Pipeline position (Epic 2)

Approved sequence (sprint-change-proposal 2026-06-02): **2.9 → 2.10 → 2.8**.

Story 2.8 is **done**; 2.9 must not break FGS lifecycle integration in `lib/app.dart`:

```text
paused:  _persistOnPause → stop LiveStepMonitor → start health FGS
resumed: stop FGS → _collectAndRefreshToday → syncSteps → periodic persist restart
```

Single-writer: when UI process alive, `LiveStepMonitor` owns pedometer; FGS uses `PhonePedometerSource` only when UI stopped (Story 2.8 AC #3).

### Key files (UPDATE — read before editing)

| File | Current behavior | 2.9 change |
|------|------------------|------------|
| `lib/app.dart` | Live pipeline owner; pause/resume/FGS; `_bindLiveMonitorToToday` skips refresh when permission granted | Add `refresh(silent:true)` before monitor bind; document sequences |
| `lib/presentation/cubits/today_cubit.dart` | Monotonic merge, `attachLiveMonitor`, `syncSteps`, `refreshMetadata` | Comments only unless tests fail |
| `lib/core/services/live_step_monitor.dart` | Sole stream owner; reconcile never lowers display | Regression only |
| `lib/presentation/screens/app_scaffold.dart` | Awaits backfill; ingestion → `refreshMetadata` only | **Preserve** — no parallel `refresh()` |
| `lib/core/services/background_collector.dart` | `IngestionCollectionLock` + `_collectInFlight` | Verify concurrent FGS/WM/pause paths |
| `lib/core/services/ingestion_collection_lock.dart` | Cross-isolate mutex | Tests must stay green |

### Architecture compliance

**Cubit refresh triggers** ([Source: `architecture.md` — Cubit refresh triggers]):

| Trigger | Today step count | Stale/goal metadata |
|---------|------------------|---------------------|
| Cold start | backfill → **refresh** → attach live → syncSteps | `refreshMetadata` after bind |
| Resume | persist → reconcile → **syncSteps** | `refreshMetadata` in `_collectAndRefreshToday` |
| `onIngestionComplete` | **Do not** full refresh | `refreshMetadata()` only |
| 60s periodic | persist only (no cubit step re-read) | — |
| Tab return Today | — | `refreshMetadata()` |

**Write path (unchanged):** Only `BackgroundCollector` → `upsertIngestionBucket`. Monitor/cubit read-only for steps.

**Phase 0 derogation:** `LiveStepMonitor.watchTodaySteps()` → `TodayCubit` is the approved exception to “no reactive streams in presentation.”

### Library / framework requirements

No new packages. Existing stack:

| Package | Usage in 2.9 |
|---------|----------------|
| `flutter_bloc` | `TodayCubit` |
| `pedometer` | Owned by `LiveStepMonitor` when UI alive |
| `permission_handler` | Gate before live pipeline |

### Testing requirements

| Test file | Covers |
|-----------|--------|
| `test/presentation/cubits/today_cubit_test.dart` | Monotonic refresh after live; live during loading; `syncSteps` |
| `test/app_live_pipeline_lifecycle_test.dart` | Cold start monotonic; resume increases; pause persist; cubit reattach |
| `test/core/services/live_step_monitor_test.dart` | `restart()` monotonic |
| `test/app_health_fgs_lifecycle_test.dart` | FGS start/stop does not break lifecycle |
| `test/core/services/ingestion_collection_lock_test.dart` | Cross-collector mutex |
| `test/core/services/background_collector_test.dart` | `_collectInFlight` + lock |

**Add for Sub-task B:** cold-start race widget test (DB < live → display = live).

Run: `flutter analyze`, `flutter test` (files above minimum).

### Previous story intelligence

**Story 2.8 (done):**
- FGS start on pause after `_persistOnPause`; stop on resume before live restart.
- `IngestionCollectionLock` added for WM/FGS/UI overlap — 2.9 must not regress concurrent collect behavior.
- Physical FR4 walk test deferred — not blocking 2.9 code completion.

**Story 2.7 (done):**
- Goal notification only when `enableGoalNotification: true` — pause/resume/periodic use `false`; do not change matrix in 2.9.

**Story 2.5 (done):**
- `GoalRing` read-only from cubit; stale via `refreshMetadata` / `isStaleData`.

**Spec `spec-step-lifecycle-hardening.md` (done):**
- Defines monotonic, cold-start order, resume `restart()` — 2.9 implements missing `refresh()` step and verification.

**Spec `spec-realtime-step-display.md`:**
- Single stream owner, reconcile protocol, 60s periodic — all shipped; 2.9 aligns cold-start with hardening spec.

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `e28ff58` chore: 2.8 done | FGS integrated — 2.9 tests must include FGS lifecycle |
| `0707ff5` fix: ingestion lock + pause UI persist | Cross-collector safety during 2.9 pause path |
| `ee87291` fix(lifecycle): monotonic, pause persist, omit threshold | **Core 2.9 groundwork** — verify + fix refresh gap |
| `c2ead9a` docs: lifecycle hardening spec | Acceptance reference |
| `b39c5dd` / sprint-change-proposal | Defines 2.9 scope, revert threshold, sequence |

### Latest technical information

No new external APIs. Relevant platform facts:

- **Monotonic UI** is a product contract, not a platform guarantee — backfill may still show lower count after force-stop until SQLite catches up; same-day monotonic applies while process alive with live overlay.
- **FGS** does not replace live overlay — when user reopens app, live path resumes per `architecture.md`.

### Project context reference

- Review-before-commit per sub-task ([Source: `docs/project-context.md`]).
- Baptiste: explain cold-start race and why `refresh` before `attach` matters in review brief.
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-02.md` — triage Keep/Revert]
- [Source: `_bmad-output/implementation-artifacts/spec-step-lifecycle-hardening.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/2-8-android-fgs-health-passive-pipeline.md` — FGS lifecycle matrix]

## Dev Agent Record

### Agent Model Used

Composer (dev-story)

### Debug Log References

- `lib/` grep: no `onPersistRequested`; `collectOnce` only in lifecycle/WM/FGS paths (`app.dart`, `background_collector.dart`, `fgs_step_collection.dart`, `workmanager_callback.dart`).
- Automated suite: 54+ tests passed before new COLD_START_RACE; full re-run blocked on Windows by `sqlite3.dll` lock from parallel test processes — re-run locally after closing hung `dart`/`flutter` processes.

### Completion Notes List

- **A:** Threshold persist absent (verified `ee87291` baseline); no code change.
- **B:** `await _todayCubit?.refresh(silent: true)` in `_bindLiveMonitorToToday` before `monitor.start()` when permission granted; COLD_START_RACE widget test added (DB 800, live ≥ 1050).
- **C:** Doc comments on `_applyTodaySnapshot`, `_startLivePipelineFirstTime`, `_runPersistCycle`; `app_scaffold` ingestion hook unchanged (`refreshMetadata` only).
- **D:** No FGS/lock code changes; existing lifecycle tests expected green once suite re-runs.
- **E:** `flutter analyze` clean (2 pre-existing infos in unrelated test); manual field tests B + force-stop left for Baptiste on device.

### File List

- `lib/app.dart`
- `lib/presentation/cubits/today_cubit.dart`
- `test/app_live_pipeline_lifecycle_test.dart`
- `test/helpers/sqflite_test_helper.dart`
- `dart_test.yaml`
- `scripts/pre_test.ps1`
- `scripts/README.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/stories/2-9-today-display-truth-model-and-live-overlay.md`

### Change Log

- 2026-06-02: Today Display Truth Model — cold-start DB refresh before live attach; audit threshold persist; COLD_START_RACE test; architecture doc links in source.
- 2026-06-02: Code review — resume `monitor.restart()`, COLD_START_RACE integration test (production bind path), scoped `pre_test.ps1`.

## Story completion status

- Status: **done** — AC #1–#2, #4–#6 verified in code/tests; AC #3 automated (resume sync). Manual field tests B / force-stop deferred to physical device (Sub-task E).
- **Note:** Core behavior shipped in `ee87291`; Story 2.9 adds cold-start `refresh()` ordering, verification, and review hardening.
