# Story 12.3: Trends Twelve-Month Monthly Chart

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want a yearly view of my walking habit,
So that I see long-term trends without daily noise.

## Acceptance Criteria

1. **Given** Trends tab  
   **When** user selects **12 months** on `PeriodToggle` (third segment alongside 7d / 30d)  
   **Then** the daily `StepBarChart` is replaced by a **monthly** bar chart with **12 bars** (one per calendar month)  
   **And** bar height = **average daily steps** for that month (see locked formula in Dev Notes)  
   **And** x-axis shows short month labels (e.g. `Jan`, `Feb`, … `Jun`) oldest → newest left → right  
   **And** chart uses same surface styling as daily chart (`bgElevated`, min height 200dp, `duration: Duration.zero`)

2. **Given** user is on **12 months** view  
   **When** screen renders  
   **Then** `TrendChip`, `TrendsAverageStatsRow`, and `TrendsPeakDayCard` are **hidden** (7d/30d-only stats — locked by Stories 12.1–12.2)  
   **And** no goal reference line on monthly chart (per-day goal line is Story 12.4)

3. **Given** `StepRepository.getChartMonthlyAggregates`  
   **When** called with `months: 12`  
   **Then** returns exactly **12** `ChartMonthAggregate` entries for the rolling window ending in the **current calendar month** (reference today from `clock`)  
   **And** aggregation uses stored samples + each row's immutable `zone_offset` via `LocalDayCalculator` (no SQL `date()` hacks, no network)  
   **And** finest-resolution-per-day dedup matches `getChartDailyAggregates` (`_finestResolutionTotal`)

4. **Given** average daily steps formula (locked — resolves epic ambiguity)  
   **When** computing each month's bar height  
   **Then** `averageDailySteps = round(totalStepsInMonth / dayCount)` where:
   - `totalStepsInMonth` = sum of daily step totals for every local day in that calendar month within the rolling window
   - `dayCount` = **calendar days in that month included in the window** (zero-step days count; same philosophy as Story 12.1 denominator)
   - For the **current (partial) month:** `dayCount` = days elapsed through reference today (inclusive)
   - For **past complete months:** `dayCount` = full calendar days in that month  
   **And** months with zero total steps render as zero-height bars (not omitted)

5. **Given** `HistoryCubit.refresh()`  
   **When** Trends data loads  
   **Then** daily aggregates (`getChartDailyAggregates(days: 30)`) and monthly aggregates (`getChartMonthlyAggregates(months: 12)`) fetch in parallel (`Future.wait`)  
   **And** monthly results cache in `_cachedMonthlyAggregates12`  
   **And** switching **7d ↔ 30d ↔ 12 months** via `selectPeriod` uses cache only — **zero** extra repository calls

6. **Given** KPI-01 / FR-28 regression guard  
   **When** user toggles **only** between `days7` and `days30`  
   **Then** toggle path remains cache-only and `chart_benchmark_test.dart` passes unchanged  
   **And** monthly query cost is paid on `refresh()` only — not on 7d/30d toggle

7. **Given** Trends loading / empty states  
   **When** `HistoryStatus.loading` → show monthly skeleton (12 gray bars) when period is `months12`, else existing 7-bar skeleton  
   **When** `HistoryStatus.empty` (no step data at all) → existing empty copy regardless of period  
   **When** `HistoryStatus.ready` on `months12` with some historical steps → monthly chart renders even if last 7 days are zero

8. **Given** implementation complete  
   **When** `flutter analyze` and targeted tests run  
   **Then** no new analyzer issues  
   **And** repository tests cover month boundaries, partial current month denominator, zone-offset travel, finest-resolution dedup  
   **And** cubit tests cover cache-only period switch including `months12`, stats hidden on 12mo  
   **And** widget/smoke tests assert 12-month toggle shows monthly chart and hides stats row

