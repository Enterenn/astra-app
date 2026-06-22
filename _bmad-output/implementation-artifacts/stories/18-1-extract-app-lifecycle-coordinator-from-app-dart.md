# Story 18.1: Extract AppLifecycleCoordinator from app.dart

Status: done

<!-- Refacto Epic 18 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 18-1 · refactoring-audit-master-v0.6.1.md §1.2a · REF-17 -->
<!-- Prerequisite: Epics 14–17 done (lifecycle mutex hardened in 14-2; repository contracts in 16-1) -->
<!-- First story in Epic 18 — epic close bumps minor+1 (0.8.0+17) after all 18-x stories done -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **developer**,
I want live pipeline orchestration isolated from `MaterialApp` state,
So that lifecycle logic is unit-testable without widget harnesses.

## Acceptance Criteria

1. **Given** `_AstraAppState` pipeline methods (audit §1.2a inventory)  
   **When** extracted  
   **Then** new injectable `AppLifecycleCoordinator` owns (REF-17):
   - `_ensureLivePipelineAttached`, `_startLivePipelineFirstTime`, `_reattachLivePipeline`
   - `_bindLiveMonitorToToday`, `_resumeLivePipeline`
   - `_runPersistCycle`, `_enqueuePersistCycle`, `_persistCycleWithOptionalSync`, `_enqueuePersistCycleReturningCount`
   - `_wireLiveMonitorDayBoundaryCallbacks`, `_startActivityBasedPersist`, `_stopActivityBasedPersist`
   - `_runLocalDayBoundaryIfNeeded`, `_runLocalDayBoundary`, `_runLocalDayBoundaryImpl`
   - `_scheduleMidnightBoundaryTimer`, `_onMidnightBoundaryTimerFired`, `_cancelMidnightBoundaryTimer`
   - `_stopStalenessPersistTimer`, `_runPersistIfNotInFlight`
   - `_onAppBackgrounded`, `_onAppForegrounded`, `_persistOnPause`
   - `_onTodayCubitReady` pipeline branch, `_initialTodayRefresh`, cold-start logging helpers
   - Active timers: `_stalenessPersistTimer`, `_midnightBoundaryTimer`
   - Pipeline state: `_livePipelineStarted`, `_lastPersistAt`, `_activeLocalDayIso`, `_dayBoundaryInFlight`, `_persistInFlight`, `_lifecycleTransitionInFlight`, `_backgroundedAt`, `_stepsAtBackground`, `_appInBackground`, cold-start stopwatch flags

2. **Given** `lib/app.dart`  
   **When** refactored  
   **Then** `_AstraAppState` delegates pipeline work to coordinator — file reduced substantially (target **≤ ~350 lines**; was ~895 lines at story creation)  
   **And** `_AstraAppState` retains only: `WidgetsBindingObserver`, `build()`, `_showMainShell` / onboarding transition, cubit-ready/dispose **wiring** (thin forwards), `dispose()` teardown call into coordinator

3. **Given** `AppDependencies`  
   **When** coordinator is wired  
   **Then** `AppLifecycleCoordinator` is constructed in `AppDependencies.create()` / `AppDependencies.test()` and exposed as `deps.appLifecycleCoordinator`  
   **And** `AstraApp` receives coordinator via `deps` (no hidden singleton)

4. **Given** `@visibleForTesting` top-level helpers in `app.dart` today  
   **When** refactored  
   **Then** `shouldTriggerStalenessPersist`, `shouldRunResumePhoneCatchUp`, `shouldRunResumePhonePeek`, `runSerializedLifecycleTransition` remain importable from `package:astra_app/app.dart` (re-export from coordinator file if moved — **do not break** `test/app_lifecycle_transition_test.dart`)

5. **Given** `AstraApp` test knobs (`enablePeriodicPersist`, `enableLiveStepPipeline`, `maxPersistStaleness`, `minPauseForPhoneCatchUp`)  
   **When** passed at construction  
   **Then** coordinator honours the same flags — `app_live_pipeline_lifecycle_test.dart` needs **no behavioural change**

6. **Given** `AppScaffold` `foregroundBackfill` contract  
   **When** coordinator owns cold-start backfill  
   **Then** `AstraApp.build()` still passes the same `Future<int>` to `AppScaffold` (expose via coordinator getter, e.g. `foregroundBackfill`)

7. **Given** live-pipeline integration tests  
   **When** `flutter test test/app_live_pipeline_lifecycle_test.dart` run **in isolation**  
   **Then** all tests pass (suite may remain `_kSkipFlakyLivePipeline` in full CI — do not remove skip flag unless Baptiste requests)

