# Story 26.4: Cover refreshAfterDayRollover Contract

Status: in-progress

<!-- Post-audit Epic 26 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 26-4 · diagnostic-couverture-structurelle.md Top #5 · AUD-53 -->
<!-- Prerequisite: Story 26-3 done; Epic 6-6 / 25-1 (TodayCubit split) done -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **developer**,
I want `TodayCubit.refreshAfterDayRollover` covered directly,
So that midnight UI reset contracts do not rely only on day-boundary monitor tests.

## Acceptance Criteria

1. **Given** `TodayCubit.refreshAfterDayRollover`
   **When** unit tests run
   **Then** at least one test **invokes the method by name** (`cubit.refreshAfterDayRollover()`) inside a dedicated `group('refreshAfterDayRollover')` or test name containing `refreshAfterDayRollover` (AUD-53, NFR-AUD-06)
   **And** tests do **not** require a full app widget tree — reuse in-memory SQLite + `FakeTimeProvider` in `today_cubit_test.dart`

2. **Given** `TodayState` with `foregroundCatchUp: true` and/or `showCelebration: true` (stale from prior local day)
   **When** `refreshAfterDayRollover()` runs directly
   **Then** the test asserts midnight reset flags **before** SQLite refresh completes:
   - `foregroundCatchUp` → `false`
   - `catchUpTargetSteps` → `null`
   - `showCelebration` → `false`

3. **Given** cubit displayed yesterday's high step total (e.g. 5000) and SQLite holds **zero or lower** steps for the **new** local day after `clock.setNowUtc(...)` advances past midnight
   **When** `refreshAfterDayRollover()` runs directly
   **Then** emitted steps **decrease** to the new-day SQLite aggregate (`allowDayDecrease: true` contract — AUD-53)
   **And** `lastAppliedLocalDay` cache reset allows decrease (not blocked by monotonic merge from Story 2-9)

4. **Given** the same new-day setup
   **When** `refreshAfterDayRollover()` completes
   **Then** week strip is rebuilt from SQLite (`weekDays` non-empty, `selectedLocalDay` matches new local day)
   **And** refresh is **silent** (no re-emission of `TodayStatus.loading` when prior state was `progress`/`goalMet`)

5. **Given** existing day-rollover coverage in `live_step_monitor_day_rollover_test.dart` and coordinator day-boundary tests
   **When** this story ships
   **Then** coverage is **extended, not duplicated** — new named group owns AUD-53 cubit contract; monitor/coordinator tests remain green unchanged
   **And** no production changes unless a test exposes a real bug

6. **Given** OK-commit gate per `docs/project-context.md`
   **When** implementing
   **Then** split into reviewable sub-tasks (gap analysis + flag reset + allow-decrease refresh + verify) with one commit per sub-task after Baptiste approval
   **And** no version bump until Epic 26 closes

**Covers:** AUD-53 · diagnostic-couverture-structurelle.md Top #5 · Story 6-6 midnight UI contract

**Depends on:** Epic 6-6 (midnight rollover semantics), Epic 25-1 (`TodayRefreshService` extraction). Independent of 26-5…26-6.

**Out of scope:** `LifecycleDayBoundaryService.runLocalDayBoundaryImpl` orchestration (persist → monitor reset → cubit refresh — covered elsewhere); changing day-boundary production sequence; widget integration (`app_live_pipeline_lifecycle_test.dart`); version bump.

## Tasks / Subtasks

