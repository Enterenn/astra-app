# Story 21.2: Decouple Foreground Backfill from First Today Paint

Status: review

<!-- Post-audit Epic 21 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 21-2 · diagnostic-cold-start.md §A1 · AUD-01 · NFR-AUD-01 -->
<!-- Prerequisite: Story 21-1 (refreshFastPath API) — done -->
<!-- Version bump: deferred to Epic 21 close (minor+1, patch=0, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want to see my stored steps before background catch-up finishes,
So that cold start is never blocked 1–2 s on ingestion backfill.

## Acceptance Criteria

1. **Given** first live-pipeline start (`_startLivePipelineFirstTime`)  
   **When** cold-start orchestration runs with `enableLiveStepPipeline: true`  
   **Then** `await _todayCubit?.refreshFastPath()` completes **before** any `await _foregroundBackfill` on the critical path (AUD-01)  
   **And** `_foregroundBackfill` is **not awaited** before first Today paint — it may already be running from `bindToWidget`; do not block on it  
   **And** `_logColdStartReadyIfNeeded()` may fire after fast-path emit (status ≠ `loading`, `lastDisplayedStepsLoaded == true`)

2. **Given** fast path has painted SQLite data  
   **When** `_bindLiveMonitorToToday()` runs on cold start  
   **Then** the coordinator does **not** call `refresh(silent: true)` again (fast path already loaded SQLite truth)  
   **And** `monitor.start()` → `reconcileFromDatabase()` → `attachLiveMonitor` → `syncSteps(clampStaleDisplay: true)` still run in order  
   **And** Today Display Truth Model is preserved: monotonic same-day display; live overlay never drops below SQLite + monitor reconcile

3. **Given** `_foregroundBackfill` completes after first paint  
   **When** backfill upserts new buckets  
   **Then** Today step count may increase via post-backfill reconcile (non-blocking) — e.g. `unawaited(_foregroundBackfill.then(...))` that reconciles monitor + `syncSteps` or `refresh(silent: true)` when mounted  
   **And** display must not regress (no flicker below prior shown steps within the same local day)

4. **Given** Story 21-1 is done  
   **When** this story ships  
   **Then** coordinator calls **`refreshFastPath()`** — no duplicate 3-query load path invented in the coordinator  
   **And** `TodayCubit.refresh()` / `refreshMetadata()` remain unchanged for resume, pull-to-refresh, and non-cold callers

5. **Given** `enableLiveStepPipeline: false`  
   **When** `onTodayCubitReady` runs `_initialTodayRefresh`  
   **Then** existing behaviour is unchanged (still `await _foregroundBackfill` then `refresh()`) — out of scope unless trivially safe

6. **Given** unit / integration tests  
   **When** story verification runs  
   **Then** at least one test proves fast-path emit (`lastDisplayedStepsLoaded: true`, status ≠ `loading`) occurs **before** a delayed backfill future completes  
   **And** existing `app_live_pipeline_lifecycle_test.dart` cold-start monotonic cases still pass  
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-01 · NFR-AUD-01 · UX-AUD-01 (GoalRing leaves skeleton once fast path runs) · diagnostic-cold-start §A1

**Depends on:** Story 21-1 (`refreshFastPath` + enrichment) — **done**

**Out of scope:** `LiveStepMonitor.start(seedSteps:)` dedup (21-3), batch week goals (21-5), pedometer drain timeout on cold backfill (21-8), `AppScaffold._initialRefresh` refactor, version bump, Trends ingestion guard (21-7).

## Tasks / Subtasks

- [x] **Sub-task A — Map current cold-start gate** (AC: #1)
  - [x] Read fully: `lib/core/services/app_lifecycle_coordinator.dart` — `bindToWidget`, `onTodayCubitReady`, `_startLivePipelineFirstTime`, `_bindLiveMonitorToToday`, `_initialTodayRefresh`
  - [x] Confirm: `_foregroundBackfill` starts at `bindToWidget` (L180–184); `_startLivePipelineFirstTime` currently **awaits** it (L609) before any Today paint
  - [x] Confirm: `_bindLiveMonitorToToday` calls `refresh(silent: true)` (L655) — redundant after fast path
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (docs-only / comment map if no code yet)

- [x] **Sub-task B — Reorder `_startLivePipelineFirstTime`** (AC: #1, #4)
  - [x] At start of `_startLivePipelineFirstTime`: `await _todayCubit?.refreshFastPath()` when permission will be checked downstream (fast path handles denied permission itself)
  - [x] Remove blocking `await _foregroundBackfill` from critical path
  - [x] Move `_logColdStartPhase('cold start backfill DONE')` to async backfill completion (e.g. `unawaited(_foregroundBackfill.then((upserted) { ... }))`) — log only, do not block UI
  - [x] Proceed to `_bindLiveMonitorToToday` with cold-start skip flag (Sub-task C)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Skip redundant SQLite refresh on cold bind** (AC: #2)
  - [x] Add parameter to `_bindLiveMonitorToToday` e.g. `{bool sqliteAlreadyPainted = false}` or `{bool skipSqliteRefresh = false}`
  - [x] When `skipSqliteRefresh` / `sqliteAlreadyPainted`: skip `await _todayCubit?.refresh(silent: true)` block (L654–656)
  - [x] Cold-start call site: pass `skipSqliteRefresh: true` after successful `refreshFastPath`
  - [x] Resume path (`foregroundCatchUp: true`) and permission-denied branch: **unchanged** (still use full `refresh()` where today)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Post-backfill reconcile (non-blocking)** (AC: #3)
  - [x] Schedule `unawaited(_foregroundBackfill.then((_) async { ... }))` from `_startLivePipelineFirstTime` after fast paint
  - [x] On completion + `_mounted()`: if monitor running, `reconcileFromDatabase()` then `syncSteps` (or `refresh(silent: true)` only if monitor not yet attached — prefer monitor path)
  - [x] Guard: monotonic rules in `TodayCubit.syncSteps` / `_applyTodaySnapshot` must prevent regression
  - [x] Do not duplicate `_onIngestionComplete` work (AppScaffold already refreshes metadata/history on upsert)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Tests** (AC: #6)
  - [x] Extend `test/core/services/app_lifecycle_coordinator_test.dart` with delaying collector + recording/mocked `TodayCubit` or spy on `refreshFastPath` call order vs backfill end
  - [x] Pattern: reuse `_DelayingBackgroundCollector` from existing coordinator test (50ms+ delay)
  - [x] Assert: `refreshFastPath` completes / cubit leaves `loading` before backfill `onCollectEnd`
  - [x] Run targeted: `flutter test test/core/services/app_lifecycle_coordinator_test.dart`
  - [x] Run: `flutter test --exclude-tags slow`
  - [x] If cold-start monotonic tests fail, adjust post-backfill reconcile — do not weaken Display Truth rules
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

### Review Findings

- (empty — populated during code review)

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Reorder `_startLivePipelineFirstTime` cold-start sequence | `TodayCubit.refreshFastPath` implementation (21-1 done) |
| Skip redundant `refresh(silent)` on cold bind | `seedSteps` on monitor start (21-3) |
| Non-blocking post-backfill reconcile | `AppScaffold._initialRefresh` (unawaited no-op wait) |
| Coordinator unit tests for ordering | Full `<100 ms` perf benchmark (NFR is directional) |

### Current state (read before editing)

**Cold-start sequence today (blocks 1–2 s):**

```605:631:lib/core/services/app_lifecycle_coordinator.dart
  Future<void> _startLivePipelineFirstTime() async {
    if (!enableLiveStepPipeline) {
      return;
    }
    await _foregroundBackfill;
    _logColdStartPhase('cold start backfill DONE');
    if (!_mounted()) {
      return;
    }
    await _bindLiveMonitorToToday();
    // ...
  }
```

**Backfill starts early (parallel-capable) but pipeline awaits it:**

```180:184:lib/core/services/app_lifecycle_coordinator.dart
    _foregroundBackfill = enableLiveStepPipeline
        ? _runPersistCycle(enableGoalNotification: false)
        : deps.backgroundCollector.collectOnce(
            enableGoalNotification: false,
          );
```

**Bind path re-reads SQLite via full refresh (7+ queries):**

```653:656:lib/core/services/app_lifecycle_coordinator.dart
    // SQLite daily sum before live overlay (Today Display Truth Model).
    if (!foregroundCatchUp) {
      await _todayCubit?.refresh(silent: true);
    }
```

**Entry from cubit ready:**

```193:199:lib/core/services/app_lifecycle_coordinator.dart
  void onTodayCubitReady(TodayCubit cubit) {
    _todayCubit = cubit;
    if (enableLiveStepPipeline) {
      unawaited(_ensureLivePipelineAttached());
    } else {
      unawaited(_initialTodayRefresh());
    }
  }
```

### Target sequence (diagnostic §A1)

1. `await _todayCubit?.refreshFastPath()` — first paint (~3 queries, enrichment unawaited)
2. Do **not** `await _foregroundBackfill` on critical path (already running from `bindToWidget`)
3. `_bindLiveMonitorToToday(skipSqliteRefresh: true)` — monitor attach + live overlay
4. `unawaited(_foregroundBackfill.then(...))` — post-backfill reconcile without blocking step 1–3

Reference: `_bmad-output/planning-artifacts/audits/diagnostic-cold-start.md` lines 196–204.

### Implementation sketch (guidance)

```dart
Future<void> _startLivePipelineFirstTime() async {
  if (!enableLiveStepPipeline) return;

  await _todayCubit?.refreshFastPath();
  if (!_mounted()) return;

  unawaited(_reconcileAfterBackfillCompletes());

  await _bindLiveMonitorToToday(skipSqliteRefresh: true);
  if (!_mounted()) return;

  _livePipelineStarted = true;
  // existing logging, day-boundary wiring, persist timers...
}

Future<void> _reconcileAfterBackfillCompletes() async {
  try {
    await _foregroundBackfill;
    _logColdStartPhase('cold start backfill DONE');
    if (!_mounted()) return;
    final monitor = deps.liveStepMonitor;
    if (monitor.isRunning) {
      await monitor.reconcileFromDatabase();
      await _todayCubit?.syncSteps(
        monitor.currentTodaySteps,
        clampStaleDisplay: true,
      );
    }
  } catch (_) {
    // backfill failure must not crash app; stale SQLite from fast path remains
  }
}
```

Extract helper name/structure is dev choice — keep logic in coordinator file unless Story 25 split is imminent.

### Concurrency cautions

| Risk | Mitigation |
|------|------------|
| Fast path + bind `syncSteps` race with in-flight backfill | `syncSteps` monotonic clamp; post-backfill reconcile runs once backfill future completes |
| Double `refreshFastPath` if hot-reload recreates cubit | `_livePipelineStarted` guard unchanged — first time only |
| `_foregroundBackfill` already complete before fast path | `.then` on completed future runs immediately — OK if reconcile is idempotent |
| Permission denied | `refreshFastPath` emits `noPermission`; `_bindLiveMonitorToToday` already short-circuits to `refresh()` — keep that branch |

### UI expectations (no widget changes)

| Phase | User sees |
|-------|-----------|
| After `refreshFastPath` | GoalRing shows SQLite steps; week strip spinner (empty `weekDays`) |
| During backfill (background) | Same steps; no full-screen loading gate |
| After monitor bind | Live overlay may increment steps; count-up from `lastDisplayedSteps` |
| After backfill completes | Steps may tick up if DB had new buckets; no downward flicker |

### Architecture compliance

- **Today Display Truth Model** ([Source: architecture.md § Today Display Truth Model]): SQLite aggregate = source of truth; live overlay = bonus; foreground backfill = mandatory recovery but **must not gate first paint** (this story).
- **Coordinator owns orchestration** ([Source: Story 18-1]): changes stay in `app_lifecycle_coordinator.dart`; do not move cold-start logic back into `app.dart`.
- **Cubits read-only on Today path**: coordinator must not write ingestion buckets directly.
- **`unawaited`**: already imported via `dart:async` in coordinator — use for backfill `.then` and existing patterns.

### Project structure notes

| Path | Role |
|------|------|
| `lib/core/services/app_lifecycle_coordinator.dart` | **UPDATE** — reorder cold start, skip redundant refresh, post-backfill hook |
| `lib/presentation/cubits/today_cubit.dart` | **Do not modify** — consume `refreshFastPath()` only |
| `lib/presentation/screens/app_scaffold.dart` | **Do not modify** — `_initialRefresh` awaits backfill but is fire-and-forget from `initState` |
| `test/core/services/app_lifecycle_coordinator_test.dart` | **UPDATE** — ordering test |
| `test/app_live_pipeline_lifecycle_test.dart` | **Verify** — no regression on cold-start monotonic cases |

### Previous story intelligence (21-1)

- `refreshFastPath()` returns after first emit; enrichment is `unawaited(_enrichAfterFastPath(generation))`.
- Generation guard (`_refreshGeneration`) aborts stale enrichment — post-backfill `refresh(silent)` or `syncSteps` must not fight enrichment; prefer `syncSteps` from monitor reconcile after backfill.
- Fast path sets `lastDisplayedStepsLoaded: true` and `skipCelebration: true` — monitor bind + `syncSteps` can apply live overlay immediately after.
- Empty `weekDays` until enrichment — UI already shows week spinner; no scaffold changes needed.
- Code review added enrich failure fallback `unawaited(refresh())` — coordinator post-backfill path should not trigger unnecessary full refresh if syncSteps suffices.

### Git intelligence

Recent Epic 21 commits:
- `0c3a4fb` — harden `refreshFastPath` after code review (generation guards, tests)
- `b6991ac` / `e00ac60` — fast path + enrichment implementation

Pattern: small commits per sub-task; coordinator change should be isolated from cubit.

### Latest tech notes

- No new packages.
- Prefer extending existing `_DelayingBackgroundCollector` test pattern over widget timing flakes.
- `flutter test --exclude-tags slow` for story gate; run `app_live_pipeline_lifecycle_test.dart` only if Sub-task D touches reconcile semantics (tagged `slow`).

### Project context reference

- OK-commit gate: one sub-task → review brief → Baptiste OK → commit ([Source: docs/project-context.md])
- Tests default: `flutter test --exclude-tags slow`
- No version bump until Epic 21 closes

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` — Story 21-2, AUD-01, NFR-AUD-01]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-cold-start.md` — §A1, Phase A]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-acces-concurrents.md` — backfill vs pipeline sequencing]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — Today Display Truth Model]
- [Source: `_bmad-output/implementation-artifacts/stories/21-1-fast-path-today-refresh-for-cold-start.md` — API contract]
- [Source: `docs/project-context.md` — workflow, tests, versioning]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- Sub-task A: Cold-start gate mapped — backfill starts L180, blocks at L609; bind re-reads SQLite L655; `refreshFastPath` ready but unused.
- Sub-task B: `_startLivePipelineFirstTime` calls `refreshFastPath()` first; backfill log moved to `unawaited(whenComplete)`.
- Sub-task C: `skipSqliteRefresh` on cold bind — avoids duplicate 7+ query refresh after fast path.
- Sub-task D: `_reconcileAfterBackfillCompletes` — monitor reconcile + syncSteps after backfill, non-blocking.
- Sub-task E: Ordering test — fast path emits before 150ms delayed backfill; `flutter test --exclude-tags slow` green (841 tests).
### File List

- `lib/core/services/app_lifecycle_coordinator.dart`
- `test/core/services/app_lifecycle_coordinator_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`
- `_bmad-output/implementation-artifacts/stories/21-2-decouple-foreground-backfill-from-first-today-paint.md`

## Change Log

- 2026-07-16: Sub-task A — cold-start gate mapped (ready-for-dev → in-progress)
- 2026-07-16: Story implementation complete — cold start decoupled from backfill gate (status: review)
