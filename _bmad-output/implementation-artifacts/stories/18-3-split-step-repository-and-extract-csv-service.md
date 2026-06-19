# Story 18.3: Split StepRepository and Extract CsvService

Status: in-progress

<!-- Refacto Epic 18 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 18-3 · refactoring-audit-master-v0.6.1.md §1.2 · REF-19 -->
<!-- Prerequisite: Story 18-2 done · Story 16-1 contracts · Story 17-1 file_picker CSV export -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **developer**,
I want step ingestion, aggregation, and CSV I/O separated,
So that each class stays under ~250 lines and is easier to test.

## Acceptance Criteria

1. **Given** `StepRepository` (~692 lines at story creation)  
   **When** split  
   **Then** creates (REF-19):
   - `StepIngestionRepository`: `upsertIngestionBucket`, `insertDevSamplesBatch`, `purge`
   - `StepAggregationRepository`: today reads, chart aggregates, footprint, compaction (`downsampleStepSamples`), `countStepSamplesByResolution`
   - `CsvService`: `exportCsv`, `importCsv`, `importSamples`

2. **Given** shared SQLite storage (`timeseries_samples` + purge side-effects on `user_preferences` / baselines)  
   **When** split  
   **Then** all three classes share the same `AstraDatabaseSession` / `Database` instance  
   **And** session retry (`_session.withRetry`) and UTC-bound helpers are extracted once — no duplicated session logic  
   **And** each resulting class is **≤ ~280 lines** (pragmatic target; extract `_step_sample_bounds.dart` if aggregation exceeds)

3. **Given** Story 16-1 `StepRepositoryContract`  
   **When** contracts are updated  
   **Then** split into:
   - `StepIngestionRepositoryContract` — ingestion + purge (+ dev batch if exposed to tests via concrete class)
   - `StepAggregationRepositoryContract` — read/aggregate surface used by cubits + `downsampleStepSamples` for lifecycle
   - `CsvServiceContract` — CSV export/import surface  
   **And** cubits/services depend on the **minimal** contract(s) they need — not the monolithic step API  
   **And** monolithic `StepRepository` class is **removed** (not kept as a facade)

4. **Given** `BackgroundCollector`, `LiveStepMonitor`, `DataLifecycleService`, WorkManager callbacks  
   **When** updated  
   **Then** inject appropriate split repository or service:
   - `BackgroundCollector` → `StepIngestionRepository` (`upsertIngestionBucket`)
   - `LiveStepMonitor` → `StepAggregationRepository` (`getTodaySteps`)
   - `DataLifecycleService` / `runMaintenanceOnConnection` → `StepAggregationRepository` (`downsampleStepSamples`)
   - `MyDataCubit` → aggregation + csv + ingestion (purge) contracts  
   **And** no user-visible behaviour change

5. **Given** CSV export/import user flows (Story 17-1 save-dialog path)  
   **When** tested manually and automatically  
   **Then** identical behaviour to pre-split:
   - Same OW-aligned header, column order, batch export cursor, temp-file hygiene
   - Same import validation, transaction boundaries, `ImportResult` counts
   - Export → purge → import round-trip restores chart aggregates (existing purge test)

6. **Given** ingestion write-path invariant (architecture D-03)  
   **When** split complete  
   **Then** only `BackgroundCollector` calls `upsertIngestionBucket` in production  
   **And** all SQLite writes still go through repository/service methods — no direct `db.insert()` in presentation

7. **Given** repository/service tests  
   **When** run  
   **Then** split test files mirror new boundaries (ingestion, aggregation, csv)  
   **And** migrated tests preserve all existing assertions from `step_repository_*_test.dart` files

8. **Given** `flutter test --exclude-tags slow`  
   **When** run after changes  
   **Then** all tests pass including `today_cubit_contract_test.dart` (update fakes to split contracts)

9. **Given** work completes on branch `refacto`  
   **When** story is marked done  
   **Then** **no version bump** yet — Epic 18 closes with **minor+1, patch=0, build+1** → `0.8.0+17` when all 18-x stories are done

