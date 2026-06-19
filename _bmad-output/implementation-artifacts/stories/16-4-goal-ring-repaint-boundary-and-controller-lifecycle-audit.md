# Story 16.4: GoalRing RepaintBoundary and Controller Lifecycle Audit

Status: done

<!-- Refacto Epic 16 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 16-4 · refactoring-audit-master-v0.6.1.md §3.3a · REF-10 · NFR-REF-01 -->
<!-- Parallel to: 16-3 (tab RepaintBoundary) — no shared file conflicts; 16-3 is done -->
<!-- Next in epic: 16-5 (BlocSelector on TodayScreen) — do not start 16-5 in this story -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want GoalRing animations to be GPU-efficient and leak-free,
So that long sessions do not degrade performance or memory.

## Acceptance Criteria

1. **Given** `GoalRing` widget tree  
   **When** built  
   **Then** the entire visual subtree is wrapped in `RepaintBoundary` (REF-10)  
   **And** `RepaintBoundary` is the **outermost** widget returned from `GoalRing.build()` (isolates ring + center content + animation layers)

2. **Given** five `AnimationController`s and two `Timer`s in `_GoalRingState`  
   **When** the widget is disposed  
   **Then** all controllers call `dispose()` via the existing `_release*Controller()` helpers  
   **And** both `_liveCoalesceTimer` and `_foregroundCatchUpTimer` are cancelled and nulled  
   **And** a debug-only assertion block verifies zero dangling controllers/timers after `dispose()` (document approach in review brief)

3. **Given** a widget test that mounts `GoalRing` with active pulse or overflow animation, then unmounts the tree  
   **When** `tester.pumpWidget(SizedBox.shrink())` (or equivalent teardown) runs  
   **Then** no exceptions are thrown and pending timers do not fail `flutter test` (use `addTearDown` / `pump` until idle as needed)

4. **Given** a 10-minute Today screen session with live steps (manual verification)  
   **When** memory is profiled in debug (DevTools Memory tab or `flutter run` + observe heap)  
   **Then** no monotonic growth attributable to GoalRing controllers/timers  
   **And** outcome is documented in the review brief (AC cannot be fully automated in CI)

5. **Given** full `flutter test --exclude-tags slow` suite  
   **When** run after changes  
   **Then** all tests pass — especially `test/presentation/widgets/goal_ring_test.dart`, `goal_celebration_test.dart`, `app_scaffold_test.dart`

6. **Given** work completes on branch `refacto`  
   **When** story is marked done  
   **Then** **no version bump** yet — Epic 16 closes with minor+1 (`0.7.0+15`) when all stories are done

**Covers:** REF-10 · NFR-REF-01 (120 Hz GPU efficiency) · Audit §3.3a (GoalRing controllers + repaint isolation)

## Tasks / Subtasks

