# Story 12.1: Trends Average Stats Cards

Status: review

<!-- Baptiste 2026-06-16: History-light mockup re-attached — two average stat cards below bar chart (167 kcal / 3532 steps). -->
<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want average calories and steps for my selected period,
So that I understand typical daily activity at a glance.

## Acceptance Criteria

1. **Given** Trends tab with **7 days** or **30 days** toggle selected  
   **When** the chart window has at least one day with `totalSteps > 0` (`HistoryStatus.ready`)  
   **Then** two side-by-side summary cards render **below** the bar chart:
   - **Average kcal burned per day** — flame icon (`PhosphorIconsRegular.fire`)
   - **Average steps taken per day** — footprints icon (`PhosphorIconsRegular.footprints`)

2. **Given** kcal average computation for the active window  
   **When** each calendar day in the window is evaluated  
   **Then** daily kcal = `DerivedActivityMetrics.compute(displaySteps: dayTotalSteps, activeBuckets: bucketsForThatDay, heightCm:, weightKg:).kcal`  
   **And** `bucketsForThatDay` comes from `StepRepository.getActiveBucketsForLocalDay(localDay)` (bucket-based — locked decision 2026-06-15)  
   **And** `heightCm` / `weightKg` are current profile values from `UserPreferencesRepository` at refresh time  
   **And** window average kcal = **arithmetic mean** of daily kcal values across **all** days in the window (7 or 30), including zero-step days as **0 kcal**

3. **Given** steps average computation for the active window  
   **When** calculated  
   **Then** window average steps = arithmetic mean of `ChartDayAggregate.totalSteps` for every day in the window (missing days in slice count as 0 steps)

4. **Given** user switches **7d ↔ 30d** via `PeriodToggle`  
   **When** toggle fires  
   **Then** both cards recalculate for the new window **from in-memory cache** (no extra `getChartDailyAggregates` or per-day bucket DB round-trips)  
   **And** chart period toggle remains KPI-01 safe (**p95 < 100 ms** — FR-28)

5. **Given** Trends is loading or empty (`HistoryStatus.loading` / `HistoryStatus.empty`)  
   **When** screen renders  
   **Then** stat cards are **hidden** (chart empty/loading UX unchanged)  
   **And** no misleading `0` averages shown over the empty-state message

6. **Given** card copy and layout vs mockup `History-light` (Baptiste attachment 2026-06-16)  
   **When** cards render in light theme  
   **Then** each card is an `ElevatedCard` in a 50/50 `Row` with `AstraSpacing.kSpaceSm` gap  
   **And** value line shows integer + unit inline (e.g. `167` + `kcal`, `3532` + `steps`) — bold primary text, unit same line smaller weight  
   **And** caption below: `average calories burned per day` / `average steps taken per day` — `AstraTypography.captionFor`, muted  
   **And** accent icon top-left inside card padding (purple / `colors.accentPrimary`)

7. **Given** implementation complete  
   **When** `flutter analyze` and targeted tests run  
   **Then** no new analyzer issues  
   **And** cubit tests cover average math (7d vs 30d slice, zero-day inclusion, bucket-based kcal)  
   **And** widget/smoke tests assert cards visible on seeded ready state and hidden on empty

**Depends on:** Epic 8 (done), Epic 6 `DerivedActivityMetrics` + `getActiveBucketsForLocalDay` (done), Epic 3 chart surface (done).  
**Enables:** Story 12.2 (peak day card — same row/section below chart).  
**Out of scope:** Peak day card (12.2), 12-month chart (12.3), per-day goal line on bars (12.4), `TrendChip` changes, chart bar styling.  
**Mockup ref:** `History-light` — user attachment 2026-06-16 (`assets/c__Users_Baptiste_..._History-light-d9311980-*.png`).

## Tasks / Subtasks

