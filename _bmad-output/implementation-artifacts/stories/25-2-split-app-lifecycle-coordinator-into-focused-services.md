# Story 25.2: Split AppLifecycleCoordinator into Focused Services

Status: review

<!-- Post-audit Epic 25 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 25-2 · diagnostic-convention-structure.md Synthèse Haute · AUD-45 -->
<!-- Prerequisite: Story 25-1 done; Epics 21–24 done; Epic 26 will add orchestration tests — keep public coordinator API stable -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **developer**,
I want lifecycle orchestration split into focused services,
So that midnight, persist, and live-pipeline changes stay isolated.

## Acceptance Criteria

1. **Given** `app_lifecycle_coordinator.dart` is ~882 LOC with a single class owning persist serialization, midnight boundary, cold-start live pipeline, resume catch-up, and foreground/background lifecycle handlers
   **When** the split completes
   **Then** responsibilities are separated into focused collaborators with clear APIs (AUD-45):
   - **Persist cycle:** `_runPersistCycle`, `_enqueuePersistCycle`, `_enqueuePersistCycleReturningCount`, `_persistCycleWithOptionalSync`, `_persistOnPause`, `_runPersistIfNotInFlight`, activity-idle + staleness timers, `_lastPersistAt`, `_persistInFlight`
   - **Midnight / day boundary:** `_wireLiveMonitorDayBoundaryCallbacks`, `_scheduleMidnightBoundaryTimer`, `_onMidnightBoundaryTimerFired`, `_cancelMidnightBoundaryTimer`, `_runLocalDayBoundaryIfNeeded`, `_runLocalDayBoundary`, `_runLocalDayBoundaryImpl`, `_activeLocalDayIso`, `_dayBoundaryInFlight`
   - **Live pipeline:** `_ensureLivePipelineAttached`, `_startLivePipelineFirstTime`, `_reattachLivePipeline`, `_bindLiveMonitorToToday`, `_resumeLivePipeline`, `_reconcileAfterBackfillCompletes`, `_initialTodayRefresh`, cold-start logging, `_livePipelineStarted`, resume phone-peek decision wiring
   **And** `AppLifecycleCoordinator` remains the public façade: same constructor, same DI registration path, same method signatures for all external callers

2. **Given** external callers (`AstraApp`, `AppDependencies`, `AppScaffold`, tests)
   **When** this story ships
   **Then** **zero import-path or signature changes** are required outside `lib/core/services/` (and new sub-files under it)
   **And** these public entry points behave equivalently (no UX regressions):
   - Widget: `bindToWidget`, `onTodayCubitReady`, `onHistoryCubitReady`, `onMyDataCubitReady`, `onLifecycleStatePaused`, `onLifecycleStateResumed`, `bindTodayCubit`/`bindHistoryCubit`/`bindMyDataCubit`, `dispose`, `foregroundBackfill`
   - Tests: `enqueuePersistCycleForTest`, `runLocalDayBoundaryIfNeededForTest`, top-level `@visibleForTesting` helpers (`shouldTriggerStalenessPersist`, `shouldRunResumePhoneCatchUp`, `shouldRunResumePhonePeek`, `runSerializedLifecycleTransition`) still importable from `package:astra_app/app.dart` (re-export unchanged)
   **And** Today Display Truth Model contracts from Epics 2.9 / 18-1 / 21 are preserved: fast-path before bind, seed on cold bind, resume catch-up semantics, day-rollover persist→reset→refresh sequence, no `DataLifecycleService.runMaintenance` on foreground resume

3. **Given** file-size guardrail from audit (§1.4)
   **When** split completes
   **Then** no new file under `lib/core/services/lifecycle/` exceeds **500 LOC**
   **And** `app_lifecycle_coordinator.dart` (facade) is **≤ ~250 LOC** — delegates only, retains lifecycle mutex + cubit binders + config wiring

4. **Given** existing test suites
   **When** `dart analyze` and `flutter test --exclude-tags slow` run
   **Then** all pass with zero behavioural regressions
   **And** `flutter test test/core/services/app_lifecycle_coordinator_test.dart test/app_lifecycle_transition_test.dart` pass
   **And** tests may import new internal types only if needed; prefer keeping coordinator tests importing `AppLifecycleCoordinator` from `package:astra_app/core/services/app_lifecycle_coordinator.dart`

