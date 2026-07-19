# Story 25.1: Split TodayCubit by Responsibility Boundaries

Status: done

<!-- Post-audit Epic 25 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 25-1 · diagnostic-convention-structure.md Synthèse Haute · AUD-44 -->
<!-- First story in Epic 25 — version bump deferred to epic close (patch+1, build+1) -->
<!-- Prerequisite: Epics 21–24 done; Epic 26 may add tests against same public API — keep signatures stable -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **developer**,
I want TodayCubit split along clear responsibilities,
So that cold-start/live/celebration changes do not risk a 1260-line god class.

## Acceptance Criteria

1. **Given** `today_cubit.dart` is ~1261 LOC with a single class owning refresh, live pipeline, celebration, week/multi-day selection, and snapshot application
   **When** the split completes
   **Then** responsibilities are separated into focused collaborators with clear APIs (AUD-44):
   - **Refresh / fast-path:** `refresh`, `refreshFastPath`, `_enrichAfterFastPath`, `refreshMetadata`, `refreshAfterDayRollover`, `_refreshImpl`, generation + in-flight coalescing
   - **Live pipeline:** `attachLiveMonitor`, `syncSteps`, `setLiveStepAppliesPaused`, `clearForegroundCatchUp`, `_applyLiveSteps`, `_clampStaleLastDisplayed`, `recordLastDisplayedSteps`
   - **Celebration:** `_maybeTriggerCelebration`, `dismissCelebration`
   - **Week / multi-day:** `selectLocalDay`, `_loadWeekDays`, `_applySelectedDayDisplay`, `_loadSnapshotForLocalDay`, `_resolveSelectedLocalDay`, `_isViewingToday`, `_patchTodayGoalMetForLiveSteps`
   - **Shared snapshot core:** `_applyTodaySnapshot` + monotonic same-day rules + `_todaySteps` / `_todayGoal` / `_todayMetrics` cache (single owner — do not duplicate truth-model logic)
   **And** `TodayCubit` remains the public façade: same constructor deps, same `Cubit<TodayState>` type, same method signatures for all external callers

2. **Given** external callers (`AppLifecycleCoordinator`, `TodayScreen`, `AppScaffold`, tests)
   **When** this story ships
   **Then** **zero import-path or signature changes** are required outside `lib/presentation/cubits/` (and new sub-files under it)
   **And** these public entry points behave equivalently (no UX regressions):
   - Coordinator: `refreshFastPath`, `refresh`, `refreshMetadata`, `refreshAfterDayRollover`, `syncSteps`, `attachLiveMonitor`, `setLiveStepAppliesPaused`
   - UI: `refresh(silent:)`, `selectLocalDay`, `updateDailyStepGoal`, `recordLastDisplayedSteps`, `clearForegroundCatchUp`, `dismissCelebration`, `todayEditableGoal`
   **And** Display Truth Model contracts from Epics 2.9 / 11 / 15 / 21 are preserved: SQLite authority on refresh, monotonic same-day steps, `lastDisplayedStepsLoaded` gate, fast-path ≤3 queries, enrichment non-blocking, `foregroundCatchUp` / celebration semantics unchanged

3. **Given** file-size guardrail from audit (§1.4)
   **When** split completes
   **Then** no new file under `lib/presentation/cubits/today/` exceeds **500 LOC** (excluding `today_state.dart` which stays put)
   **And** `today_cubit.dart` (facade) is **≤ ~250 LOC** — delegates only, no duplicated business logic blocks

4. **Given** existing test suites
   **When** `dart analyze` and `flutter test --exclude-tags slow` run
   **Then** all pass with zero behavioural regressions
   **And** tests may import new internal types only if needed; prefer keeping `today_cubit_test.dart` / `today_cubit_contract_test.dart` importing `TodayCubit` from the same public export path (`package:astra_app/presentation/cubits/today_cubit.dart` — re-export from subfolder if moved)

5. **Given** OK-commit gate per `docs/project-context.md`
   **When** implementing
   **Then** work is split into reviewable sub-tasks (mechanical extract → wire façade → tests) with one commit per sub-task after Baptiste approval
   **And** no version bump until Epic 25 closes

**Covers:** AUD-44 · diagnostic-convention-structure.md Synthèse Haute (Haute / Taille)

**Depends on:** Epics 21–24 **done** (fast-path, loading gates, discarded-futures lint). Epic 26 not required first but will add orchestration tests — **do not rename or relocate public TodayCubit API** in ways that break future 26-x work.