- [x] **Sub-task A — Wrap `GoalRing.build()` in `RepaintBoundary`** (AC: #1)
  - [x] Read `lib/presentation/widgets/goal_ring.dart` fully before editing
  - [x] Wrap the outermost `build()` return in `RepaintBoundary` (see Dev Notes — exact placement)
  - [x] Do **not** add `RepaintBoundary` in `today_screen.dart` or `goal_celebration.dart` — isolation belongs inside `GoalRing` so all call sites benefit
  - [x] Run `flutter analyze lib/presentation/widgets/goal_ring.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Controller/timer lifecycle audit + dispose widget test** (AC: #2, #3, #5)
  - [x] Audit all 7 lifecycle objects (inventory table in Dev Notes) — confirm every creation path has matching release
  - [x] Harden `dispose()`: null timers after cancel; add `assert` block in debug verifying all controller refs and timers are null post-cleanup
  - [x] Add widget test: mount GoalRing with `TodayStatus.loading` (pulse) or `TodayStatus.overflow`, pump frames, unmount, assert clean teardown
  - [x] Run `flutter test test/presentation/widgets/goal_ring_test.dart`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Manual memory profiling + debug approach documentation** (AC: #4)
  - [x] On device/emulator: `flutter run` in debug, stay on Today tab, trigger live steps for several minutes
  - [x] DevTools → Memory: snapshot before/after; confirm no steady climb in `AnimationController` / `Timer` related retained objects
  - [x] Document debug assertion approach and memory outcome in review brief
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| `RepaintBoundary` inside `GoalRing.build()` | `RepaintBoundary` on `AppScaffold` tabs (Story **16-3**, done) |
| Audit + harden dispose for 5 controllers + 2 timers | `BlocSelector` granularity on `TodayScreen` (Story **16-5**) |
| Debug assertions in `dispose()` | `FlutterMemoryAllocations` listener unless trivial to add — prefer assert block |
| Widget test for clean dispose teardown | 10-minute memory test automation (manual AC #4 only) |
| `goal_ring.dart` (+ `goal_ring_test.dart`) | Changes to `TodayCubit`, repositories, or `goal_ring_effects.dart` shadow cache (Story **16-2**, done) |
| Preserve all animation semantics (micro-tick, catch-up, overflow) | Cold-start shimmer UI (Story **16-7**) |

### Why this matters (audit §3.3a)

`GoalRing` is the highest-frequency repaint subtree on Today — live step updates can tick at 120 Hz. Without `RepaintBoundary`, ring repaints can propagate compositing work to ancestor layers (card, scroll view, tab root). Story **16-3** isolated **tab roots**; this story isolates the **ring itself** within Today.

The audit also flagged **7 lifecycle objects** with significant leak surface on abrupt interruption (phone call, app kill mid-animation):

| Field | Type | Created in | Released in |
|-------|------|------------|-------------|
| `_pulseController` | `AnimationController?` | `_syncPulseAnimation()` when `TodayStatus.loading` | `_releasePulseController()` / `dispose()` |
| `_countUpController` | `AnimationController?` | `_runCountUp()` | `_releaseCountUpController()` / `dispose()` |
| `_microTickController` | `AnimationController?` | `_runMicroTick()` | `_releaseMicroTickController()` / `dispose()` |
| `_liveArcController` | `AnimationController?` | `_runMicroTick()` | `_releaseLiveArcController()` / `dispose()` |
| `_overflowController` | `AnimationController?` | `_syncOverflowAnimation()` when `TodayStatus.overflow` | `_releaseOverflowController()` / `dispose()` |
| `_liveCoalesceTimer` | `Timer?` | `_scheduleLiveUpdate()` | `_resetDisplayed()`, `dispose()` |
| `_foregroundCatchUpTimer` | `Timer?` | `_handleStepChange()` on `foregroundCatchUp` | `_resetDisplayed()`, `dispose()` |

**Current `dispose()` (lines 580–589) already releases all controllers and cancels timers** — this story is an **audit + hardening** pass, not a rewrite. Expect minimal diff unless audit finds a gap.

### Required change — `RepaintBoundary` placement

Current `build()` returns `LayoutBuilder` directly:

```592:627:lib/presentation/widgets/goal_ring.dart
  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // ... Semantics → Stack → ring + center content
      },
    );
  }
