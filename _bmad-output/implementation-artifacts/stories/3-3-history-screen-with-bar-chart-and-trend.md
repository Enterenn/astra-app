# Story 3.3: History Screen with Bar Chart and Trend

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want to toggle 7-day and 30-day bar charts with a weekly trend indicator,
So that I can understand my movement patterns over time.

## Acceptance Criteria

1. **Given** the History tab is selected
   **When** data exists
   **Then** `PeriodToggle` switches 7d/30d views and `StepBarChart` renders accent-muted bars with dashed goal line (FR16, UX-DR9)
   **And** chart rebind on toggle has no loading animation (KPI-01 UX)

2. **Given** sufficient history exists
   **When** the screen loads
   **Then** `TrendChip` shows informational weekly comparison vs prior week — no coach copy (FR17, UX-DR10)

3. **Given** no history yet
   **When** History opens
   **Then** empty state copy displays: "No history yet. Walk a bit — data stays on this device."

4. **Given** chart semantics
   **When** inspected with screen reader
   **Then** baseline Semantics labels apply per UX §4.3 (UX-DR19 partial)

## Tasks / Subtasks

- [x] **Sub-task A — `HistoryState` + `HistoryCubit`** (AC: #1–#3, repository-only reads)
  - [x] Add `lib/presentation/cubits/history_state.dart`:
    - `HistoryStatus`: `loading`, `empty`, `ready`.
    - `HistoryPeriod`: `days7`, `days30` (maps to repository `7` / `30`).
    - Fields: `status`, `period`, `chartPoints` (`List<ChartDayAggregate>` **oldest-first** for chart X-axis), `dailyGoal`, `TrendSnapshot? trend` (nullable when hidden).
  - [x] Add `lib/presentation/cubits/history_cubit.dart`:
    - Inject `StepRepository`, `UserPreferencesRepository` (goal only).
    - `Future<void> refresh({bool silent = true})` — parallel `getChartDailyAggregates(days: 30)` + `getDailyStepGoal()`.
    - **Never** call `upsertIngestionBucket()` or raw SQL.
    - Map repository newest-first list → `chartPoints` oldest-first via `.reversed.toList()`.
    - `void selectPeriod(HistoryPeriod period)` — update period, slice `chartPoints` from cached 30d aggregates (no second DB call on toggle).
    - **Empty detection:** `empty` when sum of `totalSteps` across **all 30 cached days** is `0`.
    - **Trend math (FR17)** on cached 30d aggregates (newest-first indices from repo before reverse):
      - `currentWeekSum` = sum of days `[0..6]` (today + prior 6 local days).
      - `priorWeekSum` = sum of days `[7..13]`.
      - If `priorWeekSum == 0` and `currentWeekSum == 0` → hide chip (`trend == null`).
      - If `priorWeekSum == 0` and `currentWeekSum > 0` → flat/muted copy: "No prior week data".
      - Else `pct = ((currentWeekSum - priorWeekSum) / priorWeekSum * 100).round()`; direction up/down/flat; copy **informational only** (e.g. "Up 12% from last week" / "Down 8% from last week" / "Same as last week") — **no** coach language.
    - In-flight guard like `TodayCubit` (`_refreshInFlight`) to avoid duplicate loads.
  - [x] Add `test/presentation/cubits/history_cubit_test.dart` — fake prefs + in-memory DB + `DataInjectService` or hand-insert; assert 7/30 slice lengths, empty state, trend up/down/flat/hidden, period toggle does not hit DB twice (mock/spy optional).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — `PeriodToggle` widget** (AC: #1, #4)
  - [x] Add `lib/presentation/widgets/period_toggle.dart`:
    - Props: `HistoryPeriod selected`, `ValueChanged<HistoryPeriod> onChanged`.
    - Segmented pill on `bgSubtle`, selected segment `bgElevated` + accent underline; **48dp** min touch height (UX §2.4, §4.2).
    - Semantics: label `"Chart range"`; selected value `"7 days"` / `"30 days"` (UX §4.3).
  - [x] Widget test: tap 30d segment fires callback; semantics labels present.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — `StepBarChart` widget (`fl_chart`)** (AC: #1, #3, #4)
  - [x] Add `lib/presentation/widgets/step_bar_chart.dart`:
    - Props: `List<ChartDayAggregate> points` (oldest-first), `int dailyGoal`, `HistoryStatus status`.
    - **Loading:** 7 gray bar skeletons (UX-DR9) — not fl_chart.
    - **Empty:** centered copy exactly: `No history yet. Walk a bit — data stays on this device.`
    - **Ready:** `BarChart` with `duration: Duration.zero` (KPI-01 — no animation on rebind; fl_chart 1.2+ uses `duration`, not deprecated `swapAnimationDuration`).
    - Bars: `colors.accentPrimaryMuted`, top radius 4dp (`BorderRadius.vertical(top: Radius.circular(4))`).
    - Goal line: horizontal dashed `colors.dataGoalLine` at Y = `dailyGoal` (aggregated daily total scale).
    - X-axis: short day labels (Mon/Tue… or `d/M`) via `intl` **or** lightweight local formatter — Figtree `AstraTypography.captionFor`, muted color.
    - Y-axis: minimal — show `0` and max only; no grid clutter (UX §2.4).
    - Plot background: `colors.bgSubtle`; container `radius.md` (12dp).
    - `minHeight: 200` logical pixels (UX §3.4, §4.4).
    - Semantics wrapper: `"Step history bar chart"` (UX §4.3); decorative chart internals `excludeSemantics: true` where appropriate.
    - Touch: `BarTouchData(enabled: false)` Phase 0 (UX §4.2 — display only).
  - [x] Add `test/presentation/widgets/step_bar_chart_test.dart` — empty copy, loading skeleton count, semantics label, ready state builds without throw.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — `TrendChip` widget** (AC: #2, #4)
  - [x] Add `lib/presentation/cubits/history_state.dart` → `TrendSnapshot` enum (`up`, `down`, `flat`, `hidden`) + `int? percent` + `String label`.
  - [x] Add `lib/presentation/widgets/trend_chip.dart`:
    - Icon arrow + label; colors: up → `dataPositive`, down → `dataNegative`, flat/hidden → `textMuted` / omit widget when hidden.
    - Copy pattern: `"Up {n}% from last week"` — never "Great progress!" (UX-DR10).
  - [x] Widget test: renders correct color/copy for up/down/flat; hidden → `SizedBox.shrink()`.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — `HistoryScreen` + `AppScaffold` / `AstraApp` wiring** (AC: #1–#4, refresh triggers)
  - [x] Replace `lib/presentation/screens/history_screen.dart` placeholder with real layout (UX §2.4, §3.4):
    - Optional title `History` (`AstraTypography.title`).
    - `PeriodToggle` → `context.read<HistoryCubit>().selectPeriod`.
    - `TrendChip` when `state.trend` visible.
    - `Expanded` → `StepBarChart`.
  - [x] `AppScaffold`:
    - Hoist `HistoryCubit` alongside `TodayCubit` (constructor `createHistoryCubit` for tests).
    - `BlocProvider.value` when index == 1.
    - `_onDestinationSelected`: when `index == 1`, `unawaited(_historyCubit.refresh())`.
    - Extend `registerOnIngestionComplete` handler to also `_historyCubit.refresh(silent: true)`.
    - `onHistoryCubitReady` callback (mirror Today) for `AstraApp` resume refresh.
  - [x] `AstraApp`: on `AppLifecycleState.resumed`, after today metadata refresh, call `_historyCubit?.refresh(silent: true)` if non-null.
  - [x] Respect `MediaQuery.disableAnimationsOf(context)` for any optional toggle chrome (instant segment swap).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task F — Verification** (AC: #1–#4)
  - [x] Run `flutter analyze` and `flutter test`.
  - [x] Manual: run dev inject (`lib/dev/README.md`) → History tab → 7d bars + goal line; toggle 30d instant rebind; trend chip visible; purge DB → empty copy.
  - [x] Manual: TalkBack/VoiceOver spot-check `PeriodToggle` + chart semantics.
  - [x] Review brief notes deferrals: `chart_benchmark.dart` KPI-01 p95 → **Story 3.4**; import/purge refresh hooks fully exercised in Epic 4.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 3.3:**
- `HistoryCubit` / `HistoryState` — read path only; calls `getChartDailyAggregates` + `getDailyStepGoal`.
- Widgets: `PeriodToggle`, `StepBarChart`, `TrendChip`.
- `HistoryScreen` real layout; `AppScaffold` + `AstraApp` refresh wiring.
- Weekly trend (FR17) computed in cubit from cached 30-day aggregates — **not** in repository, **not** in widgets.
- Semantics baseline (UX §4.3).
- Unit/widget tests listed above.

**Out of scope — defer to later stories:**
- `lib/dev/chart_benchmark.dart`, KPI-01 p95 harness, regression log → **Story 3.4**.
- Post-import / post-purge / lifecycle refresh from My Data flows → **Epic 4** (wire cubit refresh when those screens exist; ingestion callback is in scope now).
- Per-bar screen reader labels, chart tap/tooltip → Phase 0 optional (UX §4.3).
- `DataLifecycleService` production compaction → **Story 4.1**.
- My Data footprint, CSV, purge UI → **Epic 4**.

Do not over-implement. This story is the **first real History surface** — not the performance benchmark harness.

### Pipeline position (Epic 3 — third story)

```text
ChartDayAggregate + getChartDailyAggregates()  ← Story 3.2 ✅
        │
        v
HistoryCubit + PeriodToggle + StepBarChart + TrendChip  ← THIS STORY
        │
        v
lib/dev/chart_benchmark.dart (KPI-01 p95)     ← Story 3.4
```

### Architecture contracts (must match exactly)

**Layering (D-21, NFR-1, NFR-9):**

| Layer | Responsibility |
|-------|----------------|
| `StepRepository.getChartDailyAggregates` | Daily totals, zero-fill, newest-first — **already done** |
| `HistoryCubit` | Cache 30d list; slice 7/30; trend math; hold `dailyGoal`; **no SQL** |
| `StepBarChart` | Bind `ChartDayAggregate` to `fl_chart`; **no sum/group** |
| `PeriodToggle` / `TrendChip` | Pure presentation |

**Forbidden patterns** ([Source: `architecture.md` — Anti-patterns]):
- ❌ SQL `date(start_time, zone_offset)` or new aggregation queries for trend
- ❌ Re-aggregating steps in `StepBarChart` or duplicating `LocalDayCalculator` in widgets
- ❌ Animated chart transition on 7d↔30d toggle
- ❌ Coach / gamified trend copy
- ❌ `8640+` bar groups (must be ≤30 `BarChartGroupData` entries)

**Cubit refresh triggers** ([Source: `architecture.md` — Cubit refresh triggers]):

| Trigger | Action |
|---------|--------|
| History tab selected | `refresh()` |
| App resume | `refresh(silent: true)` |
| `BackgroundCollector` ingestion complete | `refresh(silent: true)` |
| 7d↔30d toggle | Slice cached data only — **no** `refresh()` |

**Chart data ordering:**

`getChartDailyAggregates` returns **newest-first** (index 0 = today). `StepBarChart` needs **oldest-left** → reverse once in cubit when emitting `chartPoints`.

**Goal line:**

Horizontal dashed line at `dailyGoal` on the Y axis where bar height = `ChartDayAggregate.totalSteps` (daily total). Same goal for every day (from `UserPreferencesRepository.getDailyStepGoal()`).

**Empty vs sparse:**

- **Empty (AC #3):** no step samples in DB window → all 30 cached `totalSteps == 0` → `HistoryStatus.empty`, show copy in chart area.
- **Sparse:** some days zero, some non-zero → `ready`; bars at zero can be absent or zero-height per UX ("gaps = zero-height or absent bar").

### FR-17 trend specification (implement exactly)

Use **calendar weeks anchored to reference today** from repository clock (same as chart window):

| Window | Local days (inclusive) |
|--------|-------------------------|
| Current week | `referenceToday` − 6 … `referenceToday` |
| Prior week | `referenceToday` − 13 … `referenceToday` − 7 |

Percentage only when `priorWeekSum > 0`:

`percent = ((currentWeekSum - priorWeekSum) / priorWeekSum * 100).round()`

Direction: `percent > 0` → up; `< 0` → down; `== 0` → flat.

Trend chip is **independent** of whether user views 7d or 30d chart (always week-over-week).

### Current code state (READ before editing)

| Path | Current state | What 3.3 changes | Must preserve |
|------|---------------|------------------|---------------|
| `lib/presentation/screens/history_screen.dart` | `TabPlaceholderBody` placeholder | Full History layout | Tab route index `1` in scaffold |
| `lib/presentation/screens/app_scaffold.dart` | `const HistoryScreen()` | Provide `HistoryCubit`, refresh on tab + ingestion | Today cubit lifecycle unchanged |
| `lib/app.dart` | Resume → `_todayCubit?.refreshMetadata()` | Also refresh `HistoryCubit` when mounted | Live step pipeline unchanged |
| `lib/data/repositories/step_repository.dart` | `getChartDailyAggregates` ✅ | **No change** unless bug found | `getTodaySteps` unchanged |
| `lib/data/models/chart_day_aggregate.dart` | Read model ✅ | Consumed as-is | — |
| `lib/presentation/cubits/today_cubit.dart` | Reference pattern for refresh guard, silent refresh | Mirror patterns | Do not break Today |
| `pubspec.yaml` | `fl_chart: ^1.2.0` already declared | **No pubspec change** unless `intl` added for date labels — if added, update `docs/DEPENDENCIES.md` |

### Recommended file layout

```text
lib/presentation/cubits/history_state.dart              # NEW
lib/presentation/cubits/history_cubit.dart            # NEW
lib/presentation/widgets/period_toggle.dart           # NEW
lib/presentation/widgets/step_bar_chart.dart            # NEW
lib/presentation/widgets/trend_chip.dart                # NEW
lib/presentation/screens/history_screen.dart            # UPDATE (replace placeholder)
lib/presentation/screens/app_scaffold.dart              # UPDATE (HistoryCubit hoist)
lib/app.dart                                            # UPDATE (resume refresh)
test/presentation/cubits/history_cubit_test.dart        # NEW
test/presentation/widgets/period_toggle_test.dart       # NEW
test/presentation/widgets/step_bar_chart_test.dart      # NEW
test/presentation/widgets/trend_chip_test.dart          # NEW
```

### `fl_chart` binding notes (v1.2.0 — already in pubspec)

- Use `BarChart` + `BarChartData` with one `BarChartGroupData` per day (≤30 groups).
- **Disable animation:** `BarChart(duration: Duration.zero, ...)` ([fl_chart handle_animations.md](https://github.com/imaNNeo/fl_chart/blob/main/repo_files/documentations/handle_animations.md)).
- Optional: `ValueKey(selectedPeriod)` on chart widget to force clean rebuild on toggle.
- Theme colors via `context.astraColors` — never hardcode `#EAD55E` in widget.
- Phase 0: disable bar touch (`BarTouchData(enabled: false)`).

### UX compliance checklist (UX-DR9, UX-DR10, §2.4, §3.4, §4.3)

| Requirement | Implementation |
|-------------|----------------|
| Accent-muted bars | `accentPrimaryMuted` |
| Dashed goal line | `dataGoalLine` |
| 48dp toggle | `PeriodToggle` constraints |
| Empty copy (exact) | See AC #3 string |
| No 7d↔30d animation | `Duration.zero` + no `AnimatedSwitcher` on chart data |
| Trend copy informational | `TrendChip` strings — no coach tone |
| Chart min height 200dp | `ConstrainedBox` / `SizedBox` |
| Semantics | See AC #4 table in UX §4.3 |

### Anti-patterns

- Do not add `getChartDailyAggregates(days: 14)` or SQL trend queries — use 30d cache + cubit math.
- Do not create `chart_benchmark.dart` — Story 3.4.
- Do not change repository aggregation algorithm — Story 3.2 locked unless regression.
- Do not add second chart library.
- Do not use `AnimatedSwitcher` for period changes on chart data series.
- Do not fetch 7d and 30d separately on every toggle (NFR-1 / KPI-01 prep).

### Testing requirements

| Area | Requirement |
|------|-------------|
| Cubit | empty DB, inject 90d → ready + non-zero bars, 7↔30 slice lengths, trend up/down, toggle without extra DB call |
| Widgets | semantics, empty copy, skeleton, trend colors |
| Regression | `step_repository_chart_aggregates_test.dart` + full `flutter test` |
| Manual | dev inject README flow + toggle latency sanity (formal p95 → 3.4) |

Run: `flutter analyze`, `flutter test`, manual History tab check with inject.

### Previous story intelligence (Story 3.2 — done)

- `getChartDailyAggregates({required int days})` — 7 or 30 only; zero-fill; newest-first; Dart `LocalDayCalculator` grouping.
- `ChartDayAggregate` read model in `lib/data/models/chart_day_aggregate.dart`.
- Tests in `test/data/repositories/step_repository_chart_aggregates_test.dart` — reuse `FakeTimeProvider`, `DataInjectService`, `openAstraDatabase(inMemoryDatabasePath)`.
- Code review removed redundant sort; 30d boundary tests added.
- **Explicit deferral to this story:** `HistoryCubit`, `StepBarChart`, `PeriodToggle`, weekly trend, `fl_chart` usage.

### Previous story intelligence (Story 3.1 — dev dataset)

- `DataInjectService.inject90Days()` — 25 920 rows, anchor `2026-06-02T12:00:00Z`, `+02:00`, `Random(42)`.
- After `LifecycleSimulator` — 10 080 rows; daily totals conserved.
- Use inject in manual QA and cubit tests for realistic chart heights.

### Previous story intelligence (Story 2.5 — Today surface patterns)

- Cubit: `refresh({bool silent})`, in-flight dedup, `BlocProvider` hoist in `AppScaffold`.
- Widget tests under `test/presentation/widgets/`.
- Review-before-commit per sub-task ([Source: `docs/project-context.md`]).
- Ingestion callback registration pattern on `BackgroundCollector`.

### Git intelligence (recent commits)

Recent work completed Story 3.2:

- `258f2b4` — chart aggregates review fixes
- `a27a914` / `afa5a0c` — `getChartDailyAggregates` + `ChartDayAggregate`
- `a62cd29` — unit tests

No History UI exists yet — build on stable repository API. Match `today_cubit_test.dart` fixture style.

### Latest tech information

| Technology | Version / note |
|------------|----------------|
| Flutter | 3.44.0 stable (architecture baseline) |
| `fl_chart` | ^1.2.0 — use `duration: Duration.zero` on `BarChart` for KPI-01 UX |
| `flutter_bloc` | Cubit pattern — same as Today |
| `intl` | Only add if needed for axis date formatting; prefer minimal dependency |

No new chart packages. `fl_chart` already in `pubspec.yaml` — do not duplicate-declare.

### Project context reference

- Review-before-commit gate applies to every sub-task ([Source: `docs/project-context.md`])
- Story files live in `_bmad-output/implementation-artifacts/stories/`
- Update `docs/DEPENDENCIES.md` only if new packages added (e.g. `intl`)

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Epic 3, Story 3.3]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — D-07, D-11, D-21, NFR-1, Cubit triggers, anti-patterns]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §2.4, §3.4, §4.2–4.3, UX-DR9, UX-DR10]
- [Source: `lib/data/repositories/step_repository.dart` — `getChartDailyAggregates`]
- [Source: `lib/data/models/chart_day_aggregate.dart`]
- [Source: `lib/presentation/cubits/today_cubit.dart` — refresh / scaffold patterns]
- [Source: `_bmad-output/implementation-artifacts/stories/3-2-history-chart-data-aggregation.md` — upstream API + deferrals]
- [Source: `lib/dev/README.md` — manual inject for QA]

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- `flutter analyze` — clean (no issues)
- `flutter test` — 238/238 passed

### Completion Notes List

- Implemented `HistoryCubit` with 30-day cache, 7/30 slice on toggle (no extra DB call), FR-17 trend math, and in-flight refresh guard mirroring `TodayCubit`.
- Added `PeriodToggle`, `StepBarChart` (fl_chart, `Duration.zero`), and `TrendChip` widgets with UX semantics baseline.
- Wired `HistoryScreen`, `AppScaffold` (tab + ingestion refresh), and `AstraApp` (resume refresh).
- Unit/widget tests added; existing scaffold/widget tests updated for real History surface.
- Deferred: `chart_benchmark.dart` KPI-01 p95 → Story 3.4; My Data import/purge refresh → Epic 4.

### File List

- lib/presentation/cubits/history_state.dart (new)
- lib/presentation/cubits/history_cubit.dart (new)
- lib/presentation/widgets/period_toggle.dart (new)
- lib/presentation/widgets/step_bar_chart.dart (new)
- lib/presentation/widgets/trend_chip.dart (new)
- lib/presentation/screens/history_screen.dart (updated)
- lib/presentation/screens/app_scaffold.dart (updated)
- lib/app.dart (updated)
- test/presentation/cubits/history_cubit_test.dart (new)
- test/presentation/widgets/period_toggle_test.dart (new)
- test/presentation/widgets/step_bar_chart_test.dart (new)
- test/presentation/widgets/trend_chip_test.dart (new)
- test/presentation/screens/app_scaffold_test.dart (updated)
- test/widget_test.dart (updated)

### Change Log

- 2026-06-02: Story 3.3 — History screen with bar chart, period toggle, weekly trend chip, cubit wiring, and tests.

## Story Completion Status

- **Status:** review
- **Completion note:** Ultimate context engine analysis completed — comprehensive developer guide created
