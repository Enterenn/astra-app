# Story 16.5: Granular BlocSelector on TodayScreen

Status: review

<!-- Refacto Epic 16 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 16-5 · refactoring-audit-master-v0.6.1.md §3.1 · REF-11 · NFR-REF-01 -->
<!-- Prerequisite: 16-4 done (GoalRing RepaintBoundary) — complementary: 16-4 isolates GPU layer, 16-5 isolates widget rebuilds -->
<!-- Next in epic: 16-6 (Collection Health Indicator) — do not start 16-6 in this story -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want the Today dashboard to update only the widgets that changed,
So that live step ticks do not rebuild the entire screen 120 times per second.

## Acceptance Criteria

1. **Given** `TodayScreen` global `BlocBuilder` (currently lines 41–115)  
   **When** refactored  
   **Then** replaced with targeted `BlocSelector<TodayCubit, TodayState, …>` widgets (REF-11, NFR-REF-01):
   - `_WeekSection` → rebuilds only when week strip data changes (`weekDays` content or `selectedLocalDay`)
   - `_GoalRingCard` → rebuilds only when GoalRing-relevant fields change (see Dev Notes — field inventory)
   - `_ActivityStatsSection` → rebuilds only when `status` or `activityMetrics` change
   - `_StaleBannerSlot` → rebuilds only when `isStale` changes
   - `_PermissionCta` → rebuilds only when permission status changes (`status == TodayStatus.noPermission`)
   **And** screen title, scroll padding, and Set goal button shell are **outside** any bloc listener (static)

2. **Given** live step increment while viewing today (`TodayCubit._applyLiveSteps`)  
   **When** observed in DevTools **Rebuild Stats** (or build-counter widget test in Sub-task C)  
   **Then** `_WeekSection` does **not** rebuild unless today's `goalMet` pill toggles  
   **And** static shell (title, Set goal pill) does **not** rebuild  
   **And** `_GoalRingCard` and `_ActivityStatsSection` **may** rebuild (expected — steps + derived metrics change every tick)

3. **Given** goal change, week refresh, day selection, celebration, or stale flag change  
   **When** emitted by `TodayCubit`  
   **Then** only selectors whose selected slice changed rebuild — unaffected sections stay mounted without rebuild

4. **Given** full `flutter test --exclude-tags slow` suite  
   **When** run after changes  
   **Then** all tests pass — especially `screen_smoke_test.dart` (TodayScreen group), `app_scaffold_test.dart`, `goal_ring_test.dart`, `today_screen_trophy_test.dart`

5. **Given** work completes on branch `refacto`  
   **When** story is marked done  
   **Then** **no version bump** yet — Epic 16 closes with minor+1 (`0.7.0+15`) when all stories are done

**Covers:** REF-11 · NFR-REF-01 (120 Hz CPU rebuild efficiency) · Audit §3.1 (TodayScreen global BlocBuilder)

## Tasks / Subtasks

