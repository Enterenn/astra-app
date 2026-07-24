# Story 30.4: Inject TimeProvider into Collection Timeout Source

Status: done

<!-- audits_2 Epic 30 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 30-4 · diagnostic-workmanager-maintenance-db.md #6 · AUD2-FR27 · AUD2-NFR7 -->
<!-- Prerequisite: 30-3 done · base 0.13.0+32 -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **developer**,
I want collection timeout boundaries to use the injected clock,
So that background collector timeout tests are deterministic.

## Acceptance Criteria

1. **Given** `_TimeoutBoundedSource` in `background_collector.dart`
   **When** enforcing `maxCollectionDuration`
   **Then** it uses injected `TimeProvider` (same as lock/notification paths), not raw `DateTime.now()` — AUD2-FR27, AUD2-NFR7

2. **Given** a unit test with a fake clock
   **When** the `maxCollectionDuration` deadline elapses
   **Then** timeout behaviour is asserted without real time delays (no `Future.delayed` / wall-clock wait for the deadline path)

**Covers:** AUD2-FR27 · AUD2-NFR7 · diagnostic-workmanager-maintenance-db.md #6 (P2)

**Depends on:** 30-3 done. **Last story in Epic 30** — after merge, bump patch+1 + README at epic close (not in this story unless Baptiste closes epic in same pass).

**Out of scope:** Changing `maxCollectionDuration` / `sourceTimeout` default values (25s / 2s); lock or maintenance behaviour (30-1); busy_timeout (30-2); iOS gap docs (30-3); replacing Dart `Stream.timeout` wall-clock semantics for per-event `sourceTimeout` (see Dev Notes — optional follow-up, not required for AC).

## Tasks / Subtasks

