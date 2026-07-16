# Story 22.2: Disable Goal CTA During Today Loading States

Status: done

<!-- Post-audit Epic 22 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 22-2 · diagnostic-etat-chargement.md §3.1 · AUD-17 -->
<!-- Prerequisite: Story 22-1 — done -->
<!-- Version bump: deferred to Epic 22 close (patch+1, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want the “set goal” control disabled until Today data is ready,
So that I cannot open the goal editor on a ghost/loading ring.

## Acceptance Criteria

1. **Given** `TodayStatus.loading` **or** `lastDisplayedStepsLoaded == false`
   **When** Today goal action is rendered
   **Then** the CTA is disabled / non-interactive (AUD-17)
   **And** semantics reflect disabled state if exposed as a button

2. **Given** Today is ready with `lastDisplayedStepsLoaded == true` and status is not `loading`
   **When** user taps the goal action
   **Then** existing editor sheet behaviour is unchanged (`todayEditableGoal` → `showGoalEditorSheet` → `updateDailyStepGoal`)

3. **Given** a live step tick while Today is display-ready
   **When** only `steps` / `activityMetrics` change
   **Then** the Set goal slot does **not** rebuild (Story 16-5 build-isolation contract preserved)

4. **Given** day switch (`selectLocalDay`) or explicit refresh (`refresh(silent: false)`)
   **When** cubit emits `TodayStatus.loading` or `lastDisplayedStepsLoaded: false`
   **Then** CTA disables until display prefs + snapshot resolve and cubit emits ready state

5. **Given** existing Today widget / smoke tests
   **When** this story ships
   **Then** new tests cover disabled + enabled paths
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-17 · diagnostic-etat-chargement.md §3.1 (ghost state #1)

**Depends on:** Story 22-1 — **done** · Epic 21 cold-start / display-truth model — **done**

**Out of scope:** Rich semantic button label (Epic 23 / AUD-25 Story 23-1), converting CTA to `AstraButton`, disabling week day picker or scroll during loading, `TodayStatus.noPermission` gating (not in AC), version bump until Epic 22 closes.

## Tasks / Subtasks

- [x] **Sub-task A — Gate Set goal CTA on display-ready state** (AC: #1, #2, #3)
  - [x] Read fully: `lib/presentation/screens/today_screen.dart` — `_GoalRingCard` Set goal block (L516–545), `_onSetGoalTapped` (L551+)
  - [x] Read: `lib/presentation/widgets/goal_ring.dart` — `_isLoadingPlaceholder` (L558–560) — **reuse same predicate inverted**
  - [x] Add `@visibleForTesting bool todaySetGoalEnabled(TodayState state)`:
    ```dart
    state.status != TodayStatus.loading && state.lastDisplayedStepsLoaded
    ```
  - [x] Add minimal `_SetGoalViewModel { bool enabled }` + `fromState` + `@visibleForTesting todaySetGoalSelectorSlice`
  - [x] Replace static `Builder` with `BlocSelector<TodayCubit, TodayState, _SetGoalViewModel>` — selector must **not** include `steps`, `goal`, or `activityMetrics`
  - [x] When disabled:
    - `AstraPressable(enabled: false)`
    - `InkWell(onTap: null)` (no ripple / no tap)
    - Label style uses `colors.textMuted` (match `AstraButton` disabled secondary/ghost)
    - Wrap with `Semantics(button: true, enabled: vm.enabled, label: l10n.todaySetGoalLabel)`
  - [x] Defense in depth: early return in `_onSetGoalTapped` if `!todaySetGoalEnabled(cubit.state)`
  - [x] Keep `_probeSectionBuild('staticSetGoal')` probe name unchanged for existing build-isolation tests
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Widget tests for disabled / enabled CTA** (AC: #1, #2, #4, #5)
  - [x] Extend `test/presentation/screens/today_screen_selector_test.dart` (preferred — already has `staticSetGoal` probe + seeded cubit helpers)
  - [x] Test: `TodayStatus.loading` → tap `Set goal` → `showGoalEditorSheet` **not** invoked (mock navigator or verify no bottom sheet)
  - [x] Test: `lastDisplayedStepsLoaded: false` with non-loading status → tap blocked
  - [x] Test: display-ready state → CTA tappable (optional smoke if sheet mock is heavy)
  - [x] Test: selector slice unchanged when only `steps` ticks (reuse build-isolation pattern from existing group)
  - [x] Unit test: `todaySetGoalEnabled` pure function cases
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Regression** (AC: #5)
  - [x] Run: `flutter test test/presentation/screens/today_screen_selector_test.dart`
  - [x] Run: `flutter test test/presentation/screens/screen_smoke_test.dart`
  - [x] Run: `flutter test test/presentation/widgets/goal_ring_test.dart`
  - [x] Run: `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Disable Set goal pill during loading / prefs-not-loaded | AUD-25 semantic button label polish (Epic 23) |
| Minimal BlocSelector slice + disabled visuals | Refactor CTA to `AstraButton` |
| `@visibleForTesting` enable helper + tests | Disable week picker, ActivityStats, or scroll |
| Defense-in-depth guard in `_onSetGoalTapped` | Changing cubit loading emit semantics |

### Root cause (read before editing)

**Ghost interactive CTA while ring is in skeleton state:**

Diagnostic §3.1 item #1: the “Set goal” pill stays tappable during `TodayStatus.loading` or `lastDisplayedStepsLoaded == false`; it opens the editor with `todayEditableGoal` (async fetch) while GoalRing shows skeleton [Source: diagnostic-etat-chargement.md L81].

**Current implementation — always interactive:**

```516:545:lib/presentation/screens/today_screen.dart
          Builder(
            builder: (context) {
              _probeSectionBuild('staticSetGoal');
              // ...
                    child: InkWell(
                      onTap: () => _onSetGoalTapped(context),
```

**GoalRing already treats the same condition as loading placeholder:**

```558:560:lib/presentation/widgets/goal_ring.dart
  bool get _isLoadingPlaceholder =>
      widget.state.status == TodayStatus.loading ||
      !widget.state.lastDisplayedStepsLoaded;
```

**Cubit gating (display truth) — Set goal must align:**

| Path | Cubit behaviour | CTA should be |
|------|-----------------|---------------|
| Cold start | `TodayState.loading()` until steps + `getLastDisplayedSteps` resolve | Disabled |
| `selectLocalDay` | Emits `loading` + `lastDisplayedStepsLoaded: false` (L770–776) | Disabled until `_applySelectedDayDisplay` completes |
| `refresh(silent: false)` | Emits `TodayStatus.loading` | Disabled |
| `syncSteps` while `!lastDisplayedStepsLoaded` | Returns early — UI stays loading (L384–396) | Disabled |
| Silent metadata refresh | Status stays non-loading, `lastDisplayedStepsLoaded` stays true | **Enabled** |
| Live step tick (ready) | Steps/metrics update only | **Enabled** — selector must not rebuild |

### Target implementation (guidance)

**Enable predicate (single source of truth for UI + tap guard):**

```dart
@visibleForTesting
bool todaySetGoalEnabled(TodayState state) =>
    state.status != TodayStatus.loading && state.lastDisplayedStepsLoaded;
```

**BlocSelector slice** — only `status` + `lastDisplayedStepsLoaded` (mirror `_SetGoalViewModel`). Do **not** fold into `_GoalRingViewModel` — that slice includes `steps` and would rebuild the CTA on every live tick, breaking Story 16-5 isolation.

**Disabled visuals (match existing design system):**

- `AstraPressable(enabled: vm.enabled)` — suppresses press scale [Source: astra_pressable.dart]
- `InkWell(onTap: vm.enabled ? () => _onSetGoalTapped(context) : null)` — Material disabled ripple behaviour
- Text color: `AstraTypography.labelFor(colors).copyWith(color: vm.enabled ? null : colors.textMuted)` — same muted pattern as `AstraButton` disabled states

**Semantics (AC #1 minimal — full label deferred to 23-1):**

```dart
Semantics(
  button: true,
  enabled: vm.enabled,
  label: l10n.todaySetGoalLabel,
  child: /* existing pill */,
)
```

Do **not** add `ExcludeSemantics` — Epic 23 will enrich the label.

### Regression cautions

| Risk | Mitigation |
|------|------------|
| Set goal rebuilds on every step tick | Selector excludes `steps` / metrics; verify with `staticSetGoal` probe counts |
| CTA stays disabled after day switch | Assert re-enables when cubit sets `lastDisplayedStepsLoaded: true` |
| Tap still opens sheet via accessibility / programmatic invoke | Guard inside `_onSetGoalTapped` |
| `noPermission` state | AC does not require disable — user may still set goal without sensor; keep enabled if display-ready |
| Smoke test finds label but cannot tap | `screen_smoke_test` only asserts visibility — should still pass |

### Architecture compliance

- **Display Truth Model:** Align CTA with GoalRing loading gate — do not change cubit emit rules [Source: Epic 21 / Story 16-7].
- **BlocSelector isolation:** Follow `_WeekProgressViewModel` / `_ActivityStatsViewModel` pattern in `today_screen.dart` [Source: Story 16-5].
- **Set goal contract unchanged:** Still edits **today's** goal via `todayEditableGoal` when viewing past days [Source: Story 11-3].
- **OK-commit gate:** One commit per sub-task [Source: docs/project-context.md].

### Project structure notes

| Path | Role |
|------|------|
| `lib/presentation/screens/today_screen.dart` | **UPDATE** — `_SetGoalViewModel`, BlocSelector, disabled UI, tap guard, `todaySetGoalEnabled` |
| `lib/presentation/widgets/goal_ring.dart` | **READ** — `_isLoadingPlaceholder` predicate reference only |
| `lib/presentation/cubits/today_cubit.dart` | **READ** — loading / day-switch emit paths; no changes expected |
| `lib/presentation/cubits/today_state.dart` | **READ** — `TodayStatus`, `lastDisplayedStepsLoaded` |
| `test/presentation/screens/today_screen_selector_test.dart` | **UPDATE** — disabled/enabled + selector isolation tests |
| `test/presentation/screens/screen_smoke_test.dart` | **READ** — regression |
| `_bmad-output/planning-artifacts/audits/diagnostic-etat-chargement.md` | **READ** — §3.1 ghost state #1 |

### Testing requirements

- **Primary:** `flutter test test/presentation/screens/today_screen_selector_test.dart`
- **Regression:** `screen_smoke_test.dart`, `goal_ring_test.dart`
- **Full:** `flutter test --exclude-tags slow`

**Suggested pure test:**

```dart
test('todaySetGoalEnabled false during loading', () {
  expect(
    todaySetGoalEnabled(
      TodayState.fromData(steps: 0, goal: 8000, isStale: false)
          .copyWith(status: TodayStatus.loading),
    ),
    isFalse,
  );
});

test('todaySetGoalEnabled false when lastDisplayedStepsLoaded false', () {
  expect(
    todaySetGoalEnabled(
      TodayState.fromData(steps: 100, goal: 8000, isStale: false)
          .copyWith(lastDisplayedStepsLoaded: false),
    ),
    isFalse,
  );
});
```

**Suggested widget test pattern (disabled tap):**

Seed `_SeededTodayCubit` with loading state → pump `TodayScreen` → `await tester.tap(find.text('Set goal'))` → `await tester.pumpAndSettle()` → expect no `GoalEditorSheet` / no route pushed.

### Previous story intelligence (22-1)

- **Tracker:** Use `sprint-status-post-audit.yaml`, not legacy `sprint-status.yaml`.
- **Scope discipline:** UI-only gate — no cubit refactor (contrast with 22-1 service hardening).
- **Test rigor:** Focused widget/unit tests + full suite gate.
- **Commit pattern:** `fix(today-ui):` or `fix(robustness):` prefix; sub-task OK-commit gate.
- **22-1 done:** LiveStepMonitor dispose hardened — unrelated to Today CTA; do not touch monitor in this story.

### Git intelligence

Recent commits:
- `eca8d21` — `fix(live-pipeline): harden LiveStepMonitor dispose sequencing (story 22-1)`
- Epic 21 close commits — coordinator/cold-start performance only

Pattern: small targeted diff + focused tests; story reference in commit message.

### Latest tech notes

- **Flutter `InkWell(onTap: null)`** — standard disabled pattern; pairs with `AstraPressable(enabled: false)`.
- **Semantics `enabled: false`** — screen readers skip activation; satisfies AC #1 until Story 23-1 adds richer label.
- **No new packages.**

### Project context reference

- OK-commit gate: sub-task → review brief → Baptiste OK → commit
- Tests: `flutter test --exclude-tags slow`
- Commit example: `fix(today-ui): disable Set goal CTA during Today loading (story 22-2)`
- Version bump: Epic 22 close only (`patch+1, build+1`)

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` — Story 22-2, AUD-17, Epic 22]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-etat-chargement.md` — §3.1 ghost state #1]
- [Source: `_bmad-output/implementation-artifacts/stories/22-1-harden-live-step-monitor-dispose-sequencing.md` — epic patterns]
- [Source: `_bmad-output/implementation-artifacts/stories/16-7-cold-start-loading-shimmer-for-today.md` — loading + lastDisplayedStepsLoaded gating]
- [Source: `_bmad-output/implementation-artifacts/stories/11-3-selected-day-indicators-and-live-guards.md` — Set goal today contract]
- [Source: `lib/presentation/screens/today_screen.dart`]
- [Source: `lib/presentation/widgets/goal_ring.dart`]
- [Source: `lib/presentation/cubits/today_cubit.dart` — selectLocalDay, syncSteps, _applyTodaySnapshot]
- [Source: `docs/project-context.md`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- `todaySetGoalEnabled` mirrors GoalRing `_isLoadingPlaceholder` inverted
- BlocSelector slice excludes steps/metrics — Story 16-5 isolation preserved
- Widget tap tests use `ensureVisible` + `pump` (GoalRing loading animations block `pumpAndSettle`)

### Completion Notes List

- Sub-task A: `_SetGoalViewModel` + BlocSelector gate Set goal CTA on display-ready; disabled visuals + Semantics; tap guard in `_onSetGoalTapped`
- Sub-task B: 7 unit + 5 widget tests in `today_screen_selector_test.dart` (disabled tap, slice isolation, loading rebuild)
- Sub-task C: selector/smoke/goal_ring + full `flutter test --exclude-tags slow` — all green
- Code review: async re-check after `todayEditableGoal`; enabled-path widget test (`_InstantGoalCubit`)

### File List

- `lib/presentation/screens/today_screen.dart`
- `test/presentation/screens/today_screen_selector_test.dart`
- `_bmad-output/implementation-artifacts/stories/22-2-disable-goal-cta-during-today-loading-states.md`
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`

## Change Log

- 2026-07-16: Story context created (ready-for-dev) — ultimate context engine analysis completed
- 2026-07-17: Implemented Set goal CTA loading gate (AUD-17) — status review
- 2026-07-17: Code review fixes + marked done
