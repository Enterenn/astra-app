# Story 3.1: Dev Data Inject and Lifecycle Simulator

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **builder**,
I want to inject 90 days of synthetic step data and simulate lifecycle aging,
So that I can benchmark charts and validate storage behavior without walking for months.

## Acceptance Criteria

1. **Given** `lib/dev/` tools gated by `kDebugMode`
   **When** inject command runs
   **Then** 90 days of valid `timeseries_samples` rows are written inside a transaction (FR28)
   **And** canonical sample shape and UUID ids are respected

2. **Given** injected data spans multiple resolution tiers after lifecycle simulation
   **When** downsampling simulator runs
   **Then** row counts drop predictably per FR11 tiers (dev-only preview of Epic 4 service)

3. **Given** inject + simulate completes
   **When** documented in dev README or script comment
   **Then** steps are reproducible for CI/manual benchmark (FR28)

## Tasks / Subtasks

- [x] **Sub-task A — Resolution constants + repository batch insert** (AC: #1)
  - [x] Add resolution constants alongside existing `kFiveMinuteResolution` in `lib/data/models/normalized_step_bucket.dart`:
    - `kHourlyResolution = '1hour'`
    - `kDailyResolution = '1d'`
  - [x] Add `StepRepository.insertDevSamplesBatch(List<TimeseriesSampleModel> samples)`:
    - Wrap entire batch in `db.transaction()`.
    - Use plain `INSERT` (not ingestion upsert) — each row has unique UUID `id` and unique bucket identity.
    - Document in dartdoc: **dev/test only** — only `DataInjectService` and unit tests may call; never production ingestion.
    - Guard entry with `assert(() { ... kDebugMode check ... return true; }())` so release builds strip the assert but method remains unreachable from UI if callers respect dev-only policy.
  - [x] Add `StepRepository.countStepSamples()` and optional `countStepSamplesByResolution()` helpers for test assertions (simple `SELECT COUNT(*)` — no business aggregation).
  - [x] Unit test: empty DB → insert batch of 3 samples → count = 3; duplicate UUID rejected by PK.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — `DataInjectService` (90-day synthetic inject)** (AC: #1, #3)
  - [x] Create `lib/dev/data_inject_service.dart`:
    - Constructor: `Database db`, `StepRepository repository`, optional `Random? rng` (default `Random(42)` for reproducibility).
    - `Future<DataInjectResult> inject90Days({required TimeProvider clock})`:
      - Anchor end date from `clock.snapshot().nowUtc` (local calendar day via `LocalDayCalculator` + clock offset).
      - Generate **exactly 90 local calendar days** ending on anchor day (inclusive).
      - Per day: **288 five-minute buckets** (00:00–23:55 local, aligned via UTC floor matching `StepNormalizer._floorToFiveMinuteUtc` logic).
      - Metadata: `provider = kInternalPhoneProvider`, `device_id = kSmartphoneDeviceId`, `type = steps`, `unit = count`, `resolution = kFiveMinuteResolution`.
      - `zone_offset` from injected clock (`TimestampCodec.formatZoneOffset(clock.currentZoneOffset())`) — immutable per row.
      - Step values: seeded pseudo-random **integers** 0–250 per bucket; optional day-level multiplier so daily totals land ~4 000–12 000 (realistic, not flat noise).
      - Build `TimeseriesSampleModel` rows with UUID v4 per row (`uuid` package — same as repository).
      - Call `repository.insertDevSamplesBatch()` inside one transaction (repository owns txn scope).
      - Return `DataInjectResult` with `{daysInjected: 90, bucketsInserted: 25920, anchorUtc: ...}`.
    - Top-level entry `Future<DataInjectResult> runDevInject(...)` asserts `kDebugMode`.
  - [x] **Expected row count (full inject):** `90 × 288 = 25 920` rows at `5min` resolution.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — `LifecycleSimulator` (FR11 preview)** (AC: #2)
  - [x] Create `lib/dev/lifecycle_simulator.dart`:
    - Constructor: `Database db`, `StepRepository repository`, `TimeProvider clock`.
    - `Future<LifecycleSimResult> simulateDownsampling()`:
      - Reference "now" from injected `clock.snapshot()`.
      - **Tier 2 (31–365 days old):** For step samples with `resolution = '5min'` whose `start_time` falls in age window `[31d, 365d)` relative to reference now:
        - Group by `(provider, device_id, local hour bucket)` using UTC timestamps + stored `zone_offset`.
        - Merge each complete group of up to 12 consecutive 5-min buckets within the same clock hour → one hourly row (`resolution = '1hour'`, `value = sum`, new UUID, `start_time` = hour start UTC, `end_time` = hour end UTC, preserve `zone_offset`).
        - Delete merged finer rows in same transaction.
      - **Tier 3 (>365 days):** Implement the same pattern (24 hourly → 1 daily) but document that **90-day inject only exercises Tier 1→2**; Tier 3 logic must exist for Epic 4 reuse but tests assert Tier 3 is no-op on 90-day dataset.
      - All compaction runs inside `db.transaction()` — never partial writes (D-24).
    - Return `{rowsBefore, rowsAfter, fiveMinRemaining, hourlyCreated, dailyCreated}`.
  - [x] **Predictable counts for default 90-day full inject + simulate at anchor end:**
    | Tier | Age window | Resolution after | Expected rows |
    |------|------------|----------------|---------------|
    | Recent | 0–30 days | `5min` (unchanged) | 30 × 288 = **8 640** |
    | Mid | 31–90 days | `1hour` (compacted) | 60 × 24 = **1 440** |
    | **Total** | | | **10 080** |
    | Reduction | | | 25 920 → 10 080 (**~61%** drop) |
  - [x] Extract pure helper functions (e.g. `_ageInDays`, `_mergeBucketsToHourly`) at top of file or `lib/dev/lifecycle_compaction.dart` so Epic 4.1 `DataLifecycleService` can relocate them with minimal diff.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Tests + reproducibility docs** (AC: #2, #3)
  - [x] `test/dev/data_inject_service_test.dart`:
    - In-memory DB via `openAstraDatabase(databasePath: inMemoryDatabasePath)` + `FakeTimeProvider` fixed anchor.
    - Inject → assert 25 920 rows, all `type=steps`, all `resolution=5min`, all UUIDs unique, all values integer ≥ 0.
    - Re-run inject on non-empty DB → either clear-first policy documented or assert throws/warns (choose **clear existing step samples first** inside inject for idempotent dev workflow — delete `type='steps'` rows in txn before insert; document in README).
  - [x] `test/dev/lifecycle_simulator_test.dart`:
    - Inject + simulate → assert total rows = 10 080.
    - Assert resolution breakdown: 8 640 at `5min`, 1 440 at `1hour`, 0 at `1d`.
    - Assert sum of all step `value` fields identical before and after compaction (no data loss — only granularity change).
  - [x] Create `lib/dev/README.md`:
    - Purpose: FR28 dev tooling for Epic 3 chart/benchmark stories.
    - Repro commands:
      ```bash
      flutter test test/dev/data_inject_service_test.dart
      flutter test test/dev/lifecycle_simulator_test.dart
      ```
    - Document fixed seed (`Random(42)`), default anchor, expected row counts table.
    - Explicit **release-build safety**: `lib/dev/` never imported from `main.dart` or production widgets without `kDebugMode` guard; tree-shaking note for Flutter release.
  - [x] Run `flutter analyze` and `flutter test`.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Verification** (AC: #1–#3)
  - [x] Confirm no `import` of `lib/dev/` from release code paths (`main.dart`, `app.dart`, presentation layer).
  - [x] Review brief explains row-count math in plain language for Baptiste.
  - [x] Note in review brief: Story 3.2 consumes this dataset for `getChartDailyAggregates`; Story 3.4 for KPI-01 benchmark; Story 4.1 promotes simulator logic to `DataLifecycleService`.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 3.1:**
- `lib/dev/data_inject_service.dart` — 90-day synthetic step inject (FR28).
- `lib/dev/lifecycle_simulator.dart` — dev-only FR11 downsampling preview.
- `lib/dev/README.md` — reproducibility documentation.
- `StepRepository.insertDevSamplesBatch()` + count helpers for dev/test.
- Resolution constants `1hour` / `1d`.
- Unit tests proving inject row counts, compaction ratios, and value conservation.

**Out of scope — defer to later stories:**
- `StepRepository.getChartDailyAggregates()`, `ChartDayAggregate` model → **Story 3.2**.
- History screen, `HistoryCubit`, `StepBarChart`, `PeriodToggle` → **Story 3.3**.
- `chart_benchmark.dart`, KPI-01 p95 harness → **Story 3.4**.
- Production `DataLifecycleService`, WorkManager maintenance job, VACUUM → **Story 4.1**.
- Debug UI menu / FAB to trigger inject from running app → optional nice-to-have; **tests + README satisfy AC** if no UI is added.
- CSV export/import, purge → **Epic 4**.
- Travel/mixed `zone_offset` inject scenario → **Story 3.2** tests (inject uses single offset; 3.2 adds mixed-offset fixture separately if needed).

Do not over-implement. This story is **dev tooling + compaction preview** — not History UI or production lifecycle scheduling.

### Pipeline position (Epic 3 — first story)

```text
lib/dev/data_inject_service.dart          ← THIS STORY (90d synthetic rows)
        │
        v
lib/dev/lifecycle_simulator.dart          ← THIS STORY (FR11 preview)
        │
        v
StepRepository.getChartDailyAggregates()  ← Story 3.2 (needs injected data)
        │
        v
HistoryCubit + StepBarChart               ← Story 3.3
        │
        v
lib/dev/chart_benchmark.dart              ← Story 3.4 (KPI-01)
        │
        v
DataLifecycleService (production)         ← Story 4.1 (promote compaction logic)
```

Epic 2 delivered live ingestion → SQLite. Epic 3 starts by seeding realistic volume for chart development and performance proof.

### Architecture contracts (must match exactly)

**Write path (D-03, D-19, D-24):**

| Caller | Method | Notes |
|--------|--------|-------|
| `BackgroundCollector` (production) | `upsertIngestionBucket()` | Unchanged — do not route inject through this |
| `DataInjectService` (dev) | `insertDevSamplesBatch()` | New batch insert; txn-owned |
| `LifecycleSimulator` (dev) | Direct txn via repository or dedicated `compactDevSamples()` | Must use transactions |
| UI / Cubits | **read methods only** | Never call dev inject |

**All `timeseries_samples` writes** go through `StepRepository` methods — no direct `db.insert('timeseries_samples', …)` outside the repository ([Source: `architecture.md` — Pattern Examples]).

**Canonical row shape** ([Source: `migrations.dart`, Story 2.1]):

| Column | Inject value |
|--------|--------------|
| `id` | UUID v4 string |
| `start_time`, `end_time` | ISO 8601 UTC with `Z` via `TimestampCodec.formatUtc` |
| `type` | `'steps'` |
| `value` | Non-negative integer |
| `unit` | `'count'` |
| `resolution` | `'5min'` → after simulate: `'1hour'` / `'1d'` |
| `provider` | `kInternalPhoneProvider` (`'internal_phone'`) |
| `device_id` | `kSmartphoneDeviceId` (`'smartphone'`) |
| `zone_offset` | `±HH:MM` from injected clock — immutable per row |

**FR11 downsampling tiers** ([Source: `addendum.md` §3, `architecture.md` — Lifecycle]):

| Data age (relative to reference now) | Storage resolution | Compaction action |
|--------------------------------------|-------------------|-------------------|
| 0–30 days | 5 min | Keep as-is |
| 31–365 days | 1 hour | Merge 12× 5-min → 1 hourly; delete finer rows |
| > 365 days | 1 day | Merge 24× hourly → 1 daily; delete finer rows |

Compaction is **destructive** — finer rows deleted after coarser aggregate written. Simulator must preserve total step counts (sum of `value`) even as row count drops.

**kDebugMode gate** ([Source: `architecture.md` — Agent Rules #17]):

```dart
import 'package:flutter/foundation.dart';

Future<T> runDevInject<T>(...) async {
  if (!kDebugMode) {
    throw StateError('Dev inject is only available in debug builds');
  }
  ...
}
```

Never import `lib/dev/` from release-critical paths without guard. Prefer test entry points for CI reproducibility.

**TimeProvider (D-25):** Inject and simulator accept injected `TimeProvider` / `FakeTimeProvider` — no `DateTime.now()` inside dev services.

### Current code state

| Path | Current state | What 3.1 changes | Must preserve |
|------|---------------|------------------|---------------|
| `lib/dev/` | **Does not exist** | Create folder + 3 files | — |
| `lib/data/repositories/step_repository.dart` | `upsertIngestionBucket`, `getTodaySteps`, `getLastIngestionUtc` | Add `insertDevSamplesBatch`, count helpers | Existing upsert/today semantics unchanged |
| `lib/data/models/timeseries_sample_model.dart` | Full row map + `fromNormalizedBucket` | Read-only reuse | Do not change codec behavior |
| `lib/data/models/normalized_step_bucket.dart` | `kFiveMinuteResolution` only | Add hourly/daily constants | Existing defaults unchanged |
| `lib/core/database/migrations.dart` | v2 schema | Read-only | Do not bump `kDbVersion` |
| `lib/core/di/app_dependencies.dart` | Production DI | **No change required** | Dev services instantiated in tests only for 3.1 |
| `lib/data/datasources/data_ingestion_source.dart` | Provider/device constants | Read-only reuse | Use `kInternalPhoneProvider`, `kSmartphoneDeviceId` |
| `lib/core/time/local_day_calculator.dart` | Travel-safe local day | Reuse for hour grouping in simulator | Do not use SQL `date()` |
| `test/helpers/sqflite_test_helper.dart` | FFI setup | Reuse | — |
| `test/core/time/fake_time_provider.dart` | Fixed clock | Reuse for deterministic inject | — |

`DataLifecycleService`, `ChartDayAggregate`, `getChartDailyAggregates`, `lib/dev/chart_benchmark.dart` **do not exist yet**.

### Recommended file layout

```text
lib/data/models/normalized_step_bucket.dart   # UPDATE (resolution constants)
lib/data/repositories/step_repository.dart      # UPDATE (batch insert + counts)
lib/dev/data_inject_service.dart                # NEW
lib/dev/lifecycle_simulator.dart                # NEW
lib/dev/README.md                               # NEW

test/dev/data_inject_service_test.dart          # NEW
test/dev/lifecycle_simulator_test.dart          # NEW
test/data/repositories/step_repository_dev_batch_test.dart  # NEW (optional split from inject tests)
```

### Five-minute bucket alignment (must match normalizer)

Reuse the same UTC floor logic as `StepNormalizer`:

```dart
DateTime floorToFiveMinuteUtc(DateTime value) {
  final utc = value.toUtc();
  return DateTime.utc(
    utc.year, utc.month, utc.day, utc.hour,
    utc.minute - (utc.minute % 5),
  );
}
```

Each bucket spans `[start, start + 5min)`. End time stored as `start + 5min` (matches existing upsert tests: `08:00–08:05`).

### Idempotent inject policy

Dev inject should be **repeatable** for benchmark workflows:

1. Begin transaction.
2. `DELETE FROM timeseries_samples WHERE type = 'steps'` (dev inject replaces synthetic steps only — preserves `user_preferences`).
3. Insert 25 920 fresh rows.
4. Commit.

Document this in `lib/dev/README.md`. Real device data loss acceptable in debug — warn in README ("clears existing step samples").

### Lifecycle simulator sketch

```dart
Future<LifecycleSimResult> simulateDownsampling() async {
  final now = clock.snapshot().nowUtc;
  final rowsBefore = await repository.countStepSamples();

  await db.transaction((txn) async {
    // 1. Load all 5min step rows
    // 2. For each row where ageDays in [31, 365): schedule hourly merge groups
    // 3. For each complete hour group: INSERT hourly aggregate, DELETE 5min rows
    // 4. (Tier 3) For ageDays > 365: merge hourly → daily — no-op on 90d dataset
  });

  return LifecycleSimResult(...);
}
```

Age calculation: `now.difference(startTimeUtc).inDays` (UTC-based day count sufficient for dev simulator; Epic 4 may refine with `LocalDayCalculator` if needed).

### Architecture compliance

| Decision / invariant | Requirement for 3.1 |
|----------------------|---------------------|
| D-19 | Bucket identity UNIQUE — inject generates non-overlapping buckets |
| D-21 | No chart aggregation in this story — inject raw samples only |
| D-24 | Batch inject + compaction in `db.transaction()` |
| D-25 | `TimeProvider` injected — `FakeTimeProvider` in tests |
| FR28 | 90-day inject + lifecycle + documented reproducibility |
| FR11 (preview) | Tier 1→2 compaction with predictable row counts |
| Agent rule #17 | `kDebugMode` gate on dev entry points |

### Anti-patterns

- Do not call `upsertIngestionBucket()` for inject — wrong semantics (ingestion path, upsert on conflict).
- Do not add `getChartDailyAggregates()` yet — Story 3.2.
- Do not wire inject into `AppDependencies.create()` or `main.dart` without `kDebugMode` guard.
- Do not use SQL `date(start_time, zone_offset)` for grouping.
- Do not store fractional step values — DB CHECK rejects non-integer steps.
- Do not create production `DataLifecycleService` — dev simulator only; Epic 4 promotes logic.
- Do not import `dart:io` network or external APIs — local SQLite only.
- Do not delete `user_preferences` during inject clear — step samples only.

### Testing requirements

| Area | Requirement |
|------|-------------|
| `data_inject_service` | 25 920 rows; UUID unique; integer values; canonical columns |
| `lifecycle_simulator` | 10 080 rows post-sim; resolution breakdown; sum conservation |
| `step_repository` batch | Transaction atomicity; PK enforcement |
| Regression | All Epic 2 tests pass unchanged |
| Reproducibility | Fixed `Random(42)` → identical totals across runs |

Run: `flutter analyze`, `flutter test test/dev/`, full `flutter test`

### Previous story intelligence (Epic 2 complete — 2.7)

Epic 2 established the full ingestion → SQLite → Today pipeline:

- `StepRepository.upsertIngestionBucket()` — ingestion-only write path with bucket identity upsert.
- `TimeseriesSampleModel` — canonical row mapping; UUID on insert only.
- `LocalDayCalculator` — per-row `zone_offset` grouping (reuse in simulator hour boundaries if needed).
- `FakeTimeProvider` + `openAstraDatabase(inMemoryDatabasePath)` — standard test pattern.
- Review-before-commit workflow — one commit per sub-task ([Source: `docs/project-context.md`]).
- `BackgroundCollector` / `LiveStepMonitor` — production pipeline; dev inject bypasses entirely.

Story 2.3 explicitly deferred dev inject to Story 3.1 — this is the intended hook point.

### Git intelligence (recent commits)

Recent work focused on live step pipeline (not dev tooling):

- `e669041` — TodayCubit live refresh wiring
- `a6ba815` — `LiveStepMonitor` as sole pedometer stream owner
- `4157518` — `StepIncrementCalculator` extraction

No existing `lib/dev/` code — greenfield for this story. Follow repository test patterns from `test/data/repositories/step_repository_upsert_test.dart`.

### Latest tech information

| Technology | Version / note |
|------------|----------------|
| Flutter | 3.44.0 stable (architecture baseline) |
| `sqflite` | ^2.4.2+1 — use `db.transaction()` for batch writes |
| `uuid` | ^4.4.0 — `Uuid().v4()` per sample |
| `sqflite_common_ffi` | ^2.4.0+3 — in-memory tests via `setUpSqfliteFfi()` |
| `kDebugMode` | `package:flutter/foundation.dart` — compile-time constant; true in `flutter test` |

No new pubspec dependencies expected for this story.

### Project context reference

- Review-before-commit gate applies to every sub-task ([Source: `docs/project-context.md`])
- Update `docs/DEPENDENCIES.md` only if new packages added (unlikely)
- Story files live in `_bmad-output/implementation-artifacts/stories/`

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Epic 3, Story 3.1]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — D-19, D-21, D-24, D-25, lib/dev/ structure, FR11 lifecycle table]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` — FR-28, FR-11]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/addendum.md` — §3 Data Lifecycle tiers]
- [Source: `lib/core/database/migrations.dart` — timeseries_samples DDL]
- [Source: `lib/data/repositories/step_repository.dart` — existing write/read API]
- [Source: `_bmad-output/implementation-artifacts/stories/2-3-step-repository-and-time-semantics.md` — deferred dev inject note]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Tier age uses local calendar days via `LocalDayCalculator` (UTC `inDays` caused ~110 extra rows at tier boundary).

### Completion Notes List

- ✅ Sub-task A: `insertDevSamplesBatch`, resolution constants, batch unit tests (`a559ed1`).
- ✅ Sub-task B: `DataInjectService` 90-day inject with `Random(42)` (`d5a5518`).
- ✅ Sub-task C: `LifecycleSimulator` + `lifecycle_compaction.dart` helpers (`0ba223d`).
- ✅ Sub-task D: dev tests (5/5), README, clear-first inject policy (`b4286d8`).
- ✅ Sub-task E: no `lib/dev/` imports in production paths; row-count math verified.
- All ACs satisfied: FR28 inject + docs, FR11 predictable compaction, `kDebugMode` gates.

### File List

- `lib/data/models/normalized_step_bucket.dart` (modified)
- `lib/data/repositories/step_repository.dart` (modified)
- `lib/dev/data_inject_service.dart` (new)
- `lib/dev/lifecycle_simulator.dart` (new)
- `lib/dev/lifecycle_compaction.dart` (new)
- `lib/dev/README.md` (new)
- `test/data/repositories/step_repository_dev_batch_test.dart` (new)
- `test/dev/data_inject_service_test.dart` (new)
- `test/dev/lifecycle_simulator_test.dart` (new)

### Change Log

- 2026-06-02: Story 3.1 implemented — dev inject, lifecycle simulator, tests, and README (5 commits on main).