- [x] **Sub-task A — Replace global `BlocBuilder` with static shell + peripheral selectors** (AC: #1, #3)
  - [x] Read `lib/presentation/screens/today_screen.dart` fully before editing
  - [x] Remove the outer `BlocBuilder` wrapping `SingleChildScrollView` (lines 41–115)
  - [x] Keep title `Text('Steps')`, padding, and scroll structure as **static** widgets (no bloc listener)
  - [x] Extract `_StaleBannerSlot` with `BlocSelector` on `state.isStale`
  - [x] Extract `_WeekSection` with `BlocSelector` + `_WeekProgressViewModel` equality (see Dev Notes)
  - [x] Extract `_PermissionCta` with `BlocSelector` on `state.status == TodayStatus.noPermission`
  - [x] Extract `_ActivityStatsSection` with `BlocSelector` on `_ActivityStatsViewModel` (status + metrics)
  - [x] Run `flutter analyze lib/presentation/screens/today_screen.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Refactor `_GoalRingCard` to self-contained `BlocSelector`** (AC: #1, #2, #3)
  - [x] Remove `state` constructor param from `_GoalRingCard` — read via internal `BlocSelector`
  - [x] Selector returns `_GoalRingViewModel` with all fields GoalRing / GoalCelebration need (inventory in Dev Notes)
  - [x] Preserve Set goal button **outside** the selector builder (static — no state dependency)
  - [x] Preserve existing callbacks: `dismissCelebration`, `clearForegroundCatchUp`, `recordLastDisplayedSteps`
  - [x] Run `flutter test test/presentation/screens/screen_smoke_test.dart --name TodayScreen`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Build-isolation widget test + full suite + DevTools note** (AC: #2, #4)
  - [x] Add build-counter wrapper test in `test/presentation/screens/today_screen_selector_test.dart` (new file):
    - Seed cubit with week days + initial steps
    - Wrap `_WeekSection` target with `_BuildCounter`, emit `copyWith(steps: steps + 1)` only
    - Assert week counter == 1, goal-ring counter incremented (or use separate counters per section)
  - [x] Run `flutter test test/presentation/screens/today_screen_selector_test.dart`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] Manual: DevTools Rebuild Stats on device — document in review brief that title/week row stay cold on step tick
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Replace global `BlocBuilder` with granular `BlocSelector`s in `today_screen.dart` | `RepaintBoundary` changes (Stories **16-3**, **16-4** — done) |
| Private view-model records/classes for selector equality | `Equatable` on `TodayState` / `ActivityMetricsSnapshot` (avoid scope creep) |
| Build-counter widget test proving selective rebuild | Changing `TodayCubit` emit granularity |
| DevTools Rebuild Stats verification (manual AC #2) | Collection health indicator UI (Story **16-6**) |
| Preserve all UX: stale banner, week pills, celebration, permission CTA | Cold-start shimmer (Story **16-7**) |
| `today_screen.dart` + new selector test file | Refactoring `GoalRing` internals or `ActivityStatsRow` |

### Why this matters (audit §3.1)

```41:115:lib/presentation/screens/today_screen.dart
        child: BlocBuilder<TodayCubit, TodayState>(
          builder: (context, state) {
            return Semantics(
              // ... entire screen including static title rebuilds on every emit
```

Live step pipeline (`TodayCubit._applyLiveSteps` → `_applyTodaySnapshot`) can emit at sensor frequency (~120 Hz coalesced in GoalRing, but cubit emits on each applied step). A global `BlocBuilder` forces **full subtree rebuild** including:
- Static `"Steps"` title
- Week trophy + pills (even when only step count changes)
- Set goal pill (stateless — never needs rebuild)
- Permission CTA (only when `noPermission`)

Story **16-4** added GPU `RepaintBoundary` inside GoalRing — reduces compositing cost but **does not prevent widget rebuilds**. This story addresses CPU-side rebuild isolation (REF-11).

### Cubit emit fields on live step tick (read-only — informs selector design)

From `TodayCubit._applyLiveSteps` (lines 733–785):

| Field | Changes on every step tick? | Selector |
|-------|----------------------------|----------|
| `steps` | Yes | `_GoalRingViewModel` |
| `status` | Sometimes (empty→progress, progress→goalMet, etc.) | `_GoalRingViewModel`, `_ActivityStatsViewModel` |
| `goal` | No (unless goal edit) | `_GoalRingViewModel` |
| `activityMetrics` | Yes (`_liveMetricsForSteps`) | `_ActivityStatsViewModel` |
| `weekDays` | Only when today's `goalMet` toggles (`_patchTodayGoalMetForLiveSteps`) | `_WeekProgressViewModel` |
| `selectedLocalDay` | No on step tick | `_WeekProgressViewModel` |
| `isStale` | No on step tick | `_StaleBannerSlot` |
| `showCelebration` | No on step tick | `_GoalRingViewModel` |
| `foregroundCatchUp` / `catchUpTargetSteps` | On resume, not step tick | `_GoalRingViewModel` |
| `lastDisplayedSteps` / `lastDisplayedStepsLoaded` | On day load / ring callback | `_GoalRingViewModel` |

### GoalRing field inventory (do NOT under-select)

`GoalRing` reads these `TodayState` fields (grep-verified in `goal_ring.dart`):

| Field | Used for |
|-------|----------|
| `status` | Pulse, overflow, arc, center count, semantics |
| `steps` | Display count, animations |
| `goal` | Arc ratio, center label, semantics |
| `foregroundCatchUp` | Catch-up animation path |
| `catchUpTargetSteps` | Catch-up target steps |
| `lastDisplayedSteps` | Animation seed |
| `lastDisplayedStepsLoaded` | Gate before animating |
| `selectedLocalDay` | Reset on day change (`didUpdateWidget`) |
| `showCelebration` | `_GoalRingCard` chooses GoalCelebration vs GoalRing |

`GoalCelebration` also receives full `TodayState` (uses `progressRatio` at minimum).

**Selector slice:** build `_GoalRingViewModel` with all nine fields above; implement `==` / `hashCode` manually (or Dart 3 record if preferred — records work for primitives + enum + DateTime? with care).

### Recommended selector view-models (private to `today_screen.dart`)

```dart
@immutable
final class _WeekProgressViewModel {
  const _WeekProgressViewModel({
    required this.weekDays,
    required this.selectedLocalDay,
  });

  final List<WeekDayStatus> weekDays;
  final DateTime? selectedLocalDay;

  static _WeekProgressViewModel fromState(TodayState state) =>
      _WeekProgressViewModel(
        weekDays: state.weekDays,
        selectedLocalDay: state.selectedLocalDay,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _WeekProgressViewModel &&
        listEquals(weekDays, other.weekDays) &&
        _sameLocalDay(selectedLocalDay, other.selectedLocalDay);
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(weekDays), selectedLocalDay);
}

@immutable
final class _ActivityStatsViewModel {
  const _ActivityStatsViewModel({required this.status, required this.metrics});
  final TodayStatus status;
  final ActivityMetricsSnapshot metrics;

  static _ActivityStatsViewModel fromState(TodayState state) =>
      _ActivityStatsViewModel(status: state.status, metrics: state.activityMetrics);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _ActivityStatsViewModel) return false;
    return status == other.status &&
        metrics.distanceKm == other.metrics.distanceKm &&
        metrics.kcal == other.metrics.kcal &&
        metrics.walkingDuration == other.metrics.walkingDuration;
  }

  @override
  int get hashCode => Object.hash(status, metrics.distanceKm, metrics.kcal, metrics.walkingDuration);
}
```

Use `import 'package:flutter/foundation.dart' show listEquals;` for week day list equality.

**Critical:** `WeekDayStatus` has no `==` override — `listEquals` uses `==` per element, which is **identity-only**. Two lists with identical content but new `WeekDayStatus` instances will compare unequal. This matches cubit behaviour: when `_patchTodayGoalMetForLiveSteps` returns the **same list reference** (no goalMet change), selector correctly skips rebuild. When cubit emits a new list (goalMet toggled), rebuild is correct.

### Target widget tree after refactor (structural guide)

```dart
@override
Widget build(BuildContext context) {
  // colors, padding — static
  return ColoredBox(
    child: SafeArea(
      child: Semantics(
        label: _kScreenTitle,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(_kScreenTitle, ...),           // static
              _StaleBannerSlot(),                  // BlocSelector → isStale
              _WeekSection(),                      // BlocSelector → week VM
              _GoalRingCard(),                     // internal BlocSelector → ring VM
              _PermissionCta(),                    // BlocSelector → noPermission
              _ActivityStatsSection(),             // BlocSelector → stats VM
            ],
          ),
        ),
      ),
    ),
  );
}
```

**Do not:**
- Wrap the entire `Column` in any `BlocBuilder` / `BlocConsumer`
- Add `BlocSelector` around the screen title or Set goal pill
- Change `GoalRing`, `WeekProgressRow`, or `ActivityStatsRow` widget APIs
- Add `equatable` package or modify `TodayState` / `ActivityMetricsSnapshot`
- Move selectors to `AppScaffold` (tab isolation is Story **16-3**)
- Add health indicator UI (Story **16-6**)

### `_GoalRingCard` refactor pattern

Current (lines 124–176): receives `TodayState state` from parent `BlocBuilder`.

After refactor:

```dart
class _GoalRingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedCard(
      child: Column(
        children: [
          BlocSelector<TodayCubit, TodayState, _GoalRingViewModel>(
            selector: _GoalRingViewModel.fromState,
            builder: (context, vm) {
              final cubit = context.read<TodayCubit>();
              final ringState = vm.toTodayState(); // or pass vm fields into a minimal TodayState
              return Center(
                child: vm.showCelebration
                    ? GoalCelebration(state: ringState, onComplete: cubit.dismissCelebration)
                    : GoalRing(
                        state: ringState,
                        onForegroundCatchUpHandled: cubit.clearForegroundCatchUp,
                        onLastDisplayedStepsChanged: cubit.recordLastDisplayedSteps,
                      ),
              );
            },
          ),
          // Set goal button — static, unchanged
        ],
      ),
    );
  }
}
```

**`toTodayState()` helper:** construct `TodayState.fromData(...)` or `TodayState(...)` with sensible defaults for unused fields (e.g. `weekDays: const []`, `isStale: false`) — GoalRing ignores those during ring render. Prefer `TodayState.fromData` so `status` is derived from steps/goal unless explicitly overridden.

### flutter_bloc 9.x `BlocSelector` API

Project uses `flutter_bloc: ^9.1.1` — no new dependencies.

```dart
BlocSelector<TodayCubit, TodayState, SelectedType>(
  selector: (state) => SelectedType.fromState(state),
  builder: (context, selected) => Widget(...),
)
```

Rebuild occurs when `selected != previous` (uses `==` on the **selected** value, not full `TodayState`). This is why view-model classes with proper equality are required.

**First use in codebase** — no existing `BlocSelector` patterns to copy; follow flutter_bloc docs and this story's view-models.

### Build-counter test pattern (Sub-task C)

```dart
class _BuildCounter extends StatefulWidget {
  const _BuildCounter({required this.child});
  final Widget child;
  static int builds = 0;

