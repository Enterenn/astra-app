# Story 12.4: Trends Historical Goal Line, Chart Readability & Bar Touch

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want the Trends charts to show my historical daily goal, clearer scale labels, and detailed info when I tap a bar,
so that I can see exactly what I walked, where I stand versus the goal I had that day, and explore monthly averages with confidence.

## Acceptance Criteria

1. **Given** 7d or 30d `StepBarChart` with visible daily data  
   **When** goal reference is rendered  
   **Then** each bar is compared to `getGoalForLocalDay(thatDay)` via existing `goalsByDay` map (no regression to single global goal)  
   **And** when **all visible goals are equal**, a single horizontal dashed `dataGoalLine` remains (current 8.2 behavior)  
   **And** when **goals differ** across the visible window, a **stepped dashed goal polyline** follows each day's resolved goal level (horizontal segment per day, vertical jump at goal changes) — replaces the current "omit line when goals differ" interim from Story 8.2  
   **And** changing today's goal does not retroactively shift past days' reference

2. **Given** any Trends bar chart (`StepBarChart` 7d/30d **and** `TrendsMonthlyBarChart` 12mo)  
   **When** the chart renders in `ready` state  
   **Then** the left Y-axis shows **more than 0 and max only** — at least **4 readable tick labels** including 0 and the chart ceiling  
   **And** when a daily goal reference is within the visible Y range (7d/30d only), the axis includes a tick at the **nearest applicable goal level** (single goal or the most common visible goal when stepped line is shown)  
   **And** tick values use existing compact formatting (`_formatAxisValue` / `formatStepCount` rules — thin-space thousands in tooltips, `k` suffix on axis when ≥ 1000)  
   **And** no horizontal grid lines are added (keep `FlGridData(show: false)` — readability via axis labels only)

3. **Given** `StepBarChart` in `ready` state  
   **When** user taps or long-presses a bar (`BarTouchData` enabled)  
   **Then** the touched bar highlights per UX D-4 (`accentPrimary` at ~80% opacity vs muted fill for others)  
   **And** a tooltip appears above the bar showing at minimum:
   - full date label (7d: weekday + day/month; 30d: `d/m` or equivalent short date)
   - step count formatted with `formatStepCount`
   - that day's historical goal (`Goal: X`)
   - delta vs goal (`+N over` / `N below` / `Goal met` when equal)  
   **And** tapping outside or on another bar updates selection; second tap on same bar may dismiss (toggle OK)  
   **And** touch interaction does **not** trigger repository/cubit refresh — UI-only state

4. **Given** `TrendsMonthlyBarChart` in `ready` state  
   **When** user taps a month bar (`BarTouchData` enabled)  
   **Then** tooltip shows at minimum:
   - month + year (e.g. `Jun 2026`)
   - average daily steps (`formatStepCount`)
   - optional context line: `totalSteps` and `dayCount` from `ChartMonthAggregate` (e.g. `18 000 total · 15 days`)  
   **And** touched bar uses the same highlight treatment as daily chart  
   **And** no per-day goal line or goal tooltip fields on monthly chart (goal history is daily-only — Story 12.3 scope)

5. **Given** KPI-01 / chart benchmark regression guard  
   **When** user toggles **only** between `days7` and `days30` without touching bars  
   **Then** toggle path remains cache-only and `chart_benchmark_test.dart` p95 < 100ms  
   **And** enabling `BarTouchData` does not reintroduce chart bind animation (`duration: Duration.zero` preserved)  
   **And** touch `setState` is localized to chart widget state — not `HistoryCubit` emits

6. **Given** accessibility  
   **When** a bar is selected on daily chart  
   **Then** `Semantics` on the chart container announces the selected day's summary (steps + goal + met/not met) — optional `liveRegion` or `label` update on selection  
   **And** when no bar selected, retain existing chart semantics label

7. **Given** implementation complete  
   **When** `flutter analyze` and targeted tests run  
   **Then** no new analyzer issues  
   **And** `step_bar_chart_test.dart` covers: stepped line when goals differ, equal-goals single line preserved, Y-axis tick count ≥ 4, touch tooltip content  
   **And** `trends_monthly_bar_chart_test.dart` covers: touch enabled, Y-axis ticks, tooltip month content  
   **And** `chart_benchmark_test.dart` passes unchanged on 7d↔30d toggle path

