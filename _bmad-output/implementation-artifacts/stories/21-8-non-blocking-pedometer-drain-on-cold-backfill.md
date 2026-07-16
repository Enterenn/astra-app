# Story 21.8: Non-Blocking Pedometer Drain on Cold Backfill

Status: done

<!-- Post-audit Epic 21 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 21-8 · diagnostic-cold-start.md §A4 · AUD-05 · NFR-AUD-01 -->
<!-- Prerequisite: Stories 21-1…21-7 — done -->
<!-- Version bump: deferred to Epic 21 close (minor+1, patch=0, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want cold-start catch-up not to wait on empty pedometer drains,
So that background backfill finishes faster when the live monitor is not yet running.

## Acceptance Criteria

1. **Given** cold-start foreground backfill runs from `bindToWidget` before the live monitor is active
   **When** `MonitorDrainSource` falls back to `PhonePedometerSource` (monitor stopped)
   **Then** the cold backfill path passes `sourceTimeout: Duration.zero` (or equivalent skip) into `collectOnce` (AUD-05)
   **And** empty phone drains do **not** block ~2 s per source waiting for readings that cannot exist yet

2. **Given** the live pipeline has started (`_livePipelineStarted == true`) and the monitor is running
   **When** a normal persist cycle runs (idle flush, pause, staleness, resume drain)
   **Then** default `BackgroundCollector.sourceTimeout` (**2 s/source**) is still used — genuine buffered drains remain bounded

3. **Given** cold backfill uses zero source timeout
   **When** collection completes
   **Then** `IngestionCollectionLock` acquire/release semantics are unchanged (single-writer rule preserved)
   **And** `_reconcileAfterBackfillCompletes` / post-backfill Today reconcile behaviour from Story 21-2 is unchanged

4. **Given** phone fallback would eventually emit a reading (pocket walk before monitor bind)
   **When** cold backfill runs with zero timeout before first event
   **Then** collection may upsert zero buckets (acceptable trade-off per diagnostic A4 — monitor + subsequent persist cycles catch up)
   **And** Today Display Truth Model is not regressed (fast-path SQLite remains visible; no downward flicker)

5. **Given** `enableLiveStepPipeline: false`
   **When** `bindToWidget` uses `backgroundCollector.collectOnce` for backfill
   **Then** existing behaviour unchanged unless trivially safe — **out of scope**

6. **Given** unit tests
   **When** story verification runs
   **Then** at least one test proves cold-start backfill passes zero/skip timeout while a post-pipeline persist keeps default timeout
   **And** `flutter test test/core/services/app_lifecycle_coordinator_test.dart` passes
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-05 · NFR-AUD-01 (removes residual 1–2 s invisible backfill wait) · diagnostic-cold-start §A4

**Depends on:** Stories 21-1…21-7 — **done**

**Out of scope:** Changing `MonitorDrainSource` fallback logic, resume phone peek timeout (`kResumePhoneCatchUpTimeout`), WorkManager isolate timeouts, version bump (Epic 21 close), Epic 22 dispose hardening.

## Tasks / Subtasks

- [x] **Sub-task A — Pass zero timeout on cold-start backfill** (AC: #1, #3)
  - [x] Read fully: `lib/core/services/app_lifecycle_coordinator.dart` — `bindToWidget` (L180–184), `_runPersistCycle` (L325–344), `_enqueuePersistCycle` / `_persistCycleWithOptionalSync` (L357–388)
  - [x] Update cold-start assignment:
    ```dart
    _foregroundBackfill = enableLiveStepPipeline
        ? _runPersistCycle(
            enableGoalNotification: false,
            sourceTimeout: Duration.zero,
          )
        : deps.backgroundCollector.collectOnce(
            enableGoalNotification: false,
          );
    ```
  - [x] Optional clarity: file-local `static const _coldStartBackfillSourceTimeout = Duration.zero;` — do **not** add shared constants file
  - [x] Confirm `_persistCycleWithOptionalSync` / `_enqueuePersistCycle` still call `_runPersistCycle` **without** overriding `sourceTimeout` (preserves AC #2)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Unit tests for timeout routing** (AC: #2, #6)
  - [x] Extend `test/core/services/app_lifecycle_coordinator_test.dart`
  - [x] Add `_SourceTimeoutCapturingBackgroundCollector` (records `sourceTimeout` from each `collectOnce` call)
  - [x] Test **cold start**: `bindToWidget` + `await foregroundBackfill` → captured timeout == `Duration.zero`
  - [x] Test **post-pipeline persist**: after `onTodayCubitReady` + pipeline started, call `enqueuePersistCycleForTest(enableGoalNotification: false)` → captured timeout is `null` (defaults to 2 s) **or** explicitly `Duration(seconds: 2)` if coordinator passes default — assert not zero
  - [x] Optional timing guard: hanging phone fallback + zero timeout completes in < 200 ms (reuse pattern from `_DelayingBackgroundCollector` / empty stream)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Regression** (AC: #6)
  - [x] Run: `flutter test test/core/services/app_lifecycle_coordinator_test.dart`
  - [x] Run: `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Zero/skip `sourceTimeout` on cold `_foregroundBackfill` | Rewriting `MonitorDrainSource` to skip phone fallback |
| Preserve default timeout on running-monitor persist cycles | Resume `peekPhoneStepEvent` timeout (8 s) |
| Unit tests proving timeout routing | `enableLiveStepPipeline: false` path |
| Ingestion lock unchanged | Version bump until Epic 21 closes |

### Root cause (read before editing)

**Cold-start backfill starts before monitor bind:**

```180:184:lib/core/services/app_lifecycle_coordinator.dart
    _foregroundBackfill = enableLiveStepPipeline
        ? _runPersistCycle(enableGoalNotification: false)
        : deps.backgroundCollector.collectOnce(
            enableGoalNotification: false,
          );
```

**Monitor not running → phone fallback + 2 s timeout:**

```27:36:lib/data/datasources/monitor_drain_source.dart
  Stream<StepReading> watchStepReadings() async* {
    if (_monitor.isRunning) {
      final readings = await _monitor.drainReadingsForCollectionGated();
      // ...
      return;
    }
    yield* _phoneFallback.watchStepReadings();
  }
```

```31:31:lib/core/services/background_collector.dart
    this.sourceTimeout = const Duration(seconds: 2),
```

```218:222:lib/core/services/background_collector.dart
    await for (final reading in _delegate.watchStepReadings().timeout(
      timeout,
      onTimeout: (sink) {
        sink.close();
      },
```

Diagnostic A4: empty phone drain adds **1–2 s** even with instant SQLite [Source: diagnostic-cold-start.md L93, §A4 L229–233].

**Story 21-2 already decoupled backfill from first paint** — this story removes the residual invisible wait so `_foregroundBackfill` completes faster and post-backfill reconcile runs sooner.

### Target implementation (guidance)

Only change the `bindToWidget` cold backfill call site (Sub-task A). Do **not** blanket-zero all `_runPersistCycle` calls — post-pipeline cycles must keep 2 s timeout for genuine drains.

**Timeout routing summary:**

| Call site | Monitor state | Expected `sourceTimeout` |
|-----------|---------------|--------------------------|
| `bindToWidget` → `_foregroundBackfill` | Stopped (cold) | `Duration.zero` |
| `_enqueuePersistCycle` → `_runPersistCycle` | Running | `null` → default 2 s |
| `_enqueuePersistCycleReturningCount` (resume) | Running | `null` → default 2 s |

### Regression cautions

| Risk | Mitigation |
|------|------------|
| Zero timeout on all persist cycles | Only pass override in `bindToWidget` cold backfill assignment |
| Breaking ingestion lock | Do not bypass `collectOnce` / lock — only change timeout param |
| Missing pocket steps before monitor bind | Acceptable per A4; monitor + later persist cycles recover |
| `_runPersistCycle` reconcile while monitor stopped | Pre-existing on cold backfill — do not refactor in this story |
| Test false positive (mock never calls real collector) | Use `_SourceTimeoutCapturingBackgroundCollector` wrapping real `super.collectOnce` or recording param before delegate |

### Architecture compliance

- **Single writer:** `BackgroundCollector` remains sole bucket writer; lock path unchanged [Source: architecture.md Display Truth / ingestion].
- **Coordinator owns lifecycle timing:** Timeout policy belongs in `AppLifecycleCoordinator`, not in `MonitorDrainSource` [Source: epics-post-audit target files].
- **Display Truth Model:** Fast-path SQLite + post-backfill reconcile from 21-2 unchanged — this story only shortens backfill duration [Source: architecture.md Today Display Truth Model].
- **OK-commit gate:** One commit per sub-task [Source: docs/project-context.md].

### Project structure notes

| Path | Role |
|------|------|
| `lib/core/services/app_lifecycle_coordinator.dart` | **UPDATE** — zero timeout on cold `_foregroundBackfill` |
| `lib/core/services/background_collector.dart` | **READ** — default timeout + `_TimeoutBoundedSource` |
| `lib/data/datasources/monitor_drain_source.dart` | **READ** — monitor-stopped fallback behaviour |
| `test/core/services/app_lifecycle_coordinator_test.dart` | **UPDATE** — timeout routing tests |
| `test/data/datasources/monitor_drain_source_test.dart` | **READ** — drain/fallback patterns |

### Testing requirements

- **Primary:** `flutter test test/core/services/app_lifecycle_coordinator_test.dart`
- **Full:** `flutter test --exclude-tags slow`
- **Capturing collector sketch:**
  ```dart
  class _SourceTimeoutCapturingBackgroundCollector extends BackgroundCollector {
    Duration? lastSourceTimeout;

    @override
    Future<int> collectOnce({
      int maxReadingsPerSource = 50,
      bool enableGoalNotification = false,
      Duration? sourceTimeout,
    }) async {
      lastSourceTimeout = sourceTimeout;
      return super.collectOnce(
        maxReadingsPerSource: maxReadingsPerSource,
        enableGoalNotification: enableGoalNotification,
        sourceTimeout: sourceTimeout,
      );
    }
  }
  ```
- Reuse existing cold-start harness: `buildCoordinatorUnitTestDeps`, `_boundCoordinator`, `_DelayingBackgroundCollector` patterns from 21-2/21-3 tests.
- Existing cold-start ordering / seed tests must not regress.

### Previous story intelligence (21-7)

- **Epic tracker:** Use `sprint-status-post-audit.yaml`, not legacy `sprint-status.yaml`.
- **Scope discipline:** Single concern — 21-7 guarded Trends refresh; 21-8 is coordinator timeout only.
- **Test rigor:** 21-7 review required upsert > 0 to fire callbacks — less relevant here but keep focused assertions.
- **Deferred enrichment pattern:** 21-1/21-2 moved paint off backfill; 21-8 finishes removing backfill latency itself.

### Previous story intelligence (21-2 / 21-3)

- **21-2 M1:** Post-backfill reconcile must run **after** monitor bind — do not reorder `_reconcileAfterBackfillCompletes`.
- **21-3:** Post-backfill reconcile intentionally does full DB read — separate from bind-path dedup.
- **`_DelayingBackgroundCollector`:** Proven pattern for cold-start timing tests — extend, don't duplicate harness.

### Git intelligence

Recent Epic 21 commits:
- `efa562f` — story 21-7 done (Trends guard)
- `0cb5f34` — story 21-6 done (end_time index)
- `84a3495` — story 21-5 done (batch goals)

Pattern: small coordinator diff + focused unit test; commit prefix `fix(cold-start):` or `perf(cold-start):`; sub-task OK-commit gate.

### Latest tech notes

- **Dart `Stream.timeout(Duration.zero)`:** Closes stream immediately if no synchronous event — correct for skip-empty-drain semantics on cold start.
- **No new packages.**
- **Flutter/Dart:** No API changes beyond existing optional `sourceTimeout` param on `collectOnce` / `_runPersistCycle`.

### Project context reference

- OK-commit gate: sub-task → review brief → Baptiste OK → commit
- Tests: `flutter test --exclude-tags slow`
- Commit example: `perf(cold-start): skip pedometer drain timeout on cold backfill (story 21-8)`
- Version bump: Epic 21 close only (`minor+1, patch=0, build+1`)

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` — Story 21-8, AUD-05]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-cold-start.md` — §A4, L79–93]
- [Source: `_bmad-output/implementation-artifacts/stories/21-2-decouple-foreground-backfill-from-first-today-paint.md` — backfill decouple, post-backfill reconcile]
- [Source: `_bmad-output/implementation-artifacts/stories/21-7-guard-trends-refresh-on-ingestion-by-active-tab.md` — epic patterns, sprint tracker]
- [Source: `lib/core/services/app_lifecycle_coordinator.dart`]
- [Source: `lib/core/services/background_collector.dart`]
- [Source: `lib/data/datasources/monitor_drain_source.dart`]
- [Source: `test/core/services/app_lifecycle_coordinator_test.dart`]
- [Source: `docs/project-context.md`]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-5 (Cursor)

### Debug Log References

- `_runPersistCycle` already had `Duration? sourceTimeout` param — single-line call-site change sufficient.
- `_persistCycleWithOptionalSync` confirmed not passing sourceTimeout → null → 2 s default preserved (AC #2).
- Post-pipeline persist test: uses `pumpEventQueue()` x2 after `foregroundBackfill` to let `_startLivePipelineFirstTime` set `_livePipelineStarted = true` before exercising `enqueuePersistCycleForTest`.

### Completion Notes List

- Sub-task A: `bindToWidget` cold-start call passes `sourceTimeout: Duration.zero` to `_runPersistCycle`. Only this one call site changed. All `_enqueuePersistCycle` / `_persistCycleWithOptionalSync` paths unchanged.
- Sub-task B: Added `_SourceTimeoutCapturingBackgroundCollector`; 2 new tests — cold-start asserts `Duration.zero`, post-pipeline asserts `null`. Both pass.
- Sub-task C: 7/7 coordinator tests pass; 855/855 full suite (--exclude-tags slow) pass. Zero regressions.

### File List

- `lib/core/services/app_lifecycle_coordinator.dart` (modified)
- `test/core/services/app_lifecycle_coordinator_test.dart` (modified)

## Change Log

- 2026-07-16: Story context created (ready-for-dev) — ultimate context engine analysis completed
- 2026-07-16: Story implemented and completed (review) — commits bdc6d53 (sub-task A) + fbbb1d9 (sub-tasks B+C)
- 2026-07-16: Code review passed — marked done