5. **Given** Epic 26 orchestration stories (26-1…26-2) will target coordinator public methods by name
   **When** this story ships
   **Then** method names `onTodayCubitReady`, `onLifecycleStateResumed`, `enqueuePersistCycleForTest`, `runLocalDayBoundaryIfNeededForTest` remain on the façade unchanged
   **And** extracted private methods may move but their behaviour must remain callable through the same public/test hooks

6. **Given** OK-commit gate per `docs/project-context.md`
   **When** implementing
   **Then** work is split into reviewable sub-tasks (mechanical extract → wire façade → tests) with one commit per sub-task after Baptiste approval
   **And** no version bump until Epic 25 closes

**Covers:** AUD-45 · diagnostic-convention-structure.md Synthèse Haute (Haute / Taille)

**Depends on:** Story 25-1 **done**; Epics 21–24 **done**. Epic 26 not required first but will add orchestration tests — **do not rename or relocate public coordinator API** in ways that break future 26-x work.

**Out of scope:** Changing resume/peek/catch-up algorithms, TodayCubit split (25-1 done), core DI presentation leak (25-3), MyDataCubit dialog decoupling (25-4), core/data doc comments (25-5), un-skipping `_kSkipFlakyLivePipeline`, version bump, Epic 26 test authoring.

## Tasks / Subtasks