**Depends on:** Epic 3 chart surface (done), Story 12.1–12.2 cache patterns (done).  
**Enables:** Story 12.4 (per-day goal line on **7d/30d** daily chart only).  
**Out of scope:** Per-day goal line (12.4), kcal on monthly chart, peak day / averages on 12mo view, drill-down to month detail, chart animations, new dependencies.  
**Mockup ref:** None — `sprint-change-proposal-2026-06-15.md` § 4.4 Trends.

## Tasks / Subtasks

- [x] **Sub-task A — `ChartMonthAggregate` + repository monthly query** (AC: #3, #4)
  - [x] Add `lib/data/models/chart_month_aggregate.dart`:
    - `monthStart` — `DateTime` date-only UTC (first day of month)
    - `averageDailySteps` — `int` (pre-rounded in repository)
    - Optional `totalSteps` + `dayCount` for test assertions (recommended)
  - [x] Add `StepRepository.getChartMonthlyAggregates({required int months})`:
    - Validate `months == 12` for Phase 0 (mirror daily `days` guard)
    - Compute rolling 12 calendar months ending at reference today's month
    - SQL lower bound: first day of oldest month − 1 day (zone edge buffer, mirror daily)
    - Group samples → daily totals → monthly sums using `LocalDayCalculator`
    - Apply `_finestResolutionTotal` per day before summing into month
    - Return **newest-first** (current month at index 0) — mirror `getChartDailyAggregates`
  - [x] Add `test/data/repositories/step_repository_chart_monthly_aggregates_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — `HistoryPeriod.months12` + cubit cache wiring** (AC: #5, #6, #7)
  - [x] Extend `HistoryPeriod` enum with `months12` (`dayCount` not used for monthly — document)
  - [x] Add `List<ChartMonthAggregate> monthlyChartPoints` to `HistoryState` (empty when not `months12`)
  - [x] `HistoryCubit`:
    - `_cachedMonthlyAggregates12`
    - Parallel fetch in `_refreshImpl` alongside daily aggregates + day-metrics build
    - `_sliceMonthlyForChart()` — reverse newest-first cache → **oldest-first** for display (mirror `_sliceForPeriod`)
    - `_emitReady`: when `period == months12`, emit `monthlyChartPoints`, force `periodAverages` / `peakDay` / `trend` to `null`
    - `selectPeriod(months12)`: cache-only emit; do not call `_computeAveragesForPeriod` / `_computePeakDayForPeriod`
    - Empty detection: keep existing rule (`totalSteps == 0` on 30d daily cache) — monthly-only legacy data is edge case; do not block 12mo if 30d window is zero but older months have data (see Dev Notes)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — `TrendsMonthlyBarChart` + UI wiring** (AC: #1, #2, #7)
  - [x] Create `lib/presentation/widgets/trends_monthly_bar_chart.dart`:
    - Props: `points` (`List<ChartMonthAggregate>`), `status` (`HistoryStatus`)
    - Reuse `StepBarChart` empty copy + elevated container + min height 200
    - `BarChart(duration: Duration.zero)` — 12 bars, `toY: averageDailySteps`
    - X-axis: `_monthLabels[monthStart.month - 1]` (3-letter English — match weekday label style in `StepBarChart`)
    - Y-axis: 0 + max only (reuse `_formatAxisValue` pattern — extract shared helper only if trivial)
    - **No** goal line, **no** goal-based bar coloring (uniform `accentPrimary` muted fill)
    - Loading skeleton: 12 bars (not 7)
  - [x] Update `PeriodToggle` — third option `AstraSegmentOption(value: HistoryPeriod.months12, label: '12 months')`
  - [x] Update `history_screen.dart`:
    ```dart
    Expanded(
      child: state.period == HistoryPeriod.months12
          ? TrendsMonthlyBarChart(
              key: const ValueKey('months12'),
              points: state.monthlyChartPoints,
              status: state.status,
            )
          : StepBarChart(
              key: ValueKey(state.period),
              ...
            ),
    ),
    ```
  - [x] Gate `TrendChip` on `state.period != HistoryPeriod.months12`
  - [x] Gate stats row on `state.period != HistoryPeriod.months12 && state.periodAverages != null`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Tests + KPI guard** (AC: #6, #8)
  - [x] `history_cubit_test.dart` — monthly cache on refresh, `selectPeriod(months12)` no extra repo calls, stats null on 12mo, monthly points oldest-first
  - [x] `trends_monthly_bar_chart_test.dart` — 12 bars, labels, empty/loading
  - [x] `period_toggle_test.dart` — third segment tap
  - [x] `screen_smoke_test.dart` — 12mo shows monthly chart, hides average cards
  - [x] Run `flutter analyze` + targeted tests; confirm `chart_benchmark_test.dart` unchanged on 7d↔30d toggle
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| Area | In scope (12.3) | Out of scope |
|------|-----------------|--------------|
| 12-month monthly chart | Rolling 12 calendar months, avg daily steps/bar | Daily bars in 12mo mode |
| Period toggle | Add `12 months` third segment | Separate screen / section below chart |
| Stats cards | Hidden on 12mo | Extending averages/peak to yearly |
| Goal line | None on monthly chart | Per-day goal (12.4) |
| Repository | `getChartMonthlyAggregates` | New tables / migrations |
| Version bump | None | Epic 12 close → `0.5.0+7` |

### UX decision (locked — resolves epic "UX TBD")

Extend existing `PeriodToggle` to **three segments**: `7 days | 30 days | 12 months`. Do **not** add a separate section below the chart. Rationale: `AstraSegmentedControl` already supports N options; matches sprint proposal "12-month chart" as alternate chart mode; Story 12.2 explicitly forbids conflating 12mo with 7d/30d stats.

### Layout order by period

**7d / 30d (unchanged):** Title → Toggle → `TrendChip` → `StepBarChart` → averages row → peak card.

**12 months:** Title → Toggle → `TrendsMonthlyBarChart` only (no chip, no stats).

### Average daily steps formula (locked)

```dart
// Per calendar month M in rolling 12-month window:
final daysInWindow = <DateTime> /* every local day in M clipped to [windowStart, referenceToday] */;
final totalSteps = sum(dailyStepTotal(d) for d in daysInWindow);
final averageDailySteps = (totalSteps / daysInWindow.length).round();
// daysInWindow.length is always >= 1 for months in the window
```

**Why calendar days (not "days with data"):** Story 12.1 averages divide by fixed window size (7 or 30) including zero-step days. Monthly view must stay consistent — a sparse month should show a lower average, not inflate by excluding idle days.

### Rolling window definition (locked)

Reference today = `LocalDayCalculator.localDay(clock.snapshot())`.

12 months = current month + prior 11 calendar months.

Example: reference `2026-06-02` → months `2025-07` … `2026-06` (12 buckets).

Repository returns newest-first (`2026-06` index 0). Chart displays oldest-first (`2025-07` leftmost).

### Empty-state edge case (locked)

Current `HistoryCubit` marks `empty` when **30-day** daily aggregate sum is zero. For 12.3:

- **Keep** that gate for first-load empty UX (no step data at all).
- When `ready` and user selects `months12`, render monthly chart from `_cachedMonthlyAggregates12` even if the last-30-day sum is zero but older months in the 12mo window have steps (possible after partial purge or inactive recent period).
- Implementation hint: if `_cachedMonthlyAggregates12.any((m) => m.totalSteps > 0)` while daily 30d sum is zero, prefer `ready` with monthly data — only if this falls out naturally from revised empty check; **minimal change** acceptable: extend empty check to `daily30Sum == 0 && monthly12Sum == 0`.

### Current code state (READ BEFORE EDITING)

**`lib/presentation/widgets/period_toggle.dart`** — two options only; extend `_options` list.

**`lib/presentation/cubits/history_state.dart`** — `HistoryPeriod` has `days7`, `days30`; add `months12`. No monthly chart fields yet.

**`lib/presentation/cubits/history_cubit.dart`** — `_refreshImpl` fetches 30d daily only. `_emitReady` always computes trend/averages/peak. `selectPeriod` calls `_emitReady` for ready state.

**`lib/presentation/screens/history_screen.dart`** — always `StepBarChart`; stats gated on `periodAverages != null` only.

**`lib/data/repositories/step_repository.dart`** — `getChartDailyAggregates` lines 235–294: copy structure for monthly grouping. Reuse `_finestResolutionTotal`, `clock`, `LocalDayCalculator`, `TimestampCodec`.

**`lib/presentation/widgets/step_bar_chart.dart`** — daily totals on Y axis, goal line, goal-based colors. **Do not** overload for monthly averages — separate widget keeps 12.4 goal-line work isolated.

### Repository implementation sketch

```dart
Future<List<ChartMonthAggregate>> getChartMonthlyAggregates({
  required int months,
}) async {
  if (months != 12) {
    throw ArgumentError.value(months, 'months', 'Phase 0 supports 12 only');
  }
  final referenceToday = LocalDayCalculator.localDay(...);
  final currentMonthStart = DateTime.utc(referenceToday.year, referenceToday.month, 1);
  // Oldest month in window:
  final oldestMonthStart = DateTime.utc(
    referenceToday.year,
    referenceToday.month - (months - 1),
    1,
  ); // DateTime handles month underflow

  // Query from oldestMonthStart - 1 day ...
  // Build byDayAndResolution map (copy daily loop)
  // For each of 12 months (newest to oldest index):
  //   enumerate days in month clipped to [oldestMonthStart, referenceToday]
  //   sum finest daily totals, compute average, append ChartMonthAggregate
}
```

**Pre-aggregate in repository** — UI/widgets perform zero business aggregation (architecture rule #7).

### Cubit emit rules for `months12`

```dart
if (period == HistoryPeriod.months12) {
  emit(HistoryState.ready(
    period: period,
    chartPoints: const [], // unused in UI
    monthlyChartPoints: _sliceMonthlyForChart(),
    dailyGoal: todayGoal,
    goalsByDay: goalsByDay, // kept for refreshGoal parity; unused by monthly chart
    trend: null,
    periodAverages: null,
    peakDay: null,
  ));
  return;
}
```

### Performance guardrails (KPI-01)

| Operation | When | DB cost |
|-----------|------|---------|
| `getChartMonthlyAggregates(12)` | `refresh()` | 1 query (+ Dart aggregation) |
| `getChartDailyAggregates(30)` | `refresh()` | 1 query (existing) |
| `getActiveBucketsForLocalDay` × 30 | `refresh()` | existing (12.1) |
| Toggle 7d ↔ 30d | `selectPeriod` | **0** |
| Toggle involving `months12` | `selectPeriod` | **0** — slice cached monthly |

Monthly aggregation scans ~12 months of samples — acceptable on refresh (Trends tab select / app resume). **Not acceptable:** re-query on every period toggle.

### Architecture compliance

| Rule | Application |
|------|-------------|
| Repository owns aggregation | Monthly math in `StepRepository`, not cubit/widget |
| `LocalDayCalculator` + stored `zone_offset` | Required for every row |
| `HistoryCubit` owns Trends state | Extend — no `TrendsCubit` |
| No reactive streams | Cache + emit on refresh/toggle |
| `fl_chart` `duration: Duration.zero` | No animation on bind |
| Review-before-commit | One commit per sub-task A–D per `docs/project-context.md` |
| No new dependencies | `fl_chart` already in pubspec |

### Reuse — do NOT reinvent

| Need | Use existing |
|------|--------------|
| Daily finest-resolution dedup | `_finestResolutionTotal` in `step_repository.dart` |
| Local day semantics | `LocalDayCalculator`, `TimestampCodec` |
| Segmented toggle | `AstraSegmentedControl` / `PeriodToggle` |
| Chart container styling | Mirror `StepBarChart` outer `DecoratedBox` |
| Axis formatting | Copy `_formatAxisValue` from `step_bar_chart.dart` |
| Test clock / inject | `FakeTimeProvider`, `DataInjectService.inject90Days` |
| Cubit spy pattern | `history_cubit_test.dart` delegate repos |

### Recommended `ChartMonthAggregate`

```dart
class ChartMonthAggregate {
  const ChartMonthAggregate({
    required this.monthStart,
    required this.averageDailySteps,
    required this.totalSteps,
    required this.dayCount,
  });

  final DateTime monthStart; // UTC date-only, day 1
  final int averageDailySteps;
  final int totalSteps; // test / debug friendly
  final int dayCount;   // denominator used
}
```

### Testing requirements

| Test file | Coverage |
|-----------|----------|
| `step_repository_chart_monthly_aggregates_test.dart` | **NEW** — 12 items, rolling window, partial June denominator, travel offset, mixed resolution |
| `history_cubit_test.dart` | **UPDATE** — monthly cache, period switches, stats null on 12mo |
| `trends_monthly_bar_chart_test.dart` | **NEW** — bars, labels, loading skeleton count |
| `period_toggle_test.dart` | **UPDATE** — 12 months segment |
| `screen_smoke_test.dart` | **UPDATE** — 12mo mode layout |
| `chart_benchmark_test.dart` | **No regression** on 7d↔30d toggle |
| `step_repository_chart_aggregates_test.dart` | **No change** |

**Repository hand-check:** Seed 10 days × 1000 steps in June only (clock `2026-06-15`) → June `averageDailySteps == round(10000/15)`, May == 0.

### File structure requirements

| File | Action |
|------|--------|
| `lib/data/models/chart_month_aggregate.dart` | **NEW** |
| `lib/data/repositories/step_repository.dart` | **UPDATE** — `getChartMonthlyAggregates` |
| `lib/presentation/cubits/history_state.dart` | **UPDATE** — `months12`, `monthlyChartPoints` |
| `lib/presentation/cubits/history_cubit.dart` | **UPDATE** — cache, emit, empty-check |
| `lib/presentation/widgets/trends_monthly_bar_chart.dart` | **NEW** |
| `lib/presentation/widgets/period_toggle.dart` | **UPDATE** — third segment |
| `lib/presentation/screens/history_screen.dart` | **UPDATE** — conditional chart + gates |
| `test/data/repositories/step_repository_chart_monthly_aggregates_test.dart` | **NEW** |
| `test/presentation/cubits/history_cubit_test.dart` | **UPDATE** |
| `test/presentation/widgets/trends_monthly_bar_chart_test.dart` | **NEW** |
| `test/presentation/widgets/period_toggle_test.dart` | **UPDATE** |
| `test/presentation/screens/screen_smoke_test.dart` | **UPDATE** |

**Do not** modify `StepBarChart` goal-line logic (Story 12.4 scope).

### Library / framework requirements

- `fl_chart: ^1.2.0` — `BarChart`, `duration: Duration.zero` (existing)
- No `intl` / `DateFormat` — static 3-letter month labels array (match weekday label approach)
- Flutter SDK + `flutter_bloc` per `pubspec.yaml` — **no new dependencies**

### Previous story intelligence (Story 12.2 — immediate predecessor)

- Stats section is **7d/30d only** — peak card below averages; hide all stats on `months12`
- `_cachedDayMetrics30d` / averages / peak are period-scoped — do not call on `months12`
- Sub-task rhythm A→B→C→D with review-before-commit worked well
- Code review fixes to preserve: atomic cache commit on refresh; zero-step window guards for **daily** stats only

### Previous story intelligence (Story 12.1)

- Bucket fetches on refresh are expensive — monthly path must **not** add bucket fetches (steps only)
- Period toggle cache-only pattern is KPI-01 critical — extend to third period without extra DB

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `1ec0a49` | 12.2 review hardening — follow same test rigor |
| `0db0f2e`–`f3edbfc` | Cubit → widget → screen → tests commit sequence |
| Story 12.1 commits | Repository aggregation patterns, `Future.wait` on refresh |

### Latest technical notes (2026)

- **`fl_chart` 1.2.x:** `BarChart(duration: Duration.zero)` disables animation — required for KPI-01
- **Month arithmetic:** `DateTime.utc(year, month - 11, 1)` handles year rollover — prefer over manual month math
- **12 bars << 30 daily points:** Chart bind should be faster than 30d view; KPI-01 risk is toggle path, not monthly render

### Project context reference

- Review-before-commit: `docs/project-context.md` § Development Workflow
- Versioning: Epic 12 close → `0.5.0+7` — not per story
- Sprint sequencing: `sprint-change-proposal-2026-06-15.md` § 4.4 Trends — "12-month chart: monthly **average** steps (not daily bars)"

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` § Epic 12, Story 12.3]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` § 4.4 Trends, § User decisions]
- [Source: `_bmad-output/planning-artifacts/architecture.md` § KPI-01, repository aggregation, `HistoryCubit`]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` § 2.4 Trends Surface]
- [Source: `_bmad-output/implementation-artifacts/stories/12-1-trends-average-stats-cards.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/12-2-trends-peak-day-card.md`]
- [Source: `lib/data/repositories/step_repository.dart` § `getChartDailyAggregates`]
- [Source: `lib/presentation/cubits/history_cubit.dart`]
- [Source: `lib/presentation/widgets/step_bar_chart.dart`]

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- Sub-task A: `getChartMonthlyAggregates` mirrors daily aggregation — rolling 12 calendar months, `_finestResolutionTotal` per day, partial current month denominator.
- Sub-task B: `Future.wait` on refresh for daily + monthly; empty gate extended to `daily30Sum == 0 && monthly12Sum == 0`.
- Sub-task C: `TrendsMonthlyBarChart` separate widget; stats/trend chip gated on `months12`.
- Sub-task D: 79 targeted tests pass; `chart_benchmark_test.dart` KPI-01 toggle path unchanged.

