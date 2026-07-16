# Story 22.1: Harden LiveStepMonitor Dispose Sequencing

Status: done

<!-- Post-audit Epic 22 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 22-1 · diagnostic-cycle-de-vie-ressoruce.md Reco #1 · AUD-16 -->
<!-- Prerequisite: Epic 21 — done -->
<!-- Version bump: deferred to Epic 22 close (patch+1, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want live step streaming to tear down cleanly when the pipeline stops,
So that dispose never races with a late `start` or closes the controller too early.

## Acceptance Criteria

1. **Given** `LiveStepMonitor.dispose()` is called
   **When** teardown runs
   **Then** `stop()` completes before `_stepsController` is closed (AUD-16)
   **And** a `_disposed` flag is set early so subsequent `start()` is a no-op
   **And** no unhandled async gap allows `start()` after dispose has begun

2. **Given** the monitor is running with an active hardware subscription
   **When** `dispose()` is called
   **Then** subscription cancellation finishes before the steps stream controller closes
   **And** `_emitNow` / `_scheduleEmit` do not add events to a closed controller

3. **Given** `dispose()` has been called (even if async teardown is still in flight)
   **When** `start()` or `peekPhoneStepEvent()` is invoked
   **Then** the call returns safely without re-subscribing to hardware

4. **Given** existing live monitor tests
   **When** this story ships
   **Then** new/updated tests prove dispose ordering and post-dispose start blocking
   **And** `flutter test test/core/services/live_step_monitor_test.dart` passes
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-16 · diagnostic-cycle-de-vie-ressoruce.md Reco #1

**Depends on:** Epic 21 — **done**

**Out of scope:** `HealthForegroundServiceCoordinator.dispose()` (AUD-21 / Story 25-2 area), `AppLifecycleCoordinator` calling `liveStepMonitor.dispose()` in production, stream `onError` fault-injection tests (Epic 26 / Story 26-6), version bump until Epic 22 closes.

## Tasks / Subtasks

- [x] **Sub-task A — Harden dispose sequencing + guards** (AC: #1, #2, #3)
  - [x] Read fully: `lib/core/services/live_step_monitor.dart` — `start()` (L85–117), `stop()` (L119–137), `dispose()` (L318–321), `_emitNow()` (L487–505)
  - [x] Add `bool _disposed = false;` (or equivalent) — set **first** in `dispose()`
  - [x] Guard `start()` with `if (_disposed) return;` at top (before `_running` check)
  - [x] Guard `peekPhoneStepEvent()` with early return `null` when disposed
  - [x] Replace fire-and-forget dispose body with ordered async teardown:
    - Option A (preferred): `Future<void> dispose()` — `await stop(); await _stepsController.close();` with idempotent guard
    - Option B: keep `void dispose()` but defer `_stepsController.close()` to `.then` after `await stop()`; expose `@visibleForTesting Future<void>? get disposeFuture` so tests can await completion
  - [x] Guard `_emitNow` / `_scheduleEmit` / `_onPhoneEvent` against `_disposed` or `_stepsController.isClosed` to prevent `StateError` on closed broadcast controller
  - [x] Do **not** change `stop()` public contract — coordinator still calls `stop()` independently on app teardown
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Dispose ordering unit tests** (AC: #1, #3, #4)
  - [x] Extend `test/core/services/live_step_monitor_test.dart`
  - [x] Test **post-dispose start blocked**: `await monitor.start(); monitor.dispose(); await disposeComplete; await monitor.start();` → `isRunning` stays false, no second stream listen
  - [x] Test **controller closed after subscription**: use a `StreamController` factory that records listen/cancel order; assert cancel happens before `watchTodaySteps` stream completes/errors as closed (not mid-flight add)
  - [x] Test **idempotent dispose**: call `dispose()` twice — no throw
  - [x] Update existing `tearDown` to `await monitor.dispose()` if signature becomes async (or `await monitor.disposeFuture` if Option B)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Regression** (AC: #4)
  - [x] Run: `flutter test test/core/services/live_step_monitor_test.dart`
  - [x] Run: `flutter test test/core/services/live_step_monitor_day_rollover_test.dart`
  - [x] Run: `flutter test test/core/services/app_lifecycle_coordinator_test.dart`
  - [x] Run: `flutter test test/presentation/cubits/today_cubit_test.dart`
  - [x] Run: `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| `LiveStepMonitor.dispose()` ordering + `_disposed` guard | Wiring `dispose()` into `AppDependencies` / production app shutdown |
| Guards on `start`, `peekPhoneStepEvent`, emit paths | `HealthForegroundServiceCoordinator.dispose()` (Story 25-2 / AUD-21) |
| Unit tests for dispose ordering | Epic 26 fault-injection for stream `onError` |
| Preserve existing `stop()` behaviour for coordinator | Version bump until Epic 22 closes |

### Root cause (read before editing)

**Current dispose races async stop with synchronous controller close:**

```318:321:lib/core/services/live_step_monitor.dart
  void dispose() {
    unawaited(stop());
    _stepsController.close();
  }
```

**Why this matters:**

| Resource | Created in | Teardown today | Risk |
|----------|------------|----------------|------|
| `_subscription` | `start()` | `stop()` → `await cancel` | Hardware events may still arrive while controller already closed |
| `_stepsController` | constructor | `dispose()` → immediate `close()` | `_emitNow` can throw or drop silently on closed controller |
| `_running` flag | `start()` | `stop()` sets false | Late `start()` after dispose can re-open pipeline |

Diagnostic Reco #1: make teardown synchronous **or** block `start()` after dispose [Source: diagnostic-cycle-de-vie-ressoruce.md L196].

**Production note:** `AppLifecycleCoordinator.dispose()` calls `unawaited(deps.liveStepMonitor.stop())` but does **not** call `liveStepMonitor.dispose()` [Source: app_lifecycle_coordinator.dart L239–243]. Production relies on `stop()` for app shutdown; `dispose()` is exercised heavily in tests (`live_step_monitor_test.dart`, `today_cubit_test.dart`, coordinator tests). Hardening `dispose()` fixes test/hot-restart hygiene and establishes the contract if production ever disposes the monitor.

### Target implementation (guidance)

**Minimum viable fix (AC-compliant):**

1. `_disposed = true` at the very start of `dispose()` — blocks `start()` immediately.
2. `await stop()` before `_stepsController.close()`.
3. Idempotent `dispose()` (second call no-op).
4. Emit guards: skip `_stepsController.add` when `_disposed || _stepsController.isClosed`.

**Signature choice:**

| Approach | Pros | Cons |
|----------|------|------|
| `Future<void> dispose()` | Clean await in tests; explicit contract | Update ~10 test call sites to `await monitor.dispose()` |
| `void dispose()` + test-visible `disposeFuture` | Minimal caller churn | Slightly awkward test API |

Prefer `Future<void> dispose()` — matches Dart service lifecycle patterns and makes AC #1 testable without polling.

**Do not** make `stop()` set `_disposed` — coordinator pause/resume still calls `stop()`/`start()` during normal app life.

### Regression cautions

| Risk | Mitigation |
|------|------------|
| Breaking coordinator pause/resume | Only set `_disposed` in `dispose()`, never in `stop()` |
| `watchTodaySteps` subscribers get abrupt close | Expected on dispose; tests already cancel subs in tearDown |
| Double-close `StreamController` | Guard with `if (!_stepsController.isClosed)` |
| Async `start()` racing dispose | Check `_disposed` at top of `start()` **and** after each `await` inside `start()` |
| `peekPhoneStepEvent` orphan subscription | Return `null` immediately when disposed; existing timeout/cancel path unchanged otherwise |

### Architecture compliance

- **Single writer unchanged:** `LiveStepMonitor` still never writes buckets; dispose hardening is lifecycle-only [Source: architecture.md live overlay path].
- **Display Truth Model unchanged:** No change to reconcile/seed/monotonic rules from Epic 21 [Source: epics-post-audit cross-cutting].
- **Coordinator owns pipeline orchestration:** Do not move stop/dispose policy into coordinator in this story [Source: epics-post-audit target files].
- **OK-commit gate:** One commit per sub-task [Source: docs/project-context.md].

### Project structure notes

| Path | Role |
|------|------|
| `lib/core/services/live_step_monitor.dart` | **UPDATE** — dispose sequencing, `_disposed`, emit guards |
| `test/core/services/live_step_monitor_test.dart` | **UPDATE** — dispose ordering tests, async tearDown |
| `test/core/services/live_step_monitor_day_rollover_test.dart` | **READ/UPDATE** — tearDown if dispose becomes async |
| `test/core/services/app_lifecycle_coordinator_test.dart` | **READ** — `captureMonitor.dispose()` call sites |
| `test/presentation/cubits/today_cubit_test.dart` | **READ** — monitor dispose in tearDown |
| `lib/core/services/app_lifecycle_coordinator.dart` | **READ** — `stop()` on coordinator dispose (unchanged) |

### Testing requirements

- **Primary:** `flutter test test/core/services/live_step_monitor_test.dart`
- **Related:** day rollover, coordinator, today cubit tests (listed in Sub-task C)
- **Full:** `flutter test --exclude-tags slow`

**Suggested test: post-dispose start blocked**

```dart
test('dispose blocks subsequent start', () async {
  await monitor.start();
  await monitor.dispose();
  await monitor.start();
  expect(monitor.isRunning, isFalse);
});
```

**Suggested test: subscription cancelled before controller close**

Use a factory wrapping `StreamController<PhoneStepEvent>` that records:
- `listenCount`, `cancelCount`, `cancelBeforeClose` (set true when cancel fires before test asserts controller closed)

Pump event queue / await dispose future, then assert ordering.

### Previous story intelligence (21-8 — Epic 21 close)

- **Tracker:** Use `sprint-status-post-audit.yaml`, not legacy `sprint-status.yaml`.
- **Scope discipline:** Single concern — 21-8 was coordinator timeout only; 22-1 is monitor lifecycle only.
- **Test rigor:** Focused unit tests with explicit assertions; full suite gate before done.
- **Commit pattern:** `fix(robustness):` or `fix(live-pipeline):` prefix; sub-task OK-commit gate.
- **Epic 21 learnings:** Cold-start seed/reconcile paths are stable — do not refactor them in this story.

### Git intelligence

Recent commits (Epic 21 close):
- `7db4bcb` — mark Epic 21 done in post-audit tracker
- `2f2d344` / `fbbb1d9` / `bdc6d53` — story 21-8 (coordinator timeout routing)

Pattern: small service diff + focused unit test; one concern per story; review marks done in sprint tracker.

### Latest tech notes

- **`StreamController.close()`** is async as of recent Dart — prefer `await _stepsController.close()` when dispose is async.
- **`StreamController.add` on closed controller** throws in non-broadcast mode; broadcast may silently ignore — still guard to avoid race logs.
- **No new packages.**

### Project context reference

- OK-commit gate: sub-task → review brief → Baptiste OK → commit
- Tests: `flutter test --exclude-tags slow`
- Commit example: `fix(live-pipeline): harden LiveStepMonitor dispose sequencing (story 22-1)`
- Version bump: Epic 22 close only (`patch+1, build+1`)

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` — Story 22-1, AUD-16, Epic 22]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-cycle-de-vie-ressoruce.md` — LiveStepMonitor table, Reco #1]
- [Source: `_bmad-output/implementation-artifacts/stories/21-8-non-blocking-pedometer-drain-on-cold-backfill.md` — epic patterns, sprint tracker]
- [Source: `lib/core/services/live_step_monitor.dart`]
- [Source: `lib/core/services/app_lifecycle_coordinator.dart` — dispose calls stop only]
- [Source: `test/core/services/live_step_monitor_test.dart`]
- [Source: `docs/project-context.md`]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-5

### Debug Log References

### Completion Notes List

- Sub-task A: `dispose()` → `Future<void>`, `_disposed = true` guards `start()` / `peekPhoneStepEvent()` / `_onPhoneEvent` / `_scheduleEmit` / `_emitNow`. Ordered teardown: `await stop()` then `await _stepsController.close()`. Idempotent guard at top.
- Sub-task B: 4 new tests in `dispose sequencing` group — post-dispose start blocked, idempotent dispose, peek returns null after dispose, subscription cancelled before controller closes. All tearDowns updated to `await monitor.dispose()` (5 files).
- Sub-task C: 23/23 live monitor tests pass, 4/4 day rollover, 7/7 coordinator, 53/53 today cubit. Full suite: 859/859 ✅.
- Code review: cancel in-flight peek subscriptions on dispose; ordering test asserts cancel-before-close; +1 test (in-flight peek).

### File List

- `lib/core/services/live_step_monitor.dart`
- `test/core/services/live_step_monitor_test.dart`
- `test/core/services/live_step_monitor_day_rollover_test.dart`
- `test/core/services/app_lifecycle_coordinator_test.dart`
- `test/presentation/cubits/today_cubit_test.dart`

## Change Log

- 2026-07-16: Story context created (ready-for-dev) — ultimate context engine analysis completed
- 2026-07-16: Implemented all sub-tasks A/B/C — dispose hardened, 4 new tests, 859 tests green (review)
- 2026-07-16: Code review fixes — peek cancel on dispose, teardown ordering test; marked done
