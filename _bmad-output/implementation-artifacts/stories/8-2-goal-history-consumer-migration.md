# Story 8.2: Goal History Consumer Migration

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want every goal comparison in the app to use the goal that applied on that day,
So that week dots, charts, and notifications stay truthful after I change my goal.

## Acceptance Criteria

1. **Given** goal was 8000 Mon–Wed and user changes to 10000 on Thu
   **When** `TodayCubit._loadWeekDays` runs
   **Then** Mon–Wed `goalMet` uses 8000; Thu+ uses 10000 (Thu change is immediate on current day)

2. **Given** `HistoryCubit` renders bar chart
   **When** goal reference line is drawn
   **Then** each bar day uses `getGoalForLocalDay(thatDay)` — not a single global goal
   **And** bar highlight color (`dataPositive` vs accent) compares steps to that day's resolved goal

3. **Given** `BackgroundCollector.maybeNotifyGoalReachedIfGoalMet`
   **When** evaluating today's steps
   **Then** uses `getGoalForLocalDay(today)` only (not `getDailyStepGoal()`)

4. **Given** in-app goal celebration on Today
   **When** steps cross threshold
   **Then** threshold is today's resolved goal from `getGoalForLocalDay(todayIso)` (ring status + `_maybeTriggerCelebration`)

5. **Given** existing step-ingestion and FGS tests
   **When** this story ships
   **Then** `background_collector_test`, `today_cubit_test`, `history_cubit_test`, `step_bar_chart_test` pass with **no changes** to ingest write path

## Tasks / Subtasks