### Completion Notes List

- ✅ Story 12.3 complete — twelve-month monthly chart with avg daily steps per bar
- ✅ Repository: `ChartMonthAggregate` + `getChartMonthlyAggregates(months: 12)`
- ✅ Cubit: `_cachedMonthlyAggregates12`, cache-only period toggle including `months12`
- ✅ UI: third `PeriodToggle` segment, conditional chart, stats hidden on 12mo
- ✅ Tests: repository boundaries, cubit cache, widget/smoke, KPI-01 regression guard
- `flutter analyze` — no issues on changed files
- 79 targeted tests passed (incl. `chart_benchmark_test.dart`)

### File List

- lib/data/models/chart_month_aggregate.dart (NEW)
- lib/data/repositories/step_repository.dart (UPDATED)
- lib/presentation/cubits/history_state.dart (UPDATED)
- lib/presentation/cubits/history_cubit.dart (UPDATED)
- lib/presentation/widgets/trends_monthly_bar_chart.dart (NEW)
- lib/presentation/widgets/period_toggle.dart (UPDATED)
- lib/presentation/screens/history_screen.dart (UPDATED)
- test/data/repositories/step_repository_chart_monthly_aggregates_test.dart (NEW)
- test/presentation/cubits/history_cubit_test.dart (UPDATED)
- test/presentation/widgets/trends_monthly_bar_chart_test.dart (NEW)
- test/presentation/widgets/period_toggle_test.dart (UPDATED)
- test/presentation/screens/screen_smoke_test.dart (UPDATED)

## Change Log

- 2026-06-16: Story 12.3 created — twelve-month monthly chart (repository aggregation, cubit cache, UI toggle, KPI-01 guardrails)
- 2026-06-16: Story 12.3 implemented — monthly aggregation, cubit cache, TrendsMonthlyBarChart, tests (status → review)
