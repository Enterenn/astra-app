# Story 32.4: Single Goal Source and Safe Database Open Check

Status: review

<!-- audits_2 Epic 32 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 32-4 · diagnostic-preferences-utilisateur.md #1, #2 · AUD2-FR19 · AUD2-FR20 · AUD2-FR32 -->
<!-- Prerequisite: Story 32-3 done · Epic 29–31 delivered -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want my daily goal and live pipeline to read one authoritative value,
So that My Data and Today never disagree after refresh.

## Acceptance Criteria

1. **Given** My Data goal display on refresh
   **When** goal is loaded
   **Then** it uses `getGoalForLocalDay(todayIso)` not legacy `getDailyStepGoal()` — AUD2-FR19
   **And** `getDailyStepGoal()` is deprecated or removed from production call paths

2. **Given** `UserSettingsRepository.isDatabaseOpen` / KV store guard
   **When** database is null or closed
   **Then** predicate returns `false` without throwing — AUD2-FR20
   **And** `today_live_pipeline.dart` guard works as intended

3. **Given** goal architecture
   **When** documented
   **Then** single-writer contract (`setDailyStepGoal` → journal + prefs txn) is documented — AUD2-FR32

**Covers:** AUD2-FR19 · AUD2-FR20 · AUD2-FR32 · diagnostic-preferences-utilisateur.md #1, #2 · audits_2/README.md M4, M5, D3

**Depends on:** Story 32-3 (orthogonal — no file conflict)

**Out of scope:**
- Test hook / migration v3 clock (32-5)
- Changing `setDailyStepGoal` write semantics (txn already atomic — preserve)
- Removing `user_preferences.daily_step_goal` column (cache kept for migration v3 seed + purge allowlist D-11)
- `pubspec.yaml` version bump (Epic 32 close = patch+1)

## Tasks / Subtasks

