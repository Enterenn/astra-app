# Story 26.1: Cover onTodayCubitReady Cold-Start Orchestration

Status: in-progress

<!-- Post-audit Epic 26 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 26-1 · diagnostic-couverture-structurelle.md Top #2 · AUD-50 · NFR-AUD-06 -->
<!-- Prerequisite: Epic 21 cold-start stories done; Epic 25-2 coordinator split done -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **developer**,
I want `AppLifecycleCoordinator.onTodayCubitReady` tested by name,
So that cold-start live-pipeline attachment regressions are caught without relying on widget-only coverage.

## Acceptance Criteria

1. **Given** `AppLifecycleCoordinator.onTodayCubitReady`
   **When** unit/orchestration tests run
   **Then** at least one test **invokes the method by name** (`coordinator.onTodayCubitReady(...)`) inside a dedicated `group('onTodayCubitReady')` or test name containing `onTodayCubitReady` (AUD-50, NFR-AUD-06)
   **And** tests do **not** require a full app widget tree — use `buildCoordinatorUnitTestDeps` + contract fakes

2. **Given** `enableLiveStepPipeline: true` (production default) and `bindToWidget(..., initialShowMainShell: true)` already called
   **When** `onTodayCubitReady(todayCubit)` runs
   **Then** the test asserts cold-start **sequencing** (order matters):
   - `todayCubit` is bound on session (`coordinator` holds cubit — observable via side effects)
   - **Fast path** completes before foreground backfill ends (`lastDisplayedStepsLoaded == true`, status not `loading`) — regression guard for Epic 21-1/21-2
   - **Monitor bind** occurs after fast path (`LiveStepMonitor.start` / `reconcileFromDatabase` with seed from fast-path steps when `skipSqliteRefresh: true`) — regression guard for Epic 21-3/AUD-03
   - **Backfill reconcile** runs after `foregroundBackfill` completes (monitor reconcile + `syncSteps` or silent refresh path)

3. **Given** `enableLiveStepPipeline: false` (tests / permission-denied shell path)
   **When** `onTodayCubitReady(todayCubit)` runs
   **Then** a named test asserts the **non-live branch**: `initialTodayRefresh` path — waits `foregroundBackfill`, then `TodayCubit.refresh()` (no monitor attach required)
   **And** monitor is **not** started by this path

4. **Given** existing Epic 21 cold-start tests in `app_lifecycle_coordinator_test.dart`
   **When** this story ships
   **Then** coverage is **consolidated or extended** — do not duplicate identical assertions; prefer a focused `group('onTodayCubitReady')` that owns AUD-50 contract
   **And** prior behavioural tests (`live cold start paints Today before foreground backfill completes`, seed/bind dedup) remain green

5. **Given** OK-commit gate per `docs/project-context.md`
   **When** implementing
   **Then** split into reviewable sub-tasks (named group + live pipeline sequencing + non-live branch + verify) with one commit per sub-task after Baptiste approval
   **And** no version bump until Epic 26 closes

**Covers:** AUD-50 · NFR-AUD-06 · diagnostic-couverture-structurelle.md Top #2

**Depends on:** Epic 21 (21-1…21-8), Epic 25-2 (coordinator split). Independent of 26-2…26-6.

**Out of scope:** `onLifecycleStateResumed` failure tests (26-2); widget/integration harness (`app_live_pipeline_lifecycle_test.dart`); changing production orchestration logic; version bump.

## Tasks / Subtasks

