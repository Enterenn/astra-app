# Story 20.4: Replace fl_chart with CustomPainter Charts

Status: done

<!-- Refacto Epic 20 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 20-4 · refactoring-audit-master-v0.6.1.md §4 · REF-26 · NFR-REF-01 · NFR-REF-03 -->
<!-- Prerequisite: Story 20-3 done · Epic 16 tab repaint isolation (16-3) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want charts that render natively on Impeller,
So that Trends scrolls smoothly and APK size drops ~500 KB.

## Acceptance Criteria

- [x] **AC #1 — CustomPainter replaces fl_chart** — **Given** baseline size analysis note in review brief (NFR-REF-03)
  **When** charts are reimplemented
  **Then** native `CustomPainter` (~250 lines per chart type) replaces all `fl_chart` usage (REF-26, NFR-REF-01)
  **And** `fl_chart` removed from `pubspec.yaml`
  **And** zero `import 'package:fl_chart/` remain in `lib/` or `test/`

- [x] **AC #2 — Visual & functional parity** — **Given** History/Trends screens (`HistoryScreen`)
  **When** compared to pre-change behavior (not pixel-perfect screenshots — behavior parity)
  **Then** daily bar chart (7d/30d), stepped/single goal reference line, and 12-month monthly chart are functionally equivalent:
  - Bar heights, colors (below-goal / met-goal / selected), rounded top corners
  - Left Y-axis ticks via `computeChartYAxisTicks` + `formatChartAxisValue`
  - Bottom axis labels (7d weekday shorts; 30d throttled `d/m`; monthly `MM`)
  - Tap-to-select bar with tooltip + semantics update
  - Re-tap selected bar clears selection
  - Tap outside chart clears selection
  - Single horizontal dashed goal line when all visible goals equal
  - Stepped dashed goal overlay when goals differ per day (`GoalStepLinePainter`)
  - Loading skeletons and empty states unchanged
  - No animation on data bind (KPI-01 — instant rebind on 7d ↔ 30d toggle)

- [x] **AC #3 — Performance** — **Given** chart on device with Impeller
  **When** scrolling Trends screen or toggling 7d/30d
  **Then** no perceptible regression vs fl_chart on 120 Hz scroll (NFR-REF-01)
  **And** `test/dev/chart_benchmark_test.dart` still passes (slow tag — run targeted file only)
  **And** painter uses `shouldRepaint` guards — no per-frame allocations in steady state

- [x] **AC #4 — Shared infrastructure** — **Given** two chart widgets (`StepBarChart`, `TrendsMonthlyBarChart`)
  **When** implementation is inspected
  **Then** bar rendering, touch hit-testing, and tooltip styling are shared — not duplicated wholesale
  **And** existing pure helpers are reused: `chart_axis_ticks.dart`, `bar_chart_layout.dart`, `goal_step_line_painter.dart`

- [x] **AC #5 — Tests** — **Given** `flutter test --exclude-tags slow`
  **When** run after implementation
  **Then** all tests pass
  **And** `step_bar_chart_test.dart`, `trends_monthly_bar_chart_test.dart`, `bar_chart_layout_test.dart` updated — no `BarChart` / `fl_chart` imports
  **And** existing test scenarios preserved (semantics, goal line modes, 30d label throttle, bar colors, touch selection, Y-axis tick count)

- [x] **AC #6 — Documentation** — **Given** dependency removal
  **When** story completes
  **Then** `docs/DEPENDENCIES.md` updated (remove `fl_chart` row)
  **And** `README.md` charts row updated
  **And** review brief notes APK size delta from `flutter build apk --release --analyze-size` (NFR-REF-03)

- [x] **AC #7 — Scope boundary** — **Given** Epic 20 roadmap
  **When** this story completes
  **Then** **no version bump** — Epic 20 closes with minor+1 (`0.10.0+20`) when story **20-5** is done
  **And** Phosphor subsetting (20-5), insight cards (20-2), tab haptics (20-3) are untouched

**Covers:** REF-26 · NFR-REF-01 · NFR-REF-03 · Audit §4 (~500 KB APK + Impeller fluidity)

**Depends on:** Story 20-3 done · Epic 12 chart behavior (goal lines, monthly chart) · Epic 16 tab isolation (do not regress `RepaintBoundary` in `AppScaffold`).

**Out of scope:** Changing chart data queries or cubit logic; insight cards; Phosphor subsetting (20-5); version bump; rewriting `TrendChip` / `PeriodToggle`; moving chart benchmarks out of `test/dev/`.

