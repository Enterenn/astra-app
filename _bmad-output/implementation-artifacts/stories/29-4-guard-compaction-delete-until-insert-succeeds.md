# Story 29.4: Guard Compaction Delete Until Insert Succeeds

Status: done

<!-- audits_2 Epic 29 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 29-4 · diagnostic-downsampling-compaction-fr11.md #1 · AUD2-FR4, AUD2-FR28, AUD2-FR34, AUD2-NFR5, AUD2-NFR6 -->
<!-- Prerequisite: Stories 29-1, 29-2, 29-3 done · base 0.12.1+31 -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want downsampling to never delete fine-grained step data unless the aggregated bucket was actually written,
So that re-compaction cannot silently lose my history.

## Acceptance Criteria

1. **Given** `SampleCompactionRunner` tier passes (5min→hourly, hourly→daily, catch-up)
   **When** `insertCompactedSample` uses `ConflictAlgorithm.ignore` and PK already exists
   **Then** source buckets are **not** deleted unless insert succeeded or aggregate value is verified current — AUD2-FR4, AUD2-NFR5

2. **Given** a re-run on modified source data with a stale existing aggregate PK
   **When** compaction executes
   **Then** fine-grained sources are preserved (no silent loss) — regression test — AUD2-FR34

3. **Given** a successful insert
   **When** compaction completes
   **Then** `hourlyCreated` / `dailyCreated` increment only on confirmed insert — AUD2-FR28

4. **Given** insert conflict with divergent aggregate value
   **When** detected
   **Then** anomaly is logged — AUD2-NFR6

**Covers:** AUD2-FR4 · AUD2-FR28 · AUD2-FR34 · AUD2-NFR5 · AUD2-NFR6 · diagnostic-downsampling-compaction-fr11.md #1 (P0-09)

**Depends on:** Stories 29-1, 29-2, 29-3 done. Epic 29 ships **29-1 → 29-5** in order — do not merge 29-5 (drain/calculator unification) into this PR.

