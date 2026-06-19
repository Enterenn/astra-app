# Story 16.7: Cold-Start Loading Shimmer for Today

Status: review

<!-- Refacto Epic 16 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 16-7 · refactoring-audit-master-v0.6.1.md §5.2 · REF-13 · UX-REF-03 -->
<!-- Prerequisite: 15-2 done (display state in TodayCubit) · 16-5/16-6 done (BlocSelectors + health indicator) -->
<!-- Last story in Epic 16 — epic close bumps minor+1 (0.7.0+15) after all stories done -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want the step counter to avoid flashing "0" on cold start,
So that the first impression matches my actual progress.

## Acceptance Criteria

1. **Given** Story 15-2 is complete (display state in cubit)  
   **When** app cold-starts  
   **Then** `TodayCubit` emits `TodayStatus.loading` until **both** initial SQLite steps **and** `lastDisplayedSteps` for today are loaded (`lastDisplayedStepsLoaded == true`) (REF-13, UX-REF-03)  
   **And** `silent: true` refreshes (resume, periodic, ingestion) do **not** re-enter loading or flash shimmer

2. **Given** `TodayStatus.loading` **or** `lastDisplayedStepsLoaded == false` while viewing the selected day  
   **When** Today screen renders GoalRing  
   **Then** ring + step counter show a **light shimmer / skeleton placeholder** — **not** numeric text like `0`, `0 / 8 000`, or `/8 000` (UX-REF-03, UX spec §2.3 `loading` row)

3. **Given** initial load completes (`status != loading` and `lastDisplayedStepsLoaded == true`)  
   **When** cubit emits ready state  
   **Then** shimmer transitions to actual step count **without jarring flash**  
   **And** existing cold-start count-up from `lastDisplayedSteps` → `steps` is preserved (Story 15-2 flow)

4. **Given** OS "reduce motion" is enabled  
   **When** loading UI shows  
   **Then** shimmer is **static** skeleton (no pulse loop) — same pattern as overflow ambient shimmer in Story 16-4

5. **Given** Story 16-5/16-6 selectors  
   **When** loading resolves to ready  
   **Then** stale banner stays hidden during loading (`todayStaleBannerVisible` already excludes `TodayStatus.loading`)  
   **And** collection health indicator stays hidden during loading (`CollectionHealthDisplay.loading` → `SizedBox.shrink`)

6. **Given** full `flutter test --exclude-tags slow` suite  
   **When** run after changes  
   **Then** all tests pass — extend `goal_ring_test.dart`, `today_cubit_test.dart`, and smoke/selector tests as needed

7. **Given** work completes on branch `refacto`  
   **When** story is marked done  
   **Then** **no version bump** yet — Epic 16 closes with minor+1 (`0.7.0+15`) when all stories are done

**Covers:** REF-13 · UX-REF-03 · Audit §5.2 (cold-start flash) · UX spec §2.3 GoalRing `loading` state

**Depends on:** Story 15-2 (done).

## Tasks / Subtasks

