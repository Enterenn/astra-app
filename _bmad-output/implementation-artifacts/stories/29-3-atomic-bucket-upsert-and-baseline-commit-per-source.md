# Story 29.3: Atomic Bucket Upsert and Baseline Commit Per Source

Status: done

<!-- audits_2 Epic 29 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 29-3 · diagnostic-workmanager-maintenance-db.md #1 · AUD2-FR3, AUD2-FR34, AUD2-NFR8 -->
<!-- Prerequisite: Stories 29-1 and 29-2 done · base 0.12.1+31 -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want background step collection to commit buckets and baseline together,
So that a mid-cycle failure cannot double-count steps on the next sync.

## Acceptance Criteria

1. **Given** `BackgroundCollector._collectOnce` processing one source with multiple bucket upserts
   **When** upserts and `setBaseline` run
   **Then** they execute inside a single database transaction per source — AUD2-FR3
   **And** partial upsert without baseline commit cannot survive a crash/exception within that source cycle

2. **Given** an exception after some upserts in the **prior** implementation
   **When** the next collection cycle runs
   **Then** the same deltas are not additively merged a second time (regression test or fault-injection test) — AUD2-FR34

3. **Given** `ON CONFLICT DO UPDATE value += excluded.value` additive semantics
   **When** this story ships
   **Then** additive upsert behaviour is preserved — AUD2-NFR8

**Covers:** AUD2-FR3 · AUD2-FR34 · AUD2-NFR1 · AUD2-NFR8 · diagnostic-workmanager-maintenance-db.md #1 (P0-07)

**Depends on:** Stories 29-1 and 29-2 done (correct normalizer baseline + drain forwards resets). Epic 29 ships **29-1 → 29-5** in order — do not merge 29-4/29-5 into this PR.

**Out of scope:** Compaction insert-before-delete (29-4), drain/calculator unification (29-5), `TimeProvider` in `_TimeoutBoundedSource` (30-4), maintenance VACUUM lock (30-1), version bump (Epic 29 close → `0.13.0+32` per epics-audits-2).

## Tasks / Subtasks