8. **Given** coordinator extraction  
   **When** unit-tested  
   **Then** at least **one new fast unit test** exercises coordinator logic with injected mocks (no widget harness, no sqflite) — e.g. persist enqueue serialization, day-boundary gate, or `onAppBackgrounded` FGS handoff with fake deps

9. **Given** `flutter test --exclude-tags slow`  
   **When** run after changes  
   **Then** all tests pass including existing `test/app_lifecycle_transition_test.dart`

10. **Given** work completes on branch `refacto`  
    **When** story is marked done  
    **Then** **no version bump** yet — Epic 18 closes with **minor+1, patch=0, build+1** → `0.8.0+17` when all 18-x stories are done

**Covers:** REF-17 · Audit §1.2a · Architecture Today Display Truth Model · Story 14-2 lifecycle mutex

**Depends on:** Epics 14–17 complete (especially 14-2 mutex hardening, 16-1 repository contracts).

**Out of scope:** Splitting repositories (18-2/18-3), i18n (Epic 19), changing live-pipeline business rules, removing `_kSkipFlakyLivePipeline`, user-facing error UI for lifecycle failures.

## Tasks / Subtasks

- [x] **Sub-task A — Read baseline & design coordinator API** (AC: #1, #3)
  - [x] Read `lib/app.dart` **fully** (895 lines) before editing — map every field/method to coordinator vs widget state
  - [x] Read `lib/core/di/app_dependencies.dart`, `lib/core/services/health_foreground_service.dart` (coordinator naming precedent)
  - [x] Read `test/app_live_pipeline_lifecycle_test.dart` header + `_waitForResumePipelineComplete` — understand async drain expectations
  - [x] Design `AppLifecycleCoordinator` constructor: inject `AppDependencies` + config flags + `bool Function() isMounted` + `bool Function() showMainShell`
  - [x] Design cubit bridge: `void bindTodayCubit(TodayCubit?)`, `bindHistoryCubit`, `bindMyDataCubit` (or equivalent setters called from `_AstraAppState` callbacks)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Create `AppLifecycleCoordinator`** (AC: #1, #4, #5, #6)
  - [x] Create `lib/core/services/app_lifecycle_coordinator.dart`
  - [x] Move pipeline methods verbatim first (mechanical extraction) — preserve `livePipelineLog` calls, comments, and Story 14-2 `runSerializedLifecycleTransition` delegation
  - [x] Move `@visibleForTesting` top-level helpers + constants (`kMaxPersistStaleness`, `kResumePhoneCatchUpTimeout`) — re-export from `app.dart` if helpers move out
  - [x] Expose `Future<int> get foregroundBackfill` (or method) for `AppScaffold`
  - [x] Expose `Future<void> onTodayCubitReady(TodayCubit)`, `onAppBackgrounded()`, `onAppForegrounded()`, `dispose()`, `onLifecycleStateChanged(AppLifecycleState)`
  - [x] Register in `AppDependencies.create()` and `AppDependencies.test()` as `appLifecycleCoordinator`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Slim `app.dart` to delegation shell** (AC: #2, #5, #6)
  - [x] `_AstraAppState` keeps: `_showMainShell`, `initState` observer registration, `didChangeAppLifecycleState` → coordinator, thin cubit callbacks, `build()`, `_onOnboardingComplete`
  - [x] `dispose()` calls `coordinator.dispose()` then `removeObserver`
  - [x] Remove duplicated pipeline state from `_AstraAppState` — single source of truth in coordinator
  - [x] Verify `AstraApp` public constructor signature unchanged (test factories unaffected)
  - [x] Run `flutter analyze`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Unit test coordinator with mocks** (AC: #8, #9)
  - [x] Add `test/core/services/app_lifecycle_coordinator_test.dart` (fast, no `@Tags(['slow'])`)
  - [x] Minimum test cases (pick ≥3 meaningful ones):
    1. `_enqueuePersistCycle` serializes concurrent calls (mock collector returning delayed futures)
    2. `shouldTriggerStalenessPersist` integration via coordinator staleness timer callback (inject short `maxPersistStaleness`)
    3. Day-boundary no-op when `hasLocalDayChanged` is false (fake `TimeProvider`)
    4. Optional: `onAppBackgrounded` calls `healthForegroundCoordinator.setUiActive(false)` — mock/spy pattern from `test/helpers/recording_health_fgs.dart`
  - [x] Run `flutter test test/app_lifecycle_transition_test.dart test/core/services/app_lifecycle_coordinator_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Integration regression** (AC: #7, #9)
  - [x] Run `flutter test --exclude-tags slow`
  - [x] Run `flutter test test/app_live_pipeline_lifecycle_test.dart` in isolation — document pass/fail in review brief
  - [x] Manual smoke: cold start → walk → background → resume → verify steps persist and GoalRing updates
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Extract pipeline orchestration to `AppLifecycleCoordinator` | Rewriting resume/peek/catch-up algorithms |
| DI wiring via `AppDependencies` | `postPurgeRefresh` guard (14-1 — done) |
| Preserve Story 14-2 mutex + top-level test helpers | Repository splits (18-2, 18-3) |
| Fast coordinator unit test(s) | Full suite un-skip of slow live-pipeline tests |
| Mechanical `app.dart` line reduction | Locale/i18n in `MaterialApp` (Epic 19) |
| Branch `refacto` only | Version bump (deferred to Epic 18 close) |

### Critical baseline — read `app.dart` first

`_AstraAppState` is the **only** owner of live-pipeline orchestration today. The audit inventory (§1.2a) is the extraction checklist — do not drop "support" methods like `_persistCycleWithOptionalSync` or `_enqueuePersistCycleReturningCount`; they are load-bearing for resume and day-boundary paths.

**Widget-only state (stays in `_AstraAppState`):**

| Field / method | Why it stays |
|----------------|--------------|
| `_showMainShell` | Drives `MaterialApp.home` onboarding vs `AppScaffold` |
| `_onOnboardingComplete` | `setState` UI transition |
| `build()` | `MultiBlocProvider` + `MaterialApp` |
| Cubit dispose callbacks | `AppScaffold` lifecycle — set coordinator refs to `null` |

**Pipeline state (moves to coordinator):**

```153:177:lib/app.dart
class _AstraAppState extends State<AstraApp> with WidgetsBindingObserver {
  static const _persistMaxReadingsPerSource = 250;
  // ...
  Timer? _stalenessPersistTimer;
  Timer? _midnightBoundaryTimer;
  String? _activeLocalDayIso;
  Future<void>? _dayBoundaryInFlight;
  DateTime? _lastPersistAt;
  bool _livePipelineStarted = false;
  DateTime? _backgroundedAt;
  int? _stepsAtBackground;
  Future<void>? _persistInFlight;
  Future<void>? _lifecycleTransitionInFlight;
  Stopwatch? _coldStartStopwatch;
  bool _coldStartReadyLogged = false;
  bool _appInBackground = false;
```

### Lifecycle mutex — do NOT regress (Story 14-2)

`runSerializedLifecycleTransition` and `_enqueueLifecycleTransition` hardening are **production-critical**. The coordinator must call the same helper:

```213:222:lib/app.dart
  Future<void> _enqueueLifecycleTransition(
    Future<void> Function() operation,
  ) {
    return runSerializedLifecycleTransition(
      readInFlight: () => _lifecycleTransitionInFlight,
      writeInFlight: (future) => _lifecycleTransitionInFlight = future,
      operation: operation,
    );
  }
```

`test/app_lifecycle_transition_test.dart` imports helpers from `package:astra_app/app.dart` — preserve that import path.

### Today Display Truth Model (must preserve)

From `architecture.md` and `_bindLiveMonitorToToday` comments:

1. Cold start: `refresh(silent: true)` loads SQLite baseline **before** live overlay attach
2. Resume catch-up: `syncSteps(..., foregroundCatchUp: true)` then `attachLiveMonitor(replayLatest: !catchUpActive)`
3. Day rollover: persist → `resetForNewLocalDay` → `refreshAfterDayRollover` → re-sync steps
4. **Never** run `DataLifecycleService.runMaintenance` on foreground resume (comment at lines 256–258)

### `mounted` handling pattern

Coordinator cannot extend `State`. Inject:

```dart
AppLifecycleCoordinator({
  required this.deps,
  required bool Function() isMounted,
  required bool Function() showMainShell,
  // ...
});
```

Every `if (!mounted) return;` in current pipeline methods becomes `if (!isMounted()) return;`. Do **not** remove these guards — they prevent post-dispose cubit/DB calls.

### DI wiring pattern (follow `HealthForegroundServiceCoordinator`)

```12:18:lib/core/services/health_foreground_service.dart
/// Android health FGS coordinator — platform channel + lifecycle policy hooks.
class HealthForegroundServiceCoordinator {
  HealthForegroundServiceCoordinator({ ... });
```

Add to `AppDependencies`:

```dart
final AppLifecycleCoordinator appLifecycleCoordinator;
```

Construct in `create()` after `liveStepMonitor` + `backgroundCollector` exist (coordinator depends on them). For `AppDependencies.test()`, allow optional override parameter `AppLifecycleCoordinator? appLifecycleCoordinator` for future test injection — default builds real coordinator with test deps.

**Circular dependency note:** Coordinator needs cubit refs that arrive **after** first frame. Do not construct cubits inside coordinator — use late-bound setters from `_onTodayCubitReady` et al.

### `AstraApp` constructor knobs (tests depend on these)

```26:37:lib/app.dart
  const AstraApp({
    // ...
    this.enablePeriodicPersist = true,
    this.enableLiveStepPipeline = true,
    this.maxPersistStaleness = kMaxPersistStaleness,
    this.minPauseForPhoneCatchUp = const Duration(seconds: 10),
  });
```

Pass through to coordinator factory. `app_live_pipeline_lifecycle_test.dart` sets `maxPersistStaleness: Duration(seconds: 1)` — must keep working.

### Foreground backfill contract

```188:192:lib/app.dart
    _foregroundBackfill = widget.enableLiveStepPipeline
        ? _runPersistCycle(enableGoalNotification: false)
        : widget.deps.backgroundCollector.collectOnce(
            enableGoalNotification: false,
          );
```

`AppScaffold` receives this future for Today tab shimmer/backfill coordination:

```871:873:lib/app.dart
                    foregroundBackfill: widget.deps.initialOnboardingComplete
                        ? _foregroundBackfill
                        : null,
```

After extraction: `deps.appLifecycleCoordinator.foregroundBackfill` (or equivalent).

### Suggested coordinator file structure

```
lib/core/services/app_lifecycle_coordinator.dart
├── @visibleForTesting top-level helpers (if moved from app.dart)
├── class AppLifecycleCoordinator
│   ├── constructor + config
│   ├── cubit binders (Today/History/MyData)
│   ├── lifecycle: onLifecycleStateChanged, onAppBackgrounded, onAppForegrounded
│   ├── pipeline: ensure/start/reattach/resume/bind
│   ├── persist: run/enqueue/cycle helpers
│   ├── day boundary + midnight timer
│   ├── activity persist + staleness timer
│   ├── cold-start logging
│   └── dispose()
```

Keep file under ~600 lines; if larger, acceptable for Epic 18-1 (18-2/18-3 split other god classes).

### Unit test strategy (AC #8)

**Prefer fast mocks over widget tests** — audit §6.1 confirms live-pipeline widget suite is ~41s and flaky in full CI.

Minimal mock targets:

| Dependency | Mock approach |
|------------|---------------|
| `BackgroundCollector.collectOnce` | Subclass or manual fake returning `Future.value(0)` |
| `LiveStepMonitor` | Use existing test patterns from `app_live_pipeline_lifecycle_test.dart` or lightweight fake |
| `TimeProvider` | `FakeTimeProvider` from `test/core/time/fake_time_provider.dart` |
| `HealthForegroundServiceCoordinator` | `RecordingHealthFgs` from `test/helpers/recording_health_fgs.dart` |

Example test sketch:

```dart
test('enqueuePersistCycle serializes overlapping calls', () async {
  var concurrent = 0;
  var maxConcurrent = 0;
  // fake collector increments concurrent, coordinator should keep maxConcurrent == 1
});
```

### Integration test expectations

`test/app_live_pipeline_lifecycle_test.dart`:

- Tagged `@Tags(['slow'])` — excluded from default `flutter test --exclude-tags slow`
- `_kSkipFlakyLivePipeline` skip reason documented — **do not remove** in this story
- Tests use `pumpWidget(AstraApp(deps: deps, ...))` — public API must remain stable
- `_waitForResumePipelineComplete` drains async coordinator work — if tests fail, likely missing `await` on coordinator futures or broken cubit binding

### Previous epic intelligence

| Story | Learning for 18-1 |
|-------|-------------------|
| 14-2 | Extract `@visibleForTesting` helpers for mutex; fast unit tests beat flaky widget harness |
| 16-1 | Repository contracts exist — coordinator uses concrete `AppDependencies` services (no new abstractions needed) |
| 16-7 | Cold-start logging (`_coldStartStopwatch`, `_logColdStartPhase`) is user-visible perf telemetry — preserve log points |
| 17-3 | Refacto stories use sub-task stop points + review briefs; minimal behavioural change |

### Git intelligence (recent commits)

Recent work on `refacto` branch is Epic 17 (nav squircle, file_picker pin). No conflicting edits to `app.dart` expected. Last lifecycle hardening: Story 14-2 (`runSerializedLifecycleTransition` extraction).

### Architecture compliance

| Rule | Application |
|------|-------------|
| `lib/core/services/` for orchestration | `app_lifecycle_coordinator.dart` |
| DI via `AppDependencies` | Add `appLifecycleCoordinator` field |
| No `DateTime.now()` in ingestion | Coordinator uses `deps.timeProvider` (already does via deps) |
| Single writer `BackgroundCollector` | Preserve `_runPersistCycle` pattern |
| Injected `TimeProvider` for day boundary | `_scheduleMidnightBoundaryTimer` uses `deps.timeProvider.snapshot()` |

### Project structure notes

- Story files live in `_bmad-output/implementation-artifacts/stories/` (refacto sprint)
- Tests mirror `lib/` → `test/core/services/app_lifecycle_coordinator_test.dart`
- Do **not** edit `pubspec.yaml` version (Epic 18 close only)
- Do **not** rewrite `docs/BETA_CHECKLIST.md` historical rows

### References

- [Source: _bmad-output/planning-artifacts/epics-refacto.md#Story 18-1]
- [Source: _bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md#1.2a]
- [Source: lib/app.dart — full pipeline implementation]
- [Source: _bmad-output/planning-artifacts/architecture.md — Today Display Truth Model, DI patterns]
- [Source: _bmad-output/implementation-artifacts/stories/14-2-fix-lifecycle-transition-deadlock.md — mutex guardrails]
- [Source: test/app_live_pipeline_lifecycle_test.dart — integration contract]
- [Source: test/app_lifecycle_transition_test.dart — helper import contract]
- [Source: docs/project-context.md — test commands]

## Dev Agent Record

### Agent Model Used

Claude claude-4.6-sonnet-medium-thinking (Cursor)

### Debug Log References

- `flutter analyze` — 0 errors (2 info-level style hints resolved)
- `flutter test --exclude-tags slow` — all pass (~157s)
- `flutter test test/app_live_pipeline_lifecycle_test.dart` (skip removed temporarily) — 13/13 pass (~39s); skip flag restored

### Completion Notes List

- Extracted all live-pipeline orchestration from `_AstraAppState` into injectable `AppLifecycleCoordinator` (`lib/core/services/app_lifecycle_coordinator.dart`, ~848 lines).
- Slimmed `lib/app.dart` to 175 lines — widget shell only: `WidgetsBindingObserver`, `build()`, onboarding transition, thin cubit forwards.
- Wired `deps.appLifecycleCoordinator` via `AppDependencies._buildDependencies()` with `depsGetter` closure to resolve circular DI.
- Re-exported `@visibleForTesting` helpers from `app.dart` — `test/app_lifecycle_transition_test.dart` import path unchanged.
- `AstraApp` constructor knobs passed to coordinator via `bindToWidget()` in `initState`.
- Added 3 fast unit tests in `test/core/services/app_lifecycle_coordinator_test.dart` (persist serialization, day-boundary no-op, FGS handoff).
- Code review follow-up: restore dispose observer order, align tests with `deps.appLifecycleCoordinator`, sqflite-free unit test harness (`test/helpers/coordinator_unit_test_deps.dart`), initializing formal lint fix.
- Live-pipeline integration suite passes in isolation; `_kSkipFlakyLivePipeline` preserved for full CI.
- No version bump (deferred to Epic 18 close per AC #10).
- Manual smoke on device (cold start → walk → BG → resume) not run by dev agent — please verify on Fairphone; integration suite covers equivalent paths (13/13 pass in isolation).

### File List

- `lib/core/services/app_lifecycle_coordinator.dart` (new)
- `lib/app.dart` (modified)
- `lib/core/di/app_dependencies.dart` (modified)
- `test/core/services/app_lifecycle_coordinator_test.dart` (new)
- `test/helpers/coordinator_unit_test_deps.dart` (new)
- `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml` (modified)

### Change Log

- 2026-06-19: Story 18-1 — Extract `AppLifecycleCoordinator` from `app.dart`; DI wiring; fast unit tests; regression green.
- 2026-06-19: Code review follow-up — teardown order, DI-aligned tests, sqflite-free unit harness; story done.
