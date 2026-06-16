# Story 11.1: Steps Screen Layout Week-First

Status: done

<!-- Baptiste 2026-06-16: Today-light mockup re-attached — week card above ring, screen title "Steps". -->
<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want the week summary at the top of Steps,
So that I see weekly context before today's detail.

## Acceptance Criteria

1. **Given** Steps tab (index 0)  
   **When** screen renders (light or dark theme, any accent preset)  
   **Then** screen title is **Steps** (not "Today's activity")  
   **And** root `Semantics.label` matches **Steps**  
   **And** title uses `AstraTypography.screenTitleFor(colors)` (unchanged token)

2. **Given** Steps screen with optional stale data  
   **When** layout builds  
   **Then** vertical order below title is:
   - optional compact `StatusBanner` (stale only — unchanged copy/behavior)
   - **`SectionCard` headline "This week"** — first content card
   - goal ring card (`ElevatedCard` with `GoalRing` / `GoalCelebration` + **Set goal** pill)
   - optional permission `TextButton` when `TodayStatus.noPermission`
   - stats card (`ElevatedCard` + `ActivityStatsRow`)  
   **And** spacing between blocks remains `AstraSpacing.kSpaceMd` (same gaps as today)

3. **Given** week-first layout  
   **When** compared to mockup `Today-light` (2026-06-16 session attachment)  
   **Then** **This week** sits above the donut; donut + **Set goal** sit above the kcal/km/duration row  
   **And** bottom nav clearance padding is unchanged (`kBottomNavBottomOffset + kBottomNavBarHeight + kSpaceMd`)

4. **Given** existing Today truth model, celebration, live overlay, goal editor, stats computation  
   **When** layout reorders  
   **Then** **no** cubit, repository, or widget logic changes — presentation order + title only  
   **And** `GoalRing` center label **Steps** (inside ring) remains — distinct from screen title position

5. **Given** implementation complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no new analyzer issues  
   **And** `screen_smoke_test.dart` asserts title **Steps** and week-before-ring order  
   **And** `app_scaffold_test.dart` no longer expects "Today's activity"  
   **And** no regression in goal ring, stale banner, or week strip widget tests

**Depends on:** Epic 8 (done), Epic 10.1 (done — tab label already **STEPS**).  
**Enables:** Stories 11.2 (day picker), 11.3 (selected-day data), 11.4 (trophy X/7).  
**Mockup ref:** `Today-light` — user attachment 2026-06-16 (`assets/.../Today-light-66f41e81-*.png`).

## Tasks / Subtasks

