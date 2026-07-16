# Story 21.1: Fast-Path Today Refresh for Cold Start

Status: ready-for-dev

<!-- Post-audit Epic 21 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 21-1 · diagnostic-cold-start.md §A2 · AUD-02 · NFR-AUD-01 -->
<!-- First story in Epic 21 — do NOT wire coordinator yet (that is Story 21-2) -->
<!-- Version bump: deferred to Epic 21 close (minor+1, patch=0, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want Today to load only the data needed for the first GoalRing paint,
So that I see my local steps within ~100 ms instead of waiting for week metrics and stale checks.

## Acceptance Criteria

1. **Given** cold start needs first Today paint  
   **When** `TodayCubit.refreshFastPath()` runs  
   **Then** at most **3 SQLite/prefs queries** run in the critical path: `getTodaySteps`, today’s goal (`getGoalForLocalDay` / `_resolveTodayGoal`), `getLastDisplayedSteps` (AUD-02, NFR-AUD-01)  
   **And** state emits with `lastDisplayedStepsLoaded: true` so GoalRing leaves the pulse skeleton  
   **And** activity metrics use **distance-only** live approximation (`_liveMetricsForSteps`) — walking duration / kcal may stay zero until enrichment  
   **And** `weekDays` may be empty (UI already shows a week-section spinner when empty)

2. **Given** fast path has emitted  
   **When** deferred enrichment runs  
   **Then** `_loadWeekDays`, active buckets + full `DerivedActivityMetrics.compute`, and last-ingestion / stale banner load via `unawaited` (or equivalent non-blocking schedule)  
   **And** Today Display Truth Model is preserved: SQLite aggregate remains source of truth for steps; monotonic same-day rules in `_applyTodaySnapshot` still apply  
   **And** every deferred `emit` checks `isClosed` after each `await`

3. **Given** existing Today refresh paths (`refresh` / `refreshMetadata` / `refreshAfterDayRollover`)  
   **When** this story ships  
   **Then** full refresh behaviour remains available and unchanged for non-cold-start callers  
   **And** `AppLifecycleCoordinator` is **not** switched to `refreshFastPath` yet (Story 21-2 owns that)

4. **Given** activity recognition is denied  
   **When** `refreshFastPath()` runs  
   **Then** emit `TodayStatus.noPermission` promptly (permission check is allowed; it is not one of the 3 data queries)  
   **And** do not block first paint on week-strip load (defer `_loadWeekDays` like the happy path, or emit with empty `weekDays` then enrich)

5. **Given** unit tests  
   **When** story verification runs  
   **Then** new/updated tests prove: (a) fast-path emit happens before week/buckets/ingestion queries complete, (b) ≤3 tracked data queries on the critical path, (c) `lastDisplayedStepsLoaded == true` after fast path, (d) existing `refresh()` tests still pass  
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-02 · NFR-AUD-01 · UX-AUD-01 (GoalRing can leave skeleton once prefs resolve) · diagnostic-cold-start §A2

**Depends on:** None within Epic 21 (first story). Builds on Stories 2.9 / 11.x / 15–16 Display Truth + `lastDisplayedSteps` gate.

**Out of scope:** Decoupling `_foregroundBackfill` (21-2), seeding `LiveStepMonitor` (21-3), batch `getGoalsForLocalDays` in `_loadWeekDays` (21-5 — API already exists, do **not** change N+1 here), `end_time` index (21-6), Trends ingestion guard (21-7), pedometer drain timeout (21-8), pre-`runApp` parallelization (deferred AUD-13…15), version bump.

## Tasks / Subtasks

- [x] **Sub-task A — Design `refreshFastPath` + enrichment helper** (AC: #1, #2, #4)
  - [x] Read fully: `lib/presentation/cubits/today_cubit.dart` (`refresh`, `_refreshImpl`, `_applyTodaySnapshot`, `_liveMetricsForSteps`, `_loadWeekDays`, `_refreshInFlight`)
  - [x] Read: `today_state.dart`, `goal_ring.dart` gate on `lastDisplayedStepsLoaded`, `today_screen.dart` week empty → spinner
  - [x] Design public `Future<void> refreshFastPath()` next to `refresh()` (~after L202)
  - [x] Design private enrichment (e.g. `_enrichAfterFastPath`) that loads week + buckets/metrics + stale without blocking the returned future
  - [x] Plan concurrency vs `_refreshInFlight`: fast path must not deadlock with `refresh()`; document chosen rule in code comment
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Implement fast path emit** (AC: #1, #4)
  - [x] Permission check first (same as `_refreshImpl`)
  - [x] `Future.wait` of exactly: `getTodaySteps()`, `_resolveTodayGoal()`, `getLastDisplayedSteps(todayIso)`
  - [x] Emit via `_applyTodaySnapshot` (or equivalent) with:
    - `lastDisplayedSteps` + `lastDisplayedStepsLoaded: true`
    - `weekDays: const []` (or leave empty)
    - `activityMetrics: _liveMetricsForSteps(steps)` (distance-only)
    - `isStale: false` / `lastIngestionUtc: null` until enrichment (do not invent stale=true)
  - [x] **Do not** call `_resolveSelectedLocalDay([])` — it uses `weekDays.first` and will throw on empty list; leave `selectedLocalDay` null/unset until week loads
  - [x] Schedule enrichment with `unawaited(...)` from `dart:async` (already imported)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Implement deferred enrichment** (AC: #2)
  - [x] After fast emit, load in background (may `Future.wait` internally):
    - `_loadWeekDays()`
    - `getTodayActiveBuckets()` + `getHeightCm` / `getWeightKg` → `DerivedActivityMetrics.compute` → `_toMetricsSnapshot`
    - `getLastIngestionUtc()` → `isStaleData(...)`
  - [x] Patch state with week strip, full metrics, stale banner — preserve `_todaySteps` / monotonic rules (prefer reusing `_applyTodaySnapshot` with current `_todaySteps` if live overlay advanced steps meanwhile)
  - [x] If a full `refresh()` completed meanwhile, enrichment must not regress steps or wipe live overlay (generation token / early-return if a newer refresh finished is acceptable)
  - [x] Handle `noPermission` enrichment: populate `weekDays` only
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task D — Tests** (AC: #5)
  - [ ] Extend `test/presentation/cubits/today_cubit_test.dart` and/or `today_cubit_contract_test.dart`
  - [ ] Prefer a recording/fake aggregation + settings contract that counts query calls (pattern in `today_cubit_contract_test.dart`)
  - [ ] Cases:
    1. Fast path emits ready/`progress`/`empty` with `lastDisplayedStepsLoaded: true` and empty `weekDays` before enrichment finishes
    2. Critical path does not call `getChartDailyAggregates` / `getTodayActiveBuckets` / `getLastIngestionUtc` before first emit
    3. After enrichment settles, `weekDays.length == 7` and metrics/stale match full-refresh expectations for same fixtures
    4. Concurrent `refresh()` after fast path still works (no hang on `_refreshInFlight`)
  - [ ] Run `flutter test test/presentation/cubits/today_cubit_test.dart test/presentation/cubits/today_cubit_contract_test.dart`
  - [ ] Run `flutter test --exclude-tags slow`
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| `TodayCubit.refreshFastPath()` + deferred enrichment | `AppLifecycleCoordinator` cold-start order (21-2) |
| Keep `refresh()` / `refreshMetadata()` behaviour | `LiveStepMonitor.start(seedSteps:)` (21-3) |
| Tests proving query budget + early emit | Batch goals in `_loadWeekDays` (21-5) |
| Empty `weekDays` until enrich (existing UI spinner) | Schema / indexes / Trends guards |

### Current state (read before editing)

**`_refreshImpl` today (blocking first paint):** 7 parallel queries **then** `_loadWeekDays()` (chart aggregates + 7× `getGoalForLocalDay`). Gate: GoalRing stays on skeleton until `lastDisplayedStepsLoaded` is true.

```523:580:lib/presentation/cubits/today_cubit.dart
    final results = await Future.wait<Object?>([
      stepAggregation.getTodaySteps(),
      _resolveTodayGoal(),
      stepAggregation.getLastIngestionUtc(),
      stepAggregation.getTodayActiveBuckets(),
      userHealthMetrics.getHeightCm(),
      userHealthMetrics.getWeightKg(),
      userSettings.getLastDisplayedSteps(todayIso),
    ]);
    // ...
    final weekDays = await _loadWeekDays();
    // ...
    await _applyTodaySnapshot(
      // ...
      lastDisplayedStepsLoaded: true,
    );
```

**What this story changes:** Add an alternate entry that emits after the 3 essential reads, then enriches.

**What must be preserved:**
- SQLite steps as display truth on refresh (`stepsFromDb` comment in `_refreshImpl`)
- Monotonic same-day clamping in `_applyTodaySnapshot`
- `syncSteps` early-return while `!lastDisplayedStepsLoaded` (fast path **must** set the flag so live overlay can apply)
- Full `refresh()` for pull-to-refresh / goal update / rollover / non-cold callers
- Single-writer: cubit remains **read-only** (no ingestion writes)

### Implementation sketch (guidance, not copy-paste mandate)

```dart
Future<void> refreshFastPath() async {
  if (isClosed) return;
  final granted = await _activityPermissionGranted();
  if (isClosed) return;
  if (!granted) {
    emit(const TodayState(status: TodayStatus.noPermission, weekDays: []));
    unawaited(_enrichWeekDaysOnly()); // optional
    return;
  }

  final todayIso = formatLocalDayIso(clock.snapshot());
  final results = await Future.wait<Object?>([
    stepAggregation.getTodaySteps(),
    _resolveTodayGoal(),
    userSettings.getLastDisplayedSteps(todayIso),
  ]);
  if (isClosed) return;

  final steps = results[0]! as int;
  final goal = results[1]! as int;
  final lastDisplayed = results[2] as int?;

  await _applyTodaySnapshot(
    steps: steps,
    goal: goal,
    isStale: false,
    lastIngestionUtc: null,
    weekDays: const [],
    activityMetrics: _liveMetricsForSteps(steps),
    lastDisplayedSteps: lastDisplayed,
    lastDisplayedStepsLoaded: true,
    // omit selectedLocalDay — do NOT resolve against empty weekDays
  );

  unawaited(_enrichAfterFastPath());
}
```

**Cubit + `unawaited`:** Safe to emit from deferred work on a Cubit (unlike Bloc event handlers). Still: catch errors in enrichment, check `isClosed`, and avoid silent unhandled async errors (pair `unawaited` with try/catch inside the helper).

### Concurrency / `_refreshInFlight`

Existing `refresh()` coalesces via `_refreshInFlight`. Choose one explicit policy and test it:

| Option | Behaviour |
|--------|-----------|
| **A (recommended)** | Fast path uses its own in-flight flag or none; if `refresh()` starts, enrichment no-ops when it detects a newer full refresh completed |
| **B** | Fast path participates in `_refreshInFlight` so concurrent `refresh()` awaits the same future — only if that future includes enrichment completion (would defeat “return after first paint”) |

Prefer **A**: `refreshFastPath` returns after first emit; enrichment is best-effort.

### UI expectations (no widget rewrite required)

| Surface | Fast-path state | After enrichment |
|---------|-----------------|------------------|
| GoalRing | Leaves skeleton (`lastDisplayedStepsLoaded: true`); may count-up from `lastDisplayedSteps` | Same steps unless live/backfill updates |
| Week strip | `CircularProgressIndicator` (empty `weekDays`) | 7 pills + trophy |
| Activity stats | Distance approx; duration/kcal often 0 | Full derived metrics |
| Stale banner | Hidden (`isStale: false`) until enrich | May appear if last ingestion old |

### Architecture compliance

- **Today Display Truth Model** ([Source: architecture.md § Today Display Truth Model]): SQLite daily aggregate = source of truth; live overlay separate; foreground backfill remains mandatory but **not awaited here** (21-2).
- **Cubits only** — no Riverpod / new state libraries (`flutter_bloc: ^9.1.1`).
- **Repository contracts** — keep depending on `StepAggregationRepositoryContract`, `UserSettingsRepositoryContract`, `UserHealthMetricsRepositoryContract` (Story 18-x split). Do not reintroduce concrete repos into the cubit.
- **`getGoalsForLocalDays` already exists** on the health-metrics contract — leave for Story 21-5; deferred path may keep current `_loadWeekDays` N+1 for this story.

### Project structure notes

| Path | Role |
|------|------|
| `lib/presentation/cubits/today_cubit.dart` | **UPDATE** — add `refreshFastPath` + enrichment |
| `lib/presentation/cubits/today_state.dart` | Likely unchanged |
| `lib/presentation/widgets/goal_ring.dart` | No change expected (consumes flag) |
| `lib/presentation/screens/today_screen.dart` | No change expected (empty week → spinner) |
| `lib/core/services/app_lifecycle_coordinator.dart` | **Do not modify** in 21-1 |
| `test/presentation/cubits/today_cubit_*.dart` | **UPDATE** — fast-path coverage |

### Previous / adjacent story intelligence

- **Story 2.9 / Display Truth:** SQLite truth + live overlay; do not invent a second truth source in fast path.
- **`lastDisplayedSteps` gate (c6b9f9e):** GoalRing intentionally waits for prefs — fast path’s job is to resolve prefs **early**, not remove the gate.
- **Story 18-1:** Coordinator owns cold-start order; 21-1 only exposes the API the coordinator will call in 21-2.
- **Contract tests:** Prefer fakes that assert call counts over timing-based flaky tests.

### Git intelligence

Recent relevant history on `today_cubit.dart`:
- `eaed703` / `031e57a` — split contracts injection (keep contracts)
- `c6b9f9e` — gate loading until display prefs load
- `4010061` — lastDisplayedSteps owned by TodayCubit

Pattern: small, reviewed commits per sub-task; no drive-by refactors.

### Latest tech notes

- Use `unawaited` from `dart:async` (already in file) to document fire-and-forget enrichment.
- Prefer `Future.wait` for the 3 critical queries and for independent enrichment queries.
- Do not introduce new packages.

### Project context reference

- Review-before-commit workflow: one sub-task → review brief → Baptiste OK → commit ([Source: docs/project-context.md])
- Tests: `flutter test --exclude-tags slow` for story verification
- No version bump until Epic 21 closes

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` — Story 21-1, AUD-02, NFR-AUD-01]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-cold-start.md` — §A2, C3, C4]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-etat-chargement.md` — GoalRing / week loading]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — Today Display Truth Model]
- [Source: `docs/project-context.md` — workflow, tests, versioning]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

## Change Log

- 2026-07-16: Story context created (ready-for-dev) — ultimate context engine analysis completed