- [x] **Sub-task A — Verify & harden cubit loading gate** (AC: #1)
  - [x] Read `today_cubit.dart`, `today_state.dart` fully before editing
  - [x] Confirm cold-start path: constructor `super(const TodayState.loading())` → `_refreshImpl` loads steps + `getLastDisplayedSteps` in one `Future.wait` → `_applyTodaySnapshot(..., lastDisplayedStepsLoaded: true)` emits ready state
  - [x] **Gap to fix:** `selectLocalDay` emits `lastDisplayedStepsLoaded: false` but keeps prior `status` — GoalRing can briefly show stale numbers. Emit `TodayStatus.loading` (or equivalent gate) until `_applySelectedDayDisplay` finishes loading display prefs for the new day
  - [x] Ensure `syncSteps` / live pipeline does **not** emit ready state while `lastDisplayedStepsLoaded == false` on cold bind
  - [x] Preserve `refresh(silent: true)` — no loading emit when silent (lines 483–485)
  - [x] Add/extend `today_cubit_test.dart` cases: cold start stays loading until both fetches complete; `selectLocalDay` does not flash prior day's count
  - [x] Run `flutter test test/presentation/cubits/today_cubit_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — GoalRing center shimmer skeleton** (AC: #2, #4)
  - [x] Read `goal_ring.dart` fully — especially `_buildCenterContent`, `_syncPulseAnimation`, `_buildRing`
  - [x] **Root bug today:** loading hides center step count (`''`) but still renders `'/${formatStepCount(widget.state.goal)}'` — this is the visible `/8 000` flash users see
  - [x] Introduce `_isLoadingPlaceholder` getter:
  - [x] When `_isLoadingPlaceholder`: replace numeric center column with skeleton bars (reuse ring's `_pulseController` opacity or static bars when reduce motion)
  - [x] Recommended layout (match UX "light shimmer"):
  - [x] Keep existing ring `FadeTransition` pulse on track during loading — already matches UX §2.3 "Skeleton ring (muted track pulse)"
  - [x] Semantics: keep `'Steps today: loading'` label; value `null` (already correct)
  - [x] Run `flutter analyze lib/presentation/widgets/goal_ring.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Loading → ready transition polish** (AC: #3)
  - [x] Ensure `_handleStepChange` cold-start path still fires when transitioning `loading → progress|empty|goalMet|overflow` with `lastDisplayedStepsLoaded == true` (lines 262–276 — do not regress)
  - [x] Optional: short `AnimatedSwitcher` (200–300ms) on center content skeleton → count — only if it does not fight count-up animation; document choice in review brief
  - [x] Manual verify: cold start with stored `lastDisplayedSteps=470` and DB steps `520` → shimmer → count-up 470→520 (no flash of 520 first)
  - [x] Manual verify: `refresh(silent: false)` from stale banner shows brief shimmer then data — acceptable
  - [x] Run `flutter test test/presentation/widgets/goal_ring_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Tests + regression suite** (AC: #5, #6)
  - [x] `goal_ring_test.dart`: assert loading / `lastDisplayedStepsLoaded: false` shows **no** `find.textContaining('/')` goal fraction and no `0` step digits
  - [x] `goal_ring_test.dart`: assert skeleton widgets present (e.g. `find.byType(Container)` with shimmer key or dedicated `Key('goal_ring_loading_skeleton')`)
  - [x] `goal_ring_test.dart`: loading → ready transition triggers count-up (extend existing cold-start test)
  - [x] `today_screen_selector_test.dart`: confirm stale banner + health slot stay cold/hidden during loading (may already pass — verify)
  - [x] `screen_smoke_test.dart` / `app_scaffold_test.dart`: `_SeededTodayCubit` helpers must seed `lastDisplayedStepsLoaded: true` for non-loading scenarios (pattern from 16-5/16-6)
  - [x] Run `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Cold-start + day-switch loading gate in cubit | Activity stats row shimmer redesign (`—` placeholders already exist) |
| GoalRing ring pulse + center skeleton during loading | Week section `CircularProgressIndicator` (unchanged) |
| Preserve 15-2 count-up animation after load | i18n of loading semantics (Epic 19) |
| `selectLocalDay` loading gate fix | Changing default goal constant |
| Tests for no numeric flash | New shimmer package dependency |
| `goal_ring.dart`, `today_cubit.dart`, tests | `today_screen.dart` changes unless selector wiring needs tweak |

### What already exists (do NOT reinvent)

Story 15-2 and partial 16-x work delivered most infrastructure. **Extend, don't duplicate.**

| Artifact | Current behavior | Story 16-7 action |
|----------|------------------|-------------------|
| `TodayState.loading()` | Initial cubit state | Keep |
| `lastDisplayedSteps` / `lastDisplayedStepsLoaded` | Loaded in `_refreshImpl` | Harden day-switch gate |
| GoalRing ring pulse | `FadeTransition` opacity 0.35–0.85 on track | Keep — matches UX |
| GoalRing center text | `''` for steps but **`/goal` still visible** | **Fix — main UX bug** |
| `ActivityStatsRow` | Shows `—` when loading | No change needed |
| `todayStaleBannerVisible` | Hides banner when loading | Verify only |
| `deriveCollectionHealthDisplay` | Returns `loading` → indicator hidden | Verify only |
| `_LoadingSkeleton` (History charts) | Static gray bars | Visual reference only |

### The flash bug (read this first)

```701:748:lib/presentation/widgets/goal_ring.dart
  Widget _buildCenterContent(AstraColors colors, bool reduceMotion) {
    final status = widget.state.status;
    final centerText = switch (status) {
      TodayStatus.loading => '',
      // ...
    };
    // ...
          if (centerText != null)
            Text(centerText, style: stepCountStyle)
          else if (reduceMotion || widget.freezeMotion)
            Text(formatStepCount(_targetSteps), style: stepCountStyle)
          else
            AnimatedStepCount(...),
          const SizedBox(height: 2),
          Text(
            '/${formatStepCount(widget.state.goal)}',  // ← FLASH: visible during loading
            style: AstraTypography.goalRingLabelFor(colors),
          ),
```

During `TodayStatus.loading()`, `TodayState` defaults `goal` to `kDefaultStepGoal` (8000). User sees `/8 000` before data loads — audit's "0 / 10 000" class of bug.

### Cubit loading lifecycle (preserve)

```186:192:_bmad-output/implementation-artifacts/stories/15-2-move-goal-ring-display-persistence-to-today-cubit.md
1. App opens → `TodayCubit` starts `TodayStatus.loading`
2. `_refreshImpl` loads SQLite steps + `lastDisplayedSteps` from prefs
3. Emits ready state with `lastDisplayedStepsLoaded: true`
4. `GoalRing` sees loaded flag → cold-start count-up from `lastDisplayedSteps`
```

`_refreshImpl` already batches loads:

```507:565:lib/presentation/cubits/today_cubit.dart
    final results = await Future.wait<Object?>([
      stepRepository.getTodaySteps(),
      _resolveTodayGoal(),
      // ...
      userPreferences.getLastDisplayedSteps(todayIso),
    ]);
    // ...
    await _applyTodaySnapshot(
      // ...
      lastDisplayedSteps: lastDisplayedSteps,
      lastDisplayedStepsLoaded: true,
    );
```

**Silent refresh guard** (do not break):

```483:485:lib/presentation/cubits/today_cubit.dart
    if (!silent && state.status != TodayStatus.loading) {
      emit(const TodayState.loading());
    }
```

### Day-switch gap (Sub-task A)

```600:607:lib/presentation/cubits/today_cubit.dart
    emit(
      state.copyWith(
        selectedLocalDay: normalizedDay,
        lastDisplayedSteps: null,
        lastDisplayedStepsLoaded: false,
      ),
    );
    unawaited(_applySelectedDayDisplay());
```

Status stays `progress`/`overflow`/etc. while `lastDisplayedStepsLoaded` is false → GoalRing may render prior `_displayedSteps` until async load completes. **Fix:** treat `!lastDisplayedStepsLoaded` same as loading in GoalRing (Sub-task B getter), and optionally emit `status: TodayStatus.loading` in cubit during day switch (cleaner semantics — document in review brief).

### UX specification (locked)

From `ux-design-specification.md` §2.3 GoalRing states:

| State | Visual | Behavior |
|-------|--------|----------|
| **loading** | Skeleton ring (muted track pulse) | First launch before first sample |

Center count during loading must be skeleton — not formatted digits. Celebration/overflow shimmer painters (`GoalRingShimmerPainter`) are **unrelated** — do not reuse for loading skeleton.

### Recommended center skeleton widget

Keep private inside `goal_ring.dart` unless reused:

```dart
class _GoalRingCenterSkeleton extends StatelessWidget {
  const _GoalRingCenterSkeleton({
    required this.colors,
    required this.pulseOpacity,
  });

  final AstraColors colors;
  final double? pulseOpacity; // null = static (reduce motion)

  @override
  Widget build(BuildContext context) {
    final alpha = pulseOpacity ?? 1.0;
    Color barColor() => colors.textMuted.withValues(alpha: 0.18 * alpha);
    // Two rounded Container bars, centered
  }
}
```

Wire `pulseOpacity` from `_pulseController` when animating; `null` when `MediaQuery.disableAnimationsOf(context)`.

### Cold-start animation contract (must preserve)

```262:276:lib/presentation/widgets/goal_ring.dart
    final isColdStart =
        forceColdStart ||
        (!_coldStartHandled &&
            oldStatus == TodayStatus.loading &&
            status != TodayStatus.loading);

    if (isColdStart) {
      _coldStartHandled = true;
      final start = _lastDisplayedSteps;
      // ... count-up from start → target
    }
```

Do **not** set `_displayedSteps` to target before `lastDisplayedStepsLoaded` — `initState` already holds at zero until seed (lines 152–158).

### TodayScreen selector impact

`_GoalRingViewModel` already includes `status`, `lastDisplayedStepsLoaded` — selector will rebuild when loading resolves (expected). No selector refactor needed unless extracting a `isLoadingPlaceholder` field for clarity.

**Do not** wrap GoalRing in an outer loading branch in `today_screen.dart` — keep loading UX inside `GoalRing` so `RepaintBoundary` + controller lifecycle from Story 16-4 stay cohesive.

### Previous story intelligence (16-6)

- Health indicator hidden during loading — do not regress
- Stale banner uses `todayStaleBannerVisible` — loading excluded
- Sub-task commit workflow: review brief → Baptiste OK → commit
- English strings until Epic 19
- Version stays `0.6.3+14` until epic close

### Previous story intelligence (16-5)

- `@visibleForTesting` hooks: `todaySectionBuildProbe`, section keys — loading transition may cause extra goal-ring rebuild (acceptable)
- Activity stats selector uses `Object` slice + manual equality — unchanged
- Run `today_screen_selector_test.dart` after changes

### Previous story intelligence (15-2)

- Display prefs loaded only in cubit — GoalRing must not read prefs
- `recordLastDisplayedSteps` callback unchanged
- `app_scaffold.dart` purge order: `clearLastDisplayedSteps` before `refresh` — unchanged

### Regression risks

| Risk | Mitigation |
|------|------------|
| Silent refresh flashes shimmer | Only emit loading when `!silent` |
| Count-up broken after shimmer | Test `loading → progress` with `lastDisplayedSteps` seed |
| Double loading on permission denied | `_refreshImpl` emits `noPermission` directly — skip shimmer skeleton, show dashed ring + `--` |
| Pulse controller leak | Reuse existing `_syncPulseAnimation` / dispose tests |
| `app_live_pipeline_lifecycle_test` races | Tests already wait for `status != loading` — keep pattern |
| Activity stats show `0` during loading | Already show `—` — verify no change |

### Architecture compliance

- **NFR-REF-05:** Display loading is presentation; cubit only owns loading **state** timing
- **NFR-REF-01:** No extra global rebuilds — shimmer inside existing GoalRing selector path
- **D-10 / Today hero:** GoalRing remains pure presentation
- **Layering:** No new repository calls from widgets
- **Review-before-commit:** one commit per sub-task
- **No new dependencies**

### Test files to run (minimum)

| File | Why |
|------|-----|
| `test/presentation/widgets/goal_ring_test.dart` | Loading skeleton, transition, dispose |
| `test/presentation/cubits/today_cubit_test.dart` | Loading gate, day switch |
| `test/presentation/screens/today_screen_selector_test.dart` | Stale/health hidden during loading |
| `test/presentation/screens/screen_smoke_test.dart` | TodayScreen smoke |
| `test/presentation/screens/app_scaffold_test.dart` | Cold-start integration |
| `test/app_live_pipeline_lifecycle_test.dart` | Live pipeline + loading wait |
| `flutter test --exclude-tags slow` | AC #6 |

### Manual verification steps

1. Force-stop app → relaunch → Today shows pulsing ring + skeleton center (no digits) → resolves to real steps with count-up
2. User with `lastDisplayedSteps=1200` in prefs, DB=3500 → shimmer → animates 1200→3500
3. Toggle reduce motion in OS settings → static skeleton, no pulse
4. Tap stale banner (refresh non-silent) → brief shimmer → data returns
5. Select prior day in week strip → brief skeleton (no prior day count flash) → shows selected day
6. Deny permission → no shimmer digits; dashed ring + `--` as today

### References

- [Source: `_bmad-output/planning-artifacts/epics-refacto.md` — Story 16-7, REF-13, UX-REF-03]
- [Source: `_bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md` — §5.2 cold-start flash]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §2.3 GoalRing `loading` state]
- [Source: `_bmad-output/implementation-artifacts/stories/15-2-move-goal-ring-display-persistence-to-today-cubit.md` — loading gate + count-up flow]
- [Source: `lib/presentation/cubits/today_cubit.dart` — `_refreshImpl`, `selectLocalDay`, `refresh(silent:)`]
- [Source: `lib/presentation/cubits/today_state.dart` — `TodayStatus.loading`, `lastDisplayedStepsLoaded`]
- [Source: `lib/presentation/widgets/goal_ring.dart` — pulse, center content, cold-start]
- [Source: `lib/presentation/widgets/activity_stats_row.dart` — existing `—` loading placeholders]
- [Source: `lib/presentation/widgets/step_bar_chart.dart` — `_LoadingSkeleton` color reference]
- [Source: `lib/presentation/screens/today_screen.dart` — `_GoalRingViewModel`, stale banner gate]
- [Source: `_bmad-output/implementation-artifacts/stories/16-6-collection-health-indicator-and-stale-banner-cta.md` — loading-hidden health/banner]
- [Source: `docs/project-context.md` — review-before-commit workflow]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Monotonic merge in `_applyTodaySnapshot` extended for `TodayStatus.loading` so live-pipeline steps cached during cold bind are preserved when `_refreshImpl` completes.
- Skipped `AnimatedSwitcher` on skeleton → count: existing cold-start count-up handles the transition without fighting animations.

### Completion Notes List

- **Sub-task A:** `selectLocalDay` now emits `TodayStatus.loading`; `syncSteps` and `_applyTodaySnapshot` gate UI-ready emits until `lastDisplayedStepsLoaded == true`; live steps cached in `_todaySteps` during cold bind.
- **Sub-task B:** `_isLoadingPlaceholder` + `_GoalRingCenterSkeleton` hide step digits and `/goal` fraction; pulse on ring + skeleton bars (static when reduce motion).
- **Sub-task C:** Cold-start count-up preserved via existing `_handleStepChange` / `_afterDisplayStateLoaded`; no AnimatedSwitcher added.
- **Sub-task D:** New widget + cubit tests; full `flutter test --exclude-tags slow` green (1934 tests).

### File List

- `lib/presentation/cubits/today_cubit.dart`
- `lib/presentation/widgets/goal_ring.dart`
- `test/presentation/cubits/today_cubit_test.dart`
- `test/presentation/widgets/goal_ring_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml`

## Change Log

- 2026-06-19: Story context created (create-story workflow) — ready-for-dev. Ultimate context engine analysis completed — comprehensive developer guide created.
- 2026-06-19: Implemented cold-start loading shimmer — cubit loading gate, GoalRing center skeleton, tests (status → review).