- [x] **Sub-task A — TodayCubit historical goal resolution** (AC: #1, #4)
  - [x] Add `localDayIsoFromDateOnly(DateTime localDay)` helper in `lib/core/time/local_day_formatter.dart` (same `YYYY-MM-DD` format as `formatLocalDayIso`; date-only UTC keys from `CalendarWeek` / `ChartDayAggregate`).
  - [x] Refactor `_loadWeekDays`: remove single `goal` parameter; for each week day call `getGoalForLocalDay(localDayIsoFromDateOnly(day))` (batch with `Future.wait`).
  - [x] Replace all **today ring / celebration** reads of `getDailyStepGoal()` with `getGoalForLocalDay(formatLocalDayIso(clock.snapshot()))` in: `_refreshImpl`, `refreshMetadata`, `syncSteps`, `_applyLiveSteps`.
  - [x] Add `today_cubit_test` case: seed journal rows Mon=8000, Thu=10000 with steps on Mon/Wed/Thu; assert `goalMet` respects per-day goals after mid-week change.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — History chart per-day goals** (AC: #2)
  - [x] Extend `HistoryState` with `Map<String, int> goalsByDay` (key = `YYYY-MM-DD`, value = resolved goal). Keep `dailyGoal` as **today's resolved goal** for empty-state fallback and `refreshGoal` compatibility — or derive today from map; do not break `HistoryState.empty` / `ready` factories without updating call sites.
  - [x] In `HistoryCubit._refreshImpl`: after loading aggregates, resolve goals in parallel (`Future.wait` per distinct `localDayIsoFromDateOnly(aggregate.localDay)`).
  - [x] Update `refreshGoal` to re-resolve goals for `_cachedAggregates30d` (not only today's scalar).
  - [x] Update `StepBarChart` / `_ReadyChart`:
    - Per-bar `_barColor` uses that point's resolved goal.
    - `yMax` / `safeYMax` uses `max(maxSteps, max(resolvedGoals))`.
    - Horizontal dashed goal line: when **all visible goals are equal**, keep single `HorizontalLine` (current UX). When goals differ, **omit** the global line (per-bar coloring carries semantics); Epic 12.4 adds stepped dashed line polish.
  - [x] Update `history_screen.dart`, `chart_benchmark.dart`, `chart_benchmark_render_pump.dart`, and widget tests.
  - [x] Add `history_cubit_test` + `step_bar_chart_test` coverage for mixed goals across chart window.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — BackgroundCollector notification** (AC: #3)
  - [x] In `maybeNotifyGoalReachedIfGoalMet`, replace `getDailyStepGoal()` with `getGoalForLocalDay(todayIso)` (`todayIso` already computed on line 167).
  - [x] Add/adjust `background_collector_test` asserting notification uses journal-resolved goal (e.g. set journal row ≠ prefs cache edge — optional if sync invariant holds).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Verification** (AC: #5)
  - [x] `flutter analyze`
  - [x] `flutter test test/presentation/cubits/today_cubit_test.dart test/presentation/cubits/history_cubit_test.dart test/core/services/background_collector_test.dart test/presentation/widgets/step_bar_chart_test.dart`
  - [x] Full `flutter test` — ingest / FGS / live monitor suites must stay green
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope (8.2):**
- Consumer migration: `TodayCubit`, `HistoryCubit`, `HistoryState`, `StepBarChart`, `BackgroundCollector`
- Shared `localDayIsoFromDateOnly` helper
- Unit/widget tests for per-day goal semantics

**Out of scope — do not touch:**
- `UserPreferencesRepository` API / DB schema (done in 8.1)
- Ingestion pipeline (`BackgroundCollector.collectOnce` write path, `StepNormalizer`, FGS, WorkManager)
- `MyDataCubit` / onboarding goal editors (correctly use `setDailyStepGoal` + cache display via `getDailyStepGoal`)
- CSV import/export of goal history
- Epic 11 day-picker / selected-day ring (uses 8.2 APIs later)
- Epic 12.4 stepped goal dashed line (8.2 enables per-bar threshold; full stepped line deferred)
- Version bump (`0.2.1+3` at **Epic 8 close** after this story is `done` — not mid-story)

### Business context

Epic 8 fixes the **goal retroactivity bug**: a single global `daily_step_goal` pref caused past days to re-evaluate when the user changed their goal (`WeekDayStatus.goalMet`, History bar coloring, celebration, background notification). Story 8.1 added the journal; **this story wires every comparison site to `getGoalForLocalDay`**.

**Pre-migration edge (accepted):** Days before the v3 seed row resolve to `kDefaultStepGoal` (8000). Do not add backfill logic here.

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 8.2 changes | Must preserve |
|------|---------------|------------------|---------------|
| `lib/presentation/cubits/today_cubit.dart` | `_loadWeekDays(goal:)` applies **one** goal to all 7 days; ring/celebration use `getDailyStepGoal()` | Per-day `getGoalForLocalDay`; today's ring uses `getGoalForLocalDay(todayIso)` | Live overlay guards, foreground catch-up, stale clamp, `postGoalUpdate` hook, week strip structure |
| `lib/presentation/cubits/history_cubit.dart` | Single `getDailyStepGoal()` → `HistoryState.dailyGoal` | Resolve `goalsByDay` per aggregate | Cached aggregates, trend math, period slicing, silent refresh |
| `lib/presentation/cubits/history_state.dart` | `dailyGoal: int` | Add `goalsByDay` map; keep today scalar for empty/fallback | `HistoryStatus` enum, trend snapshot |
| `lib/presentation/widgets/step_bar_chart.dart` | Single `dailyGoal` for line + bar color + yMax | Per-point goal from `goalsByDay` | fl_chart layout, 7d/30d label throttling, semantics |
| `lib/presentation/screens/history_screen.dart` | Passes `state.dailyGoal` | Pass `goalsByDay` (+ today fallback) | Screen layout |
| `lib/core/services/background_collector.dart` | `maybeNotifyGoalReachedIfGoalMet` uses `getDailyStepGoal()` | `getGoalForLocalDay(todayIso)` | Notification dedup, permission gates, `collectOnce` ingest path untouched |
| `lib/core/time/local_day_formatter.dart` | `formatLocalDayIso(TimeSnapshot)` only | Add `localDayIsoFromDateOnly(DateTime)` | Existing snapshot formatter |
| `lib/presentation/screens/app_scaffold.dart` | `postGoalUpdate` → `historyCubit.refreshGoal()` | No change expected (refreshGoal behavior updates internally) | Tab wiring |

### Canonical per-day resolution

```dart
// New helper — date-only UTC keys from CalendarWeek / ChartDayAggregate
String localDayIsoFromDateOnly(DateTime localDay) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${localDay.year}-${two(localDay.month)}-${two(localDay.day)}';
}

// Today ring / celebration / notification
final todayIso = formatLocalDayIso(clock.snapshot());
final todayGoal = await userPreferences.getGoalForLocalDay(todayIso);

// Week strip (per day)
final goalForDay = await userPreferences.getGoalForLocalDay(
  localDayIsoFromDateOnly(day),
);
```

**Do not** use `getDailyStepGoal()` for **comparison** semantics after this story. It remains valid for **displaying the current editable goal** in My Data / onboarding.

### TodayCubit `_loadWeekDays` migration pattern

Current bug (single goal for all days):

```537:562:lib/presentation/cubits/today_cubit.dart
  Future<List<WeekDayStatus>> _loadWeekDays({required int goal}) async {
    // ...
          goalMet: goal > 0 && (stepsByDay[day] ?? 0) >= goal,
```

Target: resolve goal per `day` before building `WeekDayStatus`. Future days: `goalMet` stays `false` (existing `isFuture` guard in UI). Past/today: compare steps to **that day's** resolved goal.

Call sites passing `goal:` into `_loadWeekDays` (lines 343, 379, 422, 464) should be simplified — week strip no longer shares today's scalar.

### History chart migration pattern

Current bug (single goal for all bars):

```236:257:lib/presentation/widgets/step_bar_chart.dart
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: dailyGoal.toDouble(),
                      // ...
                    ),
                  ],
                ),
                // ...
                          dailyGoal: dailyGoal,
```

Target state shape example:

```dart
HistoryState.ready(
  chartPoints: points,
  dailyGoal: todayGoal,           // fallback / empty
  goalsByDay: {
    '2026-06-09': 8000,
    '2026-06-10': 8000,
    '2026-06-11': 10000,
  },
  trend: trend,
);
```

`StepBarChart` resolves `goalsByDay[localDayIsoFromDateOnly(point.localDay)] ?? kDefaultStepGoal` per index.

### BackgroundCollector change (minimal)

```167:171:lib/core/services/background_collector.dart
    final todayIso = formatLocalDayIso(time.snapshot());

    final goal = await prefs.getDailyStepGoal();
```

Replace with `getGoalForLocalDay(todayIso)`. One-line semantic fix; `todayIso` already present.

### Architecture compliance

- **D-03:** Reads only — `UserPreferencesRepository.getGoalForLocalDay`; no new writers.
- **NFR-9:** Local day ISO strings for goal journal; week/chart days use same `YYYY-MM-DD` keys as timeseries aggregation date-only UTC keys.
- **D-21:** `ChartDayAggregate` unchanged; goals resolved at cubit layer.
- **Review gate:** One commit per sub-task after Baptiste OK — `docs/project-context.md` § Development Workflow.

### File structure requirements

| Action | Path |
|--------|------|
| MODIFY | `lib/core/time/local_day_formatter.dart` |
| MODIFY | `lib/presentation/cubits/today_cubit.dart` |
| MODIFY | `lib/presentation/cubits/history_cubit.dart` |
| MODIFY | `lib/presentation/cubits/history_state.dart` |
| MODIFY | `lib/presentation/widgets/step_bar_chart.dart` |
| MODIFY | `lib/presentation/screens/history_screen.dart` |
| MODIFY | `lib/core/services/background_collector.dart` |
| MODIFY | `test/presentation/cubits/today_cubit_test.dart` |
| MODIFY | `test/presentation/cubits/history_cubit_test.dart` |
| MODIFY | `test/core/services/background_collector_test.dart` |
| MODIFY | `test/presentation/widgets/step_bar_chart_test.dart` |
| MODIFY (if compile breaks) | `lib/dev/chart_benchmark.dart`, `lib/dev/chart_benchmark_render_pump.dart`, `test/dev/chart_benchmark_test.dart` |

Do **not** add packages. No repository or migration edits.

### Testing requirements

**TodayCubit — historical week strip (AC #1):**
1. Fake clock on Thu 2026-06-12.
2. Direct DB insert or sequential `setDailyStepGoal` with clock jumps to build journal: Mon row 8000, Thu row 10000.
3. Upsert step buckets Mon=8500, Wed=8500, Thu=5000.
4. `refresh()` → Mon/Wed `goalMet==true`, Thu `goalMet==false`.

**HistoryCubit — per-day goals (AC #2):**
1. Load chart aggregates spanning goal change.
2. Assert `state.goalsByDay` maps distinct days to correct goals.
3. `refreshGoal()` after `setDailyStepGoal` updates map without re-querying steps.

**BackgroundCollector (AC #3):**
1. Existing notification tests should pass after API swap (journal synced on `setDailyStepGoal`).
2. Optional: assert `getGoalForLocalDay` path by inserting journal row directly.

**Regression:**
- `flutter test` full suite before final sub-task.
- Grep lib/ for `getDailyStepGoal` — remaining call sites must be **display/edit** only (`my_data_cubit`, onboarding), not comparison.

### Previous story intelligence (8.1)

- DB v3 + `daily_goal_effective` shipped; `getGoalForLocalDay` + journal upsert in `setDailyStepGoal` complete.
- `getDailyStepGoal()` intentionally left for consumers until **this** story.
- Migration seed uses `formatLocalDayIso`; journal/cache stay in sync on write.
- Review deferred: `getGoalForLocalDay` input validation — internal callers must pass valid `YYYY-MM-DD` via new helper.
- Tests: 643 pass / 2 skip at 8.1 close; follow same `FakeTimeProvider` + `openAstraDatabase` patterns.
- Commits: `b098aab`, `0f17454`, `663de12`, `11a6ec0`.

### Git intelligence

Recent Epic 8 commits touched only migrations, repository, DI, tests — **zero consumer changes**. This story is the first touch of `today_cubit`, `history_cubit`, `background_collector` for goal semantics. Match existing cubit test style in `today_cubit_test.dart` (`week strip` group ~line 690).

### Latest tech information

- **sqflite ^2.4.2+1** — no schema change.
- **fl_chart** (existing) — multiple `HorizontalLine` entries possible but stepped per-x-range is awkward; omit global line when goals differ (documented).
- **flutter_bloc** — cubit refresh coalescing (`_refreshInFlight`) must remain intact when adding parallel goal fetches.

### Project context reference

- Versioning: patch `0.2.1+3` when Epic 8 closes (both 8.1 + 8.2 done)
- Commit convention: `feat(today): …`, `feat(history): …`, `fix(collector): …`
- `docs/project-context.md` — review-before-commit workflow mandatory

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` § Epic 8 Story 8.2]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` § 4.1, 4.4]
- [Source: `_bmad-output/implementation-artifacts/stories/8-1-daily-goal-history-schema-and-repository.md`]
- [Source: `lib/presentation/cubits/today_cubit.dart` — `_loadWeekDays`, celebration]
- [Source: `lib/presentation/cubits/history_cubit.dart` — single `dailyGoal`]
- [Source: `lib/presentation/widgets/step_bar_chart.dart` — bar color + goal line]
- [Source: `lib/core/services/background_collector.dart` — `maybeNotifyGoalReachedIfGoalMet`]
- [Source: `lib/data/repositories/user_preferences_repository.dart` — `getGoalForLocalDay`]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- Sub-task A (2026-06-15): `TodayCubit` week strip and ring/celebration now use `getGoalForLocalDay` per local day; added `localDayIsoFromDateOnly` helper; 46/46 `today_cubit_test` pass.
- Sub-task B (2026-06-15): `HistoryState.goalsByDay` + per-bar chart semantics; goal line omitted when goals differ; 36/36 history/chart/benchmark tests pass.
- Sub-task C (2026-06-15): `BackgroundCollector` notification uses `getGoalForLocalDay(todayIso)`; journal vs stale cache test; 21/21 `background_collector_test` pass.
- Sub-task D (2026-06-15): Full suite 651 pass / 2 skip; integration tests aligned `UserPreferencesRepository` clock with cubits; live pipeline tests drain resume async before teardown.

### File List

- `lib/core/time/local_day_formatter.dart`
- `lib/presentation/cubits/today_cubit.dart`
- `test/presentation/cubits/today_cubit_test.dart`
- `lib/presentation/cubits/history_state.dart`
- `lib/presentation/cubits/history_cubit.dart`
- `lib/presentation/widgets/step_bar_chart.dart`
- `lib/presentation/screens/history_screen.dart`
- `lib/dev/chart_benchmark.dart`
- `lib/dev/chart_benchmark_render_pump.dart`
- `test/dev/chart_benchmark_pump.dart`
- `test/dev/chart_benchmark_test.dart`
- `test/presentation/cubits/history_cubit_test.dart`
- `test/presentation/widgets/step_bar_chart_test.dart`
- `lib/core/services/background_collector.dart`
- `test/core/services/background_collector_test.dart`
- `test/app_live_pipeline_lifecycle_test.dart`
- `test/core/services/workmanager_callback_test.dart`
- `test/presentation/screens/app_scaffold_test.dart`
- `test/widget_test.dart`

## Change Log

- 2026-06-15: Sub-task A — TodayCubit per-day goal resolution for week strip and ring (committed).
- 2026-06-15: Sub-task B — History chart per-day goals and refreshGoal map update (committed).
- 2026-06-15: Sub-task C — BackgroundCollector goal notification via journal lookup (committed).
- 2026-06-15: Sub-task D — Test regression fixes for per-day goal clock alignment; full suite green (committed).