- [x] **Sub-task A — Read baseline & design split map** (AC: #1, #3)
  - [x] Read **fully** before editing: `lib/core/services/app_lifecycle_coordinator.dart` (~882 LOC)
  - [x] Read callers: `lib/app.dart`, `lib/core/di/app_dependencies.dart`
  - [x] Read tests: `test/core/services/app_lifecycle_coordinator_test.dart`, `test/app_lifecycle_transition_test.dart`, `test/helpers/coordinator_unit_test_deps.dart`
  - [x] Grep `AppLifecycleCoordinator` across `lib/` and `test/` for hidden call sites
  - [x] Produce split map (method → collaborator) in dev notes; confirm shared state owner for `_livePipelineStarted`, cubit refs, `_appInBackground`, `_foregroundBackfill`, lifecycle mutex fields
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Extract collaborators (mechanical, behaviour-preserving)** (AC: #1, #3)
  - [x] Create `lib/core/services/lifecycle/` folder with focused types (suggested names — adjust if clearer):
    - `lifecycle_persist_service.dart` — persist cycle + enqueue serialization + staleness/activity timers
    - `lifecycle_day_boundary_service.dart` — midnight timer + local-day rollover
    - `lifecycle_live_pipeline_service.dart` — cold start, bind, resume, reattach, backfill reconcile
  - [x] Move code **verbatim first** (Story 18-1 / 25-1 pattern) — preserve `livePipelineLog` calls, mutex comments, Today Display Truth Model comments
  - [x] Keep `@visibleForTesting` top-level helpers in `app_lifecycle_coordinator.dart` (or same export path) — **do not break** `test/app_lifecycle_transition_test.dart` import from `package:astra_app/app.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Slim façade `AppLifecycleCoordinator`** (AC: #2, #3, #5)
  - [x] Coordinator delegates to collaborators; holds lifecycle mutex (`_enqueueLifecycleTransition`), cubit binders, `bindToWidget`, public test hooks
  - [x] Pass shared context via small `LifecycleSessionState` class or constructor-injected refs (cubit refs, `_livePipelineStarted`, `_appInBackground`, config flags, `isMounted`/`showMainShell` callbacks)
  - [x] Keep `lib/core/services/app_lifecycle_coordinator.dart` at **same path** — no import churn for `AppDependencies` / tests
  - [x] Preserve `app.dart` re-export block unchanged
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Regression verification** (AC: #4, #6)
  - [x] Run `dart analyze`
  - [x] Run `flutter test test/core/services/app_lifecycle_coordinator_test.dart test/app_lifecycle_transition_test.dart`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] Spot-check sequencing: cold start `onTodayCubitReady` → `refreshFastPath` → bind → backfill reconcile; resume → day boundary → persist → sync; midnight → persist → reset → `refreshAfterDayRollover`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Split `AppLifecycleCoordinator` into collaborators under `core/services/lifecycle/` | Rewriting resume/peek/catch-up algorithms |
| Preserve all public coordinator methods + behaviour | TodayCubit structural changes (25-1 done) |
| Same import path for coordinator + app.dart re-exports | Moving `@visibleForTesting` helpers to unexported files |
| Mechanical refactor + existing test green | New Epic 26 orchestration tests |
| OK-commit sub-task gate | Version bump (Epic 25 close) |

### Root cause (read before editing)

**God-class risk:** `AppLifecycleCoordinator` is the second-largest service (~882 LOC, 1 class) mixing persist serialization, midnight boundary, cold-start orchestration, resume catch-up, and FGS handoff [Source: diagnostic-convention-structure.md §1.4 L78, Synthèse Haute L186].

Epics 21–22 added fast-path cold start, non-blocking backfill, query dedup, and live dispose hardening — further changes to any one concern risk regressions across unrelated paths [Source: Stories 21-1…21-8, 22-1].

**Precedent:** Story 25-1 split `TodayCubit` into collaborators with `TodaySessionCache` for shared mutable state, mechanical verbatim extract, façade ≤160 LOC, 947/947 tests green. Story 18-1 extracted coordinator from `app.dart` with same pattern [Source: 25-1, 18-1].

### Public API inventory (MUST NOT break)

**AstraApp** (`lib/app.dart`):

| Method / property | Usage context |
|-------------------|---------------|
| `bindToWidget(...)` | `initState` — config + cold-start stopwatch |
| `onTodayCubitReady` | First-frame live pipeline attach |
| `onHistoryCubitReady` / `onMyDataCubitReady` | Cubit binding |
| `onLifecycleStatePaused` / `onLifecycleStateResumed` | `WidgetsBindingObserver` |
| `bindTodayCubit(null)` etc. | Cubit dispose cleanup |
| `dispose()` | Timer cancel + monitor stop |
| `foregroundBackfill` | `AppScaffold` backfill future |

**AppDependencies:** `deps.appLifecycleCoordinator` — constructed via `depsGetter` closure [Source: app_dependencies.dart L217–218].

**Test hooks (Epic 26 targets these names):**

| Method | Purpose |
|--------|---------|
| `onTodayCubitReady` | Cold-start attach/backfill/bind (26-1) |
| `onLifecycleStateResumed` | Resume pipeline + catch recovery (26-2) |
| `enqueuePersistCycleForTest` | Persist serialization tests |
| `runLocalDayBoundaryIfNeededForTest` | Day-boundary gate tests |

**Re-export contract** (`app.dart` L23–30): `kMaxPersistStaleness`, `kResumePhoneCatchUpTimeout`, `runSerializedLifecycleTransition`, `shouldRunResumePhoneCatchUp`, `shouldRunResumePhonePeek`, `shouldTriggerStalenessPersist`.

### Suggested collaborator boundaries

```
AppLifecycleCoordinator (facade, lifecycle mutex, cubit binders)
├── LifecyclePersistService       _runPersistCycle, _enqueuePersistCycle*, _persistOnPause,
│                                 _runPersistIfNotInFlight, staleness timer, onActivityIdle wiring
├── LifecycleDayBoundaryService   midnight timer, _runLocalDayBoundary*, monitor.onLocalDayBoundary
└── LifecycleLivePipelineService  _ensureLivePipelineAttached, _startLivePipelineFirstTime,
                                  _bindLiveMonitorToToday, _resumeLivePipeline, _reconcileAfterBackfillCompletes,
                                  cold-start logging, _initialTodayRefresh
```

**Shared mutable session fields** (single owner — `LifecycleSessionState` or pass by reference):

- Cubit refs: `_todayCubit`, `_historyCubit`, `_myDataCubit`
- Pipeline flags: `_livePipelineStarted`, `_appInBackground`, `_foregroundBackfill`
- Resume context: `_backgroundedAt`, `_stepsAtBackground`
- Config: `enablePeriodicPersist`, `enableLiveStepPipeline`, `maxPersistStaleness`, `minPauseForPhoneCatchUp`
- Widget callbacks: `_isMounted`, `_showMainShell`
- Cold-start telemetry: `_coldStartStopwatch`, `_coldStartReadyLogged`

**Cross-service calls:** persist service needs `livePipelineStarted` gate; day boundary calls persist then live reset; live pipeline calls persist on resume. Wire via façade callbacks or shared session — avoid circular imports (facade orchestrates cross-calls if needed).

### Critical behaviours to preserve (non-negotiable)

1. **Lifecycle mutex (14-2):** `runSerializedLifecycleTransition` serializes pause/resume — coordinator owns `_lifecycleTransitionInFlight`; do not parallelize background/foreground handlers.

2. **Persist serialization:** `_persistInFlight` while-loop in `_enqueuePersistCycle` and `_enqueuePersistCycleReturningCount` — max concurrent persist == 1 (test: `enqueuePersistCycle serializes overlapping calls`).

3. **Cold start (21-1 / 21-2):** `onTodayCubitReady` → `refreshFastPath` → `_bindLiveMonitorToToday(skipSqliteRefresh: true)` → `unawaited(_reconcileAfterBackfillCompletes())`; backfill uses `Duration.zero` sourceTimeout; fast-path paints before backfill completes.

4. **Bind seed (21-3 / AUD-03):** Cold bind passes `seedPersistedSteps: _todayCubit?.state.steps` to `monitor.start`/`reconcileFromDatabase` — no extra `getTodaySteps` on bind path.

5. **Resume catch-up:** `_resumeLivePipeline` — drain persist, phone-peek decision via `shouldRunResumePhoneCatchUp` + `shouldRunResumePhonePeek`, `_bindLiveMonitorToToday(foregroundCatchUp: true)`, `setLiveStepAppliesPaused(false)` in `finally`.

6. **Day rollover:** persist → `resetForNewLocalDay` → update `_activeLocalDayIso` → `refreshAfterDayRollover` → history/myData silent refresh → re-sync steps.

7. **No maintenance on resume:** Comment at L292–294 — never run `DataLifecycleService.runMaintenance` in `_onAppForegrounded`.

8. **FGS handoff on pause:** `setUiActive(false)` + `startHealthCollectionService()` + `maybeNotifyGoalReachedIfGoalMet()` when shell visible.

9. **Discarded futures lint (22-5):** Preserve `unawaited()` at fire-and-forget sites when moving code.

### File structure requirements

| Path | Action |
|------|--------|
| `lib/core/services/app_lifecycle_coordinator.dart` | UPDATE → thin façade + top-level test helpers |
| `lib/core/services/lifecycle/*.dart` | NEW — collaborators (≤500 LOC each) |
| `lib/app.dart` | NO API changes — re-export block unchanged |
| `lib/core/di/app_dependencies.dart` | NO changes expected (same coordinator type/path) |
| `test/core/services/app_lifecycle_coordinator_test.dart` | UPDATE imports only if needed |
| `test/app_lifecycle_transition_test.dart` | NO changes — still imports helpers from `app.dart` |
| `test/helpers/coordinator_unit_test_deps.dart` | NO changes expected |

**Architecture compliance:** Orchestration stays in `lib/core/services/`; collaborators in subfolder `lifecycle/` [Source: architecture.md L539]. Coordinator uses `deps.timeProvider` for day boundary (D-25). Single writer: `BackgroundCollector` via `_runPersistCycle` [Source: architecture.md ingestion invariants].

**Naming:** `snake_case.dart`, `PascalCase` classes [Source: architecture.md L592–593].

### Testing requirements

| Command | When |
|---------|------|
| `flutter test test/core/services/app_lifecycle_coordinator_test.dart test/app_lifecycle_transition_test.dart` | After Sub-task C |
| `flutter test --exclude-tags slow` | Final verification (AC #4) |
| `dart analyze` | Every sub-task |

No new tests strictly required if full existing suites pass — Epic 26 will add `onTodayCubitReady` / resume failure tests. Optional: one unit test per collaborator with injected fakes (only if isolatable without duplicating coordinator_test coverage).

**Existing coordinator tests to keep green (7 tests):**

- `enqueuePersistCycle serializes overlapping calls`
- `runLocalDayBoundaryIfNeeded no-ops when local day unchanged`
- `onLifecycleStatePaused hands off to health FGS when shell visible`
- `live cold start paints Today before foreground backfill completes`
- `cold start bind seeds monitor from fast-path steps — no extra getTodaySteps on bind (AUD-03)`
- `cold-start backfill passes Duration.zero to collectOnce (AUD-05)`
- `post-pipeline persist cycle uses null (default 2 s) sourceTimeout`

### Previous story intelligence (25-1)

Story 25-1 established patterns directly applicable here:

- **Mechanical verbatim extract first**, then slim façade — do not refactor algorithms during extract.
- **`TodaySessionCache` pattern:** shared mutable state in a small holder class; collaborators receive deps + session + emit/callback hooks.
- **Cross-collaborator wiring:** use `late` function fields or façade-delegated callbacks to avoid circular imports (25-1 used 15 callbacks in façade constructor).
- **LOC targets met:** facade ~160 LOC, largest collaborator ~230 LOC — mirror for coordinator split.
- **947/947 tests green** after split — regression bar is high; run full `--exclude-tags slow` before each OK commit on Sub-task D.
- **Code review note:** late wiring fragility is acceptable trade-off; document callback ownership in split map.

### Git intelligence (recent work)

Recent commits closed Story 25-1 (TodayCubit split into 5 collaborators). No coordinator edits in last 5 commits — safe window for structural split. Last coordinator feature work was Epic 21 cold-start fast-path + Epic 22 live dispose hardening.

### Latest tech information

- **No new packages** — pure refactor.
- **flutter_bloc ^8.x:** Coordinator remains plain Dart; cubit interaction unchanged.
- **`discarded_futures` lint** enabled — preserve `unawaited()` at timer/callback fire-and-forget sites.
- **Dart 3.x:** Prefer `final class` for session state holder if no subclassing needed.

### Project context reference

- OK-commit gate: `docs/project-context.md`
- Test default: `flutter test --exclude-tags slow`
- Version bump: Epic 25 close only (`patch+1`, `build+1`) — update `pubspec.yaml` + `README.md` then, not in this story
- Tracker: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`

### References

- [Source: _bmad-output/planning-artifacts/epics-post-audit.md#Story 25-2]
- [Source: _bmad-output/planning-artifacts/audits/diagnostic-convention-structure.md §1.4 L78, Synthèse Haute L186]
- [Source: lib/core/services/app_lifecycle_coordinator.dart — full implementation]
- [Source: _bmad-output/implementation-artifacts/stories/18-1-extract-app-lifecycle-coordinator-from-app-dart.md]
- [Source: _bmad-output/implementation-artifacts/stories/25-1-split-today-cubit-by-responsibility-boundaries.md]
- [Source: _bmad-output/planning-artifacts/architecture.md — Today Display Truth Model, D-25 TimeProvider]
- [Source: test/core/services/app_lifecycle_coordinator_test.dart — regression contracts]
- [Source: test/app_lifecycle_transition_test.dart — helper re-export contract]

### Split map (Sub-task A — 2026-07-19)

**Baseline:** `app_lifecycle_coordinator.dart` = **882 LOC**. Call sites lib-only: `app.dart`, `app_dependencies.dart`. Tests: coordinator_test, app_lifecycle_transition_test (helpers via `app.dart`), app_persist_policy_test, coordinator_unit_test_deps. No hidden lib callers.

| Collaborator | Methods (verbatim move) | Owned state |
|---|---|---|
| `LifecyclePersistService` | `_runPersistCycle`, `_enqueuePersistCycle`, `_enqueuePersistCycleReturningCount`, `_persistCycleWithOptionalSync`, `_persistOnPause`, `_runPersistIfNotInFlight`, `_startActivityBasedPersist`, `_stopActivityBasedPersist`, `_stopStalenessPersistTimer` | `_stalenessPersistTimer`, `_lastPersistAt`, `_persistInFlight`; const `_persistMaxReadingsPerSource` |
| `LifecycleDayBoundaryService` | `_wireLiveMonitorDayBoundaryCallbacks`, `_scheduleMidnightBoundaryTimer`, `_onMidnightBoundaryTimerFired`, `_cancelMidnightBoundaryTimer`, `_runLocalDayBoundaryIfNeeded`, `_runLocalDayBoundary`, `_runLocalDayBoundaryImpl` | `_midnightBoundaryTimer`, `_activeLocalDayIso`, `_dayBoundaryInFlight` |
| `LifecycleLivePipelineService` | `_ensureLivePipelineAttached`, `_startLivePipelineFirstTime`, `_reattachLivePipeline`, `_bindLiveMonitorToToday`, `_resumeLivePipeline`, `_reconcileAfterBackfillCompletes`, `_initialTodayRefresh`, `_logColdStartPhase`, `_logColdStartReadyIfNeeded` | cold-start telemetry via session (`_coldStartStopwatch`, `_coldStartReadyLogged`) |
| **Façade** `AppLifecycleCoordinator` | `bindToWidget`, cubit binders, `on*CubitReady`, `onLifecycleStatePaused/Resumed`, `_enqueueLifecycleTransition`, `_onAppBackgrounded`, `_onAppForegrounded`, test hooks, `dispose`, `foregroundBackfill` | `_lifecycleTransitionInFlight`; constructs collaborators |

**`LifecycleSessionState` (single shared mutable owner):**
- Cubits: `todayCubit`, `historyCubit`, `myDataCubit`
- Pipeline: `livePipelineStarted`, `appInBackground`, `foregroundBackfill`
- Resume: `backgroundedAt`, `stepsAtBackground`
- Config mirrors (writable from bind): `enablePeriodicPersist`, `enableLiveStepPipeline`, `maxPersistStaleness`, `minPauseForPhoneCatchUp`
- Widget: `isMounted`, `showMainShell` callbacks
- Cold-start: `coldStartStopwatch`, `coldStartReadyLogged`

**Cross-calls (façade or late callbacks — avoid circular imports):**
- Persist ← needs `session.livePipelineStarted`, cubit sync
- DayBoundary → Persist.enqueue + LivePipeline reset path (via persist + monitor.reset)
- LivePipeline.resume → DayBoundary.ifNeeded + Persist.enqueueReturningCount + bind
- Façade pause/resume → Persist.onPause / LivePipeline.resume; wires day-boundary + activity persist after resume
- `_stopActivityBasedPersist` currently also cancels midnight timer — façade `dispose` will call persist.stop + dayBoundary.cancel separately (behaviour-equivalent)

**Top-level helpers stay in `app_lifecycle_coordinator.dart`:** constants + `shouldTrigger*`, `shouldRunResume*`, `runSerializedLifecycleTransition` (re-export path unchanged).

**LOC budget:** façade ≤~250; each collaborator ≤500.

## Dev Agent Record

### Agent Model Used

Cursor Grok 4.5

### Debug Log References

### Implementation Plan

- Sub-task A: baseline read + split map (no code move)
- Sub-task B: mechanical extract into `lifecycle/` + session holder
- Sub-task C: slim façade wiring
- Sub-task D: analyze + targeted + full non-slow tests

### Completion Notes List

- Sub-task A: 882 LOC confirmed; call sites enumerated; split map + session ownership recorded above.
- Sub-task B: Extracted persist / day-boundary / live-pipeline + session + policy helpers under `lifecycle/`; façade wires late callbacks; coordinator tests + transition + persist policy = 23/23 green. Helpers moved to `lifecycle_policy.dart` and re-exported from coordinator (same `app.dart` show path). Dropped `@visibleForTesting` on helpers (cross-library prod use after split).
- Sub-task C: Façade 248 LOC (≤250); public API + `app.dart` re-export unchanged; `AppDependencies` unchanged.
- Sub-task D: `dart analyze` clean; coordinator + transition 11/11; full suite `flutter test --exclude-tags slow` → **947/947** (~2 skipped). AC #3 LOC: max collaborator 323 (<500).

### Change Log

- 2026-07-19: Sub-task A — split map designed; story → in-progress
- 2026-07-19: Sub-task B — mechanical extract into `lib/core/services/lifecycle/`
- 2026-07-19: Sub-task C/D — façade verified, regression suite green; story → review

### File List

- `_bmad-output/implementation-artifacts/stories/25-2-split-app-lifecycle-coordinator-into-focused-services.md`
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`
- `lib/core/services/app_lifecycle_coordinator.dart`
- `lib/core/services/lifecycle/lifecycle_session_state.dart`
- `lib/core/services/lifecycle/lifecycle_policy.dart`
- `lib/core/services/lifecycle/lifecycle_persist_service.dart`
- `lib/core/services/lifecycle/lifecycle_day_boundary_service.dart`
- `lib/core/services/lifecycle/lifecycle_live_pipeline_service.dart`


