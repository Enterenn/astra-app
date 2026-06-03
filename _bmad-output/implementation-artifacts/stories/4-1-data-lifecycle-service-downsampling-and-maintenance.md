# Story 4.1: Data Lifecycle Service (Downsampling and Maintenance)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want old step data compressed automatically,
So that storage stays bounded without manual cleanup.

## Acceptance Criteria

1. **Given** samples older than 30/365 day thresholds
   **When** `DataLifecycleService` runs inside repository-owned transactions
   **Then** downsampling applies FR11 tiers destructively and updates `resolution` field (FR11)
   **And** finer rows are deleted after compaction — irreversible

2. **Given** maintenance is due
   **When** Android weekly job or iOS foreground/resume opportunistic run executes
   **Then** `PRAGMA optimize` and `VACUUM` run off UI thread (FR12)
   **And** Phase 0 does not require reliable iOS background VACUUM for acceptance

3. **Given** 90-day inject test with repeated lifecycle cycles
   **When** complete
   **Then** DB file size does not grow unbounded (FR12, NFR7)

## Tasks / Subtasks

- [x] **Sub-task A — Promote compaction core to production module** (AC: #1)
  - [x] Move `lib/dev/lifecycle_compaction.dart` → `lib/core/lifecycle/lifecycle_compaction.dart` (update imports in dev + tests).
  - [x] Extract shared compaction orchestration from `LifecycleSimulator` into `lib/core/lifecycle/sample_compaction_runner.dart` (or equivalent) — single implementation for tier 2/3 passes:
    - Tier 2: 5min → 1hour (age 30–364 local days)
    - Tier 3: hourly → daily (age ≥365)
    - Tier 3 catch-up: orphaned 5min → daily (age ≥365)
  - [x] Preserve existing semantics from Story 3.1: complete groups only (12×5min, 24×1hour, 288×5min), value-sum conservation, skip incomplete groups.
  - [x] Refactor `LifecycleSimulator` to delegate to shared runner (dev-only entry stays `kDebugMode` guarded).
  - [x] Run `flutter test test/dev/lifecycle_simulator_test.dart test/dev/lifecycle_compaction_test.dart` — must stay green after move.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — `StepRepository` administrative compaction API** (AC: #1)
  - [x] Add `Future<CompactionResult> downsampleStepSamples({Transaction? txn})` (name flexible) on `StepRepository`:
    - Owns `db.transaction()` when `txn` is null; accepts external `txn` for callers that batch with other admin writes.
    - Uses injected `TimeProvider` for reference now + zone offset (D-25) — never `DateTime.now()` inline.
    - Returns counts: `{hourlyCreated, dailyCreated, fiveMinDeleted, ...}` for tests/logging.
  - [x] All inserts/deletes on `timeseries_samples` stay inside repository (architecture administrative write path) — compaction runner must not call `db.insert` outside repository.
  - [x] Unit tests: in-memory DB + `FakeTimeProvider` — inject 90d → downsample → assert **10 080** rows, resolution breakdown **8640 / 1440 / 0**, total step sum unchanged (mirror `lifecycle_simulator_test.dart`).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — `DataLifecycleService` production service** (AC: #1–#2)
  - [x] Create `lib/core/services/data_lifecycle_service.dart`:
    - Constructor: `Database db`, `StepRepository repository`, `UserPreferencesRepository userPreferences`, `TimeProvider clock`.
    - `Future<LifecycleRunResult> runMaintenance({bool force = false})`:
      1. If not `force` and not `isMaintenanceDue()` → return early (no-op).
      2. `await repository.downsampleStepSamples()` inside transaction scope.
      3. Off UI thread: `PRAGMA optimize;` then `VACUUM;` (use `compute`/isolate or run inside WM callback — **never** on UI isolate main thread during frame build).
      4. Persist `last_database_optimized_at` ISO UTC in `user_preferences` (new key — see Sub-task D).
    - `bool isMaintenanceDue()` — weekly interval (7 days since last optimized); treat missing key as due.
  - [x] Wire into `AppDependencies.create()` / `.test()` as `dataLifecycleService` singleton.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Scheduling: Android WM + iOS opportunistic** (AC: #2)
  - [x] Add constants in `lib/core/services/workmanager_tasks.dart`:
    - `kDatabaseMaintenanceUniqueName`, `kDatabaseMaintenanceTaskName` (distinct from step collection task).
  - [x] Extend `handleWorkmanagerTask` / `callbackDispatcher` to route maintenance task → `runDatabaseMaintenanceWorkmanagerTask(databasePath: ...)`.
  - [x] Register weekly periodic task on Android in `main.dart` (after DB path known), frequency **7 days**, `ExistingPeriodicWorkPolicy.update`, pass `databasePath` in `inputData` (same pattern as 2.10 step collection).
  - [x] iOS: no WM — in `AstraApp.didChangeAppLifecycleState(resumed)`, call `dataLifecycleService.runMaintenance()` **without awaiting on UI thread** (unawaited microtask/Future; service runs VACUUM off main thread internally).
  - [x] Document: Phase 0 acceptance does **not** require reliable iOS background VACUUM; foreground/resume path is sufficient.
  - [x] Add `kLastDatabaseOptimizedAtKey` to `preference_keys.dart` + `UserPreferencesRepository.get/setLastDatabaseOptimizedAt`.
  - [x] Tests: `workmanager_callback_test.dart` — maintenance task invokes service (mocked DB); maintenance due/ skip logic unit test.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Bounded growth + regression harness** (AC: #3)
  - [x] Add `test/core/services/data_lifecycle_service_test.dart`:
    - Inject 90d → run maintenance twice → row count stable; file size on disk (temp DB path) does not increase materially on second run (assert row count + optional `File.lengthSync` delta threshold).
    - Repeated `downsample` without new inject is idempotent (second pass creates 0 new rows).
  - [x] Update `lib/dev/README.md` — note production service supersedes dev-only simulate for real devices; keep `runDevLifecycleSimulate` for KPI-01 compacted profile.
  - [x] Run full `flutter test` + `flutter analyze`.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task F — Verification** (AC: #1–#3)
  - [x] Confirm `main.dart` / `app.dart` do not import `lib/dev/` in release paths.
  - [x] Manual (Android): inject 90d via tests or debug helper → trigger maintenance → verify row drop in log; optional `getDatabasesPath()` size before/after VACUUM.
  - [x] Regression: `test/data/repositories/step_repository_chart_aggregates_test.dart` post-compaction conservation still passes.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 4.1:**
- Production `DataLifecycleService` + FR11 downsampling + FR12 VACUUM/optimize
- Promote `lifecycle_compaction.dart` to `lib/core/lifecycle/`
- `StepRepository` administrative downsample method
- Android weekly WorkManager maintenance task
- iOS opportunistic maintenance on foreground resume
- `last_database_optimized_at` preference (FR-13 precursor — display in **Story 4.2**)
- Tests proving compaction math + bounded growth

**Out of scope — defer to later stories:**
- My Data footprint UI, "last optimized" relative time display → **Story 4.2** (this story only persists timestamp)
- `getFootprint()`, sample count / DB size queries for UI → **Story 4.2**
- CSV export/import, purge → **Stories 4.3–4.5**
- Pre/post compaction **CSV export** round-trip test → **Story 4.3** (FR-11 export consequence; unit compaction tests suffice here)
- History/Today cubit refresh after maintenance → optional; charts already sum all resolutions (3.2). Wire explicit refresh in 4.2 when My Data exists.
- SQLCipher, archive tier, reversible compaction → Phase 1+ / never Phase 0

Epic 4 opens here: production lifecycle is the foundation for sovereignty UI in 4.2+.

### Pipeline position (Epic 4 — first story)

```text
Epic 2 ingestion → SQLite (5min buckets)     ✅
Epic 3 dev inject + LifecycleSimulator preview ✅
        │
        v
DataLifecycleService + WM weekly maintenance   ← THIS STORY
        │
        v
My Data footprint + background status (4.2)
CSV export / import / purge (4.3–4.5)
```

### Architecture contracts (must match exactly)

**FR11 tier table** ([Source: `architecture.md` — Lifecycle, `epics.md` FR11]):

| Local calendar age (relative to reference now) | Resolution kept | Compaction action |
|-----------------------------------------------|-----------------|-------------------|
| 0–29 days (tier 1) | `5min` | No change |
| 30–364 days (tier 2) | `1hour` | Merge 12× consecutive 5min within same local hour → delete 5min rows |
| ≥365 days (tier 3) | `1d` | Merge 24× consecutive `1hour` within same local day → delete hourly rows |
| ≥365 days catch-up | `1d` | Merge 288× consecutive 5min within same local day if never hourly-compacted |

**Destructive policy:** Finer rows deleted after coarser row inserted in **same transaction** (D-24). Total step `value` sum across all rows must be unchanged.

**Resolution strings** (already in codebase — do not rename):
- `5min`, `1hour`, `1d` — see `normalized_step_bucket.dart`

**Write path (D-03, administrative writes):**

| Caller | Method | Notes |
|--------|--------|-------|
| `BackgroundCollector` | `upsertIngestionBucket()` | Unchanged — only ingestion writer |
| `DataLifecycleService` | `StepRepository.downsampleStepSamples()` | NEW — compaction only |
| `DataInjectService` / tests | `insertDevSamplesBatch()` | Unchanged — dev only |
| `LifecycleSimulator` | Delegates to shared compaction | Dev preview; keep `kDebugMode` entry |
| UI / Cubits | Read methods only | Never open transactions for compaction |

**VACUUM policy** ([Source: `epics.md` line 145, `architecture.md` line 359]):
- **Never** on UI thread during build/layout
- Android: weekly WM background isolate
- iOS: opportunistic after `AppLifecycleState.resumed` when due
- Sequence: `PRAGMA optimize;` then `VACUUM;`
- Phase 0: no acceptance criterion requiring iOS background VACUUM reliability

**TimeProvider (D-25):** Reference "now" for tier boundaries must use `clock.snapshot()` — same as `LifecycleSimulator` today. Enables deterministic tests with `FakeTimeProvider`.

**WorkManager (D-04, D-06):** Maintenance task is **separate** from `kStepCollectionTaskName`. Reuse patterns from Story 2.10:
- `@pragma('vm:entry-point')` dispatcher
- `WidgetsFlutterBinding.ensureInitialized()` + `DartPluginRegistrant.ensureInitialized()`
- `openIsolateAstraDatabase(databasePath: inputData['databasePath'])`
- Pass `databasePath` from `main.dart` registration

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 4.1 changes | Must preserve |
|------|---------------|------------------|---------------|
| `lib/dev/lifecycle_compaction.dart` | Pure FR11 merge/age helpers (~480 lines) | Move to `lib/core/lifecycle/` | All tier constants, group completeness rules, tests |
| `lib/dev/lifecycle_simulator.dart` | Dev-only compaction orchestration + direct `txn.insert/delete` | Delegate to repository/service; shrink | `runDevLifecycleSimulate` + `LifecycleSimResult` for KPI-01 |
| `lib/core/services/data_lifecycle_service.dart` | **Does not exist** | Create | — |
| `lib/data/repositories/step_repository.dart` | Ingestion upsert, chart aggregates, dev batch insert, counts | Add `downsampleStepSamples()` | `upsertIngestionBucket`, `getChartDailyAggregates`, `getTodaySteps` |
| `lib/core/services/workmanager_callback.dart` | Step collection task only | Add maintenance task branch | Existing step collection behavior |
| `lib/main.dart` | Registers step WM | Register maintenance WM (Android) | Notification init order; cancel-before-init |
| `lib/app.dart` | Resume → collect + Today refresh | Add opportunistic maintenance call on resume (iOS + Android) | Live pipeline, monotonic Today, FGS matrix |
| `lib/core/di/app_dependencies.dart` | No lifecycle service | Expose `dataLifecycleService` | All existing deps |
| `lib/core/constants/preference_keys.dart` | No last-optimized key | Add `kLastDatabaseOptimizedAtKey` | Existing keys |
| `test/dev/lifecycle_simulator_test.dart` | 10 080 row assertions | Update imports only if moved | Expected counts unchanged |

### Recommended file layout

```text
lib/core/lifecycle/lifecycle_compaction.dart          # MOVED from lib/dev/
lib/core/lifecycle/sample_compaction_runner.dart      # NEW (shared orchestration)
lib/core/services/data_lifecycle_service.dart         # NEW
lib/data/repositories/step_repository.dart            # UPDATE — downsample API
lib/core/services/workmanager_callback.dart           # UPDATE — maintenance task
lib/core/services/workmanager_tasks.dart              # UPDATE — constants
lib/core/constants/preference_keys.dart               # UPDATE
lib/data/repositories/user_preferences_repository.dart # UPDATE
lib/core/di/app_dependencies.dart                     # UPDATE
lib/main.dart                                         # UPDATE — register maintenance WM
lib/app.dart                                          # UPDATE — resume maintenance hook
lib/dev/lifecycle_simulator.dart                      # UPDATE — delegate
lib/dev/README.md                                     # UPDATE

test/core/services/data_lifecycle_service_test.dart   # NEW
test/data/repositories/step_repository_downsample_test.dart  # NEW (or merge into existing repo tests)
test/core/services/workmanager_callback_test.dart     # UPDATE
```

### Compaction implementation strategy (minimize diff)

**Preferred approach:** Extract the three `_compactTier*` loops from `LifecycleSimulator` into `SampleCompactionRunner` that accepts a `CompactionWriter` callback or `Transaction` + repository methods. `StepRepository.downsampleStepSamples()` calls the runner inside `db.transaction()`.

**Do not** duplicate tier logic in service and simulator. Story 3.1 explicitly extracted helpers for Epic 4.1 reuse ([Source: `stories/3-1-dev-data-inject-and-lifecycle-simulator.md`]).

**UUID generation:** Production compaction uses `StepRepository`'s injected `Uuid` (same as ingestion) for new hourly/daily row ids.

### Expected test metrics (90-day inject at anchor)

| Stage | Rows | Resolutions |
|-------|------|-------------|
| After `inject90Days()` | 25 920 | all `5min` |
| After first `downsample` / maintenance | 10 080 | 8 640 `5min` + 1 440 `1hour` |
| After second maintenance (no new data) | 10 080 | unchanged (idempotent) |

Value conservation: `SUM(value)` identical before/after (existing test pattern in `lifecycle_simulator_test.dart`).

### NFR storage budgets (context for AC #3)

| Horizon | Target (steps-only, lifecycle active) |
|---------|----------------------------------------|
| 1 year | < 50 MB (NFR-7) |
| 5 years | < 200 MB (NFR-8) |

90-day inject + compaction is the Phase 0 proof point; full 1-year soak is not required in this story but idempotent maintenance must not grow row count or file size on repeated runs.

### Architecture compliance

| Decision / invariant | Requirement for 4.1 |
|----------------------|---------------------|
| D-24 | Downsample + delete in single `db.transaction()` |
| D-25 | `TimeProvider` for tier age boundaries |
| D-06 | Maintenance WM uses `openIsolateAstraDatabase` |
| FR-11 | Three tiers + destructive compaction + `resolution` field update |
| FR-12 | Weekly maintenance + off-UI-thread VACUUM |
| NFR-7 | Bounded growth demonstrated on 90d inject + repeat maintenance |

### Anti-patterns (do NOT)

- Call `VACUUM` synchronously on the UI isolate during widget build or `await` it on resume **on the main thread** without offloading.
- Add compaction `db.insert`/`delete` calls in `DataLifecycleService` directly — use `StepRepository`.
- Route dev inject through `downsample` or change `upsertIngestionBucket` semantics.
- Break `LifecycleSimulator` expected counts used by `chart_benchmark.dart` compacted profile (`kDatasetLabelCompacted10080`).
- Implement My Data UI or footprint display (4.2).
- Add new pub dependencies for scheduling unless Baptiste approves — `workmanager` already present.

### Previous story intelligence (Epic 3 — immediate predecessor)

Story **3.4** (done) validated KPI-01 on injected data; optional **10 080** row compacted profile depends on `LifecycleSimulator` remaining stable.

Story **3.1** (done) deliverables to **reuse, not rewrite**:
- `lifecycle_compaction.dart` pure functions — production-ready
- `LifecycleSimulator` transaction pattern — promote to service
- `insertDevSamplesBatch`, `countStepSamplesByResolution` — test fixtures
- Dev README row-count tables — update, do not delete

Story **3.2** proved `getChartDailyAggregates` sums all resolutions — post-compaction daily totals unchanged; regression test must stay green.

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `17948ad` | Epic 4 stories 4.8–4.9 planned — no lifecycle code |
| `f7103f8` | WM/notification init race fix — preserve `cancelStepCollectionWorkmanager` before init when adding maintenance registration |
| `ea0b8fc` / Epic 2 close | Passive pipeline complete — lifecycle is next storage boundary |

### Library / framework notes

- **sqflite** `VACUUM` and `PRAGMA optimize` via `db.execute()` — run in background isolate or `compute`; closing connection before VACUUM may be required on some platforms; close/reopen pattern used elsewhere: follow `openIsolateAstraDatabase` lifecycle in WM callback.
- **workmanager** `0.9.x` — minimum periodic interval on Android is 15 minutes API-wise; **7-day** `frequency` is valid for weekly maintenance task (separate `uniqueName` from step collection).
- No new packages expected for this story.

### Project context reference

- Review-before-commit workflow: `docs/project-context.md` — one sub-task per commit, review brief in French-friendly format.
- Update `docs/DEPENDENCIES.md` only if new packages added (unlikely).

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 4.1, FR11–FR12]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — Lifecycle table, D-24, administrative writes, FR-11–12 mapping]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` — §4.4 Data Lifecycle]
- [Source: `_bmad-output/implementation-artifacts/stories/3-1-dev-data-inject-and-lifecycle-simulator.md` — compaction preview]
- [Source: `lib/dev/lifecycle_simulator.dart` — orchestration to promote]
- [Source: `lib/dev/lifecycle_compaction.dart` — pure helpers to promote]
- [Source: `lib/core/services/workmanager_callback.dart` — WM isolate pattern]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

### Completion Notes List

- Sub-tasks A–F complete: production FR11 downsampling via `StepRepository.downsampleStepSamples()`, `DataLifecycleService` with weekly due logic + off-UI VACUUM, Android WM + iOS resume scheduling, bounded-growth tests on file DB.
- `flutter test` full suite green; chart aggregates post-compaction regression green.
- `main.dart` / `app.dart` have no `lib/dev/` imports.

### File List

- lib/core/lifecycle/lifecycle_compaction.dart
- lib/core/lifecycle/sample_compaction_runner.dart
- lib/core/services/data_lifecycle_service.dart
- lib/core/services/workmanager_tasks.dart
- lib/core/services/workmanager_callback.dart
- lib/core/constants/preference_keys.dart
- lib/core/di/app_dependencies.dart
- lib/data/repositories/step_repository.dart
- lib/data/repositories/user_preferences_repository.dart
- lib/dev/lifecycle_simulator.dart
- lib/dev/README.md
- lib/main.dart
- lib/app.dart
- test/core/services/data_lifecycle_service_test.dart
- test/core/services/workmanager_callback_test.dart
- test/core/di/app_dependencies_test.dart
- test/data/repositories/step_repository_downsample_test.dart
- test/dev/lifecycle_compaction_test.dart
- test/dev/lifecycle_simulator_test.dart
- lib/dev/lifecycle_compaction.dart (deleted)

## Story completion status

- Ultimate context engine analysis completed — comprehensive developer guide created
- Status: **done**