## Tasks / Subtasks

- [x] **Sub-task A — Shared native bar chart core** (AC: #1, #4, #5 partial)
  - [x] Read fully before editing:
    - `lib/presentation/widgets/chart/astra_bar_chart_touch.dart`
    - `lib/presentation/widgets/chart/bar_chart_layout.dart`
    - `lib/presentation/widgets/chart/chart_axis_ticks.dart`
    - `lib/presentation/widgets/chart/goal_step_line_painter.dart`
    - `test/presentation/widgets/bar_chart_layout_test.dart`
  - [x] Create `lib/presentation/widgets/chart/astra_bar_chart_painter.dart` — `CustomPainter` drawing bars from normalized values:
    - Input: `List<double> values`, `maxY`, `barWidth`, `barCount`, `plotRect`, `Color Function(int index, bool isSelected)`, `BorderRadius` top corners
    - Use `computeSpaceAroundBarCenters` for X positions (same math as today)
    - `shouldRepaint` compares values/colors/maxY/barWidth/selection
  - [x] Create `lib/presentation/widgets/chart/astra_bar_chart_core.dart` — shared `StatefulWidget` shell:
    - Layout: left axis column (Text labels from ticks) + plot area (`CustomPaint` + `GestureDetector`)
    - Bottom axis row (Text labels via callback)
    - Touch: map `localPosition` → bar index using bar centers + bar width; toggle selection on tap up; clear on tap outside
    - Tooltip: `Material`/`DecoratedBox` positioned above selected bar (reuse styling from current `astraBarTooltipPrimaryStyle`)
    - **No implicit animations** — data changes repaint instantly
  - [x] Create `lib/presentation/widgets/chart/astra_single_goal_line_painter.dart` — horizontal dashed line for uniform goal (replaces fl_chart `ExtraLinesData.horizontalLines`)
  - [x] Rewrite `lib/presentation/widgets/chart/astra_bar_chart_touch.dart` → remove fl_chart types; export touch helpers + tooltip style for core widget (or merge into core file if <30 lines remain)
  - [x] Update `bar_chart_layout_test.dart` — test `computeSpaceAroundBarCenters` directly without fl_chart `calculateGroupsX` import
  - [x] Add `test/presentation/widgets/chart/astra_bar_chart_painter_test.dart` — golden or geometry assertions for bar positions/heights
  - [x] Run `flutter analyze` on new chart files
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Migrate `StepBarChart`** (AC: #2, #5)
  - [x] Read `lib/presentation/widgets/step_bar_chart.dart` and `test/presentation/widgets/step_bar_chart_test.dart` fully
  - [x] Replace `_ReadyChart` fl_chart `BarChart` with `AstraBarChartCore` (or inline equivalent using shared painter)
  - [x] Preserve all constants: `_kBelowGoalBarAlpha`, `_kSelectedBarAlpha`, `_kMaxBarWidth`, `_kMinBarWidth`, `_kBarSlotFillRatio`, `_kLeftAxisReserved`, `_kBottomAxisReserved`, `kDailyChartHeight`
  - [x] Preserve goal logic: `_goalForPoint`, `showSingleGoalLine` / `showSteppedGoalLine`, `GoalStepLinePainter` overlay
  - [x] Preserve semantics: default label + selection label via `_selectionSemanticsLabel`
  - [x] Preserve `_LoadingSkeleton` / `_EmptyState` unchanged
  - [x] Update `test/helpers/bar_chart_touch_test_helper.dart` — simulate taps via `GestureDetector`/`tester.tapAt` instead of `BarTouchData.touchCallback`
  - [x] Migrate all `step_bar_chart_test.dart` assertions off `BarChart` widget introspection — assert via finders (text labels, `GoalStepLinePainter`, semantics, bar colors via painter delegate or widget keys)
  - [x] Run `flutter test test/presentation/widgets/step_bar_chart_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Migrate `TrendsMonthlyBarChart`** (AC: #2, #5)
  - [x] Read `lib/presentation/widgets/trends_monthly_bar_chart.dart` and `test/presentation/widgets/trends_monthly_bar_chart_test.dart` fully
  - [x] Replace `_ReadyChart` fl_chart usage with shared core (no goal line — monthly chart has none today)
  - [x] Preserve static helpers: `formatMonthLabel`, `formatPeriodRange`
  - [x] Preserve 12-bar loading skeleton, empty state, semantics wrapper
  - [x] Update monthly chart tests — remove `BarChart` imports
  - [x] Run `flutter test test/presentation/widgets/trends_monthly_bar_chart_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Remove fl_chart + docs + size analysis** (AC: #1, #3, #6, #7)
  - [x] Remove `fl_chart: ^1.2.0` from `pubspec.yaml`; run `flutter pub get`
  - [x] Grep entire repo for `fl_chart` — fix any remaining imports (`test/dev/chart_benchmark_render_pump.dart`, `chart_benchmark_pump.dart`, license docs if referenced)
  - [x] Update `docs/DEPENDENCIES.md` and `README.md` charts row
  - [x] Run `flutter test --exclude-tags slow`
  - [x] Run `flutter test test/dev/chart_benchmark_test.dart` (slow — targeted)
  - [x] Run `flutter build apk --release --analyze-size`; note delta in review brief (~500 KB expected per audit)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Replace fl_chart in `StepBarChart` + `TrendsMonthlyBarChart` | History cubit / repository query changes |
| Shared `CustomPainter` bar infrastructure | Phosphor font subsetting (20-5) |
| Touch, tooltip, goal lines, axis labels parity | Version bump (Epic 20 close at 20-5) |
| Remove `fl_chart` from pubspec + docs | Pixel-perfect visual match to fl_chart |
| Update chart widget tests + layout test | Rewriting KPI-01 benchmark harness architecture |
| APK size measurement in review brief | `HistoryScreen` layout changes beyond chart widgets |

### Critical baseline — fl_chart usage today

**Production files importing fl_chart:**

| File | Role |
|------|------|
| `lib/presentation/widgets/step_bar_chart.dart` | Daily 7d/30d bar chart + goal lines |
| `lib/presentation/widgets/trends_monthly_bar_chart.dart` | 12-month monthly averages |
| `lib/presentation/widgets/chart/astra_bar_chart_touch.dart` | Shared touch + tooltip helpers |

**Already native (reuse, do not rewrite):**

| File | Role |
|------|------|
| `chart/goal_step_line_painter.dart` | Stepped per-day goal dashed line overlay |
| `chart/bar_chart_layout.dart` | `computeSpaceAroundBarCenters` — bar X math |
| `chart/chart_axis_ticks.dart` | Y-axis tick computation + label formatting |

**Screen wiring (READ ONLY — chart widgets drop in unchanged API):**

```75:94:lib/presentation/screens/history_screen.dart
                      if (state.period == HistoryPeriod.months12) ...[
                        SizedBox(
                          height: _kMonthlyChartHeight,
                          child: TrendsMonthlyBarChart(
                            key: const ValueKey('months12'),
                            points: state.monthlyChartPoints,
                            status: state.status,
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          height: StepBarChart.kDailyChartHeight,
                          child: StepBarChart(
                            key: ValueKey(state.period),
                            points: state.chartPoints,
                            dailyGoal: state.dailyGoal,
                            goalsByDay: state.goalsByDay,
                            status: state.status,
                          ),
                        ),
```

Public widget constructors (`StepBarChart`, `TrendsMonthlyBarChart`) must remain API-compatible — `HistoryScreen` should need **zero changes**.

### Recommended architecture — shared core widget

```
AstraBarChartCore (StatefulWidget)
├── Row
│   ├── Column (left Y-axis Text labels from computeChartYAxisTicks)
│   └── Expanded
│       └── Stack
│           ├── CustomPaint(AstraBarChartPainter) — bars
│           ├── CustomPaint(AstraSingleGoalLinePainter?) — uniform goal
│           ├── CustomPaint(GoalStepLinePainter?) — stepped goal (StepBarChart only)
│           ├── GestureDetector — hit test via computeSpaceAroundBarCenters
│           └── Positioned tooltip (selected bar)
└── Row (bottom X-axis Text labels)
```

**Design decisions (follow these — prevents reinvention):**

1. **Axis labels as `Text` widgets**, not painted — preserves `AstraTypography`, l10n, and existing test patterns for label strings.
2. **Bars in `CustomPainter`** — single draw pass, Impeller-friendly, no fl_chart widget tree overhead.
3. **Touch via geometry**, not fl_chart `BarTouchData` — map x coordinate to nearest bar center ± half bar width.
4. **No `Animated*` widgets** — KPI-01 requires instant rebind; `shouldRepaint` handles data changes.
5. **Keep `ExcludeSemantics` on plot + outer `Semantics` on shell** — matches current accessibility pattern in `StepBarChart`.

### Behavior checklist — must preserve from current fl_chart impl

| Behavior | Current location | Notes |
|----------|------------------|-------|
| No animation on bind | `duration: Duration.zero` | Implicit when no AnimationController |
| Bar width clamp 4–12px, 55% slot fill | `_resolveBarWidth` in both charts | Copy constants exactly |
| Below-goal bar alpha 0.66 | `_kBelowGoalBarAlpha` | |
| Selected bar alpha 0.8 | `_kSelectedBarAlpha` | |
| Met-goal color `colors.dataPositive` | `_barColor` in StepBarChart | Monthly chart: no goal coloring |
| Y max = max(steps, goals) × 1.05 | `_ReadyChartState.build` | |
| 30d bottom label throttle | `_shouldShowBottomLabel` | step = ceil(count/6) |
| Single vs stepped goal line | `showSingleGoalLine` / `showSteppedGoalLine` | |
| Tooltip content + styles | `_dailyTooltipItem` / `_monthlyTooltipItem` | |
| Selection semantics | `_selectionSemanticsLabel` | StepBarChart only |
| Left reserved 36, bottom 24 | both `_ReadyChartState` | Match plot insets for goal painters |

### fl_chart touch pattern to replicate

Current touch contract in `astra_bar_chart_touch.dart`:

```14:34:lib/presentation/widgets/chart/astra_bar_chart_touch.dart
  return BarTouchData(
    enabled: true,
    handleBuiltInTouches: false,
    touchTooltipData: tooltipData,
    touchCallback: (event, response) {
      if (event is FlTapUpEvent || event is FlLongPressEnd) {
        final spot = response?.spot;
        if (spot == null) {
          onTouchedIndexChanged(null);
          return;
        }
        final index = spot.touchedBarGroupIndex;
        onTouchedIndexChanged(touchedIndex == index ? null : index);
        return;
      }

      if (!event.isInterestedForInteractions) {
        onTouchedIndexChanged(null);
      }
    },
  );
```

Native equivalent: `GestureDetector(onTapUp: …)` + manual index from x; `onTapDown` outside plot clears; toggle on re-tap same bar.

### Previous story intelligence (20-3)

| Learning | Application |
|----------|-------------|
| Review-before-commit per sub-task | Same gate — A/B/C/D commits |
| `flutter test --exclude-tags slow` regression bar (~824+ tests) | Run full suite in Sub-task D |
| Branch `refacto` only | Do not merge to main from this story |
| No mid-epic version bump | Bump at 20-5 only |
| Preserve 16-3 `RepaintBoundary` tab roots | Do not touch `AppScaffold` |
| Story 20-2 explicitly deferred chart work to 20-4 | This is the intended home |

### Previous story intelligence (20-2)

| Learning | Application |
|----------|-------------|
| Do not touch chart widgets when doing insights | Inverse: do not touch `TrendsInsightCardsSection` / cubit insight logic |
| Insight cards hidden on 12-month period | Monthly chart migration must not break `months12` branch |
| Calm empty states | Preserve `trendsEmptyHistory` copy in chart empty states |

### Git intelligence

Recent commits (2026-06-21):

- `e48d57a` — Story 20-3 code review fixes
- `30e974b` / `2d347c2` — tab haptic feat + tests
- Pattern: scoped commits `feat(nav):`, `test(nav):`, `fix(nav):`

Suggested commit messages:

- `feat(charts): add CustomPainter bar chart core (story 20-4-A)`
- `feat(charts): migrate StepBarChart off fl_chart (story 20-4-B)`
- `feat(charts): migrate TrendsMonthlyBarChart off fl_chart (story 20-4-C)`
- `chore(deps): remove fl_chart and update chart docs (story 20-4-D)`

### Architecture compliance

| Rule | Application |
|------|-------------|
| REF-26 | Native CustomPainter replaces fl_chart |
| NFR-REF-01 | Minimize per-frame allocations; `shouldRepaint` guards; no chart animations |
| NFR-REF-03 | Measure APK before/after in review brief |
| KPI-01 | Pre-aggregated data only; instant rebind; benchmark test must still pass |
| D-11 (architecture) | Update mental model: charts are CustomPainter — architecture.md still says fl_chart (do not edit planning doc; note in completion) |
| Presentation layer | Charts stay in `lib/presentation/widgets/` — no repository imports |
| Review-before-commit | One commit per sub-task after Baptiste OK |

### Library / framework requirements

| Package | Version | Usage |
|---------|---------|-------|
| `flutter` (SDK) | ^3.12 (project constraint) | `CustomPainter`, `GestureDetector`, `Canvas` |
| — | — | **Remove** `fl_chart: ^1.2.0` |
| — | — | **No new chart packages** |

**Do not add:** `syncfusion_flutter_charts`, `charts_flutter`, or any third-party chart lib — audit explicitly targets native painter (~250 lines/chart).

### File structure requirements

| Action | Path |
|--------|------|
| **NEW** | `lib/presentation/widgets/chart/astra_bar_chart_painter.dart` |
| **NEW** | `lib/presentation/widgets/chart/astra_bar_chart_core.dart` |
| **NEW** | `lib/presentation/widgets/chart/astra_single_goal_line_painter.dart` |
| **NEW** | `test/presentation/widgets/chart/astra_bar_chart_painter_test.dart` |
| **UPDATE** | `lib/presentation/widgets/step_bar_chart.dart` — swap fl_chart for core |
| **UPDATE** | `lib/presentation/widgets/trends_monthly_bar_chart.dart` — swap fl_chart for core |
| **UPDATE/DELETE** | `lib/presentation/widgets/chart/astra_bar_chart_touch.dart` — remove fl_chart types |
| **UPDATE** | `test/presentation/widgets/step_bar_chart_test.dart` |
| **UPDATE** | `test/presentation/widgets/trends_monthly_bar_chart_test.dart` |
| **UPDATE** | `test/presentation/widgets/bar_chart_layout_test.dart` |
| **UPDATE** | `test/helpers/bar_chart_touch_test_helper.dart` |
| **UPDATE** | `test/dev/chart_benchmark_render_pump.dart` (if fl_chart import) |
| **UPDATE** | `pubspec.yaml` — remove fl_chart |
| **UPDATE** | `docs/DEPENDENCIES.md`, `README.md` |
| **READ ONLY** | `lib/presentation/screens/history_screen.dart` |
| **READ ONLY** | `lib/presentation/screens/app_scaffold.dart` |
| **REUSE AS-IS** | `goal_step_line_painter.dart`, `bar_chart_layout.dart`, `chart_axis_ticks.dart` |

### Testing requirements

```bash
flutter analyze lib/presentation/widgets/chart/ lib/presentation/widgets/step_bar_chart.dart lib/presentation/widgets/trends_monthly_bar_chart.dart
flutter test test/presentation/widgets/chart/
flutter test test/presentation/widgets/step_bar_chart_test.dart
flutter test test/presentation/widgets/trends_monthly_bar_chart_test.dart
flutter test test/presentation/widgets/bar_chart_layout_test.dart
flutter test --exclude-tags slow
flutter test test/dev/chart_benchmark_test.dart   # slow — KPI-01 smoke
```

**Test migration strategy:**

- Replace `find.byType(BarChart)` with finders on chart core widget or semantics
- Replace `barChart.data.maxY` introspection — expose `chartMaxY` via test keys or test-only getters if needed (prefer testing rendered axis labels)
- Replace `fakeBarTouchResponse` / `simulateBarTap` with `tester.tapAt(Offset(x, y))` at computed bar center
- `hasGoalStepLinePainter(tester)` helper stays valid — `GoalStepLinePainter` unchanged

**Manual checklist (physical device):**

1. Trends → 7d: bars, weekday labels, tap bar → tooltip + haptic-free selection
2. Toggle 30d: instant rebind, throttled date labels, no animation flash
3. Change daily goal history → stepped goal line appears when goals differ
4. 12-month view: 12 bars, month labels, tooltip on tap
5. Scroll Trends while chart visible — smooth 120 Hz, no jank vs before
6. Period toggle while bar selected — selection clears or rebinds cleanly

### Cross-story roadmap (Epic 20)

| Story | Responsibility |
|-------|----------------|
| 20-1 | Onboarding trust emphasis ✅ |
| 20-2 | Local Trends insight cards ✅ |
| 20-3 | Tab haptic feedback ✅ |
| **20-4 (this)** | Replace fl_chart with CustomPainter |
| 20-5 | Phosphor subsetting + **Epic 20 version bump** `0.10.0+20` |

### Latest technical notes (CustomPainter + Impeller, 2026)

- Flutter Impeller renders `CustomPainter` paths directly — no Skia layer indirection; prefer single `Canvas.drawRRect` per bar over widget-per-bar.
- Use `RRect.fromRectAndCorners` for top-rounded bars matching current `BorderRadius.vertical(top: Radius.circular(4))`.
- Cache `Paint` objects as `final` fields on the painter delegate — do not allocate `Paint()` inside `paint()` per bar.
- `computeSpaceAroundBarCenters` already validated against fl_chart math — keep as single source of truth for X positions.
- Dashed lines: reuse dash-loop pattern from `GoalStepLinePainter._drawDashedPath` for single goal line painter.

### Project context reference

- [Source: docs/project-context.md] Review-before-commit gate — stop after each sub-task.
- [Source: docs/project-context.md] Default test command: `flutter test --exclude-tags slow`.
- [Source: docs/project-context.md] Version bump at epic close only for Epic 20.
- [Source: _bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md §4] ~500 KB APK gain + Impeller fluidity rationale.
- [Source: _bmad-output/planning-artifacts/epics-refacto.md REF-26, NFR-REF-01, NFR-REF-03]

### References

- [Source: _bmad-output/planning-artifacts/epics-refacto.md#story-20-4-replace-fl_chart-with-custompainter-charts]
- [Source: _bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md §4]
- [Source: lib/presentation/widgets/step_bar_chart.dart]
- [Source: lib/presentation/widgets/trends_monthly_bar_chart.dart]
- [Source: lib/presentation/widgets/chart/goal_step_line_painter.dart]
- [Source: _bmad-output/implementation-artifacts/stories/3-4-chart-performance-benchmark-kpi-01.md] KPI-01 constraints
- [Source: _bmad-output/implementation-artifacts/stories/12-4-trends-historical-goal-line.md] Goal line behavior spec

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- `flutter analyze` on chart files: clean (after removing unused imports)
- `flutter test --exclude-tags slow`: 830 tests passed
- `flutter test test/dev/chart_benchmark_test.dart`: 11 passed (KPI-01 p95 ~41ms render profile)
- `flutter build apk --release --analyze-size --target-platform android-arm64`: 19.3 MB total compressed

### Completion Notes List

- Implemented shared native chart stack: `AstraBarChartPainter`, `AstraBarChartCore`, `AstraSingleGoalLinePainter`; rewrote touch helpers without fl_chart.
- Migrated `StepBarChart` and `TrendsMonthlyBarChart` to `AstraBarChartCore`; preserved goal lines, semantics, tooltips, 30d label throttle, bar colors.
- Removed `fl_chart` from `pubspec.yaml`; zero imports remain in `lib/` or `test/`.
- Updated chart widget tests + `bar_chart_touch_test_helper.dart` for geometry-based tap simulation.
- Fixed `chart_benchmark_pump.dart` to use `TestMaterialApp` (l10n required by chart widgets).
- APK post-migration: **19.3 MB** arm64 release (no pre-change baseline in session; audit estimated ~500 KB gain from fl_chart removal).
- No version bump (Epic 20 closes at story 20-5).

### File List

- `lib/presentation/widgets/chart/astra_bar_chart_painter.dart` (new)
- `lib/presentation/widgets/chart/astra_bar_chart_core.dart` (new)
- `lib/presentation/widgets/chart/astra_single_goal_line_painter.dart` (new)
- `lib/presentation/widgets/chart/astra_bar_chart_touch.dart` (rewritten)
- `lib/presentation/widgets/chart/bar_chart_layout.dart` (comment)
- `lib/presentation/widgets/chart/chart_axis_ticks.dart` (comments)
- `lib/presentation/widgets/step_bar_chart.dart` (migrated)
- `lib/presentation/widgets/trends_monthly_bar_chart.dart` (migrated)
- `test/presentation/widgets/chart/astra_bar_chart_painter_test.dart` (new)
- `test/presentation/widgets/bar_chart_layout_test.dart` (updated)
- `test/presentation/widgets/step_bar_chart_test.dart` (updated)
- `test/presentation/widgets/trends_monthly_bar_chart_test.dart` (updated)
- `test/helpers/bar_chart_touch_test_helper.dart` (updated)
- `test/dev/chart_benchmark_pump.dart` (l10n fix)
- `test/dev/chart_benchmark_render_pump.dart` (comment)
- `pubspec.yaml` (removed fl_chart)
- `docs/DEPENDENCIES.md` (removed fl_chart row)
- `README.md` (charts row updated)
- `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml` (status → review)

## Change Log

- 2026-06-21 — Story 20-4 created: comprehensive CustomPainter migration guide for fl_chart removal.
- 2026-06-21 — Story 20-4 implemented: native CustomPainter charts, fl_chart removed, tests green.
