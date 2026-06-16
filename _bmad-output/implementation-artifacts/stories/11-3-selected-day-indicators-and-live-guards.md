# Story 11.3: Selected Day Indicators and Live Guards

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want the ring, stats, and goal to reflect the selected day,
So that the dashboard is truthful for any day I pick.

## Acceptance Criteria

1. **Given** a past local day is selected in the week strip  
   **When** Steps refreshes or the user taps that day  
   **Then** the goal ring shows that day's step total from SQLite (not live overlay)  
   **And** the ring goal line uses `getGoalForLocalDay(thatDay)` (Epic 8 historical resolution)  
   **And** `ActivityStatsRow` shows metrics computed from that day's steps + 5min active buckets + profile  
   **And** **Set goal** still opens the editor with **today's** current goal and persists via `setDailyStepGoal` (applies from today per Epic 8 — ring on a past day does not change what Set goal edits)

2. **Given** `selectedLocalDay` is today (default on cold start / resume)  
   **When** the live step pipeline emits  
   **Then** ring and stats update live per Story 2.9 / 6.1 (distance from `displaySteps`; kcal/duration from buckets on full refresh)  
   **And** goal celebration and foreground catch-up remain **enabled**

3. **Given** `selectedLocalDay` is not today (past day in current week)  
   **When** the live step pipeline emits, `syncSteps`, or `refreshMetadata` runs  
   **Then** displayed `steps`, `goal`, `activityMetrics`, and derived `TodayStatus` **do not** change from live overlay or today's refresh paths  
   **And** no celebration is triggered or shown  
   **And** `foregroundCatchUp` is not started while viewing a past day

4. **Given** user selects a past day then taps today again  
   **When** selection returns to today  
   **Then** ring/stats immediately reflect today's truth (SQLite + live overlay if monitor running)  
   **And** live updates resume without requiring app restart

5. **Given** unit/widget tests  
   **When** tests run  
   **Then** cover:
   - past-day selection loads correct steps, goal, and status from seeded SQLite
   - live stream ignored while past day selected; reapplied when today re-selected
   - celebration suppressed when past day selected even if live crosses today's goal
   - Set goal editor receives today's goal when viewing a past day (not that day's historical goal)
   - existing today truth-model tests (`today_cubit_test`, `app_live_pipeline_lifecycle_test`) remain green

**Depends on:** Stories 8.2, 11.2.  
**Mockup ref:** `Today-light` (THU highlighted — ring/stats follow selected pill).  
**Enables:** Story 11.4 (trophy X/7 uses week data; ring/stats truth model must be stable first).

## Tasks / Subtasks