- [x] **Sub-task A — My Data refresh loads journal goal** (AC: #1)
  - [x] Read fully: `lib/presentation/cubits/my_data_cubit.dart` — `_refreshImpl`, `_emitReadySnapshot`, `updateDailyStepGoal`
  - [x] In `_refreshImpl`, add `userHealthMetrics.getGoalForLocalDay(formatLocalDayIso(clock.snapshot()))` to the existing `Future.wait` (alongside footprint, last ingestion, permission, last optimized)
  - [x] Pass resolved goal into `_emitReadySnapshot(dailyStepGoal: …)` so refresh **replaces** stale state (not only `?? state.dailyStepGoal` fallback on missing param)
  - [x] Import `formatLocalDayIso` from `lib/core/time/local_day_formatter.dart` if not already present
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Regression test: refresh vs journal authority** (AC: #1)
  - [x] Create `test/presentation/cubits/my_data_cubit_goal_refresh_test.dart` (or extend nearest cubit test file if pattern fits):
    - Seed in-memory DB via `UserHealthMetricsRepository.setDailyStepGoal(8000)` then **direct SQL** update `daily_goal_effective.goal` to `12000` **without** updating prefs cache (simulates partial-write / legacy drift)
    - Construct `MyDataCubit` with real repos + `FakeTimeProvider` pinned to same local day
    - `await cubit.refresh()` → expect `state.dailyStepGoal == 12000` (journal wins)
  - [x] Run: `flutter test test/presentation/cubits/my_data_cubit_goal_refresh_test.dart`
  - [x] Run: `flutter test --tags critical`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Deprecate legacy `getDailyStepGoal()`** (AC: #1)
  - [x] Read fully: `lib/data/repositories/user_health_metrics_repository.dart` L30-37
  - [x] Add `@Deprecated('Use getGoalForLocalDay with today local-day ISO')` on concrete `getDailyStepGoal()` (method stays for test/migration introspection only — **not** on `UserHealthMetricsRepositoryContract`, which already omits it)
  - [x] Grep `lib/` — confirm zero production callers (expected today)
  - [x] Optionally migrate repository tests that assert via `getDailyStepGoal()` to `getGoalForLocalDay(todayIso)` where the test subject is display/comparison semantics; keep **one** test asserting prefs cache still written by `setDailyStepGoal` txn if useful
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Safe `isDatabaseOpen` predicate** (AC: #2)
  - [x] Read fully: `lib/core/database/astra_database_session.dart`, `lib/data/repositories/_user_preferences_kv_store.dart`, `lib/data/repositories/user_settings_repository.dart`, `lib/presentation/cubits/today/today_live_pipeline.dart` L194-208
  - [x] Add non-throwing session probe on `AstraDatabaseSession`:
    ```dart
    bool get isOpen {
      final db = _db;
      return db != null && db.isOpen;
    }
    ```
    Do **not** route through throwing `database` getter
  - [x] Change KV store: `bool get isDatabaseOpen => _session.isOpen;`
  - [x] `UserSettingsRepository.isDatabaseOpen` unchanged (delegates to KV)
  - [x] Verify `recordLastDisplayedSteps` early-return path: when session closed, no throw, no persist attempt
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Tests for safe `isDatabaseOpen`** (AC: #2)
  - [x] Add `test/data/repositories/user_preferences_kv_store_test.dart` (or extend existing prefs test):
    - Open in-memory DB → `isDatabaseOpen == true`
    - `await db.close()` → `isDatabaseOpen == false` (no throw)
    - Fresh `AstraDatabaseSession(databasePath: …)` with `_db == null` → `isDatabaseOpen == false`
  - [x] Optional targeted: `today_live_pipeline` / `TodayCubit` test that `recordLastDisplayedSteps` is no-op when DB closed (mock `UserSettingsRepositoryContract` with `isDatabaseOpen => false` already exists in lifecycle tests — extend if gap)
  - [x] Run targeted file + `flutter test --tags critical`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task F — Document single-writer contract + close diagnostic** (AC: #3)
  - [x] Update `diagnostic-preferences-utilisateur.md`:
    - #1 → `fixed` (32-4) — My Data refresh via journal; `getDailyStepGoal` deprecated
    - #2 → `fixed` (32-4) — safe `isDatabaseOpen`
    - Refresh synthèse table + statut global if all items fixed
  - [x] Sync `audits_2/README.md`: diagnostic 06 row → `fixed` or `partial`→`fixed`; M4, M5, D3 rows marked done (32-4)
  - [x] Add short **Daily goal storage** subsection to `docs/project-context.md`:
    - **Read path (display/comparison):** `getGoalForLocalDay(localDayIso)` — journal `daily_goal_effective`
    - **Write path (single writer):** `setDailyStepGoal` txn → journal row for today + prefs cache `daily_step_goal`
    - **Prefs cache role:** migration v3 seed, purge allowlist (D-11), not authoritative for display after refresh
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

**Dual read paths — journal vs prefs cache:**

| Store | Location | Reader today | Role |
|-------|----------|--------------|------|
| Journal | `daily_goal_effective` | `getGoalForLocalDay` / `getGoalsForLocalDays` | Authoritative per local day (Story 8-1/8-2) |
| Prefs cache | `user_preferences.daily_step_goal` | `getDailyStepGoal()` (concrete only) | Legacy cache; still written atomically by `setDailyStepGoal` |

**Production readers already use journal:** Today (`today_refresh_service.dart`, `today_snapshot_applier.dart`), History (`history_cubit.dart`), BackgroundCollector (`background_collector.dart`).

**My Data gap:** `_refreshImpl` never loads goal — `_emitReadySnapshot` preserves `state.dailyStepGoal` (defaults to `kDefaultStepGoal` from `MyDataState`). After app restart or silent refresh, editor can show default/stale value while Today ring uses journal.

```530:580:lib/presentation/cubits/my_data_cubit.dart
  Future<void> _refreshImpl({required bool silent}) async {
    // ...
      final results = await Future.wait<Object?>([
        stepAggregation.getFootprint(databasePath: databasePath),
        stepAggregation.getLastIngestionUtc(),
        _activityPermissionGranted(),
        userSettings.getLastDatabaseOptimizedAt(),
      ]);
    // ...
      _emitReadySnapshot(
        // dailyStepGoal not passed → keeps prior state
```

```644:644:lib/presentation/cubits/my_data_cubit.dart
        dailyStepGoal: dailyStepGoal ?? state.dailyStepGoal,
```

**`getDailyStepGoal()` in lib/:** Defined only on concrete `UserHealthMetricsRepository` — **zero call sites in `lib/`** (verified). Remaining usages: tests + story docs.

[Source: `diagnostic-preferences-utilisateur.md` #1 · AUD2-FR19]

---

**`isDatabaseOpen` throws instead of returning false:**

```13:13:lib/data/repositories/_user_preferences_kv_store.dart
  bool get isDatabaseOpen => _session.database.isOpen;
```

```20:25:lib/core/database/astra_database_session.dart
  Database get database {
    final db = _db;
    if (db == null || !db.isOpen) {
      throw StateError('Database is not open');
    }
```

**Impact:** `today_live_pipeline.dart:198` — `if (!userSettings.isDatabaseOpen) return;` throws **before** the guard when DB is null/closed during teardown or race with isolate close.

```194:208:lib/presentation/cubits/today/today_live_pipeline.dart
  Future<void> recordLastDisplayedSteps(int steps) async {
    // ...
    if (!userSettings.isDatabaseOpen) return;
```

[Source: `diagnostic-preferences-utilisateur.md` #2 · AUD2-FR20]

### Recommended implementation

**A — My Data refresh (minimal diff):**

```dart
final todayIso = formatLocalDayIso(clock.snapshot());
final results = await Future.wait<Object?>([
  stepAggregation.getFootprint(databasePath: databasePath),
  stepAggregation.getLastIngestionUtc(),
  _activityPermissionGranted(),
  userSettings.getLastDatabaseOptimizedAt(),
  userHealthMetrics.getGoalForLocalDay(todayIso),
]);
// ...
final dailyStepGoal = results[4]! as int;
_emitReadySnapshot(
  // ...
  dailyStepGoal: dailyStepGoal,
);
```

`updateDailyStepGoal` already calls `setDailyStepGoal` then `emit(copyWith(dailyStepGoal: parsed))` — no change needed for edit flow. Refresh after import/purge/resume will now reconcile display with journal.

**C — Deprecation:** `@Deprecated` on concrete method only. Do not add to contract. Tests may keep calling deprecated method for prefs-cache assertions or migrate to journal reads.

**D — Safe open:** Prefer `AstraDatabaseSession.isOpen` (new) over try/catch around throwing getter — keeps predicate O(1) and explicit.

**Do NOT:**
- Remove `daily_step_goal` prefs key (purge allowlist D-11, v3 migration seed)
- Change `setDailyStepGoal` txn shape (journal + prefs must stay atomic)
- Use `getDailyStepGoal()` in any new `lib/` code path
- Rename `isDatabaseOpen` on contract (breaking); fix semantics in place per epic

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-03 / single writer | Only `UserHealthMetricsRepository.setDailyStepGoal` writes goal; document prefs vs journal roles (AUD2-FR32) |
| Story 8-2 | Today/History/Collector already on `getGoalForLocalDay` — My Data must align |
| D-11 purge | `daily_step_goal` prefs row preserved on purge — cache remains valid after purge |
| D-24 txn | `setDailyStepGoal` journal+prefs txn unchanged |
| Agent tests | `flutter test --tags critical` after changes; targeted cubit/repo files |
| OK commit gate | Sub-tasks A→F with separate commits |

[Source: `architecture.md` · Story 8-1/8-2 · `docs/project-context.md`]

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/cubits/my_data_cubit.dart` | **UPDATE** — refresh loads journal goal |
| `lib/data/repositories/user_health_metrics_repository.dart` | **UPDATE** — `@Deprecated` on `getDailyStepGoal` |
| `lib/core/database/astra_database_session.dart` | **UPDATE** — add safe `isOpen` getter |
| `lib/data/repositories/_user_preferences_kv_store.dart` | **UPDATE** — `isDatabaseOpen` → `_session.isOpen` |
| `lib/data/repositories/user_settings_repository.dart` | **VERIFY** — delegate unchanged |
| `lib/presentation/cubits/today/today_live_pipeline.dart` | **VERIFY** — guard works post-fix (likely no code change) |
| `test/presentation/cubits/my_data_cubit_goal_refresh_test.dart` | **NEW** — journal authority on refresh |
| `test/data/repositories/user_preferences_kv_store_test.dart` | **NEW** (or extend) — safe open predicate |
| `test/data/repositories/user_health_metrics_repository_test.dart` | **UPDATE** (optional) — migrate deprecated calls |
| `docs/project-context.md` | **UPDATE** — Daily goal storage subsection |
| `planning-artifacts/audits_2/diagnostic-preferences-utilisateur.md` | Close #1, #2 |
| `planning-artifacts/audits_2/README.md` | Sync M4, M5, D3, diag 06 |

**Do not touch:** `migrations.dart` v3 seed (32-5 owns injectable clock), onboarding goal save (already uses `setDailyStepGoal`), Today/History goal resolution (already correct).

### Testing requirements

| Verify | Command |
|--------|---------|
| My Data cubit goal refresh | `flutter test test/presentation/cubits/my_data_cubit_goal_refresh_test.dart` |
| KV safe open | `flutter test test/data/repositories/user_preferences_kv_store_test.dart` |
| Critical gate | `flutter test --tags critical` |
| Repo regression (if touched) | `flutter test test/data/repositories/user_health_metrics_repository_test.dart` |

Do **not** run bare `flutter test`.

**Regression focus:**
- Existing My Data export/import/purge tests must stay green (refresh signature change only adds parallel read)
- `recordLastDisplayedSteps` must not throw during app teardown / closed DB
- Today ring goal unchanged (already journal-based) — smoke via critical tags

### Previous story intelligence

| Learning | Impact on 32-4 |
|----------|----------------|
| 32-3: Path A disclaimer done; Footprint UI additive | Orthogonal — no My Data goal section conflict |
| 32-3: OK commit gate A→F pattern | Mirror sub-task commits |
| 32-3: diagnostic + README sync on close | Mirror in sub-task F |
| 32-2/32-1: tracker = `sprint-status-audits-2.yaml` | Same sprint file |
| 8-2: journal is comparison source of truth | My Data was the missing consumer |
| 15-2: `isDatabaseOpen` guard pattern in Today cubit | Same predicate fix benefits GoalRing persist path |

[Source: `stories/32-3-privacy-at-rest-product-decision.md` · `stories/8-2-goal-history-consumer-migration.md`]

### Cross-story context (Epic 32)

| Story | Status | Relationship |
|-------|--------|--------------|
| 32-1 | done | ID alignment — orthogonal |
| 32-2 | done | Dev guard — orthogonal |
| 32-3 | done | Privacy disclaimer — orthogonal |
| **32-4** | **this story** | Goal single source + safe DB open |
| 32-5 | backlog | Test hook + migration v3 clock |

**Epic 32 close after 32-5:** bump `pubspec.yaml` patch+1 + `README.md` per sprint tracker.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `3cf74fe` | Story 32-3 done — latest Epic 32 |
| `c155690` | 32-3 implementation pattern |
| `c45260e` / `41e748f` | 32-2 — diagnostic close + targeted tests |
| `384ce70` | 32-1 — P0 row sync pattern |

Active branch `main`; tracker `sprint-status-audits-2.yaml`; base `0.14.0+34`.

### Latest tech / library notes

- **sqflite `Database.isOpen`:** Standard sqflite API — safe to read on closed handle returns `false`; null `_db` must be handled explicitly (this fix).
- **No new packages** for this story.
- **`@Deprecated` in Dart 3.12:** Analyzer warns on new call sites; existing test calls may suppress or migrate incrementally.

### Project context reference

- OK commit gate: sub-tasks with separate commits after Baptiste approval
- Tests: targeted file + `flutter test --tags critical`
- Version bump: Epic 32 close — not per story
- Chat French; story/doc English per BMAD config

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc` · `.cursor/rules/app-versioning.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 32-4, AUD2-FR19, AUD2-FR20, AUD2-FR32]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-preferences-utilisateur.md` #1, #2]
- [Source: `_bmad-output/planning-artifacts/audits_2/README.md` M4, M5, D3, diagnostic 06]
- [Source: `_bmad-output/planning-artifacts/implementation-readiness-report-2026-07-24.md` FR-9 → E32-4]
- [Source: `lib/presentation/cubits/my_data_cubit.dart`]
- [Source: `lib/data/repositories/user_health_metrics_repository.dart`]
- [Source: `lib/core/database/astra_database_session.dart`]
- [Source: `lib/data/repositories/_user_preferences_kv_store.dart`]
- [Source: `lib/presentation/cubits/today/today_live_pipeline.dart`]
- [Source: `_bmad-output/implementation-artifacts/stories/8-2-goal-history-consumer-migration.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/32-3-privacy-at-rest-product-decision.md`]

## Dev Agent Record

### Agent Model Used

Composer (create-story) · Composer (dev-story)

### Debug Log References

- Sub-task A committed: `61ac06f`
- Sub-tasks B–F committed: `aead860` B · `63a6c05` C · `7d9296c` D · `3b7da46` E · pending F

### Completion Notes List

- ✅ A: My Data `_refreshImpl` loads journal goal via `getGoalForLocalDay(todayIso)`
- ✅ B: `my_data_cubit_goal_refresh_test.dart` — journal wins over drifted prefs cache on refresh
- ✅ C: `@Deprecated` on concrete `getDailyStepGoal()`; zero `lib/` callers
- ✅ D: `AstraDatabaseSession.isOpen` + KV `isDatabaseOpen` safe predicate
- ✅ E: `user_preferences_kv_store_test.dart` — open/closed/null session cases
- ✅ F: diagnostic 06 closed; README M4/M5/D3 done; `project-context.md` Daily goal storage

### File List

- `lib/core/database/astra_database_session.dart`
- `lib/data/repositories/_user_preferences_kv_store.dart`
- `lib/data/repositories/user_health_metrics_repository.dart`
- `test/presentation/cubits/my_data_cubit_goal_refresh_test.dart` (new)
- `test/data/repositories/user_preferences_kv_store_test.dart` (new)
- `_bmad-output/planning-artifacts/audits_2/diagnostic-preferences-utilisateur.md`
- `_bmad-output/planning-artifacts/audits_2/README.md`
- `docs/project-context.md`

## Change Log

- 2026-07-25: Story 32-4 created — single goal source (My Data journal read) + safe `isDatabaseOpen` + single-writer documentation
- 2026-07-25: Sub-task A committed — My Data refresh journal goal
- 2026-07-25: Sub-tasks B–F committed — tests, safe open, deprecation, docs
