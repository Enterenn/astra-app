# Story 15.2: Move GoalRing Display Persistence to TodayCubit

Status: review

<!-- Refacto Epic 15 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 15-2 · refactoring-audit-master-v0.6.1.md §1.1 -->
<!-- Blocks: Story 16-7 (cold-start shimmer) · NFR-REF-05 -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **developer**,
I want GoalRing to be a pure presentation widget,
So that step display state is testable via cubit mocks and architecture boundaries are respected.

## Acceptance Criteria

1. **Given** `GoalRing` widget  
   **When** refactored  
   **Then** `_loadLastDisplayedSteps()` and `_persistLastDisplayedSteps()` are removed from widget state (REF-04, NFR-REF-05)  
   **And** `GoalRing.disableStepPersistence` static flag is eliminated  
   **And** `GoalRing` has **no** import of `UserPreferencesRepository` or `sqflite`

2. **Given** `TodayState`  
   **When** extended  
   **Then** includes `lastDisplayedSteps` (`int?`, null = not yet loaded) and `lastDisplayedStepsLoaded` (`bool`) managed by `TodayCubit`  
   **And** cubit loads from `UserPreferencesRepository.getLastDisplayedSteps` during `_refreshImpl` (today) and `_applySelectedDayDisplay` (past day)  
   **And** cubit persists via `setLastDisplayedSteps` when GoalRing reports a new displayed value (not on every animation frame — same dedup semantics as today’s `_lastPersistedSteps`)

3. **Given** existing animation semantics (Story 5.13)  
   **When** cold start or day change  
   **Then** count-up **starts from** `state.lastDisplayedSteps ?? 0`, not from a widget-local prefs load  
   **And** if `lastDisplayedSteps == targetSteps` → instant render (no animation)  
   **And** monotonic-within-day rule preserved: displayed value does not decrease when SQLite lags prefs  
   **And** `foregroundCatchUp`, micro-tick, and celebration (`freezeMotion`) paths behave as before

4. **Given** `TodayCubit._clampStaleLastDisplayed` and `syncSteps(clampStaleDisplay: true)`  
   **When** stale-high prefs are clamped  
   **Then** in-memory `state.lastDisplayedSteps` is updated to match prefs write (no widget-only fix)

5. **Given** `postPurgeRefresh` in `AppScaffold`  
   **When** `clearLastDisplayedSteps()` runs then `TodayCubit.refresh`  
   **Then** cubit reloads `lastDisplayedSteps` as null/0 — GoalRing does not show pre-purge cached display steps

6. **Given** existing GoalRing, TodayCubit, scaffold, and lifecycle tests  
   **When** updated  
   **Then** all `GoalRing.disableStepPersistence = true` toggles are removed  
   **And** widget tests seed display state via `TodayState.lastDisplayedSteps` (or `BlocProvider` + mock cubit) — not static flags  
   **And** `flutter test` + `flutter analyze` pass on touched files

7. **Given** work completes on branch `refacto`  
   **When** story is marked done  
   **Then** **no version bump** yet — Epic 15 closes with patch+1 (`0.6.2+13` → `0.6.3+14`) when all Epic 15 stories are done

8. **Given** audit §1.1 alternative (`GoalRingDisplayStateService`)  
   **When** cubit approach is chosen  
   **Then** review brief documents accepted display-state coupling in `TodayState` vs dedicated service (enables Story 16-7 without extra DI)

**Covers:** REF-04 · NFR-REF-05 · Audit §1.1 (P1) · **Blocks** Story 16-7 (REF-13 / UX-REF-03)

## Tasks / Subtasks