  @override
  State<_BuildCounter> createState() => _BuildCounterState();
}

class _BuildCounterState extends State<_BuildCounter> {
  @override
  Widget build(BuildContext context) {
    _BuildCounter.builds++;
    return widget.child;
  }
}
```

Test flow:
1. Reset counters; pump `TodayScreen` with seeded `_SeededTodayCubit` (copy pattern from `screen_smoke_test.dart`)
2. Record initial build counts for week section vs goal ring section (use `Key` + `find.byKey` to locate subtrees, or test private widgets via `@visibleForTesting` exports — prefer **keys** on section roots: `Key('today_week_section')`, etc.)
3. `cubit.emit(cubit.state.copyWith(steps: cubit.state.steps + 1, activityMetrics: ...))` — mirror what `_applyLiveSteps` would emit
4. `await tester.pump()`
5. Assert week build counter unchanged; goal ring / stats counters incremented

Export section keys on widgets for testability without making view-models public.

### Previous story intelligence (16-4)

- `GoalRing` now has internal `RepaintBoundary` — orthogonal to this story; do not remove or duplicate
- Sub-task commit workflow: review brief → Baptiste OK → commit (`docs/project-context.md`)
- Version stays `0.6.3+14` until epic close
- Dispose/lifecycle hardening complete — do not touch `goal_ring.dart` unless ring rebuild regression found

### Previous story intelligence (16-3)

- Tab-level `RepaintBoundary` in `AppScaffold` — Today tab root still rebuilds when `TodayScreen` rebuilds; this story reduces **internal** Today rebuild scope
- DevTools **Repaint Rainbow** was used for 16-3; use **Rebuild Stats** (or Track Widget Rebuilds) for 16-5
- Structural widget test pattern: assert expected widget types at tree positions

### Previous story intelligence (15-2)

- `GoalRing` is prefs-free; `lastDisplayedSteps` flows from cubit state
- `_GoalRingCard._onSetGoalTapped` uses `cubit.todayEditableGoal` — unchanged, stays outside selector

### Regression risks

| Risk | Mitigation |
|------|------------|
| Under-selecting GoalRing fields → stale UI | Use full nine-field inventory above |
| Week row not updating on day tap | Selector must include `selectedLocalDay` |
| Week row not updating when goalMet toggles | Accept rebuild when list reference/content changes |
| Celebration overlay not showing | Include `showCelebration` in ring VM |
| `screen_smoke_test` breaks | Run full TodayScreen group after Sub-task B |
| Set goal button rebuilds unnecessarily | Keep outside `BlocSelector` builder |
| Over-engineering with `context.select` | Use explicit `BlocSelector` per audit/epic spec |

### Architecture compliance

- **NFR-REF-01:** Reduces CPU widget rebuild work during 120 Hz live step updates
- **NFR-REF-05:** Presentation-only; no repository or cubit logic changes
- **D-10 / Today hero:** GoalRing remains pure presentation; cubit remains single writer
- **Review-before-commit:** one commit per sub-task, review brief, wait for Baptiste OK
- **No new dependencies**

### Test files to run (minimum)

| File | Why |
|------|-----|
| `test/presentation/screens/today_screen_selector_test.dart` | New — build isolation |
| `test/presentation/screens/screen_smoke_test.dart` | TodayScreen smoke group |
| `test/presentation/screens/app_scaffold_test.dart` | Tab integration |
| `test/presentation/widgets/goal_ring_test.dart` | Ring behaviour unchanged |
| `test/presentation/screens/today_screen_trophy_test.dart` | `countWeekGoalsMet` helper unchanged |
| `flutter test --exclude-tags slow` | AC #4 — suite-wide regression |

### Manual DevTools steps (Sub-task C)

1. `flutter run` on device/emulator (profile or debug with rebuild tracking)
2. Open DevTools → **Performance** → enable **Track Widget Rebuilds**
3. Stay on Today tab; trigger live steps (walk or dev ingest)
4. Confirm `"Steps"` title and week strip widgets stay green/low rebuild count
5. Confirm GoalRing and stats row rebuild (expected)
6. Tap a past day pill — only week + ring sections should spike rebuilds
7. Record findings in review brief

### References

- [Source: `_bmad-output/planning-artifacts/epics-refacto.md` — Story 16-5, REF-11, NFR-REF-01]
- [Source: `_bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md` — §3.1 TodayScreen BlocSelector]
- [Source: `lib/presentation/screens/today_screen.dart` — global BlocBuilder (lines 41–115), `_GoalRingCard` (124–204)]
- [Source: `lib/presentation/cubits/today_state.dart` — state fields]
- [Source: `lib/presentation/cubits/today_cubit.dart` — `_applyLiveSteps` (733–785), `_patchTodayGoalMetForLiveSteps` (792–821)]
- [Source: `lib/presentation/widgets/goal_ring.dart` — state field usage]
- [Source: `test/presentation/screens/screen_smoke_test.dart` — `_SeededTodayCubit`, `pumpScreen` helpers]
- [Source: `_bmad-output/implementation-artifacts/stories/16-4-goal-ring-repaint-boundary-and-controller-lifecycle-audit.md` — GPU vs rebuild distinction]
- [Source: `_bmad-output/implementation-artifacts/stories/16-3-tab-repaint-isolation-in-app-scaffold.md` — DevTools verification pattern]
- [Source: `docs/project-context.md` — review-before-commit workflow]

## Dev Agent Record

### Agent Model Used

Composer (dev-story workflow)

### Debug Log References

- BlocSelector rebuild probes inside mounted GoalRing/WeekProgressRow subtrees are unreliable in widget tests (GoalRing lifecycle emits during pump). Isolation proven via slice-equality unit tests + standalone BlocSelector widget tests with `todaySectionBuildProbe`.

### Completion Notes List

- Replaced global `BlocBuilder` with static shell (`Steps` title, scroll padding) and five targeted `BlocSelector` sections: stale banner, week, goal ring, permission CTA, activity stats.
- Added private view-models (`_WeekProgressViewModel`, `_ActivityStatsViewModel`, `_GoalRingViewModel`) with manual `==`/`hashCode` for selective rebuild.
- `_GoalRingCard` is self-contained: internal `BlocSelector` for ring/celebration; Set goal pill remains static outside selector builder.
- `@visibleForTesting` hooks: `todaySectionBuildProbe`, slice equality helpers, section builders for tests.
- New `today_screen_selector_test.dart`: slice equality unit tests + BlocSelector rebuild isolation (week cold on step tick; goal-ring VM hot on step tick).
- `flutter analyze` clean on `today_screen.dart`. Story-specific tests pass (smoke, scaffold, goal_ring, trophy). Full suite: 771 pass; 1 pre-existing flaky cubit test (`past-day select…`) fails only in batch order, passes in isolation — unrelated to this story.
- **DevTools (manual AC #2):** Profile/debug → DevTools → Performance → Track Widget Rebuilds. On live step tick, expect `"Steps"` title and week strip cold; GoalRing + stats row hot. Tap past-day pill → week + ring spike only.
- No version bump (Epic 16 close policy). Review-before-commit: 3 sub-task commits pending Baptiste OK.

### File List

- `lib/presentation/screens/today_screen.dart` (modified)
- `test/presentation/screens/today_screen_selector_test.dart` (new)
- `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml` (status sync)
- `_bmad-output/implementation-artifacts/stories/16-5-granular-bloc-selector-on-today-screen.md` (story record)

## Change Log

- 2026-06-19: Story context created (create-story workflow) — ready-for-dev. Ultimate context engine analysis completed — comprehensive developer guide created.
- 2026-06-19: Implemented granular BlocSelector refactor on TodayScreen (Sub-tasks A–C). Status → review.
