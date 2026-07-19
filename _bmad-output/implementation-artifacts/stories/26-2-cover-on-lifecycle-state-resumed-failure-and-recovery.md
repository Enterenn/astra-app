# Story 26.2: Cover onLifecycleStateResumed Failure and Recovery

Status: review

<!-- Post-audit Epic 26 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 26-2 · diagnostic-couverture-structurelle.md Top #1 · AUD-51 -->
<!-- Prerequisite: Story 26-1 done; Epic 25-2 coordinator split done -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **developer**,
I want resume orchestration tested including forced pipeline failure,
So that the resume `catch` path cannot regress silently.

## Acceptance Criteria

1. **Given** `AppLifecycleCoordinator.onLifecycleStateResumed`
   **When** unit/orchestration tests run
   **Then** at least one test **invokes the method by name** (`coordinator.onLifecycleStateResumed()`) inside a dedicated `group('onLifecycleStateResumed')` or test name containing `onLifecycleStateResumed` (AUD-51)
   **And** tests do **not** require a full app widget tree — use `buildCoordinatorUnitTestDeps` + contract fakes (NFR-AUD-06)

2. **Given** live pipeline already started (`enableLiveStepPipeline: true`, cold start via `onTodayCubitReady`, pause via `onLifecycleStatePaused`)
   **When** `onLifecycleStateResumed()` runs on the happy path
   **Then** the test asserts resume orchestration side effects:
   - Health FGS stops and UI becomes active (`RecordingHealthFgs`: `stop`, `uiActive:true`)
   - `resumeLivePipeline` completes (`monitor.reconcileFromDatabase` / `bindLiveMonitorToToday(foregroundCatchUp: true)` exercised)
   - `TodayCubit.setLiveStepAppliesPaused(false)` in `finally` — live overlay unpaused after resume

3. **Given** the same pause/resume setup with live pipeline active
   **When** `resumeLivePipeline` is forced to fail mid-flight (e.g. monitor throws on `reconcileFromDatabase` or `bindLiveMonitorToToday` path)
   **Then** the **`catch` in `LifecycleLivePipelineService.resumeLivePipeline`** is exercised (AUD-51 error-path requirement)
   **And** `onLifecycleStateResumed()` **still completes** (error swallowed inside pipeline — must not crash coordinator)
   **And** `setLiveStepAppliesPaused(false)` runs in **`finally`** even on failure — cubit must not stay stuck paused
   **And** app remains usable (no unhandled async error propagating to test harness)

4. **Given** existing pause test in `app_lifecycle_coordinator_test.dart` (`onLifecycleStatePaused hands off to health FGS`)
   **When** this story ships
   **Then** coverage is **extended, not duplicated** — new `group('onLifecycleStateResumed')` owns AUD-51 contract
   **And** prior pause/serialization/day-boundary tests remain green

5. **Given** OK-commit gate per `docs/project-context.md`
   **When** implementing
   **Then** split into reviewable sub-tasks (named group + happy resume + failure catch + verify) with one commit per sub-task after Baptiste approval
   **And** no version bump until Epic 26 closes

**Covers:** AUD-51 · diagnostic-couverture-structurelle.md Top #1

**Depends on:** Story 26-1 **done**; Epic 25-2 (coordinator split). Independent of 26-3…26-6.

**Out of scope:** Changing resume/peek/catch-up algorithms; widget integration harness (`app_live_pipeline_lifecycle_test.dart`); non-live resume branch (`enableLiveStepPipeline: false` uses persist-only path — optional extra test, not required by AUD-51); version bump.

## Tasks / Subtasks