- [x] **Sub-task A — Extend TodayState + TodayCubit display-state API** (AC: #2, #4, #5)
  - [x] Read `TodayState`, `TodayCubit._refreshImpl`, `_applySelectedDayDisplay`, `_clampStaleLastDisplayed` **before editing**
  - [x] Add `lastDisplayedSteps` (`int?`) and `lastDisplayedStepsLoaded` (`bool`, default `false`) to `TodayState`; wire through `copyWith`, `fromData`, constructors
  - [x] Add `Future<void> recordLastDisplayedSteps(int steps)` on `TodayCubit`:
    - No-op when `steps < 0` or same as `state.lastDisplayedSteps`
    - Guard `!userPreferences.isDatabaseOpen` (mirror widget’s `DatabaseException` swallow)
    - Persist to prefs for **current display local day** (today ISO or `selectedLocalDay`)
    - Emit `copyWith(lastDisplayedSteps: steps, lastDisplayedStepsLoaded: true)`
  - [x] Load `lastDisplayedSteps` in `_refreshImpl` parallel batch (add to existing `Future.wait` for today view)
  - [x] Load per-day value in `_applySelectedDayDisplay` when viewing a past day
  - [x] Update `_clampStaleLastDisplayed` to also emit clamped value into state
  - [x] Add cubit unit tests: load on refresh, record persists to prefs, clamp updates state
  - [x] Run `flutter analyze` + `flutter test test/presentation/cubits/today_cubit_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Purify GoalRing + wire TodayScreen** (AC: #1, #3)
  - [x] Remove from `GoalRing`: `userPreferences`, `localDayIso`, `disableStepPersistence`, `_loadLastDisplayedSteps`, `_persistLastDisplayedSteps`, prefs-related imports
  - [x] Add `ValueChanged<int>? onLastDisplayedStepsChanged` callback (called when displayed steps settle — count-up complete, instant set, micro-tick complete)
  - [x] Initialize animation start from `widget.state.lastDisplayedSteps ?? 0` once `state.lastDisplayedStepsLoaded` is true (replace async prefs gate)
  - [x] On `didUpdateWidget`: react to `lastDisplayedSteps` / `lastDisplayedStepsLoaded` / `selectedLocalDay` changes instead of `localDayIso` prefs reload
  - [x] Update `today_screen.dart` `_GoalRingCard`: remove `userPreferences` / `localDayIso` args; pass `onLastDisplayedStepsChanged: cubit.recordLastDisplayedSteps`
  - [x] Verify `goal_celebration.dart` usages still compile (`freezeMotion` path unchanged)
  - [x] Run `flutter analyze` + `flutter test test/presentation/widgets/goal_ring_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Migrate tests off `disableStepPersistence`** (AC: #6)
  - [x] Remove flag toggles from: `goal_ring_test.dart`, `screen_smoke_test.dart`, `widget_test.dart`, `app_scaffold_test.dart`, `app_live_pipeline_lifecycle_test.dart`
  - [x] Replace `debugLastDisplayedSteps` with `TodayState` field where possible; keep `debugLastDisplayedSteps` only if a test truly needs widget-only seeding without Bloc — prefer state field
  - [x] Update `goal_ring_test.dart` setUp: seed `lastDisplayedSteps` + `lastDisplayedStepsLoaded: true` on test `TodayState` fixtures
  - [x] Run full `flutter test` (or at minimum all touched test files + `today_cubit_test.dart`)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Move display-step prefs I/O from `GoalRing` → `TodayCubit` | Cold-start shimmer UI (Story 16-7) — but **must** expose `lastDisplayedStepsLoaded` for it |
| Remove `disableStepPersistence` test flag | Repository interface extraction (Story 16-1) |
| Preserve Story 5.13 animation semantics | `RepaintBoundary` / GPU perf (Story 16-4) |
| Update tests that toggled static flag | Batch goal SQL (Story 15-1 — done) |
| Branch `refacto` only | Version bump (deferred to Epic 15 close) |

### Architecture decision — cubit vs service

Audit §1.1 offered `GoalRingDisplayStateService` as an alternative to avoid coupling display state into `TodayState`.

**Choose cubit approach** (per epic AC):

- `TodayCubit` already owns `foregroundCatchUp`, celebration, and `_clampStaleLastDisplayed` — display persistence is the same concern
- Story 16-7 requires `TodayCubit` to hold `lastDisplayedSteps` **and** loading gate — a separate service would still need cubit coordination
- NFR-REF-05: cubit-mockable unit tests without widget prefs I/O

Document this trade-off in the Sub-task A review brief.

### Critical baseline — read before editing

**Widget prefs leak (`goal_ring.dart`):**

```211:256:lib/presentation/widgets/goal_ring.dart
  Future<void> _loadLastDisplayedSteps() async {
    // ... reads prefs.getLastDisplayedSteps(day) ...
  }
```

```558:577:lib/presentation/widgets/goal_ring.dart
  Future<void> _persistLastDisplayedSteps(int steps) async {
    if (GoalRing.disableStepPersistence || _lastPersistedSteps == steps) {
      return;
    }
    // ... prefs.setLastDisplayedSteps ...
  }
```

**Today screen passes repository into widget (violation):**

```155:160:lib/presentation/screens/today_screen.dart
                : GoalRing(
                    state: state,
                    userPreferences: cubit.userPreferences,
                    localDayIso: localDayIsoForPrefs,
                    onForegroundCatchUpHandled: cubit.clearForegroundCatchUp,
                  ),
```

**Cubit already touches same prefs (`today_cubit.dart` 793–810):**

```793:810:lib/presentation/cubits/today_cubit.dart
  Future<void> _clampStaleLastDisplayed(int truthSteps) async {
    final todayIso = formatLocalDayIso(clock.snapshot());
    final lastDisplayed = await userPreferences.getLastDisplayedSteps(todayIso);
    // ... setLastDisplayedSteps when stale-high ...
  }
```

After this story, **all** `get/setLastDisplayedSteps` calls from presentation widgets must be gone; only `TodayCubit` (and `AppScaffold.postPurgeRefresh` clear) remain.

### Prefs semantics (do not change)

Repository stores a **single** last-displayed pair per app (day key + steps) — not per-day history:

```351:368:lib/data/repositories/user_preferences_repository.dart
  Future<int?> getLastDisplayedSteps(String localDayIso) async {
    final storedDay = await _readValue(kLastDisplayedStepsLocalDayKey);
    if (storedDay != localDayIso) {
      return null;
    }
    // ...
  }
```

When user selects a past day, `getLastDisplayedSteps(pastDayIso)` typically returns `null` → animation starts at 0. Preserve this.

### GoalRing internal state after refactor

| Field | Keep in widget? | Notes |
|-------|-----------------|-------|
| `_displayedSteps`, `_animatedProgress` | Yes | Runtime animation state |
| `_lastDisplayedSteps` | **Derive from** `state.lastDisplayedSteps` on load/day change | Do not persist from widget |
| `_prefsLoaded`, `_prefsLoadHandled` | Replace with `state.lastDisplayedStepsLoaded` | Enables 16-7 loading gate |
| `_lastPersistedSteps` dedup | Move to cubit `recordLastDisplayedSteps` | Avoid duplicate writes |

### Cold-start animation flow (preserve)

1. App opens → `TodayCubit` starts `TodayStatus.loading`
2. `_refreshImpl` loads SQLite steps + `lastDisplayedSteps` from prefs
3. Emits ready state with `lastDisplayedStepsLoaded: true`
4. `GoalRing` sees loaded flag → `_handleStepChange(forceColdStart: true)` with `start = state.lastDisplayedSteps ?? 0`
5. Count-up to `state.steps` (or instant if equal)

**Do not** flash target count before load — keep “hold at zero until loaded” behavior from current `initState` (lines 178–181), but gate on `lastDisplayedStepsLoaded` instead of async prefs.

### Selected local day

When `selectLocalDay` switches to a past day, `_applySelectedDayDisplay` must load `lastDisplayedSteps` for that day’s ISO and emit with `lastDisplayedStepsLoaded: true`. `GoalRing.didUpdateWidget` must reset cold-start handling when `selectedLocalDay` changes (replaces current `localDayIso` reload).

### Callback contract

`onLastDisplayedStepsChanged` fires when displayed steps **settle** (same call sites as current `_persistLastDisplayedSteps`):

- `_setDisplayedInstant`
- count-up `AnimationStatus.completed`
- micro-tick completion (if it persists today — verify in `goal_ring.dart` ~523)

Do **not** call on every `addListener` tick.

### Call sites — files to touch

| File | Action |
|------|--------|
| `lib/presentation/cubits/today_state.dart` | Add fields + copyWith |
| `lib/presentation/cubits/today_cubit.dart` | Load, record, clamp state sync |
| `lib/presentation/widgets/goal_ring.dart` | Remove prefs; use state + callback |
| `lib/presentation/screens/today_screen.dart` | Wire callback; drop repo args |
| `lib/presentation/widgets/goal_celebration.dart` | Verify compile (no repo args today) |
| `test/presentation/cubits/today_cubit_test.dart` | New display-state tests |
| `test/presentation/widgets/goal_ring_test.dart` | State seeding; remove flag |
| `test/presentation/screens/screen_smoke_test.dart` | Remove flag |
| `test/widget_test.dart` | Remove flag |
| `test/presentation/screens/app_scaffold_test.dart` | Remove flag |
| `test/app_live_pipeline_lifecycle_test.dart` | Remove flag |

**Do not change** `app_scaffold.dart` purge step order — `clearLastDisplayedSteps` before `todayCubit.refresh` remains correct.

### Testing requirements

| Test file | What to prove |
|-----------|---------------|
| `today_cubit_test.dart` | Refresh loads `lastDisplayedSteps`; `recordLastDisplayedSteps` writes prefs; clamp updates state; existing `refresh ignores stale-high lastDisplayed` still passes |
| `goal_ring_test.dart` | Cold start count-up from `TodayState.lastDisplayedSteps`; no `disableStepPersistence`; celebration/freezeMotion unchanged |
| `app_scaffold_test.dart` | Post-purge refresh still works without flag |
| Regression | `flutter test` full suite green |

### Architecture compliance

- **Layering:** `presentation/widgets/` must not import `data/repositories/` (architecture.md D-22, presentation → repositories via cubits only)
- **Single-writer:** Prefs writes for display steps only from `TodayCubit.recordLastDisplayedSteps` and existing clamp path
- **Review before commit:** One commit per sub-task per `docs/project-context.md`
- **Time semantics:** Use `formatLocalDayIso(clock.snapshot())` / `localDayIsoFromDateOnly(selectedDay)` — same helpers as today

### Library / framework requirements

- No new dependencies
- Remove `sqflite` import from `goal_ring.dart` if only used for `DatabaseException` in persist
- `flutter_bloc` — `TodayScreen` already uses `context.read<TodayCubit>()`

### Previous story intelligence (15-1)

Story 15-1 patterns to reuse:

- Sub-task gate: implement → review brief → Baptiste OK → commit
- Read baseline code blocks before editing
- Scope table in Dev Notes prevents drive-by refactors
- Spy/subclass tests in cubit layer — prefer cubit tests over widget prefs mocking for persistence logic
- No version bump mid-epic

Story 15-1 explicitly listed “GoalRing persistence move (Story 15-2)” as out of scope — no conflicting changes expected in `goal_ring.dart` from 15-1.

### Git intelligence (recent refacto commits)

| Commit | Relevance |
|--------|-----------|
| `2aeb607` Story 15-1 done | Batch goals shipped; base for 15-2 |
| `bc31561` / `a47424d` | Sub-task commit pattern on `refacto` |
| `c9d761d` Epic 14 close `v0.6.2+13` | Current base version |

### Downstream dependency (16-7)

Story 16-7 will use:

- `TodayStatus.loading` until **both** SQLite steps and `lastDisplayedStepsLoaded == true`
- Shimmer on GoalRing while loading

This story **must** expose `lastDisplayedStepsLoaded` but **must not** implement shimmer — avoid scope creep.

### Latest technical notes

- **flutter_bloc 8.x:** `recordLastDisplayedSteps` can be synchronous emit + unawaited prefs write (mirror current widget `unawaited(_persistLastDisplayedSteps)`), or fully async — prefer async with `isClosed` guards matching cubit style
- **Widget tests without DB:** Seeding `TodayState(lastDisplayedSteps: 470, lastDisplayedStepsLoaded: true, ...)` eliminates sqflite timer flakes that motivated `disableStepPersistence` (Story 5.13 review patch)

### Project context reference

- Branch: `refacto` until merge review
- Review-before-commit workflow: `docs/project-context.md`
- Versioning at epic close: `epics-refacto.md` → Epic 15 = patch+1
- Story location: `_bmad-output/implementation-artifacts/stories/`
- Sprint tracking: `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml`

## Dev Agent Record

### Agent Model Used

claude-4.6-sonnet-medium-thinking

### Debug Log References

- Chose cubit-over-service approach per Dev Notes (Story 16-7 needs `lastDisplayedStepsLoaded` on `TodayState`).
- `recordLastDisplayedSteps` emits synchronously then `unawaited` prefs write (mirrors prior widget pattern).
- Removed `deactivate` persist — not in callback contract; caused sqflite timer flakes in `app_scaffold_test`.

### Completion Notes List

- ✅ `TodayState` extended with `lastDisplayedSteps` / `lastDisplayedStepsLoaded`.
- ✅ `TodayCubit` loads display prefs on refresh and day select; `recordLastDisplayedSteps` + clamp sync state.
- ✅ `GoalRing` is prefs-free; uses cubit state + `onLastDisplayedStepsChanged` callback.
- ✅ All `disableStepPersistence` / `debugLastDisplayedSteps` test toggles removed.
- ✅ `flutter analyze` (touched lib files) + full `flutter test` (835 passed, 15 skipped).

### File List

- `lib/presentation/cubits/today_state.dart`
- `lib/presentation/cubits/today_cubit.dart`
- `lib/presentation/widgets/goal_ring.dart`
- `lib/presentation/screens/today_screen.dart`
- `test/presentation/cubits/today_cubit_test.dart`
- `test/presentation/widgets/goal_ring_test.dart`
- `test/presentation/screens/screen_smoke_test.dart`
- `test/presentation/screens/app_scaffold_test.dart`
- `test/widget_test.dart`
- `test/app_live_pipeline_lifecycle_test.dart`

### Change Log

- 2026-06-18: Moved GoalRing display-step persistence to TodayCubit/TodayState; removed widget prefs I/O and test static flag.