- [x] **Sub-task A — Repository: per-day buckets** (AC: #1)
  - [x] Add `StepRepository.getActiveBucketsForLocalDay(DateTime localDay)` mirroring `getTodayActiveBuckets()`:
    - same SQL filters (`type = steps`, `resolution = 5min`, `value > 0`)
    - per-row `LocalDayCalculator` filter against **parameter** day (not clock today)
    - reuse or extract shared UTC bounds helper from `_todaySampleUtcBounds` (reference day ±1)
  - [x] Add repository test: seed buckets on Mon + Tue; assert Mon query excludes Tue rows
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — TodayCubit: display vs today truth split** (AC: #1–#4)
  - [x] Introduce private cubit fields for **today truth** (e.g. `_todaySteps`, `_todayGoal`, `_todayMetrics`) separate from emitted display fields when `selectedLocalDay != today`
  - [x] Add `_isViewingToday()` helper (compare `state.selectedLocalDay` to week strip `isToday` day, date-only)
  - [x] Add `_loadSnapshotForLocalDay(DateTime day)`:
    - steps: finest-resolution total for that day (from `getChartDailyAggregates(days: 7)` map or dedicated repo read)
    - goal: `getGoalForLocalDay(localDayIsoFromDateOnly(day))`
    - buckets: `getActiveBucketsForLocalDay(day)`
    - metrics: `DerivedActivityMetrics.compute(...)` full compute (not live distance-only shortcut)
  - [x] Update `selectLocalDay`: after setting selection, `unawaited(_applySelectedDayDisplay())` to load and emit historical snapshot when not today; when selecting today, re-emit today truth fields
  - [x] Guard **all live/today-only paths** with `_isViewingToday()`:
    - `_applyLiveSteps` — early return when not viewing today
    - `syncSteps` / `foregroundCatchUp` — no catch-up emit when not viewing today
    - `_maybeTriggerCelebration` — skip when not viewing today
    - `attachLiveMonitor` listener + `setLiveStepAppliesPaused` resume path
  - [x] `_refreshImpl` / `refreshMetadata`: always refresh today truth internally; emit to UI only when `_isViewingToday()`, else refresh week strip + keep selected-day display unchanged (except week pill `goalMet` dots)
  - [x] Preserve Story 2.9 monotonic same-day merge for today truth when viewing today
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — TodayScreen / GoalRing wiring** (AC: #1, #2)
  - [x] `GoalRing.localDayIso`: pass **selected** day's ISO (`localDayIsoFromDateOnly(state.selectedLocalDay!)`) not always clock today
  - [x] `_onSetGoalTapped`: open editor with **today's editable goal** — add `TodayCubit.todayEditableGoal` getter (async or cached today goal) **not** `state.goal` when viewing past day
  - [x] After successful `updateDailyStepGoal`, if viewing past day: refresh week strip + keep past-day ring; if viewing today: existing refresh behavior
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Tests** (AC: #5)
  - [x] Extend `test/presentation/cubits/today_cubit_test.dart`:
    - past-day select shows seeded steps + historical goal
    - live tick ignored while Mon selected; today re-select applies live steps
    - celebration blocked on past-day view
  - [x] Add `test/data/repositories/step_repository_test.dart` case for `getActiveBucketsForLocalDay` (or extend existing file)
  - [x] Update `test/presentation/screens/screen_smoke_test.dart` if Set goal wiring changes
  - [x] Run `flutter analyze` + targeted tests + `app_live_pipeline_lifecycle_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Change Log

- 2026-06-16: Story 11.3 — per-day bucket query, selected-day display truth split, live guards, Set goal today contract, tests.

## Dev Notes

### Story scope boundary

| Area | In scope (11.3) | Out of scope |
|------|-----------------|--------------|
| Ring + stats data | Follow `selectedLocalDay` | Trophy **X/7** badge (11.4) |
| Live overlay | Suppressed when not today | New day picker UI (11.2 done) |
| Set goal | Always edits **today** goal | Goal editor UX redesign |
| Week strip dots | Still from `_loadWeekDays` (today's goal resolution per 8.2) | Per-day historical dot re-score beyond existing `goalMet` (11.4) |
| Stale banner | Unchanged (today ingestion metadata) | Stale semantics per selected day |
| Version bump | None | Epic 11 close → `0.4.0+6` |

### Current code state (READ BEFORE EDITING)

**After Story 11.2**, selection exists but ring/stats always show **today**:

| File | Current behavior | 11.3 change |
|------|------------------|-------------|
| `today_cubit.dart` | `steps`/`goal`/`activityMetrics` always today; `selectLocalDay` only updates `selectedLocalDay` | Display follows selection; live paths guarded |
| `today_state.dart` | `steps`, `goal`, `activityMetrics`, `status` are display fields | May add `todayEditableGoal` on cubit only (avoid state bloat unless needed) |
| `today_screen.dart` | `GoalRing` gets clock-today `localDayIso`; Set goal uses `state.goal` | Selected day ISO; Set goal uses today goal |
| `step_repository.dart` | `getTodayActiveBuckets()` only | Add parameterized local-day buckets |
| `goal_ring.dart` | `localDayIso` change resets prefs load (line ~198) | Correct — pass selected day |

**`selectLocalDay` post-hardening (11.2):** rejects `isFuture` days and days outside current week — future empty-state AC is defensive only unless selection rules change.

### Architecture compliance

| Rule | Application |
|------|-------------|
| Today Display Truth Model (Story 2.9) | SQLite truth for historical days; live overlay **only** when viewing today |
| Derived metrics (Story 6.1) | Past days: full bucket compute; today live tick: distance-only overlay unchanged |
| Goal history (Story 8.2) | Ring goal = `getGoalForLocalDay(selectedDay)`; Set goal = today's journal row |
| Monotonic same-day | Applies to **today truth** while viewing today — do not apply live monotonic merge to past-day display |
| No reactive streams | Keep cubit + imperative refresh; no new `StreamController` in UI |
| Review-before-commit | One commit per sub-task A–D per `docs/project-context.md` |

### Recommended cubit design (avoid common LLM mistakes)

**Do not** add parallel `displaySteps` fields on `TodayState` unless necessary — prefer emitting correct `steps`/`goal`/`activityMetrics` for the selected day while caching today truth in private cubit fields.

```dart
// Pseudocode — adapt to existing method names
bool _isViewingToday() {
  final selected = state.selectedLocalDay;
  if (selected == null) return true;
  final today = state.weekDays.cast<WeekDayStatus?>().firstWhere(
    (d) => d!.isToday,
    orElse: () => null,
  );
  return today != null && _isSameLocalDay(today.localDay, selected);
}

Future<void> _applySelectedDayDisplay() async {
  if (_isViewingToday()) {
    await _emitTodayDisplay(); // from cached _today* fields + live rules
    return;
  }
  final day = state.selectedLocalDay!;
  final snapshot = await _loadSnapshotForLocalDay(day);
  emit(state.copyWith(
    steps: snapshot.steps,
    goal: snapshot.goal,
    activityMetrics: snapshot.metrics,
    status: TodayState.fromData(
      steps: snapshot.steps,
      goal: snapshot.goal,
      isStale: state.isStale,
    ).status,
    showCelebration: false,
    foregroundCatchUp: false,
    catchUpTargetSteps: null,
  ));
}
```

**Live guard checklist** — every path that mutates `steps`/`goal`/`activityMetrics`/`showCelebration`/`foregroundCatchUp`:

| Method | Guard |
|--------|-------|
| `_applyLiveSteps` | Return early if `!_isViewingToday()` |
| `syncSteps(foregroundCatchUp: true)` | Skip catch-up emit if `!_isViewingToday()` |
| `_maybeTriggerCelebration` | Return immediately if `!_isViewingToday()` |
| `attachLiveMonitor` listener | Same as `_applyLiveSteps` |
| `setLiveStepAppliesPaused(false)` resume | Only `_applyLiveSteps` when viewing today |
| `_refreshImpl` | Update today cache always; `emit` display from cache only if viewing today, else update `weekDays` + selected-day snapshot if needed |

### Reuse — do NOT reinvent

| Need | Use existing |
|------|--------------|
| Per-day goal | `userPreferences.getGoalForLocalDay(localDayIsoFromDateOnly(day))` |
| Per-day steps (week window) | `stepRepository.getChartDailyAggregates(days: 7)` — already called in `_loadWeekDays`; consider reusing map |
| Active buckets pattern | Copy `getTodayActiveBuckets` query shape |
| Metrics engine | `DerivedActivityMetrics.compute` |
| Day ISO keys | `localDayIsoFromDateOnly` / `formatLocalDayIso` |
| Week strip | `WeekProgressRow` + `selectLocalDay` — no new picker |
| Set goal persist | `TodayCubit.updateDailyStepGoal` + `showGoalEditorSheet` |

### Set goal vs ring goal (critical UX contract)

When user views **Monday** with goal 8000 that day but today's goal is 10000:

- Ring shows Monday steps vs **8000** (historical)
- **Set goal** opens editor pre-filled with **10000** (today editable goal)
- Saving updates journal from **today** forward (Epic 8 `setDailyStepGoal`)

Implement via cubit getter that resolves today's goal independently of display `state.goal`.

### GoalRing behavior on past days

- Pass selected day `localDayIso` so `getLastDisplayedSteps` / `setLastDisplayedSteps` are per-day
- Expect static display (no live micro-ticks) — `GoalRing` should show final SQLite total
- `showCelebration` must be false on past-day view
- `foregroundCatchUp` must be false on past-day view; clearing catch-up when switching to past day avoids stuck animation

### Testing requirements

| Test file | New coverage |
|-----------|--------------|
| `today_cubit_test.dart` | Selected-day snapshot; live guard; celebration guard; re-select today |
| `step_repository_test.dart` | `getActiveBucketsForLocalDay` cross-day isolation |
| `screen_smoke_test.dart` | Optional: tap past pill → ring count changes (if seed data in smoke harness) |
| `app_live_pipeline_lifecycle_test.dart` | **Must stay green** — regression guard for Story 2.9 |

**Suggested cubit test pattern:**

```dart
// Seed Monday 6000 steps, today 1000; select Monday
await cubit.refresh();
cubit.selectLocalDay(monday);
await pumpEventQueue(); // if display load is async
expect(cubit.state.steps, 6000);

await cubit.syncSteps(5000); // live for today
expect(cubit.state.steps, 6000); // still Monday display

cubit.selectLocalDay(today);
expect(cubit.state.steps, 5000); // today truth restored
```

### File structure requirements

| File | Action |
|------|--------|
| `lib/data/repositories/step_repository.dart` | **UPDATE** — `getActiveBucketsForLocalDay` |
| `lib/presentation/cubits/today_cubit.dart` | **UPDATE** — display split + live guards |
| `lib/presentation/screens/today_screen.dart` | **UPDATE** — `localDayIso`, Set goal goal source |
| `test/data/repositories/step_repository_test.dart` | **UPDATE** or create |
| `test/presentation/cubits/today_cubit_test.dart` | **UPDATE** |

**Do not create** new screens or widgets for 11.3.

### Library / framework requirements

- Flutter SDK per `pubspec.yaml` — **no new dependencies**
- `flutter_bloc` immutable state + `copyWith` pattern unchanged
- `DerivedActivityMetrics` pure Dart — no Flutter imports in metrics layer

### Previous story intelligence (11.2)

- `selectedLocalDay` on `TodayState`; normalized date-only in cubit
- `_resolveSelectedLocalDay` on refresh preserves in-session selection
- `_hasUserSelectedLocalDay` flag — preserve when implementing display reload
- `WeekProgressRow` already receives `selectedLocalDay` + `onDayTap`
- Future-day selection **blocked** in `selectLocalDay` after hardening commit `3ca1018`
- Tests in `today_cubit_test.dart` group `'week strip'` — extend, do not break

### Previous story intelligence (11.1)

- Layout order locked: week card → ring → stats
- Screen title **Steps**; internal class names remain `TodayScreen` / `TodayCubit`

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `3ca1018` | Day picker guards hardened — future day ignored |
| `fa2e73f` | Week pills wired as tappable picker |
| `2536bb6` | `selectedLocalDay` state added to TodayCubit |
| `bc96ee2` | Week-first layout (11.1) |

Follow pattern: narrow cubit + repository + screen wiring + tests per sub-task.

### Latest technical notes (2026)

- **Flutter Bloc:** guard async `selectLocalDay` display load with `isClosed` checks after each `await`
- **SQLite:** per-day bucket query is O(samples in ±1 day window) — same cost class as `getTodayActiveBuckets`
- **No kcal live scaling** on today view (Story 6.1) — do not add for past days either; full bucket compute only

### Project context reference

- Review-before-commit: `docs/project-context.md` § Development Workflow
- Versioning: Epic 11 close → `0.4.0+6` — not per story
- Sprint sequencing: `sprint-change-proposal-2026-06-15.md` — Epic 11 after Epic 8 + 10

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` § Epic 11, Story 11.3]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` § Epic 11 / `today_cubit.dart` selected day]
- [Source: `_bmad-output/planning-artifacts/architecture.md` § Today Display Truth Model]
- [Source: `_bmad-output/implementation-artifacts/stories/8-2-goal-history-consumer-migration.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/2-9-today-display-truth-model-and-live-overlay.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/6-1-derived-activity-metrics.md` § Live display contract]
- [Source: `_bmad-output/implementation-artifacts/stories/11-2-day-picker-and-selected-day-state.md`]
- [Source: `lib/presentation/cubits/today_cubit.dart`]
- [Source: `lib/data/repositories/step_repository.dart`]
- [Source: `lib/presentation/screens/today_screen.dart`]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

- (Temporary) instrumentation during development was removed.

### Completion Notes List

- `flutter analyze` (touched files): `lib/data/repositories/step_repository.dart`, `lib/presentation/cubits/today_cubit.dart`, `lib/presentation/screens/today_screen.dart`
- `flutter test`:
  - `test/data/repositories/step_repository_active_buckets_test.dart`
  - `test/presentation/cubits/today_cubit_test.dart`
  - `test/app_live_pipeline_lifecycle_test.dart` (execution result: all tests reported as passed; some cases can be marked flaky/skip in this repo)
  - `test/presentation/screens/screen_smoke_test.dart` (no code changes required)

### File List

lib/data/repositories/step_repository.dart
lib/presentation/cubits/today_cubit.dart
lib/presentation/screens/today_screen.dart
test/data/repositories/step_repository_active_buckets_test.dart
test/presentation/cubits/today_cubit_test.dart

## Story completion status

- Status: **review**
- Ultimate context engine analysis completed — comprehensive developer guide created