- [x] **Sub-task A — Reorder `TodayScreen` column** (AC: #2, #3, #4)
  - [x] In `lib/presentation/screens/today_screen.dart`, move the `SectionCard(headline: 'This week', …)` block **above** `_GoalRingCard`
  - [x] Keep stale banner between title and first card (banner still directly under title, week card is first **card**)
  - [x] Preserve permission CTA placement after ring card
  - [x] Do **not** touch `_GoalRingCard`, `GoalRing`, `ActivityStatsRow`, or cubit code
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Rename screen title + semantics** (AC: #1)
  - [x] Change `_kScreenTitle` from `"Today's activity"` to `'Steps'`
  - [x] Update visible `Text` and `Semantics.label` to use `_kScreenTitle`
  - [x] **Do not** rename `TodayScreen` / `TodayCubit` files or classes (deferred — internal names stable until broader refactor)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests** (AC: #5)
  - [x] `test/presentation/screens/screen_smoke_test.dart`:
    - Title test: expect `find.text('Steps')` for screen title (use `find.descendant(of: find.byType(TodayScreen), …)` or `findsWidgets` ≥2 if ring label also matches — prefer **scoped** finder on title `Text` at column index 0)
    - Add layout-order smoke: first `SectionCard` appears before `_GoalRingCard` / `GoalRing` in scroll column (compare `Offset.dy` or widget tree order)
    - Update `'shows three main cards'` — still expects `This week`, `Set goal`, `ActivityStatsRow`, `WeekProgressRow`
  - [x] `test/presentation/screens/app_scaffold_test.dart`: replace `find.text("Today's activity")` with scoped **Steps** screen title assertion
  - [x] Run `flutter analyze` + `flutter test`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**Epic 11 opens with layout + naming on the existing Today surface.** This story is intentionally narrow — reorder + title only.

| Area | In scope (11.1) | Out of scope (later stories) |
|------|-----------------|------------------------------|
| Card order | Week → ring → stats | Day pill tap / `selectedLocalDay` (11.2) |
| Screen title | **Steps** | Rename `TodayScreen` → `StepsScreen` file/class |
| Week card header | **This week** only | Trophy **X/7** badge (11.4) |
| Week dots / ring data | Unchanged (today's data) | Selected-day ring/stats/live guards (11.3) |
| Navigation | Already **STEPS** tab (10.1) | — |
| Version bump | None | Epic 11 close → `0.4.0+6` per sprint-change-proposal |

### Visual reference (authoritative)

**Mockup (Baptiste 2026-06-16):** Steps screen, light theme.

| Region | Mockup element | Implementation today | This story |
|--------|----------------|----------------------|------------|
| Top-left title | **Steps** (muted gray) | "Today's activity" | → **Steps** |
| Card 1 | **This week** + Mon–Sun pills + trophy 3/7 | Card 3 at bottom; no trophy | Move card to top; **no trophy yet** |
| Card 2 | Donut 3 750 / 10 000 + **Set goal** | Card 1 at top | Move below week card |
| Card 3 | Kcal · Km · Duration | Card 2 middle | Move to bottom |
| Bottom nav | STEPS active | Done (10.1) | No change |

**Prior mockup assets (5.9):** `assets/.../Today-light-17acf199-*.png`, `Today-dark-*.png` — ring/stats/week **styling** still valid; **order** superseded by Epic 11 mockup.

### Current file state (READ BEFORE EDITING)

`lib/presentation/screens/today_screen.dart` — **current column order (top → bottom):**

```dart
Text(_kScreenTitle)           // "Today's activity"
StatusBanner? (stale)
_GoalRingCard                 // ElevatedCard: GoalRing + Set goal
TextButton? (no permission)
ElevatedCard(ActivityStatsRow)
SectionCard('This week', WeekProgressRow)
```

**Target order:**

```dart
Text(_kScreenTitle)           // "Steps"
StatusBanner? (stale)
SectionCard('This week', WeekProgressRow)   // FIRST card
_GoalRingCard
TextButton? (no permission)
ElevatedCard(ActivityStatsRow)
```

**Preserve unchanged:**
- `SingleChildScrollView` + horizontal/bottom padding
- `_GoalRingCard` internals (`GoalCelebration`, `showGoalEditorSheet`, snackbar on save failure)
- `state.weekDays.isEmpty` → `CircularProgressIndicator` inside week card
- Stale banner variant `staleCompact` (UX-DR8 — tap still navigates to Data via existing `StatusBanner` behavior if wired)

### Architecture compliance

| Rule | Application |
|------|-------------|
| Presentation-only change | No SQLite, repository, or ingestion writes |
| `TodayCubit` refresh triggers | Unchanged — week data still loaded in `_loadWeekDays()` on refresh |
| Truth model (Story 2.9) | Ring/stats still reflect **today** until 11.2–11.3 |
| Goal history (Epic 8) | Week dots still use current goal resolution — historical per-day goals in 11.4 |
| No reactive streams | Layout story — no new streams |
| Review-before-commit | One commit per sub-task A/B/C per `docs/project-context.md` |

### Reuse — do NOT reinvent

| Need | Use existing |
|------|--------------|
| Week pills | `WeekProgressRow` + `WeekDayStatus` from `TodayState.weekDays` |
| Week section shell | `SectionCard(headline: 'This week', …)` |
| Ring + goal CTA | `_GoalRingCard` private widget — move block, don't duplicate |
| Stats | `ActivityStatsRow` in `ElevatedCard` |
| Screen title style | `AstraTypography.screenTitleFor(colors)` |
| Tab label | `AppBottomNav` already **STEPS** — no edit |

### Testing requirements

| Test file | Change |
|-----------|--------|
| `test/presentation/screens/screen_smoke_test.dart` | Title + layout order |
| `test/presentation/screens/app_scaffold_test.dart` | Remove "Today's activity" assertion |
| `test/presentation/widgets/week_progress_row_test.dart` | No change expected |
| `test/presentation/widgets/goal_ring_test.dart` | No change — ring label "Steps" stays |
| `test/presentation/cubits/today_cubit_test.dart` | No change — no state shape changes |

**Layout order test pattern (suggested):**

```dart
final weekCard = find.ancestor(
  of: find.text('This week'),
  matching: find.byType(SectionCard),
);
final ring = find.byType(GoalRing);
expect(tester.getTopLeft(weekCard).dy, lessThan(tester.getTopLeft(ring).dy));
```

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/screens/today_screen.dart` | **UPDATE** — reorder + title |
| `test/presentation/screens/screen_smoke_test.dart` | **UPDATE** |
| `test/presentation/screens/app_scaffold_test.dart` | **UPDATE** |

**Do not create** new screens, cubits, or widgets for 11.1.

### Library / framework requirements

- Flutter SDK per `pubspec.yaml` — no new dependencies
- `flutter_bloc` / existing `TodayCubit` contract unchanged
- Phosphor icons unchanged (nav + ring sneaker icon)

### Previous epic intelligence (Epic 10 — navigation shell)

Story **10.1** deliberately left `TodayScreen` content unchanged when switching to 3-tab nav:

- Tab 0 = `TodayScreen` (internal name kept)
- Nav label **STEPS** ≠ screen title until Epic 11
- `AppScaffold` cubit lifecycle, `postGoalUpdate`, ingestion callbacks — **do not modify** for layout story

Story **10.8** closed Epic 10 at `0.3.0+5`. Epic 11 version bump (`0.4.0+6`) happens at **epic close**, not per story.

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `f6f9a63` Epic 10 close, Data purge fix | Confirms shell stable; Steps is next surface |
| `9b40d4a` Data three-card layout | Pattern: mockup-driven **card order** refactor in single screen file + test updates |
| `84dac4c` Data/About tests | Test update style for screen copy assertions |

### Latest technical notes

- **Duplicate "Steps" text:** After title rename, both screen title and `GoalRing` center show "Steps". Tests must scope finders to `TodayScreen` title `Text` (first child of column) vs ring interior.
- **UX spec §2.3 order is stale:** `ux-design-specification.md` still lists ring-before-week (pre–Epic 11). **Epic 11 AC + mockup override** for this story.
- **Trophy placeholder:** Mockup shows trophy + `3/7` in week card header — **Story 11.4** adds this; do not add a stub badge in 11.1.

### Project context reference

- Review-before-commit workflow: `docs/project-context.md` § Development Workflow
- Versioning: Epic 11 close → `0.4.0+6` — `docs/project-context.md` § Versioning, `.cursor/rules/app-versioning.mdc`
- Sprint sequencing: Epic 8 → (9 ∥ 10) → (11 ∥ 12) — `sprint-change-proposal-2026-06-15.md`

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` § Epic 11, Story 11.1]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` § Epic 11]
- [Source: `_bmad-output/implementation-artifacts/stories/10-1-three-tab-bottom-navigation.md` — nav done, layout deferred]
- [Source: `_bmad-output/implementation-artifacts/stories/5-9-today-figma-layout-no-greeting.md` — card widgets + week strip baseline]
- [Source: `lib/presentation/screens/today_screen.dart` — file to reorder]
- [Source: `lib/presentation/widgets/app_bottom_nav.dart` — STEPS tab already shipped]
- [Source: `_bmad-output/planning-artifacts/architecture.md` § Today Display Truth Model]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

 - `flutter analyze lib/presentation/screens/today_screen.dart` ✅
 - `flutter analyze` ⚠️ existing repository info/warning set (no new issue from this story)
 - `flutter test test/presentation/screens/screen_smoke_test.dart test/presentation/screens/app_scaffold_test.dart test/presentation/widgets/week_progress_row_test.dart test/presentation/widgets/goal_ring_test.dart` ✅
 - `flutter test` ⚠️ existing unrelated failures in `test/widget_test.dart` (4 failing tests)

### Completion Notes List

 - Reordered `TodayScreen` layout to week-first while preserving stale banner, permission CTA location, and spacing tokens.
 - Renamed `TodayScreen` title/semantics label to `Steps` via `_kScreenTitle` without renaming screen/cubit classes.
 - Updated smoke tests to assert scoped Steps semantics and added explicit week-before-ring layout order assertion.
 - Verified targeted regression tests pass for updated screens and related week/ring widgets.

### File List

 - `lib/presentation/screens/today_screen.dart`
 - `test/presentation/screens/screen_smoke_test.dart`
 - `test/presentation/screens/app_scaffold_test.dart`

## Change Log

 - 2026-06-16: Implemented Story 11.1 (week-first Steps layout + title/semantics rename + smoke test updates).
