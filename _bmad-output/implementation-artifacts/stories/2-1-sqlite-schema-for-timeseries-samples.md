# Story 2.1: SQLite Schema for Timeseries Samples

Status: in-progress

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **builder**,
I want the `timeseries_samples` table created with OW-aligned schema and indexes,
So that step buckets can be persisted correctly for charts and export later.

## Acceptance Criteria

1. **Given** Story 1.4 migration v1 exists and currently creates only `user_preferences`
   **When** migration v2 runs on a fresh install
   **Then** `timeseries_samples` is created with canonical columns: `id`, `start_time`, `end_time`, `type`, `value`, `unit`, `resolution`, `provider`, `device_id`, `zone_offset` (FR7)
   **And** v1 defaults in `user_preferences` (`daily_step_goal=8000`, `theme_mode=system`) are still seeded

2. **Given** migration v2 runs
   **When** SQLite schema metadata is inspected
   **Then** `idx_timeseries_query` exists on `(type, start_time DESC)`
   **And** unique index `idx_bucket_identity` exists on `(provider, device_id, type, start_time, end_time, resolution)`

3. **Given** the database connection opens in any isolate
   **When** initialized through `openAstraDatabase()`
   **Then** `PRAGMA journal_mode=WAL` and `PRAGMA foreign_keys=ON` execute explicitly
   **And** the existing file-backed WAL test remains green

4. **Given** step samples will use 5-minute buckets
   **When** insert constraints are exercised in tests
   **Then** `value >= 0` is enforced
   **And** rows where `type='steps'` reject fractional values such as `12.5`
   **And** rows where `type='steps'` accept whole values such as `12` or `12.0`

5. **Given** a user upgrades from schema v1
   **When** migrations run from v1 to v2
   **Then** the existing `user_preferences` rows are preserved without loss
   **And** `timeseries_samples` plus both indexes are added

## Tasks / Subtasks

