# Story 8.1: Daily Goal History Schema and Repository

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want my daily step goal changes recorded with an effective date,
So that historical days keep the goal that applied when I walked them.

## Acceptance Criteria

1. **Given** fresh install or upgrade from DB v2
   **When** migration v3 runs
   **Then** table `daily_goal_effective (effective_from_local_day TEXT PRIMARY KEY, goal INTEGER NOT NULL CHECK (goal > 0))` exists
   **And** one seed row is inserted for today's local day with the current `daily_step_goal` preference value (default 8000 if unset)

2. **Given** `UserPreferencesRepository.getGoalForLocalDay(localDay)`
   **When** called for any local calendar day (`YYYY-MM-DD` string)
   **Then** returns the `goal` from the latest row where `effective_from_local_day ≤ localDay`
   **And** falls back to `kDefaultStepGoal` when no row applies

3. **Given** `UserPreferencesRepository.setDailyStepGoal(goal)` with valid positive integer
   **When** today's local day already has a row in `daily_goal_effective`
   **Then** that row is **updated** to the new goal
   **When** today has no row yet
   **Then** a row is **inserted** with `effective_from_local_day = today`
   **And** `user_preferences.daily_step_goal` cache is kept in sync

4. **Given** unit tests in `test/data/repositories/user_preferences_repository_test.dart` (or dedicated goal history test)
   **When** run
   **Then** cover: seed on migration, same-day update, new-day insert, resolution for past/future days, invalid goal rejected

## Tasks / Subtasks