- [x] **Sub-task A — Wire `TimeProvider` into `_TimeoutBoundedSource`** (AC: #1)
  - [x] Read fully: `background_collector.dart` (L116-120, L217-248), `ingestion_collection_lock.dart` (clock fallback pattern L46-47, L78-79)
  - [x] Add optional `TimeProvider? clock` parameter to `_TimeoutBoundedSource`; remove `const` constructor if needed
  - [x] Pass `clock: clock` from `_collectOnce` when wrapping each source (reuse `BackgroundCollector.clock` — already injected in `AppDependencies` and `createIsolateBackgroundCollector`)
  - [x] Replace both `DateTime.now()` calls (deadline + `isAfter`) with UTC helper matching lock pattern: `(_clock?.nowUtc() ?? DateTime.now().toUtc())`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Deterministic `maxCollectionDuration` test** (AC: #2)
  - [x] Read: `test/core/services/background_collector_test.dart` (`@Tags(['slow'])`, existing `_FakeStepSource` / `_SlowStepSource` helpers L1073+)
  - [x] Add test: source yields reading A, advances `FakeTimeProvider` past `maxCollectionDuration`, then yields reading B — collector persists only buckets from A (deadline break before B)
  - [x] Pass `clock:` and explicit short `maxCollectionDuration` (e.g. `Duration(minutes: 30)`) on `BackgroundCollector`; use `sourceTimeout` long enough not to interfere (e.g. `Duration(seconds: 5)`)
  - [x] Run: `flutter test test/core/services/background_collector_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Diagnostic closure** (AC: #1)
  - [x] Update `planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md` #6 → `fixed` with story ref `30-4`
  - [x] Update `planning-artifacts/audits_2/README.md` §03 row #6 statut → `fixed (30-4)`; refresh P2 open count if tracked
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

`BackgroundCollector` already accepts `TimeProvider? clock` and passes it to:
- `IngestionCollectionLock.isHeld` / `IngestionCollectionLock(...)` (cross-isolate mutex)
- `maybeNotifyGoalReachedIfGoalMet` (local-day formatting)

But `_TimeoutBoundedSource` — the wrapper around each `DataIngestionSource` during normalize — still uses wall clock for the **overall collection window**:

```217:248:lib/core/services/background_collector.dart
class _TimeoutBoundedSource implements DataIngestionSource {
  // ...
  Stream<StepReading> watchStepReadings() async* {
    final deadline = DateTime.now().add(maxCollectionDuration);
    await for (final reading in _delegate.watchStepReadings().timeout(
      timeout,
      onTimeout: (sink) {
        sink.close();
      },
    )) {
      if (DateTime.now().isAfter(deadline)) {
        break;
      }
      yield reading;
    }
  }
}
```

**Gap:** Tests cannot advance a fake clock to assert `maxCollectionDuration` truncation without real delays. Violates D-25 / AUD2-NFR7 for this ingestion path.

[Source: `diagnostic-workmanager-maintenance-db.md` #6 · `epics-audits-2.md` AUD2-FR27]

### Recommended implementation

**Minimal diff — pass existing collector clock through:**

```dart
// _collectOnce L116-120
_TimeoutBoundedSource(
  source,
  timeout: sourceTimeout,
  maxCollectionDuration: maxCollectionDuration,
  clock: clock,
),

// _TimeoutBoundedSource
DateTime _nowUtc() => (_clock?.nowUtc() ?? DateTime.now().toUtc());

Stream<StepReading> watchStepReadings() async* {
  final deadline = _nowUtc().add(maxCollectionDuration);
  await for (final reading in _delegate.watchStepReadings().timeout(/* unchanged */)) {
    if (_nowUtc().isAfter(deadline)) {
      break;
    }
    yield reading;
  }
}
```

**Why UTC:** Matches `IngestionCollectionLock` and `TimeProvider.nowUtc()` contract. Duration math on UTC instants is correct for elapsed-time boundaries (not local-day semantics).

**Production unchanged:** `AppDependencies.create()` and `createIsolateBackgroundCollector` already set `clock: timeProvider` / `SystemTimeProvider()`. No factory or DI changes required.

**Fallback when `clock` is null:** Same as lock — `DateTime.now().toUtc()`. Existing tests without `clock:` keep current wall-clock behaviour.

### `sourceTimeout` vs `maxCollectionDuration` (do not conflate)

| Parameter | Purpose | Clock after this story |
|-----------|---------|------------------------|
| `maxCollectionDuration` (default 25s) | Cap total time reading from a source in one collect cycle | **Injected `TimeProvider`** (AC scope) |
| `sourceTimeout` (default 2s) | Per-event idle timeout on stream via Dart `Stream.timeout` | **Still wall-clock** — Dart API limitation |

AC and diagnostic #6 target lines 236/243 (`maxCollectionDuration` deadline). Do **not** refactor `Stream.timeout` unless Baptiste expands scope — existing tests (`_NeverEmittingStepSource` with 10ms `sourceTimeout`) rely on real async timing and remain valid.

### Deterministic test pattern (Sub-task B)

Use a test-only source that **advances the fake clock inside the stream** between yields (no `Future.delayed` for deadline assertion):

```dart
class _ClockAdvancingStepSource implements DataIngestionSource {
  _ClockAdvancingStepSource({required this.clock, required this.first, required this.second});
  final FakeTimeProvider clock;
  final StepReading first;
  final StepReading second;

  @override
  Stream<StepReading> watchStepReadings() async* {
    yield first;
    clock.setNowUtc(clock.nowUtc().add(const Duration(hours: 1))); // past maxCollectionDuration
    yield second;
  }
  // providerId / deviceId → kInternalPhoneProvider / kSmartphoneDeviceId
}
```

**Assert:** `collectOnce()` upserts 1 bucket (delta from `first` only); second reading ignored by deadline break.

Reuse existing `setUp` `FakeTimeProvider` anchor (`DateTime.utc(2026, 6, 2, 8)`).

### Preserve (do not break)

| Behaviour | Must remain |
|-----------|-------------|
| Default `maxCollectionDuration` 25s / `sourceTimeout` 2s | Unchanged |
| Per-source txn upsert + baseline (29-3) | Unchanged |
| `IngestionCollectionLock` acquire/release in `collectOnce` | Unchanged |
| `_collectInFlight` dedup | Unchanged |
| `Stream.timeout` on delegate for idle sources | Unchanged |
| WM / FGS / UI collector wiring via factory + `AppDependencies` | Unchanged |

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-25: injected clock in ingestion/lifecycle | Remove last `DateTime.now()` in `_TimeoutBoundedSource` deadline path |
| AUD2-NFR7: test determinism | Fake clock test for `maxCollectionDuration` without wall-clock wait |
| AUD2-NFR8: preserve strengths | Lock + txn patterns untouched |
| Token economy | Minimal diff — one production file + one test file + diagnostic closure |

[Source: `architecture.md` D-25 (L341-351, L701) · `epics-audits-2.md` AUD2-NFR7]

### File structure requirements

| File | Action |
|------|--------|
| `lib/core/services/background_collector.dart` | Pass `clock` to `_TimeoutBoundedSource`; replace `DateTime.now()` in deadline path |
| `test/core/services/background_collector_test.dart` | Add deterministic `maxCollectionDuration` test |
| `_bmad-output/planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md` | Close #6 |
| `_bmad-output/planning-artifacts/audits_2/README.md` | Sync §03 row #6 |

**Do not touch:** `background_collector_factory.dart` (already passes clock), `ingestion_collection_lock.dart`, `workmanager_callback.dart`, version bump (epic close), `Stream.timeout` implementation.

### Testing requirements

| Verify | Command / expectation |
|--------|----------------------|
| New + regression collector tests | `flutter test test/core/services/background_collector_test.dart` |
| Critical gate (if no other slow files touched) | `flutter test --exclude-tags slow` should still pass |
| Full collector file | File is `@Tags(['slow'])` — run targeted file above, not bare `flutter test` |

**New test scenario (minimum):** fake clock advanced past `maxCollectionDuration` → second reading dropped, single bucket persisted.

Do **not** run bare `flutter test` unless Baptiste asks.

### Previous story intelligence (30-3)

| Learning | Impact on 30-4 |
|----------|----------------|
| Diagnostic closure: update diagnostic `#N` + README row | Replicate for #6 |
| OK commit gate per sub-task (A → B → C) | Same workflow |
| Tracker = `sprint-status-audits-2.yaml` | Update on story create |
| Epic 30 doc/code mix: 30-3 was docs-only; 30-4 is code + test | Run collector tests in Sub-task B |
| iOS gap documented — WM only Android | `maxCollectionDuration` applies to all platforms' collect path equally |

[Source: `stories/30-3-document-ios-background-collection-gap.md`]

### Cross-story context (Epic 30)

| Story | Status | Relationship |
|-------|--------|--------------|
| 30-1 | done | Collection/maintenance locks — `_TimeoutBoundedSource` runs inside lock scope |
| 30-2 | done | busy_timeout — orthogonal; same DB connections |
| 30-3 | done | iOS WM gap docs — unrelated to clock injection |
| **30-4** | **this story** | Closes AUD2-FR27; **last Epic 30 story** |

**Epic 30 close (after 30-4 done):** bump `pubspec.yaml` patch+1 + `README.md` status row; mark `epic-30: done` in `sprint-status-audits-2.yaml`.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `d56e9b3` | 30-3 done — Epic 30 last doc story |
| `035832d` | 30-2 done — diagnostic closure pattern |
| `2538f68` | 30-1 maintenance lock — clock already on lock |

Active branch `main`; `base_version: 0.13.0+32` per sprint tracker.

### Latest tech / library notes

- **Dart `Stream.timeout`** — uses system timer; not replaceable with `FakeTimeProvider` without custom stream wrapper. Out of scope for AC.
- **`FakeTimeProvider.setNowUtc`** — established test API (`test/core/time/fake_time_provider.dart`).
- **No new packages.**

### Project context reference

- OK commit gate: sub-tasks A→C, separate commits after Baptiste approval
- Tests: `background_collector_test.dart` is slow-tagged — run that file explicitly
- Version bump: Epic 30 close after 30-4 (patch+1)
- Communication: French in chat; story in English

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc` · `.cursor/rules/app-versioning.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 30-4, AUD2-FR27, AUD2-NFR7]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md` #6]
- [Source: `_bmad-output/planning-artifacts/audits_2/README.md` §03 row #6]
- [Source: `_bmad-output/planning-artifacts/architecture.md` D-25]
- [Source: `lib/core/services/background_collector.dart`]
- [Source: `lib/core/services/background_collector_factory.dart`]
- [Source: `lib/core/services/ingestion_collection_lock.dart`]
- [Source: `test/core/time/fake_time_provider.dart`]
- [Source: `test/core/services/background_collector_test.dart`]
- [Source: `stories/30-3-document-ios-background-collection-gap.md`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Sub-task A: `_TimeoutBoundedSource` accepts optional `TimeProvider? clock`; `_nowUtc()` mirrors lock fallback pattern.
- Sub-task B: `_ClockAdvancingStepSource` advances fake clock between yields; test asserts 1 bucket (15 steps) and baseline 25, second reading dropped.
- Sub-task C: diagnostic #6 + README §03 row closed as `fixed (30-4)`.

### Completion Notes List

- AC #1: `DateTime.now()` removed from `maxCollectionDuration` deadline path; `clock` propagated from `BackgroundCollector`.
- AC #2: deterministic test without wall-clock wait for deadline (`stops reading after maxCollectionDuration using injected clock`).
- `flutter test test/core/services/background_collector_test.dart` — 28/28 passed.

### File List

- `lib/core/services/background_collector.dart`
- `test/core/services/background_collector_test.dart`
- `_bmad-output/planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md`
- `_bmad-output/planning-artifacts/audits_2/README.md`
- `_bmad-output/implementation-artifacts/sprint-status-audits-2.yaml`
- `_bmad-output/implementation-artifacts/stories/30-4-inject-timeprovider-into-collection-timeout-source.md`

### Change Log

- 2026-07-24: Story 30-4 implemented — TimeProvider in `_TimeoutBoundedSource`, deterministic test, diagnostic #6 closed.