- [x] **Sub-task A - Add migration v2 DDL** (AC: #1, #2, #4)
  - [x] Update `lib/core/database/migrations.dart`: bump `kDbVersion` from `1` to `2`.
  - [x] Add a `case 2:` migration function, for example `onCreateV2(db)`, called by the existing `runMigrations` loop.
  - [x] Create `timeseries_samples` with exact column names and constraints from PRD/architecture.
  - [x] Create `idx_timeseries_query` and unique `idx_bucket_identity`.
  - [x] Keep `onCreateV1(db)` unchanged except for comments if needed.
  - [x] **Stop -> review brief -> wait for Baptiste OK -> commit**

- [ ] **Sub-task B - Preserve database open behavior** (AC: #3)
  - [x] Review `lib/core/database/app_database.dart`; keep `onConfigure` before migrations and preserve current `rawQuery('PRAGMA journal_mode=WAL')` Android-compatible behavior.
  - [x] Do not introduce a shared static database singleton; WorkManager/UI isolate safety depends on each isolate opening its own handle.
  - [x] Do not add Android manifest WAL metadata in this story unless existing tests prove it is required; current code-level PRAGMA is accepted by architecture.
  - [ ] **Stop -> review brief -> wait for Baptiste OK -> commit**

- [ ] **Sub-task C - Add migration tests** (AC: #1, #2, #4, #5)
  - [ ] Update `test/core/database/migrations_test.dart` so the existing v1 assertions are either renamed to "v2 fresh install" or split into direct `runMigrations(..., targetVersion: 1)` tests where useful.
  - [ ] Test fresh install creates both `user_preferences` and `timeseries_samples`.
  - [ ] Test `user_preferences` default seed values remain present after fresh v2 install.
  - [ ] Test schema columns include all canonical names and `NOT NULL` expectations where inspectable.
  - [ ] Test both indexes exist, and verify `idx_bucket_identity` is unique.
  - [ ] Test constraints with inserts: valid whole-step row succeeds; negative `value` fails; fractional `steps` value fails.
  - [ ] Test v1 -> v2 upgrade preserves a custom `daily_step_goal` and `theme_mode`.
  - [ ] **Stop -> review brief -> wait for Baptiste OK -> commit**

- [ ] **Sub-task D - Verification** (AC: #1-#5)
  - [ ] Run `flutter analyze`.
  - [ ] Run `flutter test test/core/database/migrations_test.dart`.
  - [ ] Run full `flutter test` if the targeted test passes.
  - [ ] In the review brief, explain the fresh-install path and upgrade path separately.
  - [ ] **Stop -> review brief -> wait for Baptiste OK -> commit**

## Dev Notes

### Story scope boundary

**In scope for 2.1:**
- SQLite schema version bump from v1 to v2.
- `timeseries_samples` table DDL.
- Query index and bucket identity unique index.
- Constraint tests for non-negative values and integer-only `steps`.
- Fresh install and v1 -> v2 upgrade migration tests.
- Preserve explicit WAL and foreign key PRAGMAs.

**Out of scope - defer to later stories:**
- `StepRepository` implementation and ingestion upsert method -> Story 2.3.
- `DataIngestionSource`, `PhonePedometerSource`, `AdpBleSource`, and `StepNormalizer` -> Story 2.2.
- `BackgroundCollector`, WorkManager, FGS declarations, and Android 14 health service compliance -> Story 2.4.
- Today dashboard queries/UI -> Story 2.5.
- Dev data inject and lifecycle simulator -> Epic 3 and Epic 4.
- CSV import/export repository methods -> Epic 4.

Do not over-implement. This story establishes schema and migration safety only.

### Current code state

| Path | Current state | What 2.1 changes | Must preserve |
|------|---------------|------------------|---------------|
| `lib/core/database/migrations.dart` | `kDbVersion = 1`; `runMigrations` loops versions; v1 creates `user_preferences` and seeds defaults | Bump to v2; add `timeseries_samples` and indexes in version 2 | v1 idempotency and seeded defaults |
| `lib/core/database/app_database.dart` | `openAstraDatabase()` opens `astra_app.db`; `onConfigure` enables WAL for file DBs and foreign keys for all DBs; `onCreate`/`onUpgrade` delegate to `runMigrations` | Usually no code change required except if migration tests expose an issue | `onConfigure` order, `rawQuery` PRAGMA workaround, no shared singleton |
| `test/core/database/migrations_test.dart` | Covers v1: only `user_preferences`, default seeds, WAL, foreign keys | Expand to v2 fresh install and upgrade tests | Existing WAL/foreign key assertions |
| `test/helpers/sqflite_test_helper.dart` | Initializes sqflite FFI test factory | Reuse as-is | No duplicate FFI setup |

### Canonical DDL

Use this shape unless a test reveals a sqflite/SQLite compatibility issue:

```sql
CREATE TABLE IF NOT EXISTS timeseries_samples (
  id TEXT PRIMARY KEY,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  type TEXT NOT NULL,
  value REAL NOT NULL CHECK (value >= 0),
  unit TEXT NOT NULL,
  resolution TEXT NOT NULL,
  provider TEXT NOT NULL,
  device_id TEXT NOT NULL,
  zone_offset TEXT NOT NULL,
  CHECK (type <> 'steps' OR value = CAST(value AS INTEGER))
);

CREATE INDEX IF NOT EXISTS idx_timeseries_query
  ON timeseries_samples (type, start_time DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_bucket_identity
  ON timeseries_samples (
    provider,
    device_id,
    type,
    start_time,
    end_time,
    resolution
  );
```

Rationale:
- `value` remains `REAL` for future non-step series.
- Phase 0 `type='steps'` rows must be non-negative whole counts.
- Bucket identity intentionally excludes `id` and `zone_offset`; duplicate ingestion for the same provider/device/type/window/resolution must converge on one bucket.
- `zone_offset` remains a per-row immutable value for local-day calculations later.

### Migration pattern

Keep the existing incremental migration loop:

```dart
for (var version = fromVersion + 1; version <= targetVersion; version++) {
  switch (version) {
    case 1:
      await onCreateV1(db);
    case 2:
      await onCreateV2(db);
    default:
      break;
  }
}
```

This matters because fresh install at version 2 must run v1 then v2, while upgrade from v1 must run only v2.

### Test guidance

Recommended test rows:

```dart
const validStepSample = {
  'id': '00000000-0000-4000-8000-000000000001',
  'start_time': '2026-06-02T08:00:00Z',
  'end_time': '2026-06-02T08:05:00Z',
  'type': 'steps',
  'value': 12,
  'unit': 'count',
  'resolution': '5min',
  'provider': 'internal_phone',
  'device_id': 'smartphone',
  'zone_offset': '+02:00',
};
```

Add focused negative cases:
- Same row with `value: -1` throws `DatabaseException`.
- Same row with `value: 12.5` throws `DatabaseException`.
- Duplicate bucket identity with a different `id` throws `DatabaseException` for a raw insert. Later ingestion upsert will intentionally handle this in `StepRepository`.

For upgrade coverage, create a temporary file-backed or in-memory database, run v1, write non-default preferences, then run `runMigrations(db, 2, fromVersion: 1)` or exercise `openDatabase` upgrade if practical. Assert preferences survive and v2 schema exists.

### Architecture compliance

| Decision / invariant | Requirement for 2.1 |
|----------------------|---------------------|
| D-01 | Use SQLite via `sqflite`; no Hive/Isar/remote DB |
| D-02 | `timeseries_samples` plus existing `user_preferences` are the Phase 0 persistence foundation |
| D-06 | Every opened connection explicitly enables WAL and foreign keys |
| D-15 | Numbered migrations from project inception; fresh install and upgrade path tested |
| D-19 | Bucket identity unique index enforces dedupe boundary |
| D-24 | Multi-row writes later belong in repository-owned transactions; no new write API here |
| NFR-9 | Store UTC timestamps and immutable `zone_offset`; no local-day SQL in this story |

### Anti-patterns

- Do not collapse v1 and v2 into one "current schema" function that makes upgrade behavior untestable.
- Do not remove or weaken `user_preferences` seeding from v1.
- Do not compute `local_day` or add a `local_day` column. Architecture requires Dart-side `LocalDayCalculator` later.
- Do not use SQL `date(start_time, zone_offset)` anywhere.
- Do not add `StepRepository` just to satisfy schema tests.
- Do not add ingestion, background collection, WorkManager, or pedometer code.
- Do not add runtime packages.
- Do not store raw sensor waveforms or raw pedometer events.
- Do not use a static shared `Database` across isolates.

### Previous Story Intelligence

From **Story 1.5** (done):
- Review-before-commit remains mandatory: complete one sub-task, post review brief, wait for Baptiste's explicit "OK commit", then commit.
- Current test count was 50 passing after onboarding review fixes; keep unrelated onboarding/theme behavior untouched.
- `AppDependencies` and onboarding gate were hardened recently; this story should not touch app startup unless migration version wiring requires it.
- Recent commits use scoped conventional messages such as `feat(onboarding): ...`, `fix(onboarding): ...`, and `refactor(app): ...`.

From **Story 1.4** (done, inferred from current code):
- `user_preferences` v1 is the established first migration.
- `UserPreferencesRepository` is the only writer to `user_preferences`.
- `openAstraDatabase()` is the central database opener; use it in tests rather than opening ad hoc paths unless testing upgrade mechanics directly.
- WAL is skipped for `inMemoryDatabasePath`; file-backed WAL test covers real journal mode.

### Git Intelligence Summary

Recent commits:

| Commit | Relevance |
|--------|-----------|
| `d478120` | Hardened onboarding/theme foundations; avoid unrelated app/theme edits |
| `253d73c` | Permission error and story 1.5 review fixes; preserve review discipline |
| `2b1634c` | Story documentation moved through review lifecycle |
| `f182c3b` | Added cubit and widget tests; continue focused test expansion |
| `2a5fc9b` | App gate wiring; do not disturb startup path |

### Latest Tech Information

- `sqflite` remains current at `2.4.2+1`, matching `pubspec.yaml`.
- sqflite documents enabling WAL in `onConfigure`; Android can require `rawQuery('PRAGMA journal_mode=WAL')`, which matches current `app_database.dart`.
- SQLite type enforcement is permissive by default. Use explicit `CHECK` constraints and tests for Phase 0 `steps` integer semantics rather than relying on column affinity alone.

### Project Structure Notes

Expected changed files:

```text
lib/core/database/migrations.dart              # UPDATE
test/core/database/migrations_test.dart        # UPDATE
```

Usually read-only / preserve:

```text
lib/core/database/app_database.dart            # VERIFY, avoid unnecessary edits
test/helpers/sqflite_test_helper.dart          # VERIFY, reuse
lib/data/repositories/user_preferences_repository.dart # PRESERVE
```

No new production directories are expected for this story.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` - Story 2.1, FR7/FR8/FR10]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` - §4.3 Local Persistence & Schema, §4.3.1 Canonical Sample Shape]
- [Source: `_bmad-output/planning-artifacts/architecture.md` - Data Architecture, DB initialization PRAGMAs, D-15, D-19]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` - no direct UI scope for 2.1; future Today/History/My Data depend on this schema]
- [Source: `_bmad-output/implementation-artifacts/stories/1-5-trust-first-onboarding-flow.md` - previous story workflow and current repo notes]
- [Source: `lib/core/database/migrations.dart` - current v1 migration]
- [Source: `lib/core/database/app_database.dart` - current database open/PRAGMA behavior]
- [Source: `test/core/database/migrations_test.dart` - existing migration tests]
- [Source: sqflite package docs - WAL via `onConfigure`, current version `2.4.2+1`](https://pub.dev/packages/sqflite)
- [Source: SQLite docs - `CHECK` constraints and type affinity behavior](https://sqlite.org/lang_expr.html)

## Dev Agent Record

### Agent Model Used

GPT-5.5

### Debug Log References

- 2026-06-02: `python3 _bmad/scripts/resolve_customization.py --skill .agents/skills/bmad-dev-story --key workflow` failed because `python3` is not available in the shell; resolved customization manually from skill defaults.
- 2026-06-02: RED phase confirmed with `flutter test test/core/database/migrations_test.dart`; expected failures showed missing `timeseries_samples` table, columns, indexes, and constraints.
- 2026-06-02: GREEN phase passed with `flutter test test/core/database/migrations_test.dart` after adding migration v2 DDL.
- 2026-06-02: Ran `dart format lib/core/database/migrations.dart test/core/database/migrations_test.dart`.
- 2026-06-02: Re-ran `flutter test test/core/database/migrations_test.dart`; all targeted migration tests passed.
- 2026-06-02: Restored `onCreateV1(db)` formatting to keep the v1 migration diff unchanged; re-ran `flutter test test/core/database/migrations_test.dart`; all targeted migration tests passed.
- 2026-06-02: Committed Sub-task A as `5c52e32 feat(database): add timeseries samples migration v2`.
- 2026-06-02: Reviewed `lib/core/database/app_database.dart` for Sub-task B; existing open behavior already satisfies AC #3 and required no code change.

### Completion Notes List

- Sub-task A implementation is ready for review; commit is pending Baptiste approval per the review-before-commit gate.
- Added migration v2 through the existing incremental `runMigrations` loop, preserving `onCreateV1(db)` behavior and user preference seeding.
- Added `timeseries_samples` with canonical Phase 0 columns, non-negative `value` check, integer-only `steps` check, `idx_timeseries_query`, and unique `idx_bucket_identity`.
- Added focused migration tests covering v2 fresh install table creation, default preference seeding, canonical columns, indexes, and step value constraints; v1 direct-target behavior remains covered.
- Sub-task B required no production change: `openAstraDatabase()` still opens a fresh handle per call, runs `onConfigure` before migrations, enables WAL for file-backed databases with `rawQuery`, and enables foreign keys for all database paths.

### File List

- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/stories/2-1-sqlite-schema-for-timeseries-samples.md`
- `lib/core/database/migrations.dart`
- `test/core/database/migrations_test.dart`

## Story Completion Status

- Status: **in-progress**
- Ultimate context engine analysis completed - comprehensive developer guide created
- Sprint status should mark `epic-2` as `in-progress` and `2-1-sqlite-schema-for-timeseries-samples` as `ready-for-dev`.
- Critical guardrail: schema-only story; do not implement repository or ingestion pipeline yet.
