# Story 11.2: Day Picker and Selected Day State

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want to tap a day in the **This week** card pills to inspect that day,
So that I can review past activity directly from Steps.

## Acceptance Criteria

1. **Given** the week strip on Steps  
   **When** user taps any day pill (past, today, future)  
   **Then** `TodayState.selectedLocalDay` updates to that pill day  
   **And** this day becomes the selected UI state in the week strip.

2. **Given** app cold start or resume and Steps tab visible  
   **When** `TodayCubit.refresh()` / `refreshMetadata()` runs  
   **Then** `selectedLocalDay` defaults to local **today** unless the user has just changed it in-session.

3. **Given** week pills rendering  
   **When** a day is selected  
   **Then** selected pill visual is distinct and consistent with mockup intent (accent-filled selected state; clear contrast for label/day number)  
   **And** this selection behavior is implemented on the existing **This week** pills (no new day picker widget elsewhere).

4. **Given** a future day is selected  
   **When** state is consumed by UI  
   **Then** selection is allowed  
   **And** future-day path is explicitly represented for downstream display guards (11.3) so ring/stats can show empty/zero without live overlay.

5. **Given** unit/widget tests  
   **When** tests run  
   **Then** cover:
   - selected day update on tap
   - default selected day = today on initial load/resume
   - future day selectable and flagged for empty-state path.

## Tasks / Subtasks