- [x] **Sub-task A — Transaction-scoped repository writes** (AC: #1, #3)
  - [x] Read fully: `step_ingestion_repository.dart` (`upsertIngestionBucket`), `ingestion_baseline_repository.dart` (`setBaseline`), `step_aggregation_repository.dart` (`downsampleStepSamples` txn pattern — D-24)
  - [x] Add optional `{Transaction? txn}` to `upsertIngestionBucket` — use `txn ?? db` for `rawInsert`; preserve additive SQL unchanged
  - [x] Add optional `{Transaction? txn}` to `setBaseline` — use `txn.insert(...)` when txn provided; keep `withRetry` wrapper when txn is null
  - [x] **Do not** add a new public ingestion entry point beyond txn overloads — BackgroundCollector remains sole production caller of upsert
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Atomic per-source persist in collector** (AC: #1)
  - [x] Read fully: `lib/core/services/background_collector.dart` (`_collectOnce` L100–135)
  - [x] Replace sequential `await upsert` loop + `await setBaseline` with one `databaseSession.withRetry` → `db.transaction((txn) async { … })` **per source**
  - [x] Normalization (`getBaseline`, `normalizer.normalize`) stays **outside** the txn — only persist writes are transactional
  - [x] On txn failure: exception propagates to existing per-source `catch` — no partial buckets/baseline for that source
  - [x] Preserve: `upsertedCount` increment, `_onIngestionComplete`, goal notification path, multi-source loop, per-source error isolation
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Fault-injection / atomicity regression test** (AC: #2)
  - [x] Add test in `test/core/services/background_collector_test.dart`:
    - Scenario: readings produce ≥2 buckets; inject failure on `setBaseline` (or on 2nd upsert via test double)
    - After failed cycle: assert **no** net bucket rows **or** baseline unchanged (full rollback)
    - Run `collectOnce` again with identical readings: assert today steps equal **single** application of deltas (not doubled)
  - [x] Keep existing `@Tags(['slow'])` tests passing
  - [x] Run `flutter test test/core/services/background_collector_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Diagnostic closure** (AC: #1)
  - [x] Update `planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md` #1 status → `fixed` with story ref
  - [x] Update `planning-artifacts/audits_2/README.md` rows for diagnostic 03 / P0-07 / T2
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Root cause (read before editing)

**Bug:** `_collectOnce` upserts each bucket sequentially, then calls `setBaseline` in separate autocommit operations. Upsert is **additive** on bucket identity conflict:

```62:63:lib/data/repositories/step/step_ingestion_repository.dart
      ON CONFLICT(provider, device_id, type, start_time, end_time, resolution)
      DO UPDATE SET value = timeseries_samples.value + excluded.value
```

Baseline lives in `user_preferences` via `IngestionBaselineRepository.setBaseline` — a separate write with no shared txn today.

**Failure scenario:**

1. Cycle N: buckets B1..Bk upserted successfully; exception before `setBaseline` (or between upserts)
2. Cycle N+1: same readings re-normalized against **old** baseline → same bucket keys → values **added again**

[Source: `diagnostic-workmanager-maintenance-db.md` #1 · `epics-audits-2.md` AUD2-FR3]

### Current broken implementation (MUST wrap persist in txn)

```116:128:lib/core/services/background_collector.dart
        for (final bucket in result.buckets) {
          await repository.upsertIngestionBucket(bucket);
          upsertedCount += 1;
        }

        final terminalBaseline = result.terminalBaseline;
        if (terminalBaseline != null) {
          await baselineRepository.setBaseline(
            provider: source.providerId,
            deviceId: source.deviceId,
            cumulative: terminalBaseline,
          );
        }
```

Each `await` is its own committed write. Partial state survives per-source `catch` at L129–134.

### Required implementation shape

**Pattern to follow:** D-24 transactional batching — same as `StepAggregationRepository.downsampleStepSamples({Transaction? txn})` and `StepIngestionRepository.purge` (txn + `IngestionBaselineRepository.clearAllBaselines(txn)`).

**Per source, after normalization succeeds:**

```dart
await repository.databaseSession.withRetry((db) async {
  await db.transaction((txn) async {
    for (final bucket in result.buckets) {
      await repository.upsertIngestionBucket(bucket, txn: txn);
      upsertedCount += 1;
    }
    final terminalBaseline = result.terminalBaseline;
    if (terminalBaseline != null) {
      await baselineRepository.setBaseline(
        provider: source.providerId,
        deviceId: source.deviceId,
        cumulative: terminalBaseline,
        txn: txn,
      );
    }
  });
});
```

**Critical constraints:**

| Rule | Rationale |
|------|-----------|
| Txn scope = one source's persist writes only | Multi-source partial success remains valid — source A can commit while source B fails |
| Normalization stays outside txn | Long-running stream read must not hold SQLite write lock |
| Same `Database` connection | Both repos in production share `AstraDatabaseSession` from `AppDependencies` — txn participates across `timeseries_samples` + `user_preferences` |
| Preserve additive upsert SQL | AUD2-NFR8 — do not switch to replace semantics |
| Do not txn-wrap goal notification / callback | Those run after all sources; unchanged |

**Shared session in production:**

```123:130:lib/core/di/app_dependencies.dart
    final stepIngestion = StepIngestionRepository(databaseSession);
    ...
    final baselineRepository = IngestionBaselineRepository(databaseSession);
```

Both repos accept the same `AstraDatabaseSession` — `repository.databaseSession.withRetry` is the correct txn entry point.

### Repository txn overload sketch

**`upsertIngestionBucket`:** extract inner `rawInsert` to accept `DatabaseExecutor exec` (`Database` or `Transaction`):

```dart
Future<void> upsertIngestionBucket(NormalizedStepBucket bucket, {Transaction? txn}) async {
  // ... build model/row unchanged ...
  await _session.run((db) => _upsertBucketExec(txn ?? db, row));
}

Future<void> _upsertBucketExec(DatabaseExecutor exec, Map<String, Object?> row) =>
  exec.rawInsert('''INSERT ... ON CONFLICT ... DO UPDATE SET value = ...''', [...]);
```

When `txn != null`, caller owns the outer transaction — **do not** nest `db.transaction` inside `_session.run`. Preferred: if `txn != null`, call `_upsertBucketExec(txn, row)` directly without `withRetry`; if `txn == null`, keep existing `_session.run` path.

**`setBaseline`:** mirror `clearAllBaselines(Transaction txn)` pattern at L29–36:

```dart
Future<void> setBaseline({..., Transaction? txn}) async {
  if (cumulative < 0) throw ArgumentError...;
  final row = {'key': preferenceKey(...), 'value': cumulative.toString()};
  if (txn != null) {
    await txn.insert('user_preferences', row, conflictAlgorithm: ConflictAlgorithm.replace);
    return;
  }
  return _session.withRetry((db) => db.insert(...));
}
```

### Fault-injection test guidance (AC #2)

**Goal:** Prove that without atomic txn, retry would double-count; with txn, retry is idempotent.

**Suggested approach — failing baseline repository test double:**

```dart
class _FailingOnSetBaselineRepository extends IngestionBaselineRepository {
  _FailingOnSetBaselineRepository(super.db, {this.failOnce = true});
  bool failOnce;
  @override
  Future<void> setBaseline({...}) async {
    if (failOnce) {
      failOnce = false;
      throw StateError('simulated baseline persist failure');
    }
    return super.setBaseline(...);
  }
}
```

**Test flow:**

1. `_FakeStepSource` with readings 10 → 15 → 30 (produces 2 buckets, same as existing happy-path test)
2. First `collectOnce` with failing baseline repo → expect exception caught, **0 bucket rows** (txn rolled back)
3. Second `collectOnce` with normal baseline repo → expect 2 buckets, values 5 and 15, baseline 30
4. Third `collectOnce` with **same readings** again → expect counts **unchanged** (not 10 and 30 from double-add)

Alternative: inject throw on 2nd `upsertIngestionBucket` via `@visibleForTesting` wrapper on repository.

**Assertion targets:**

- `SUM(value)` for today's buckets after step 3 equals step 2 (not 2×)
- `getBaseline()` matches `terminalBaseline` from normalizer only after successful cycle

### Preserve existing behaviour

| Case | Expected after this story |
|------|---------------------------|
| Happy path multi-bucket collect | Unchanged totals — same buckets, same baseline |
| Source throws before normalize completes | No writes — unchanged |
| Source throws during txn | Full rollback for that source |
| Second source after first source failed | Second source still processes — per-source catch preserved |
| `collectOnce` lock held | Still no-ops — unchanged |
| `upsertedCount == 0` | No callback — unchanged |
| Empty buckets, baseline only | Txn commits baseline only (if normalizer returns terminalBaseline with empty buckets) |

Existing tests in `background_collector_test.dart` (20+ cases) **must all pass** — txn wrapping is transparent on happy path.

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-20: single ingestion writer | Only `BackgroundCollector` calls `upsertIngestionBucket` — txn overload is internal |
| D-24: admin/persist txn batching | Follow `downsampleStepSamples({Transaction? txn})` and `purge` patterns |
| Additive upsert invariant | SQL unchanged — AUD2-NFR8 |
| WAL + isolate model | Txn is per-connection; `IngestionCollectionLock` still serializes collection across isolates |
| Live vs persist separation | No changes to `LiveStepMonitor` — 29-2 drain fix is prerequisite, not in scope |

**Persist chain after 29-3:**

```
BackgroundCollector._collectOnce (per source)
  → normalize (outside txn)
  → db.transaction:
       → upsertIngestionBucket × N  (additive)
       → setBaseline (terminalBaseline)
  → next source / goal notification
```

[Source: `architecture.md` §Ingestion write path · `diagnostic-workmanager-maintenance-db.md`]

### File structure requirements

| File | Action |
|------|--------|
| `lib/data/repositories/step/step_ingestion_repository.dart` | Add `{Transaction? txn}` overload / exec helper |
| `lib/data/repositories/ingestion_baseline_repository.dart` | Add `{Transaction? txn}` to `setBaseline` |
| `lib/core/services/background_collector.dart` | Wrap per-source persist in txn |
| `test/core/services/background_collector_test.dart` | Fault-injection atomicity regression test |
| `planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md` | Close #1 |
| `planning-artifacts/audits_2/README.md` | Sync diagnostic 03 / P0-07 / T2 |

**Do not touch:** `sample_compaction_runner.dart` (29-4), `live_step_monitor.dart` drain (29-2 done), `step_normalizer.dart` (29-1 done), `_TimeoutBoundedSource` clock (30-4).

### Testing requirements

| Command | When |
|---------|------|
| `flutter test test/core/services/background_collector_test.dart` | After Sub-tasks B + C (file is `@Tags(['slow'])`) |
| `flutter test --exclude-tags slow` | Quick regression if only repository txn overload changed in A |

**Do not** run bare `flutter test` unless Baptiste asks.

**Test naming suggestions:**

- `rolls back bucket upserts when baseline persist fails within source txn`
- `second collect after simulated mid-cycle failure does not double-count additive buckets`

### Previous story intelligence

| Learning | Impact on 29-3 |
|----------|----------------|
| 29-1 (`c90fb5e`): `terminalBaseline` = accepted baseline | Baseline commit in txn must persist normalizer output — already correct value |
| 29-2 (`7a5949e`): reset-aware drain gate | Readings reach normalizer; atomic persist prevents double-add on retry after partial failure |
| OK commit gate | One commit per sub-task A/B/C/D after Baptiste approval |
| Epic 29 atomic bundle | Ship 29-3 before 29-4/29-5; no compaction or drain unification in this PR |
| `idle_flush_persist_test.dart` | Uses `collectOnce` end-to-end — should pass unchanged after txn wrap |

[Source: `stories/29-2-forward-hardware-reset-readings-through-live-drain.md` · `stories/29-1-fix-terminal-baseline-after-rejected-sensor-noise.md`]

### Cross-story context (Epic 29)

| Story | Relationship |
|-------|--------------|
| 29-1 | Done — correct terminalBaseline after noise |
| 29-2 | Done — drain forwards hardware resets |
| **29-3** | **This story** — atomic txn buckets + baseline per source |
| 29-4 | Compaction delete guard — separate concern (insert-before-delete) |
| 29-5 | Unify drain gate + calculator — do not refactor drain here |

**Diagnostic cross-link:** P0-07 (this story) and P0-09 (29-4) are distinct failure modes — both cause data integrity issues but different code paths.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `39a72e1` | Story 29-2 done — drain + integration tests |
| `7a5949e` | Reset-aware drain gate implementation |
| `c90fb5e` | Story 29-1 done — normalizer baseline fix |
| `453fd04` | audits_2 epics E29–E33 definition |

### Latest tech / library notes

- **sqflite:** `Database.transaction` provides ACID across `timeseries_samples` and `user_preferences` on the same connection. Use `Transaction` (implements `DatabaseExecutor`) for inserts — no API changes needed beyond executor typing.
- **No new dependencies.**
- **Nested transactions:** sqflite does not support nested `db.transaction` — when `txn != null`, repository methods must **not** open inner transactions (same pattern as `downsampleStepSamples` when `txn` passed).
- **Flutter 3.x / Dart 3.x:** Use `DatabaseExecutor` type for shared upsert helper.

### Project context reference

- OK commit gate: sub-tasks A/B/C/D each get separate commit after Baptiste approval
- Tests: targeted file above; `@Tags(['slow'])` on background_collector_test
- Version bump: defer to Epic 29 close (`0.13.0+32`)
- Communication: French in chat; story in English

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 29-3]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md` #1]
- [Source: `_bmad-output/planning-artifacts/audits_2/README.md` §P0-07, diagnostic 03]
- [Source: `_bmad-output/planning-artifacts/architecture.md` §Ingestion write path, D-24]
- [Source: `lib/data/repositories/step/step_aggregation_repository.dart` `downsampleStepSamples`]
- [Source: `stories/29-2-forward-hardware-reset-readings-through-live-drain.md`]
- [Source: `stories/29-1-fix-terminal-baseline-after-rejected-sensor-noise.md`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- `upsertedCount` incremented after successful txn (not inside loop) so failed txn does not inflate count or trigger callback.

### Completion Notes List

- Sub-task A: `{Transaction? txn}` on `upsertIngestionBucket` / `setBaseline`; `_upsertBucketExec(DatabaseExecutor)` helper; additive SQL unchanged.
- Sub-task B: per-source `databaseSession.withRetry` → `db.transaction` wrapping all bucket upserts + baseline commit; normalization stays outside txn.
- Sub-task C: 2 regression tests (rollback on baseline failure; recovery without double-count); 26/26 `background_collector_test.dart` green.
- Sub-task D: diagnostic 03 #1 → `fixed` (29-3); README P0-07 / cross-links / test gap updated.

### File List

- `lib/data/repositories/step/step_ingestion_repository.dart`
- `lib/data/repositories/ingestion_baseline_repository.dart`
- `lib/core/services/background_collector.dart`
- `test/core/services/background_collector_test.dart`
- `_bmad-output/planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md`
- `_bmad-output/planning-artifacts/audits_2/README.md`

### Change Log

- 2026-07-24: Atomic per-source txn for bucket upserts + baseline commit (Story 29-3); fault-injection tests; diagnostic 03 P0-07 closed.