- [x] **Sub-task A — Period stats model + `HistoryCubit` computation** (AC: #2, #3, #4)
  - [x] Add `TrendsDayMetrics` (or equivalent) immutable type: `localDay`, `totalSteps`, `dailyKcal`
  - [x] Extend `HistoryState` with optional `TrendsPeriodAverages? periodAverages` (`averageKcal`, `averageSteps`) — `null` when loading/empty
  - [x] In `HistoryCubit._refreshImpl`, after `getChartDailyAggregates(days: 30)`:
    - Parallel fetch `getHeightCm()`, `getWeightKg()`
    - For each aggregate day (30 entries, newest-first as returned), `Future.wait` `getActiveBucketsForLocalDay(aggregate.localDay)` → per-day `DerivedActivityMetrics.compute`
    - Cache `_cachedDayMetrics30d` (newest-first, aligned with repository aggregate order)
  - [x] Add `_computeAveragesForPeriod(HistoryPeriod)` — slice first N days from cache, mean kcal + mean steps (divide by **period.dayCount**, not count of non-zero days)
  - [x] Wire into `_emitReady` / `selectPeriod` — period toggle recomputes averages from cache only
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — `TrendsAverageStatsRow` widget** (AC: #1, #6)
  - [x] Create `lib/presentation/widgets/trends_average_stats_row.dart`:
    - Props: `averageKcal`, `averageSteps` (non-null ints when shown)
    - Private `_TrendsStatCard` using `ElevatedCard`, icon, value+unit row, caption
    - Reuse `formatKcal` from `activity_metrics_formatter.dart`; steps as plain integer string (no unit formatter exists — match mockup `3532 steps`)
    - Semantics per card (e.g. `Average 167 kilocalories burned per day`)
  - [x] **Do not** reuse `ActivityStatsRow` — different layout (two standalone cards, not three-column dividers)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Wire `HistoryScreen` layout** (AC: #1, #5, #6)
  - [x] In `history_screen.dart`, below `Expanded(StepBarChart…)`, add:
    ```dart
    if (state.status == HistoryStatus.ready && state.periodAverages != null) ...[
      const SizedBox(height: AstraSpacing.kSpaceMd),
      TrendsAverageStatsRow(averages: state.periodAverages!),
    ],
    ```
  - [x] Verify bottom nav clearance padding unchanged; cards sit above bottom inset inside existing `Column`
  - [x] Confirm chart still has `minHeight: 200` and flexes — cards are **not** inside `Expanded`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Tests** (AC: #7)
  - [x] `test/presentation/cubits/history_cubit_test.dart`:
    - Seeded buckets + daily totals → expect `periodAverages.averageSteps` matches hand-computed mean
    - Kcal average uses bucket path (seed 5min buckets with ≥40 steps for walking minutes)
    - `selectPeriod(days30)` changes averages without incrementing chart aggregate spy call count
    - Zero-step days in window pull averages down (include in denominator)
  - [x] `test/presentation/widgets/trends_average_stats_row_test.dart` — renders values, captions, icons
  - [x] Extend `screen_smoke_test.dart` History group — ready state shows both captions; empty state hides cards
  - [x] Run `flutter analyze` + targeted tests
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| Area | In scope (12.1) | Out of scope |
|------|-----------------|--------------|
| Average kcal + steps cards | Below chart, 7d/30d window | Peak day card (12.2) |
| Kcal source | Bucket-based `DerivedActivityMetrics` per day | Distance/duration on Trends |
| Data loading | On `HistoryCubit.refresh` (+ app resume / tab select existing triggers) | Live overlay / today-only bucket refresh |
| Profile changes | Recalculate on next `refresh` (height/weight read at refresh) | New `refreshMetadata` on HistoryCubit (optional follow-up) |
| Chart / goal line | Unchanged | Per-day goal line (12.4) |
| Version bump | None | Epic 12 close → `0.5.0+7` per sprint plan |

### Visual reference (authoritative mockup)

**Mockup (Baptiste 2026-06-16):** Trends screen, light theme.

| Region | Mockup element | Implementation target |
|--------|----------------|----------------------|
| Title | **Trends** (muted) | Already `HistoryScreen` — no change |
| Toggle | **7 days** \| **30 days** pill | Existing `PeriodToggle` — no change |
| Chart | Bar chart + dashed goal line | Existing `StepBarChart` — no change |
| Card left | Flame icon, **167 kcal**, caption | `TrendsAverageStatsRow` card 1 |
| Card right | Footprints, **3532 steps**, caption | `TrendsAverageStatsRow` card 2 |
| Bottom nav | TRENDS active | Epic 10 — no change |

**Layout order (top → bottom):** Title → `PeriodToggle` → optional `TrendChip` → `Expanded(StepBarChart)` → **stats row** (this story).

### Current code state (READ BEFORE EDITING)

**`lib/presentation/screens/history_screen.dart`** — column ends after chart; no stats section:

```dart
Expanded(child: StepBarChart(...)),
const SizedBox(height: AstraSpacing.kSpaceMd),
// ← insert TrendsAverageStatsRow here (ready only)
```

**`lib/presentation/cubits/history_cubit.dart`** — already caches `_cachedAggregates30d` and slices via `_sliceForPeriod`. Extend with parallel `_cachedDayMetrics30d` built during `_refreshImpl` only.

**`lib/presentation/cubits/history_state.dart`** — add averages field; keep `copyWith` in sync.

**`lib/data/repositories/step_repository.dart`** — reuse:
- `getChartDailyAggregates(days: 30)` — daily step totals (already used)
- `getActiveBucketsForLocalDay(DateTime localDay)` — per-day 5min buckets (Story 11.3)

**`lib/core/metrics/derived_activity_metrics.dart`** — canonical kcal engine (Story 6.1). **Do not** duplicate MET math in cubit.

### Average computation (locked formulas)

```dart
// For period P with dayCount = 7 or 30:
final slice = cachedDayMetrics.take(P.dayCount); // newest-first cache
final averageSteps = slice.fold<int>(0, (s, d) => s + d.totalSteps) / P.dayCount;
final averageKcal = slice.fold<int>(0, (s, d) => s + d.dailyKcal) / P.dayCount;
// Round for display: .round() on the mean (167 not 167.4)
```

**Zero-step days:** Still in slice with `totalSteps: 0`, `dailyKcal: 0` — denominator is always 7 or 30.

**Window alignment:** Use the **same** `_sliceForPeriod` / `_cachedAggregates30d` ordering as chart points (reversed to oldest-first for chart). Build day-metrics cache in **newest-first** repository order, then slice identically to chart logic before reversing for display if needed.

### Performance guardrails (KPI-01)

| Operation | When | DB cost |
|-----------|------|---------|
| `getChartDailyAggregates(30)` | `refresh()` | 1 query (existing) |
| `getActiveBucketsForLocalDay` × 30 | `refresh()` only | Up to 30 bucket queries — batch with `Future.wait` |
| Period toggle 7d↔30d | `selectPeriod` | **0** — slice cached metrics |
| Chart re-render | toggle | Pre-aggregated points only (existing) |

**Acceptable:** Refresh latency may increase slightly on Trends load (bucket fetches). **Not acceptable:** Per-toggle bucket fetches or blocking chart bind past 100 ms on toggle.

**Optional optimization (only if refresh regresses in QA):** Compute day metrics lazily for visible period first — **not required** unless Baptiste flags perf; prefer straightforward full 30-day cache.

### Architecture compliance

| Rule | Application |
|------|-------------|
| `HistoryCubit` owns Trends aggregates | Extend — do not create `TrendsCubit` |
| Pure metrics math | `DerivedActivityMetrics` in `core/metrics/` |
| No reactive streams | Cache + emit on refresh/toggle only |
| Presentation widgets | New row in `presentation/widgets/` |
| Review-before-commit | One commit per sub-task A–D per `docs/project-context.md` |
| Phosphor icons | `phosphoricons_flutter` — no new deps |

### Reuse — do NOT reinvent

| Need | Use existing |
|------|--------------|
| Daily step totals | `ChartDayAggregate` / `getChartDailyAggregates` |
| Per-day buckets | `getActiveBucketsForLocalDay` (mirror of `getTodayActiveBuckets`) |
| Kcal formula | `DerivedActivityMetrics.compute` |
| Kcal display | `formatKcal` |
| Card surface | `ElevatedCard` |
| Period enum | `HistoryPeriod.dayCount` |
| Icons | `PhosphorIconsRegular.fire`, `.footprints` |
| Spacing / type | `AstraSpacing`, `AstraTypography` |

### Recommended `HistoryState` extension

```dart
class TrendsPeriodAverages {
  const TrendsPeriodAverages({
    required this.averageKcal,
    required this.averageSteps,
  });
  final int averageKcal;
  final int averageSteps;
}

// In HistoryState:
final TrendsPeriodAverages? periodAverages;
```

Populate in `HistoryState.ready` factory; `null` in `loading` / `empty` factories.

### `refreshGoal` behavior

`refreshGoal()` today updates goals only — **no change required** for 12.1. Kcal averages depend on height/weight, not goal. Full recomputation happens on `refresh()` (app resume, Trends tab select, post import/purge).

### Testing requirements

| Test file | Coverage |
|-----------|----------|
| `history_cubit_test.dart` | **UPDATE** — averages math, toggle without extra DB, zero-day denominator |
| `trends_average_stats_row_test.dart` | **NEW** — layout, copy, semantics |
| `screen_smoke_test.dart` | **UPDATE** — cards visible/hidden |
| `derived_activity_metrics_test.dart` | **No change** — already covers MET math |
| `chart_benchmark_test.dart` | **No regression** — KPI-01 path untouched on toggle |

**Cubit test seeding pattern:** Use `upsertIngestionBucket` with `resolution: '5min'` (via `NormalizedStepBucket`) for bucket-based kcal — see `step_repository_active_buckets_test.dart`.

**Hand-check example:** 7 days each 1000 steps, identical buckets → average steps 1000; kcal > 0 when buckets exceed 40-step threshold.

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/cubits/history_state.dart` | **UPDATE** — `TrendsPeriodAverages`, `periodAverages` field |
| `lib/presentation/cubits/history_cubit.dart` | **UPDATE** — cache day metrics, compute averages |
| `lib/presentation/widgets/trends_average_stats_row.dart` | **NEW** |
| `lib/presentation/screens/history_screen.dart` | **UPDATE** — wire stats row |
| `test/presentation/cubits/history_cubit_test.dart` | **UPDATE** |
| `test/presentation/widgets/trends_average_stats_row_test.dart` | **NEW** |
| `test/presentation/screens/screen_smoke_test.dart` | **UPDATE** |

**Do not** rename `HistoryScreen` / `HistoryCubit` (internal names; tab label already **TRENDS**).

### Library / framework requirements

- Flutter SDK + `flutter_bloc` per `pubspec.yaml` — **no new dependencies**
- `DerivedActivityMetrics` — pure Dart, already tested
- Integer rounding: display averages as rounded ints (`167`, `3532`)

### Previous story intelligence (Epic 11 — Steps dashboard)

- Epic 11 closed at `0.4.0+6` — presentation patterns: `ElevatedCard`, `SectionCard`, Phosphor icons, review-before-commit sub-tasks
- `getActiveBucketsForLocalDay` added in Story 11.3 for selected-day stats — **same API** for Trends per-day kcal
- `TodayCubit` computes metrics for one day; Trends averages **reuse the same compute path** across N days

### Previous story intelligence (Epic 3 + 6 — chart + metrics)

- `HistoryCubit` caches 30d aggregates; period toggle slices without re-query (Story 3.2/3.3) — **mirror for averages**
- Story 6.1 locked bucket-based kcal — sprint proposal 2026-06-15 explicitly requires bucket-based Trends kcal (not steps-only estimate)

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `3a4ce52` | Epic 11 closed — Epic 12 opens next |
| `473d106` | Trophy/live patch pattern — prefer localized state updates over full reload when possible; here full refresh on tab is OK |
| `c4c27b3` | Small widget + screen wiring + tests per sub-task |

### Latest technical notes (2026)

- **`getActiveBucketsForLocalDay`:** 5min resolution, `value > 0`, zone-offset filtered — O(samples in ±1 day window) per call
- **`Future.wait`:** Standard pattern in `TodayCubit._refreshImpl` for parallel prefs + buckets — copy style
- **fl_chart / KPI-01:** Do not add animations or extra rebuilds on stats row bind

### Project context reference

- Review-before-commit: `docs/project-context.md` § Development Workflow
- Versioning: Epic 12 close → `0.5.0+7` — not per story
- Sprint sequencing: `sprint-change-proposal-2026-06-15.md` § 4.4 Trends

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` § Epic 12, Story 12.1]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` § 4.4 Trends, § User decisions — bucket-based kcal]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` § 2.4 Trends Surface — layout baseline]
- [Source: `lib/presentation/screens/history_screen.dart`]
- [Source: `lib/presentation/cubits/history_cubit.dart`]
- [Source: `lib/core/metrics/derived_activity_metrics.dart`]
- [Source: `lib/data/repositories/step_repository.dart` § `getActiveBucketsForLocalDay`]
- [Source: `_bmad-output/implementation-artifacts/stories/6-1-derived-activity-metrics.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/11-3-selected-day-indicators-and-live-guards.md`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Spy test repositories updated to delegate `getActiveBucketsForLocalDay` after cubit extension.

### Completion Notes List

- Sub-task A: `TrendsDayMetrics`, `TrendsPeriodAverages`, `_cachedDayMetrics30d` built on refresh via parallel bucket fetches + `DerivedActivityMetrics.compute`; period toggle slices cache only (KPI-01 safe).
- Sub-task B: `TrendsAverageStatsRow` with two `ElevatedCard` stat cards (fire/footprints icons, mockup copy).
- Sub-task C: Wired below chart in `HistoryScreen`; hidden on loading/empty.
- Sub-task D: Cubit math tests, widget tests, smoke tests; `flutter analyze` clean; 39 targeted tests pass.

### File List

- `lib/presentation/cubits/history_state.dart`
- `lib/presentation/cubits/history_cubit.dart`
- `lib/presentation/widgets/trends_average_stats_row.dart`
- `lib/presentation/screens/history_screen.dart`
- `test/presentation/cubits/history_cubit_test.dart`
- `test/presentation/widgets/trends_average_stats_row_test.dart`
- `test/presentation/screens/screen_smoke_test.dart`

## Change Log

- 2026-06-16: Story 12.1 — Trends average kcal/steps cards below bar chart (bucket-based kcal, cache-only period toggle).
