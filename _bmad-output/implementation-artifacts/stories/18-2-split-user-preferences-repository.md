# Story 18.2: Split UserPreferencesRepository

Status: review

<!-- Refacto Epic 18 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 18-2 · refactoring-audit-master-v0.6.1.md §1.2c · REF-18 -->
<!-- Prerequisite: Story 18-1 done · Story 16-1 contracts · Story 15-2 GoalRing display in TodayCubit -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **developer**,
I want preferences split by domain,
So that each repository has a single responsibility.

## Acceptance Criteria

1. **Given** `UserPreferencesRepository` (~478 lines at story creation)  
   **When** split  
   **Then** creates (REF-18):
   - `UserSettingsRepository`: theme, accent, units, notifications, onboarding, celebration dedup, goal-notification dedup, DB maintenance timestamps, **and** GoalRing display-step persistence (`lastDisplayedSteps`)
   - `UserHealthMetricsRepository`: display name, height, weight, daily step goal APIs (`getDailyStepGoal`, `getGoalForLocalDay`, `getGoalsForLocalDays`, `setDailyStepGoal`)

2. **Given** shared SQLite storage (`user_preferences` table + `daily_goal_effective` journal)  
   **When** split  
   **Then** both repositories share the same `AstraDatabaseSession` / `Database` instance (single writer per table, no schema change)  
   **And** KV helpers (`_readValue`, `_writeValue`, `_deleteValue`) are extracted once — no duplicated session logic

3. **Given** Story 16-1 `UserPreferencesRepositoryContract`  
   **When** contracts are updated  
   **Then** split into `UserSettingsRepositoryContract` and `UserHealthMetricsRepositoryContract` in `lib/data/contracts/`  
   **And** method placement matches repository boundaries (see Dev Notes — method inventory)  
   **And** cubits depend on the **minimal** contract(s) they need — not the monolithic prefs API

4. **Given** `getLastDisplayedSteps` / `setLastDisplayedSteps` / `clearLastDisplayedSteps`  
   **When** Story 15-2 already moved display **state** to `TodayCubit`/`TodayState`  
   **Then** methods live on `UserSettingsRepository` only (UI display persistence — not health metrics)  
   **And** **no presentation widget** imports or calls these methods directly (only `TodayCubit` + `AppScaffold.postPurgeRefresh` clear)  
   **And** monolithic `UserPreferencesRepository` class is **removed** (not kept as a facade)

5. **Given** `AppDependencies`  
   **When** wired  
   **Then** exposes `userSettings: UserSettingsRepository` and `userHealthMetrics: UserHealthMetricsRepository`  
   **And** **`userPreferences` field is removed** — all call sites updated to the appropriate split repo  
   **And** cold-start bootstrap in `create()` / `test()` reads theme/accent/units/onboarding from `userSettings`

6. **Given** all services and cubits  
   **When** updated  
   **Then** inject the appropriate repository with **no user-visible behaviour change**  
   **And** `BackgroundCollector.maybeNotifyGoalReachedIfGoalMet` receives both repos it needs (settings for notification prefs/dedup, health for `getGoalForLocalDay`)

7. **Given** repository tests  
   **When** run  
   **Then** split into `test/data/repositories/user_settings_repository_test.dart` and `user_health_metrics_repository_test.dart` mirroring boundaries  
   **And** migrated tests preserve all existing assertions from `user_preferences_repository_test.dart`

8. **Given** `flutter test --exclude-tags slow`  
   **When** run after changes  
   **Then** all tests pass including cubit contract tests (`today_cubit_contract_test.dart`)

9. **Given** work completes on branch `refacto`  
   **When** story is marked done  
   **Then** **no version bump** yet — Epic 18 closes with **minor+1, patch=0, build+1** → `0.8.0+17` when all 18-x stories are done

**Covers:** REF-18 · Audit §1.2c · Unblocks Epic 19 locale in `UserSettingsRepository`

**Depends on:** Stories 16-1 (contracts), 15-2 (display state in cubit), 18-1 (coordinator extraction — no conflicting prefs work).

