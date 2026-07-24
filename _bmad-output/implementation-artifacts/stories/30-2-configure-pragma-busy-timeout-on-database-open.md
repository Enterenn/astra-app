# Story 30.2: Configure PRAGMA busy_timeout on Database Open

Status: done

<!-- audits_2 Epic 30 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 30-2 · diagnostic-couche-donnees.md #5 · AUD2-FR14 -->
<!-- Prerequisite: 30-1 done · base 0.13.0+32 -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want the app to retry briefly when SQLite is busy across isolates,
So that background tasks and UI do not fail with avoidable `database_locked` errors.

## Acceptance Criteria

1. **Given** `AppDatabase` / `onConfigure` (or equivalent open hook)
   **When** the database connection opens
   **Then** `PRAGMA busy_timeout=5000` (or project-standard value) is set — AUD2-FR14

2. **Given** concurrent WM collection and UI read under test
   **When** contention occurs
   **Then** `AstraDatabaseSession.withRetry` can recover without user-visible failure in happy-path tests

**Covers:** AUD2-FR14 · AUD2-NFR2 · diagnostic-couche-donnees.md #5 (P1)

**Depends on:** 30-1 done (maintenance + collection cross-isolate locks). Ships **after 30-1**, before 30-3.

**Out of scope:** Changing `withRetry` to loop on `database_locked` (busy_timeout is SQLite-level wait); maintenance lock wiring (30-1); iOS gap doc (30-3); `TimeProvider` in `_TimeoutBoundedSource` (30-4); version bump (Epic 30 close → patch+1).

## Tasks / Subtasks

