# Story 3.2: History Chart Data Aggregation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want history queries to return pre-aggregated daily totals,
So that charts load instantly even with months of data.

## Acceptance Criteria

1. **Given** 90 days of injected step samples
   **When** `StepRepository.getChartDailyAggregates(days: 7)` and `(days: 30)` are called
   **Then** `List<ChartDayAggregate>` returns at most ~7 or ~30 items (NFR1, architecture D-21)
   **And** UI/widgets perform zero business aggregation

2. **Given** samples with mixed `zone_offset` (travel scenario test)
   **When** daily totals are computed
   **Then** grouping uses each row's stored offset via `LocalDayCalculator`

3. **Given** repository read methods
   **When** called from `HistoryCubit`
   **Then** no direct SQL from presentation layer

## Tasks / Subtasks

- [x] **Sub-task A — `ChartDayAggregate` view model** (AC: #1)
  - [x] Create `lib/data/models/chart_day_aggregate.dart`:
    - Fields: `final DateTime localDay` (date-only UTC `DateTime` per `LocalDayCalculator` convention), `final int totalSteps`.
    - Immutable class with `const` constructor, `==` / `hashCode` (or equatable-free value equality via manual override — match `TimeseriesSampleModel` style).
    - Document: **read model only** — produced by repository; consumed by `HistoryCubit` / `StepBarChart` in Story 3.3.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — `StepRepository.getChartDailyAggregates()`** (AC: #1–#3)
  - [x] Add method signature:
    ```dart
    Future<List<ChartDayAggregate>> getChartDailyAggregates({required int days});
    ```
  - [x] **Phase 0 contract:** `days` must be `7` or `30` — throw `ArgumentError` otherwise (History only exposes these two ranges).
  - [x] **Reference window** (mirror `getTodaySteps()` clock usage):
    1. `timeSnapshot = clock.snapshot()`.
    2. `referenceToday = LocalDayCalculator.localDay(utc: timeSnapshot.nowUtc, zoneOffset: TimestampCodec.formatZoneOffset(timeSnapshot.zoneOffset))`.
    3. `windowStart = referenceToday.subtract(Duration(days: days - 1))` (inclusive range `[windowStart, referenceToday]`).
  - [x] **Aggregation algorithm** (Dart-side — **not** SQL `date()`):
    1. Load step rows with optional coarse SQL `start_time` lower bound for perf (UTC buffer ≥ `windowStart - 1 day` — still compute `local_day` per row in Dart).
    2. For each row: `rowLocalDay = LocalDayCalculator.localDay(utc: sample.startTimeUtc, zoneOffset: sample.zoneOffset)`.
    3. Include row when `rowLocalDay` is within `[windowStart, referenceToday]` inclusive.
    4. Sum `sample.value.toInt()` into `Map<DateTime, int>` keyed by `rowLocalDay`.
    5. **Zero-fill:** emit one `ChartDayAggregate` per calendar day in the inclusive window (even when `totalSteps == 0`) so Story 3.3 chart axis is stable.
    6. Sort **descending** by `localDay` (newest first) — matches architecture pattern example.
  - [x] **Multi-resolution:** sum all resolutions (`5min`, `1hour`, `1d`) — post-compaction rows must aggregate identically to pre-compaction daily totals.
  - [x] Reuse `TimeseriesSampleModel.fromMap` — do not parse timestamps ad hoc in the loop.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Unit tests** (AC: #1, #2)
  - [x] Create `test/data/repositories/step_repository_chart_aggregates_test.dart`:
    - **7d / 30d row counts:** inject 90 days via `DataInjectService` + `FakeTimeProvider` (anchor `2026-06-02T12:00:00Z`, `+02:00`) → `getChartDailyAggregates(days: 7)` returns **7** items; `days: 30` returns **30** items; each `totalSteps > 0`.
    - **Window boundaries:** fixed clock on anchor day → oldest item in 7d result equals `referenceToday - 6 days`; no item outside window.
    - **Travel / mixed offset:** hand-insert two buckets sharing UTC instant but different `zone_offset` (reuse pattern from `step_repository_today_test.dart`) → each lands on correct local day aggregate; totals match expected split.
    - **Post-compaction:** inject + `LifecycleSimulator.simulateDownsampling()` → daily totals for 7d window **unchanged** vs pre-simulate (value conservation across resolutions).
    - **Empty DB:** returns 7 (or 30) zero-filled entries when no samples exist.
    - **Invalid days:** `getChartDailyAggregates(days: 14)` throws `ArgumentError`.
  - [x] Run `flutter test test/data/repositories/step_repository_chart_aggregates_test.dart`.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Verification** (AC: #1–#3)
  - [x] Run `flutter analyze` and full `flutter test`.
  - [x] Confirm no presentation-layer SQL (`HistoryScreen` remains placeholder — no cubit yet).
  - [x] Review brief notes deferrals: `HistoryCubit`, `StepBarChart`, weekly trend → Story 3.3; KPI-01 benchmark → Story 3.4.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 3.2:**
- `lib/data/models/chart_day_aggregate.dart` — chart read model (D-21).
- `StepRepository.getChartDailyAggregates({required int days})` — repository-side daily aggregation.
- Unit tests: 7d/30d counts, travel offset, post-compaction conservation, empty DB, invalid `days`.
- Reuse Story 3.1 dev inject + lifecycle simulator as test fixtures.

**Out of scope — defer to later stories:**
- `HistoryCubit`, `HistoryState`, `history_screen.dart` UI → **Story 3.3**.
- `StepBarChart`, `PeriodToggle`, `TrendChip`, weekly trend math (FR17) → **Story 3.3**.
- `lib/dev/chart_benchmark.dart`, KPI-01 p95 harness → **Story 3.4**.
- `fl_chart` dependency usage → **Story 3.3** (may already be in pubspec; no widget work here).
- SQL `GROUP BY date(...)` or SQLite timezone functions → **forbidden** (use Dart grouping).
- Chart aggregation in widgets or cubits → **forbidden** (D-21).
- Production `DataLifecycleService` → **Story 4.1**.

Do not over-implement. This story is **repository read model + aggregation only** — not History UI or benchmarks.

### Pipeline position (Epic 3 — second story)

```text
lib/dev/data_inject_service.dart          ← Story 3.1 (90d synthetic rows) ✅
        │
        v
lib/dev/lifecycle_simulator.dart          ← Story 3.1 (FR11 preview) ✅
        │
        v
ChartDayAggregate + getChartDailyAggregates()  ← THIS STORY
        │
        v
HistoryCubit + StepBarChart + PeriodToggle     ← Story 3.3
        │
        v
lib/dev/chart_benchmark.dart              ← Story 3.4 (KPI-01 p95)
        │
        v
DataLifecycleService (production)         ← Story 4.1
```

Story 3.1 seeded realistic volume (25 920 rows → 10 080 after simulate). Story 3.2 turns that into chart-ready daily points (~7 or ~30 per query).

### Architecture contracts (must match exactly)

**Read path (D-21, NFR-1, NFR-9):**

| Layer | Responsibility |
|-------|----------------|
| `StepRepository` | Load samples, compute `local_day` per row via `LocalDayCalculator`, sum to daily totals, return `List<ChartDayAggregate>` |
| `HistoryCubit` (3.3) | Call repository; hold selected period (7/30); **no aggregation math** |
| `StepBarChart` (3.3) | Bind pre-aggregated points to `fl_chart`; **no sum/group logic** |

**Forbidden patterns** ([Source: `architecture.md` — Anti-patterns]):
- ❌ `date(start_time, zone_offset)` in SQL
- ❌ Computing historical `local_day` from device **current** timezone
- ❌ Returning 8640+ points for 30-day view (raw 5-min buckets)
- ❌ Chart aggregation inside `StepBarChart` or `HistoryCubit`

**`ChartDayAggregate` shape** ([Source: `architecture.md` — Read model]):

```dart
class ChartDayAggregate {
  final DateTime localDay;  // date-only key from LocalDayCalculator
  final int totalSteps;
}
```

**`getChartDailyAggregates` API** ([Source: `architecture.md` — Read model]):
- `getChartDailyAggregates(days: 7|30)` → `List<ChartDayAggregate>` with **exactly `days` entries** when zero-fill enabled (~7 or ~30 items, never thousands).
- Sorted newest-first for History chart default (left = older, right = newer can be handled in 3.3 widget — document sort order in dartdoc).

**Algorithm sketch** (follow architecture good example):

```dart
Future<List<ChartDayAggregate>> getChartDailyAggregates({required int days}) async {
  if (days != 7 && days != 30) {
    throw ArgumentError.value(days, 'days', 'Phase 0 supports 7 or 30 only');
  }
  final snapshot = clock.snapshot();
  final referenceToday = LocalDayCalculator.localDay(
    utc: snapshot.nowUtc,
    zoneOffset: TimestampCodec.formatZoneOffset(snapshot.zoneOffset),
  );
  final windowStart = DateTime.utc(
    referenceToday.year,
    referenceToday.month,
    referenceToday.day,
  ).subtract(Duration(days: days - 1));

  // Optional: SQL prefilter start_time >= windowStart.subtract(1 day) UTC string
  final rows = await db.query('timeseries_samples', where: 'type = ?', whereArgs: [kStepSampleType]);

  final totals = <DateTime, int>{};
  for (final row in rows) {
    final sample = TimeseriesSampleModel.fromMap(row);
    final rowLocalDay = LocalDayCalculator.localDay(
      utc: sample.startTimeUtc,
      zoneOffset: sample.zoneOffset,
    );
    if (rowLocalDay.isBefore(windowStart) || rowLocalDay.isAfter(referenceToday)) {
      continue;
    }
    totals[rowLocalDay] = (totals[rowLocalDay] ?? 0) + sample.value.toInt();
  }

  final results = <ChartDayAggregate>[];
  for (var i = 0; i < days; i++) {
    final day = referenceToday.subtract(Duration(days: i));
    results.add(ChartDayAggregate(localDay: day, totalSteps: totals[day] ?? 0));
  }
  results.sort((a, b) => b.localDay.compareTo(a.localDay));
  return results;
}
```

**Post-compaction charts** ([Source: `architecture.md` — Lifecycle]): History queries aggregate whatever resolution exists in range — coarser buckets sum correctly. Tests must prove daily totals unchanged after `LifecycleSimulator`.

**Presentation layer AC #3:** Story 3.3's `HistoryCubit` will call `stepRepository.getChartDailyAggregates(days: …)` only. This story does **not** require creating `HistoryCubit` — verify no new SQL in `lib/presentation/`.

### Current code state

| Path | Current state | What 3.2 changes | Must preserve |
|------|---------------|------------------|---------------|
| `lib/data/models/chart_day_aggregate.dart` | **Does not exist** | Create read model | — |
| `lib/data/repositories/step_repository.dart` | `upsertIngestionBucket`, `getTodaySteps`, dev batch, counts, `getLastIngestionUtc` | Add `getChartDailyAggregates` | Existing methods unchanged |
| `lib/core/time/local_day_calculator.dart` | Travel-safe local day | Read-only reuse | Do not change semantics |
| `lib/dev/data_inject_service.dart` | 90-day inject ✅ | Test fixture only | No changes required |
| `lib/dev/lifecycle_simulator.dart` | FR11 preview ✅ | Test fixture only | No changes required |
| `lib/presentation/screens/history_screen.dart` | Placeholder `TabPlaceholderBody` | **No change** | Defer UI to 3.3 |
| `lib/presentation/cubits/history_cubit.dart` | **Does not exist** | **Do not create** | Story 3.3 |
| `test/data/repositories/step_repository_today_test.dart` | Travel offset patterns | Reference for chart travel test | Do not break |

### Recommended file layout

```text
lib/data/models/chart_day_aggregate.dart              # NEW
lib/data/repositories/step_repository.dart            # UPDATE (getChartDailyAggregates)
test/data/repositories/step_repository_chart_aggregates_test.dart  # NEW
```

No pubspec changes expected. No `AppDependencies` wiring required until Story 3.3 adds `HistoryCubit`.

### Performance notes (NFR-1 / KPI-01 prep)

- Story 3.2 unit tests assert **correctness and row count**, not latency.
- Story 3.4 owns p95 < 100ms benchmark on 90-day injected dataset.
- **Acceptable Phase 0 approach:** same full-table scan + Dart grouping as `getTodaySteps()` (~10k–26k rows) — proven sufficient for KPI-01 per architecture when output is ≤30 points.
- **Optional optimization (only if benchmark fails in 3.4):** add indexed `start_time` SQL lower bound before Dart loop; never move grouping to SQL `date()`.

### Anti-patterns

- Do not create `HistoryCubit`, `StepBarChart`, or replace `HistoryScreen` placeholder — Story 3.3.
- Do not add `chart_benchmark.dart` — Story 3.4.
- Do not aggregate in presentation layer to "save time" — D-21 violation.
- Do not use device `DateTime.now().timeZoneOffset` for historical rows.
- Do not return raw `timeseries_samples` rows to UI for client-side grouping.
- Do not change `getTodaySteps()` behavior or dev inject/lifecycle code unless a regression is found.
- Do not bump DB schema version — no migration needed.

### Testing requirements

| Area | Requirement |
|------|-------------|
| Row count | 7d → 7 entries; 30d → 30 entries on 90-day inject |
| Travel | Mixed `zone_offset` → correct per-row local day buckets |
| Compaction | inject + simulate → same daily totals as pre-simulate |
| Empty | Zero-filled list, all `totalSteps == 0` |
| Regression | All Epic 2 + Story 3.1 tests pass unchanged |
| Fixtures | `FakeTimeProvider`, `openAstraDatabase(inMemoryDatabasePath)`, `DataInjectService`, `LifecycleSimulator` |

Run: `flutter analyze`, `flutter test test/data/repositories/step_repository_chart_aggregates_test.dart`, full `flutter test`

### Previous story intelligence (Story 3.1 — done)

Story 3.1 delivered the dataset and patterns this story consumes:

- **`DataInjectService.inject90Days()`** — 25 920 rows at `5min`, `Random(42)`, anchor `2026-06-02T12:00:00Z` / `+02:00`.
- **`LifecycleSimulator.simulateDownsampling()`** — 10 080 rows (8 640 `5min` + 1 440 `1hour`); total step sum conserved.
- **`StepRepository.insertDevSamplesBatch(replaceExistingSteps: true)`** — idempotent dev inject.
- **Tier age uses `LocalDayCalculator`** — not raw UTC `inDays` (code review fix in 3.1).
- **Review-before-commit** — one commit per sub-task ([Source: `docs/project-context.md`]).
- Story 3.1 explicitly deferred `ChartDayAggregate` and `getChartDailyAggregates` to **this story**.

### Previous story intelligence (Story 2.3 — repository time semantics)

- `getTodaySteps()` established the **per-row `zone_offset` grouping pattern** — extend the same loop for multi-day window instead of single-day filter.
- Travel tests in `step_repository_today_test.dart` are the canonical fixture for mixed-offset scenarios.
- `TimeProvider.snapshot()` used for reference "today" — chart window anchor must use the same snapshot semantics.

### Git intelligence (recent commits)

Recent work completed Story 3.1 dev tooling:

- `ec9a5b0` — harden inject and lifecycle compaction after code review
- `b4286d8` — dev tests + README
- `0ba223d` — `LifecycleSimulator` FR11 preview
- `d5a5518` — `DataInjectService` 90-day inject

No existing chart aggregation code — greenfield on top of stable `StepRepository`. Follow test patterns from `step_repository_today_test.dart` and inject tests in `test/dev/`.

### Latest tech information

| Technology | Version / note |
|------------|----------------|
| Flutter | 3.44.0 stable (architecture baseline) |
| `sqflite` | ^2.4.2+1 — read via `db.query`; no new transactions for read-only aggregation |
| `fl_chart` | ^1.2.0 — **not used in 3.2**; Story 3.3 binds aggregates |
| `sqflite_common_ffi` | ^2.4.0+3 — in-memory tests via `setUpSqfliteFfi()` |

No new pubspec dependencies expected.

### Project context reference

- Review-before-commit gate applies to every sub-task ([Source: `docs/project-context.md`])
- Story files live in `_bmad-output/implementation-artifacts/stories/`
- Update `docs/DEPENDENCIES.md` only if new packages added (unlikely)

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Epic 3, Story 3.2]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — D-07, D-21, NFR-1, NFR-9, chart aggregation pattern, anti-patterns]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §2.4 History (chart consumes aggregates in 3.3)]
- [Source: `lib/data/repositories/step_repository.dart` — `getTodaySteps()` pattern to extend]
- [Source: `lib/core/time/local_day_calculator.dart`]
- [Source: `lib/dev/README.md` — inject row counts and reproducibility]
- [Source: `_bmad-output/implementation-artifacts/stories/3-1-dev-data-inject-and-lifecycle-simulator.md` — upstream dataset + deferrals]
- [Source: `_bmad-output/implementation-artifacts/stories/2-3-step-repository-and-time-semantics.md` — travel test patterns]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Implemented all sub-tasks A–D in single session; tests green before story marked review.

### Completion Notes List

- **Sub-task A:** Added immutable `ChartDayAggregate` read model with manual `==` / `hashCode`.
- **Sub-task B:** Added `getChartDailyAggregates({required int days})` to `StepRepository` — Dart-side grouping via `LocalDayCalculator`, zero-fill, newest-first sort, optional SQL `start_time` prefilter.
- **Sub-task C:** Eight unit tests cover 7d/30d counts, window boundaries, mixed offsets, SQL prefilter boundary (+14:00), post-compaction conservation (7d + 30d), empty DB, invalid `days`.
- **Sub-task D:** `flutter analyze` clean; full `flutter test` suite passes; no presentation-layer changes.
- **Code review:** Removed redundant sort; added 30-day boundary/sort tests, SQL prefilter edge-case test, and 30-day post-compaction conservation.

### File List

- `lib/data/models/chart_day_aggregate.dart` (new)
- `lib/data/repositories/step_repository.dart` (updated)
- `test/data/repositories/step_repository_chart_aggregates_test.dart` (new)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (updated)

### Change Log

- 2026-06-02: Story 3.2 — chart daily aggregation read model + repository method + unit tests.
- 2026-06-02: Code review fixes — redundant sort removed; extended test coverage; story marked done.
