# Story 26.6: Add Fault-Injection Tests for Live Monitor Stream Errors

Status: review

<!-- Post-audit Epic 26 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 26-6 · diagnostic-couverture-structurelle.md LiveStepMonitor error paths · AUD-55 · NFR-AUD-06 -->
<!-- Prerequisite: Story 22-1 dispose sequencing done; Story 26-5 done (Epic 26 final story) -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **developer**,
I want LiveStepMonitor stream errors fault-injected in tests,
So that `onError` / peek timeout paths cannot regress unnoticed.

## Acceptance Criteria

1. **Given** `LiveStepMonitor.start` with an injected `stepEventStreamFactory`
   **When** the underlying pedometer stream emits an error via test double (`addError` or error-yielding stream)
   **Then** at least one test in a dedicated `group('stream fault injection')` (or test name containing `start stream onError`) asserts the **onError handler contract** (AUD-55, NFR-AUD-06):
   - monitor remains `isRunning == true` (handler logs only — does **not** auto-stop)
   - no unhandled async exception propagates to the test zone
   - `watchTodaySteps` listener does **not** receive the platform error (broadcast controller unaffected)
   **And** test lives in `test/core/services/live_step_monitor_test.dart` — extend existing file, do not create a parallel harness

2. **Given** monitor is **stopped** and `peekPhoneStepEvent` is invoked
   **When** the peek subscription stream errors before any event
   **Then** test asserts peek returns `null` without throw
   **And** peek subscription is cancelled (`cancelOnError: true` path)
   **And** test name references `peekPhoneStepEvent` + `onError` or `stream error`

3. **Given** monitor is **stopped** and `peekPhoneStepEvent` is invoked with a **short timeout** (e.g. `Duration(milliseconds: 50)`)
   **When** the injected stream emits **no** events before timeout
   **Then** test asserts peek returns `null` (TimeoutException path — AUD-55)
   **And** test name references `peek timeout` or `TimeoutException`
   **And** this complements (does not duplicate) the happy-path peek test at L414–434

4. **Given** existing dispose / reconcile / activity-idle / seed-API tests in `live_step_monitor_test.dart`
   **When** this story ships
   **Then** coverage is **extended, not duplicated** — new fault-injection group owns AUD-55; day-rollover and coordinator resume tests remain green unchanged
   **And** no production changes unless a test exposes a real bug (expected: tests-only)

5. **Given** OK-commit gate per `docs/project-context.md`
   **When** implementing
   **Then** split into reviewable sub-tasks (gap analysis + start onError + peek onError + peek timeout + verify) with one commit per sub-task after Baptiste approval
   **And** no version bump until Epic 26 closes (final Epic 26 story → bump patch+1, build+1 at epic close)

**Covers:** AUD-55 · diagnostic-couverture-structurelle.md § LiveStepMonitor error paths · NFR-AUD-06

**Depends on:** Story 22-1 (dispose guards), Story 26-1…26-5 (Epic 26 patterns). Closes Epic 26 test tranche.

**Out of scope:** Changing production `onError` behavior (e.g. auto-restart on stream death); coordinator `_resumeLivePipeline` catch tests (AUD separate); widget/integration resume harness (`app_live_pipeline_lifecycle_test.dart`); version bump until Epic 26 retrospective/close.

## Tasks / Subtasks