**Depends on:** Story 8.2 (`goalsByDay`), Story 12.3 (monthly chart widget).  
**Enables:** Epic 12 close → version `0.5.0+7`.  
**Out of scope:** Goal line on 12mo monthly chart, kcal in tooltips, chart animations, new dependencies, History stats/peak changes, drag-to-scrub, haptic feedback.  
**Mockup ref:** `History-light` (dashed goal line — now per-day/stepped post Epic 8).  
**User amendment (2026-06-16):** Expand 12.4 beyond goal line alone — richer Y-axis labels + `barTouchData` on **all** Trends bar charts.

## Tasks / Subtasks

- [x] **Sub-task A — Stepped historical goal line** (AC: #1)
  - [x] In `step_bar_chart.dart` `_ReadyChart`: replace `showGoalLine` / single `HorizontalLine` branch with stepped goal renderer when `resolvedGoals` are not all equal
  - [x] Preferred implementation: `Stack` with `BarChart` + overlay `CustomPainter` (or thin `LineChart` with `isStepLineChart: true` aligned to bar x-centers) drawing dashed `dataGoalLine` segments at each day's `resolvedGoals[i]`
  - [x] Preserve single `HorizontalLine` fast path when all goals equal
  - [x] Ensure `yMax` still uses `max(maxSteps, max(resolvedGoals))` (existing)
  - [x] Update `step_bar_chart_test.dart`: stepped line visible when goals differ; remove/adjust test that expects `horizontalLines` empty
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Shared Y-axis tick helper + apply to both charts** (AC: #2)
  - [x] Extract `computeChartYAxisTicks({required double maxY, Iterable<int> referenceValues})` → sorted unique tick positions (target 4–5 labels, nice round steps)
  - [x] Place in `lib/presentation/widgets/chart/chart_axis_ticks.dart` (NEW) with shared `formatChartAxisValue(int)` (move/consolidate from duplicated `_formatAxisValue` in both chart files)
  - [x] Update `StepBarChart` left `SideTitles`: render ticks from helper; pass visible goal value(s) as `referenceValues`
  - [x] Update `TrendsMonthlyBarChart` left `SideTitles` similarly (no goal reference values)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — `BarTouchData` on `StepBarChart`** (AC: #3, #5, #6)
  - [x] Convert `_ReadyChart` to `StatefulWidget` (or extract `_InteractiveBarChart` state holder) for `touchedIndex`
  - [x] Configure `BarTouchData(enabled: true, handleBuiltInTouches: false, touchCallback: …)` per fl_chart 1.2.x pattern
  - [x] Use `showingTooltipIndicators` on `BarChartGroupData` + `BarTouchTooltipData.getTooltipItems` for multi-line tooltip (or custom `Positioned` tooltip widget in `Stack` if built-in tooltip styling is too limited)
  - [x] Bar color: touched index → `accentPrimary` @ 80%; others keep goal-aware muted/positive colors
  - [x] Wire semantics update on selection
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — `BarTouchData` on `TrendsMonthlyBarChart`** (AC: #4, #5)
  - [x] Mirror touch/highlight pattern from Sub-task C (reuse shared helper if extracted: `astra_bar_chart_touch.dart`)
  - [x] Tooltip: month/year, avg steps, total · dayCount
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Tests + KPI guard** (AC: #5, #7)
  - [x] Update `trends_monthly_bar_chart_test.dart` — touch data enabled, axis tick count, tooltip pump via `tester.tap` on chart area
  - [x] Update `screen_smoke_test.dart` if needed (charts still render)
  - [x] Run `flutter analyze` + targeted tests; confirm `chart_benchmark_test.dart` unchanged on 7d↔30d toggle
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| Area | In scope (12.4) | Out of scope |
|------|-----------------|--------------|
| Per-day goal line | Stepped dashed polyline when goals differ; single line when equal | Monthly chart goal line |
| Y-axis | 4–5 ticks on daily + monthly charts | Grid lines, right axis |
| Touch | `BarTouchData` on `StepBarChart` + `TrendsMonthlyBarChart` | LineChart, Steps week strip |
| Data layer | None — consume existing `goalsByDay`, aggregates | New repository methods |
| Version bump | None | Epic 12 close → `0.5.0+7` |

### UX decisions (locked)

**Y-axis density (overrides Phase 0 "0 + max only" minimalism — explicit user request 2026-06-16):**

- Target **4–5** left-axis labels so users can estimate bar height without guessing between floor and ceiling.
- Algorithm sketch:
  ```dart
  // 1. ceiling = safeYMax (existing)
  // 2. Pick nice step: e.g. 1k/2k/5k increments based on ceiling
  // 3. Emit 0, step, 2*step, … up to ceiling; dedupe near-duplicates
  // 4. Merge in referenceValues (goal levels) if within (0, ceiling] and not within 8% of an existing tick
  ```
- Do **not** enable `FlGridData` — axis labels only, per existing calm aesthetic.

**Bar touch (overrides Story 3.3 Phase 0 `enabled: false` — explicit user request):**

- Use fl_chart **1.2.x** touch flow: `handleBuiltInTouches: false` + `touchCallback` + `showingTooltipIndicators` (see [fl_chart bar touch gist](https://gist.github.com/imaNNeo/bce3f0169ff3fd6c3f137cdeb5005c0e)).
- Tooltip styling: `bgElevated` surface, `AstraTypography.captionFor`, `textPrimary` / `neutralGray` for secondary lines, `maxContentWidth` ~140–160.
- Selected bar: UX D-4 locked — `accentPrimary` @ **80%** (goal-met bars may stay `dataPositive` when not selected; on touch, selected bar wins visually).

**Stepped goal line (resolves Story 8.2 deferral):**

Story 8.2 intentionally omitted the global dashed line when visible goals differ (`step_bar_chart_test.dart` asserts `horizontalLines.isEmpty`). **12.4 replaces that interim** with a stepped reference:

```
Steps │     ┌──── goal 10k
      │     │
      │ ┌───┘ goal 8k
      │ │
      └─┴─┴─┴─► days
```

- X alignment: bar group center for each index `i`, y = `resolvedGoals[i]`.
- Dashed stroke: match existing `HorizontalLine` — `strokeWidth: 1.5`, `dashArray: [6, 4]`, `colors.dataGoalLine`.
- When all goals equal: keep current single `HorizontalLine` (no CustomPainter needed).

### Current code state (READ BEFORE EDITING)

**`lib/presentation/widgets/step_bar_chart.dart`** — `_ReadyChart` (lines ~118–340):

- `barTouchData: const BarTouchData(enabled: false)` — **must enable**
- Y-axis: only renders `0` and `chartMaxY` via `interval: chartMaxY` + two `getTitlesWidget` branches
- Goal line: `allGoalsEqual` → one `HorizontalLine`; else `horizontalLines: []`
- Per-bar color already uses `resolvedGoals[i]` (Story 8.2) — preserve

**`lib/presentation/widgets/trends_monthly_bar_chart.dart`** — `_ReadyChart` (lines ~144–293):

- Same `BarTouchData(enabled: false)` and 0/max-only Y-axis
- No goal props — touch shows month metrics only
- Shares `_formatAxisValue` duplicate — consolidate in Sub-task B

**`lib/presentation/cubits/history_cubit.dart`**:

- `_cachedGoalsByDay` populated on refresh; `goalsByDay` passed to `StepBarChart` — **no cubit changes required** for 12.4 unless touch somehow needs new fields (it should not)

**`lib/presentation/screens/history_screen.dart`**:

- Already passes `goalsByDay` + `dailyGoal` to `StepBarChart` — no screen changes expected

**`test/presentation/widgets/step_bar_chart_test.dart`**:

- `omits goal line when visible goals differ` — **must be rewritten** to expect stepped goal overlay instead of empty `horizontalLines`

### Stepped line implementation options (pick one — do not bike-shed)

| Option | Pros | Cons |
|--------|------|------|
| **A. CustomPainter overlay** in `Stack` above `BarChart` | Full control over dashed segments; no second chart | Must map bar index → pixel x using chart layout |
| **B. Overlay `LineChart` with `isStepLineChart: true`** | fl_chart native stepping | Two charts to sync size/padding; trickier hit testing |
| **C. Multiple `HorizontalLine` only** | Simple | Cannot step per day — **reject** |

**Recommendation: Option A** — `GoalStepLinePainter` in `lib/presentation/widgets/chart/goal_step_line_painter.dart` taking `List<int> goals`, `maxY`, bar count, chart padding. Keeps touch hit testing on the `BarChart` layer.

### Y-axis tick helper (shared)

```dart
// lib/presentation/widgets/chart/chart_axis_ticks.dart
List<double> computeChartYAxisTicks({
  required double maxY,
  Iterable<int> referenceValues = const [],
  int targetTickCount = 5,
});

String formatChartAxisValue(int value); // k suffix + plain int
```

Both chart widgets import this — delete private `_formatAxisValue` duplicates after migration.

### Touch tooltip copy (locked English strings)

**Daily bar (`StepBarChart`):**

| Line | Example |
|------|---------|
| Date | `Mon 9 Jun` (7d) / `9/6` (30d) |
| Steps | `8 547 steps` |
| Goal | `Goal: 8 000` |
| Delta | `547 over goal` / `1 200 below goal` / `Goal met` |

**Monthly bar (`TrendsMonthlyBarChart`):**

| Line | Example |
|------|---------|
| Period | `Jun 2026` |
| Average | `3 532 steps/day` |
| Context | `52 980 total · 15 days` |

Use `formatStepCount` from `lib/presentation/formatters/step_count_formatter.dart` — do not add `intl`.

### KPI-01 / performance guardrails

| Operation | When | DB / cubit cost |
|-----------|------|-----------------|
| 7d ↔ 30d toggle | `selectPeriod` | **0** (unchanged) |
| Bar tap | `setState` in chart widget | **0** |
| Goal line / axis recompute | chart `build` | Dart-only, O(n) n ≤ 30 |

**Critical:** Do not call `HistoryCubit.refresh()` on touch. Do not add `AnimationController`. Keep `BarChart(duration: Duration.zero)`.

Verify `test/dev/chart_benchmark_test.dart` after Sub-task E.

### Architecture compliance

| Rule | Application |
|------|-------------|
| Repository owns aggregation | No new queries — display only |
| `goalsByDay` from cubit | Already resolved via `getGoalForLocalDay` |
| `fl_chart` `duration: Duration.zero` | Mandatory |
| Review-before-commit | One commit per sub-task A–E per `docs/project-context.md` |
| No new dependencies | `fl_chart ^1.2.0` only |
| UX D-4 selected bar | 80% accent on touch |

### Reuse — do NOT reinvent

| Need | Use existing |
|------|--------------|
| Per-day goals | `goalsByDay` map + `_goalForPoint` pattern in `step_bar_chart.dart` |
| Step formatting | `formatStepCount` |
| Goal line color | `colors.dataGoalLine` |
| Bar width math | `_resolveBarWidth` (copy to shared only if touch tooltip needs it) |
| Month label | `TrendsMonthlyBarChart.formatMonthLabel` + `_formatMonthYear` |
| Test pump pattern | `step_bar_chart_test.dart` / `trends_monthly_bar_chart_test.dart` |
| Benchmark harness | `chart_benchmark.dart`, `chart_benchmark_render_pump.dart` — update only if widget constructor changes |

### Testing requirements

| Test file | Coverage |
|-----------|----------|
| `step_bar_chart_test.dart` | **UPDATE** — stepped goal when goals differ; equal goals single line; ≥4 Y labels; touch shows tooltip strings |
| `trends_monthly_bar_chart_test.dart` | **UPDATE** — touch enabled; Y ticks; monthly tooltip |
| `chart_benchmark_test.dart` | **No regression** on 7d↔30d toggle |
| `history_cubit_test.dart` | **No change** expected |
| `screen_smoke_test.dart` | **UPDATE** if layout breaks |

**Widget touch test hint:** tap center of chart `SizedBox` from test pump; use `BarTouchData.enabled` assertion via `tester.widget<BarChart>()`.

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/widgets/chart/chart_axis_ticks.dart` | **NEW** |
| `lib/presentation/widgets/chart/goal_step_line_painter.dart` | **NEW** (if Option A) |
| `lib/presentation/widgets/chart/astra_bar_chart_touch.dart` | **NEW** (optional — shared touch config) |
| `lib/presentation/widgets/step_bar_chart.dart` | **UPDATE** — goal line, axis, touch, StatefulWidget |
| `lib/presentation/widgets/trends_monthly_bar_chart.dart` | **UPDATE** — axis, touch, StatefulWidget |
| `test/presentation/widgets/step_bar_chart_test.dart` | **UPDATE** |
| `test/presentation/widgets/trends_monthly_bar_chart_test.dart` | **UPDATE** |

**Do not** modify `HistoryCubit`, `StepRepository`, or monthly aggregation unless a bug is found.

### Library / framework requirements

- `fl_chart: ^1.2.0` — `BarTouchData`, `BarTouchTooltipData`, `showingTooltipIndicators`, `BarTooltipItem`
- `handleBuiltInTouches: false` when using custom selection state (fl_chart 1.2.x best practice)
- Flutter SDK + `flutter_bloc` per `pubspec.yaml` — **no new dependencies**

### Previous story intelligence (Story 12.3 — immediate predecessor)

- Separate widgets for daily vs monthly — touch/axis work applies to **both**, not `StepBarChart` alone
- `TrendsMonthlyBarChart` has `totalSteps` + `dayCount` on `ChartMonthAggregate` — use in monthly tooltip
- Sub-task rhythm A→E with review-before-commit worked well
- KPI-01: monthly toggle cache-only — touch must not affect toggle benchmark

### Previous story intelligence (Story 8.2)

- `goalsByDay` resolution in `HistoryCubit._resolveGoalsForAggregates` — already complete
- Per-bar coloring vs goal — preserve when adding touch highlight (selected state overrides)
- Test `colors bars against per-day resolved goals` — keep green

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `3f1d9e4` | 12.3 month labels — match label style in touch tooltips |
| `2b92574` | Monthly chart widget structure — extend, don't rewrite |
| `de444c6`–`0bcba19` | Repository/cubit/test sequence — follow same rigor |

### Latest technical notes (fl_chart 1.2.x, 2026)

- **Touch:** Set `handleBuiltInTouches: false` and manage `touchedIndex` in `touchCallback` on `FlTapUpEvent` / `FlPanEndEvent`; clear on tap outside
- **Tooltip:** `BarTouchTooltipData.getTooltipItems` returns `List<BarTooltipItem?>` — use `\n` in text or multiple tooltip items for multi-line
- **Step line overlay:** CustomPainter receives `Size` from `LayoutBuilder` same as `BarChart` — share constraints
- **Accessibility:** Update parent `Semantics` `label` when `touchedIndex != null` with composed summary string

### Project context reference

- Review-before-commit: `docs/project-context.md` § Development Workflow
- Versioning: Epic 12 close → `0.5.0+7` — not per story
- UX D-4 selected bar + goal line: `_bmad-output/planning-artifacts/ux-design-specification.md` § Chart bars

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` § Epic 12, Story 12.4]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` § 2.4 Trends, D-4 Chart bars]
- [Source: `_bmad-output/planning-artifacts/architecture.md` § KPI-01, D-11 fl_chart]
- [Source: `_bmad-output/implementation-artifacts/stories/8-2-goal-history-consumer-migration.md` — deferred stepped line]
- [Source: `_bmad-output/implementation-artifacts/stories/12-3-trends-twelve-month-monthly-chart.md`]
- [Source: `lib/presentation/widgets/step_bar_chart.dart`]
- [Source: `lib/presentation/widgets/trends_monthly_bar_chart.dart`]
- [Source: fl_chart BarTouchData API — pub.dev/documentation/fl_chart/latest/fl_chart/BarTouchData-class.html]

## Dev Agent Record

### Agent Model Used

claude-4.6-sonnet-medium-thinking

### Debug Log References

- fl_chart 1.2.x: left-axis title widgets render outside `BarChart` descendant tree — tick coverage validated via `computeChartYAxisTicks` unit/widget tests.
- Touch widget tests use simulated `BarTouchData.touchCallback` + `showingTooltipIndicators` assertions (tap coordinates unreliable in widget harness).

### Completion Notes List

- ✅ Sub-task A: `GoalStepLinePainter` stepped dashed overlay when per-day goals differ; single `HorizontalLine` preserved when equal.
- ✅ Sub-task B: Shared `chart_axis_ticks.dart` with `computeChartYAxisTicks`, `formatChartAxisValue`, goal reference merge.
- ✅ Sub-task C: `StepBarChart` `_ReadyChart` stateful — touch highlight, multi-line tooltip, semantics label on selection.
- ✅ Sub-task D: `TrendsMonthlyBarChart` touch + monthly tooltip (month/year, avg, total · days).
- ✅ Sub-task E: Tests updated; `chart_benchmark_test.dart` toggle p95 ~0.5ms (pass). `flutter analyze` clean on widgets.

### File List

- `lib/presentation/widgets/chart/chart_axis_ticks.dart` (new)
- `lib/presentation/widgets/chart/goal_step_line_painter.dart` (new)
- `lib/presentation/widgets/chart/astra_bar_chart_touch.dart` (new)
- `lib/presentation/widgets/step_bar_chart.dart` (updated)
- `lib/presentation/widgets/trends_monthly_bar_chart.dart` (updated)
- `test/presentation/widgets/step_bar_chart_test.dart` (updated)
- `test/presentation/widgets/trends_monthly_bar_chart_test.dart` (updated)
- `test/presentation/widgets/chart_axis_ticks_test.dart` (new)
- `test/helpers/bar_chart_touch_test_helper.dart` (new)

## Change Log

- 2026-06-16: Story 12.4 created — historical stepped goal line, richer Y-axis ticks, BarTouchData on all Trends charts (user amendment included)
- 2026-06-16: Story 12.4 implemented — stepped goal line, shared Y-axis ticks, bar touch on daily + monthly charts, tests + KPI-01 guard