**Covers:** REF-19 · Audit §1.2 · Completes Epic 18 decomposition tranche

**Depends on:** Stories 16-1 (contracts), 17-1 (CSV export via file_picker), 18-2 (split prefs pattern to mirror).

**Out of scope:** Epic 19 i18n, changing CSV column format, schema migrations, `mocktail`/`mockito` adoption, rewriting all cubit tests to drop sqflite.

## Tasks / Subtasks

- [ ] **Sub-task A — Design split + shared session helpers** (AC: #1, #2, #3)
  - [ ] Read `lib/data/repositories/step_repository.dart` **fully** (692 lines) before editing — map every public method to Ingestion / Aggregation / Csv
  - [ ] Read `lib/data/contracts/step_repository_contract.dart` and grep all `stepRepository.` / `StepRepository` call sites in `lib/` and `test/`
  - [ ] Design shared internal helper (e.g. `_StepRepositorySessionMixin` or `_step_repository_session.dart`) holding `_session`, `_run`
  - [ ] Design `_step_sample_bounds.dart` for `_todaySampleUtcBounds`, `_sampleUtcBoundsForLocalDay`, `_finestResolutionTotal`
  - [ ] Design contract method lists (Dev Notes inventory)
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task B — Create split repositories, CsvService, and contracts** (AC: #1, #2, #3)
  - [ ] Create `lib/data/repositories/step_ingestion_repository.dart`
  - [ ] Create `lib/data/repositories/step_aggregation_repository.dart`
  - [ ] Create `lib/data/csv/csv_service.dart` (alongside `timeseries_csv_codec.dart`)
  - [ ] Move methods mechanically — preserve SQL, transactions, `@override`, debug asserts
  - [ ] Create `step_ingestion_repository_contract.dart`, `step_aggregation_repository_contract.dart`, `csv_service_contract.dart`
  - [ ] Update `lib/data/contracts/contracts.dart` — export new contracts; **remove** `step_repository_contract.dart` after migration
  - [ ] Delete `lib/data/repositories/step_repository.dart` once call sites compile
  - [ ] Run `flutter analyze` on new files
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task C — Update DI and services** (AC: #4, #6)
  - [ ] Update `AppDependencies`: replace `stepRepository` with `stepIngestion`, `stepAggregation`, `csvService`; fix `create()`, `test()`, `_buildDependencies()`
  - [ ] Update `BackgroundCollector` (+ factory), `LiveStepMonitor`, `DataLifecycleService`, `runMaintenanceOnConnection`, `workmanager_callback.dart`, `background_collector_factory.dart`
  - [ ] Run `flutter analyze`
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task D — Update cubits and contract test fakes** (AC: #3, #4)
  - [ ] `TodayCubit`: inject `StepAggregationRepositoryContract` only
  - [ ] `HistoryCubit`: inject `StepAggregationRepositoryContract` only
  - [ ] `MyDataCubit`: inject aggregation + csv + ingestion contracts (three fields — minimal per usage)
  - [ ] Update `AppScaffold` cubit construction wiring
  - [ ] Split `_FakeStepRepository` in `today_cubit_contract_test.dart` → `_FakeStepAggregationRepository` (+ update any other contract fakes)
  - [ ] Run cubit tests: `flutter test test/presentation/cubits/today_cubit_test.dart test/presentation/cubits/history_cubit_test.dart test/presentation/cubits/my_data_cubit_test.dart test/presentation/cubits/today_cubit_contract_test.dart`
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task E — Split repository tests + full regression** (AC: #5, #7, #8)
  - [ ] Split `test/data/repositories/step_repository_*_test.dart` files by domain (ingestion / aggregation / csv)
  - [ ] Grep `test/` for `StepRepository` — update to appropriate split class(es); consider thin test helper constructing all three from same `db` where tests need cross-domain setup
  - [ ] Preserve round-trip test: export → purge → import → chart aggregates
  - [ ] Run `flutter test --exclude-tags slow`
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Split monolithic step repo into Ingestion + Aggregation + CsvService | Epic 19 locale/i18n |
| Split + migrate repository/service contracts | Changing CSV format or file_picker UX (17-1) |
| Update all `lib/` + `test/` consumers | Rewriting every cubit test to drop sqflite |
| Extract shared session + bounds helpers (DRY) | New mock packages |
| Remove `StepRepository` class entirely | Version bump (Epic 18 close) |
| Branch `refacto` only | Schema migrations |

### Method inventory — authoritative split (audit §1.2 + codebase grep 2026-06-20)

#### `StepIngestionRepository` (+ contract)

| Method | Notes |
|--------|-------|
| `upsertIngestionBucket(NormalizedStepBucket)` | **Production caller:** `BackgroundCollector` only (D-03) |
| `insertDevSamplesBatch(...)` | Debug/test only — keep `assert(kDebugMode)` guard |
| `purge({testHookAfterDeleteSamples})` | Deletes `timeseries_samples`, clears baselines via `IngestionBaselineRepository.clearAllBaselines`, scrubs health-adjacent pref keys (celebration, goal notification, collect lock, last optimized) |

#### `StepAggregationRepository` (+ contract)

| Method | Notes |
|--------|-------|
| `TimeProvider get clock` | Required by `HistoryCubit._resolveTodayGoal` |
| `getTodaySteps()` | Finest-resolution dedup logic preserved |
| `getTodayActiveBuckets()` | 5min resolution filter |
| `getActiveBucketsForLocalDay(DateTime localDay)` | Used by Today + History |
| `getChartDailyAggregates({required int days})` | 7 or 30 only |
| `getChartMonthlyAggregates({required int months})` | 12 only |
| `getLastIngestionUtc()` | Stale banner / My Data |
| `countStepSamples()` | My Data footprint |
| `getFootprint({required String databasePath})` | Read-only; file size via `File.lengthSync` |
| `downsampleStepSamples({Transaction? txn})` | FR11 compaction — `DataLifecycleService` |
| `countStepSamplesByResolution()` | Dev/diagnostic — stays on aggregation concrete class (optional on contract) |

#### `CsvService` (+ contract)

| Method | Notes |
|--------|-------|
| `exportCsv({required String outputDirectory})` | Needs `clock` for filename date + batched read; inject `AstraDatabaseSession` + `TimeProvider` |
| `importCsv({required String filePath})` | Parse via `TimeseriesCsvCodec.parseImportFile` → delegates to `importSamples` |
| `importSamples(List<TimeseriesSampleModel> samples)` | Single transaction, `ConflictAlgorithm.ignore` |

**Do not** duplicate CSV parse/serialize logic — keep using `lib/data/csv/timeseries_csv_codec.dart`.

### Contract migration from Story 16-1

Old `StepRepositoryContract` methods → new homes:

| Old contract method | New contract |
|---------------------|--------------|
| `clock` | `StepAggregationRepositoryContract` |
| `getTodaySteps`, `getTodayActiveBuckets`, `getActiveBucketsForLocalDay` | `StepAggregationRepositoryContract` |
| `getChartDailyAggregates`, `getChartMonthlyAggregates` | `StepAggregationRepositoryContract` |
| `getLastIngestionUtc`, `countStepSamples`, `getFootprint` | `StepAggregationRepositoryContract` |
| `exportCsv`, `importSamples` | `CsvServiceContract` |
| `purge` | `StepIngestionRepositoryContract` |

**Excluded from cubit contracts** (service/test callers use concrete classes or dedicated contracts):
- `upsertIngestionBucket`, `insertDevSamplesBatch` → ingestion concrete (+ contract if BackgroundCollector typed to abstract)
- `downsampleStepSamples` → aggregation concrete (lifecycle service)
- `importCsv` → csv concrete (MyData may call via cubit using `CsvServiceContract.importSamples` after parse in cubit — **preserve current flow**: cubit calls `TimeseriesCsvCodec.parseImportFile` then `importSamples`; `importCsv` stays on service for tests)

Update cubit constructor types accordingly. **Delete** `step_repository_contract.dart` after all imports migrated.

### Shared session implementation pattern

Mirror Story 18-2 `UserPreferencesKvStore`:

```dart
// lib/data/repositories/_step_repository_session.dart
class StepRepositorySession {
  StepRepositorySession(Object sessionOrDatabase, {String databasePath = inMemoryDatabasePath})
    : _session = sessionOrDatabase is AstraDatabaseSession
        ? sessionOrDatabase
        : AstraDatabaseSession(databasePath: databasePath, initial: sessionOrDatabase as Database);

  final AstraDatabaseSession _session;
  Database get db => _session.database;
  Future<T> run<T>(Future<T> Function(Database db) action) => _session.withRetry(action);
}
```

Each split class holds a `StepRepositorySession` (or equivalent) constructed from the same `databaseSession` in DI.

UTC bound helpers (`_todaySampleUtcBounds`, `_sampleUtcBoundsForLocalDay`, `_finestResolutionTotal`) → `lib/data/repositories/_step_sample_bounds.dart` — pure functions taking `TimeProvider` / `DateTime` inputs.

### Critical baseline — read repository before editing

Monolith constructor pattern today:

```25:43:lib/data/repositories/step_repository.dart
class StepRepository implements StepRepositoryContract {
  StepRepository({
    required this.clock,
    AstraDatabaseSession? session,
    Database? db,
    String databasePath = inMemoryDatabasePath,
  }) : _session =
           session ??
           AstraDatabaseSession(
             databasePath: databasePath,
             initial: db!,
           ),
       assert(session != null || db != null);

  final AstraDatabaseSession _session;
  @override
  final TimeProvider clock;

  Database get db => _session.database;
```

**Preserve exactly:**
- Ingestion upsert: `ON CONFLICT(...) DO UPDATE SET value = timeseries_samples.value + excluded.value`
- Deterministic bucket IDs via `SampleIdGenerator.deterministicFromIngestionBucket`
- Finest-resolution dedup (`5min → hourly → daily`) in today/chart aggregations
- Per-row `LocalDayCalculator` filtering (never SQL `date(start_time, zone_offset)`)
- Export batch cursor `(start_time, id)` pagination — batch size 500
- Import `ConflictAlgorithm.ignore` skip semantics → `ImportResult.skippedCount`
- Purge transaction atomicity + `IngestionBaselineRepository.clearAllBaselines(txn)`
- `downsampleStepSamples` optional external `txn` for D-24 batching
- Debug-only guard on `insertDevSamplesBatch`

### Consumer map — update every file (grep verified 2026-06-20)

#### `lib/` — ingestion repo

| File | Methods used |
|------|--------------|
| `core/services/background_collector.dart` | `upsertIngestionBucket` |
| `presentation/cubits/my_data_cubit.dart` | `purge` |
| `core/di/app_dependencies.dart` | constructs + wires |
| `core/services/background_collector_factory.dart` | constructs |
| `core/services/workmanager_callback.dart` | constructs |

#### `lib/` — aggregation repo

| File | Methods used |
|------|--------------|
| `presentation/cubits/today_cubit.dart` | today steps, active buckets, chart daily, last ingestion |
| `presentation/cubits/history_cubit.dart` | chart daily/monthly, active buckets, `clock` |
| `presentation/cubits/my_data_cubit.dart` | count, footprint, last ingestion |
| `core/services/live_step_monitor.dart` | `getTodaySteps` |
| `core/services/data_lifecycle_service.dart` | `downsampleStepSamples` |
| `core/di/app_dependencies.dart` | constructs + wires |

#### `lib/` — csv service

| File | Methods used |
|------|--------------|
| `presentation/cubits/my_data_cubit.dart` | `exportCsv`, `importSamples` (parse in cubit via `TimeseriesCsvCodec`) |

#### `test/` — high-touch files

| Area | Files (non-exhaustive — grep `StepRepository`) |
|------|--------------------------------------------------|
| Repository tests | `step_repository_upsert_test.dart`, `_export_test.dart`, `_import_test.dart`, `_purge_test.dart`, `_today_test.dart`, `_chart_*`, `_footprint_test.dart`, `_downsample_test.dart`, `_active_buckets_test.dart`, `_dev_batch_test.dart`, `_last_ingestion_test.dart` |
| Cubit tests | `today_cubit_test.dart`, `history_cubit_test.dart`, `my_data_cubit_*`, `today_cubit_contract_test.dart` |
| Service tests | `background_collector_test.dart`, `data_lifecycle_service_test.dart` |
| Integration | `app_live_pipeline_lifecycle_test.dart` |
| Dev helpers | `test/dev/data_inject_service.dart`, `lifecycle_simulator.dart` |

**Test helper suggestion:** optional `StepTestFixtures.createRepos(Database db, TimeProvider clock)` returning `(ingestion, aggregation, csv)` tuple — reduces boilerplate in tests that seed via upsert then read via aggregation.

### `AppDependencies` migration sketch

```dart
class AppDependencies {
  AppDependencies({
    required this.stepIngestion,
    required this.stepAggregation,
    required this.csvService,
    // remove stepRepository
    ...
  });

  final StepIngestionRepository stepIngestion;
  final StepAggregationRepository stepAggregation;
  final CsvService csvService;
}

// In create() — shared session:
final stepSession = ...; // or reuse databaseSession
final stepIngestion = StepIngestionRepository(session: databaseSession);
final stepAggregation = StepAggregationRepository(session: databaseSession, clock: timeProvider);
final csvService = CsvService(session: databaseSession, clock: timeProvider);

BackgroundCollector(repository: stepIngestion, ...);
LiveStepMonitor(stepAggregation: stepAggregation, ...);
DataLifecycleService(repository: stepAggregation, ...);
```

### `MyDataCubit` — three contract fields

```dart
class MyDataCubit extends Cubit<MyDataState> {
  MyDataCubit({
    required this.stepAggregation,
    required this.csvService,
    required this.stepIngestion,
    ...
  });

  final StepAggregationRepositoryContract stepAggregation;
  final CsvServiceContract csvService;
  final StepIngestionRepositoryContract stepIngestion;
}
```

Route calls:
- Export/import → `csvService`
- Footprint, counts, stale → `stepAggregation`
- Purge → `stepIngestion`

### CSV export flow (Story 17-1 — do not regress)

Current flow in `MyDataCubit`:
1. Temp dir via `getTemporaryDirectory()`
2. `stepRepository.exportCsv(outputDirectory: tempPath)` writes OW-aligned file
3. Read bytes → `FilePicker.saveFile` (user picks destination)
4. Delete temp file in `finally`

After split: step 2 calls `csvService.exportCsv` — **same** repository method body moved verbatim.

### Purge cross-table effects

`purge` touches:
- `timeseries_samples` (delete all)
- `ingestion_baselines` via `IngestionBaselineRepository.clearAllBaselines(txn)`
- `user_preferences` keys: celebration, goal notification, collect lock, last optimized

Does **not** delete goals, theme, onboarding, display name — preserve exactly.

Post-purge UI refresh remains in `AppScaffold.postPurgeRefresh` (clears `userSettings.clearLastDisplayedSteps()` — unchanged).

### Previous story intelligence (18-2)

| Learning | Application |
|----------|-------------|
| Mechanical extraction first, behaviour unchanged | Move methods verbatim before renaming call sites |
| Shared KV/session helper extracted once | Use `StepRepositorySession` + bounds helper file |
| Sub-task stop → review → commit | Follow same workflow per project-context |
| Remove monolith — no facade | Delete `StepRepository`; do not keep delegating wrapper |
| Split contract fakes in `today_cubit_contract_test.dart` | `_FakeStepAggregationRepository` only (Today needs aggregation) |
| `AppDependencies._buildDependencies()` pattern | Construct all three from same `databaseSession` |
| No version bump mid-epic | Defer to Epic 18 close (`0.8.0+17`) |
| 805 tests passed at 18-2 close | Regression bar — run `flutter test --exclude-tags slow` |

### Previous story intelligence (18-1)

| Learning | Application |
|----------|-------------|
| Service extraction from `app.dart` complete | No conflicting lifecycle work in 18-3 |
| `DataLifecycleService` already uses concrete `StepRepository` for downsample | Retype to `StepAggregationRepository` |

### Git intelligence

Recent commits (2026-06-20):
- `1c489f4` — isolate session races, cubit contracts hardening (post 18-2)
- `15148da`–`bd70523` — Story 18-2 prefs split (pattern to mirror)
- Safe to refactor step repo; no in-flight step work expected

### Architecture compliance

| Rule | Application |
|------|-------------|
| Repositories in `lib/data/repositories/` | `step_ingestion_repository.dart`, `step_aggregation_repository.dart` |
| CSV at `lib/data/csv/` | `csv_service.dart` next to `timeseries_csv_codec.dart` |
| Contracts in `lib/data/contracts/` | Three new contracts + barrel export |
| Single ingestion write path (D-03) | Only `BackgroundCollector` → `upsertIngestionBucket` |
| All writes via repository methods | No direct sqflite in presentation |
| Transaction boundaries (D-24) | Import, purge, dev batch, downsample keep `db.transaction` |
| Local day in Dart (NFR-9) | Preserve `LocalDayCalculator` per-row filtering |
| Cubits depend on contracts (16-1) | Minimal split contracts per cubit |
| No artificial `lib/domain/` folder | Keep contracts in `data/contracts/` |

### Project structure notes

- Story file: `_bmad-output/implementation-artifacts/stories/18-3-split-step-repository-and-extract-csv-service.md`
- Sprint tracker: `sprint-status-refacto.yaml` (not main `sprint-status.yaml`)
- Do **not** edit `pubspec.yaml` version
- Do **not** rewrite `docs/BETA_CHECKLIST.md` historical rows
- Epic 18 is last story — after 18-3 review + done, bump `0.8.0+17` per epic close policy

### Testing requirements

Default verification (project-context):

```bash
flutter analyze
flutter test --exclude-tags slow
```

Targeted after sub-task D:

```bash
flutter test test/presentation/cubits/today_cubit_contract_test.dart
flutter test test/data/repositories/step_repository_export_test.dart  # → migrated name
flutter test test/data/repositories/step_repository_purge_test.dart   # → migrated name
```

Round-trip assertion (must survive migration):

```dart
// export → purge → import restores chart daily aggregates
final exportPath = await csvService.exportCsv(outputDirectory: tempDir.path);
await stepIngestion.purge();
await csvService.importCsv(filePath: exportPath);
final aggregates = await stepAggregation.getChartDailyAggregates(days: 7);
```

### References

- [Source: _bmad-output/planning-artifacts/epics-refacto.md#Story 18-3]
- [Source: _bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md#1.2]
- [Source: lib/data/repositories/step_repository.dart — full monolith baseline (692 lines)]
- [Source: lib/data/contracts/step_repository_contract.dart]
- [Source: _bmad-output/implementation-artifacts/stories/16-1-introduce-repository-abstraction-contracts.md — contract pattern]
- [Source: _bmad-output/implementation-artifacts/stories/18-2-split-user-preferences-repository.md — split pattern to mirror]
- [Source: _bmad-output/implementation-artifacts/stories/17-1-replace-share-plus-with-file-picker-csv-export.md — CSV UX preservation]
- [Source: lib/presentation/cubits/my_data_cubit.dart — export/import/purge call sites]
- [Source: lib/core/services/background_collector.dart — sole ingestion caller]
- [Source: lib/core/services/data_lifecycle_service.dart — downsample caller]
- [Source: docs/project-context.md — test commands, review-before-commit workflow]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

### Change Log
