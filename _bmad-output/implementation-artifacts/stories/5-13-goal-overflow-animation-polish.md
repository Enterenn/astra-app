# Story 5.13: Today Motion Polish (Celebration · Count-Up · Overflow)

Status: done

<!-- Scope expanded 2026-06-05 per Baptiste: richer goal celebration, animated step count + ring sync, overflow ambient. Replaces narrow overflow-only brief. -->

## Story

As a **user**,
I want Today to feel alive and rewarding when I open the app and reach my goals,
So that my progress is acknowledged with satisfying motion without gamified pressure.

## Acceptance Criteria

### A — Enhanced goal celebration (rewarding tier — Baptiste 2026-06-05)

1. **Given** today's steps first cross `daily_step_goal` and celebration plays (Story 2.6 dedup unchanged)
   **When** `GoalCelebration` runs with animations enabled
   **Then** the sequence feels distinctly more rewarding than today:
   - Ring scale pulse **1.0 → 1.08 → 1.0** (single smooth sin bump ~720ms — Baptiste device pass 2026-06-05)
   - Glow halo peak **~30%** opacity (up from 18%), blur 28dp
   - **Arc completion sweep**: ring draws from current progress to 360° over ~400ms at sequence start (synced with count if mid-animation)
   - Total sequence **~4s** (up from 2.5s); micro-copy holds slightly longer
   - Haptic: `lightImpact` @ ~260ms (Android); iOS `mediumImpact` — single tap (Baptiste device pass 2026-06-05)
   **And** once-per-day dedup via `celebration_shown_date` is unchanged (V-6)

2. **Given** reduce-motion enabled
   **When** celebration triggers
   **Then** static full ring + micro-copy fade only (no scale/glow/pulse loops) — unchanged contract

3. **Given** celebration intensity upgrade
   **When** implemented
   **Then** a **moderate** radial particle burst (~45 specks, no confetti) may accompany celebration — Baptiste approved 2026-06-05
   **And** still **no** confetti, sound, streak badge, coach copy, or modal overlay (UX guardrails)

### B — Animated step count + ring sync (Baptiste 2026-06-05)

4. **Given** user opens Today on **cold start** (first load of session when `TodayState` transitions from `loading` to data)
   **When** persisted steps are available (e.g. 1024) and last displayed count was lower (e.g. 470)
   **Then** center count animates via **ease-in-out count-up** from **470 → 1024** (actual previous value, not a computed offset)
   **And** the progress arc **fills in sync** from matching start ratio to target ratio (same controller, same `Curves.easeInOut`)
   **And** duration scales with delta: `clamp(600ms, delta * 1.5ms, 1800ms)` — e.g. 470→1024 ≈ 1.1s

5. **Given** user **returns to Today tab** after visiting another tab (same session)
   **When** steps increased since last displayed value (e.g. was 1024, now 1087)
   **Then** ease-in-out count-up animates **only the delta** (1024→1087, ~100ms minimum) with arc sync (`Curves.easeInOut`)
   **And** switching tabs does **not** replay full cold-start animation

6. **Given** user stays on Today and **live steps** increment (+1 to +N via `LiveStepMonitor`)
   **When** each update arrives
   **Then** a **micro-tick** plays on changed digits (subtle 4–6px vertical slide + fade, ~150ms, `Curves.easeOut`) — not a full count-up restart
   **And** arc advances smoothly to match (short 150–300ms tween per update batch, `Curves.easeOut`)

7. **Given** step count animation style (Baptiste deferred to dev recommendation)
   **When** implemented
   **Then** use **ease-in-out integer count-up** (`Curves.easeInOut` on shared controller) as primary — works with `formatStepCount` thin-space grouping
   **And** arc progress uses the **same controller + curve** so ring and number move together visually
   **And** live micro-ticks use **`Curves.easeOut`** (short settle, separate from count-up curve)
   **And** micro-tick uses per-digit vertical clip on **changed digit positions only** (lightweight odometer feel without full slot-machine widget)
   **And** do **not** add a new package; pure Flutter `AnimationController` / `Tween<int>`

