# Story 16.1: Introduce Repository Abstraction Contracts

Status: done

<!-- Refacto Epic 16 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 16-1 · refactoring-audit-master-v0.6.1.md §1.3 · REF-07 · NFR-REF-04 -->
<!-- Unblocks: Stories 16-5–16-7 fast cubit tests · Epic 18 repository splits -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **developer**,
I want cubits to depend on interfaces,
So that I can write fast unit tests with mocks instead of `sqflite_common_ffi`.

## Acceptance Criteria

1. **Given** a new contracts module under `lib/data/contracts/`  
   **When** created  
   **Then** defines `StepRepositoryContract` and `UserPreferencesRepositoryContract` (REF-07, NFR-REF-04)  
   **And** each contract exposes **only** the methods/getters consumed by `TodayCubit`, `HistoryCubit`, and `MyDataCubit` (see Dev Notes — method inventory)  
   **And** `StepRepositoryContract` includes `TimeProvider get clock` (required by `HistoryCubit._resolveTodayGoal`)

2. **Given** existing concrete repositories  
   **When** updated  
   **Then** `StepRepository implements StepRepositoryContract`  
   **And** `UserPreferencesRepository implements UserPreferencesRepositoryContract`  
   **And** no method signatures or behaviour change — contracts are drop-in abstractions

3. **Given** `TodayCubit`, `HistoryCubit`, `MyDataCubit`  
   **When** refactored  
   **Then** constructor field types use abstract contracts, not concrete repository classes  
   **And** `AppDependencies` / `AppScaffold` wiring continues passing concrete `StepRepository` / `UserPreferencesRepository` instances (subtype substitution)

4. **Given** at least one cubit unit test (prefer `TodayCubit`)  
   **When** run with **manual fakes** implementing the contracts  
   **Then** test completes **without** calling `setUpSqfliteFfi()` or opening SQLite  
   **And** runs in **&lt;1s** locally (no `sqflite_common_ffi` bootstrap)

5. **Given** the existing integration / widget test suite  
   **When** `flutter test` runs  
   **Then** all pass — contracts are behavioural no-ops; no user-visible change

6. **Given** work completes on branch `refacto`  
   **When** story is marked done  
   **Then** **no version bump** yet — Epic 16 closes with minor+1 (`0.6.3+14` → `0.7.0+15`) when all Epic 16 stories are done

**Covers:** REF-07 · NFR-REF-04 · Audit §1.3 (P2) · **Unblocks** fast cubit unit tests (16-5, 16-7) and Epic 18 splits

## Tasks / Subtasks

