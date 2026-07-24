# Story 30.1: Cross-Isolate Lock for Maintenance and VACUUM

Status: review

<!-- audits_2 Epic 30 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 30-1 · diagnostic-workmanager-maintenance-db.md #2 · AUD2-FR11, AUD2-FR26, AUD2-NFR8 -->
<!-- Prerequisite: Epic 29 done · base 0.13.0+32 -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want database maintenance not to collide with background step collection,
So that my data file is not corrupted during VACUUM or downsampling.

## Acceptance Criteria

1. **Given** `DataLifecycleService.runMaintenanceOnConnection` with `maintenanceOnCurrentConnection: true` (WM path)
   **When** maintenance runs downsample + VACUUM
   **Then** a cross-isolate lock is acquired before work begins — AUD2-FR11
   **And** the 15-min step collection task waits or skips while lock is held (same pattern as `IngestionCollectionLock`)

2. **Given** maintenance lock implementation
   **When** configured
   **Then** it uses a dedicated lock key and TTL suited to VACUUM duration (not 35s collection TTL) — AUD2-FR26

3. **Given** UI-triggered maintenance via `compute` offload
   **When** WM maintenance is not running
   **Then** existing UI path behaviour is preserved — AUD2-NFR8

**Covers:** AUD2-FR11 · AUD2-FR26 · AUD2-NFR2 · AUD2-NFR8 · diagnostic-workmanager-maintenance-db.md #2 (P0-08)

**Depends on:** Epic 29 done (atomic collect txn, compaction guard). Epic 30 ships **30-1 → 30-4** in order.

**Out of scope:** `PRAGMA busy_timeout` (30-2), iOS gap doc (30-3), `TimeProvider` in `_TimeoutBoundedSource` (30-4), version bump (Epic 30 close → patch+1 per sprint tracker).

## Tasks / Subtasks

