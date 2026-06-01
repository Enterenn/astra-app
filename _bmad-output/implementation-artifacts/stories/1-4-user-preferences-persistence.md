# Story 1.4: User Preferences Persistence

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want my daily step goal and theme preference saved locally,
So that my choices persist across app restarts.

## Acceptance Criteria

1. **Given** migration v1 runs on fresh install
   **When** the database is created
   **Then** only `user_preferences` table exists (key/value) — no `timeseries_samples` yet (database incremental principle)
   **And** defaults are seeded: `daily_step_goal=8000` and `theme_mode=system` (FR9)
   **And** database file is `astra_app.db` under `getDatabasesPath()`

2. **Given** `UserPreferencesRepository` is wired via `AppDependencies`
   **When** a preference is written and the app restarts
   **Then** the stored value is read back correctly (goal integer, theme string)

3. **Given** a preference update occurs
   **When** saved
   **Then** only `UserPreferencesRepository` writes to `user_preferences` — no direct SQL from UI/Cubits

4. **Given** Story 1.2 `ThemeCubit` defaults to `system` in memory
   **When** the app cold-starts after `AppDependencies.create()` completes
   **Then** `ThemeCubit` initial state reflects persisted `theme_mode` from the repository
   **And** `MaterialApp.themeMode` matches before the first frame renders (no incorrect theme flash on restart when user had chosen `light` or `dark`)

5. **Given** every database connection opens (UI isolate for this story)
   **When** initialized
   **Then** `PRAGMA journal_mode=WAL` and `PRAGMA foreign_keys=ON` execute explicitly (Architecture D-06 / FR10 prep)

## Tasks / Subtasks