- [x] **Sub-task A — Baseline + gap analysis** (AC: #1, #5)
  - [x] Read `TodayRefreshService.refreshAfterDayRollover` + `TodayCubit` façade delegate
  - [x] Grep `test/` for `refreshAfterDayRollover` — confirm **zero** named hits (AUD-53)
  - [x] Note indirect coverage: `live_step_monitor_day_rollover_test.dart`, coordinator day-boundary sequencing — **not** cubit contract
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (plan-only commit optional)

- [ ] **Sub-task B — Named flag-reset group** (AC: #1, #2)
  - [ ] Add `group('refreshAfterDayRollover', () { ... })` in `test/presentation/cubits/today_cubit_test.dart`
  - [ ] Setup: seed goal-met steps → `refresh()` → `showCelebration: true`; add `syncSteps(..., foregroundCatchUp: true)` for catch-up flags
  - [ ] Advance clock to next local day via `clock.setNowUtc(...)` (keep `zoneOffset: +02:00`)
  - [ ] Test: `refreshAfterDayRollover clears foregroundCatchUp and dismisses celebration` — direct call; assert flags cleared
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task C — Allow-decrease SQLite refresh on new day** (AC: #3, #4)
  - [ ] Test: `refreshAfterDayRollover allows step decrease and rebuilds week strip for new local day` — yesterday 5000 steps in state, new day empty DB → steps `0` (or seeded new-day bucket); `weekDays`/`selectedLocalDay` updated
  - [ ] Optional: assert `refreshGeneration` incremented on success (Story 21-1 success-only bump policy)
  - [ ] Prefer **direct** `cubit.refreshAfterDayRollover()` entry (not only via coordinator)
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task D — Regression verification** (AC: #5, #6)
  - [ ] Run `flutter test test/presentation/cubits/today_cubit_test.dart --exclude-tags slow`
  - [ ] Run `flutter test --exclude-tags slow`
  - [ ] Grep confirms test name or group contains `refreshAfterDayRollover`
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Named unit tests for `TodayCubit.refreshAfterDayRollover` | Full day-boundary orchestration in `LifecycleDayBoundaryService` |
| Catch-up / celebration reset + allow-decrease refresh | Monitor `resetForNewLocalDay` (already tested) |
| Silent refresh + week strip rebuild on new day | Widget/integration midnight resume harness |
| Reuse `today_cubit_test.dart` SQLite FFI setup | Production logic changes unless bug found |
| OK-commit sub-task gate | Version bump (Epic 26 close) |

### Root cause (read before editing)

**Coverage gap (AUD-53):** `diagnostic-couverture-structurelle.md` Top #5 flags `refreshAfterDayRollover` as **never targeted by method name** in `test/`. Story 6-6 added monitor rollover tests and coordinator boundary sequencing; `app_live_pipeline_lifecycle_test.dart` covers resume-after-midnight at widget level — **none** invoke the cubit method directly or assert its UI-reset contract.

**Why it matters:** At local midnight, `LifecycleDayBoundaryService.runLocalDayBoundaryImpl` calls `todayCubit?.refreshAfterDayRollover()` after monitor reset. This method owns three critical UX contracts: (1) clear stale `foregroundCatchUp` so live applies resume, (2) dismiss in-flight celebration for the new day, (3) refresh SQLite with `allowDayDecrease: true` so yesterday's total does not stick on the GoalRing.

### Production call chain (MUST preserve — do not change in this story)

**Orchestrator** (`lib/core/services/lifecycle/lifecycle_day_boundary_service.dart` L110–148):

```
runLocalDayBoundaryImpl()
  → enqueuePersistCycle(enableGoalNotification: false)   // if live pipeline started
  → liveStepMonitor.resetForNewLocalDay()
  → _activeLocalDayIso = toDay
  → todayCubit.refreshAfterDayRollover()    // ← THIS STORY
  → historyCubit.refresh(silent: true)
  → myDataCubit.refresh(silent: true)
  → todayCubit.syncSteps(monitor.currentTodaySteps)      // if live pipeline started
```

**Façade** (`lib/presentation/cubits/today_cubit.dart` L140–141):

```dart
Future<void> refreshAfterDayRollover() =>
    _refresh.refreshAfterDayRollover();
```

**Implementation** (`lib/presentation/cubits/today/today_refresh_service.dart` L187–221):

```dart
Future<void> refreshAfterDayRollover() async {
  if (isClosed()) return;
  final state = getState();
  livePipelineLog('cubit', 'dayBoundary refresh', details: {...});
  if (state.foregroundCatchUp || state.showCelebration) {
    emit(state.copyWith(
      foregroundCatchUp: false,
      catchUpTargetSteps: null,
      showCelebration: false,
    ));
  }
  cache.lastAppliedLocalDay = null;
  if (cache.refreshInFlight != null) return cache.refreshInFlight!;

  cache.refreshInFlight =
      _refreshImpl(silent: true, allowDayDecrease: true);
  var succeeded = false;
  try {
    await cache.refreshInFlight!;
    succeeded = true;
  } finally {
    cache.refreshInFlight = null;
    if (succeeded) cache.refreshGeneration++;
  }
}
```

**`allowDayDecrease` path** (`today_snapshot_applier.dart` L74–96): when `allowDecrease: true`, monotonic floor is skipped — steps may drop on rollover. Normal `refresh()` / `syncSteps` keep monotonic within same local day (Story 2-9).

### Current test file state (UPDATE — read fully)

**Primary target:** `test/presentation/cubits/today_cubit_test.dart` (~1300 LOC)

| Existing test area | Covers rollover contract? | AUD-53 gap |
|--------------------|---------------------------|------------|
| `syncSteps: monotonic merge and foregroundCatchUp flow` | Catch-up mechanics only | No named method |
| `celebration triggers on goalMet...` | Celebration trigger, not rollover dismiss | No rollover path |
| `silent refresh does not re-emit loading...` | Silent refresh pattern | Different entry point |
| `live_step_monitor_day_rollover_test.dart` | Monitor reset | Not cubit |
| Coordinator day-boundary tests | Full orchestration | Indirect cubit call, no symbol grep |

**Reuse — do not reinvent:**

- `setUp` block: in-memory DB, `FakeTimeProvider(fixedNowUtc: DateTime.utc(2026, 6, 2, 12), zoneOffset: +02:00)`, `StepTestFixtures.create`
- `buildCubit()` helper (L72–86)
- `_bucket(...)` helper at file bottom for seeding ingestion buckets
- Celebration setup pattern (L280–296): goal 5000 + bucket 5000 → `refresh()` → `showCelebration: true`
- Catch-up setup (L579–588): `syncSteps(1500, foregroundCatchUp: true)`
- Clock advance: `clock.setNowUtc(DateTime.utc(2026, 6, 3, 10))` — next local day with same offset

**Suggested named group skeleton:**

```dart
group('refreshAfterDayRollover', () {
  test('refreshAfterDayRollover clears foregroundCatchUp and dismisses celebration', () async {
    await userHealthMetrics.setDailyStepGoal(5000);
    await stepRepos.ingestion.upsertIngestionBucket(
      _bucket(startTimeUtc: DateTime.utc(2026, 6, 2, 10), value: 5000, zoneOffset: '+02:00'),
    );
    final cubit = buildCubit();
    await cubit.refresh();
    expect(cubit.state.showCelebration, isTrue);

    await cubit.syncSteps(cubit.state.steps + 100, foregroundCatchUp: true);
    expect(cubit.state.foregroundCatchUp, isTrue);

    clock.setNowUtc(DateTime.utc(2026, 6, 3, 10)); // local day rolls to 2026-06-03

    await cubit.refreshAfterDayRollover();

    expect(cubit.state.foregroundCatchUp, isFalse);
    expect(cubit.state.catchUpTargetSteps, isNull);
    expect(cubit.state.showCelebration, isFalse);
    await cubit.close();
  });

  test('refreshAfterDayRollover allows step decrease and rebuilds week strip for new local day', () async {
    await stepRepos.ingestion.upsertIngestionBucket(
      _bucket(startTimeUtc: DateTime.utc(2026, 6, 2, 10), value: 5000, zoneOffset: '+02:00'),
    );
    final cubit = buildCubit();
    await cubit.refresh();
    expect(cubit.state.steps, 5000);

    clock.setNowUtc(DateTime.utc(2026, 6, 3, 10));
    // New day: no buckets yet → SQLite today = 0

    await cubit.refreshAfterDayRollover();

    expect(cubit.state.steps, 0);
    expect(cubit.state.weekDays, isNotEmpty);
    expect(
      cubit.state.selectedLocalDay,
      formatLocalDayIso(clock.snapshot()),
    );
    await cubit.close();
  });
});
```

**Test nuance:** Flag reset happens **synchronously** before `_refreshImpl` await — can assert immediately after call completes. Step decrease requires clock advance **and** empty/new-day SQLite (no bucket with timestamps on new day unless intentionally seeded).

### Architecture compliance

- **Today Display Truth Model:** Monotonic within local day; **only** rollover may decrease displayed steps [Source: spec-midnight-day-rollover-flush.md §Boundaries]
- **Single-writer ingestion:** Tests seed buckets via `stepRepos.ingestion.upsertIngestionBucket` only — never write from cubit
- **Silent refresh:** `refreshAfterDayRollover` uses `silent: true` — must not flash loading when user already sees data (mirror existing silent refresh test pattern)
- **Celebration vs notification:** Rollover clears `showCelebration` only — do not assert notification prefs here (Story 26-3)
- **NFR-AUD-06:** Unit tests with SQLite FFI fakes — no widget tree
- **Post-25-1 layering:** Logic in `TodayRefreshService`; tests call public `TodayCubit.refreshAfterDayRollover()` — do not import refresh service internals unless spying requires it

### File structure requirements

| Action | Path |
|--------|------|
| **UPDATE** | `test/presentation/cubits/today_cubit_test.dart` — add `group('refreshAfterDayRollover')` |
| **READ ONLY** | `lib/presentation/cubits/today_cubit.dart` |
| **READ ONLY** | `lib/presentation/cubits/today/today_refresh_service.dart` |
| **READ ONLY** | `lib/presentation/cubits/today/today_snapshot_applier.dart` (`allowDecrease`) |
| **READ ONLY** | `lib/core/services/lifecycle/lifecycle_day_boundary_service.dart` (caller context) |
| **DO NOT** | Change `live_step_monitor_day_rollover_test.dart` or coordinator tests unless fixing shared helper breakage |

### Testing requirements

**Default verify command:**

```bash
flutter test test/presentation/cubits/today_cubit_test.dart --exclude-tags slow
flutter test --exclude-tags slow
```

**AUD-53 verification grep:**

```bash
rg "refreshAfterDayRollover" test/presentation/cubits/today_cubit_test.dart
```

Expect: group name + test bodies calling `cubit.refreshAfterDayRollover(`.

**Assertions checklist:**

- [ ] Direct method call is the **explicit** test entry (not only coordinator boundary)
- [ ] `foregroundCatchUp` / `catchUpTargetSteps` / `showCelebration` cleared
- [ ] Steps decrease when new-day SQLite < prior displayed total
- [ ] `weekDays` rebuilt; `selectedLocalDay` matches `formatLocalDayIso(clock.snapshot())`
- [ ] No `TodayStatus.loading` flash on silent rollover refresh (optional stream spy)
- [ ] `cubit.close()` in every test (avoid leaks)

### Previous story intelligence (26-3)

- Sub-task A→D + OK-commit gate pattern — mirror for 26-4
- AUD-52/53 same class of gap: **indirect boundary behaviour vs named audit contract**
- Full fast suite green after 26-3 — extend `today_cubit_test.dart`, do not break celebration/syncSteps tests
- Tests-only expectation — no production changes unless bug exposed

### Git intelligence

Recent commits (Story 26-3):

- `09c8987` — close story 26-3 after code review
- `ccd04bf` / `e2dbac3` / `9cf8622` — named `maybeNotifyGoalReachedIfGoalMet` tests

`refreshAfterDayRollover` unchanged since Epic 25-1 split (delegates to `TodayRefreshService`) — safe to add named tests only.

### Project context reference

- OK-commit gate mandatory per sub-task — `docs/project-context.md`
- Default test command: `flutter test --exclude-tags slow`
- Version bump at **Epic 26 close** only (patch+1, build+1) — current `0.11.2+27`
- Sprint tracker: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` (not legacy `sprint-status.yaml`)

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` § Story 26-4]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-couverture-structurelle.md` § Top #5, § today_cubit table]
- [Source: `_bmad-output/implementation-artifacts/spec-midnight-day-rollover-flush.md` § persist-then-reset sequence]
- [Source: `_bmad-output/implementation-artifacts/stories/25-1-split-today-cubit-by-responsibility-boundaries.md` § refreshAfterDayRollover]
- [Source: `_bmad-output/implementation-artifacts/stories/26-3-cover-goal-notification-evaluation-and-rollback-path.md`]
- [Source: `lib/presentation/cubits/today/today_refresh_service.dart` L187–221]
- [Source: `lib/core/services/lifecycle/lifecycle_day_boundary_service.dart` L110–148]
- [Source: `test/presentation/cubits/today_cubit_test.dart` — celebration, catch-up, silent refresh patterns]
- [Source: `docs/project-context.md` § Test commands, Story completion checklist]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Sub-task A: `rg refreshAfterDayRollover test/` → 0 hits before implementation; indirect coverage in `live_step_monitor_day_rollover_test.dart` + coordinator day-boundary sequencing only.

### Completion Notes List

### File List

## Change Log