8. **Given** count-up start value (Baptiste 2026-06-05 — no computed offset)
   **When** animation begins (cold start or tab return)
   **Then** start from **`lastDisplayedSteps`** — the step count the user actually saw last on Today, not a formula
   **And** example: user last saw **470**, DB now has **1024** → animate **470 → 1024**
   **And** if `lastDisplayedSteps == targetSteps` → skip animation (instant render)
   **And** if no stored value for current local day (first open ever / new day / post-purge) → start from **0** → target with same `Curves.easeInOut`

9. **Given** reduce-motion enabled
   **When** any count/arc animation would play
   **Then** show final values instantly — no count-up, no micro-tick

10. **Given** semantics (UX §4.3)
    **When** count is mid-animation
    **Then** `Semantics` label reports **target** step count (not intermediate frames) to avoid TalkBack spam

### C — Overflow ambient (original 5.13 scope)

11. **Given** `TodayStatus.overflow` after celebration dismissed
    **When** user views Today
    **Then** full ring shows calm ambient shimmer/pulse loop (distinct from celebration burst)
    **And** center count continues live updates with micro-tick (AC #6)

12. **Given** reduce-motion + overflow
    **When** steps exceed goal
    **Then** static full ring; optional factual micro-copy; no loops

13. **Given** `TodayStatus.goalMet` exactly (not overflow)
    **When** celebration finished
    **Then** no overflow ambient loop — static full arc

### D — Debug celebration preview (temporary — Baptiste 2026-06-05)

14. **Given** `kDebugMode` build and user on Today
    **When** a **Preview goal** chip is shown beside **Set goal**
    **Then** tapping it triggers `GoalCelebration` immediately — no need to walk steps to goal
    **And** the button is **replayable unlimited times** (each tap remounts a fresh celebration sequence)
    **And** `celebration_shown_date` pref is **not** written or consumed by preview (production dedup unchanged)

15. **Given** real steps are below `daily_step_goal` when preview is tapped
    **When** celebration renders
    **Then** display uses a **visual-only** full-ring state (steps ≥ goal for the widget) without mutating cubit truth (`state.steps` unchanged after dismiss)

16. **Given** celebration polish is signed off on device
    **When** story is closed
    **Then** remove preview button, `previewCelebration()`, `celebrationPreviewNonce`, and related tests — **not shipped in release** (`kDebugMode` guard during dev)

### E — Quality gate

17. **Given** implementation complete
    **When** `flutter analyze` and `flutter test` run
    **Then** no regressions; celebration once/day; no layout jump on sync refresh (V-5)

18. **Given** token compliance (V-2)
    **When** motion widgets updated
    **Then** no ad-hoc hex in `lib/presentation/`; shared painters in `goal_ring_effects.dart` if extracted

**Depends on:** Stories 2.6, 2.5, 2.9 (live steps), 5.12.  
**Stretch (implement only if time after A–F):** see §Stretch goals below.  
**Out of scope:** Confetti, sounds, streaks, second ring lap, notification/cubit dedup changes, Epic 6 stats values, History chart bar-grow (KPI-01 risk).

---

## Tasks / Subtasks

- [x] **A — `AnimatedStepCount` + arc sync** (AC: #4–#10)
  - [x] Add `lib/presentation/widgets/animated_step_count.dart` — owns displayed int, cold-start count-up, tab-return delta, micro-tick on live +1
  - [x] Track `lastDisplayedSteps` in widget state **and** persist to `user_preferences` (`last_displayed_steps` + `last_displayed_steps_local_day`) so cold start resumes from actual last seen count (e.g. 470), not session memory only
  - [x] Write pref when animation completes and on Today dispose/background (same local day only)
  - [x] Shared `AnimationController` with `Curves.easeInOut` drives **both** `Tween<int>` count and arc `progressRatio`; micro-ticks use `Curves.easeOut`
  - [x] Wire `GoalRingPainter` progress from animated ratio, not raw `state.progressRatio`, during active tween
  - [x] Cold-start detect: first non-loading emit with `steps > 0` or any transition from `loading`
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **B — Debug preview button (temporary)** (AC: #14–#16) — **do first** so Baptiste can iterate on celebration feel
  - [x] `today_screen.dart`: beside **Set goal**, add **Preview goal** chip in `kDebugMode` only (`Wrap` or `Row`)
  - [x] `TodayCubit.previewCelebration()` — sets `showCelebration: true`, increments `celebrationPreviewNonce`; **does not** call `tryClaimCelebrationShownDate`
  - [x] `GoalCelebration(key: ValueKey(nonce), …)` so each tap remounts animation mid-sequence
  - [x] `_celebrationDisplayState(state)` in screen — if `steps < goal`, pass visual-only `goalMet` state to widget; cubit truth unchanged
  - [x] ~~`today_screen_test.dart`~~ — preview tap test removed with screen smoke consolidation (2026-06-05); `goal_ring_test.dart` covers celebration widget
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **C — Enhanced `GoalCelebration`** (AC: #1–#3)
  - [x] Bump `_kCelebrationSequenceMs` to ~4000; implement double pulse + stronger glow + arc sweep at t=0
  - [x] Second haptic at ~1200ms; update `goal_celebration_test.dart` durations/assertions
  - [x] Extract shared shimmer/sweep painters to `goal_ring_effects.dart` for reuse with overflow
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **D — Overflow ambient** (AC: #11–#13)
  - [x] Slow shimmer loop on full ring when `overflow && !showCelebration`
  - [x] Reduce-motion static variant
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **E — Integration + edge cases** (AC: #4–#6, #17)
  - [x] `today_screen.dart`: ensure celebration path still swaps widget correctly; animated count pauses/resumes across celebration handoff
  - [x] During `GoalCelebration`, count shows target (celebration owns ring); after dismiss, animated count resumes from celebration value
  - [x] Silent refresh / 60s periodic refresh: **no** full count-up replay (only delta if steps changed)
  - [x] Purge → 0 steps: instant reset, no count-up from old value
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **F — Tests** (AC: #17–#18)
  - [x] `animated_step_count_test.dart` — cold start, delta, reduce motion, semantics target value
  - [x] Update `goal_ring_test.dart`, `goal_celebration_test.dart`
  - [x] `flutter analyze` + `flutter test`
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **G — UX spec update** (AC: #1, #11)
  - [x] Update `ux-design-specification.md` §2.3.1 celebration table + §2.3 overflow row + new §2.3.2 step count motion
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **H — Remove debug preview** (AC: #16) — **last sub-task before story done**
  - [x] Delete **Preview goal** chip, `previewCelebration()`, `celebrationPreviewNonce`, `kPreviewGoalCelebrationLabel`, preview tests
  - [x] Grep cleanup: no `previewCelebration` / `Preview goal` left in `lib/` or `test/`
  - [x] **Stop → review brief → Baptiste OK → commit**

---

## Dev Notes

### Product intent — scope expansion (Baptiste 2026-06-05)

Original 5.13 covered overflow ambient only. Baptiste wants Today to feel **more alive**:

| Pillar | User ask | Story response |
|--------|----------|----------------|
| Celebration | Too subtle, not rewarding enough | **Rewarding tier**: scale 1.10, double pulse, arc sweep, ~4s, dual haptic |
| Step count | Count-up or odometer on app open | **Count-up primary** + digit micro-tick on live; arc synced |
| Overflow | Static after goal | Ambient shimmer (original AC) |
| Dev preview | Test celebration without walking | **Preview goal** button, `kDebugMode`, removed at story close |
| Particles | Maybe later | **Out of scope** until celebration baseline ships — evaluate after device pass |
| App-wide | More life | Stretch goals below — not blocking |

**Tone shift:** Still no gamification (no confetti/streaks/coach copy), but motion can be **more expressive** than UX §2.3.1 original "calm" spec. Task F updates UX doc to match.

### Current animation inventory (audit)

| Surface | Today | Opportunity |
|---------|-------|-------------|
| `GoalRing` center count | Instant `Text(formatStepCount(steps))` | **AC B** — main win |
| `GoalRing` arc | Instant `CustomPaint` progress | **AC B** — sync with count |
| `GoalCelebration` | 2.5s, scale 1.05, glow 18% | **AC A** — enhance |
| `GoalRing` loading | Track opacity pulse only | Keep as-is |
| `GoalRing` overflow | Static (same as goalMet) | **AC C** |
| Tab switch | 200ms `AnimatedSwitcher` crossfade | Stretch: subtle slide |
| `WeekProgressRow` pills | Static | Stretch: today pill entrance |
| `ActivityStatsRow` | Static placeholders | Defer to Epic 6 |
| `HistoryScreen` chart | Instant bind (<100ms KPI-01) | **Do not** bar-grow in 5.13 |
| `PeriodToggle` / `ThemeSelector` | `AnimatedContainer` 200ms | OK |

### Recommended count-up vs odometer (Baptiste: "unsure")

**Primary: `Tween<int>` count-up with `Curves.easeInOut`** — recommended because:
- Works with `formatStepCount` thin-space (`10 847`) without per-digit slot complexity
- Syncs trivially with arc `progressRatio` on one controller
- Performant for live +1 updates (micro-tick on changed digits only)

**Micro-tick (live updates):** For +3 steps `1021→1024`, only last digit column animates a 4–6px vertical clip — gives odometer *feel* without full slot machine.

**Rejected for Phase 0:** Full odometer widget for every frame — heavy, fights locale formatting, overkill for +1 steps.

### Cold start vs tab return vs live (Baptiste: both)

```text
Session start → Today first paint (loading→data)
  → read lastDisplayedSteps from pref (same local day) — e.g. 470
  → easeInOut count-up 470 → 1024 + arc sync (600–1800ms, Curves.easeInOut)

User on Trends, steps accumulate → return Today
  → easeInOut delta lastDisplayed → newSteps (min 100ms)

User on Today, live monitor +1
  → micro-tick 150ms on changed digits + short arc bump (Curves.easeOut)
```

**Start value rule (Baptiste 2026-06-05):** Always `lastDisplayedSteps` — the real previous count the user saw. **Never** a computed offset like `target - 500`.

**Persistence:** `last_displayed_steps` + `last_displayed_steps_local_day` in `user_preferences` (new keys, no migration — key/value table). Purge clears or resets on new local day. Cubit still owns truth (`state.steps`); widget owns displayed animation layer.

**Easing (Baptiste confirmed easeInOut):** `Curves.easeInOut` on count-up and arc — slow start, mid acceleration, soft landing on final value. `Curves.easeOut` on live micro-ticks (~150ms).

### Enhanced celebration spec (rewarding tier)

| Layer | Current (2.6) | Target (5.13) |
|-------|---------------|---------------|
| Duration | 2500ms | **4000ms** |
| Ring scale | 1.0→1.05→1.0 once | **1.0→1.10→1.0** + second **1.0→1.04→1.0** at t≈1.2s |
| Glow peak | 18%, blur 24 | **30%**, blur **28** |
| Arc sweep | Instant full at goal | **Animate** remaining arc to 360° in first 400ms |
| Haptic | 1× light @300ms | **2×** light @300ms + @1200ms |
| Micro-copy | 2.5s fade | Hold to **3.5s** total visibility |

### Celebration ↔ count animation handoff

```text
Goal crossed → GoalCelebration plays (owns ring stack)
  → onComplete → dismissCelebration()
  → GoalRing resumes; lastDisplayedSteps = celebration steps
  → if overflow: ambient shimmer starts
  → live +1: micro-tick resumes
```

Do **not** run cold-start count-up underneath active celebration.

### Debug preview button (temporary — Task B)

**Purpose:** Baptiste tunes celebration feel without walking to goal. **Not** a product feature.

```dart
// TodayCubit — does NOT touch celebration_shown_date
void previewCelebration() {
  emit(state.copyWith(
    showCelebration: true,
    celebrationPreviewNonce: state.celebrationPreviewNonce + 1,
  ));
}

// today_screen.dart — kDebugMode only
Wrap(
  children: [
    _GoalActionChip(label: 'Set goal', …),
    if (kDebugMode)
      _GoalActionChip(
        label: 'Preview goal',
        onTap: cubit.previewCelebration,
      ),
  ],
)

// Remount on each tap
GoalCelebration(
  key: ValueKey(state.celebrationPreviewNonce),
  state: _celebrationDisplayState(state), // visual full ring if steps < goal
  onComplete: () => cubit.dismissCelebration(),
)
```

**Removal (Task H):** Strip all preview code when animation signed off — release builds never include it (`kDebugMode` is sufficient guard during development).

### Current code state (READ before editing)

| File | Change |
|------|--------|
| `goal_ring.dart` | Integrate `AnimatedStepCount`; animated arc progress; overflow loop; `TickerProviderStateMixin` |
| `goal_celebration.dart` | Enhanced sequence; extract painters |
| `goal_ring_effects.dart` | **NEW** — shared shimmer, arc sweep painters |
| `animated_step_count.dart` | **NEW** — count-up + micro-tick |
| `today_screen.dart` | Preview chip (Task B) + celebration wrapper; remove preview (Task H) |
| `today_cubit.dart` | Add `previewCelebration()` + nonce (Task B); remove (Task H); celebration dedup unchanged |
| `today_state.dart` | Add `celebrationPreviewNonce` (Task B); remove (Task H) |
| `user_preferences_repository.dart` | **UPDATE** — `last_displayed_steps` get/set scoped to local day |
| `preference_keys.dart` | **UPDATE** — new keys for last displayed steps |
| `step_count_formatter.dart` | Add `digitSegments(int)` helper for micro-tick diff (optional) |

### Architecture compliance

- Presentation + **minimal pref** for `last_displayed_steps` (same pattern as `celebration_shown_date`); no SQLite schema migration
- No new packages
- Semantics: announce **target** value, not intermediate frames
- V-5: no layout jump — `FittedBox` on count preserved; animate inside fixed box
- Review-before-commit per sub-task ([Source: `docs/project-context.md`])

### Stretch goals (non-blocking)

Implement only if A–F complete early:

| # | Idea | Effort | Notes |
|---|------|--------|-------|
| S1 | Today pill scale-in when week row loads | Low | `WeekProgressRow` today `AnimatedScale` 0.95→1.0 |
| S2 | Tab crossfade + 8px horizontal slide | Low | `app_scaffold.dart` `AnimatedSwitcher` transitionBuilder |
| S3 | `ElevatedCard` subtle accent border flash on goal cross | Medium | Only during celebration |
| S4 | Set goal button success ripple after save | Low | Existing `InkWell` |

**Explicitly defer:** History bar grow, confetti, sounds, stats row count-up (Epic 6).

### Testing requirements

| Test | Assert |
|------|--------|
| `animated_step_count_test` | Cold start animates; reduce motion instant; semantics = target |
| `goal_ring_test` | Arc progress follows tween; overflow shimmer when enabled |
| `goal_celebration_test` | ~4s duration; double scale peak; glow present; reduce motion unchanged |
| `today_cubit_test` | **No changes** to celebration dedup |
| `goal_ring_test` | Celebration overlay behavior (screen preview test removed in Phase B cleanup) |
| Manual device | **Preview goal** replays celebration; cold start count-up; tab return delta; overflow shimmer; reduce motion all static |

### Previous story intelligence

- **5.12:** V-5 no layout jump; V-6 celebration once/day — preserve dedup
- **2.6:** `tryClaimCelebrationShownDate` — do not alter
- **2.9:** Monotonic steps in cubit; live monitor replays on attach — micro-tick must handle burst updates (coalesce within 100ms window)

### Project context reference

- [Source: `docs/project-context.md`]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` §2.3, §2.3.1, §4.5]
- [Source: `_bmad-output/implementation-artifacts/stories/2-6-goal-celebration-animation.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/2-9-today-display-truth-model-and-live-overlay.md`]

---

## Dev Agent Record

### Agent Model Used

claude-4.6-sonnet-medium-thinking (Cursor Agent)

### Debug Log References

- Fixed sqflite pending-timer flakes in widget tests via `GoalRing.disableStepPersistence` test flag and skipping pref load when disabled.
- `tabReturnDurationMs` uses 100ms floor (distinct from cold-start 600ms floor).

### Completion Notes List

- ✅ **AnimatedStepCount + GoalRing sync:** easeInOut count-up from `last_displayed_steps` pref; arc progress synced on shared controller; live +1 uses easeOut micro-tick per changed digit.
- ✅ **GoalCelebration rewarding tier:** ~4s sequence, double scale pulse (1.10 + 1.04), 30% glow blur 28dp, arc sweep 400ms, dual haptic at 300ms/1200ms.
- ✅ **Overflow ambient:** slow shimmer loop on full ring; static when reduce motion.
- ✅ **Debug preview:** implemented during dev (Task B), removed before story close (Task H) — not shipped.
- ✅ **UX spec:** §2.3.1, §2.3 overflow row, new §2.3.2 step count motion.
- ✅ **Tests:** 565 passing; `flutter analyze` clean (info-level only in unrelated files).

### File List

- `lib/core/constants/preference_keys.dart`
- `lib/data/repositories/user_preferences_repository.dart`
- `lib/presentation/formatters/step_count_formatter.dart`
- `lib/presentation/screens/today_screen.dart`
- `lib/presentation/widgets/animated_step_count.dart` (new)
- `lib/presentation/widgets/goal_celebration.dart`
- `lib/presentation/widgets/goal_ring.dart`
- `lib/presentation/widgets/goal_ring_effects.dart` (new)
- `test/presentation/screens/app_scaffold_test.dart`
- ~~`test/presentation/screens/today_screen_test.dart`~~ (merged into `screen_smoke_test.dart`, 2026-06-05)
- `test/presentation/widgets/animated_step_count_test.dart` (new)
- `test/presentation/widgets/goal_celebration_test.dart`
- `test/presentation/widgets/goal_ring_test.dart`
- `_bmad-output/planning-artifacts/ux-design-specification.md`

### Change Log

- 2026-06-05: Story 5.13 — Today motion polish (celebration rewarding tier, animated step count + arc sync, overflow ambient, UX spec update). Debug preview used during implementation then removed.

---

## Story completion status

- **Status:** done
- **Completion note:** Scope expanded per Baptiste 2026-06-05 — celebration rewarding tier (single pulse + moderate particles), easeInOut count-up from last displayed steps + arc sync, easeOut micro-ticks for live deltas ≤15 steps (count-up above), overflow ambient. Debug preview removed post-review (Task H).

### Review Findings (2026-06-05)

- [x] [Review][Patch] Remove debug preview code — removed `previewCelebration`, preview chip, nonce fields, tests
- [x] [Review][Decision] AC #3 particles — Baptiste approved moderate radial burst; AC updated
- [x] [Review][Patch] Cold-start count/arc flash — hold at 0 until prefs load; `_effectiveProgress` uses `_animatedProgress`
- [x] [Review][Decision] Celebration pulse/haptic spec — Baptiste confirmed single 1.08 bump + single haptic; AC #1 updated
- [x] [Review][Patch] Live step bursts — micro-tick ≤15 steps, count-up above (coalesced 100ms)
- [x] [Review][Patch] Purge clears `last_displayed_steps` — wired in `postPurgeRefresh`
- [x] [Review][Patch] Missing tests — overflow shimmer, cold-start progress, semantics during count-up
- [x] [Review][Patch] Micro-tick layout — always render segment row for consistent width
- [x] [Review][Patch] Dead `_pulseScale` helper — removed from `goal_celebration.dart`
