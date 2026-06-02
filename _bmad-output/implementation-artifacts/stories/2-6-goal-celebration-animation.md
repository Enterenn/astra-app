# Story 2.6: Goal Celebration Animation

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want a calm once-per-day celebration when I reach my step goal,
So that I feel acknowledged without gamified pressure.

## Acceptance Criteria

1. **Given** today's steps first cross `daily_step_goal` for the local calendar day
   **When** the user views Today (or deferred from background crossing while on another tab)
   **Then** `GoalCelebration` plays once: ring pulse, glow, shimmer per UX §2.3.1 (FR15, UX-DR6)
   **And** `celebration_shown_date` preference prevents repeat until next local day

2. **Given** reduce-motion OS setting enabled
   **When** celebration triggers
   **Then** static full ring + micro-copy fade only (no scale/glow animation)

3. **Given** goal already met earlier today (celebration already shown or `celebration_shown_date` set)
   **When** user reopens Today or switches back to the Today tab
   **Then** no celebration replay and no coach language toast

## Tasks / Subtasks

- [x] **Sub-task A — `celebration_shown_date` preference API** (AC: #1, #3)
  - [x] Add `kCelebrationShownDateKey = 'celebration_shown_date'` to `lib/core/constants/preference_keys.dart` (no DB migration — key/value table accepts new keys on first write).
  - [x] Add `UserPreferencesRepository.getCelebrationShownDate()` → `Future<String?>` and `setCelebrationShownDate(String localDayIso)` — sole writer rule unchanged.
  - [x] Add helper `formatLocalDayIso(TimeSnapshot snapshot)` in `lib/core/time/local_day_formatter.dart` (or inline in repo) producing `YYYY-MM-DD` from `TimeProvider.snapshot()` using device zone offset — **not** raw `DateTime.now()`.
  - [x] Unit tests in `test/data/repositories/user_preferences_repository_test.dart` — round-trip write/read; null when unset.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Celebration trigger in `TodayCubit`** (AC: #1, #3, deferred play)
  - [x] Extend `TodayState` with `bool showCelebration` (default `false`) — transient UI flag, not persisted.
  - [x] In `TodayCubit.refresh()` after computing steps/goal: if `steps >= goal && goal > 0`, read `getCelebrationShownDate()` and compare to today's local ISO via `clock.snapshot()`; when mismatch → emit state with `showCelebration: true` **and immediately** `setCelebrationShownDate(todayIso)` (persist before animation finishes to prevent double-fire on coalesced refresh).
  - [x] When pref already equals today → `showCelebration: false` even if `goalMet`/`overflow`.
  - [x] Add `void dismissCelebration()` on cubit to clear `showCelebration` after animation completes (micro-copy fade done).
  - [x] Tests in `test/presentation/cubits/today_cubit_test.dart`:
    - steps ≥ goal, pref unset → `showCelebration true`, pref written
    - steps ≥ goal, pref already today → `showCelebration false`
    - steps < goal → never show
    - overflow (steps > goal) same first-play semantics
    - permission denied / empty → no celebration
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — `GoalCelebration` widget** (AC: #1–#2, UX-DR6, UX-DR19)
  - [x] Add `lib/presentation/widgets/goal_celebration.dart` — composite overlay wrapping `GoalRing` in a `Stack`:
    - **Ring scale:** 1.0 → 1.05 → 1.0, 600ms, `Curves.easeOutCubic`
    - **Glow halo:** `color.accentPrimary` @ 0% → 18% → 0%, blur 24dp, behind ring, 800ms ease-out
    - **Stroke shimmer:** progress stroke opacity 1.0 → 1.25 → 1.0, 200–700ms ease-in-out (clip to arc, no hue shift)
    - **Center count scale (optional):** 1.0 → 1.02 → 1.0, 100–500ms
  - [x] **Reduce motion:** when `MediaQuery.disableAnimationsOf(context)` → skip scale/glow/shimmer; static full ring + micro-copy 500ms fade only.
  - [x] **Haptics:** `HapticFeedback.lightImpact()` at ~300ms peak on Android; optional `mediumImpact` on iOS if not conflicting (guard with `Platform.isAndroid` default).
  - [x] **Micro-copy:** below ring area — Figtree caption `color.textSecondary`: **"Daily goal reached"** — fade in ~500ms, hold, fade out by 2.5s total; no SnackBar, no modal, no coach copy.
  - [x] **Semantics:** outer `Semantics(liveRegion: true, label: 'Daily goal reached')` once; glow/shimmer layers `ExcludeSemantics`.
  - [x] `onComplete` callback when animation sequence finishes → cubit `dismissCelebration()`.
  - [x] Widget tests in `test/presentation/widgets/goal_celebration_test.dart` — reduce-motion path renders micro-copy without scale animation controller; decorative layers excluded from semantics tree.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — `TodayScreen` integration** (AC: #1–#3)
  - [x] Replace bare `GoalRing(state: state)` with celebration-aware wrapper:
    ```dart
    if (state.showCelebration)
      GoalCelebration(
        state: state,
        onComplete: () => context.read<TodayCubit>().dismissCelebration(),
      )
    else
      GoalRing(state: state),
    ```
  - [x] Celebration plays on **first Today visit** after goal crossed (including return from History tab) — trigger lives in cubit refresh on tab return (`AppScaffold` already calls `refresh()` when returning to Today).
  - [x] Do **not** replay on every 60s periodic refresh once pref set same day.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Verification** (AC: #1–#3)
  - [x] Run `flutter analyze` and `flutter test`.
  - [x] Manual: inject steps to cross goal → celebration plays once; leave tab and return → no replay; enable reduce motion in OS → static variant only.
  - [x] Review brief documents **deferred to 2.7**: `NotificationService`, background notification path writing same `celebration_shown_date`.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 2.6:**
- `GoalCelebration` composite widget (UX §2.3.1, UX-DR6)
- `celebration_shown_date` read/write via `UserPreferencesRepository`
- Trigger + dedup logic in `TodayCubit` (foreground / deferred Today visit)
- Reduce-motion variant, haptics, accessibility (`liveRegion`, decorative exclude)
- Micro-copy "Daily goal reached" (2s fade cycle)

**Out of scope — defer to later stories:**
- `NotificationService.showGoalReached()` → **Story 2.7** (will write same pref key when notification fires — 2.6 must **read** pref so notification-first path suppresses animation replay)
- BackgroundCollector goal evaluation for notifications → **Story 2.7**
- Coach copy, confetti, streaks, sound, full-screen overlay → never (UX guardrail)
- History-tab celebration → deferred to Today visit only (no History overlay)

Do not over-implement. This story is **celebration choreography + once-per-day dedup** — not notifications.

### Pipeline position (Epic 2)

```text
TodayCubit.refresh()
        │
        ├─ steps >= goal ?
        ├─ celebration_shown_date != todayLocalIso ?
        │
        v
emit TodayState(showCelebration: true)
setCelebrationShownDate(todayLocalIso)   ← immediate persist
        │
        v
TodayScreen → GoalCelebration overlay
        │
        v
onComplete → dismissCelebration()
```

Story 2.5 delivered read path + `GoalRing`. Story 2.6 adds acknowledgment layer on goal threshold.

### Architecture contracts (must match exactly)

**Preference coordination** ([Source: `architecture.md` — Notifications & Goal Celebration]):

| Key | Value | Writer (Phase 0) |
|-----|-------|------------------|
| `celebration_shown_date` | Local day ISO string `YYYY-MM-DD` | `UserPreferencesRepository` — **2.6** (foreground celebration); **2.7** adds notification path |

Compare using `TimeProvider.snapshot()` zone offset — same boundary semantics as `LocalDayCalculator` / `getTodaySteps()`.

**Foreground trigger** ([Source: `architecture.md`]):

| Trigger | Mechanism |
|---------|-----------|
| Goal reached (foreground) | `TodayCubit` on refresh → if steps ≥ goal and pref ≠ today → celebration widget |
| Dedup | Persist pref immediately on trigger; natural reset at local midnight (new day string) |

**Single-writer rule:** Only `UserPreferencesRepository` touches `user_preferences` SQL — cubit calls repo methods, never raw sqflite.

**Time semantics:** Use injected `TimeProvider` for "today" string — **never** `DateTime.now()` in cubit.

### UX animation spec (§2.3.1) — implement literally

| Layer | Animation | Timing | Easing |
|-------|-----------|--------|--------|
| Ring scale | 1.0 → 1.05 → 1.0 | 0–600ms | `Curves.easeOutCubic` |
| Ring glow | Halo accent @ 0% → 18% → 0%, blur 24dp | 0–800ms | ease-out |
| Stroke shimmer | Stroke opacity 1.0 → 1.25 → 1.0 | 200–700ms | ease-in-out |
| Center count | Scale 1.0 → 1.02 → 1.0 | 100–500ms | subtle (optional) |
| Micro-copy | "Daily goal reached" fade in/out | ~2.5s total | caption secondary |
| Haptic | light impact | ~300ms | Android primary |

**Reduced motion:** static full ring + micro-copy 500ms fade — no scale/glow/shimmer controllers.

**Overflow:** Celebration at first `steps >= goal` crossing; subsequent steps same day do not re-trigger (pref dedup handles this).

### Current code state

| Path | Current state | What 2.6 changes | Must preserve |
|------|---------------|------------------|---------------|
| `lib/presentation/widgets/goal_ring.dart` | Full ring states, loading pulse, semantics | Optionally extract shared ring painter for reuse inside `GoalCelebration`; do not break existing tests | Arc cap 100%, dashed no-permission, FittedBox center |
| `lib/presentation/cubits/today_cubit.dart` | Read-only refresh, silent/coalesced | Add celebration trigger + `dismissCelebration()` | No ingestion writes; `isClosed` guard; coalesced refresh |
| `lib/presentation/cubits/today_state.dart` | 6 status variants | Add `showCelebration` flag | `_resolveStatus` overflow/goalMet logic |
| `lib/presentation/screens/today_screen.dart` | `GoalRing` hero | Conditional `GoalCelebration` wrapper | Stale banner, SourceChip, layout flex 55/45 |
| `lib/data/repositories/user_preferences_repository.dart` | goal, theme, onboarding | Add celebration date get/set | Sole writer pattern |
| `lib/core/constants/preference_keys.dart` | 3 keys | Add `kCelebrationShownDateKey` | Existing defaults unchanged |
| `lib/presentation/screens/app_scaffold.dart` | Tab return → `refresh()` | No change required if cubit handles dedup | Periodic 60s refresh, ingestion callback |

`GoalCelebration`, `celebration_shown_date` repo methods **do not exist yet**.

### Recommended file layout

```text
lib/core/constants/preference_keys.dart                    # UPDATE
lib/core/time/local_day_formatter.dart                     # NEW (small helper)
lib/data/repositories/user_preferences_repository.dart     # UPDATE
lib/presentation/cubits/today_state.dart                   # UPDATE
lib/presentation/cubits/today_cubit.dart                   # UPDATE
lib/presentation/widgets/goal_celebration.dart             # NEW
lib/presentation/screens/today_screen.dart                 # UPDATE

test/data/repositories/user_preferences_repository_test.dart # UPDATE
test/presentation/cubits/today_cubit_test.dart               # UPDATE
test/presentation/widgets/goal_celebration_test.dart         # NEW
```

### Celebration trigger sketch (suggested)

```dart
Future<void> _maybeTriggerCelebration({
  required int steps,
  required int goal,
  required TodayState baseState,
}) async {
  if (goal <= 0 || steps < goal) {
    emit(baseState.copyWith(showCelebration: false));
    return;
  }

  final todayIso = formatLocalDayIso(clock.snapshot());
  final shownDate = await userPreferences.getCelebrationShownDate();
  if (shownDate == todayIso) {
    emit(baseState.copyWith(showCelebration: false));
    return;
  }

  await userPreferences.setCelebrationShownDate(todayIso);
  emit(baseState.copyWith(showCelebration: true));
}

void dismissCelebration() {
  if (state.showCelebration) {
    emit(state.copyWith(showCelebration: false));
  }
}
```

Call `_maybeTriggerCelebration` at end of `_refreshImpl` after `TodayState.fromData(...)`.

**Important:** Persist pref **before** or **with** emit — if refresh coalesces mid-animation, pref already set prevents duplicate controllers.

### GoalCelebration structure (suggested)

```dart
class GoalCelebration extends StatefulWidget {
  const GoalCelebration({
    required this.state,
    required this.onComplete,
    super.key,
  });

  final TodayState state;
  final VoidCallback onComplete;
}
```

Use `Stack` alignment center:
1. `CelebrationGlow` — `AnimatedBuilder` on opacity 0→0.18→0 with `ImageFilter.blur(sigmaX: 24, sigmaY: 24)` or `BoxShadow` spread
2. `Transform.scale` on `GoalRing` for pulse
3. Shimmer: duplicate arc painter with animated opacity overlay OR modulate `GoalRingPainter` progress color alpha
4. Micro-copy `AnimatedOpacity` below ring in parent `TodayScreen` column OR inside celebration widget footer

Total sequence ~900ms animations + micro-copy until 2.5s → `onComplete`.

### Coordination with Story 2.7 (read now, implement later)

When 2.7 lands, `BackgroundCollector` may call `setCelebrationShownDate(todayIso)` when firing notification. **2.6 must treat pref as source of truth:**

- If notification set pref while app closed → user opens Today → **no** celebration replay (AC #3 satisfied)
- If celebration set pref while app open → 2.7 must check pref before notification (already in architecture)

Do **not** implement `NotificationService` in 2.6.

### Architecture compliance

| Decision / invariant | Requirement for 2.6 |
|----------------------|----------------------|
| D-03 | Cubit reads repos; celebration pref via `UserPreferencesRepository` only |
| D-09 | Extend `TodayCubit` / `TodayState` — no new global state |
| D-25 | Local day from `TimeProvider.snapshot()` — no `DateTime.now()` |
| FR15 | Once-per-day celebration animation |
| UX-DR6 | Pulse, glow, shimmer, micro-copy, haptic, reduce motion |
| UX-DR19 | `liveRegion` polite; decorative exclude; English labels |
| UX-DR18 | No confetti/streak animations |

### Anti-patterns

- Do not implement `NotificationService` or background notification evaluation (2.7).
- Do not use SnackBar/toast with coach language ("You're crushing it!").
- Do not replay celebration on every tab switch or 60s poll — pref dedup is mandatory.
- Do not write `celebration_shown_date` from widgets — cubit/repo only.
- Do not use SQL or device TZ for local day string — use `TimeProvider` + offset.
- Do not add confetti packages or Lottie assets.
- Do not block interaction with full-screen modal overlay.
- Do not seed `celebration_shown_date` in migrations — absent until first goal met.

### Testing requirements

| Area | Requirement |
|------|-------------|
| `user_preferences_repository` | get/set celebration date round-trip |
| `today_cubit` | First goal cross triggers once; pref blocks replay; overflow included |
| `goal_celebration` | Reduce motion skips animated layers; semantics liveRegion once |
| Widget | Pump with `showCelebration: true`; verify `onComplete` fired after timeout |
| Regression | Existing `goal_ring_test`, `today_cubit_test`, `app_scaffold_test` still pass |

Run: `flutter analyze`, `flutter test test/data/repositories/user_preferences_repository_test.dart test/presentation/cubits/today_cubit_test.dart test/presentation/widgets/goal_celebration_test.dart test/presentation/widgets/goal_ring_test.dart`

### Previous story intelligence (2.5)

- `GoalRing` complete with `GoalRingPainter`, semantics, overflow arc cap — reuse inside celebration stack.
- `TodayCubit.refresh(silent: true)` default — celebration trigger must work on silent refresh (no loading flash).
- Coalesced refresh (`_refreshInFlight`) — persist pref before animation to survive concurrent refresh.
- `AppScaffold` calls `refresh()` when returning to Today tab — celebration deferred from History path works automatically.
- Code review fixes retained: FittedBox for text scale, silent refresh, centered SourceChip — do not regress.
- Review gate: **one commit per sub-task** after Baptiste OK ([Source: `docs/project-context.md`]).

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `feat(today): complete story 2.5 with code review fixes` | Today dashboard stable — build celebration on top |
| `feat(today): add GoalRing widget with progress arc states` | Reuse painter/semantics patterns |
| `feat(today): add TodayCubit and TodayState read path` | Extend cubit for celebration trigger |

### Library / framework requirements

| Package | Version | Usage |
|---------|---------|-------|
| flutter (sdk) | ^3.12 | `AnimationController`, `HapticFeedback`, `MediaQuery.disableAnimationsOf` |
| flutter_bloc | ^9.1.1 | `TodayCubit` extension |

**No new pubspec dependencies** expected. Use Flutter built-in animation/haptic APIs only.

### Latest technical notes

- **Reduce motion:** `MediaQuery.disableAnimationsOf(context)` (Flutter 3.16+) — same pattern as `GoalRing` loading pulse.
- **Multiple `AnimationController`s:** single `TickerProviderStateMixin`; dispose all in `dispose()`; call `onComplete` once via `Future.wait` or master controller 2500ms.
- **Glow performance:** prefer one `CustomPaint` halo circle behind ring over expensive blur on low-end devices; blur 24dp per spec but test on emulator.
- **Opacity > 1.0 on stroke:** clamp painter alpha channel rather than literal opacity widget > 1.
- **Pref format:** ISO date `YYYY-MM-DD` string — lexicographic compare safe for same timezone logic; document in repo dartdoc.

### Project context reference

- Review-before-commit workflow mandatory per sub-task.
- Baptiste is Flutter novice — review briefs should explain `AnimationController`, `Stack` overlay, and pref dedup.
- [Source: `docs/project-context.md`]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — Notifications & Goal Celebration table]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §2.3.1, §3.3, §4.3, §4.5]
- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 2.6 AC]
- [Source: `_bmad-output/implementation-artifacts/stories/2-5-today-dashboard-with-goal-ring.md` — deferred scope + current file map]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

### Completion Notes List

- Sub-task A: `celebration_shown_date` pref key, repo get/set, `formatLocalDayIso` aligned with `LocalDayCalculator` + unit tests.
- Sub-task B: `TodayState.showCelebration`, cubit trigger with immediate pref persist, `dismissCelebration()`, cubit tests for dedup/overflow/permission.
- Sub-task C: `GoalCelebration` widget (pulse, glow, shimmer, micro-copy, haptics, reduce motion, semantics) + widget tests.
- Sub-task D: `TodayScreen` conditional `GoalCelebration` vs `GoalRing`.
- Sub-task E: `flutter analyze` clean; 162 tests pass. Story 2.7 deferred: `NotificationService` + background notification writing same pref.

### File List

- lib/core/constants/preference_keys.dart
- lib/core/time/local_day_formatter.dart
- lib/data/repositories/user_preferences_repository.dart
- lib/presentation/cubits/today_state.dart
- lib/presentation/cubits/today_cubit.dart
- lib/presentation/widgets/goal_celebration.dart
- lib/presentation/screens/today_screen.dart
- test/core/time/local_day_formatter_test.dart
- test/data/repositories/user_preferences_repository_test.dart
- test/presentation/cubits/today_cubit_test.dart
- test/presentation/widgets/goal_celebration_test.dart

### Change Log

- 2026-06-02: Story 2.6 — goal celebration animation, once-per-day dedup via `celebration_shown_date`, Today cubit trigger and screen integration.

## Story completion status

- Ultimate context engine analysis completed — comprehensive developer guide created
- Status: **review**
