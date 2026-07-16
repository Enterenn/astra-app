# Story 21.3: Deduplicate Cold-Start getTodaySteps Queries

Status: in-progress

<!-- Post-audit Epic 21 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 21-3 · diagnostic-cold-start.md §A3 · diagnostic-acces-concurrents.md §3 · AUD-03 -->
<!-- Prerequisite: Story 21-1 (refreshFastPath) + 21-2 (coordinator fast-path bind) — both done -->
<!-- Version bump: deferred to Epic 21 close (minor+1, patch=0, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want cold start to avoid re-reading the same day aggregate repeatedly,
So that first paint is not delayed by redundant SQLite round-trips.

## Acceptance Criteria

1. **Given** `refreshFastPath()` has already loaded today's SQLite aggregate  
   **When** `_bindLiveMonitorToToday(skipSqliteRefresh: true)` runs on cold start  
   **Then** `LiveStepMonitor.start` is seeded from the fast-path result (e.g. `start(seedPersistedSteps: cubitSteps)`) and does **not** call `stepAggregation.getTodaySteps()` (AUD-03)  
   **And** the immediate post-`start` reconcile on the cold-bind path does **not** call `getTodaySteps()` again before `syncSteps` / first live overlay attach  
   **And** the cold-start bind path reduces serial `getTodaySteps` reads from **3×** (fast path + start + reconcile) to **1×** before first paint

2. **Given** resume / reattach / `foregroundCatchUp: true` monitor binds  
   **When** no authoritative seed is available (monitor stopped, or SQLite may have changed during background)  
   **Then** existing `start()` → `reconcileFromDatabase()` read behaviour remains correct  
   **And** monotonic same-day display rules are preserved (overlay never drops below prior shown total)

3. **Given** `_reconcileAfterBackfillCompletes` runs after first paint  
   **When** foreground backfill upserted new buckets  
   **Then** a full `reconcileFromDatabase()` (with DB read) **still runs** — post-backfill refresh is intentional, not a duplicate of the pre-paint seed  
   **And** `syncSteps(clampStaleDisplay: true)` may increase steps without regression

4. **Given** parallel `_foregroundBackfill` may call `reconcileFromDatabase` inside `_runPersistCycle` while bind is in flight  
   **When** this story ships  
   **Then** bind-path dedup is unchanged; do **not** weaken backfill reconcile semantics  
   **And** document in code comment that post-collect reconcile is legitimate (DB may have changed)

5. **Given** unit tests  
   **When** story verification runs  
   **Then** `live_step_monitor_test.dart` proves `start(seedPersistedSteps: N)` skips `getTodaySteps` and `currentTodaySteps` initializes to `N`  
   **And** coordinator or monitor test proves cold bind with seed performs **0** extra `getTodaySteps` between fast path and `syncSteps`  
   **And** existing `app_live_pipeline_lifecycle_test.dart` cold-start monotonic cases still pass  
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-03 · NFR-AUD-01 (fewer SQLite reads on hot path) · diagnostic-cold-start §A3 · diagnostic-acces-concurrents §3

**Depends on:** Story 21-1 (`refreshFastPath`) + Story 21-2 (`skipSqliteRefresh` cold bind) — **done**

**Out of scope:** `getBaseline` dedup (6× cold start — separate concern), batch week goals (21-5), ingestion lock retry (21-4), `end_time` index (21-6), Trends guard (21-7), pedometer drain timeout (21-8), changing `refreshFastPath` query budget, version bump.

## Tasks / Subtasks

- [x] **Sub-task A — Map duplicate reads on cold bind** (AC: #1)
  - [x] Read fully: `lib/core/services/live_step_monitor.dart` (`start` L85–115, `reconcileFromDatabase` L221–248)
  - [x] Read: `lib/core/services/app_lifecycle_coordinator.dart` (`_startLivePipelineFirstTime`, `_bindLiveMonitorToToday` L664–721)
  - [x] Confirm current count: `refreshFastPath` (1×) + `start` (1×) + `reconcileFromDatabase` on bind (1×) = **3×** before `syncSteps`; post-backfill adds 4th after paint
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (docs-only map if no code yet)

- [ ] **Sub-task B — Add seed API to LiveStepMonitor** (AC: #1, #2)
  - [ ] Extend `start({int? seedPersistedSteps})` — when non-null, assign `_persistedTodaySteps = seedPersistedSteps` instead of `await stepAggregation.getTodaySteps()`
  - [ ] Extend `reconcileFromDatabase({int? seedPersistedSteps})` — when non-null, skip DB read for persisted total; still run `_syncMemoryBaselineFromRepository()`, monotonic floor, `_trackedLocalDay`, `_emitNow`
  - [ ] Keep `_syncMemoryBaselineFromRepository()` in `start()` before seed assignment (baseline still required for live delta)
  - [ ] Log seed usage in `livePipelineLog` details for cold-start diagnostics
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task C — Wire coordinator cold bind seed** (AC: #1, #3, #4)
  - [ ] In `_bindLiveMonitorToToday`, when `skipSqliteRefresh: true` and cubit has painted steps: capture `final seed = _todayCubit?.state.steps` (after 21-2, fast path already ran)
  - [ ] Call `await monitor.start(seedPersistedSteps: seed)` then `await monitor.reconcileFromDatabase(seedPersistedSteps: seed)` on cold bind only
  - [ ] Resume / `foregroundCatchUp` / `skipSqliteRefresh: false` paths: pass **no** seed — full DB reads unchanged
  - [ ] Do **not** pass seed into `_reconcileAfterBackfillCompletes` — always full reconcile after backfill
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task D — Tests** (AC: #5)
  - [ ] `test/core/services/live_step_monitor_test.dart`: recording fake or call-count wrapper on `StepAggregationRepository` — assert `start(seedPersistedSteps: 42)` leaves `getTodaySteps` call count at 0; `reconcileFromDatabase(seedPersistedSteps: 42)` also skips read
  - [ ] `test/core/services/live_step_monitor_test.dart`: unseeded `start()` + `reconcileFromDatabase()` still reads DB (regression guard)
  - [ ] Extend `test/core/services/app_lifecycle_coordinator_test.dart`: `_CountingStepAggregation` implementing contract with `getTodayStepsCallCount`; cold start with `skipSqliteRefresh` path → assert count == **1** before `syncSteps` completes (only fast path read)
  - [ ] Run: `flutter test test/core/services/live_step_monitor_test.dart test/core/services/app_lifecycle_coordinator_test.dart`
  - [ ] Run: `flutter test --exclude-tags slow`
  - [ ] If monotonic tests fail, fix seed/reconcile monotonic floor — do not weaken Display Truth rules
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| `LiveStepMonitor.start` / `reconcileFromDatabase` optional seed | `getBaseline` dedup (6×) |
| Coordinator passes fast-path steps on cold bind | `TodayCubit.refreshFastPath` changes |
| Tests proving bind-path query reduction | Parallel backfill `_runPersistCycle` reconcile |
| Post-backfill full reconcile preserved | Batch goals (21-5), indexes (21-6) |

### Current state (read before editing)

**After Stories 21-1 + 21-2, cold-start bind still re-reads SQLite twice:**

```85:91:lib/core/services/live_step_monitor.dart
  Future<void> start() async {
    if (_running) {
      return;
    }
    await _syncMemoryBaselineFromRepository();
    _persistedTodaySteps = await stepAggregation.getTodaySteps();
```

```674:678:lib/core/services/app_lifecycle_coordinator.dart
    if (!monitor.isRunning) {
      await monitor.start();
      await monitor.reconcileFromDatabase();
    }
```

**Fast path already read the same aggregate:**

```253:257:lib/presentation/cubits/today_cubit.dart
    final results = await Future.wait<Object?>([
      stepAggregation.getTodaySteps(),
      _resolveTodayGoal(),
      userSettings.getLastDisplayedSteps(todayIso),
    ]);
```

**Diagnostic baseline (pre-21-2):** 4× serial `getTodaySteps` on cold start [Source: `diagnostic-acces-concurrents.md` §3]. After 21-2 removed redundant `refresh(silent)` on bind, remaining duplicates are **monitor `start` + `reconcileFromDatabase`** (2×) atop fast path (1×).

### Target sequence (diagnostic §A3)

1. `await refreshFastPath()` — **authoritative** `getTodaySteps` read #1; cubit `state.steps` holds SQLite truth
2. `monitor.start(seedPersistedSteps: cubit.state.steps)` — **no** `getTodaySteps`
3. `monitor.reconcileFromDatabase(seedPersistedSteps: cubit.state.steps)` — **no** `getTodaySteps`; baseline sync + monotonic floor + emit
4. `syncSteps(monitor.currentTodaySteps)` — live overlay attach
5. Later: `_reconcileAfterBackfillCompletes` → full `reconcileFromDatabase()` — **allowed** DB read after paint

### Implementation sketch (guidance)

```dart
// live_step_monitor.dart
Future<void> start({int? seedPersistedSteps}) async {
  if (_running) return;
  await _syncMemoryBaselineFromRepository();
  _persistedTodaySteps = seedPersistedSteps ??
      await stepAggregation.getTodaySteps();
  _trackedLocalDay = formatLocalDayIso(clock.snapshot());
  _running = true;
  // ... subscription unchanged
}

Future<void> reconcileFromDatabase({int? seedPersistedSteps}) async {
  final todayIso = formatLocalDayIso(clock.snapshot());
  final crossDay = _trackedLocalDay != null && _trackedLocalDay != todayIso;
  final floorDisplay = crossDay ? 0 : currentTodaySteps;
  _persistedTodaySteps = seedPersistedSteps ??
      await stepAggregation.getTodaySteps();
  await _syncMemoryBaselineFromRepository();
  // ... existing monotonic floor + emit unchanged
}
```

```dart
// app_lifecycle_coordinator.dart — inside _bindLiveMonitorToToday
final seedSteps = skipSqliteRefresh ? _todayCubit?.state.steps : null;
if (!monitor.isRunning) {
  await monitor.start(seedPersistedSteps: seedSteps);
  await monitor.reconcileFromDatabase(seedPersistedSteps: seedSteps);
}
```

**Seed source:** `_todayCubit!.state.steps` after `refreshFastPath()` — do **not** add a second `getTodaySteps` in coordinator to obtain seed. Optional: assert `lastDisplayedStepsLoaded == true` when `skipSqliteRefresh` (debug-only).

### Concurrency cautions

| Risk | Mitigation |
|------|------------|
| Backfill upserts between fast path and bind (ms window) | Post-backfill `_reconcileAfterBackfillCompletes` full reconcile corrects monitor + cubit |
| Seed stale vs parallel `_runPersistCycle` reconcile | Backfill reconcile runs on stopped or reconciling monitor — bind seed is best-effort pre-paint; post-backfill is authoritative |
| `seedPersistedSteps` lower than monitor `currentTodaySteps` mid-day | Monotonic floor in `reconcileFromDatabase` preserves `floorDisplay`; seed should match cubit SQLite truth |
| Resume without seed | `seedSteps == null` → full DB reads — unchanged behaviour |
| Hot-reload cubit recreate | `_livePipelineStarted` guard; if pipeline re-starts, fast path re-runs before bind |

### UI expectations (no widget changes)

| Phase | User sees |
|-------|-----------|
| After fast path | Same as 21-2 — GoalRing shows SQLite steps |
| After seeded bind | Same step count; live overlay may attach without extra SQLite delay |
| After backfill | Steps may tick up via post-backfill reconcile — no downward flicker |

### Architecture compliance

- **Today Display Truth Model** ([Source: `architecture.md` § Today Display Truth Model]): SQLite aggregate = source of truth; seed propagates cubit SQLite truth into monitor `_persistedTodaySteps` without inventing a second truth source.
- **LiveStepMonitor never writes buckets** — seed is read-only propagation; `BackgroundCollector` remains sole writer.
- **Monotonic same-day display** — `reconcileFromDatabase` floor logic must run even with seed (pending delta reset rules unchanged).
- **Coordinator owns orchestration** — changes in `app_lifecycle_coordinator.dart` + `live_step_monitor.dart`; do not move seed logic into `TodayCubit` unless returning steps from `refreshFastPath()` is cleaner (optional `int` return — dev choice, not required).

### Project structure notes

| Path | Role |
|------|------|
| `lib/core/services/live_step_monitor.dart` | **UPDATE** — `start` + `reconcileFromDatabase` optional seed |
| `lib/core/services/app_lifecycle_coordinator.dart` | **UPDATE** — pass seed on `skipSqliteRefresh` cold bind |
| `lib/presentation/cubits/today_cubit.dart` | **Do not modify** — consume `state.steps` as seed source |
| `test/core/services/live_step_monitor_test.dart` | **UPDATE** — seed skips DB read |
| `test/core/services/app_lifecycle_coordinator_test.dart` | **UPDATE** — counting aggregation cold-start bind |
| `test/app_live_pipeline_lifecycle_test.dart` | **Verify** — monotonic cold-start cases |

### Previous story intelligence (21-1 + 21-2)

- **21-1:** `refreshFastPath()` returns after first emit; `state.steps` = SQLite aggregate from single `getTodaySteps`. Generation guards prevent stale enrichment — seed should be read immediately after `await refreshFastPath()` in coordinator, not from stale closure.
- **21-2:** `_bindLiveMonitorToToday(skipSqliteRefresh: true)` skips `refresh(silent: true)` — monitor bind is now the duplicate-read hotspot this story fixes.
- **21-2 review M1:** Post-backfill reconcile scheduled **after** bind — monitor guaranteed `isRunning` when reconcile resumes. Do not reorder; seed only affects pre-paint bind.
- **21-2:** `_reconcileAfterBackfillCompletes` uses full `reconcileFromDatabase()` + `syncSteps` — keep full DB read there.

### Git intelligence

Recent Epic 21 commits (coordinator cold-start):
- `153c93e` — post-backfill reconcile after monitor bind
- `de9e3ce` / `117f789` / `25996ee` / `a3d6163` — fast path ordering + skip redundant refresh

Pattern: small commits per sub-task; monitor API change isolated from cubit.

### Latest tech notes

- No new packages or Flutter API changes.
- Optional named parameter on `start` / `reconcileFromDatabase` is backward-compatible — all existing call sites pass nothing → current behaviour.
- Prefer call-count fakes over timing-based tests ([Source: 21-1 contract test pattern]).

### Project context reference

- OK-commit gate: one sub-task → review brief → Baptiste OK → commit ([Source: `docs/project-context.md`])
- Tests: `flutter test --exclude-tags slow`
- No version bump until Epic 21 closes

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` — Story 21-3, AUD-03]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-cold-start.md` — §A3]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-acces-concurrents.md` — §3, duplicate table]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — Today Display Truth Model]
- [Source: `_bmad-output/implementation-artifacts/stories/21-2-decouple-foreground-backfill-from-first-today-paint.md` — bind sequence, skipSqliteRefresh]
- [Source: `_bmad-output/implementation-artifacts/stories/21-1-fast-path-today-refresh-for-cold-start.md` — fast path query budget]
- [Source: `docs/project-context.md` — workflow, tests, versioning]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- Sub-task A: Confirmed 3× getTodaySteps before first paint — fast path (read #1, authoritative) + monitor.start (read #2, dup) + reconcileFromDatabase on bind (read #3, dup). Post-backfill reconcile (#4, intentional). No code changes in this sub-task.

### File List

## Change Log

- 2026-07-16: Story context created (ready-for-dev) — ultimate context engine analysis completed