- [x] **Sub-task A — busy_timeout constant + onConfigure PRAGMA** (AC: #1)
  - [x] Read fully: `app_database.dart`, `isolate_database_factory.dart`, `astra_database_session.dart` (`_reopenImpl` L57-64)
  - [x] Add `const kDatabaseBusyTimeoutMs = 5000;` in `app_database.dart` (project-standard; diagnostic recommends 5000)
  - [x] In `onConfigure`, after existing PRAGMAs, add: `await db.rawQuery('PRAGMA busy_timeout = $kDatabaseBusyTimeoutMs');`
  - [x] Use `rawQuery` not `execute()` — Android sqflite throws on PRAGMA via execute (existing comment L17)
  - [x] Apply to **all** connections: file-backed, in-memory, UI reopen, WM via `openIsolateAstraDatabase` (all delegate to `openAstraDatabase`)
  - [x] Do **not** gate on `enableWal` — busy_timeout applies to in-memory test DBs too
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Tests** (AC: #1, #2)
  - [x] Read: `test/core/database/migrations_test.dart` (WAL L70-85, foreign_keys L87-90 pattern)
  - [x] Add PRAGMA assertion test: after `openAstraDatabase`, `PRAGMA busy_timeout;` returns `5000` (in-memory + file-backed)
  - [x] Add reopen assertion: `AstraDatabaseSession.reopen()` connection also has busy_timeout set
  - [x] Add happy-path contention test (minimum): two connections on same file path — connection A starts write txn and holds briefly; connection B read via `withRetry` succeeds (no throw). Pattern: `workmanager_callback_test.dart` dual-`openAstraDatabase` on same `databasePath`
  - [x] Run: `flutter test test/core/database/migrations_test.dart test/core/database/astra_database_session_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Diagnostic closure** (AC: #1)
  - [x] Update `planning-artifacts/audits_2/diagnostic-couche-donnees.md` #5 → `fixed` with story ref
  - [x] Update `planning-artifacts/audits_2/README.md`: row #5 statut + M1 todo + concurrence SQLite table (L87)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

UI, WorkManager, and file-picker flows share `astra_app.db`. Each isolate opens its own sqflite connection via `openAstraDatabase` / `openIsolateAstraDatabase`. Today:

| Mitigation | Layer | Handles |
|------------|-------|---------|
| WAL | SQLite | Concurrent readers + one writer |
| `IngestionCollectionLock` + maintenance lock (30-1) | App preference txn | Collect vs maintenance serialization |
| `AstraDatabaseSession.withRetry` | Session | `database_closed` after other isolate closes shared file |

**Gap:** No `PRAGMA busy_timeout`. When two connections contend for a write lock, SQLite returns `SQLITE_BUSY` immediately (default timeout 0). Short overlaps (e.g. WM read during UI preference write) can fail instead of waiting.

[Source: `diagnostic-couche-donnees.md` #5 · `epics-audits-2.md` AUD2-FR14]

### Recommended implementation

**Single change point — `openAstraDatabase.onConfigure`:**

```dart
const kDatabaseBusyTimeoutMs = 5000;

onConfigure: (db) async {
  if (enableWal) {
    await db.rawQuery('PRAGMA journal_mode=WAL');
  }
  await db.rawQuery('PRAGMA foreign_keys = ON');
  await db.rawQuery('PRAGMA busy_timeout = $kDatabaseBusyTimeoutMs');
},
```

**Why not `astra_database_session.dart`?** busy_timeout is per-connection, set at open. `reopen()` already calls `openAstraDatabase` — no session changes needed.

**Why 5000 ms?** Diagnostic + epic specify 5000. Aligns with collection lock TTL (35s) and maintenance TTL (10 min) — busy_timeout is a short spin-wait, not a cross-isolate mutex. Locks (30-1) prevent long VACUUM vs collect overlap; busy_timeout absorbs brief same-millisecond contention.

**Interaction with `withRetry`:** `withRetry` retries once on `database_closed` only (L66-77). Do **not** extend it to retry `database_locked` — busy_timeout makes SQLite wait internally. AC #2 means existing session tests + new contention test pass without user-visible errors, not a withRetry refactor.

### Current file state (UPDATE — read completely)

**`app_database.dart`** — `onConfigure` sets WAL (file only) + `foreign_keys=ON`. No busy_timeout. All opens flow through here.

**`isolate_database_factory.dart`** — Thin wrapper: `return openAstraDatabase(...)`. No separate PRAGMA path.

**`astra_database_session.dart`** — `_reopenImpl` L63: `_db = await openAstraDatabase(databasePath: databasePath)`. Reopened connections inherit busy_timeout automatically.

### Preserve (do not break)

| Behaviour | Must remain |
|-----------|-------------|
| WAL on file-backed DB only | `enableWal = path != inMemoryDatabasePath` unchanged |
| `foreign_keys=ON` on every connection | Keep order: WAL → foreign_keys → busy_timeout |
| `rawQuery` for all PRAGMAs | Android sqflite constraint |
| 30-1 maintenance/collection locks | Untouched — complementary, not replaced |
| `withRetry` single retry on `database_closed` | No new retry loops |
| Migration version / schema | No DB version bump for PRAGMA-only change |

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-06: isolate-safe factory + WAL PRAGMAs | Extend same `onConfigure` hook — all isolates get busy_timeout |
| D-24: repository-owned transactions | No change — shorter busy windows reduce txn collision failures |
| AUD2-NFR2: SQLite concurrency | busy_timeout + 30-1 locks = layered defense |
| NFR-AUD-03: separate connections per isolate | Each connection sets busy_timeout at open independently |

[Source: `architecture.md` §D-06, isolate-safe persistence · `epics-audits-2.md` guardrails]

### File structure requirements

| File | Action |
|------|--------|
| `lib/core/database/app_database.dart` | Add `kDatabaseBusyTimeoutMs` + PRAGMA in `onConfigure` |
| `test/core/database/migrations_test.dart` | PRAGMA busy_timeout assertions (fits existing DB open tests) |
| `test/core/database/astra_database_session_test.dart` | Reopen inherits busy_timeout; optional contention test |
| `planning-artifacts/audits_2/diagnostic-couche-donnees.md` | Close #5 |
| `planning-artifacts/audits_2/README.md` | Sync #5 + M1 + concurrence table |

**Do not touch:** `ingestion_collection_lock.dart`, `data_lifecycle_service.dart`, `background_collector.dart`, `withRetry` implementation, version bump.

### Testing requirements

| Command | When |
|---------|------|
| `flutter test test/core/database/migrations_test.dart` | After Sub-task B |
| `flutter test test/core/database/astra_database_session_test.dart` | After Sub-task B (contention / reopen) |

**New test scenarios (minimum):**

1. `PRAGMA busy_timeout;` returns `5000` on in-memory open
2. `PRAGMA busy_timeout;` returns `5000` on file-backed open
3. After `AstraDatabaseSession.reopen()`, busy_timeout still `5000`
4. Dual-connection: held write txn on conn A → read on conn B via `withRetry` succeeds (happy-path contention)

**Contention test sketch:**

```dart
// Pseudocode — adapt to sqflite_ffi
final path = ...;
final dbA = await openAstraDatabase(databasePath: path);
final dbB = await openAstraDatabase(databasePath: path);
await dbA.execute('BEGIN IMMEDIATE'); // hold write lock briefly
final sessionB = AstraDatabaseSession(databasePath: path, initial: dbB);
final future = sessionB.withRetry((db) => db.query('user_preferences', limit: 1));
await Future.delayed(const Duration(milliseconds: 100));
await dbA.execute('COMMIT');
await expectLater(future, completes); // B waited via busy_timeout, did not throw
```

Use `@Tags(['critical'])` on new tests in `migrations_test.dart` if added there (file already critical-tagged).

Do **not** run bare `flutter test` unless Baptiste asks.

### Previous story intelligence (30-1)

| Learning | Impact on 30-2 |
|----------|----------------|
| Maintenance lock (`kDatabaseMaintenanceLockKey`, 10 min TTL) + collection lock mutual exclusion | Reduces long VACUUM vs collect overlap; busy_timeout handles residual micro-contention |
| `openAstraDatabase` is shared by UI reopen and WM `openIsolateAstraDatabase` | Single PRAGMA change covers all isolates |
| `tryAcquire` atomic opposing-lock check (code review patch) | Lock layer stable — do not modify for this story |
| Diagnostic closure pattern: update `.md` #N + README row | Replicate for #5 / M1 |
| OK commit gate per sub-task | A → B → C, separate commits |

[Source: `stories/30-1-cross-isolate-lock-for-maintenance-and-vacuum.md`]

### Cross-story context (Epic 30)

| Story | Status | Relationship |
|-------|--------|--------------|
| 30-1 | done | Maintenance VACUUM lock — reduces need for long busy waits |
| **30-2** | **this story** | SQLite-level busy wait on every connection open |
| 30-3 | backlog | iOS WM gap documentation |
| 30-4 | backlog | `TimeProvider` in `_TimeoutBoundedSource` |

After Epic 30: bump patch+1 in `pubspec.yaml` + `README.md`, mark `epic-30: done`.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `2538f68` | 30-1 code review — atomic opposing lock in tryAcquire |
| `546dc5c`–`8777b22` | 30-1 maintenance lock wiring across lifecycle/collector |
| `e56e5bc` | Epic 29 closed — persist path stable baseline |

Recent commits confirm Epic 30 active on `main`; 30-1 merged, 30-2 is natural next step per sprint tracker comment.

### Latest tech / library notes

- **sqflite ^2.4.2+1** — `PRAGMA busy_timeout` via `rawQuery` (same as WAL/foreign_keys). Value in milliseconds; persists for connection lifetime.
- **SQLite 3.x** — Default busy_timeout=0 (fail immediately). Setting 5000 makes engine sleep/retry up to 5s before returning SQLITE_BUSY to sqflite.
- **sqflite_common_ffi ^2.4.0+3** (tests) — busy_timeout supported in FFI test harness; dual-connection contention tests viable.
- **No new packages.** One constant + one PRAGMA line.

### Project context reference

- OK commit gate: sub-tasks A→C, separate commits after Baptiste approval
- Tests: localized `flutter test <path>` per token-economy rule
- Version bump: defer to Epic 30 close (patch+1)
- Communication: French in chat; story in English

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 30-2, AUD2-FR14]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-couche-donnees.md` #5]
- [Source: `_bmad-output/planning-artifacts/audits_2/README.md` §#5, M1, concurrence table]
- [Source: `lib/core/database/app_database.dart`]
- [Source: `lib/core/database/isolate_database_factory.dart`]
- [Source: `lib/core/database/astra_database_session.dart`]
- [Source: `test/core/database/migrations_test.dart` — WAL/foreign_keys test patterns]
- [Source: `stories/30-1-cross-isolate-lock-for-maintenance-and-vacuum.md`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Contention test: read-under-lock passes in WAL but tearDown failed on `sessionB.database`; switched to write-under-lock + `dbB.isOpen` tearDown.

### Completion Notes List

- Sub-task A: `kDatabaseBusyTimeoutMs = 5000` + `PRAGMA busy_timeout` in `openAstraDatabase.onConfigure` (all connections).
- Sub-task B: PRAGMA assertions (in-memory + file), reopen inherits busy_timeout, dual-connection write contention via `withRetry`.
- Sub-task C: diagnostic #5 → `fixed` (30-2); README concurrence table, row #5, M1 updated.
- Tests: 18/18 pass on targeted files; critical suite green.

### File List

- `lib/core/database/app_database.dart`
- `test/core/database/migrations_test.dart`
- `test/core/database/astra_database_session_test.dart`
- `_bmad-output/planning-artifacts/audits_2/diagnostic-couche-donnees.md`
- `_bmad-output/planning-artifacts/audits_2/README.md`
- `_bmad-output/implementation-artifacts/sprint-status-audits-2.yaml`

### Change Log

- 2026-07-24: Story 30-2 — PRAGMA busy_timeout on every DB open; tests + audit diagnostic closure.