- [x] **Sub-task A — Baseline + gap analysis** (AC: #1, #4)
  - [x] Read `onTodayCubitReady` façade + `LifecycleLivePipelineService.startLivePipelineFirstTime` / `initialTodayRefresh`
  - [x] Grep `test/` for `onTodayCubitReady` — note existing indirect coverage in `app_lifecycle_coordinator_test.dart` L432, L518, L622
  - [x] Confirm diagnostic gap is **naming/contract**, not total absence of behaviour tests
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (plan-only commit optional)

- [x] **Sub-task B — Named `onTodayCubitReady` live-pipeline group** (AC: #1, #2)
  - [x] Add `group('onTodayCubitReady', () { ... })` in `test/core/services/app_lifecycle_coordinator_test.dart`
  - [x] Test: `onTodayCubitReady runs refreshFastPath before backfill completes` — reuse `_DelayingBackgroundCollector` + event ordering pattern from existing test L372–445
  - [x] Test: `onTodayCubitReady binds monitor with fast-path seed without extra getTodaySteps on bind` — reuse `_SeedCapturingMonitor` + `_CountingStepAggregation` pattern from L448–545
  - [x] Test: `onTodayCubitReady reconciles after foregroundBackfill completes` — assert post-backfill monitor reconcile / cubit steps sync
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Non-live pipeline branch** (AC: #3)
  - [x] Test: `onTodayCubitReady with enableLiveStepPipeline false waits backfill then refreshes Today` — `bindToWidget(enableLiveStepPipeline: false)`, spy/monitor `isRunning` stays false, cubit reaches loaded state via `refresh()`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task D — Regression verification** (AC: #4, #5)
  - [ ] Run `flutter test test/core/services/app_lifecycle_coordinator_test.dart --exclude-tags slow`
  - [ ] Run `flutter test --exclude-tags slow` (full fast suite)
  - [ ] Grep confirms test name or group contains `onTodayCubitReady`
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Named unit tests for `onTodayCubitReady` | Resume pipeline / `onLifecycleStateResumed` (26-2) |
| Assert attach/backfill/bind sequencing via fakes | Full-app widget test harness |
| Live + non-live (`enableLiveStepPipeline`) branches | Production logic changes unless test exposes bug |
| Reuse existing test doubles in coordinator test file | New test helper package / broad refactor |
| OK-commit sub-task gate | Version bump (Epic 26 close) |

### Root cause (read before editing)

**Coverage gap (AUD-50):** `diagnostic-couverture-structurelle.md` Top #2 flags `onTodayCubitReady` as never targeted **by method name** in `test/`. Epic 21 added behavioural cold-start tests that **call** the method but use descriptive names (`live cold start paints Today…`) — CI grep for the symbol still fails the audit contract.

**Why it matters:** `onTodayCubitReady` is the sole UI entry point for cold-start live pipeline attach. Regressions in order (`refreshFastPath` → bind → backfill reconcile) cause monotonicity bugs, duplicate SQLite reads, or blank GoalRing — historically fixed across Epic 21.

### Production call chain (MUST preserve — do not change in this story)

```
AppScaffold.initState → widget.onTodayCubitReady?.call(_todayCubit)
  → AstraApp._onTodayCubitReady → coordinator.onTodayCubitReady(cubit)
```

**Façade** (`lib/core/services/app_lifecycle_coordinator.dart` L134–141):

```dart
void onTodayCubitReady(TodayCubit cubit) {
  _session.todayCubit = cubit;
  if (enableLiveStepPipeline) {
    unawaited(_livePipeline.ensureLivePipelineAttached());
  } else {
    unawaited(_livePipeline.initialTodayRefresh());
  }
}
```

**Live path** (`LifecycleLivePipelineService.startLivePipelineFirstTime` — `lib/core/services/lifecycle/lifecycle_live_pipeline_service.dart` L201–227):

1. `await session.todayCubit?.refreshFastPath()` — SQLite fast paint (Epic 21-1)
2. `await bindLiveMonitorToToday(skipSqliteRefresh: true)` — seed monitor from cubit steps, attach live overlay (21-3)
3. `unawaited(reconcileAfterBackfillCompletes())` — after `session.foregroundBackfill`, reconcile + `syncSteps` (21-2)
4. Side effects: `livePipelineStarted = true`, wire day-boundary + persist timers

**Parallel backfill:** `bindToWidget(..., enableLiveStepPipeline: true)` sets `session.foregroundBackfill` to persist cycle with `sourceTimeout: Duration.zero` (21-8/AUD-05).

**Non-live path** (`initialTodayRefresh` L139–147): await backfill → `todayCubit.refresh()` → cold-start ready log.

### Current test file state (UPDATE — read fully)

**Primary target:** `test/core/services/app_lifecycle_coordinator_test.dart` (~646 LOC)

| Existing test | Calls `onTodayCubitReady`? | AUD-50 gap |
|---------------|---------------------------|------------|
| `live cold start paints Today before foreground backfill completes` | Yes L432 | Name omits method |
| `cold start bind seeds monitor from fast-path steps` | Yes L518 | Name omits method |
| `post-pipeline persist cycle uses null sourceTimeout` | Yes L622 | Incidental call |

**Reuse — do not reinvent:**

- `buildCoordinatorUnitTestDeps` — `test/helpers/coordinator_unit_test_deps.dart` (no SQLite, stub DB)
- `_DelayingBackgroundCollector` — delays `collectOnce` to prove fast-path-before-backfill
- `_SeedCapturingMonitor` / `_CountingStepAggregation` — bind seed + getTodaySteps dedup
- `_ColdStartStepAggregation`, `_ColdStartUserSettings`, `_ColdStartUserHealthMetrics` — minimal TodayCubit fakes
- `_boundCoordinator` helper — already binds widget; pass `enableLiveStepPipeline: true` when needed

**Recording pattern for sequencing** (from existing test L385–440):

```dart
final events = <String>[];
todayCubit.stream.listen((state) {
  if (state.lastDisplayedStepsLoaded && !events.contains('fast_path')) {
    events.add('fast_path');
  }
});
// onCollectEnd → events.add('backfill_end')
coordinator.onTodayCubitReady(todayCubit);
expect(events.indexOf('fast_path'), lessThan(events.indexOf('backfill_end')));
```

### Architecture compliance

- **Today Display Truth Model:** SQLite aggregate = truth; monitor = overlay; fast path may show SQLite before overlay — display must stay monotonic within local day [Source: epics-post-audit.md Additional Requirements]
- **Single-writer ingestion:** Tests must not add UI-side bucket writes — only assert orchestration order
- **NFR-AUD-06:** Prefer unit/fault-injection over FFI/widget for lifecycle entry points
- **Layering post-25-2:** Façade delegates to `LifecycleLivePipelineService` — tests stay on public `AppLifecycleCoordinator` API; do not import lifecycle internals unless spying requires it
- **Epic 26 note (epics-post-audit Story 25-2 AC):** Public method names on façade unchanged — update imports only if paths move

### File structure requirements

| Action | Path |
|--------|------|
| **UPDATE** | `test/core/services/app_lifecycle_coordinator_test.dart` — add `group('onTodayCubitReady')`, optional refactor of existing cold-start tests into group |
| **READ ONLY** | `lib/core/services/app_lifecycle_coordinator.dart` |
| **READ ONLY** | `lib/core/services/lifecycle/lifecycle_live_pipeline_service.dart` |
| **READ ONLY** | `test/helpers/coordinator_unit_test_deps.dart` |
| **DO NOT** | `test/app_live_pipeline_lifecycle_test.dart` (slow tag, integration — out of scope) |

### Testing requirements

**Default verify command:**

```bash
flutter test test/core/services/app_lifecycle_coordinator_test.dart --exclude-tags slow
flutter test --exclude-tags slow
```

**AUD-50 verification grep:**

```bash
rg "onTodayCubitReady" test/core/services/app_lifecycle_coordinator_test.dart
```

Expect: group name + test bodies calling `coordinator.onTodayCubitReady(`.

**Assertions checklist (live path):**

- [ ] `coordinator.onTodayCubitReady(todayCubit)` is the **explicit** test entry (not only via widget pump)
- [ ] Fast path before backfill end
- [ ] Monitor `start`/`reconcile` receive fast-path seed (`skipSqliteRefresh` bind)
- [ ] After `await coordinator.foregroundBackfill`, reconcile/sync path exercised
- [ ] `todayCubit.close()` + monitor dispose in `tearDown`/test end (avoid leaks)

**Non-live branch:**

- [ ] `enableLiveStepPipeline: false`
- [ ] Monitor not running after `onTodayCubitReady` + pump
- [ ] Cubit leaves loading via `refresh()` path

### Previous story intelligence (Epic 25-2)

- Coordinator split into `LifecyclePersistService`, `LifecycleDayBoundaryService`, `LifecycleLivePipelineService` — **public façade unchanged**
- Story 25-2 explicitly listed `onTodayCubitReady` as Epic 26 target (26-1)
- Cold-start sequencing documented in 25-2 Dev Notes — same contract applies
- Full suite was green at 947+ tests after 25-2 — extend, do not break mutex/persist/day-boundary tests in same file

### Git intelligence

Recent commits (Epic 25 close):

- `075d995` — epic-25 close at 0.11.2+27
- `31b7076` / doc commits — 25-5 class doc comments only

No pending coordinator behaviour changes since 25-2 — safe to add tests only.

### Project context reference

- OK-commit gate mandatory per sub-task — `docs/project-context.md`
- Default test command: `flutter test --exclude-tags slow`
- Version bump at **Epic 26 close** only (patch+1, build+1) — current `0.11.2+27`
- Sprint tracker: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` (not legacy `sprint-status.yaml`)

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` § Story 26-1]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-couverture-structurelle.md` § Top #2]
- [Source: `_bmad-output/implementation-artifacts/stories/25-2-split-app-lifecycle-coordinator-into-focused-services.md` § Public API inventory, Critical behaviours #3–#4]
- [Source: `_bmad-output/implementation-artifacts/stories/21-2-decouple-foreground-backfill-from-first-today-paint.md`]
- [Source: `lib/core/services/app_lifecycle_coordinator.dart` L134–141]
- [Source: `lib/core/services/lifecycle/lifecycle_live_pipeline_service.dart` L139–227, L260–322]
- [Source: `test/helpers/coordinator_unit_test_deps.dart`]
- [Source: `docs/project-context.md` § Test commands, Story completion checklist]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Sub-task A: AUD-50 gap confirmed — 3 existing calls at L432/L518/L622 without named group; behaviour covered, symbol grep failed audit contract.
- Sub-task B: Added `group('onTodayCubitReady')` with 3 live-pipeline tests (fast path ordering, bind seed dedup, post-backfill reconcile).
- Sub-task C: Added non-live branch test — monitor stays stopped, cubit loaded via refresh after backfill.

### Completion Notes List

- ✅ Sub-task B: live cold-start sequencing under named group (AC #1, #2)
- ✅ Sub-task C: non-live initialTodayRefresh path (AC #3)

### File List

- `test/core/services/app_lifecycle_coordinator_test.dart` (modified)

## Change Log
