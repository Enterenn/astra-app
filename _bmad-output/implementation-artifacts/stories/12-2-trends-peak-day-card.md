# Story 12.2: Trends Peak Day Card

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want to see my best day in the selected period,
So that I know my peak performance.

## Acceptance Criteria

1. **Given** Trends tab with **7 days** or **30 days** toggle selected  
   **When** the active window has at least one day with `totalSteps > 0` (`HistoryStatus.ready`)  
   **Then** a **Peak day** stat card renders **below** the average stats row (`TrendsAverageStatsRow`)  
   **And** displays the local date label and step count of the day with maximum `totalSteps` in that window  
   **And** ties break to the **most recent** day (same calendar day wins if tied with an older day)

2. **Given** peak day computation for the active window  
   **When** calculated  
   **Then** source data is the same `_cachedDayMetrics30d` slice used for period averages (newest-first, first `period.dayCount` entries)  
   **And** only days with `totalSteps > 0` are candidates for peak  
   **And** period toggle **7d ↔ 30d** recomputes peak from cache only — **no** extra `getChartDailyAggregates` or bucket DB calls (KPI-01 / FR-28)

3. **Given** date label formatting (no Figma mockup — locked here)  
   **When** peak card renders  
   **Then** date label follows the same period context as the bar chart x-axis:
   - **7d window:** weekday short + day number — e.g. `Wed 4` via `CalendarWeek.weekdayLabelFor(localDay)` + space + `localDay.day`
   - **30d window:** `day/month` — e.g. `4/6` (matches `StepBarChart._formatDayLabel` for 30d)  
   **And** step count displays as plain integer + `steps` unit inline (same typography pattern as average cards)

4. **Given** Trends is loading or the active window has no steps (`HistoryStatus.loading` / `HistoryStatus.empty` / ready with zero-step window)  
   **When** screen renders  
   **Then** peak day card is **hidden** (`peakDay == null`) — consistent with Story 12.1 `periodAverages == null` pattern  
   **And** no misleading placeholder values

5. **Given** card copy and layout  
   **When** card renders in light theme  
   **Then** full-width `ElevatedCard` (not 50/50 split — single stat)  
   **And** trophy icon top-left (`PhosphorIconsRegular.trophy` — same family as `WeekTrophyBadge`)  
   **And** value line: `{dateLabel}` + `{stepCount}` + `steps` — bold primary value, unit same line smaller weight  
   **And** caption below: `peak day in this period` — `AstraTypography.captionFor`, muted  
   **And** semantics label e.g. `Peak day Wednesday 4 with 8500 steps in this period`

6. **Given** implementation complete  
   **When** `flutter analyze` and targeted tests run  
   **Then** no new analyzer issues  
   **And** cubit tests cover peak selection, tie-break to most recent, 7d vs 30d slice, toggle without extra DB  
   **And** widget/smoke tests assert card visible on seeded ready state and hidden when `peakDay` is null

**Depends on:** Story 12.1 (done) — `_cachedDayMetrics30d`, `TrendsAverageStatsRow`, `HistoryCubit` cache pattern.  
**Enables:** Story 12.3 (12-month chart — separate section; do not conflate with 7d/30d stats).  
**Out of scope:** 12-month monthly chart (12.3), per-day goal line (12.4), kcal on peak day, navigation to Steps for that day, chart bar highlight for peak day.  
**Mockup ref:** None — product spec `sprint-change-proposal-2026-06-15.md` § User decisions (peak day respects 7d/30d toggle).

## Tasks / Subtasks