- [x] **Sub-task A — Database v1 (user_preferences only)** (AC: #1, #5)
  - [x] Create `lib/core/constants/preference_keys.dart` — `kDailyStepGoalKey`, `kThemeModeKey`, `kDefaultStepGoal = 8000`, `kDefaultThemeMode = 'system'`; add `kOnboardingCompleteKey` constant (used by Story 1.5, no UI yet)
  - [x] Create `lib/core/database/migrations.dart` — `const kDbVersion = 1`; `onCreateV1(Database db)` creates **only** `user_preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL)` and seeds defaults via `INSERT OR IGNORE`
  - [x] Create `lib/core/database/app_database.dart` — `Future<Database> openAstraDatabase()` using `join(getDatabasesPath(), 'astra_app.db')`, wires `onCreate`/`onUpgrade`, applies WAL + foreign_keys PRAGMAs after open
  - [x] **Critical:** Do **not** create `timeseries_samples` or indexes in v1 — Story 2.1 adds them in migration v2
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — UserPreferencesRepository** (AC: #2, #3)
  - [x] Create `lib/data/repositories/user_preferences_repository.dart` — sole writer to `user_preferences`
  - [x] Typed API (minimum): `getDailyStepGoal()`, `setDailyStepGoal(int)`, `getThemeMode()` → `AstraThemePreference`, `setThemeMode(AstraThemePreference)`, `getOnboardingComplete()`, `setOnboardingComplete(bool)` (for 1.5; default false when key absent)
  - [x] Parse/validate: goal must be positive integer; theme must be `system`|`light`|`dark` — invalid stored values fall back to defaults (defensive, not user-facing validation)
  - [x] Use parameterized queries (`whereArgs`) — no string-interpolated SQL
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — AppDependencies + startup wiring** (AC: #2, #4)
  - [x] Create `lib/core/di/app_dependencies.dart` — `AppDependencies.create()` async: opens DB, constructs `UserPreferencesRepository`; `AppDependencies.test(...)` factory for tests
  - [x] Update `lib/main.dart` — `WidgetsFlutterBinding.ensureInitialized()` → `await AppDependencies.create()` → `runApp(AstraApp(deps: deps))`
  - [x] Update `lib/app.dart` — accept `AppDependencies deps`; pass repository into `ThemeCubit(initialPreference: ...)` loaded **before** `runApp` (read synchronously from repo after create, or await `getThemeMode()` inside create)
  - [x] Update `ThemeCubit` — constructor accepts optional `AstraThemePreference initialPreference`; **do not** add ThemeSelector UI or public `setThemeMode()` persistence method yet (Story 4.7)
  - [x] Preserve existing shell: `home: const AppScaffold()` — no onboarding gate yet (Story 1.5)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Tests & verification** (AC: #1–#4)
  - [x] Add `sqflite_common_ffi: ^2.4.0+3` to `dev_dependencies` (and `sqlite3: ^3.0.0` if resolver requires — see sqflite_common_ffi troubleshooting)
  - [x] Create `test/helpers/sqflite_test_helper.dart` — `setUpAll` with `sqfliteFfiInit()` + `databaseFactory = databaseFactoryFfi`
  - [x] Create `test/core/database/migrations_test.dart` — fresh v1 creates only `user_preferences`; seeded defaults present; `timeseries_samples` table absent
  - [x] Create `test/data/repositories/user_preferences_repository_test.dart` — write/read round-trip for goal + theme; invalid stored theme falls back to system
  - [x] Update `test/presentation/cubits/theme_cubit_test.dart` — initial preference from constructor
  - [x] Update `test/widget_test.dart` — pump `AstraApp` with `AppDependencies.test(...)` using in-memory DB + seeded repo (not bare `const AstraApp()`)
  - [x] Run `flutter analyze` (zero issues) and `flutter test` (all pass)
  - [x] Manual: change theme in DB (or via temporary debug call), kill app, relaunch → theme persists without flash
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary (critical)

**In scope for 1.4:**
- SQLite database file `astra_app.db` with migration **v1 only**
- `user_preferences` key/value table + default seed rows
- `UserPreferencesRepository` as the **only** writer to preferences
- `AppDependencies` composition root (minimal: DB + preferences repo for now)
- Cold-start theme load into `ThemeCubit` from persisted `theme_mode`
- Unit tests for migration + repository; widget test DI update

**Out of scope — defer to later stories:**
- `timeseries_samples` table, indexes, bucket constraints → **Story 2.1** (migration v2)
- `StepRepository`, ingestion, `BackgroundCollector`, WorkManager → **Epic 2**
- `isolate_database_factory.dart` full WorkManager wiring → **Story 2.4** (create shared `openAstraDatabase()` now; isolate wrapper added when background work lands)
- `ThemeSelector` UI on My Data + `ThemeCubit.setThemeMode()` user flow → **Story 4.7**
- Onboarding flow + completion flag UI → **Story 1.5** (repository API for `onboarding_complete` is in scope; UI is not)
- `TimeProvider`, `LocalDayCalculator` → **Epic 2** (not needed for static preferences)
- `shared_preferences`, Hive, Isar, or any second persistence layer → **forbidden**

Do not over-implement. Story 1.4 ends with **local preference persistence + DI skeleton** — not step data, onboarding screens, or theme picker UI.

### Database incremental principle (non-negotiable)

Epics AC and implementation-readiness report explicitly require:

| Migration | Creates |
|-----------|---------|
| **v1 (this story)** | `user_preferences` only |
| **v2 (Story 2.1)** | `timeseries_samples` + indexes |

Architecture document shows the **full Phase 0 schema** for reference, but **do not copy `timeseries_samples` DDL into v1**. Story 2.1 tests upgrade-from-v1 path (FR10).

### Canonical schema (v1)

```sql
CREATE TABLE IF NOT EXISTS user_preferences (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
-- Seed (INSERT OR IGNORE):
-- daily_step_goal → '8000'
-- theme_mode → 'system'
```

[Source: architecture.md Data Architecture; epics.md Story 1.4; addendum.md §2]

### Preference keys & value encoding

| Key | Value type | Default | Used by |
|-----|------------|---------|---------|
| `daily_step_goal` | integer as string | `8000` | Story 1.5 onboarding, Epic 2 GoalRing, Story 4.6 editor |
| `theme_mode` | `system` \| `light` \| `dark` | `system` | ThemeCubit startup (1.4); ThemeSelector (4.7) |
| `onboarding_complete` | `true` \| `false` | absent = false | Story 1.5 gate |

Future keys (`celebration_shown_date`, permission choices) — define constants when needed; **do not** seed in v1 unless architecture requires.

Map DB strings ↔ `AstraThemePreference` enum (already in `theme_state.dart`):

```dart
AstraThemePreference parseThemeMode(String? raw) => switch (raw) {
  'light' => AstraThemePreference.light,
  'dark' => AstraThemePreference.dark,
  _ => AstraThemePreference.system,
};
```

### Repository pattern (mandatory)

```
UI / Cubit  →  UserPreferencesRepository  →  sqflite Database
                     ↑
              ONLY writer to user_preferences
```

- Cubits **read** via repository methods; they **never** import `sqflite` or execute SQL
- Story 4.7 will call `setThemeMode()` on repository + update `ThemeCubit` state
- Story 1.5 will call `setDailyStepGoal()` + `setOnboardingComplete(true)`

Architecture rule "all SQLite writes through repositories" applies — `StepRepository` owns `timeseries_samples` writes later; `UserPreferencesRepository` owns preference writes now.

### AppDependencies (minimal Phase 0 slice)

Full architecture lists many singletons. **For 1.4, wire only what exists:**

```dart
class AppDependencies {
  const AppDependencies({required this.userPreferences});

  final UserPreferencesRepository userPreferences;

  static Future<AppDependencies> create() async {
    final db = await openAstraDatabase();
    final userPreferences = UserPreferencesRepository(db);
    return AppDependencies(userPreferences: userPreferences);
  }

  static AppDependencies test({
    required UserPreferencesRepository userPreferences,
  }) =>
      AppDependencies(userPreferences: userPreferences);
}
```

Later stories extend this class (TimeProvider, StepRepository, collectors) **without** replacing the pattern. Do not introduce `get_it`, Riverpod, or a service locator.

### Cold-start theme load (avoid flash)

Story 1.2 deferred DB load; FR31 / UX-DR22 require no incorrect theme flash on cold start.

**Recommended flow:**

1. `main()` awaits `AppDependencies.create()`
2. Inside `create()`, after DB open: `final theme = await userPreferences.getThemeMode()`
3. Pass to `AstraApp(deps: deps, initialTheme: theme)` or embed in deps
4. `ThemeCubit(initialPreference: theme)` before first `MaterialApp` build

Do **not** use `FutureBuilder` around the whole app for theme — load completes in `main()` before `runApp`.

### Mandatory dev workflow

Follow [`docs/project-context.md`](../../../docs/project-context.md):

- One commit per sub-task (A, B, C, D) after Baptiste review
- Review brief format required before each commit
- No push unless explicitly requested
- Update `docs/DEPENDENCIES.md` if adding `sqflite_common_ffi` dev dependency

### Current repo state (post Story 1.3)

| Item | State |
|------|-------|
| `lib/main.dart` | Sync `runApp(const AstraApp())` — **replace** with async DI bootstrap |
| `lib/app.dart` | Inline `BlocProvider<ThemeCubit>()` with in-memory default `system` |
| `lib/presentation/cubits/theme_cubit.dart` | No repository dependency; no persistence |
| `lib/core/database/` | **Absent** — create |
| `lib/core/di/` | **Absent** — create |
| `lib/data/repositories/` | **Absent** — create |
| `sqflite` in pubspec | Present (^2.4.2+1) but **unused** in lib/ |
| Tests | 13 passing; no DB tests yet |

### Suggested file tree after 1.4

```
lib/
├── main.dart                              # async bootstrap + AppDependencies
├── app.dart                               # accepts deps, ThemeCubit with loaded preference
├── core/
│   ├── constants/
│   │   └── preference_keys.dart           # NEW
│   ├── database/
│   │   ├── app_database.dart              # NEW — openAstraDatabase()
│   │   └── migrations.dart                # NEW — v1 only
│   └── di/
│       └── app_dependencies.dart          # NEW
├── data/
│   └── repositories/
│       └── user_preferences_repository.dart  # NEW
└── presentation/
    └── cubits/
        ├── theme_cubit.dart               # UPDATE — initialPreference ctor param
        └── theme_state.dart               # unchanged enum

test/
├── helpers/
│   └── sqflite_test_helper.dart           # NEW
├── core/database/
│   └── migrations_test.dart               # NEW
├── data/repositories/
│   └── user_preferences_repository_test.dart  # NEW
├── presentation/cubits/
│   └── theme_cubit_test.dart              # UPDATE
└── widget_test.dart                       # UPDATE — inject test deps
```

### `openAstraDatabase()` pattern (from Architecture)

```dart
Future<Database> openAstraDatabase() async {
  final path = join(await getDatabasesPath(), 'astra_app.db');
  final db = await openDatabase(
    path,
    version: kDbVersion,
    onCreate: (db, version) async {
      await runMigrations(db, version);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      await runMigrations(db, newVersion, fromVersion: oldVersion);
    },
  );
  await db.execute('PRAGMA journal_mode=WAL;');
  await db.execute('PRAGMA foreign_keys = ON;');
  return db;
}
```

Extract migration runner so Story 2.1 adds v2 steps without rewriting open logic.

### Anti-patterns (do not do in 1.4)

- ❌ Create `timeseries_samples` in migration v1
- ❌ Direct `db.insert()` / `db.query()` from Cubits or widgets
- ❌ Use `shared_preferences` or Hive for preferences
- ❌ Static singleton `Database? _instance` shared across isolates (WorkManager story will use factory per isolate)
- ❌ Add ThemeSelector, GoalEditor, or onboarding screens
- ❌ Add `GoRouter`, new state-management packages, or DI frameworks
- ❌ Change `AppScaffold` tab shell behavior from Story 1.3
- ❌ Batch sub-tasks A+B+C+D into one commit
- ❌ Commit without Baptiste review approval

### Epic 1 cross-story context

| Story | Focus | Relation to 1.4 |
|-------|-------|-----------------|
| 1.2 (done) | Tokens, `ThemeCubit`, in-memory `system` default | Enum + `ThemeState` reused; DB load added here |
| 1.3 (done) | Tab shell + placeholders | Unchanged; still direct `AppScaffold` home |
| **1.4** (this) | DB v1 + preferences repo + DI | Enables persistence for theme + goal |
| 1.5 | Onboarding → save goal + `onboarding_complete` | Consumes repository API from 1.4 |

Epic 2 Story 2.1 **depends on** migration v1 existing — preserve `kDbVersion` constant and upgrade path.

### Project Structure Notes

- Aligns with Architecture `lib/core/database/`, `lib/core/di/app_dependencies.dart`, `lib/data/repositories/user_preferences_repository.dart`
- Tests mirror `lib/` under `test/` per naming patterns
- Database file name `astra_app.db` matches D-18 / architecture project naming

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Story 1.4, FR9, FR10]
- [Source: _bmad-output/planning-artifacts/architecture.md — Data Architecture, DI, openAstraDatabase example]
- [Source: _bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/addendum.md — user_preferences DDL]
- [Source: _bmad-output/planning-artifacts/implementation-readiness-report-2026-05-25.md — incremental DB v1/v2 split]
- [Source: _bmad-output/implementation-artifacts/stories/1-3-app-scaffold-and-bottom-navigation.md — shell unchanged]
- [Source: _bmad-output/implementation-artifacts/stories/1-2-design-tokens-and-theme-system.md — ThemeCubit enum mapping]
- [Source: docs/project-context.md — review-before-commit workflow]
- [Source: sqflite_common_ffi testing doc](https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi/doc/testing.md)

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- WAL PRAGMA skipped for `:memory:` paths (in-memory SQLite cannot use WAL; avoids FFI hang in widget tests)
- Widget test DB init moved to `setUpAll` — async sqflite inside `testWidgets` body hung on Windows

### Completion Notes List

- Implemented SQLite v1 with `user_preferences` only; seeded `daily_step_goal=8000` and `theme_mode=system`
- `UserPreferencesRepository` is sole writer; typed get/set for goal, theme, onboarding flag with defensive parse fallbacks
- `AppDependencies.create()` loads persisted theme before `runApp` — no theme flash on cold start
- 25 tests pass; `flutter analyze` zero issues
- Manual persistence check: use `setThemeMode` via repository (Story 4.7 adds UI); cold start reads persisted value into `ThemeCubit`

### File List

- lib/core/constants/preference_keys.dart (new)
- lib/core/database/migrations.dart (new)
- lib/core/database/app_database.dart (new)
- lib/core/di/app_dependencies.dart (new)
- lib/data/repositories/user_preferences_repository.dart (new)
- lib/main.dart (updated)
- lib/app.dart (updated)
- lib/presentation/cubits/theme_cubit.dart (updated)
- test/helpers/sqflite_test_helper.dart (new)
- test/core/database/migrations_test.dart (new)
- test/data/repositories/user_preferences_repository_test.dart (new)
- test/presentation/cubits/theme_cubit_test.dart (updated)
- test/widget_test.dart (updated)
- pubspec.yaml (updated)
- docs/DEPENDENCIES.md (updated)

### Change Log

- 2026-06-01: Story 1.4 — SQLite v1 preferences, repository, DI bootstrap, theme cold-start load, test suite (25 tests)

## Technical Requirements

1. **Migration v1:** `user_preferences` table only; seed `daily_step_goal=8000`, `theme_mode=system`
2. **DB file:** `astra_app.db`; WAL + foreign_keys PRAGMAs on every open
3. **Repository:** `UserPreferencesRepository` — sole writer; typed get/set for goal, theme, onboarding flag
4. **DI:** `AppDependencies.create()` in `main.dart`; pass deps to `AstraApp`
5. **Theme startup:** Load persisted `theme_mode` before first frame; map to `AstraThemePreference`
6. **Shell:** Keep `AppScaffold` as home; no onboarding gate
7. **Tests:** Migration schema assertions + repository round-trip + widget test with test deps
8. **Analyzer:** `flutter analyze` zero issues; `flutter test` all pass

## Architecture Compliance

| Decision | Requirement for 1.4 |
|----------|---------------------|
| D-01 | SQLite via `sqflite ^2.4.2+1` — first real usage in lib/ |
| D-02 | `user_preferences` key/value model per PRD |
| D-15 | Numbered migrations from v1; v2 deferred to Story 2.1 |
| D-06 prep | WAL PRAGMA on open; isolate factory deferred to 2.4 |
| DI | Manual `AppDependencies` — no DI framework |
| Write path | Preferences via `UserPreferencesRepository` only |
| Naming | `snake_case` SQL keys; `kDefaultStepGoal`; `UserPreferencesRepository` |
| State | `ThemeCubit` only — no new Cubits |
| Navigation | Unchanged from 1.3 — no GoRouter |
| Offline | No network; local SQLite only |

## Library & Framework Requirements

| Package | Version | 1.4 action |
|---------|---------|------------|
| sqflite | ^2.4.2+1 | **Use** — open DB, migrations, repository |
| path | ^1.9.1 | **Use** — `join()` for DB path |
| flutter_bloc | ^9.1.1 | **Unchanged** — `ThemeCubit` gets initial state from repo |
| sqflite_common_ffi | ^2.4.0+3 | **Add dev_dependency** — unit/widget DB tests on desktop |
| sqlite3 | ^3.0.0 | **Add dev_dependency if required** by sqflite_common_ffi 2.4 |

**Do NOT add:** `shared_preferences`, Hive, Isar, DI frameworks, new runtime packages.

Document `sqflite_common_ffi` in `docs/DEPENDENCIES.md` (dev/test only).

## File Structure Requirements

| Path | Action |
|------|--------|
| `lib/core/constants/preference_keys.dart` | NEW |
| `lib/core/database/migrations.dart` | NEW |
| `lib/core/database/app_database.dart` | NEW |
| `lib/core/di/app_dependencies.dart` | NEW |
| `lib/data/repositories/user_preferences_repository.dart` | NEW |
| `lib/main.dart` | UPDATE — async bootstrap |
| `lib/app.dart` | UPDATE — accept `AppDependencies` |
| `lib/presentation/cubits/theme_cubit.dart` | UPDATE — `initialPreference` constructor |
| `test/helpers/sqflite_test_helper.dart` | NEW |
| `test/core/database/migrations_test.dart` | NEW |
| `test/data/repositories/user_preferences_repository_test.dart` | NEW |
| `test/presentation/cubits/theme_cubit_test.dart` | UPDATE |
| `test/widget_test.dart` | UPDATE — test DI |
| `pubspec.yaml` | UPDATE — dev_dependencies |
| `docs/DEPENDENCIES.md` | UPDATE — sqflite_common_ffi note |

## Testing Requirements

- **Unit:** `migrations_test.dart` — v1 table list excludes `timeseries_samples`; default rows exist
- **Unit:** `user_preferences_repository_test.dart` — goal/theme round-trip; parse fallbacks; onboarding default false
- **Unit:** `theme_cubit_test.dart` — constructor with `initialPreference: dark` → `ThemeMode.dark`
- **Widget:** `widget_test.dart` — `AppDependencies.test(...)` + in-memory DB; nav shell still works
- **Manual:** Persist non-default theme, force-quit, relaunch — no theme flash
- **Commands:** `flutter analyze` (0 issues), `flutter test` (all pass)
- **Not required:** Migration v1→v2 upgrade test (Story 2.1), isolate/WorkManager DB test (Story 2.4)

## Previous Story Intelligence

From **Story 1.3** (done):

- `AstraApp` → `AppScaffold` home; dev onboarding skip until 1.5 — **preserve**
- Inline `BlocProvider<ThemeCubit>()` in `app.dart` — **refactor** to inject deps, not remove shell
- Review-before-commit: **4 sub-tasks**, Baptiste OK before each commit
- Widget tests use `pumpWidget(const AstraApp())` — **must update** for required `deps` parameter
- `flutter analyze` / `flutter test` must stay clean (13 tests today → will grow)
- Do not touch tab cross-fade, NavigationBar theme, or placeholder copy unless DI wiring requires it

From **Story 1.2** (done):

- `AstraThemePreference` enum values map 1:1 to DB `theme_mode` strings — reuse, do not rename
- Default in-memory `system` before DB existed — now superseded by seeded DB + startup load
- `ThemeCubit` had no `setThemeMode()` — still deferred to Story 4.7
- Token/theming files unchanged except `ThemeCubit` constructor

From **Story 1.1** (done):

- Flutter **3.44.0** / Dart **3.12.0**; package `astra_app`
- `sqflite` already in pubspec but unused — 1.4 is first lib/ usage

## Git Intelligence Summary

Recent commits (Story 1.3):

| Commit | Relevance |
|--------|-----------|
| `074fbdd` | Story 1.3 marked done |
| `7766ade` | Shell hardening — preserve when wiring DI |
| `de800bf` | `app.dart` home → `AppScaffold` — extend, don't revert |
| `20c6a3c` | Test patterns for shell — update widget_test for deps |

**Convention:** `feat(database):`, `feat(prefs):`, `feat(di):`, `test(database):` scoped commits.

## Latest Tech Information

- **sqflite 2.4.x:** Use `openDatabase` with explicit `version`, `onCreate`, `onUpgrade`; call PRAGMAs after open (not only in onCreate) per architecture example
- **Testing:** `sqflite_common_ffi` ^2.4.0+3 with `sqfliteFfiInit()` + `databaseFactory = databaseFactoryFfi` in `setUpAll` enables VM/desktop tests without emulator [sqflite testing doc](https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi/doc/testing.md)
- **sqlite3 v3:** If using sqflite_common_ffi 2.4+, add `sqlite3: ^3.0.0` under dev_dependencies if pub get warns
- **In-memory tests:** Use `inMemoryDatabasePath` via FFI factory for fast repository tests
- **Async main:** `void main() async { WidgetsFlutterBinding.ensureInitialized(); ... }` is standard for pre-runApp DB init
- **No theme flash:** Load preference synchronously after await in `main()` — avoid showing `MaterialApp` until `ThemeCubit` has final initial state

## Project Context Reference

Mandatory for all stories — [`docs/project-context.md`](../../../docs/project-context.md):

- Review-before-commit gate (4 sub-task commits)
- Commit message convention: `type(scope): imperative summary`
- Story file path: `_bmad-output/implementation-artifacts/stories/1-4-user-preferences-persistence.md`
- Update `docs/DEPENDENCIES.md` when adding dev packages

## Story Completion Status

- Status: **review**
- Ultimate context engine analysis completed — comprehensive developer guide created
- Epic 1 status: **in-progress** (stories 1.1–1.3 done; 1.4 next)
- Next story after dev: **1-5-trust-first-onboarding-flow**
- Critical guardrail: migration v1 = `user_preferences` **only** (timeseries in v2)