- [x] **Sub-task A — Define `StepRepositoryContract`, `UserPreferencesRepositoryContract`** (AC: #1)
  - [x] Read `TodayCubit`, `HistoryCubit`, `MyDataCubit` and grep `stepRepository.` / `userPreferences.` **before editing**
  - [x] Create `lib/data/contracts/step_repository_contract.dart` and `user_preferences_repository_contract.dart`
  - [x] Use `abstract class` (matches existing `DataIngestionSource`, `TimeProvider` pattern — architecture naming)
  - [x] Export both from `lib/data/contracts/contracts.dart` (barrel) for clean cubit imports
  - [x] Run `flutter analyze` on new files
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Wire concrete repositories to contracts** (AC: #2)
  - [x] Add `implements StepRepositoryContract` to `StepRepository`
  - [x] Add `implements UserPreferencesRepositoryContract` to `UserPreferencesRepository`
  - [x] Fix any `@override` / signature mismatches (should be zero if contract mirrors existing public API subset)
  - [x] Run repository unit tests unchanged: `flutter test test/data/repositories/`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Refactor three cubits to depend on contracts** (AC: #3)
  - [x] Update field types + constructor params in `today_cubit.dart`, `history_cubit.dart`, `my_data_cubit.dart`
  - [x] Import contracts barrel — **do not** import concrete repository classes in cubit files
  - [x] Verify `AppScaffold` / `AppDependencies` compile without change (concrete instances satisfy contracts)
  - [x] Run `flutter analyze` + cubit tests that still use SQLite: `flutter test test/presentation/cubits/today_cubit_test.dart test/presentation/cubits/history_cubit_test.dart test/presentation/cubits/my_data_cubit_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Add fast mock-based cubit test(s)** (AC: #4)
  - [x] Create `test/presentation/cubits/today_cubit_contract_test.dart` (or dedicated group in existing file **without** `setUpAll(setUpSqfliteFfi)`)
  - [x] Implement `_FakeStepRepository implements StepRepositoryContract` and `_FakeUserPreferencesRepository implements UserPreferencesRepositoryContract` with stubbed returns — use `noSuchMethod` for unneeded methods (same pattern as `history_cubit_test.dart` spies)
  - [x] Cover at least one behaviour path, e.g. `refresh emits noPermission when activity permission denied` or `refresh emits empty when permission granted and mocked zero steps`
  - [x] Assert test file has **no** `sqflite` / `setUpSqfliteFfi` imports
  - [x] Run: `flutter test test/presentation/cubits/today_cubit_contract_test.dart` — confirm &lt;1s
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Migrate existing test spies + full suite** (AC: #5)
  - [x] Update `history_cubit_test.dart` spy classes: `implements StepRepositoryContract` (not `StepRepository`) where applicable
  - [x] Run full `flutter test` + `flutter analyze`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Abstract contracts for cubit-facing repository APIs | Splitting `StepRepository` / `UserPreferencesRepository` (Epic 18) |
| Refactor `TodayCubit`, `HistoryCubit`, `MyDataCubit` constructors | `ProfileCubit`, `ThemeCubit`, `UnitsCubit`, `OnboardingCubit` (future story or Epic 18) |
| One fast cubit test without SQLite | Rewriting all cubit tests to drop `sqflite_common_ffi` (future stories 16-5+) |
| Manual fakes in tests (no new mock package) | Adding `mocktail` / `mockito` dev dependency |
| Branch `refacto` only | Version bump (deferred to Epic 16 close) |
| Drop-in behaviour — zero UX change | Changing `AppDependencies` field types to contracts (services still need full concrete API) |

### Contract location — prefer `lib/data/contracts/` over `lib/domain/`

Epic allows `lib/domain/` **or** `lib/data/contracts/`. **Choose `lib/data/contracts/`:**

- Architecture **D-22**: pragmatic 3-layer model — *"no artificial DDD domain folder"*
- Matches existing abstractions: `DataIngestionSource` in `lib/data/datasources/`, `TimeProvider` in `lib/core/time/`
- Epic 18 splits stay in `lib/data/repositories/`; contracts remain stable facades

### Method inventory (contract surface = cubit call sites only)

**Do not** copy the full repository public API (~20+ methods each). Contracts must list **only** what the three cubits call today (grep 2026-06-19):

#### `StepRepositoryContract`

| Method / getter | Used by |
|-----------------|---------|
| `TimeProvider get clock` | `HistoryCubit` (`_resolveTodayGoal`) |
| `Future<int> getTodaySteps()` | `TodayCubit` |
| `Future<List<TimeseriesSampleModel>> getTodayActiveBuckets()` | `TodayCubit` |
| `Future<List<TimeseriesSampleModel>> getActiveBucketsForLocalDay(DateTime localDay)` | `TodayCubit`, `HistoryCubit` |
| `Future<List<ChartDayAggregate>> getChartDailyAggregates({required int days})` | `TodayCubit`, `HistoryCubit` |
| `Future<List<ChartMonthAggregate>> getChartMonthlyAggregates({required int months})` | `HistoryCubit` |
| `Future<DateTime?> getLastIngestionUtc()` | `TodayCubit`, `MyDataCubit` |
| `Future<int> countStepSamples()` | `MyDataCubit` |
| `Future<ImportResult> importSamples(List<TimeseriesSampleModel> samples)` | `MyDataCubit` |
| `Future<String> exportCsv({required String outputDirectory})` | `MyDataCubit` |
| `Future<void> purge({...})` | `MyDataCubit` — mirror existing signature exactly |
| `Future<DatabaseFootprint> getFootprint({required String databasePath})` | `MyDataCubit` |

**Explicitly excluded** from contract (service / ingestion callers only): `upsertIngestionBucket`, `insertDevSamplesBatch`, `downsampleStepSamples`, `importCsv`, `db` getter, etc.

#### `UserPreferencesRepositoryContract`

| Method / getter | Used by |
|-----------------|---------|
| `bool get isDatabaseOpen` | `TodayCubit` (`recordLastDisplayedSteps` guard) |
| `Future<int> getGoalForLocalDay(String localDayIso)` | `TodayCubit`, `HistoryCubit` |
| `Future<Map<String, int>> getGoalsForLocalDays(List<String> localDayIsos)` | `HistoryCubit` |
| `Future<void> setDailyStepGoal(int goal)` | `TodayCubit`, `MyDataCubit` |
| `Future<int?> getHeightCm()` | `TodayCubit`, `HistoryCubit` |
| `Future<double?> getWeightKg()` | `TodayCubit`, `HistoryCubit` |
| `Future<int?> getLastDisplayedSteps(String localDayIso)` | `TodayCubit` |
| `Future<void> setLastDisplayedSteps({required String localDayIso, required int steps})` | `TodayCubit` |
| `Future<bool> tryClaimCelebrationShownDate(String localDayIso)` | `TodayCubit` |
| `Future<void> setDisplayName(String? name)` | `MyDataCubit` |
| `Future<DateTime?> getLastDatabaseOptimizedAt()` | `MyDataCubit` |

When adding a method to a contract, **grep all three cubits** — do not expose prefs APIs used only by `ProfileCubit` / `ThemeCubit` in this story.

### Critical baseline — read before editing

**Cubits depend on concrete classes today:**

```42:43:lib/presentation/cubits/today_cubit.dart
  final StepRepository stepRepository;
  final UserPreferencesRepository userPreferences;
```

```19:20:lib/presentation/cubits/history_cubit.dart
  final StepRepository stepRepository;
  final UserPreferencesRepository userPreferences;
```

**DI passes concrete instances — no change needed after cubit refactor:**

```76:79:lib/presentation/screens/app_scaffold.dart
        TodayCubit(
          stepRepository: widget.deps.stepRepository,
          userPreferences: widget.deps.userPreferences,
          clock: widget.deps.timeProvider,
```

**Existing tests already use partial fakes — migrate type, not pattern:**

```41:49:test/presentation/cubits/history_cubit_test.dart
class _ChartAggregateSpyRepository implements StepRepository {
  _ChartAggregateSpyRepository(this._delegate);

  final StepRepository _delegate;
  int chartAggregateCallCount = 0;
  // ...
  @override
  TimeProvider get clock => _delegate.clock;
```

After Sub-task A, change to `implements StepRepositoryContract` and `_delegate` type to `StepRepositoryContract`.

**Today cubit tests bootstrap SQLite for every test today:**

```22:39:test/presentation/cubits/today_cubit_test.dart
  setUpAll(() async {
    await setUpSqfliteFfi();
  });
  // ...
      userPreferences = UserPreferencesRepository(db, clock: clock);
      stepRepository = StepRepository(db: db, clock: clock);
```

Sub-task D adds a **separate** test file without this bootstrap to satisfy NFR-REF-04. Leave existing integration-style cubit tests intact.

### Suggested contract shape (illustrative — verify signatures against source)

```dart
// lib/data/contracts/step_repository_contract.dart
abstract class StepRepositoryContract {
  TimeProvider get clock;

  Future<int> getTodaySteps();
  Future<List<TimeseriesSampleModel>> getTodayActiveBuckets();
  Future<List<TimeseriesSampleModel>> getActiveBucketsForLocalDay(
    DateTime localDay,
  );
  Future<List<ChartDayAggregate>> getChartDailyAggregates({required int days});
  Future<List<ChartMonthAggregate>> getChartMonthlyAggregates({
    required int months,
  });
  Future<DateTime?> getLastIngestionUtc();
  Future<int> countStepSamples();
  Future<ImportResult> importSamples(List<TimeseriesSampleModel> samples);
  Future<String> exportCsv({required String outputDirectory});
  Future<void> purge({
    Future<void> Function(Transaction txn)? testHookAfterDeleteSamples,
  });
  Future<DatabaseFootprint> getFootprint({required String databasePath});
}
```

Copy **exact** parameter lists and return types from concrete methods — do not simplify or rename.

### Fast fake test example (Sub-task D)

```dart
class _FakeStepRepository implements StepRepositoryContract {
  _FakeStepRepository(this.clock);

  @override
  final TimeProvider clock;

  @override
  Future<int> getTodaySteps() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

Pair with `_FakeUserPreferencesRepository` returning defaults for height/weight/goals/display steps. Inject `FakeTimeProvider` — already in `test/core/time/fake_time_provider.dart`.

Recommended first test: **`refresh emits noPermission when activity permission denied`** — single `refresh()` call, no repository data setup, fastest path.

### `AppDependencies` — keep concrete field types

Services (`BackgroundCollector`, `LiveStepMonitor`, `DataLifecycleService`, `workmanager_callback`) need the **full** `StepRepository` API including `upsertIngestionBucket`. Do **not** widen contracts to satisfy services.

Only cubit constructor params change to contracts. `AppDependencies.stepRepository` stays `StepRepository`.

### Previous story intelligence (Epic 15)

- **15-2** moved GoalRing display persistence into `TodayCubit` — cubit now owns `getLastDisplayedSteps` / `setLastDisplayedSteps` / `isDatabaseOpen` guard. Contract **must** include these prefs methods.
- **15-4** added `SampleIdGenerator` — unrelated to contracts; no conflict.
- Epic 15 closed at **`0.6.3+14`** on branch `refacto`.
- Review-before-commit workflow: one commit per sub-task, review brief, wait for Baptiste OK (`docs/project-context.md`).

### Regression risks

| Risk | Mitigation |
|------|------------|
| Contract missing a cubit-called method | Use method inventory table; grep before merge |
| `HistoryCubit` loses `clock` access | Include `TimeProvider get clock` on step contract |
| Signature drift between contract and concrete class | `implements` + analyzer catches mismatches |
| Breaking test spies | Sub-task E updates `implements` target |
| Scope creep into other cubits / services | Explicit out-of-scope table |
| Accidentally adding mock package | Use manual fakes — project has zero mock deps today |

### Architecture compliance

- **D-22:** Contracts in `lib/data/contracts/` — no `lib/domain/` folder.
- **Naming:** `StepRepositoryContract` suffix per audit/epic (exception to bare-noun `DataIngestionSource` rule — follow epic verbatim).
- **NFR-REF-04:** Fast cubit test without SQLite — Sub-task D deliverable.
- **NFR-REF-05:** Cubits depend on abstractions; widgets already do not touch repositories (15-2).
- **Drop-in replacement:** No ingestion/admin write path changes; `BackgroundCollector` unchanged.

### Test files to run (minimum)

| File | Why |
|------|-----|
| `test/presentation/cubits/today_cubit_contract_test.dart` | **New** — AC #4 fast mock test |
| `test/presentation/cubits/today_cubit_test.dart` | Regression — SQLite path still works |
| `test/presentation/cubits/history_cubit_test.dart` | Spy migration + batch goal tests |
| `test/presentation/cubits/my_data_cubit_test.dart` | Import/export/purge regression |
| `test/data/repositories/step_repository_today_test.dart` | Concrete repo still implements contract |
| Full `flutter test` | AC #5 |

### References

- [Source: `_bmad-output/planning-artifacts/epics-refacto.md` — Story 16-1, REF-07, NFR-REF-04]
- [Source: `_bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md` — §1.3 repository abstractions]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — D-22 layering, interface naming]
- [Source: `lib/data/repositories/step_repository.dart` — concrete API]
- [Source: `lib/data/repositories/user_preferences_repository.dart` — concrete API]
- [Source: `lib/core/di/app_dependencies.dart` — composition root]
- [Source: `test/presentation/cubits/history_cubit_test.dart` — existing spy/fake pattern]
- [Source: `_bmad-output/implementation-artifacts/stories/15-2-move-goal-ring-display-persistence-to-today-cubit.md` — TodayCubit prefs coupling]
- [Source: `docs/project-context.md` — review-before-commit workflow]

## Dev Agent Record

### Agent Model Used

claude-4.6-sonnet-medium-thinking

### Debug Log References

- Sub-task D: `noPermission` path still calls `_loadWeekDays()` → fakes must stub `getChartDailyAggregates` + `getGoalForLocalDay`; `empty` path needs full refresh stub set.
- Sub-task E: `buildCubit({StepRepository?})` updated to `StepRepositoryContract?` after spy migration.

### Completion Notes List

- Added `lib/data/contracts/` with `StepRepositoryContract` (12 methods + `clock`) and `UserPreferencesRepositoryContract` (11 members) — cubit call-site surface only per method inventory.
- `StepRepository` / `UserPreferencesRepository` implement contracts; cubit field types use contracts; `AppDependencies` unchanged (concrete subtypes).
- New `today_cubit_contract_test.dart`: 2 tests, no SQLite, ~5s file load (tests &lt;1s each).
- `history_cubit_test.dart` spies migrated to `StepRepositoryContract`; `buildCubit` param type updated.
- Full `flutter test` green (2043 lines output, all pass). Analyzer reports info-level `annotate_overrides` on concrete repos only (pre-existing style).

### File List

**Created:**
- `lib/data/contracts/step_repository_contract.dart`
- `lib/data/contracts/user_preferences_repository_contract.dart`
- `lib/data/contracts/contracts.dart`
- `test/presentation/cubits/today_cubit_contract_test.dart`

**Modified:**
- `lib/data/repositories/step_repository.dart`
- `lib/data/repositories/user_preferences_repository.dart`
- `lib/presentation/cubits/today_cubit.dart`
- `lib/presentation/cubits/history_cubit.dart`
- `lib/presentation/cubits/my_data_cubit.dart`
- `test/presentation/cubits/history_cubit_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml`

## Change Log

- 2026-06-19: Story context created (create-story workflow) — ready-for-dev. Ultimate context engine analysis completed — comprehensive developer guide created.
- 2026-06-19: Implementation complete — repository abstraction contracts, cubit refactor, fast contract test, spy migration. Status → review.
- 2026-06-19: Code review polish — `@override` on concrete repos, `buildCubit` preferences param uses contract. Status → done.