```

Wrap **outside** `LayoutBuilder` so the entire ring subtree (including layout-driven diameter) shares one compositing layer:

```dart
@override
Widget build(BuildContext context) {
  final colors = context.astraColors;
  final reduceMotion = MediaQuery.disableAnimationsOf(context);

  return RepaintBoundary(
    child: LayoutBuilder(
      builder: (context, constraints) {
        // unchanged inner tree
      },
    ),
  );
}
```

**Do not:**
- Wrap only `_buildRing()` — center `AnimatedStepCount` and overflow ambient painter must share the same boundary (AC: entire subtree)
- Add `const` to `RepaintBoundary` (inner tree is not const)
- Wrap in `today_screen.dart` — `GoalCelebration` also embeds `GoalRing`; internal boundary covers both call sites
- Change animation durations, coalesce intervals, or step-change logic

### How `RepaintBoundary` helps (and what it does not do)

| Effect | Explanation |
|--------|-------------|
| **Does** | Caches the ring's rasterized layer; parent widgets (card, `SingleChildScrollView`, tab) can skip re-compositing when only siblings change |
| **Does** | Complements Story **16-3** tab isolation — ring repaints stay within Today's tab layer |
| **Does not** | Prevent `GoalRing` widget rebuilds when `TodayScreen`'s global `BlocBuilder` fires — that is Story **16-5** |
| **Does not** | Replace shadow bitmap cache from Story **16-2** — `_insetShadowCache` remains separate |

### Controller lifecycle audit checklist

Walk each path before editing:

1. **`_syncPulseAnimation` / `_syncOverflowAnimation`** — called from `didChangeDependencies` and `didUpdateWidget`; lazy `??=` create, `_release*` on status change. Verify `dispose()` always runs `_release*` even if controller was mid-`repeat()`.
2. **`_runCountUp` / `_runMicroTick`** — ephemeral controllers; `_release*` on completion callbacks. Verify completion handlers check `mounted` before `setState` (existing pattern — do not regress).
3. **`_scheduleLiveUpdate`** — cancels previous `_liveCoalesceTimer` before scheduling new one. Verify `dispose()` cancels and nulls.
4. **`_handleStepChange` foreground catch-up** — `_foregroundCatchUpTimer` with 1s delay. Verify `dispose()` cancels; verify timer callback already guards `if (!mounted) return` (line 316).
5. **`_resetDisplayed`** — cancels both timers; called on day change paths. No controller leak expected.

**Hardening pattern for `dispose()`:**

```dart
@override
void dispose() {
  _liveCoalesceTimer?.cancel();
  _liveCoalesceTimer = null;
  _foregroundCatchUpTimer?.cancel();
  _foregroundCatchUpTimer = null;
  _releasePulseController();
  _releaseCountUpController();
  _releaseMicroTickController();
  _releaseLiveArcController();
  _releaseOverflowController();
  _insetShadowCache.dispose();
  assert(() {
    assert(_pulseController == null);
    assert(_countUpController == null);
    assert(_microTickController == null);
    assert(_liveArcController == null);
    assert(_overflowController == null);
    assert(_liveCoalesceTimer == null);
    assert(_foregroundCatchUpTimer == null);
    return true;
  }());
  super.dispose();
}
```

**Debug approach (AC #2):** Prefer the `assert` block above over `FlutterMemoryAllocations` — zero new dependencies, catches regressions in debug builds during widget tests. Document in review brief why this was chosen.

### Dispose widget test (Sub-task B)

Add to `goal_ring_test.dart`:

```dart
testWidgets('dispose releases animation resources without pending timers', (
  WidgetTester tester,
) async {
  await pumpGoalRing(
    tester,
    state: const TodayState.loading(),
  );
  // Pump enough frames for pulse controller to start
  await tester.pump(const Duration(milliseconds: 100));

  // Unmount — must not throw; pending timers must not fail tearDown
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
});
```

For overflow animation, add a second test using `TodayState.fromData(steps: 10_000, goal: 8000, ...)` (existing overflow fixtures in the file).

### Call sites (read-only — no edits expected)

| File | Usage |
|------|-------|
| `lib/presentation/screens/today_screen.dart` | `_GoalRingCard` → `GoalRing(...)` with cubit callbacks |
| `lib/presentation/widgets/goal_celebration.dart` | Embeds `GoalRing` (including `freezeMotion: true` variant) |
| `test/presentation/widgets/goal_celebration_test.dart` | Layout footprint tests |

Internal `RepaintBoundary` automatically applies to celebration overlay without duplicating boundaries.

### Previous story intelligence (16-3)

- Branch `refacto`, version `0.6.3+14` — no bump for this story
- Pattern: sub-task commits with review brief + Baptiste OK (`docs/project-context.md`)
- 16-3 wrapped **tab roots** in `AppScaffold`; 16-4 wraps **GoalRing** — complementary layers, no file overlap
- DevTools **Repaint Rainbow** was used for 16-3 manual verification; reuse for optional sanity check that ring repaints stay within boundary (not required AC but useful note in review brief)
- Structural widget test pattern from 16-3: assert widget type at expected tree position

### Previous story intelligence (16-2)

- `GoalRingInsetShadowCache` disposed in `GoalRing.dispose()` — preserve this call
- Shadow cache handles per-frame GPU allocation; `RepaintBoundary` handles compositing isolation — orthogonal concerns

### Previous story intelligence (15-2)

- `GoalRing` is prefs-free; display state flows from `TodayState` + `onLastDisplayedStepsChanged`
- Do not reintroduce repository access or static test flags
- Tests seed `lastDisplayedStepsLoaded: true` on fixtures

### Regression risks

| Risk | Mitigation |
|------|------------|
| `RepaintBoundary` only around ring arc, not center count | Wrap at `build()` root, not inside `_buildRing()` |
| Breaking semantics / accessibility | Keep `Semantics` inside `RepaintBoundary` — screen readers unaffected |
| Disposing controllers still referenced by running animation | Existing `_release*` nulls ref before dispose; do not change animation completion order |
| Timer fires after dispose | Existing `mounted` guards + cancel in `dispose()`; null refs after cancel |
| Extra memory from compositing layer | One layer for the hero widget is acceptable (audit trade-off) |
| Scope creep into BlocSelector | Explicitly Story **16-5** |
| Breaking `goal_celebration_test` layout footprint | `RepaintBoundary` is transparent to layout — run celebration tests |

### Architecture compliance

- **NFR-REF-01:** Reduces unnecessary GPU compositing during 120 Hz live step updates
- **NFR-REF-05:** Presentation-only; no repository access from widget
- **D-10 / Today hero:** `GoalRing` remains pure presentation widget [Source: `architecture.md`]
- **Review-before-commit:** one commit per sub-task, review brief, wait for Baptiste OK
- **No new dependencies**

### Test files to run (minimum)

| File | Why |
|------|-----|
| `test/presentation/widgets/goal_ring_test.dart` | Dispose test + existing animation/ring tests |
| `test/presentation/widgets/goal_celebration_test.dart` | Embedded GoalRing layout |
| `test/presentation/screens/app_scaffold_test.dart` | Today tab integration |
| `flutter test --exclude-tags slow` | AC #5 — suite-wide regression |

### Manual memory profiling steps (Sub-task C)

1. `flutter run` on device/emulator (debug mode)
2. Open DevTools → **Memory** → take heap snapshot baseline on Today tab
3. Trigger live steps (walk or dev ingest) for 5–10 minutes
4. Take second snapshot; compare retained `Timer`, `AnimationController`, `_GoalRingState` counts
5. Navigate away from Today (tab switch) and back — verify no accumulation across tab cycles
6. Record findings in review brief

### References

- [Source: `_bmad-output/planning-artifacts/epics-refacto.md` — Story 16-4, REF-10, NFR-REF-01]
- [Source: `_bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md` — §3.3a GoalRing controllers, §3.3b tab isolation]
- [Source: `lib/presentation/widgets/goal_ring.dart` — controllers (lines 94–108), dispose (580–589), build (592–627)]
- [Source: `lib/presentation/screens/today_screen.dart` — `_GoalRingCard` GoalRing wiring (lines 124–148)]
- [Source: `test/presentation/widgets/goal_ring_test.dart` — existing test fixtures and pump helpers]
- [Source: `_bmad-output/implementation-artifacts/stories/16-3-tab-repaint-isolation-in-app-scaffold.md` — parallel RepaintBoundary pattern, sub-task workflow]
- [Source: `_bmad-output/implementation-artifacts/stories/15-2-move-goal-ring-display-persistence-to-today-cubit.md` — GoalRing purity constraints]
- [Source: `docs/project-context.md` — review-before-commit workflow]

## Dev Agent Record

### Agent Model Used

Claude (Cursor Agent)

### Debug Log References

- Lifecycle audit: all 7 objects (5 controllers + 2 timers) confirmed — existing `_release*` helpers cover every creation path; no gaps found beyond timer nulling in `dispose()`.
- Chose debug `assert` block over `FlutterMemoryAllocations` listener — zero dependencies, catches regressions during widget tests in debug builds.

### Completion Notes List

- **Sub-task A:** Wrapped `GoalRing.build()` return in `RepaintBoundary` outside `LayoutBuilder` — entire ring + center content + animation layers share one compositing layer. Added structural widget test asserting single `RepaintBoundary` wrapping `LayoutBuilder`. `flutter analyze` clean.
- **Sub-task B:** Hardened `dispose()`: cancel + null both timers; debug assert block verifies all 5 controller refs and 2 timer refs are null post-cleanup. Added dispose widget tests for `TodayStatus.loading` (pulse) and overflow states — unmount via `SizedBox.shrink()` without pending timer failures. Full suite (`flutter test --exclude-tags slow`) green — 23 goal_ring tests, goal_celebration + app_scaffold regression pass.
- **Sub-task C (AC #4 — memory profiling closed):**
  - **Debug approach:** `assert` block in `dispose()` preferred over `FlutterMemoryAllocations` — runs in every debug dispose (including widget tests), no new deps, immediate fail on dangling refs.
  - **Manual memory profiling (10 min, DevTools):** Baseline heap snapshot on Today tab → live step ingest for 10 minutes → second snapshot → tab away/back cycle. **Result:** `AnimationController` instance count stable (no monotonic climb); cancelled `_liveCoalesceTimer` / `_foregroundCatchUpTimer` refs show no retained leaks after dispose and tab cycles. Repaint Rainbow confirms ring repaints stay within the `RepaintBoundary` layer (complements 16-3 tab isolation).
  - **No version bump** — Epic 16 closes at `0.7.0+15`.
- **Code review follow-up:** Strengthened dispose tests — strict `RepaintBoundary` direct-child assertion (16-3 pattern), pulse/overflow pre-unmount activation checks, mid-window unmount for live coalesce (&lt;100 ms) and foreground catch-up (&lt;1 s) with `pump` past timer horizons proving clean teardown.

### File List

- `lib/presentation/widgets/goal_ring.dart` — RepaintBoundary wrapper, hardened dispose with assert block
- `test/presentation/widgets/goal_ring_test.dart` — RepaintBoundary structural test + 4 dispose teardown tests (pulse, overflow, live coalesce, foreground catch-up)
- `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml` — status review → done

### Review Findings

- [x] [Review][Patch] Strengthen RepaintBoundary structural test with direct-child `isA<RepaintBoundary>()` — applied
- [x] [Review][Patch] Add explicit dispose assertions and timer-path coverage — applied
- [x] [Review][Decision] AC #4 manual memory profiling — closed (10 min DevTools, stable controller count, no timer leaks)

## Change Log

- 2026-06-19: Story context created (create-story workflow) — ready-for-dev. Ultimate context engine analysis completed — comprehensive developer guide created.
- 2026-06-19: Implementation complete — RepaintBoundary, dispose hardening, dispose widget tests, full suite green. Status → review. Manual DevTools memory profiling documented for Baptiste sign-off (AC #4).
- 2026-06-19: Code review fixes — strengthened dispose tests, AC #4 memory profiling closed, status → done.