- [x] **Sub-task A — Migration v3 DDL + seed** (AC: #1)
  - [x] Bump `kDbVersion` from `2` to `3` in `lib/core/database/migrations.dart`.
  - [x] Add `onCreateV3(Database db)` with `daily_goal_effective` table (exact DDL below).
  - [x] Add `case 3:` in `runMigrations` switch.
  - [x] Seed one row: read current `daily_step_goal` from `user_preferences` (fallback `kDefaultStepGoal`), `effective_from_local_day` = today's local `YYYY-MM-DD` (use device-local `DateTime.now()` in migration — acceptable one-time path; not `TimeProvider`).
  - [x] Use `INSERT OR IGNORE` or existence check so re-run/idempotency does not duplicate PK.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Repository goal history API** (AC: #2, #3)
  - [x] Add optional `TimeProvider clock` to `UserPreferencesRepository` (default `SystemTimeProvider()` for production + easy test injection — mirror `StepRepository` pattern).
  - [x] Add `Future<int> getGoalForLocalDay(String localDayIso)` — SQL below.
  - [x] Extend `setDailyStepGoal(int goal)` to upsert today's row in `daily_goal_effective` **and** update `user_preferences` cache (existing `_writeValue` path). Use transaction for atomicity.
  - [x] Keep `getDailyStepGoal()` as cache reader (unchanged semantics for existing callers until Story 8.2).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests** (AC: #1, #2, #3, #4)
  - [x] Extend `test/core/database/migrations_test.dart`: v3 fresh install creates table + seed row; v2→v3 upgrade preserves custom `daily_step_goal` and adds seed row with matching goal.
  - [x] Extend `test/data/repositories/user_preferences_repository_test.dart` (or add `daily_goal_history_test.dart`):
    - Resolution: row on Mon + change on Thu → Mon–Wed use Mon goal, Thu+ use Thu goal
    - Same-day update does not create second row
    - New calendar day insert creates new row (inject fixed `TimeProvider` / fake clock)
    - No row → `kDefaultStepGoal`
    - Invalid goal rejected on write
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Verification** (AC: all)
  - [x] `flutter analyze`
  - [x] `flutter test test/core/database/migrations_test.dart test/data/repositories/user_preferences_repository_test.dart`
  - [x] Full `flutter test` — existing step-ingestion / cubit tests must stay green (no consumer changes in this story)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope (8.1):**
- DB v3 migration + `daily_goal_effective` table
- `getGoalForLocalDay(localDayIso)` repository API
- `setDailyStepGoal` writes history journal + prefs cache
- Migration + repository unit tests

**Out of scope — defer to Story 8.2:**
- `TodayCubit`, `HistoryCubit`, `BackgroundCollector`, celebration, notifications switching to `getGoalForLocalDay`
- UI changes (week dots, chart goal line)
- CSV import/export of goal history
- Version bump (`0.2.1+3` at **Epic 8 close**, not per story)

Do not touch consumer call sites in this story.

### Business context

Epic 8 fixes the **goal retroactivity bug**: a single global `daily_step_goal` pref causes past days to re-evaluate when the user changes their goal (`WeekDayStatus.goalMet`, History goal line, celebration). Effective-dated rows freeze past days; changes apply from **today** forward.

**Approved sprint decision (2026-06-15):** Pre-migration backfill is minimal — seed **one row for today's local day** with current pref. Past days before that effective date resolve via `kDefaultStepGoal` until user changes goal again. Acceptable for solo beta; Story 8.2 consumer migration may surface edge cases — do not expand scope here without correct-course.

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 8.1 changes | Must preserve |
|------|---------------|------------------|---------------|
| `lib/core/database/migrations.dart` | `kDbVersion = 2`; v1 prefs, v2 timeseries | v3 `daily_goal_effective` + seed | v1/v2 idempotency, existing switch structure |
| `lib/core/database/app_database.dart` | Delegates to `runMigrations` | No change unless tests expose issue | WAL PRAGMA, `onConfigure` order |
| `lib/data/repositories/user_preferences_repository.dart` | `get/setDailyStepGoal` → `user_preferences` only | Add `getGoalForLocalDay`, journal upsert in `setDailyStepGoal`, optional `clock` | All other pref methods unchanged; sole writer to prefs table |
| `lib/data/repositories/step_repository.dart` | `purge()` deletes `timeseries_samples` + selected pref keys | **No change** — new table not in purge delete list → survives purge automatically | FR-20 non-health prefs preserved |
| `lib/core/di/app_dependencies.dart` | `UserPreferencesRepository(databaseSession)` | Pass shared `TimeProvider` if constructor extended | DI wiring for other deps |
| `test/core/database/migrations_test.dart` | v1, v2 fresh + upgrade | Add v3 groups | Existing assertions stay green |

### Canonical DDL

```sql
CREATE TABLE IF NOT EXISTS daily_goal_effective (
  effective_from_local_day TEXT PRIMARY KEY,
  goal INTEGER NOT NULL CHECK (goal > 0)
);
```

No extra index required for Phase 0 volume (≤ few dozen rows lifetime).

### Resolution query (repository)

```sql
SELECT goal
FROM daily_goal_effective
WHERE effective_from_local_day <= ?
ORDER BY effective_from_local_day DESC
LIMIT 1
```

`localDayIso` and stored keys are lexicographically sortable `YYYY-MM-DD` strings — same convention as `formatLocalDayIso`, celebration dedup keys, etc.

### Write semantics (`setDailyStepGoal`)

1. Validate `goal > 0` (existing `ArgumentError`).
2. Compute `todayIso = formatLocalDayIso(clock.snapshot())`.
3. In one transaction:
   - If row exists for `todayIso` → `UPDATE goal`
   - Else → `INSERT (todayIso, goal)`
   - Upsert `user_preferences.daily_step_goal` cache (existing `_writeValue`)

**New calendar day:** first goal write of the day inserts a new effective row (even if goal unchanged from yesterday — journal records continuity). Do not update yesterday's row.

### Time semantics

- **Today** for writes: `formatLocalDayIso(clock.snapshot())` — uses `TimeSnapshot.zoneOffset`, not raw `DateTime.now()` in repository code.
- **Migration seed:** one-time upgrade may use device-local date from `DateTime.now()` (migrations have no injected clock). Document in review brief.
- **Local day strings:** align with `LocalDayCalculator` / `StepRepository` — never compare using device timezone for stored bucket rows; goal journal uses plain calendar ISO strings.

### Purge / lifecycle

`StepRepository.purge()` does **not** delete `daily_goal_effective`. Goal history survives health-data purge (Epic 10 Story 10.8 AC). No purge changes in 8.1.

### Architecture compliance

- **D-03:** `UserPreferencesRepository` remains sole writer to `user_preferences`; sole writer to `daily_goal_effective` in this story.
- **D-15:** Numbered migrations via `runMigrations`; bump `kDbVersion`.
- **NFR-9:** Goal journal keyed by local calendar day ISO; independent of per-row `zone_offset` in timeseries (goal is user intent, not sensor event).
- **Review gate:** One commit per sub-task after Baptiste OK — see `docs/project-context.md` § Development Workflow.

### File structure requirements

| Action | Path |
|--------|------|
| MODIFY | `lib/core/database/migrations.dart` |
| MODIFY | `lib/data/repositories/user_preferences_repository.dart` |
| MODIFY | `lib/core/di/app_dependencies.dart` (if clock wired) |
| MODIFY | `test/core/database/migrations_test.dart` |
| MODIFY | `test/data/repositories/user_preferences_repository_test.dart` |
| OPTIONAL | `lib/core/constants/preference_keys.dart` — table name constant only if it aids clarity |

Do **not** add new packages. Use existing `sqflite` transaction patterns from repository (`_session.withRetry`).

### Testing requirements

- Reuse `test/helpers/sqflite_test_helper.dart` + `openAstraDatabase`.
- For day-boundary tests: inject `FakeTimeProvider` or existing test clock helper (grep `TimeProvider` in `test/`).
- Migration v2→v3: file-backed DB pattern from existing `migration v1 to v2 upgrade` test.
- Run full suite before final sub-task — zero consumer changes means regressions would indicate accidental API breakage.

### Previous story intelligence

Epic 7 closed at `0.2.0+2` with CI green. Recent commits: stale data banners, dead-code cleanup, versioning policy docs. **Story 2.1** established migration patterns (bump version, `onCreateVN`, upgrade tests, review-per-sub-task). Follow identical migration test structure.

No prior story in Epic 8 — Epic 8 starts here.

### Git intelligence

Recent work touched `my_data_cubit`, `history_cubit`, `background_collector`, tests — all still use `getDailyStepGoal()`. **Do not modify** those files in 8.1.

### Latest tech information

- **sqflite ^2.4.2+1** (locked in architecture) — `CHECK` constraints and `INSERT OR REPLACE` supported on Android SQLite.
- **Flutter 3.x / Dart 3** — use existing `switch` migration loop style in `migrations.dart`.
- No new dependencies; no web research required.

### Project context reference

- Versioning: patch bump at Epic 8 **close** → `0.2.1+3` (not this story)
- Commit convention: `feat(database): …` / `feat(prefs): …`
- `docs/project-context.md` — review-before-commit workflow mandatory

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` § Epic 8 Story 8.1]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` § 4.1 Data model]
- [Source: `_bmad-output/planning-artifacts/architecture.md` § Data Architecture, D-15 migrations]
- [Source: `lib/core/database/migrations.dart` — current v2 schema]
- [Source: `lib/data/repositories/user_preferences_repository.dart` — sole prefs writer]
- [Source: `lib/core/time/local_day_formatter.dart` — `formatLocalDayIso`]
- [Source: `_bmad-output/implementation-artifacts/stories/2-1-sqlite-schema-for-timeseries-samples.md` — migration story template]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- Sub-task A committed (`b098aab`): migration v3 + `daily_goal_effective` table + seed row.
- Sub-task B committed (`0f17454`): `getGoalForLocalDay`, journal upsert in `setDailyStepGoal`, shared `TimeProvider` in DI.
- Sub-task C committed (`663de12`): migration v3 + goal history repository tests (47 targeted, 643 full suite green).
- Sub-task D verified: `flutter analyze` 0 errors; full `flutter test` 643 pass / 2 skip; no consumer call sites changed.
- Code review (2026-06-15): migration seed uses `formatLocalDayIso`; journal/cache sync tests added; story marked done.

### Review Findings

- [x] [Review][Patch] Migration seed date uses `formatLocalDayIso` instead of hand-rolled formatting [`migrations.dart:115`] — fixed
- [x] [Review][Patch] Tests assert journal row + `getGoalForLocalDay(today)` sync with prefs cache — fixed
- [x] [Review][Defer] First-of-day concurrent `setDailyStepGoal` PK race — deferred, solo beta acceptable
- [x] [Review][Defer] `getGoalForLocalDay` input format validation — deferred to Story 8.2 internal callers

### File List

- `lib/core/database/migrations.dart`
- `lib/data/repositories/user_preferences_repository.dart`
- `lib/core/di/app_dependencies.dart`
- `test/core/database/migrations_test.dart`
- `test/data/repositories/user_preferences_repository_test.dart`

## Change Log

- 2026-06-15: Story 8.1 implementation complete — DB v3 goal history journal, repository API, tests (4 commits: b098aab, 0f17454, 663de12 + verification gate).
- 2026-06-15: Code review fixes — unified migration date formatting, journal/cache sync tests; story done.