**Out of scope:** Splitting `StepRepository` (18-3), locale/i18n keys (Epic 19), changing GoalRing animation semantics, schema migrations, `mocktail`/`mockito` adoption.

## Tasks / Subtasks

- [x] **Sub-task A — Design split + shared KV base** (AC: #1, #2, #3)
  - [x] Read `lib/data/repositories/user_preferences_repository.dart` **fully** (478 lines) before editing — map every public method to Settings vs Health
  - [x] Read `lib/data/contracts/user_preferences_repository_contract.dart` and grep all `userPreferences.` call sites in `lib/` and `test/`
  - [x] Design shared internal helper (e.g. `_UserPreferencesKeyValueStore` or private base class) holding `_session`, `_readValue`, `_writeValue`, `_deleteValue`
  - [x] Design `UserSettingsRepositoryContract` + `UserHealthMetricsRepositoryContract` method lists (Dev Notes inventory)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Create split repositories + contracts** (AC: #1, #2, #4)
  - [x] Create `lib/data/repositories/user_settings_repository.dart`
  - [x] Create `lib/data/repositories/user_health_metrics_repository.dart`
  - [x] Move methods mechanically — preserve validation, transactions (`setDailyStepGoal`, `tryClaim*`), and `@override` semantics
  - [x] Create `lib/data/contracts/user_settings_repository_contract.dart` and `user_health_metrics_repository_contract.dart`
  - [x] Update `lib/data/contracts/contracts.dart` barrel — export new contracts; **remove** `user_preferences_repository_contract.dart` after migration
  - [x] Delete `lib/data/repositories/user_preferences_repository.dart` once call sites compile
  - [x] Run `flutter analyze` on new files
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Update DI and services** (AC: #5, #6)
  - [x] Update `AppDependencies`: replace `userPreferences` with `userSettings` + `userHealthMetrics`; fix `create()`, `test()`, `_buildDependencies()`
  - [x] Update `BackgroundCollector` (+ factory), `DataLifecycleService`, `goal_notification_migration.dart`, `workmanager_callback.dart`, `background_collector_factory.dart`
  - [x] Update `AppScaffold.postPurgeRefresh` → `deps.userSettings.clearLastDisplayedSteps()`
  - [x] Update `lib/app.dart` / `onboarding_flow.dart` factory signatures if they reference concrete prefs type
  - [x] Run `flutter analyze`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Update cubits and presentation** (AC: #3, #4, #6)
  - [x] `TodayCubit`: inject `UserSettingsRepositoryContract` + `UserHealthMetricsRepositoryContract` (split fields — do not merge back into one concrete class)
  - [x] `HistoryCubit`: health metrics contract only (goals + height/weight)
  - [x] `MyDataCubit`: both contracts (goal + display name on health; `getLastDatabaseOptimizedAt` on settings)
  - [x] `ThemeCubit`, `UnitsCubit`: settings repository only
  - [x] `ProfileCubit`, `OnboardingCubit`: both repos or minimal split per method usage
  - [x] Update `AppScaffold` cubit construction wiring
  - [x] Run cubit tests: `flutter test test/presentation/cubits/today_cubit_test.dart test/presentation/cubits/history_cubit_test.dart test/presentation/cubits/my_data_cubit_test.dart test/presentation/cubits/today_cubit_contract_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Split repository tests + full regression** (AC: #7, #8)
  - [x] Split `test/data/repositories/user_preferences_repository_test.dart` → settings + health test files (preserve every test case)
  - [x] Grep `test/` for `UserPreferencesRepository` — update to appropriate split repo(s)
  - [x] Update `_FakeUserPreferencesRepository` in `today_cubit_contract_test.dart` → split fakes implementing both contracts
  - [x] Run `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Split monolithic prefs repo into Settings + Health | `StepRepository` split (18-3) |
| Split + migrate repository contracts | Locale preference (Epic 19 — note future home: `UserSettingsRepository`) |
| Update all `lib/` + `test/` consumers | Rewriting every cubit test to drop sqflite (future stories) |
| Extract shared KV helper (DRY) | New mock packages |
| Remove `UserPreferencesRepository` class entirely | Version bump (Epic 18 close) |
| Branch `refacto` only | Changing business rules for goals, notifications, or display persistence |

### Method inventory — authoritative split (audit §1.2c + codebase grep 2026-06-20)

#### `UserSettingsRepository` (+ contract)

| Method | Notes |
|--------|-------|
| `getThemeMode` / `setThemeMode` | |
| `getAccentPreset` / `setAccentPreset` | |
| `getOnboardingComplete` / `setOnboardingComplete` | |
| `get/setDistanceDisplayUnit`, `get/setWeightDisplayUnit`, `get/setHeightDisplayUnit` | Display **units**, not body metrics |
| `isGoalNotificationsPreferenceSet`, `get/setGoalNotificationsEnabled` | |
| `get/setCelebrationShownDate`, `tryClaimCelebrationShownDate` | Atomic claim stays on settings |
| `get/setGoalNotificationShownDate`, `clearGoalNotificationShownDateIfMatches`, `tryClaimGoalNotificationShownDate` | Used by `BackgroundCollector` |
| `get/setLastDatabaseOptimizedAt` | `DataLifecycleService` |
| `getLastDisplayedSteps`, `setLastDisplayedSteps`, `clearLastDisplayedSteps` | **TodayCubit only** + purge clear in `AppScaffold` |
| `bool get isDatabaseOpen` | Needed by `TodayCubit.recordLastDisplayedSteps` guard — expose on **settings** contract |

#### `UserHealthMetricsRepository` (+ contract)

| Method | Notes |
|--------|-------|
| `getDailyStepGoal` | Not on old cubit contract but used in tests/services |
| `getGoalForLocalDay`, `getGoalsForLocalDays`, `setDailyStepGoal` | Includes `daily_goal_effective` journal writes |
| `getDisplayName` / `setDisplayName` | Profile + My Data |
| `getHeightCm` / `setHeightCm`, `getWeightKg` / `setWeightKg` | Body metrics — **not** display-unit prefs |

**Do not** put body height/weight in Settings repo — audit separates "métriques corporelles" from "unités d'affichage".

### Contract migration from Story 16-1

Old `UserPreferencesRepositoryContract` methods → new homes:

| Old contract method | New contract |
|---------------------|--------------|
| `isDatabaseOpen` | `UserSettingsRepositoryContract` |
| `getGoalForLocalDay`, `getGoalsForLocalDays`, `setDailyStepGoal` | `UserHealthMetricsRepositoryContract` |
| `getHeightCm`, `getWeightKg` | `UserHealthMetricsRepositoryContract` |
| `getLastDisplayedSteps`, `setLastDisplayedSteps` | `UserSettingsRepositoryContract` |
| `tryClaimCelebrationShownDate` | `UserSettingsRepositoryContract` |
| `setDisplayName` | `UserHealthMetricsRepositoryContract` |
| `getLastDatabaseOptimizedAt` | `UserSettingsRepositoryContract` |

Update cubit constructor types accordingly. **Delete** `user_preferences_repository_contract.dart` after all imports migrated.

### Shared KV implementation pattern

Both repos must share one session — follow existing constructor pattern:

```dart
UserSettingsRepository(
  Object sessionOrDatabase, {
  String databasePath = inMemoryDatabasePath,
  TimeProvider? clock, // health repo needs clock; settings repo does not unless you pass for consistency
})
```

Extract KV primitives once:

```dart
// lib/data/repositories/_user_preferences_kv_store.dart (private library part or internal class)
class UserPreferencesKvStore {
  UserPreferencesKvStore(this._session);
  final AstraDatabaseSession _session;
  Future<String?> readValue(String key) { ... }
  Future<void> writeValue(String key, String value) { ... }
  Future<void> deleteValue(String key) { ... }
}
```

`UserHealthMetricsRepository` keeps `TimeProvider _clock` for `setDailyStepGoal` / journal effective-day logic.

### Critical baseline — read repository before editing

Sole writer to `user_preferences` table today:

```14:29:lib/data/repositories/user_preferences_repository.dart
/// Sole writer to the `user_preferences` table.
class UserPreferencesRepository implements UserPreferencesRepositoryContract {
  UserPreferencesRepository(
    Object sessionOrDatabase, {
    String databasePath = inMemoryDatabasePath,
    TimeProvider? clock,
  }) : _session = sessionOrDatabase is AstraDatabaseSession
           ? sessionOrDatabase
           : AstraDatabaseSession(
               databasePath: databasePath,
               initial: sessionOrDatabase as Database,
             ),
       _clock = clock ?? const SystemTimeProvider();
```

**Preserve:**
- `setDailyStepGoal` transaction touching both `daily_goal_effective` and prefs cache key `kDailyStepGoalKey`
- Atomic `tryClaimCelebrationShownDate` / `tryClaimGoalNotificationShownDate` transaction semantics
- Validation ranges (`kMinHeightCm`, goal positivity, display name length)
- Default fallbacks (`kDefaultStepGoal`, theme parse fallback to system)

### Consumer map — update every file (grep verified 2026-06-20)

#### `lib/` — settings repo

| File | Methods used |
|------|--------------|
| `core/di/app_dependencies.dart` | theme, accent, units, onboarding bootstrap |
| `presentation/cubits/theme_cubit.dart` | theme, accent |
| `presentation/cubits/units_cubit.dart` | display units |
| `presentation/cubits/today_cubit.dart` | lastDisplayed*, tryClaimCelebration*, isDatabaseOpen |
| `presentation/cubits/my_data_cubit.dart` | getLastDatabaseOptimizedAt |
| `core/services/data_lifecycle_service.dart` | get/setLastDatabaseOptimizedAt |
| `core/services/background_collector.dart` | getGoalNotificationsEnabled, tryClaimGoalNotification*, clearGoalNotification* |
| `core/preferences/goal_notification_migration.dart` | notification pref migration |
| `presentation/screens/app_scaffold.dart` | clearLastDisplayedSteps |
| `presentation/cubits/profile_cubit.dart` | get/setGoalNotificationsEnabled |

#### `lib/` — health repo

| File | Methods used |
|------|--------------|
| `presentation/cubits/today_cubit.dart` | goals, height, weight, setDailyStepGoal |
| `presentation/cubits/history_cubit.dart` | goals, height, weight |
| `presentation/cubits/my_data_cubit.dart` | setDailyStepGoal, setDisplayName |
| `presentation/cubits/profile_cubit.dart` | displayName, height, weight |
| `presentation/cubits/onboarding_cubit.dart` | setDailyStepGoal, weight, height |
| `core/services/background_collector.dart` | getGoalForLocalDay |

#### `lib/` — both repos

| File | Notes |
|------|-------|
| `core/di/app_dependencies.dart` | constructs both from same `databaseSession` |
| `core/services/workmanager_callback.dart` | constructs repos from shared `db` |
| `core/services/background_collector_factory.dart` | passes both into collector |
| `presentation/cubits/onboarding_cubit.dart` | health (body) + settings (onboarding complete) |
| `presentation/cubits/profile_cubit.dart` | split as above |

### `BackgroundCollector` wiring

Today optional `UserPreferencesRepository? userPreferences`. Replace with:

```dart
final UserSettingsRepository? userSettings;
final UserHealthMetricsRepository? userHealthMetrics;
```

`maybeNotifyGoalReachedIfGoalMet` uses:
- `userSettings`: notification enabled + dedup claim/clear
- `userHealthMetrics`: `getGoalForLocalDay`

Keep nullable fields for test/minimal ctor paths.

### `TodayCubit` — two contract fields (not one)

```dart
class TodayCubit extends Cubit<TodayState> {
  TodayCubit({
    required this.stepRepository,
    required this.userSettings,
    required this.userHealthMetrics,
    required this.clock,
    // ...
  });

  final StepRepositoryContract stepRepository;
  final UserSettingsRepositoryContract userSettings;
  final UserHealthMetricsRepositoryContract userHealthMetrics;
```

Route calls:
- `_resolveTodayGoal`, `_clampStaleLastDisplayed` health vs settings per inventory above
- `recordLastDisplayedSteps` → `userSettings` only
- `tryClaimCelebrationShownDate` → `userSettings`

Update `AppScaffold` TodayCubit construction to pass both from `deps`.

### `AppDependencies` migration sketch

```dart
class AppDependencies {
  AppDependencies({
    required this.userSettings,
    required this.userHealthMetrics,
    // remove userPreferences
    ...
  });

  final UserSettingsRepository userSettings;
  final UserHealthMetricsRepository userHealthMetrics;
}

// In create():
final userSettings = UserSettingsRepository(databaseSession);
final userHealthMetrics = UserHealthMetricsRepository(
  databaseSession,
  clock: timeProvider,
);
final initialTheme = await userSettings.getThemeMode();
// ...
BackgroundCollector(
  userSettings: userSettings,
  userHealthMetrics: userHealthMetrics,
  ...
);
```

### Display-step persistence vs Story 15-2 AC

Story 15-2 moved **state** off `GoalRing` into `TodayCubit`/`TodayState`. Persistence **remains** in SQLite for cold-start count-up — do **not** delete persistence unless replacing with in-memory-only (would break cold start).

Epic 18-2 AC "removed or deprecated" means: removed from **monolithic** `UserPreferencesRepository` and from widgets — **relocate** to `UserSettingsRepository`, not delete the feature.

Allowed callers after split:
- `TodayCubit` (load/clamp/record)
- `AppScaffold.postPurgeRefresh` (`clearLastDisplayedSteps`)

### Test migration

| Current | Action |
|---------|--------|
| `test/data/repositories/user_preferences_repository_test.dart` | Split by domain; delete original when empty |
| Tests using `UserPreferencesRepository(db)` for theme only | → `UserSettingsRepository(db)` |
| Tests seeding goals/height | → `UserHealthMetricsRepository(db, clock: ...)` |
| `today_cubit_contract_test.dart` fake | Split into `_FakeUserSettingsRepository` + `_FakeUserHealthMetricsRepository` |
| `history_cubit_test.dart` spies | Health contract for goal/height/weight stubs |

Run default suite per project-context:

```bash
flutter analyze
flutter test --exclude-tags slow
```

### Previous story intelligence (18-1)

| Learning | Application |
|----------|-------------|
| Mechanical extraction first, behaviour unchanged | Move methods verbatim before renaming call sites |
| Sub-task stop → review → commit | Follow same workflow |
| `AppDependencies._buildDependencies()` + `depsGetter` for circular DI | Both repos constructed before services; no new circular deps expected |
| Fast contract tests without sqflite | Update fakes in `today_cubit_contract_test.dart` — keep **no** sqflite in contract test |
| No version bump mid-epic | Defer to Epic 18 close (`0.8.0+17`) |

### Git intelligence

Latest commit: `c559c2d refactor(lifecycle): extract AppLifecycleCoordinator from app.dart (Story 18-1)` — touched `app_dependencies.dart`, no prefs split yet. Safe to refactor prefs without conflicting with 18-1.

### Architecture compliance

| Rule | Application |
|------|-------------|
| Repositories in `lib/data/repositories/` | `user_settings_repository.dart`, `user_health_metrics_repository.dart` |
| Contracts in `lib/data/contracts/` | Split contracts + barrel export |
| Single SQLite writer per table | Shared session; both repos are writers to `user_preferences` — acceptable because they own disjoint key sets |
| Cubits depend on contracts (16-1) | Use split contracts — not concrete classes |
| No artificial `lib/domain/` folder | Keep contracts in `data/contracts/` per Story 16-1 decision |
| Epic 19 locale | Document: add `get/setLocale` to `UserSettingsRepository` in Story 19-3 — **do not** add locale in this story |

### Project structure notes

- Story file: `_bmad-output/implementation-artifacts/stories/18-2-split-user-preferences-repository.md`
- Sprint tracker: `sprint-status-refacto.yaml` (not main `sprint-status.yaml`)
- Do **not** edit `pubspec.yaml` version
- Do **not** rewrite `docs/BETA_CHECKLIST.md` historical rows

### References

- [Source: _bmad-output/planning-artifacts/epics-refacto.md#Story 18-2]
- [Source: _bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md#1.2c]
- [Source: lib/data/repositories/user_preferences_repository.dart — full monolith baseline]
- [Source: lib/data/contracts/user_preferences_repository_contract.dart]
- [Source: _bmad-output/implementation-artifacts/stories/16-1-introduce-repository-abstraction-contracts.md — contract pattern]
- [Source: _bmad-output/implementation-artifacts/stories/15-2-move-goal-ring-display-persistence-to-today-cubit.md — display state ownership]
- [Source: lib/core/di/app_dependencies.dart — DI wiring]
- [Source: lib/presentation/cubits/today_cubit.dart — lastDisplayed + celebration call sites]
- [Source: lib/core/services/background_collector.dart — cross-domain prefs usage]
- [Source: docs/project-context.md — test commands, review-before-commit workflow]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

### Completion Notes List

- Split monolithic `UserPreferencesRepository` (478 lines) into `UserSettingsRepository` + `UserHealthMetricsRepository` sharing `UserPreferencesKvStore` on one `AstraDatabaseSession`.
- Replaced `UserPreferencesRepositoryContract` with `UserSettingsRepositoryContract` (7 members) and `UserHealthMetricsRepositoryContract` (7 members); cubits depend on minimal contract(s).
- `AppDependencies` exposes `userSettings` + `userHealthMetrics`; `userPreferences` removed. Cold-start bootstrap reads from `userSettings`.
- `BackgroundCollector.maybeNotifyGoalReachedIfGoalMet` uses settings for notification prefs/dedup and health for `getGoalForLocalDay`.
- `TodayCubit` holds two contract fields; `lastDisplayedSteps` persistence on settings only (`TodayCubit` + `AppScaffold.postPurgeRefresh`).
- Repository tests split into `user_settings_repository_test.dart` + `user_health_metrics_repository_test.dart`; 33 test files migrated.
- `flutter analyze lib` — info only; `flutter test --exclude-tags slow` — 805 passed, 2 skipped.
- No version bump (Epic 18 close).

### File List

**Added**
- lib/data/repositories/_user_preferences_kv_store.dart
- lib/data/repositories/user_settings_repository.dart
- lib/data/repositories/user_health_metrics_repository.dart
- lib/data/contracts/user_settings_repository_contract.dart
- lib/data/contracts/user_health_metrics_repository_contract.dart
- test/data/repositories/user_settings_repository_test.dart
- test/data/repositories/user_health_metrics_repository_test.dart

**Deleted**
- lib/data/repositories/user_preferences_repository.dart
- lib/data/contracts/user_preferences_repository_contract.dart
- test/data/repositories/user_preferences_repository_test.dart

**Modified (lib)**
- lib/data/contracts/contracts.dart
- lib/core/di/app_dependencies.dart
- lib/core/services/background_collector.dart
- lib/core/services/background_collector_factory.dart
- lib/core/services/data_lifecycle_service.dart
- lib/core/services/workmanager_callback.dart
- lib/core/preferences/goal_notification_migration.dart
- lib/main.dart
- lib/app.dart
- lib/presentation/cubits/today_cubit.dart
- lib/presentation/cubits/history_cubit.dart
- lib/presentation/cubits/my_data_cubit.dart
- lib/presentation/cubits/theme_cubit.dart
- lib/presentation/cubits/units_cubit.dart
- lib/presentation/cubits/profile_cubit.dart
- lib/presentation/cubits/onboarding_cubit.dart
- lib/presentation/screens/app_scaffold.dart
- lib/presentation/onboarding/onboarding_flow.dart

**Modified (test)** — 33 files under test/ (cubits, screens, core services, dev benchmarks, helpers, widget/integration tests)

**Modified (tracking)**
- _bmad-output/implementation-artifacts/sprint-status-refacto.yaml

### Change Log

- 2026-06-20: Story 18-2 — split UserPreferencesRepository into UserSettingsRepository + UserHealthMetricsRepository (REF-18); migrate all consumers and tests; no version bump.