**Out of scope:** Drain/calculator unification (29-5), maintenance VACUUM lock (30-1), `downsampleStepSamples(txn:)` caller audit (diagnostic #2 — document only if touched), version bump (Epic 29 close → `0.13.0+32`).

## Tasks / Subtasks

- [x] **Sub-task A — Insert outcome contract on CompactionWriter** (AC: #1, #3, #4)
  - [x] Read fully: `sample_compaction_runner.dart` (`CompactionWriter`, `TransactionCompactionWriter`, all three tier loops L145–254)
  - [x] Change `insertCompactedSample` return type from `Future<void>` to a small result type, e.g. `CompactionInsertOutcome { inserted, alreadyCurrent, conflictDivergent }`
  - [x] In `TransactionCompactionWriter.insertCompactedSample`:
    - sqflite `insert` with `ConflictAlgorithm.ignore` returns **row id > 0** on insert, **0** on conflict
    - On conflict: `SELECT value FROM timeseries_samples WHERE id = ?` — compare to merged sample value
    - `inserted` → new row written
    - `alreadyCurrent` → PK exists, stored value == merged value (safe idempotent path — may delete sources, **do not** increment created counters)
    - `conflictDivergent` → PK exists, stored value != merged value — log anomaly, **no delete**
  - [x] Add compaction log helper (reuse `livePipelineLog` pattern from 29-2 or a dedicated `compactionLog` in same debug module — keep kDebugMode-gated)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Guard delete + counter increments in runner** (AC: #1, #3)
  - [x] Extract shared helper, e.g. `_compactGroup({ required insert outcome handler })` or inline guard in each tier loop — **all three sites** must match:
    - L145–151 (`compactTierTwoFiveMinuteToHourly`)
    - L195–201 (`compactTierThreeHourlyToDaily`)
    - L248–254 (`compactTierThreeFiveMinuteCatchUpToDaily`)
  - [x] Delete sources **only** when outcome is `inserted` or `alreadyCurrent`
  - [x] Increment `hourlyCreated` / `dailyCreated` **only** when outcome is `inserted`
  - [x] Preserve: grouping, completeness guards, merge functions, `CompactionResult` shape, txn ownership in `downsampleStepSamples`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Regression tests** (AC: #2, #3)
  - [x] Add tests in `test/data/repositories/step_repository_downsample_test.dart`:
    1. **Stale aggregate + modified sources:** inject/seed complete hour of 5min buckets → first downsample → manually change 5min `value` (or re-upsert one bucket) → second downsample → assert 5min rows **still present**, hourly value **unchanged**, `hourlyCreated == 0`
    2. **Happy path unchanged:** existing tests (`compacts injected 90d…`, `preserves total step value sum`, `second downsample pass is idempotent`) must pass without modification of expectations
    3. **Counter accuracy:** on first pass `hourlyCreated` matches inserts; on ignored-only second pass `hourlyCreated == 0` (already covered — verify still green)
  - [x] Run `flutter test test/data/repositories/step_repository_downsample_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Diagnostic closure** (AC: #1)
  - [x] Update `planning-artifacts/audits_2/diagnostic-downsampling-compaction-fr11.md` #1 → `fixed` with story ref; #3 → `fixed` (counter fix bundled)
  - [x] Update `planning-artifacts/audits_2/README.md` P0-09 row + diagnostic 04 status
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Root cause (read before editing)

**Bug:** Each compaction merge calls `insertCompactedSample` with `ConflictAlgorithm.ignore`, then **unconditionally** deletes source buckets and increments created counters — regardless of whether the insert actually wrote a row.

```51:56:lib/core/lifecycle/sample_compaction_runner.dart
  Future<void> insertCompactedSample(TimeseriesSampleModel sample) {
    return _txn.insert(
      'timeseries_samples',
      sample.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
```

```145:151:lib/core/lifecycle/sample_compaction_runner.dart
        await writer.insertCompactedSample(hourlySample);
        hourlyCreated++;

        for (final bucket in hourBuckets) {
          await writer.deleteStepSample(bucket.id);
          fiveMinDeleted++;
        }
```

Same pattern at L195–201 (hourly→daily) and L248–254 (5min catch-up→daily).

**Failure scenario:**

1. First compaction: hourly aggregate inserted from 12 five-minute buckets; sources deleted — OK
2. Later: fine buckets reappear (re-ingestion, dev inject, or partial rollback) **or** source values change while stale hourly PK remains
3. Re-compaction: merge recalculates new total; `insert` **ignored** (PK exists, old value retained); sources **deleted anyway** → **silent data loss**

**Txn atomicity does not fix this:** `downsampleStepSamples` wraps `runAllTiers` in one transaction — the txn commits successfully while content is wrong (fine data gone, stale aggregate kept).

[Source: `diagnostic-downsampling-compaction-fr11.md` #1 · `epics-audits-2.md` AUD2-FR4]

### Required implementation shape

**Decision tree per merge group:**

| Insert outcome | Delete sources? | Increment `*Created`? | Log |
|----------------|-----------------|----------------------|-----|
| `inserted` (row id > 0) | Yes | Yes | optional debug |
| `alreadyCurrent` (PK exists, value matches) | Yes | No | optional debug |
| `conflictDivergent` (PK exists, value differs) | **No** | No | **Yes** — AUD2-NFR6 |

**Value comparison:** use merged sample's `value` field vs existing row `value` (both `int`). PK for compaction aggregates is `SampleIdGenerator.deterministicFromMergedBucket(startTimeUtc, resolution)` — stable across re-runs for same bucket window.

**Do not switch to `ON CONFLICT DO UPDATE` blindly:** additive upsert on aggregates could double-count if misapplied. This story is **insert-or-verify**, not replace semantics.

**Suggested writer implementation sketch:**

```dart
enum CompactionInsertOutcome { inserted, alreadyCurrent, conflictDivergent }

Future<CompactionInsertOutcome> insertCompactedSample(TimeseriesSampleModel sample) async {
  final rowId = await _txn.insert(
    'timeseries_samples',
    sample.toMap(),
    conflictAlgorithm: ConflictAlgorithm.ignore,
  );
  if (rowId != 0) return CompactionInsertOutcome.inserted;

  final existing = await _txn.query(
    'timeseries_samples',
    columns: ['value'],
    where: 'id = ?',
    whereArgs: [sample.id],
    limit: 1,
  );
  if (existing.isEmpty) return CompactionInsertOutcome.inserted; // defensive

  final stored = (existing.single['value']! as num).toInt();
  if (stored == sample.value) return CompactionInsertOutcome.alreadyCurrent;

  compactionLog('compaction', 'insert conflict divergent', details: {
    'id': sample.id,
    'stored': stored,
    'merged': sample.value,
    'resolution': sample.resolution,
  });
  return CompactionInsertOutcome.conflictDivergent;
}
```

**Runner guard sketch (apply identically in all 3 tier loops):**

```dart
final outcome = await writer.insertCompactedSample(hourlySample);
switch (outcome) {
  case CompactionInsertOutcome.inserted:
    hourlyCreated++;
    await _deleteSources(writer, hourBuckets, onDeleted: () => fiveMinDeleted++);
  case CompactionInsertOutcome.alreadyCurrent:
    await _deleteSources(writer, hourBuckets, onDeleted: () => fiveMinDeleted++);
  case CompactionInsertOutcome.conflictDivergent:
    break; // preserve fine buckets
}
```

### Preserve existing behaviour

| Case | Expected after this story |
|------|---------------------------|
| First downsample on stable 90d inject | Unchanged — `hourlyCreated: 1440`, sum preserved |
| Second downsample (no new/changed data) | Idempotent — `hourlyCreated: 0`, row count unchanged |
| External txn batch (`downsampleStepSamples(txn:)`) | Still works — writer uses same txn |
| Incomplete hour/day groups | Still skipped — completeness guards unchanged |
| `CompactionResult` consumers (`DataLifecycleService`) | Same fields — counters more accurate |
| Ingestion additive upsert (29-3) | Untouched — separate code path |

Existing `step_repository_downsample_test.dart` (4 tests, `@Tags(['slow'])`) **must all pass** — add new tests, do not weaken existing assertions.

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-24: admin txn batching | `downsampleStepSamples` still owns txn when `txn == null`; writer stays txn-scoped |
| FR11 completeness guards | Do not relax `isComplete*` / `contiguous*Groups` — diagnostic #5 DST doc is Epic 33 |
| `finestResolutionTotal` read path | Unchanged — compaction fix is write-path only |
| `CompactionWriter` abstraction | Interface change is internal to lifecycle package + tests |
| AUD2-NFR8 | Do not alter ingestion upsert or live monitor paths |

**Compaction chain (unchanged structure):**

```
downsampleStepSamples()
  └─ db.transaction
       └─ SampleCompactionRunner.runAllTiers
            ├─ compactTierTwoFiveMinuteToHourly
            ├─ compactTierThreeHourlyToDaily
            └─ compactTierThreeFiveMinuteCatchUpToDaily
                 each merge: insertCompactedSample → [guard] → delete sources
```

[Source: `diagnostic-downsampling-compaction-fr11.md` §Flux compaction · `architecture.md` D-24]

### File structure requirements

| File | Action |
|------|--------|
| `lib/core/lifecycle/sample_compaction_runner.dart` | `CompactionInsertOutcome`, writer return type, runner guards, logging |
| `lib/core/debug/live_pipeline_log.dart` (or new `compaction_log.dart`) | Optional — anomaly log helper |
| `test/data/repositories/step_repository_downsample_test.dart` | Stale-aggregate regression test(s) |
| `planning-artifacts/audits_2/diagnostic-downsampling-compaction-fr11.md` | Close #1, #3 |
| `planning-artifacts/audits_2/README.md` | Sync P0-09 / diagnostic 04 |

**Do not touch:** `background_collector.dart` (29-3 done), `live_step_monitor.dart` (29-5 scope), `lifecycle_compaction.dart` merge math (unless test helper needs exported keys), `step_ingestion_repository.dart`.

### Testing requirements

| Command | When |
|---------|------|
| `flutter test test/data/repositories/step_repository_downsample_test.dart` | After Sub-tasks B + C |
| `flutter test test/dev/lifecycle_simulator_test.dart` | Optional sanity — compaction on 90d dataset |

**Do not** run bare `flutter test` unless Baptiste asks.

**Regression test scenario (AC #2) — suggested steps:**

1. `inject90Days` or manual insert: 12 contiguous 5min buckets forming one complete hour in tier-2 age window
2. `downsampleStepSamples()` → hourly row exists, 5min sources for that hour deleted
3. Re-insert **one** 5min bucket for same hour with **different** `value` (simulates modified source data while stale hourly remains)
4. `downsampleStepSamples()` again
5. Assert: re-inserted 5min row **still exists**; hourly `value` **unchanged**; `hourlyCreated == 0`

Alternative: seed hourly aggregate directly with stale value + fine 5min sources, run tier-2 only via test-visible runner (if needed, `@visibleForTesting` on tier method — prefer full `downsampleStepSamples` path).

**Test naming suggestions:**

- `preserves fine buckets when aggregate PK exists with divergent value`
- `increments hourlyCreated only on confirmed insert`

### Previous story intelligence

| Learning | Impact on 29-4 |
|----------|----------------|
| 29-3 (`752e1cb`): per-source txn for buckets + baseline | Separate failure mode from compaction — P0-07 fixed, P0-09 is this story |
| 29-3 pattern: txn overload via `DatabaseExecutor` | Compaction already uses `TransactionCompactionWriter` — extend, don't add parallel writer |
| 29-2: `livePipelineLog` for drop reasons | Mirror for compaction anomalies — AUD2-NFR6 |
| OK commit gate | One commit per sub-task A/B/C/D after Baptiste approval |
| Epic 29 atomic bundle | Ship 29-4 before 29-5; no drain/calculator refactor here |

[Source: `stories/29-3-atomic-bucket-upsert-and-baseline-commit-per-source.md`]

### Cross-story context (Epic 29)

| Story | Relationship |
|-------|--------------|
| 29-1 | Done — terminalBaseline after noise |
| 29-2 | Done — drain forwards hardware resets |
| 29-3 | Done — atomic txn buckets + baseline |
| **29-4** | **This story** — compaction insert-before-delete guard |
| 29-5 | Unify drain gate + calculator — separate PR |

**Diagnostic cross-link:** P0-07 (29-3 double upsert) and P0-09 (this story) both cause integrity issues but different code paths — both must be fixed for Epic 29 close.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `752e1cb` | Story 29-3 done — diagnostic P0-07 closed |
| `fa4ba0c` | Per-source txn in collector — pattern reference |
| `39a72e1` / `7a5949e` | Story 29-2 — logging pattern for NFR6 |
| `c90fb5e` | Story 29-1 — normalizer baseline |

### Latest tech / library notes

- **sqflite `insert` + `ConflictAlgorithm.ignore`:** returns `0` when row skipped due to conflict; returns auto-increment id otherwise. Documented sqflite behaviour — no package upgrade needed.
- **No new dependencies.**
- **Do not use `INSERT OR REPLACE`:** would overwrite aggregate without verifying source alignment — wrong semantics for this fix.
- **Flutter 3.x / Dart 3.x:** sealed class or enum for `CompactionInsertOutcome` — match project style (enum preferred, consistent with existing code).

### Project context reference

- OK commit gate: sub-tasks A/B/C/D each get separate commit after Baptiste approval
- Tests: `@Tags(['slow'])` on downsample test file
- Version bump: defer to Epic 29 close (`0.13.0+32`)
- Communication: French in chat; story in English

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 29-4]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-downsampling-compaction-fr11.md` #1, #3]
- [Source: `_bmad-output/planning-artifacts/audits_2/README.md` §P0-09, diagnostic 04]
- [Source: `lib/core/lifecycle/sample_compaction_runner.dart`]
- [Source: `lib/data/repositories/step/step_aggregation_repository.dart` `downsampleStepSamples`]
- [Source: `stories/29-3-atomic-bucket-upsert-and-baseline-commit-per-source.md`]

## Dev Agent Record

### Agent Model Used

Composer 2.5

### Debug Log References

- `flutter test test/data/repositories/step_repository_downsample_test.dart` — 6/6 passed

### Completion Notes List

- Added `CompactionInsertOutcome` enum and `TransactionCompactionWriter.insertCompactedSample` insert-or-verify contract
- Added `compaction_log.dart` for divergent conflict anomalies (AUD2-NFR6)
- Guarded all 3 tier loops: delete sources only on `inserted`/`alreadyCurrent`; counters only on `inserted`
- Regression tests: stale aggregate + modified sources preserved; counter accuracy verified
- Closed diagnostic P0-09 (#1) and P2 #3 in audits_2 docs

### File List

- `lib/core/debug/compaction_log.dart` (new)
- `lib/core/lifecycle/sample_compaction_runner.dart` (modified)
- `test/data/repositories/step_repository_downsample_test.dart` (modified)
- `_bmad-output/planning-artifacts/audits_2/diagnostic-downsampling-compaction-fr11.md` (modified)
- `_bmad-output/planning-artifacts/audits_2/README.md` (modified)

## Change Log

- 2026-07-24: Story 29-4 — compaction insert-before-delete guard, counter fix, regression tests, diagnostic closure