- [x] **Sub-task A — Add selected-day state to Today domain** (AC: #1, #2, #4)
  - [x] Update `lib/presentation/cubits/today_state.dart`:
    - add `DateTime selectedLocalDay`
    - include in constructor, `fromData`, and `copyWith`
  - [x] Ensure `selectedLocalDay` is normalized date-only local day (same shape as `WeekDayStatus.localDay`)
  - [x] Update `lib/presentation/cubits/today_cubit.dart`:
    - initialize/realign selection to today during refresh paths
    - add explicit selection method (e.g. `selectLocalDay(DateTime day)`) used by UI tap handler
    - preserve existing refresh, stale, celebration, and live-monitor behavior.

- [x] **Sub-task B — Make “This week” pills the day picker** (AC: #1, #3, #4)
  - [x] Update `lib/presentation/widgets/week_progress_row.dart`:
    - add selected day input + tap callback
    - render selected style distinctly (selected accent fill)
    - keep existing goal dots semantics (past goal-met dot, future muted dot)
  - [x] Update `lib/presentation/screens/today_screen.dart`:
    - pass `state.selectedLocalDay` and `onDayTap` from cubit to `WeekProgressRow`
    - keep current layout order from 11.1 (This week above ring, then stats).

- [x] **Sub-task C — Tests for day picker state and visuals** (AC: #5)
  - [x] Update `test/presentation/cubits/today_cubit_test.dart`:
    - selected day defaults to today after refresh
    - selection changes on explicit day select
    - resume/metadata refresh keeps day valid and deterministic
  - [x] Update `test/presentation/widgets/week_progress_row_test.dart`:
    - selected day styling differs from non-selected
    - tap callback emits expected `localDay`
    - future day tap is allowed
  - [x] Update `test/presentation/screens/screen_smoke_test.dart`:
    - integration assertion that week pills act as day picker wiring (tap -> cubit selected day).

## Dev Notes

### User clarification to lock scope

The requested behavior is explicit: **the pills inside the “This week” card are the day picker**.  
Do not introduce a second picker, modal, segmented control, or alternate selector.

### Current code state (must be preserved)

- `TodayScreen` already uses week-first order from story 11.1 (`This week` card above ring).
- `WeekProgressRow` currently renders static pills (`StatelessWidget`) with no tap callback and highlights only `isToday`.
- `TodayState` currently has no selected-day field.
- `TodayCubit` already computes week days and today metrics; no selected-day transitions yet.

### Architecture compliance guardrails

- Stay in **presentation + cubit state** scope for 11.2.
- No repository schema change.
- No new dependency in `pubspec.yaml`.
- No break in `TodayCubit` silent refresh behavior, stale banner logic, or celebration flow.
- Keep local-day semantics aligned with `LocalDayCalculator` / `localDayIsoFromDateOnly`.

### Story boundary with 11.3 / 11.4

**In scope now (11.2):**
- selected day state and interaction wiring
- selected visual in week pills
- future-day selectable path marker

**Out of scope now:**
- ring + stats + goal content switching to selected day (11.3)
- live-overlay suppression rules implementation for non-today rendering (11.3 full behavior)
- trophy `X/7` and historical-goal week scoring (11.4)

### Reuse — avoid reinvention

- Keep using `WeekDayStatus` list from `TodayCubit._loadWeekDays()`.
- Keep `SectionCard(headline: 'This week', child: WeekProgressRow(...))`.
- Extend existing `WeekProgressRow` instead of replacing with a new component.

### Testing requirements

- Cubit unit tests for deterministic selected-day lifecycle.
- Widget tests for day-pill selected style + tap callback.
- Smoke-level wiring test from `TodayScreen` to cubit selection.
- Existing tests for stale banner, goal ring, and stats must remain green.

### Git intelligence summary

Recent commit pattern shows small, focused steps around Steps surface:
- `bc96ee2` moved layout order only
- `206ec35` and `1709e0e` hardened title/layout tests

Follow same approach: state + widget wiring + tests in narrow scope.

### Latest technical notes (2026)

- Flutter chips/day selectors are still best implemented with a single source of truth for selected item in state (`Cubit`), with pure render widgets receiving `selected` + callback.
- Existing project style already uses immutable state + `copyWith`; keep that model for `selectedLocalDay`.
- Avoid introducing Material `ChoiceChip` unless needed; current custom pill component already matches visual language and avoids style drift.

### Project context reference

- Review-before-commit expectation: `docs/project-context.md`
- Versioning note: epic-level bump at Epic 11 close (`0.4.0+6`), not per story

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` § Epic 11, Story 11.2]
- [Source: `_bmad-output/implementation-artifacts/stories/11-1-steps-screen-layout-week-first.md`]
- [Source: `lib/presentation/screens/today_screen.dart`]
- [Source: `lib/presentation/widgets/week_progress_row.dart`]
- [Source: `lib/presentation/cubits/today_state.dart`]
- [Source: `lib/presentation/cubits/today_cubit.dart`]
- [Source: `test/presentation/cubits/today_cubit_test.dart`]
- [Source: `test/presentation/widgets/week_progress_row_test.dart`]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

- Context analysis: epics + architecture + UX + previous story loaded
- Recent commits reviewed: `1709e0e`, `206ec35`, `bc96ee2`, `f6f9a63`, `84dac4c`
- Implemented selected-day state lifecycle in Today state/cubit with date-only normalization and in-session preservation.
- Wired week pills as tappable day picker with selected visual state and callback propagation from `TodayScreen`.
- Ran targeted tests:
  - `flutter test test/presentation/cubits/today_cubit_test.dart test/presentation/widgets/week_progress_row_test.dart test/presentation/screens/screen_smoke_test.dart`
  - Result: all tests passed.

### Completion Notes List

- Story scope anchored to user clarification: week-card pills are the day picker.
- Guardrails added to keep 11.2 state/wiring-focused and avoid leaking 11.3/11.4 scope.
- File-level update targets and test expectations defined for dev execution.
- Added `selectedLocalDay` to `TodayState` and carried it through `fromData` and `copyWith`.
- Added `TodayCubit.selectLocalDay(...)` and refresh/metadata selection resolution logic with deterministic date-only comparison.
- Updated `WeekProgressRow` to be interactive and to render selected-pill accent fill independently from `isToday`.
- Added/updated tests covering selected-day default, selection update, future-day select path, and screen-level tap wiring.

### File List

- `_bmad-output/implementation-artifacts/stories/11-2-day-picker-and-selected-day-state.md`
- `lib/presentation/cubits/today_state.dart`
- `lib/presentation/cubits/today_cubit.dart`
- `lib/presentation/widgets/week_progress_row.dart`
- `lib/presentation/screens/today_screen.dart`
- `test/presentation/cubits/today_cubit_test.dart`
- `test/presentation/widgets/week_progress_row_test.dart`
- `test/presentation/screens/screen_smoke_test.dart`