**Out of scope:** Splitting `AppLifecycleCoordinator` (25-2), core DI presentation leak (25-3), MyDataCubit dialog decoupling (25-4), core/data doc comments (25-5), changing refresh/live business rules, GoalRing widget split, version bump, Epic 26 test authoring.

## Tasks / Subtasks

- [x] **Sub-task A — Read baseline & design split map** (AC: #1, #3)
  - [x] Read **fully** before editing: `lib/presentation/cubits/today_cubit.dart`, `today_state.dart`
  - [x] Read callers: `app_lifecycle_coordinator.dart` (all `_todayCubit?.` sites), `today_screen.dart`, `app_scaffold.dart`
  - [x] Read tests: `test/presentation/cubits/today_cubit_test.dart`, `today_cubit_contract_test.dart`, `test/app_live_pipeline_lifecycle_test.dart` (grep only — do not un-skip flaky suite)
  - [x] Produce split map (method → collaborator) in code comment or story dev notes; confirm shared state owner for `_refreshGeneration`, `_todaySteps`, `_todayGoal`, `_lastAppliedLocalDay`, `_hasUserSelectedLocalDay`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Extract collaborators (mechanical, behaviour-preserving)** (AC: #1, #3)
  - [x] Create `lib/presentation/cubits/today/` folder with focused types (suggested names — adjust if clearer):
    - `today_refresh_service.dart` — refresh paths + generation gate
    - `today_live_pipeline.dart` — monitor attach + syncSteps + lastDisplayed persist
    - `today_celebration_controller.dart` — celebration claim + dismiss
    - `today_week_selection.dart` — week strip load + day picker
    - `today_snapshot_applier.dart` — `_applyTodaySnapshot` + metrics helpers (`_liveMetricsForSteps`, `_toMetricsSnapshot`, `_resolveTodayGoal`)
  - [x] Move code **verbatim first** (Story 18-1 pattern) — preserve comments on concurrency (fast-path Option A, `_refreshInFlight` coalescing)
  - [x] Keep `@visibleForTesting` on façade where tests depend on it (`liveStepAppliesPaused`)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Slim façade `TodayCubit`** (AC: #2, #3)
  - [x] `TodayCubit` delegates to collaborators; holds `Cubit<TodayState>` emit path (collaborators receive `void Function(TodayState)` or callback interface — avoid second Cubit)
  - [x] Preserve `close()` cleanup: cancel `_liveStepsSubscription`, null `_attachedMonitor`
  - [x] If files moved: keep `lib/presentation/cubits/today_cubit.dart` as **barrel export** so existing imports unchanged
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Regression verification** (AC: #4, #5)
  - [x] Run `dart analyze`
  - [x] Run `flutter test test/presentation/cubits/today_cubit_test.dart test/presentation/cubits/today_cubit_contract_test.dart`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] Spot-check: cold-start path still calls `refreshFastPath` from coordinator; day rollover still calls `refreshAfterDayRollover`; live bind still uses `attachLiveMonitor` + `syncSteps(clampStaleDisplay: true)`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Split `TodayCubit` into collaborators under `presentation/cubits/today/` | `AppLifecycleCoordinator` split (25-2) |
| Preserve all public TodayCubit methods + behaviour | Changing fast-path query count or enrichment timing |
| Barrel export to keep import paths stable | Moving `TodayState` or week models |
| Mechanical refactor + existing test green | New Epic 26 orchestration tests |
| OK-commit sub-task gate | Version bump (Epic 25 close) |

### Root cause (read before editing)

**God-class risk:** `TodayCubit` is the largest cubit (~1261 LOC, 1 class) mixing SQLite refresh, live monitor subscription, goal celebration persistence, week strip, and multi-day GoalRing display [Source: diagnostic-convention-structure.md §1.4 L73–82, Synthèse Haute L186].

Epics 21–22 added fast-path, generation guards, and loading semantics — further feature work on any one concern risks regressions across unrelated paths [Source: diagnostic-cold-start.md, Stories 21-1…21-8, 22-1…22-2].

**Precedent:** Story 18-1 extracted `AppLifecycleCoordinator` mechanically first, preserved public contracts and re-exports, then added targeted unit tests [Source: 18-1].

### Public API inventory (MUST NOT break)

**AppLifecycleCoordinator** (`lib/core/services/app_lifecycle_coordinator.dart`):

| Method | Usage context |
|--------|----------------|
| `refreshFastPath()` | Cold-start first paint (L612) |
| `refresh(silent: true)` | Post-ingestion, resume, bind fallback |
| `refreshMetadata()` | Permission/stale refresh on resume |
| `refreshAfterDayRollover()` | Midnight boundary (L862) |
| `syncSteps(...)` | Live reconcile, catch-up, day rollover |
| `attachLiveMonitor(...)` | Live pipeline bind |
| `setLiveStepAppliesPaused(bool)` | Screen off/on (L278, L505) |

**TodayScreen / widgets:** `refresh(silent: false)`, `selectLocalDay`, `updateDailyStepGoal`, `recordLastDisplayedSteps`, `clearForegroundCatchUp`, `dismissCelebration`, `todayEditableGoal`.

**Tests:** `today_cubit_test.dart` (~1300 LOC integration-style), `today_cubit_contract_test.dart` (fast-path generation, refresh contracts), `app_live_pipeline_lifecycle_test.dart`, widget tests via `BlocSelector`.

### Suggested collaborator boundaries

```
TodayCubit (facade, emit owner)
├── TodayRefreshService      refresh*, _refreshImpl, _enrichAfterFastPath, _refreshGeneration, _refreshInFlight
├── TodayLivePipeline        attachLiveMonitor, syncSteps, setLiveStepAppliesPaused, clearForegroundCatchUp,
│                            recordLastDisplayedSteps, _applyLiveSteps, _clampStaleLastDisplayed
├── TodayCelebrationController  _maybeTriggerCelebration, dismissCelebration
├── TodayWeekSelection       selectLocalDay, _loadWeekDays, _applySelectedDayDisplay, _loadSnapshotForLocalDay,
│                            _resolveSelectedLocalDay, _isViewingToday, _patchTodayGoalMetForLiveSteps, _isSameLocalDay
└── TodaySnapshotApplier     _applyTodaySnapshot, _liveMetricsForSteps, _toMetricsSnapshot, _resolveTodayGoal,
                             _displayLocalDayIso, _loadLastDisplayedStepsForDisplayDay
```

**Shared mutable session fields** (single owner — pass by reference or small `TodaySessionCache` class):

- `_todaySteps`, `_todayGoal`, `_todayMetrics`, `_lastAppliedLocalDay`, `_hasUserSelectedLocalDay`
- `_refreshGeneration`, `_refreshInFlight` (refresh service owns; live path reads generation for abort checks)

**Do not** introduce a second `Cubit` or `Bloc` — collaborators are plain Dart classes receiving emit callback + dependencies.

### Critical behaviours to preserve (non-negotiable)

1. **Fast path (21-1):** `refreshFastPath` bumps generation on entry; ≤3 data queries before first emit; `skipCelebration: true`; `unawaited(_enrichAfterFastPath)`; empty `weekDays` safe (no `_resolveSelectedLocalDay([])` throw).

2. **Generation abort:** `_generationStillValid` / `isClosed` checks after every `await` in enrichment and fast path.

3. **Monotonic steps:** `_applyTodaySnapshot` decrease guards (`allowDecrease`, `_lastAppliedLocalDay`, `_isViewingToday`) — copy logic exactly; this is the Display Truth Model.

4. **Live gating:** Ignore live events when `_pauseLiveStepApplies` or `state.foregroundCatchUp`; re-apply on resume unpause.

5. **Celebration:** `tryClaimCelebrationShownDate` — keep in-flight celebration across silent refresh (existing branch in `_maybeTriggerCelebration`).

6. **Multi-day:** `selectLocalDay` sets loading + clears `lastDisplayedStepsLoaded`; async race guard on `intendedSelectedLocalDay`.

7. **Coalesced refresh:** concurrent `refresh()` shares `_refreshInFlight`; fast path uses Option A (no shared gate with full refresh) per L232–239 comment.

### File structure requirements

| Path | Action |
|------|--------|
| `lib/presentation/cubits/today_cubit.dart` | UPDATE → thin façade + barrel export (or keep file, extract internals) |
| `lib/presentation/cubits/today/*.dart` | NEW — collaborators (≤500 LOC each) |
| `lib/presentation/cubits/today_state.dart` | NO MOVE — unchanged |
| `lib/core/services/app_lifecycle_coordinator.dart` | NO API changes |
| `lib/presentation/screens/today_screen.dart` | NO changes expected |
| `test/presentation/cubits/today_cubit_test.dart` | UPDATE imports only if needed |

**Architecture compliance:** Cubits stay in `presentation/cubits/`; repositories via `data/contracts/` only (already true). Collaborators must not import widgets/screens [Source: architecture.md L826].

**Naming:** `snake_case.dart`, `PascalCase` classes [Source: architecture.md L592–593].

### Testing requirements

| Command | When |
|---------|------|
| `flutter test test/presentation/cubits/today_cubit_test.dart test/presentation/cubits/today_cubit_contract_test.dart` | After Sub-task C |
| `flutter test --exclude-tags slow` | Final verification (AC #4) |
| `dart analyze` | Every sub-task |

No new tests strictly required if full existing suites pass — optional: one unit test per collaborator with injected fakes (only if a collaborator is testable in isolation without duplicating `today_cubit_test.dart` coverage).

**Epic 26 note:** Stories 26-1…26-6 will target `AppLifecycleCoordinator` + `TodayCubit` public methods by name — keep method names stable on the façade.

### Previous story intelligence (Epic 24 close)

Epic 24 established patterns useful here:

- **Mechanical-first refactors** with explicit out-of-scope boundaries (24-6 deferred architecture to Epic 25).
- **Defense-in-depth:** UI + cubit guards — when splitting, keep guards in the same logical owner (e.g. loading no-ops stay with refresh service).
- **OK-commit gate:** one sub-task → review → commit (24-6 shipped in 3 commits).
- **Import stability:** shared widgets extracted without breaking callers (24-1 `SheetDragHandle` pattern) — mirror with barrel export for `TodayCubit`.

### Git intelligence (recent work)

Recent commits closed Epic 24 (design-system loading gates, PeriodToggle). No TodayCubit edits in last 5 commits — safe window for structural split. Last TodayCubit feature work was Epic 21 fast-path + Epic 22 live dispose hardening.

### Latest tech information

- **flutter_bloc ^8.x:** Single `Cubit<TodayState>` remains the state owner; extract plain Dart helpers/services (same pattern as repository split in 18-3).
- **No new packages** — pure refactor.
- **`discarded_futures` lint** enabled in 22-5 — preserve `unawaited()` at fire-and-forget sites when moving code.

### Project context reference

- OK-commit gate: `docs/project-context.md`
- Test default: `flutter test --exclude-tags slow`
- Version bump: Epic 25 close only (`patch+1`, `build+1`) — update `pubspec.yaml` + `README.md` then, not in this story
- Tracker: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-5 (Sonnet 4.6)

### Debug Log References

### Completion Notes List

Sub-task A: Split map produced. 5 collaborators identified under `today/` subfolder. `TodaySessionCache` as shared mutable state holder. Cross-collaborator calls via `late` function fields wired in the facade constructor. No circular imports. `today_cubit.dart` stays at its current path as thin facade.

Sub-tasks B+C: All 5 collaborators extracted verbatim. `TodaySessionCache` holds shared mutable state (`todaySteps`, `todayGoal`, `todayMetrics`, `lastAppliedLocalDay`, `hasUserSelectedLocalDay`, `refreshGeneration`, `refreshInFlight`). Facade wires 15 cross-collaborator callbacks. No second Cubit. `today_cubit.dart` unchanged import path. LOC per file: facade ~160, refresh_service ~230, live_pipeline ~200, week_selection ~200, snapshot_applier ~110, celebration_controller ~60, session_cache ~25. All within 500 LOC limit.

Sub-task D: `dart analyze` — 0 issues. `flutter test` (cubit tests): 51/51 pass. `flutter test --exclude-tags slow`: 947/947 pass, 0 regressions.

Code review: mergeable — no blocking bugs; follow-ups noted (late wiring fragility, collaborator unit tests optional, metrics duplication).

### File List

lib/presentation/cubits/today_cubit.dart (updated — slim facade)
lib/presentation/cubits/today/today_session_cache.dart (new)
lib/presentation/cubits/today/today_snapshot_applier.dart (new)
lib/presentation/cubits/today/today_celebration_controller.dart (new)
lib/presentation/cubits/today/today_week_selection.dart (new)
lib/presentation/cubits/today/today_live_pipeline.dart (new)
lib/presentation/cubits/today/today_refresh_service.dart (new)
_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml (updated)
_bmad-output/implementation-artifacts/stories/25-1-split-today-cubit-by-responsibility-boundaries.md (updated)