- [x] **Sub-task A — Peak day model + `HistoryCubit` computation** (AC: #1, #2, #4)
  - [x] Add `TrendsPeakDay` immutable type: `localDay`, `totalSteps`, `dateLabel` (label computed in cubit so widget stays dumb)
  - [x] Extend `HistoryState` with optional `TrendsPeakDay? peakDay` — `null` when loading/empty/zero-step window
  - [x] Add `_computePeakDayForPeriod(HistoryPeriod period)`:
    - Slice `_cachedDayMetrics30d.take(period.dayCount)` (newest-first)
    - Iterate in order; track max `totalSteps` among days with `totalSteps > 0`
    - On tie (`==`), keep first winner → most recent day (newest-first iteration)
    - Build `dateLabel` via private `_formatPeakDayLabel(localDay, period)`
  - [x] Wire into `_emitReady` / `selectPeriod` alongside `_computeAveragesForPeriod`
  - [x] Return `null` when `!slice.any((d) => d.totalSteps > 0)` — mirror averages guard
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — `TrendsPeakDayCard` widget** (AC: #3, #5)
  - [x] Create `lib/presentation/widgets/trends_peak_day_card.dart`:
    - Props: `TrendsPeakDay peakDay`
    - Reuse card structure from `_TrendsStatCard` in `trends_average_stats_row.dart` (icon, value+unit row, caption) — **extract shared private card only if trivial; duplicating ~40 lines is acceptable to avoid scope creep**
    - Trophy icon, date + steps on value line, caption `peak day in this period`
  - [x] **Do not** fold into `TrendsAverageStatsRow` — peak is full-width below the 50/50 row
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Wire `HistoryScreen` layout** (AC: #1, #4)
  - [x] Below `TrendsAverageStatsRow`, when `state.peakDay != null`:
    ```dart
    const SizedBox(height: AstraSpacing.kSpaceSm),
    TrendsPeakDayCard(peakDay: state.peakDay!),
    ```
  - [x] Gate on same condition as averages row (`state.periodAverages != null`) or explicitly `state.peakDay != null` inside that block
  - [x] Verify bottom nav clearance unchanged; card not inside `Expanded`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Tests** (AC: #6)
  - [x] `test/presentation/cubits/history_cubit_test.dart`:
    - Seed 7d with distinct step totals → expect correct peak day and steps
    - Tie on max steps (two days same count) → most recent day wins
    - `selectPeriod` 7d→30d changes peak without incrementing chart aggregate spy
    - Zero-step active window → `peakDay` null
  - [x] `test/presentation/widgets/trends_peak_day_card_test.dart` — date label, steps, caption, trophy, semantics
  - [x] Extend `screen_smoke_test.dart` History group — peak card visible when seeded; hidden when null
  - [x] Run `flutter analyze` + targeted tests; confirm `chart_benchmark_test.dart` unchanged on toggle
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| Area | In scope (12.2) | Out of scope |
|------|-----------------|--------------|
| Peak day card | Full-width below average cards, 7d/30d window | 12-month chart (12.3) |
| Data source | `_cachedDayMetrics30d` slice (steps only) | Kcal, buckets, distance |
| Tie-break | Most recent day on equal `totalSteps` | Random / oldest day |
| Empty state | Hidden (`peakDay == null`) | Em dash placeholder (12.1 chose hide) |
| Chart | Unchanged | Highlight peak bar (12.4) |
| Version bump | None | Epic 12 close → `0.5.0+7` |

### Layout order (top → bottom)

Title → `PeriodToggle` → optional `TrendChip` → `Expanded(StepBarChart)` → `TrendsAverageStatsRow` (12.1) → **`TrendsPeakDayCard`** (this story).

### Current code state (READ BEFORE EDITING)

**`lib/presentation/screens/history_screen.dart`** — averages row wired; insert peak card immediately below:

```dart
if (state.periodAverages != null) ...[
  const SizedBox(height: AstraSpacing.kSpaceMd),
  TrendsAverageStatsRow(averages: state.periodAverages!),
  if (state.peakDay != null) ...[
    const SizedBox(height: AstraSpacing.kSpaceSm),
    TrendsPeakDayCard(peakDay: state.peakDay!),
  ],
],
```

**`lib/presentation/cubits/history_cubit.dart`** — `_cachedDayMetrics30d` built in `_buildDayMetricsCache` on refresh only. `_computeAveragesForPeriod` already slices cache and guards zero-step windows — **mirror adjacent**.

**`lib/presentation/cubits/history_state.dart`** — add `TrendsPeakDay? peakDay`; extend `ready` factory and `copyWith`.

**`lib/presentation/widgets/trends_average_stats_row.dart`** — reference for `_TrendsStatCard` visual pattern (icon, value+unit, caption). Peak card is full-width single column, not 50/50 `Row`.

### Peak day algorithm (locked)

```dart
TrendsPeakDay? _computePeakDayForPeriod(HistoryPeriod period) {
  final slice = _cachedDayMetrics30d.take(period.dayCount);
  TrendsDayMetrics? best;
  for (final day in slice) {
    if (day.totalSteps == 0) continue;
    if (best == null || day.totalSteps > best.totalSteps) {
      best = day;
    }
    // Equal steps: keep `best` — first seen in newest-first slice is most recent
  }
  if (best == null) return null;
  return TrendsPeakDay(
    localDay: best.localDay,
    totalSteps: best.totalSteps,
    dateLabel: _formatPeakDayLabel(best.localDay, period),
  );
}
```

**Tie-break proof:** `_cachedDayMetrics30d` is newest-first (same order as `getChartDailyAggregates` return). Iterating forward and updating only on `>` means the first day reaching the maximum wins — the most recent tied day.

**Window alignment:** Use identical `take(period.dayCount)` as `_computeAveragesForPeriod` — do not re-slice aggregates separately.

### Date label helper (locked)

```dart
String _formatPeakDayLabel(DateTime localDay, HistoryPeriod period) {
  return switch (period) {
    HistoryPeriod.days7 =>
      '${CalendarWeek.weekdayLabelFor(localDay)} ${localDay.day}',
    HistoryPeriod.days30 =>
      '${localDay.day}/${localDay.month}',
  };
}
```

Import `../../core/time/calendar_week.dart` in cubit (already used elsewhere in presentation layer via widgets — cubit may import core).

### Performance guardrails (KPI-01)

| Operation | When | DB cost |
|-----------|------|---------|
| Peak day compute | `refresh()` emit + `selectPeriod` | **0** — reads `_cachedDayMetrics30d` only |
| Period toggle | `selectPeriod` | **0** — slice + max scan ≤ 30 items |

**Not acceptable:** Per-toggle repository calls or bucket fetches.

### Architecture compliance

| Rule | Application |
|------|-------------|
| `HistoryCubit` owns Trends aggregates | Extend — do not create `TrendsCubit` |
| Pure metrics | Steps from `TrendsDayMetrics.totalSteps` — no new MET math |
| No reactive streams | Cache + emit on refresh/toggle only |
| Presentation widgets | New card in `presentation/widgets/` |
| Review-before-commit | One commit per sub-task A–D per `docs/project-context.md` |
| Phosphor icons | `phosphoricons_flutter` — no new deps |

### Reuse — do NOT reinvent

| Need | Use existing |
|------|--------------|
| Per-day step totals in cache | `TrendsDayMetrics` / `_cachedDayMetrics30d` |
| Period slice | Same `take(period.dayCount)` as averages |
| Weekday short label | `CalendarWeek.weekdayLabelFor` |
| 30d date shorthand | Match `StepBarChart._formatDayLabel` (`day/month`) |
| Card surface | `ElevatedCard` from `elevated_card.dart` |
| Trophy icon | `PhosphorIconsRegular.trophy` (`week_trophy_badge.dart`) |
| Spacing / type | `AstraSpacing`, `AstraTypography` |
| Empty guard | Same as `periodAverages == null` when no steps in window |

### Recommended `HistoryState` extension

```dart
class TrendsPeakDay {
  const TrendsPeakDay({
    required this.localDay,
    required this.totalSteps,
    required this.dateLabel,
  });
  final DateTime localDay;
  final int totalSteps;
  final String dateLabel;
}

// In HistoryState:
final TrendsPeakDay? peakDay;
```

Populate in `HistoryState.ready`; `null` in `loading` / `empty` / when active window has no steps.

### `refreshGoal` behavior

**No change required** — peak day depends on step totals, not goals.

### Testing requirements

| Test file | Coverage |
|-----------|----------|
| `history_cubit_test.dart` | **UPDATE** — peak selection, tie-break, toggle cache-only, null on empty window |
| `trends_peak_day_card_test.dart` | **NEW** — layout, copy, semantics |
| `screen_smoke_test.dart` | **UPDATE** — peak visible/hidden |
| `trends_average_stats_row_test.dart` | **No change** |
| `chart_benchmark_test.dart` | **No regression** |

**Cubit test seeding:** Reuse patterns from Story 12.1 tests — `upsertIngestionBucket` + daily totals via test repository.

**Hand-check tie-break:** Newest-first seed: day0=5000, day1=8000, day2=8000 (day0 most recent) → peak = day0 with 8000 steps.

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/cubits/history_state.dart` | **UPDATE** — `TrendsPeakDay`, `peakDay` field |
| `lib/presentation/cubits/history_cubit.dart` | **UPDATE** — `_computePeakDayForPeriod`, wire emit |
| `lib/presentation/widgets/trends_peak_day_card.dart` | **NEW** |
| `lib/presentation/screens/history_screen.dart` | **UPDATE** — wire peak card below averages |
| `test/presentation/cubits/history_cubit_test.dart` | **UPDATE** |
| `test/presentation/widgets/trends_peak_day_card_test.dart` | **NEW** |
| `test/presentation/screens/screen_smoke_test.dart` | **UPDATE** |

### Library / framework requirements

- Flutter SDK + `flutter_bloc` per `pubspec.yaml` — **no new dependencies**
- No `intl` / `DateFormat` — match project convention (lightweight string formatting)

### Previous story intelligence (Story 12.1 — immediate predecessor)

- `_cachedDayMetrics30d` built on `refresh()` via parallel bucket fetches + `DerivedActivityMetrics` — peak day **only needs `totalSteps`** from that cache
- `periodAverages` hidden when active window has no steps — **apply same guard to `peakDay`**
- Code review fix: atomic cache commit on refresh; hide averages when zero-step window — do not regress
- Sub-task commit rhythm: A cubit → B widget → C screen → D tests
- `TrendsAverageStatsRow` uses `_TrendsStatCard` private widget — peak card can mirror without refactoring averages row

### Previous story intelligence (Epic 11 — trophy pattern)

- `WeekTrophyBadge` uses `PhosphorIconsRegular.trophy` at ~16–20dp — match icon size in peak card (~20dp like average cards)

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `2dd9da3` | 12.1 review hardening — cache consistency, zero-step visibility guard |
| `ee68a05` / `10068d3` | Screen + widget wiring pattern for Trends stats |
| `48b345f` | Test coverage pattern: cubit + widget + smoke |

### Latest technical notes (2026)

- **`TrendsDayMetrics` order:** Newest-first, aligned with `ChartDayAggregate` repository order — critical for tie-break
- **Max scan cost:** O(7) or O(30) per toggle — negligible vs KPI-01 budget
- **No chart coupling:** Peak card is presentation-only; chart `StepBarChart` unchanged

### Project context reference

- Review-before-commit: `docs/project-context.md` § Development Workflow
- Versioning: Epic 12 close → `0.5.0+7` — not per story
- Sprint sequencing: `sprint-change-proposal-2026-06-15.md` § 4.4 Trends, § User decisions — peak day on 7d/30d toggle

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` § Epic 12, Story 12.2]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` § User decisions — peak day 7d/30d]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` § 2.4 Trends Surface — layout baseline (no peak mockup)]
- [Source: `_bmad-output/implementation-artifacts/stories/12-1-trends-average-stats-cards.md`]
- [Source: `lib/presentation/cubits/history_cubit.dart`]
- [Source: `lib/presentation/widgets/trends_average_stats_row.dart`]
- [Source: `lib/presentation/widgets/step_bar_chart.dart` § `_formatDayLabel`]
- [Source: `lib/core/time/calendar_week.dart`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- `_computePeakDayForPeriod` mirrors `_computeAveragesForPeriod` slice/guard pattern
- Tie-break: forward iteration on newest-first cache, update only on `>` keeps most recent tied day
- `_formatPeakDayLabel`: 7d uses `CalendarWeek.weekdayLabelFor` + day; 30d uses `day/month`

### Completion Notes List

- Added `TrendsPeakDay` model and `peakDay` field on `HistoryState` (ready factory + copyWith)
- `HistoryCubit` computes peak from `_cachedDayMetrics30d` on refresh and period toggle — zero DB cost on toggle
- New full-width `TrendsPeakDayCard` below `TrendsAverageStatsRow` on Trends screen
- Tests: 5 cubit cases (selection, tie-break, toggle cache-only, null guards), widget + smoke coverage
- `flutter analyze` clean; 61 targeted tests pass including `chart_benchmark_test.dart` (KPI-01 toggle unchanged)

### File List

- lib/presentation/cubits/history_state.dart
- lib/presentation/cubits/history_cubit.dart
- lib/presentation/widgets/trends_peak_day_card.dart
- lib/presentation/screens/history_screen.dart
- test/presentation/cubits/history_cubit_test.dart
- test/presentation/widgets/trends_peak_day_card_test.dart
- test/presentation/screens/screen_smoke_test.dart

## Change Log

- 2026-06-16: Story 12.2 — Peak day card (cubit computation, widget, screen wiring, tests)