- [x] **Sub-task A — Baseline + gap analysis** (AC: #1, #4)
  - [x] Read `onLifecycleStateResumed` façade + `_onAppForegrounded` + `LifecycleLivePipelineService.resumeLivePipeline`
  - [x] Grep `test/` for `onLifecycleStateResumed` and `resumeLivePipeline` — confirm **zero** named coverage (AUD-51)
  - [x] Note widget-only indirect exercise via `AppLifecycleState.resumed` in integration tests — out of scope for AUD-51
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (plan-only commit optional)

- [x] **Sub-task B — Named happy-path `onLifecycleStateResumed` group** (AC: #1, #2)
  - [x] Add `group('onLifecycleStateResumed', () { ... })` in `test/core/services/app_lifecycle_coordinator_test.dart`
  - [x] Setup helper: bind widget → `onTodayCubitReady` → await cold-start settle → `onLifecycleStatePaused` → assert `setLiveStepAppliesPaused(true)`
  - [x] Test: `onLifecycleStateResumed runs resume pipeline and clears live pause flag` — `RecordingHealthFgs` asserts FGS stop + `uiActive:true`; monitor reconcile/bind side effects observable
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Forced `resumeLivePipeline` failure + recovery** (AC: #3)
  - [x] Add `_ThrowingLiveStepMonitor` (or extend `_SeedCapturingMonitor`) — throws on `reconcileFromDatabase` **only after** cold-start bind (or on resume-specific call count)
  - [x] Test: `onLifecycleStateResumed swallows resumeLivePipeline errors and clears live pause flag` — `await coordinator.onLifecycleStateResumed()` completes; cubit live-pause cleared; optional: spy/assert `resume pipeline ERROR` log path reached
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Regression verification** (AC: #4, #5)
  - [x] Run `flutter test test/core/services/app_lifecycle_coordinator_test.dart --exclude-tags slow`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] Grep confirms test name or group contains `onLifecycleStateResumed`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Named unit tests for `onLifecycleStateResumed` | Resume algorithm changes (peek/catch-up policy) |
| Happy-path resume orchestration via fakes | Full-app widget test harness (`@Tags(['slow'])`) |
| Forced failure in `resumeLivePipeline` catch/finally | Production logic changes unless test exposes bug |
| Reuse existing test doubles + `RecordingHealthFgs` | New test helper package / broad refactor |
| OK-commit sub-task gate | Version bump (Epic 26 close) |

### Root cause (read before editing)

**Coverage gap (AUD-51):** `diagnostic-couverture-structurelle.md` Top #1 flags `onLifecycleStateResumed` as **never targeted by method name** in `test/`. Resume is exercised indirectly at widget level (`AppLifecycleState.resumed` in slow integration tests) but:
- CI/audit grep for `\bonLifecycleStateResumed\b` fails
- The **`catch` block in `resumeLivePipeline`** (formerly `_resumeLivePipeline`) has **never been forced** — silent regression risk on foreground recovery

**Why it matters:** Resume orchestrates FGS handoff, persist drain, phone peek, monitor reconcile, and cubit sync. A broken `catch`/`finally` leaves the UI stuck with `setLiveStepAppliesPaused(true)` — live steps freeze after unlock.

### Production call chain (MUST preserve — do not change in this story)

```
AstraApp.didChangeAppLifecycleState(resumed)
  → coordinator.onLifecycleStateResumed()
    → _enqueueLifecycleTransition(_onAppForegrounded)
```

**Façade** (`lib/core/services/app_lifecycle_coordinator.dart` L155–157, L219–247):

```dart
Future<void> onLifecycleStateResumed() {
  return _enqueueLifecycleTransition(_onAppForegrounded);
}

Future<void> _onAppForegrounded() async {
  _session.appInBackground = false;
  await deps.databaseSession.ensureOpen();
  await healthFgs.stopHealthCollectionService();
  await healthFgs.setUiActive(true);
  if (enableLiveStepPipeline && _session.shellVisible()) {
    await _livePipeline.resumeLivePipeline();  // errors caught inside
  } else {
    await _persist.enqueuePersistCycle(...);
    // metadata/history/myData refresh
  }
  if (_session.livePipelineStarted && enablePeriodicPersist) {
    _persist.startActivityBasedPersist();
  }
  if (_session.livePipelineStarted) {
    _dayBoundary.wireLiveMonitorDayBoundaryCallbacks();
    _dayBoundary.scheduleMidnightBoundaryTimer();
  }
}
```

**Resume pipeline** (`lib/core/services/lifecycle/lifecycle_live_pipeline_service.dart` L40–137):

1. `runLocalDayBoundaryIfNeeded()`
2. `getTodaySteps()` → `enqueuePersistCycleReturningCount` (drain)
3. Phone peek decision (`shouldRunResumePhoneCatchUp` / `shouldRunResumePhonePeek`)
4. Monitor reconcile/start
5. `bindLiveMonitorToToday(foregroundCatchUp: true)`
6. Cubit metadata + history/myData silent refresh
7. **`catch`:** logs `resume pipeline ERROR`, `debugPrintStack` in debug — **does not rethrow**
8. **`finally`:** `session.todayCubit?.setLiveStepAppliesPaused(false)` — **always runs**

**Pause setup** (`_onAppBackgrounded` L194–217): sets `appInBackground`, `setLiveStepAppliesPaused(true)`, starts FGS.

### Current test file state (UPDATE — read fully)

**Primary target:** `test/core/services/app_lifecycle_coordinator_test.dart` (~860 LOC after 26-1)

| Existing test | Calls `onLifecycleStateResumed`? | AUD-51 gap |
|---------------|----------------------------------|------------|
| `onLifecycleStatePaused hands off to health FGS when shell visible` | No (pause only L398) | Complementary — reuse FGS pattern |
| `group('onTodayCubitReady')` (26-1) | No | Provides cold-start/live-pipeline setup pattern |
| Widget tests (`app_live_pipeline_lifecycle_test.dart`) | Indirect via lifecycle | Slow tag — not AUD-51 contract |

**Reuse — do not reinvent:**

- `buildCoordinatorUnitTestDeps` — `test/helpers/coordinator_unit_test_deps.dart`
- `_boundCoordinator` / manual `bindToWidget` + `onTodayCubitReady` — cold-start live pipeline
- `RecordingHealthFgs` — `test/helpers/recording_health_fgs.dart` (already used in pause test L398)
- `_NoOpBackgroundCollector`, `_ColdStartStepAggregation`, `_CountingStepAggregation` — minimal TodayCubit fakes
- `_SeedCapturingMonitor` pattern — extend for throw-on-resume spy

**Suggested failure injection (pick one — minimal scope):**

```dart
class _ThrowingOnResumeMonitor extends LiveStepMonitor {
  _ThrowingOnResumeMonitor({...}) : _reconcileCalls = 0;
  int _reconcileCalls;

  @override
  Future<void> reconcileFromDatabase({int? seedPersistedSteps}) async {
    _reconcileCalls++;
    if (_reconcileCalls >= 2) {
      throw StateError('forced resume pipeline failure');
    }
    return super.reconcileFromDatabase(seedPersistedSteps: seedPersistedSteps);
  }
}
```

Cold start bind calls reconcile once; resume path calls again → throws inside `resumeLivePipeline` try block.

**Pause/resume test skeleton:**

```dart
group('onLifecycleStateResumed', () {
  test('onLifecycleStateResumed runs resume pipeline and clears live pause flag', () async {
    final fgs = RecordingHealthFgs(calls: []);
    // ... build deps with fgs, enableLiveStepPipeline: true
    final coordinator = await _boundCoordinator(deps, enableLiveStepPipeline: true);
    final todayCubit = TodayCubit(...);
    coordinator.onTodayCubitReady(todayCubit);
    await coordinator.foregroundBackfill;
    await pumpEventQueue();

    await coordinator.onLifecycleStatePaused();
    expect(todayCubit.state.liveStepAppliesPaused, isTrue); // verify field name in TodayState

    await coordinator.onLifecycleStateResumed();
    expect(fgs.calls, contains('stop'));
    expect(fgs.calls, contains('uiActive:true'));
    expect(todayCubit.state.liveStepAppliesPaused, isFalse);

    await todayCubit.close();
  });
});
```

**Verify `TodayState` field:** grep `liveStepAppliesPaused` / `setLiveStepAppliesPaused` in `today_state.dart` — use the public getter the cubit exposes.

### Architecture compliance

- **Today Display Truth Model:** Resume catch-up uses `bindLiveMonitorToToday(foregroundCatchUp: true)` — tests assert orchestration, not display math [Source: architecture.md]
- **No maintenance on resume:** `_onAppForegrounded` explicitly avoids `DataLifecycleService.runMaintenance` — do not add maintenance calls in tests
- **NFR-AUD-06:** Prefer unit/fault-injection over FFI/widget for lifecycle entry points
- **Layering post-25-2:** Tests stay on public `AppLifecycleCoordinator` API; failure injected via `LiveStepMonitor` fake in deps — no need to import `LifecycleLivePipelineService` unless spying requires it
- **Error swallowing is intentional:** `resumeLivePipeline` catch prevents resume crash — test must assert **completion + finally side effect**, not expect rethrow

### File structure requirements

| Action | Path |
|--------|------|
| **UPDATE** | `test/core/services/app_lifecycle_coordinator_test.dart` — add `group('onLifecycleStateResumed')`, optional `_ThrowingOnResumeMonitor` |
| **READ ONLY** | `lib/core/services/app_lifecycle_coordinator.dart` |
| **READ ONLY** | `lib/core/services/lifecycle/lifecycle_live_pipeline_service.dart` |
| **READ ONLY** | `test/helpers/coordinator_unit_test_deps.dart`, `test/helpers/recording_health_fgs.dart` |
| **DO NOT** | `test/app_live_pipeline_lifecycle_test.dart` (slow tag — out of scope) |

### Testing requirements

**Default verify command:**

```bash
flutter test test/core/services/app_lifecycle_coordinator_test.dart --exclude-tags slow
flutter test --exclude-tags slow
```

**AUD-51 verification grep:**

```bash
rg "onLifecycleStateResumed" test/core/services/app_lifecycle_coordinator_test.dart
```

Expect: group name + test bodies calling `coordinator.onLifecycleStateResumed(`.

**Assertions checklist (happy path):**

- [ ] `coordinator.onLifecycleStateResumed()` is the **explicit** test entry
- [ ] Preceded by `onLifecycleStatePaused()` with live pipeline started
- [ ] FGS `stop` + `uiActive:true` recorded
- [ ] `liveStepAppliesPaused` cleared after resume
- [ ] `todayCubit.close()` + monitor dispose in test end

**Failure path:**

- [ ] Forced throw inside `resumeLivePipeline` try block
- [ ] `await coordinator.onLifecycleStateResumed()` completes without test failure
- [ ] `liveStepAppliesPaused` still cleared (`finally`)
- [ ] Optional: assert monitor reconcile was attempted before throw

### Previous story intelligence (26-1)

- Story 26-1 established `group('onTodayCubitReady')` pattern — same file, same helpers, same OK-commit gate
- Sub-task structure A→B→C→D worked well; mirror for resume
- Code review on 26-1 hardened ordering guards — apply same rigor to pause-before-resume setup (await backfill before pause)
- Full fast suite green at 947+ tests after 26-1 — extend, do not break cold-start group

### Git intelligence

Recent commits (Story 26-1):

- `29a81b0` — harden onTodayCubitReady guards and close story
- `e7661e4` — named onTodayCubitReady live-pipeline group
- `79ff232` — gap analysis AUD-50

No coordinator resume behaviour changes since 25-2 — safe to add tests only.

### Project context reference

- OK-commit gate mandatory per sub-task — `docs/project-context.md`
- Default test command: `flutter test --exclude-tags slow`
- Version bump at **Epic 26 close** only (patch+1, build+1) — current `0.11.2+27`
- Sprint tracker: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` (not legacy `sprint-status.yaml`)

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` § Story 26-2]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-couverture-structurelle.md` § Top #1, § app_lifecycle_coordinator table]
- [Source: `_bmad-output/implementation-artifacts/stories/26-1-cover-on-today-cubit-ready-cold-start-orchestration.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/25-2-split-app-lifecycle-coordinator-into-focused-services.md` § resumeLivePipeline inventory]
- [Source: `lib/core/services/app_lifecycle_coordinator.dart` L155–157, L219–247]
- [Source: `lib/core/services/lifecycle/lifecycle_live_pipeline_service.dart` L40–137]
- [Source: `test/helpers/coordinator_unit_test_deps.dart`, `test/helpers/recording_health_fgs.dart`]
- [Source: `docs/project-context.md` § Test commands, Story completion checklist]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Sub-task A (2026-07-19): `rg onLifecycleStateResumed|resumeLivePipeline test/` → 0 hits (AUD-51 confirmed). Indirect resume via `AppLifecycleState.resumed` in slow/widget tests. `liveStepAppliesPaused` on `TodayCubit` (not TodayState).
- Sub-task B (2026-07-19): `group('onLifecycleStateResumed')` + happy path — cold start → pause → resume; FGS stop/uiActive:true; reconcile on resume; pause flag cleared.
- Sub-task C (2026-07-19): `_ThrowingOnResumeMonitor` gated by post-pause flag; forced throw inside `resumeLivePipeline` try (persist drain reconcile); coordinator completes; `finally` clears pause flag.
- Sub-task D (2026-07-19): coordinator file 11/11; full fast suite 951 passed (~2 skipped).

### Completion Notes List

- AUD-51 satisfied: named `group('onLifecycleStateResumed')` with explicit `coordinator.onLifecycleStateResumed()` calls (happy + failure paths).
- Happy path asserts FGS stop/uiActive, monitor reconcile on resume, `liveStepAppliesPaused` cleared.
- Failure path forces throw inside `resumeLivePipeline` catch; coordinator completes; pause flag still cleared via `finally`.
- No production code changes; prior pause/onTodayCubitReady tests remain green.

### File List

- `test/core/services/app_lifecycle_coordinator_test.dart`
- `_bmad-output/implementation-artifacts/stories/26-2-cover-on-lifecycle-state-resumed-failure-and-recovery.md`
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`

## Change Log

- 2026-07-19: Story 26-2 — named onLifecycleStateResumed unit tests (happy resume + forced resumeLivePipeline failure recovery); AUD-51.
