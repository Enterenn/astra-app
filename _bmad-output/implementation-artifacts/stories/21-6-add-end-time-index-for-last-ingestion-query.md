# Story 21.6: Add end_time Index for Last Ingestion Query

Status: review

<!-- Post-audit Epic 21 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 21-6 · diagnostic-cold-start.md §B2 · AUD-07 · NFR-AUD-02 -->
<!-- Prerequisite: Stories 21-1…21-5 — done -->
<!-- Version bump: deferred to Epic 21 close (minor+1, patch=0, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want stale/last-ingestion checks to stay fast as data grows,
So that Today metadata refresh does not scan the full timeseries table.

## Acceptance Criteria

1. **Given** last-ingestion queries use `MAX(end_time)` filtered by `type = 'steps'`
   **When** schema migrates to v4
   **Then** index `idx_timeseries_last_end` on `timeseries_samples (type, end_time DESC)` is created via migration (AUD-07)
   **And** `kDbVersion` is bumped from `3` to `4`
   **And** migration is incremental and safe on existing installs (v3 → v4 upgrade path)

2. **Given** a fresh install at v4
   **When** `runMigrations(db, 4)` completes
   **Then** all prior schema (v1–v3) remains intact
   **And** `idx_timeseries_last_end` exists alongside `idx_timeseries_query` and `idx_bucket_identity`

3. **Given** existing queries and consumers
   **When** migration applies
   **Then** `StepAggregationRepository.getLastIngestionUtc()` SQL is unchanged
   **And** no functional regression in last-ingestion / stale banner logic (`TodayCubit`, `MyDataCubit`, `CollectionHealthIndicator`, `BackgroundStatusCard`)

4. **Given** unit tests
   **When** story verification runs
   **Then** migration tests assert index existence, column order `(type, end_time)`, and `DESC` on `end_time` (mirror v2 index assertions)
   **And** v3 → v4 upgrade test preserves existing data and adds the new index only
   **And** `step_repository_last_ingestion_test.dart` still passes unchanged
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-07 · NFR-AUD-02 (contributes to ~100–200 ms full Today refresh target) · diagnostic-cold-start §B2

**Depends on:** Stories 21-1…21-5 — **done**

**Out of scope:** Changing `getLastIngestionUtc` SQL, B3 active-buckets partial index, B4 chart SQL aggregation, query-plan benchmarks, version bump, `AppLifecycleCoordinator` / cubit logic changes.

## Tasks / Subtasks

- [x] **Sub-task A — Add migration v4 index** (AC: #1, #2)
  - [x] Read fully: `lib/core/database/migrations.dart` — current `kDbVersion = 3`, switch cases, `onCreateV2` index patterns
  - [x] Bump `kDbVersion` to `4`
  - [x] Add `case 4:` → `onCreateV4(db)` in `runMigrations` switch
  - [x] Implement `onCreateV4`:
    ```sql
    CREATE INDEX IF NOT EXISTS idx_timeseries_last_end
      ON timeseries_samples (type, end_time DESC)
    ```
  - [x] Do **not** modify `onCreateV2` / v3 — v4 is the sole delivery path (fresh + upgrade)
  - [x] Do **not** touch `app_database.dart` unless `kDbVersion` import breaks (it reads constant automatically)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Migration tests** (AC: #2, #4)
  - [x] Update `test/core/database/migrations_test.dart`:
    - Extend fresh-install index test (currently asserts `idx_timeseries_query` + `idx_bucket_identity`) to also expect `idx_timeseries_last_end`
    - Assert columns via `PRAGMA index_info(idx_timeseries_last_end)` → `['type', 'end_time']`
    - Assert `DESC` on `end_time` via `PRAGMA index_xinfo` (same pattern as `start_time` on `idx_timeseries_query`, L131–137)
  - [x] Add `migration v3 to v4 upgrade` group:
    - Open v3 DB on temp file (`version: 3`, `onCreate` → `runMigrations(db, 3)`)
    - Insert sample rows into `timeseries_samples` + `daily_goal_effective` seed
    - Close, reopen via `openAstraDatabase` (v4)
    - Assert data preserved + new index present
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Regression** (AC: #3, #4)
  - [x] Run: `flutter test test/core/database/migrations_test.dart`
  - [x] Run: `flutter test test/data/repositories/step_repository_last_ingestion_test.dart`
  - [x] Run: `flutter test test/core/health/stale_data_evaluator_test.dart`
  - [x] Run: `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Migration v4 + `idx_timeseries_last_end` | Rewriting `getLastIngestionUtc` query |
| `kDbVersion` bump 3 → 4 | B3 `idx_timeseries_active` partial index |
| Migration + upgrade tests | EXPLAIN QUERY PLAN perf assertions |
| Regression on last-ingestion consumers | TodayCubit / coordinator changes |

### Current state (read before editing)

**Query to optimize (do not change SQL this story):**

```276:290:lib/data/repositories/step/step_aggregation_repository.dart
  Future<DateTime?> getLastIngestionUtc() async {
    final rows = await _session.run(
      (db) => db.rawQuery(
        '''
      SELECT MAX(end_time) AS last_end_time
      FROM timeseries_samples
      WHERE type = ?
      ''',
        [kStepSampleType],
      ),
    );
    final value = rows.single['last_end_time'] as String?;
    return value == null ? null : TimestampCodec.parseUtc(value);
  }
```

**Existing index (covers `start_time`, not `end_time`):**

```77:80:lib/core/database/migrations.dart
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_timeseries_query
      ON timeseries_samples (type, start_time DESC)
  ''');
```

**Why a separate index:** SQLite cannot use `(type, start_time DESC)` efficiently for `MAX(end_time) WHERE type = ?`. Without `(type, end_time DESC)`, the planner scans all step rows per type — cost grows with history volume [Source: diagnostic-cold-start §B2, L182].

**Consumers (read-only this story — verify no regression):**

| Consumer | Usage |
|----------|-------|
| `TodayCubit._enrichAfterFastPath` | Deferred `getLastIngestionUtc()` → `isStaleData` → stale banner |
| `TodayCubit.refresh` / `refreshMetadata` | Same stale evaluation path |
| `MyDataCubit.load` | Background status card |
| `CollectionHealthIndicator` | Today week strip health dot |
| `BackgroundStatusCard` | My Data footprint section |

**Cold-start context:** `getLastIngestionUtc()` is **deferred** off the fast path (Story 21-1). This index optimizes the enrichment + full refresh paths, not first paint.

### Target implementation (guidance)

```dart
const kDbVersion = 4;

// in runMigrations switch:
case 4:
  await onCreateV4(db);

Future<void> onCreateV4(Database db) async {
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_timeseries_last_end
      ON timeseries_samples (type, end_time DESC)
  ''');
}
```

**Naming:** `idx_timeseries_last_end` matches diagnostic B2 and architecture index convention `idx_{table}_{purpose}` [Source: architecture.md L587].

**Idempotency:** `CREATE INDEX IF NOT EXISTS` — safe on re-run / partial failure retry.

### Regression cautions

| Risk | Mitigation |
|------|------------|
| Forgetting v3→v4 upgrade test | Follow Story 8-1 / 2-1 file-backed upgrade pattern |
| Breaking fresh install (runs v1→v4 chain) | Extend existing fresh-install index assertions, don't replace |
| Accidentally editing query SQL | AC #3 — repository unchanged; index-only story |
| Index name drift from diagnostic | Use exact name `idx_timeseries_last_end` |
| Data loss on upgrade | Insert sample rows in v3 DB before upgrade; assert row count + values after |

### Architecture compliance

- **D-15:** Numbered migrations via `runMigrations`; bump `kDbVersion` in `migrations.dart` only [Source: architecture.md].
- **Index naming:** `idx_timeseries_last_end` alongside `idx_timeseries_query`, `idx_bucket_identity`.
- **Single-writer rule:** No repository or ingestion changes — read-path optimization only.
- **Isolate safety:** Index is schema-level; both UI and WorkManager isolates benefit automatically on next `openAstraDatabase`.
- **OK-commit gate:** One commit per sub-task [Source: `docs/project-context.md`].

### Project structure notes

| Path | Role |
|------|------|
| `lib/core/database/migrations.dart` | **UPDATE** — v4 index, `kDbVersion = 4` |
| `lib/core/database/app_database.dart` | **READ** — uses `kDbVersion` constant (no edit expected) |
| `lib/data/repositories/step/step_aggregation_repository.dart` | **READ** — query unchanged |
| `test/core/database/migrations_test.dart` | **UPDATE** — fresh install + v3→v4 upgrade tests |
| `test/data/repositories/step_repository_last_ingestion_test.dart` | **READ** — regression must pass unchanged |
| `test/core/health/stale_data_evaluator_test.dart` | **READ** — pure logic, no DB; sanity run |

### Testing requirements

- **Primary:** `flutter test test/core/database/migrations_test.dart`
- **Regression:** `flutter test test/data/repositories/step_repository_last_ingestion_test.dart`
- **Full:** `flutter test --exclude-tags slow`
- **Index assertion pattern (copy from v2 test):**
  ```dart
  final columns = await db.rawQuery('PRAGMA index_info(idx_timeseries_last_end);');
  expect(columns.map((c) => c['name']), orderedEquals(['type', 'end_time']));
  final xinfo = await db.rawQuery('PRAGMA index_xinfo(idx_timeseries_last_end);');
  final endTimeCol = xinfo.firstWhere((c) => c['name'] == 'end_time');
  expect(endTimeCol['desc'], 1);
  ```
- **Do not** add timing-based performance tests — index existence + functional regression is sufficient for AC
- **Do not** add EXPLAIN QUERY PLAN tests unless trivial — not required by AC

### Previous story intelligence (21-5)

- **Pattern:** Small targeted change + migration/regression tests; OK-commit gate per sub-task.
- **Scope discipline:** Database/index only — do not touch cubit orchestration, batch goals, or ingestion lock.
- **Deferred enrichment:** `getLastIngestionUtc` runs in `_enrichAfterFastPath` parallel batch (L297–302) — index speeds that deferred path, not fast-path paint.
- **Fake fixes:** Story 21-5 needed contract fake updates for unrelated batch API — not applicable here (no API changes).

### Git intelligence

Recent Epic 21 commits:
- `84a3495` — story 21-5 review + done
- `40b2224` — batch week goal resolution (cubit perf)
- `1265784` — story 21-4 lock/session done

Pattern: database stories (21-3, 21-4) isolated from cubit changes; this story is pure schema — expect single-file migration + test commit.

### Latest tech notes

- **sqflite ^2.4.2+1** — `CREATE INDEX IF NOT EXISTS` supported; DESC column order via SQLite index definition (same as v2 `idx_timeseries_query`).
- **SQLite on Android/iOS:** Composite index `(type, end_time DESC)` supports `WHERE type = ?` + `MAX(end_time)` seek — no partial index needed.
- No new packages. No Flutter/Dart API changes.

### Project context reference

- OK-commit gate: sub-task → review brief → Baptiste OK → commit
- Commit convention: `feat(database): add end_time index for last-ingestion query (story 21-6)`
- Tests: `flutter test --exclude-tags slow`
- No version bump until Epic 21 closes

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` — Story 21-6, AUD-07]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-cold-start.md` — §B2 index DDL]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — D-15 migrations, index naming]
- [Source: `_bmad-output/implementation-artifacts/stories/2-1-sqlite-schema-for-timeseries-samples.md` — migration test template]
- [Source: `_bmad-output/implementation-artifacts/stories/8-1-daily-goal-history-schema-and-repository.md` — v3 migration pattern]
- [Source: `_bmad-output/implementation-artifacts/stories/21-5-batch-week-goal-resolution-and-reduce-n-plus-1.md` — epic patterns, explicit out-of-scope for 21-6]
- [Source: `lib/core/database/migrations.dart`]
- [Source: `lib/data/repositories/step/step_aggregation_repository.dart` — `getLastIngestionUtc`]
- [Source: `test/core/database/migrations_test.dart`]
- [Source: `docs/project-context.md`]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-5

### Debug Log References

### Completion Notes List

- Sub-task A: `kDbVersion` 3→4, `onCreateV4` added with `idx_timeseries_last_end ON timeseries_samples (type, end_time DESC)`. No v1–v3 migration modified.
- Sub-task B: fresh-install index test extended (3 indexes + column order + DESC assertion); `migration v3 to v4 upgrade` group added (data preservation + index presence).
- Sub-task C: 12/12 migration tests ✅ · 9/9 regression tests ✅ · 851/851 full suite ✅

### File List

- lib/core/database/migrations.dart
- test/core/database/migrations_test.dart
- _bmad-output/implementation-artifacts/sprint-status-post-audit.yaml

## Change Log

- 2026-07-16: Story context created (ready-for-dev) — ultimate context engine analysis completed
- 2026-07-16: Implementation complete — migration v4 + tests; all 851 tests pass (review)