- [x] **Sub-task A — Maintenance lock key + generalized lock API** (AC: #2)
  - [x] Read fully: `ingestion_collection_lock.dart`, `preference_keys.dart`, `ingestion_collection_lock_test.dart`
  - [x] Add `kDatabaseMaintenanceLockKey = 'database_maintenance_lock'` to `preference_keys.dart`
  - [x] Add project-standard maintenance TTL constant (recommend `Duration(minutes: 10)` — diagnostic #5 suggests 5–10 min; VACUUM can exceed 35s)
  - [x] Extend `IngestionCollectionLock` with optional `lockKey` + `ttl` params (defaults unchanged: `kIngestionCollectLockKey`, 35s) — **do not** rename the class (21-4 references, tests, docs)
  - [x] Add named convenience: `IngestionCollectionLock.forMaintenance(session, {clock})` using maintenance key + TTL
  - [x] Add static/read helper `Future<bool> isHeld(AstraDatabaseSession session, String lockKey, {TimeProvider? clock})` for cross-lock checks without acquiring
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Acquire maintenance lock on WM path** (AC: #1)
  - [x] Read fully: `data_lifecycle_service.dart` (`runMaintenanceOnConnection`, `_runMaintenanceImpl`, `_maintenanceOnCurrentConnection`)
  - [x] Read: `workmanager_callback.dart` (`runDatabaseMaintenanceWorkmanagerTask` L129-165)
  - [x] When `_maintenanceOnCurrentConnection == true`, wrap `_runMaintenanceImpl` body (the `runMaintenanceOnConnection` call path) with maintenance lock acquire/release in `finally`
  - [x] Before acquire: if collection lock (`kIngestionCollectLockKey`) is non-expired → skip maintenance this cycle (`LifecycleRunResult(skipped: true)`) — mutual exclusion
  - [x] If maintenance lock not acquired (contention) → skip (`skipped: true`), do **not** throw — weekly WM can retry next schedule
  - [x] **Do not** change UI `compute` offload path (`useIsolateOffload == true`) — AUD2-NFR8 regression guard
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Collection skips when maintenance lock held** (AC: #1)
  - [x] Read: `background_collector.dart` `collectOnce` L65-91
  - [x] Before collection `tryAcquire`, check `isHeld(..., kDatabaseMaintenanceLockKey)` — if true, return `0` (same no-op semantics as held collection lock)
  - [x] Preserve existing `_collectInFlight`, collection lock acquire/release, and `finally` structure from 21-4
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Tests** (AC: #1, #2, #3)
  - [x] Extend `ingestion_collection_lock_test.dart`: maintenance factory uses dedicated key; TTL independent of collection; `isHeld` reflects expiry
  - [x] Add `background_collector_test.dart`: `collectOnce` no-ops when maintenance lock held (mirror existing ingestion-lock-held test L242-267)
  - [x] Add `data_lifecycle_service_test.dart`: `maintenanceOnCurrentConnection: true` skips when collection lock held; skips when maintenance lock already held
  - [x] Add `workmanager_callback_test.dart` or lifecycle test: WM maintenance path does not run downsample when lock blocked (optional inject `runMaintenance`)
  - [x] Run: `flutter test test/core/services/ingestion_collection_lock_test.dart test/core/services/background_collector_test.dart test/core/services/data_lifecycle_service_test.dart test/core/services/workmanager_callback_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Diagnostic closure** (AC: #1)
  - [x] Update `planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md` #2 → `fixed` with story ref
  - [x] Update `planning-artifacts/audits_2/README.md` P0-08 row + epic 03 status if applicable
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

WorkManager runs two periodic Android tasks on the **same** `astra_app.db` file:

| Task | Unique name | Frequency | Lock today |
|------|-------------|-----------|------------|
| Step collection | `astra_step_collection_periodic` | 15 min | `IngestionCollectionLock` (35s TTL) |
| DB maintenance | `astra_database_maintenance_periodic` | 7 days | **None** |

WM maintenance calls `DataLifecycleService` with `maintenanceOnCurrentConnection: true` → `runMaintenanceOnConnection` → downsample + `PRAGMA optimize` + `VACUUM` on the WM isolate connection. If collection overlaps, SQLite can deadlock or corrupt under concurrent write + VACUUM.

**Mitigation already in place (do not break):** UI-triggered maintenance uses `compute` + ephemeral connection (`data_lifecycle_service.dart:168-180`) — avoids UI-connection VACUUM race. This story targets **WM vs WM** collision only.

[Source: `diagnostic-workmanager-maintenance-db.md` #2 · `epics-audits-2.md` AUD2-FR11]

### Recommended implementation

**1. Generalize lock, don't duplicate class**

Story 21-4 established `IngestionCollectionLock` + `AstraDatabaseSession.withRetry`. Reuse the same txn pattern with parameterized key:

```dart
class IngestionCollectionLock {
  IngestionCollectionLock(
    this._session, {
    String? lockKey,
    Duration? ttl,
    TimeProvider? clock,
  }) : _lockKey = lockKey ?? kIngestionCollectLockKey,
       ttl = ttl ?? const Duration(seconds: 35),
       _clock = clock;

  factory IngestionCollectionLock.forMaintenance(
    AstraDatabaseSession session, {
    TimeProvider? clock,
  }) => IngestionCollectionLock(
    session,
    lockKey: kDatabaseMaintenanceLockKey,
    ttl: kDatabaseMaintenanceLockTtl,
    clock: clock,
  );
}
```

**2. Mutual exclusion matrix**

| Caller | Before work | On blocked |
|--------|-------------|------------|
| `BackgroundCollector.collectOnce` | If maintenance lock held → return 0 | No-op (existing pattern) |
| WM maintenance (`maintenanceOnCurrentConnection`) | If collection lock held → skip | `LifecycleRunResult(skipped: true)` |
| WM maintenance | `forMaintenance().tryAcquire()` | skip if false |
| UI compute offload | **Unchanged** this story | — |

Collection and maintenance use **different keys** but **cross-check** the opposing lock — prevents VACUUM during active collect and collect during VACUUM.

**3. Where to wire maintenance lock**

Preferred: `DataLifecycleService._runMaintenanceImpl` when `_maintenanceOnCurrentConnection` is true — single entry for WM path and in-memory tests with that flag.

```dart
// Pseudocode — adapt to actual structure
if (_maintenanceOnCurrentConnection) {
  if (await IngestionCollectionLock.isHeld(_session, kIngestionCollectLockKey, clock: _clock)) {
    return const LifecycleRunResult(skipped: true);
  }
  final lock = IngestionCollectionLock.forMaintenance(_session, clock: _clock);
  if (!await lock.tryAcquire()) {
    return const LifecycleRunResult(skipped: true);
  }
  try {
    return await _session.withRetry((db) => runMaintenanceOnConnection(...));
  } finally {
    await lock.release();
  }
}
```

Pass `AstraDatabaseSession` into `DataLifecycleService` if not already exposed for lock construction — today `_session` field exists (L134).

**4. TTL rationale (AUD2-FR26)**

| Lock | Key | TTL | Reason |
|------|-----|-----|--------|
| Collection | `ingestion_collect_lock` | 35s | Matches `maxCollectionDuration` (25s) + margin |
| Maintenance | `database_maintenance_lock` | 10 min | Downsample + VACUUM on 90-day inject can exceed 35s (`data_lifecycle_service_test.dart` bounded growth uses real VACUUM) |

Use explicit `release()` in `finally` — TTL is crash safety net only (21-4 pattern).

### Current file state (UPDATE — read completely)

**`ingestion_collection_lock.dart`** — Single key hardcoded (`kIngestionCollectLockKey`), 35s default TTL, `tryAcquire`/`release` via `withRetry`. No maintenance variant.

**`data_lifecycle_service.dart`** — `runMaintenanceOnConnection` (L41-59) runs downsample + vacuum with no lock. `_maintenanceInFlight` dedupes **same-isolate** concurrent callers only — not cross-isolate WM vs WM. `_maintenanceOnCurrentConnection` bypasses compute offload (L169-171).

**`workmanager_callback.dart`** — `runDatabaseMaintenanceWorkmanagerTask` opens DB, builds `DataLifecycleService(..., maintenanceOnCurrentConnection: true)`, calls `runMaintenance()`. No lock.

**`background_collector.dart`** — `collectOnce` acquires collection lock only (L74-87). Does not check maintenance lock.

### Preserve (AUD2-NFR8)

| Behaviour | Must remain |
|-----------|-------------|
| UI maintenance via `compute` | No lock wiring required this story; existing offload + ephemeral connection |
| Collection lock TTL/key | Default 35s / `kIngestionCollectLockKey` unchanged |
| `collectOnce` returns 0 on skip | Same semantics for maintenance-blocked path |
| `_maintenanceInFlight` same-isolate dedup | Keep — orthogonal to cross-isolate lock |
| WM task return values | `runDatabaseMaintenanceWorkmanagerTask` still returns `true` on skipped maintenance (not due / lock blocked) unless existing tests expect otherwise — match skip-when-not-due pattern |
| Additive upsert, atomic collect txn (29-3) | Untouched |

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-24: repository-owned transactions | Lock uses preference txn inside `withRetry` — same as 21-4 |
| D-25: injected clock | Pass `TimeProvider` to lock for TTL expiry in tests |
| VACUUM off UI thread | WM path already on background isolate — lock does not move VACUUM to UI |
| Single-writer ingestion | Lock serializes collect vs maintenance; does not add new bucket writers |
| WAL + cross-isolate mutex | Complements 30-2 `busy_timeout` (separate story) |

[Source: `architecture.md` §VACUUM/maintenance · `epics-audits-2.md` guardrails]

### File structure requirements

| File | Action |
|------|--------|
| `lib/core/constants/preference_keys.dart` | Add `kDatabaseMaintenanceLockKey` |
| `lib/core/services/ingestion_collection_lock.dart` | Parameterize key/TTL; `forMaintenance` factory; `isHeld` helper |
| `lib/core/services/data_lifecycle_service.dart` | WM-path lock acquire/release + skip on contention |
| `lib/core/services/background_collector.dart` | Skip collect when maintenance lock held |
| `test/core/services/ingestion_collection_lock_test.dart` | Maintenance key/TTL + `isHeld` |
| `test/core/services/background_collector_test.dart` | Maintenance lock contention case |
| `test/core/services/data_lifecycle_service_test.dart` | Lock skip paths for `maintenanceOnCurrentConnection` |
| `planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md` | Close #2 |
| `planning-artifacts/audits_2/README.md` | Sync P0-08 |

**Do not touch:** `app_database.dart` (30-2), `live_step_monitor.dart`, compaction runner, `StepNormalizer`, version bump.

### Testing requirements

| Command | When |
|---------|------|
| `flutter test test/core/services/ingestion_collection_lock_test.dart` | After Sub-task A/D |
| `flutter test test/core/services/background_collector_test.dart` | After Sub-task C/D |
| `flutter test test/core/services/data_lifecycle_service_test.dart` | After Sub-task B/D |
| `flutter test test/core/services/workmanager_callback_test.dart` | After Sub-task D (regression) |

**Existing tests that must pass without semantic regression:**

- `ingestion_collection_lock_test.dart` — acquire/release/contention/`database_closed` retry (21-4)
- `background_collector_test.dart` — `collectOnce no-ops when ingestion lock is held`
- `data_lifecycle_service_test.dart` — concurrent `runMaintenance`, bounded growth with `maintenanceOnCurrentConnection: true`
- `workmanager_callback_test.dart` — maintenance downsamples when due, skips when not due

**New test scenarios (minimum):**

1. Maintenance lock uses separate preference row from collection lock
2. Collector returns 0 when maintenance lock held (readings not persisted)
3. `DataLifecycleService` with `maintenanceOnCurrentConnection: true` skips when collection lock held
4. Maintenance lock TTL constant > 35s (assert constant, not wall-clock wait)

Do **not** run bare `flutter test` unless Baptiste asks.

### Previous story intelligence (Epic 29)

| Learning | Impact on 30-1 |
|----------|----------------|
| 29-3: per-source txn in `BackgroundCollector._collectOnce` | Collection lock must still wrap full `_collectOnce` — do not shrink lock scope |
| 29-3: `IngestionCollectionLock` still serializes cross-isolate collect | Extend pattern, don't replace |
| 29-4/29-5: compaction + drain paths stable | No changes to those files |
| 21-4: lock via `repository.databaseSession` + `withRetry` | Maintenance lock on same session type in lifecycle service |
| OK commit gate | One commit per sub-task A/B/C/D/E |

[Source: `stories/29-3-atomic-bucket-upsert-and-baseline-commit-per-source.md` · `stories/21-4-route-ingestion-lock-through-session-with-retry.md`]

### Cross-story context (Epic 30)

| Story | Status | Relationship |
|-------|--------|--------------|
| **30-1** | **this story** | Maintenance VACUUM lock — **first in epic** |
| 30-2 | backlog | `PRAGMA busy_timeout` — complementary contention mitigation |
| 30-3 | backlog | iOS WM gap documentation |
| 30-4 | backlog | `TimeProvider` in `_TimeoutBoundedSource` |

After Epic 30: bump patch+1 in `pubspec.yaml` + `README.md`, mark `epic-30: done`.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `e56e5bc` | Epic 29 closed — `0.13.0+32`, persist path stable |
| `841bd5e` | 29-5 calculator unification — unrelated to locks |
| `ee172e6` | 29-4 compaction guard — maintenance calls same downsample path |

Recent work confirms audits_2 sprint active on `main`; Epic 30 starts from stable persist + compaction baseline.

### Latest tech / library notes

- **sqflite ^2.4.2+1** — lock rows in `user_preferences` table; `ConflictAlgorithm.replace` on acquire unchanged from 21-4.
- **No new packages.** Preference-backed mutex is established project pattern.
- **WorkManager** — no plugin API changes; lock is app-layer only.
- **Flutter 3.x `compute`/`Isolate.run`** — UI maintenance path untouched.

### Project context reference

- OK commit gate: sub-tasks A→E, separate commits after Baptiste approval
- Tests: localized `flutter test <path>` per token-economy rule
- Version bump: defer to Epic 30 close (patch+1)
- Communication: French in chat; story in English

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc` · `.cursor/rules/app-versioning.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 30-1, AUD2-FR11, AUD2-FR26]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md` #2, #5]
- [Source: `_bmad-output/planning-artifacts/audits_2/README.md` §P0-08]
- [Source: `lib/core/services/ingestion_collection_lock.dart`]
- [Source: `lib/core/services/data_lifecycle_service.dart`]
- [Source: `lib/core/services/workmanager_callback.dart`]
- [Source: `lib/core/services/background_collector.dart` — collectOnce lock]
- [Source: `stories/21-4-route-ingestion-lock-through-session-with-retry.md`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Sub-task A: generalized `IngestionCollectionLock` with parameterized key/TTL + `forMaintenance` factory + `isHeld` helper
- Sub-task B: WM path in `_runMaintenanceImpl` acquires maintenance lock; skips on collection lock held or acquire failure
- Sub-task C: `BackgroundCollector.collectOnce` returns 0 when maintenance lock held
- Sub-task D: 61 tests pass across 4 test files

### Completion Notes List

- Implemented cross-isolate maintenance mutex (`kDatabaseMaintenanceLockKey`, TTL 10 min) reusing 21-4 preference txn pattern
- Mutual exclusion: WM maintenance skips if collection lock held; collector no-ops if maintenance lock held
- UI `compute` offload path unchanged (AUD2-NFR8)
- Closed diagnostic P0-08 / diagnostic-workmanager-maintenance-db #2

### File List

- `lib/core/constants/preference_keys.dart`
- `lib/core/services/ingestion_collection_lock.dart`
- `lib/core/services/data_lifecycle_service.dart`
- `lib/core/services/background_collector.dart`
- `test/core/services/ingestion_collection_lock_test.dart`
- `test/core/services/background_collector_test.dart`
- `test/core/services/data_lifecycle_service_test.dart`
- `test/core/services/workmanager_callback_test.dart`
- `_bmad-output/planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md`
- `_bmad-output/planning-artifacts/audits_2/README.md`
- `_bmad-output/implementation-artifacts/sprint-status-audits-2.yaml`

### Change Log

- 2026-07-24: Story 30-1 — cross-isolate maintenance lock + mutual exclusion with step collection (Epic 30)
