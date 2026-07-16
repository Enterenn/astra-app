# Story 21.4: Route Ingestion Lock Through Session withRetry

Status: review

<!-- Post-audit Epic 21 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 21-4 · diagnostic-acces-concurrents.md §1 · AUD-04 · NFR-AUD-03 -->
<!-- Prerequisite: Stories 21-1…21-3 — done -->
<!-- Version bump: deferred to Epic 21 close (minor+1, patch=0, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want background collection locks to survive brief DB reconnects,
So that multi-isolate ingestion does not fail spuriously after session reopen.

## Acceptance Criteria

1. **Given** `IngestionCollectionLock.tryAcquire` / `release` perform SQL  
   **When** the UI or isolate session needs reopen/retry  
   **Then** lock SQL runs through `AstraDatabaseSession.withRetry` (or equivalent `_session.run`), **not** raw `StepIngestionRepository.db` (AUD-04, NFR-AUD-03)  
   **And** single-writer ingestion rule is unchanged (only `BackgroundCollector` writes buckets via `upsertIngestionBucket`)

2. **Given** lock contention between collectors (UI + WorkManager/FGS isolates share one DB file)  
   **When** `tryAcquire` finds a non-expired lock row  
   **Then** behaviour matches current semantics — returns `false`, collector no-ops (`collectOnce` returns 0)  
   **And** TTL expiry logic (`heldUntil > now`) is unchanged (default 35 s)

3. **Given** a collector successfully acquires the lock  
   **When** collection completes or throws  
   **Then** `release()` still runs in `finally` (existing `BackgroundCollector.collectOnce` structure)  
   **And** no permanent lock leak is introduced beyond existing TTL safety net

4. **Given** `database_closed` during lock SQL (simulated or real cross-isolate invalidation)  
   **When** `withRetry` reopens the session  
   **Then** the lock operation retries once and succeeds (or fails acquire honestly on contention)  
   **And** no unhandled `DatabaseException` escapes `collectOnce` solely from lock paths

5. **Given** unit tests  
   **When** story verification runs  
   **Then** `ingestion_collection_lock_test.dart` covers acquire/release/contention with session-backed lock  
   **And** at least one test proves `tryAcquire`/`release` survive `database_closed` via `withRetry`  
   **And** `background_collector_test.dart` lock-contention case still passes  
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-04 · NFR-AUD-03 · diagnostic-acces-concurrents §1

**Depends on:** Stories 21-1…21-3 — **done**

**Out of scope:** batch week goals (21-5), `end_time` index (21-6), Trends tab guard (21-7), pedometer drain timeout (21-8), changing lock TTL/key semantics, WorkManager orchestration, version bump.

## Tasks / Subtasks

- [x] **Sub-task A — Map lock bypass and read UPDATE files** (AC: #1)
  - [x] Read fully: `lib/core/services/ingestion_collection_lock.dart`
  - [x] Read: `lib/core/services/background_collector.dart` (`collectOnce` L62–88)
  - [x] Read: `lib/data/repositories/step/step_ingestion_repository.dart`, `_step_repository_session.dart`
  - [x] Read: `lib/core/database/astra_database_session.dart` (`withRetry` L66–77)
  - [x] Read: `lib/data/repositories/user_settings_repository.dart` (`tryClaimGoalNotificationShownDate` — transaction-in-withRetry pattern)
  - [x] Confirm gap: lock uses `repository.db` → `_session.database` with **no** reopen wrapper [Source: diagnostic-acces-concurrents §1]
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (docs-only map if no code yet)

- [x] **Sub-task B — Refactor IngestionCollectionLock to session API** (AC: #1, #2, #3)
  - [x] Change constructor: accept `AstraDatabaseSession` instead of raw `Database`
  - [x] `tryAcquire()`: wrap transaction in `session.withRetry((db) => db.transaction<bool>(...))` — preserve query/insert/TTL logic verbatim
  - [x] `release()`: wrap delete in `session.withRetry((db) => db.delete(...))`
  - [x] Do **not** change `kIngestionCollectLockKey`, TTL default, or transaction shape
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Wire BackgroundCollector + repository session access** (AC: #1)
  - [x] Add `AstraDatabaseSession get databaseSession => _session.session` on `StepIngestionRepository` (or expose existing `_session.session` via getter)
  - [x] In `BackgroundCollector.collectOnce`: `IngestionCollectionLock(repository.databaseSession, clock: clock)` — remove `repository.db` usage for lock
  - [x] Verify isolate bootstrap (`background_collector_factory.dart`): `StepIngestionRepository(db)` already wraps raw `Database` in `StepRepositorySession` → session getter works without factory changes
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Tests** (AC: #4, #5)
  - [x] Update `test/core/services/ingestion_collection_lock_test.dart`: construct lock with `AstraDatabaseSession(databasePath: ..., initial: db)` instead of raw `db`
  - [x] Add test: close session DB after setup, call `tryAcquire`/`release` — expect success (mirrors `astra_database_session_test.dart` pattern)
  - [x] Update `test/core/services/background_collector_test.dart` contention test if it constructs `IngestionCollectionLock(db)` directly
  - [x] Run: `flutter test test/core/services/ingestion_collection_lock_test.dart test/core/services/background_collector_test.dart`
  - [x] Run: `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| `IngestionCollectionLock` → `withRetry` | Lock TTL / key changes |
| `BackgroundCollector` lock wiring | `upsertIngestionBucket` path (already uses `_session.run`) |
| `StepIngestionRepository.databaseSession` getter | Batch goals (21-5), indexes (21-6) |
| Session-backed lock tests + `database_closed` retry | Refactor all repos to share one session type |

### Current state (read before editing)

**Lock bypasses session retry layer:**

```21:51:lib/core/services/ingestion_collection_lock.dart
  Future<bool> tryAcquire() async {
    final now = (_clock?.nowUtc() ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    final expiry = now + ttl.inMilliseconds;

    return _db.transaction<bool>((txn) async {
      // ... query held lock, insert expiry row
    });
  }
```

```54:59:lib/core/services/ingestion_collection_lock.dart
  Future<void> release() async {
    await _db.delete(
      'user_preferences',
      where: 'key = ?',
      whereArgs: [kIngestionCollectLockKey],
    );
  }
```

**Collector passes raw DB handle:**

```71:84:lib/core/services/background_collector.dart
    final lock = IngestionCollectionLock(repository.db, clock: clock);
    try {
      if (!await lock.tryAcquire()) {
        return 0;
      }
      try {
        return await _collectOnce(/* ... */);
      } finally {
        await lock.release();
      }
```

**Repositories already use retry — lock is the exception:**

```23:24:lib/data/repositories/step/_step_repository_session.dart
  Future<T> run<T>(Future<T> Function(Database db) action) =>
      _session.withRetry(action);
```

```9:9:_bmad-output/planning-artifacts/audits/diagnostic-acces-concurrents.md
Exception notable : IngestionCollectionLock utilise StepIngestionRepository.db directement, sans withRetry
```

**Cold-start timeline:** lock SQL runs at step #11 (tryAcquire) and #16 (release) during `_runPersistCycle` [Source: diagnostic-acces-concurrents §2] — same moment WorkManager/FGS isolates may invalidate UI connection.

### Target implementation (guidance)

**Reference pattern** — preference claim uses transaction inside `withRetry`:

```172:193:lib/data/repositories/user_settings_repository.dart
  Future<bool> tryClaimGoalNotificationShownDate(String localDayIso) async {
    return _kv.session.withRetry(
      (db) => db.transaction((txn) async {
        // read + conditional insert
      }),
    );
  }
```

**Lock refactor sketch:**

```dart
// ingestion_collection_lock.dart
class IngestionCollectionLock {
  IngestionCollectionLock(this._session, {this.ttl = const Duration(seconds: 35), this._clock});

  final AstraDatabaseSession _session;

  Future<bool> tryAcquire() async {
    final now = /* unchanged */;
    final expiry = now + ttl.inMilliseconds;
    return _session.withRetry(
      (db) => db.transaction<bool>((txn) async {
        // existing query + insert logic unchanged
      }),
    );
  }

  Future<void> release() async {
    await _session.withRetry(
      (db) => db.delete('user_preferences', where: 'key = ?', whereArgs: [kIngestionCollectLockKey]),
    );
  }
}
```

```dart
// step_ingestion_repository.dart
AstraDatabaseSession get databaseSession => _session.session;

// background_collector.dart
final lock = IngestionCollectionLock(repository.databaseSession, clock: clock);
```

**Why session from repository (not new DI param):** lock and bucket upserts must share the same `AstraDatabaseSession` instance so reopen invalidates/repairs the handle used for both acquire and upsert in one `collectOnce` cycle.

### Concurrency cautions

| Risk | Mitigation |
|------|------------|
| `database_closed` mid-`tryAcquire` transaction | `withRetry` reopens + retries whole transaction — atomic acquire preserved |
| Retry after partial acquire | Transaction is all-or-nothing; retry either acquires or sees held lock |
| `release()` after failed reopen | `finally` in collector still calls release; release uses own `withRetry` |
| Cross-isolate lock row | Lock is in SQLite `user_preferences`, not in-memory — session reopen does not clear row |
| Stale `repository.db` getter elsewhere | Story only removes lock usage of `.db`; do not delete getter (tests may use it) |
| Isolate factory `databasePath` default | `StepIngestionRepository(db)` uses `inMemoryDatabasePath` for reopen path — pre-existing; do not fix unless lock tests on file DB expose it |

### UI / behaviour expectations (no widget changes)

| Scenario | User-visible effect |
|----------|---------------------|
| Normal collect | Unchanged — steps ingest as today |
| Lock held by other isolate | Unchanged — silent no-op, no duplicate buckets |
| UI DB invalidated during backfill | Collect may succeed after retry instead of failing lock SQL |
| Lock TTL expiry | Unchanged — stale lock auto-expires after 35 s |

### Architecture compliance

- **Single-writer rule** ([Source: `architecture.md` § Ingestion write path]): only `BackgroundCollector` calls `upsertIngestionBucket` — this story does not add writers.
- **All SQLite via repository** — lock stays in `user_preferences` table; no new direct `db.insert` in collector.
- **Cross-isolate mutex** — SQLite-backed lock in `user_preferences` remains source of truth; instance `_collectInFlight` on UI collector stays as first guard.
- **NFR-AUD-03** — UI session resilience: lock joins the same `withRetry` family as settings/health/step repos.

### Project structure notes

| Path | Role |
|------|------|
| `lib/core/services/ingestion_collection_lock.dart` | **UPDATE** — session-backed SQL |
| `lib/core/services/background_collector.dart` | **UPDATE** — pass `repository.databaseSession` |
| `lib/data/repositories/step/step_ingestion_repository.dart` | **UPDATE** — expose `databaseSession` getter |
| `lib/data/repositories/step/_step_repository_session.dart` | **READ** — existing `session` getter |
| `lib/core/database/astra_database_session.dart` | **READ** — `withRetry` contract |
| `test/core/services/ingestion_collection_lock_test.dart` | **UPDATE** — session construction + retry test |
| `test/core/services/background_collector_test.dart` | **UPDATE** — lock helper construction if needed |
| `lib/core/services/background_collector_factory.dart` | **Verify only** — no change expected |

### Testing requirements

- **Primary:** `flutter test test/core/services/ingestion_collection_lock_test.dart test/core/services/background_collector_test.dart`
- **Regression:** `flutter test --exclude-tags slow`
- **`database_closed` test pattern:** close `session.database`, invoke lock op, assert success + `session.database.isOpen` (copy from `astra_database_session_test.dart` L37–41)
- **Do not** add timing-based flake tests — use explicit close + retry assertion
- **`app_health_fgs_lifecycle_test.dart`:** comment notes `IngestionCollectionLock.release()` vs `db.close` tearDown race — if test fails after refactor, fix tearDown ordering; do not weaken lock release

### Previous story intelligence (21-3)

- **21-3 pattern:** small API extension + coordinator wiring + call-count/behaviour tests; OK-commit gate per sub-task.
- **21-3 scope discipline:** post-backfill reconcile and parallel `_runPersistCycle` paths left untouched — same here: only lock SQL path, not `_collectOnce` body.
- **21-3 review:** prefer explicit regression tests over assuming retrofit compatibility.

### Git intelligence

Recent Epic 21 commits (monitor/cold-start — adjacent, not lock):
- `05c1102` — story 21-3 done + review tests
- `10d0118` / `404acc4` — seed API for duplicate query dedup

Pattern: one concern per commit; lock refactor isolated from monitor/cubit work.

### Latest tech notes

- No new packages. `sqflite` transaction API unchanged inside `withRetry` callback.
- `AstraDatabaseSession.withRetry` retries **once** after reopen — sufficient for `database_closed`; do not add custom retry loops in lock.
- Constructor breaking change on `IngestionCollectionLock` — update all 3 call sites: `background_collector.dart`, `ingestion_collection_lock_test.dart`, `background_collector_test.dart`.

### Project context reference

- OK-commit gate: sub-task → review brief → Baptiste OK → commit ([Source: `docs/project-context.md`])
- Tests: `flutter test --exclude-tags slow`
- No version bump until Epic 21 closes

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` — Story 21-4, AUD-04]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-acces-concurrents.md` — §1 connection sharing, §2 steps #11/#16]
- [Source: `_bmad-output/planning-artifacts/audits/README.md` — lock via withRetry checklist item]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — single-writer, BackgroundCollector]
- [Source: `_bmad-output/implementation-artifacts/stories/21-3-deduplicate-cold-start-get-today-steps-queries.md` — epic patterns, out-of-scope list]
- [Source: `lib/core/database/astra_database_session.dart`]
- [Source: `docs/project-context.md`]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- Sub-task A: Gap confirmed — `IngestionCollectionLock` uses raw `Database._db` with no `withRetry`; `BackgroundCollector.collectOnce` passes `repository.db`; `_StepRepositorySession.session` getter already exists (L19); fix plan clear.
- Sub-task B: `IngestionCollectionLock` refactored — constructor now takes `AstraDatabaseSession`; `tryAcquire` and `release` wrapped in `withRetry`; TTL/key/transaction logic unchanged.
- Sub-task C: `StepIngestionRepository.databaseSession` getter added; `BackgroundCollector.collectOnce` now passes `repository.databaseSession` to lock; factory unchanged (pre-existing `inMemoryDatabasePath` not in scope).
- Sub-task D: `ingestion_collection_lock_test.dart` updated to `AstraDatabaseSession` construction + `database_closed` retry test added; `background_collector_test.dart` contention test updated; 24/24 lock+collector tests pass; 848/848 regression suite passes.

### File List

- `lib/core/services/ingestion_collection_lock.dart`
- `lib/core/services/background_collector.dart`
- `lib/data/repositories/step/step_ingestion_repository.dart`
- `test/core/services/ingestion_collection_lock_test.dart`
- `test/core/services/background_collector_test.dart`

## Change Log

- 2026-07-16: Story context created (ready-for-dev) — ultimate context engine analysis completed
- 2026-07-16: Sub-task A complete — gap mapped, no code changes
- 2026-07-16: Sub-task B complete — IngestionCollectionLock refactored to AstraDatabaseSession + withRetry
- 2026-07-16: Sub-task C complete — databaseSession getter + BackgroundCollector wired
- 2026-07-16: Sub-task D complete — tests updated, database_closed retry test added, 848/848 pass