- [x] **Sub-task A — Baseline + gap analysis** (AC: #1, #4)
  - [x] Read `lib/core/services/live_step_monitor.dart` fully — focus `start()` L87–122, `peekPhoneStepEvent()` L145–207
  - [x] Grep `test/` for `addError`, `stream ERROR`, `peek timeout`, `peek stream ERROR` — confirm **zero** fault-injection hits (AUD-55)
  - [x] Note existing peek coverage: happy path L414–434, dispose peek L553–582 — **no** timeout/error paths
  - [x] Note production resume caller: `lifecycle_live_pipeline_service.dart` L77–95 treats `peekPhoneStepEvent == null` as skip catch-up
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (plan-only commit optional)

- [x] **Sub-task B — start() stream onError fault injection** (AC: #1)
  - [x] Add `group('stream fault injection', () { ... })` in `live_step_monitor_test.dart`
  - [x] Test: `start stream onError is logged and monitor stays running` — inject `StreamController` + `events.addError(StateError('pedometer'))` after `await monitor.start()`; assert `isRunning`, no zone error, `watchTodaySteps` listener count unchanged
  - [x] Use `expectLater(..., completes)` / `pumpEventQueue()` to flush async onError callback
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — peekPhoneStepEvent onError path** (AC: #2)
  - [x] Test: `peekPhoneStepEvent returns null when peek stream errors` — factory returns single-subscription stream that errors immediately (or controller.addError before event)
  - [x] Assert result `isNull`, monitor `isRunning` unchanged (peek while stopped)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — peekPhoneStepEvent timeout path** (AC: #3)
  - [x] Test: `peekPhoneStepEvent returns null on timeout when stream is silent` — factory returns never-emitting stream (e.g. empty broadcast with no events), `timeout: Duration(milliseconds: 50)`
  - [x] Assert result `isNull` within reasonable wall time (< 500 ms)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Regression verification + Epic 26 close prep** (AC: #4, #5)
  - [x] Run `flutter test test/core/services/live_step_monitor_test.dart --exclude-tags slow`
  - [x] Run `flutter test test/core/services/live_step_monitor_day_rollover_test.dart test/core/services/app_lifecycle_coordinator_test.dart --exclude-tags slow`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] Grep confirms fault-injection group + `start stream onError` / `peekPhoneStepEvent` error/timeout test names
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Fault-injection unit tests for `start()` stream `onError` | Auto-restart / reconnect production logic |
| Fault-injection for `peekPhoneStepEvent` onError + timeout | Coordinator resume pipeline catch (separate AUD) |
| Extend `live_step_monitor_test.dart` only | New test file unless harness extraction unavoidable |
| Assert behavioral contracts (null return, isRunning, no throw) | Testing `livePipelineLog` output strings |
| OK-commit sub-task gate | Version bump (Epic 26 close — this is last story) |

### Root cause (read before editing)

**Coverage gap (AUD-55):** `diagnostic-couverture-structurelle.md` flags two LiveStepMonitor handlers as **never fault-injected**:

| Method | Handler | Production impact |
|--------|---------|-------------------|
| `start()` L109–120 | `onError` on pedometer subscription | Stream dies silently; monitor stays `_running` — UI freezes live updates until resume/restart |
| `peekPhoneStepEvent()` L168–175 | `onError` on peek subscription | Resume phone catch-up skipped (`null` → no enqueue) |
| `peekPhoneStepEvent()` L195–202 | `TimeoutException` | Same — resume catch-up skipped when hardware slow/absent |

Story 22-1 hardened dispose sequencing and explicitly deferred stream `onError` tests to this story [Source: 22-1 Out of scope L44].

**Why it matters:** `LifecycleLivePipelineService._resumeLivePipeline` calls `peekPhoneStepEvent(timeout: kResumePhoneCatchUpTimeout)` when pocket-walk heuristics fire [Source: `lifecycle_live_pipeline_service.dart` L72–95]. Timeout/error → `null` → catch-up skipped but monitor restarted — must not throw or leave orphan subscriptions (22-1 `_activePeekCancels` guards).

### Production implementation (MUST preserve — do not change unless bug found)

**`start()` subscription — logs only, no stop:**

```109:121:lib/core/services/live_step_monitor.dart
    _subscription = _stepEventStreamFactory().listen(
      _onPhoneEvent,
      onError: (Object error, StackTrace stackTrace) {
        livePipelineLog(
          'monitor',
          'stream ERROR',
          details: {'error': error},
        );
        if (kDebugMode) {
          debugPrintStack(stackTrace: stackTrace);
        }
      },
    );
```

Note: **no** `cancelOnError` — default `false`. After error, subscription is done but `_running` stays true.

**`peekPhoneStepEvent()` — error cancels peek, timeout returns null:**

```164:203:lib/core/services/live_step_monitor.dart
      subscription = _stepEventStreamFactory().listen(
        (event) {
          unawaited(endPeek(result: _disposed ? null : event));
        },
        onError: (Object error, StackTrace stackTrace) {
          livePipelineLog(
            'monitor',
            'peek stream ERROR',
            details: {'error': error},
          );
          unawaited(cancelPeek());
        },
        cancelOnError: true,
      );
      // ...
      try {
        final event = await completer.future.timeout(timeout);
        // ...
        return event;
      } on TimeoutException {
        // ...
        await cancelPeek();
        return null;
      }
```

**Resume consumer (READ ONLY):**

```72:95:lib/core/services/live_step_monitor.dart
      if (needsPhonePeek) {
        final wasRunning = monitor.isRunning;
        if (wasRunning) {
          await monitor.stop();
        }
        final pocketEvent = await monitor.peekPhoneStepEvent(
          timeout: kResumePhoneCatchUpTimeout,
        );
        if (pocketEvent != null) {
          // enqueue + persist
        } else if (wasRunning && !monitor.isRunning) {
          await monitor.start();
        }
      }
```

Tests must assert monitor/peek contracts — **not** re-test coordinator resume orchestration (26-2 territory).

### Current test landscape (UPDATE — read before writing)

| File | Relevant coverage | AUD-55 gap |
|------|-------------------|------------|
| `live_step_monitor_test.dart` | Happy path, dispose, peek ok L414–434, seed API, activity idle | **No** `addError`, **no** peek timeout/error |
| `live_step_monitor_day_rollover_test.dart` | Midnight boundary on monitor | N/A |
| `app_lifecycle_coordinator_test.dart` | Resume orchestration (26-2) | Indirect — no stream fault injection |
| `app_live_pipeline_lifecycle_test.dart` | Widget resume (slow tag) | Out of scope |

Grep baseline (expect before story):

```bash
rg "addError|peek timeout|stream onError|peek stream ERROR" test/core/services/live_step_monitor_test.dart
# → 0 fault-injection hits (only dispose group onError listener at L603)
```

### Reuse patterns — do not reinvent

**Existing harness** (`live_step_monitor_test.dart` L101–124):

```dart
events = StreamController<PhoneStepEvent>.broadcast();
monitor = LiveStepMonitor(
  stepAggregation: stepAggregation,
  baselineRepository: baselineRepository,
  clock: clock,
  stepEventStreamFactory: () => events.stream,
  emitThrottle: Duration.zero,
);
```

**Start onError injection pattern:**

```dart
test('start stream onError is logged and monitor stays running', () async {
  await monitor.start();
  final errors = <Object>[];
  final sub = monitor.watchTodaySteps(replayLatest: false).listen(
    (_) {},
    onError: errors.add,
  );
  events.addError(StateError('pedometer fault'));
  await pumpEventQueue();
  expect(monitor.isRunning, isTrue);
  expect(errors, isEmpty);
  await sub.cancel();
});
```

**Peek onError injection — dedicated factory (avoid polluting shared `events` controller):**

```dart
final peekMonitor = LiveStepMonitor(
  stepAggregation: stepAggregation,
  baselineRepository: baselineRepository,
  clock: clock,
  stepEventStreamFactory: () => Stream<PhoneStepEvent>.error(
    StateError('peek fault'),
  ),
  emitThrottle: Duration.zero,
);
final result = await peekMonitor.peekPhoneStepEvent(
  timeout: const Duration(seconds: 2),
);
expect(result, isNull);
await peekMonitor.dispose();
```

**Peek timeout — silent stream:**

```dart
stepEventStreamFactory: () => const Stream<PhoneStepEvent>.empty(),
// or: StreamController<PhoneStepEvent>().. never add
final result = await peekMonitor.peekPhoneStepEvent(
  timeout: const Duration(milliseconds: 50),
);
expect(result, isNull);
```

**Async flush:** use `await pumpEventQueue()` (already imported via flutter_test) after `addError` — same as dispose peek test L574.

### Architecture compliance

- **NFR-AUD-06:** Unit tests with injected stream factory — no widget tree, no real pedometer plugin
- **Layering:** Monitor in `core/services/` — tests stay in `test/core/services/`
- **Single-writer ingestion:** Fault tests must **not** write buckets — read-only monitor state asserts only
- **22-1 dispose contract:** Fault-injection tests that create auxiliary monitors must `await dispose()` in test body or tearDown — do not regress dispose group
- **Do not assert log strings:** `livePipelineLog` is debug-only; assert behavioral outcomes only

### File structure requirements

| Action | Path |
|--------|------|
| **UPDATE** | `test/core/services/live_step_monitor_test.dart` — add `group('stream fault injection')` |
| **READ ONLY** | `lib/core/services/live_step_monitor.dart` |
| **READ ONLY** | `lib/core/services/lifecycle/lifecycle_live_pipeline_service.dart` (peek consumer) |
| **READ ONLY** | `test/core/services/live_step_monitor_day_rollover_test.dart` (regression) |
| **DO NOT** | Modify production monitor unless test exposes real bug |
| **DO NOT** | Duplicate coordinator resume tests from 26-2 |

### Testing requirements

**Default verify command:**

```bash
flutter test test/core/services/live_step_monitor_test.dart --exclude-tags slow
flutter test test/core/services/live_step_monitor_day_rollover_test.dart --exclude-tags slow
flutter test --exclude-tags slow
```

**AUD-55 verification grep:**

```bash
rg "stream fault injection|start stream onError|peekPhoneStepEvent.*(error|timeout|null)" test/core/services/live_step_monitor_test.dart
```

**Assertions checklist:**

- [ ] `start()` + stream error → `isRunning` true, no listener error, no zone failure
- [ ] `peekPhoneStepEvent` + stream error → returns `null`, no throw
- [ ] `peekPhoneStepEvent` + silent stream + short timeout → returns `null`
- [ ] Existing 23+ live monitor tests still green
- [ ] Full fast suite green (~960+ tests post 26-5)

### Previous story intelligence (26-5)

- Sub-task A→E + OK-commit gate — mirror for 26-6 (final Epic 26 story)
- AUD-54 pattern: named audit contract via grep-verifiable test/group names
- Tests-only default — production unchanged unless bug exposed
- Full fast suite was 960 passed after 26-5 — extend without breaking WM/FGS/collector/coordinator tests
- Story 26-5 used **new file** because zero prior harness; 26-6 **extends** rich existing `live_step_monitor_test.dart`

### Previous story intelligence (22-1)

- Dispose hardening established `_disposed` guards and ordered teardown
- Stream `onError` explicitly deferred to Story 26-6 — do not re-open dispose sequencing
- Peek dispose test (L561–582) validates `_activePeekCancels` — fault-injection peek tests must not leave orphan listeners

### Git intelligence

Recent commits (Story 26-5):

- `f325551` — close story 26-5 after code review
- `7b8faa5` / `f2869e7` / `32c48a5` / `ad76401` — sub-task commits for factory bootstrap tests

`live_step_monitor.dart` unchanged since 22-1 dispose hardening — safe to add tests only. This story **closes Epic 26** — after merge + retrospective, bump `pubspec.yaml` patch+1 build+1 per sprint-status-post-audit.yaml versioning notes.

### Latest tech information

- **Dart Stream `listen(onError:)`:** Default `cancelOnError: false` on `start()` subscription — after error, subscription is closed but callback already ran; test with `StreamController.addError` on broadcast stream
- **Dart 3 `Completer.future.timeout`:** Throws `TimeoutException` — caught explicitly in peek (not generic catch)
- **flutter_test `pumpEventQueue`:** Flushes microtask queue for async onError callbacks — prefer over arbitrary `Future.delayed`
- **No new packages** — pure Dart stream fault injection

### Project context reference

- OK-commit gate mandatory per sub-task — `docs/project-context.md`
- Default test command: `flutter test --exclude-tags slow`
- Version bump at **Epic 26 close** (this story completes the epic tranche) — current `0.11.2+27`
- Sprint tracker: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` (not legacy `sprint-status.yaml`)

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` § Story 26-6 · AUD-55]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-couverture-structurelle.md` § LiveStepMonitor table · § Gestion d'erreur jamais exercée]
- [Source: `_bmad-output/implementation-artifacts/stories/22-1-harden-live-step-monitor-dispose-sequencing.md` § deferred onError scope]
- [Source: `_bmad-output/implementation-artifacts/stories/26-5-cover-isolate-background-collector-factory-bootstrap.md` § story structure]
- [Source: `lib/core/services/live_step_monitor.dart`]
- [Source: `lib/core/services/lifecycle/lifecycle_live_pipeline_service.dart` § resume peek consumer]
- [Source: `test/core/services/live_step_monitor_test.dart`]
- [Source: `docs/project-context.md` § Test commands, OK-commit gate]

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- Gap analysis: 0 prior fault-injection hits in `live_step_monitor_test.dart`
- `start stream onError` test: `StackTrace.empty` required to avoid `debugPrintStack` assertion in kDebugMode test zone

### Completion Notes List

- Added `group('stream fault injection')` with 3 tests covering AUD-55: start onError (monitor stays running, listener unaffected), peek onError (null return), peek timeout (silent stream, 50ms)
- Tests-only — no production changes
- Full fast suite: 963 passed (~2 skipped slow-tagged)

### File List

- `test/core/services/live_step_monitor_test.dart` — added stream fault injection group (3 tests)
- `_bmad-output/implementation-artifacts/stories/26-6-add-fault-injection-tests-for-live-monitor-stream-errors.md` — story tracking
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` — status in-progress → review

## Change Log

- 2026-07-19: Story context created — AUD-55 LiveStepMonitor stream fault-injection guide (ready-for-dev).
- 2026-07-19: Implemented fault-injection tests (AUD-55) — 3 new tests, full fast suite green (963 passed).
