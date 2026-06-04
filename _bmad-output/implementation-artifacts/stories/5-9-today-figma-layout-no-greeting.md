# Story 5.9: Today Screen — Figma Layout (No Greeting)

Status: review

<!-- Baptiste 2026-06-04: Today light/dark mockups attached to create-story session. Three stacked cards; title replaces greeting; SourceChip removed. -->
<!-- Baptiste 2026-06-04 (decisions): calendar week Mon–Sun; week dots = invisible if goal not met / accentPrimary if met / neutralGray if future; Set goal + My Data both kept; inset surfaces = bgSubtle ("inner card"). -->

## Story

As a **user**,
I want Today's activity at a glance with goal, week progress, and reserved stats,
so that the home screen matches the redesigned Figma layout.

## Acceptance Criteria

1. **Given** the TODAY tab is selected  
   **When** the screen renders in light or dark theme with any accent preset (Story 5.8)  
   **Then** the layout matches Figma (session mockups: Today light / Today dark):  
   - Screen title **Today's activity** (top-left, `AstraTypography.captionFor` / muted)  
   - Optional compact stale `StatusBanner` below title (unchanged behavior, tap → Data tab)  
   - **Card 1** outer surface `bgElevated`, `kRadiusMd`: donut `GoalRing` + **Set goal** pill on **`bgSubtle`** (inner card / inset — Story 5.8 token name)  
   - **Card 2** outer `bgElevated`; stats row content on **`bgSubtle`** inset if mockup shows grey well — same inner-card token  
   - **Card 2** columns: Phosphor `Flame`, `MapPin`, `Clock`; values placeholder **`—`** until Epic 6 (row **visible**, not hidden)  
   - **Card 3** (`SectionCard` headline **This week**): seven vertical day pills (MON–SUN of the **calendar week** containing reference today)  
   **And** content scrolls above the floating nav without being clipped (bottom padding ≥ nav float offset from Story 5.7)

2. **Given** Story 4.8 greeting  
   **When** Today loads with or without `display_name` stored  
   **Then** **no** `Hello, {name}` line is shown  
   **And** `SourceChip` ("Phone sensor") is **not** rendered on Today (UX §2.3 — removed per product direction)

3. **Given** `GoalRing` in Card 1  
   **When** steps are shown (not loading / no-permission)  
   **Then** center content matches mockup: small sneaker icon (`PhosphorIconsRegular.sneakerMove`, `neutralGray`), label **Steps**, large formatted count (`formatStepCount`), goal line **`/{goal}`** with thin-space thousands (e.g. `/10 000`)  
   **And** ring track uses `accentPrimaryMuted`; progress arc uses `accentPrimary` (existing opacity rules for in-progress vs goal-met)  
   **And** `GoalCelebration` overlay behavior is unchanged (Story 2.6)

4. **Given** stats row (Epic 6 not done)  
   **When** Card 2 renders  
   **Then** each column shows icon + value `—` + unit label (**Kcal**, **Km**, duration as **HH:MM:SS** placeholder layout or `—` for value only — match mockup spacing)  
   **And** columns are separated by thin vertical dividers using `accentPrimary` at low opacity (mockup orange rules)

5. **Given** **This week** (Card 3)  
   **When** week data is loaded for the **calendar week** (Monday–Sunday containing reference today — best UX fit for label "This week")  
   **Then** each pill shows: optional status dot, three-letter weekday (`MON`…`SUN`), calendar date number  
   **And** **today** pill: filled `accentPrimary` background, text/date on `accentSecondary` (mockup)  
   **And** **past** days before today: if `steps >= daily_step_goal` → dot visible, color **`accentPrimary`**; if goal **not** met → **no visible dot** (reserved space OK, opacity 0 or `SizedBox` — no red/green semantic)  
   **And** **future** days (`localDay` after reference today): dot visible, color **`neutralGray`**; pill background stays default (not accent-filled)  
   **And** tapping a day pill does **not** navigate (display-only in 5.9)

6. **Given** **Set goal** pill tapped  
   **When** `showGoalEditorSheet` completes with a valid goal  
   **Then** validation matches Story 4.6 (1,000–100,000 integer)  
   **And** goal persists via `UserPreferencesRepository.setDailyStepGoal`  
   **And** `TodayCubit` refreshes ring + week strip; `HistoryCubit` goal refresh hook runs (mirror `postGoalUpdate` from My Data)

7. **Given** stale threshold exceeded  
   **When** Today is visible  
   **Then** compact stale banner may still link to Data tab (UX-DR8)

8. **Given** implementation complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no regressions; greeting tests replaced with title/layout tests; week + placeholder widget tests added

**Depends on:** Stories 5.8 (done), 5.7 (done), 5.6 Phosphor (done).  
**Prerequisite for:** Story 5.12 cohesion audit; Epic 6 fills stats values.  
**Out of scope:** Remove goal row from My Data → **5.10**; display name on Profil → **5.11**; real kcal/km/duration → **Epic 6**.

---

## Tasks / Subtasks

- [x] **A — Today layout shell** (AC: #1, #2, #7)
  - [x] Refactor `today_screen.dart`: drop `Expanded` 55/45 split; use `SingleChildScrollView` + horizontal padding + inter-card `kSpaceMd` gaps
  - [x] Add title **Today's activity**; remove greeting block and `SourceChip` import/usage
  - [x] Keep stale banner + permission `TextButton` below cards or under ring card as today (permission CTA must remain reachable)
  - [x] Bottom padding so Card 3 clears floating `AppBottomNav` (~`kBottomNavBottomOffset` + bar height)
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **B — Card 1: ring + Set goal** (AC: #1, #3, #6)
  - [x] Wrap ring in elevated card (reuse `SectionCard` without headline, or thin `TodayMetricCard` wrapper — same `bgElevated` + radius tokens)
  - [x] Update `goal_ring.dart` center copy + icon; ring track → `accentPrimaryMuted`
  - [x] Add centered **Set goal** pill on **`colors.bgSubtle`** (inner card — not `bgElevated`), `kRadiusFull`, `labelFor` text; opens `showGoalEditorSheet`
  - [x] Add `TodayCubit.updateDailyStepGoal(int)` (mirror `MyDataCubit` validation/persist); wire snackbar on failure
  - [x] `AppScaffold`: after Today save, `refreshMetadata` + `_historyCubit.refreshGoal()` (same as existing `postGoalUpdate`)
  - [x] **Stop → review → commit**

- [x] **C — Card 2: `ActivityStatsRow`** (AC: #1, #4)
  - [x] New `lib/presentation/widgets/activity_stats_row.dart` — three columns, Phosphor icons, placeholder `—`
  - [x] Widget test: icons + placeholders visible in light/dark `MaterialApp` with `buildAstraLightTheme` / `buildAstraDarkTheme`
  - [x] **Stop → review → commit**

- [x] **D — Card 3: `WeekProgressRow` + data** (AC: #1, #5)
  - [x] New `lib/presentation/widgets/week_progress_row.dart` — seven pills, states per AC #5
  - [x] Extend `TodayState` with `List<WeekDayStatus>` (or similar immutable model in `today_state.dart`)
  - [x] Load aggregates in `TodayCubit.refresh` / `_refreshImpl`: calendar week bounds via `LocalDayCalculator` + `stepRepository.getChartDailyAggregates(days: 30)` — **zero-fill** missing days
  - [x] Repository/unit test for week boundary math if new helper added
  - [x] **Stop → review → commit**

- [x] **E — Tests & cleanup** (AC: #2, #8)
  - [x] Replace `today_screen_test.dart` greeting group with: title visible; no `Hello,`; no `Phone sensor`; three cards smoke
  - [x] Optional: stop loading `displayName` in `TodayCubit` if unused (or leave until 5.11 — document choice in Dev Agent Record)
  - [x] Full `flutter test` + `flutter analyze`
  - [x] **Stop → review → commit**

---

## Dev Notes

### Visual reference (authoritative for this story)

| Asset | Path (workspace) |
|-------|------------------|
| Today dark | `assets/c__Users_Baptiste_AppData_Roaming_Cursor_User_workspaceStorage_838eccf53fbdedd221dd14ed672601e5_images_Today-dark-2a68b99c-bb2f-4469-ba1c-20564330e3be.png` |
| Today light | `assets/c__Users_Baptiste_AppData_Roaming_Cursor_User_workspaceStorage_838eccf53fbdedd221dd14ed672601e5_images_Today-light-17acf199-b929-4054-8803-52ccd3e9b948.png` |

**Card structure (top → bottom):**

1. Title row (not inside a card)  
2. Card — ring + Set goal  
3. Card — stats row (placeholders)  
4. Card — This week + pills  

### Architecture compliance

- **Presentation only** — no new ingestion, WM, or FGS changes  
- **Tokens:** `context.astraColors.*` only — no raw `Color(0x…)` (Story 5.8, V-2)  
- **Single writer:** goal still persists through `UserPreferencesRepository`  
- **Today Display Truth Model:** do not change `_applyTodaySnapshot` monotonic merge or live overlay (Story 2.9)  
- **Navigation:** keep index `0` = Today; stale → Data index `2`  
- **Review-before-commit:** one commit per sub-task A–E (`docs/project-context.md`)

### Current code state (READ before editing)

| File | Today | Change in 5.9 | Preserve |
|------|-------|---------------|----------|
| `lib/presentation/screens/today_screen.dart` | Greeting + flex ring + `SourceChip` | Scroll + 3 cards + title | `BlocBuilder`, celebration swap, stale banner, permission CTA |
| `lib/presentation/widgets/goal_ring.dart` | "steps today" / "goal N" | Icon + Steps + `/goal` | Progress math, a11y semantics, pulse loading, celebration stack |
| `lib/presentation/widgets/source_chip.dart` | Used on Today | **Remove usage** (widget file can remain for P1/deferred) | — |
| `lib/presentation/widgets/goal_editor_sheet.dart` | My Data only | Reuse on Today Set goal | Validation in `step_goal_validator.dart` |
| `lib/presentation/widgets/section_card.dart` | My Data sections | Card 3 headline **This week** | Token styling |
| `lib/presentation/cubits/today_cubit.dart` | Loads `displayName` | Add week load + `updateDailyStepGoal` | `refresh`, `attachLiveMonitor`, silent refresh |
| `lib/presentation/cubits/today_state.dart` | No week data | Add week pill model | Status enum + `progressRatio` |
| `lib/data/repositories/step_repository.dart` | `getChartDailyAggregates` | Reuse or add `getCalendarWeekAggregates()` | `getTodaySteps` unchanged |
| `test/presentation/screens/today_screen_test.dart` | Greeting tests | Title/layout tests | Seeded cubit pattern |

### Product decisions (Baptiste 2026-06-04)

| Topic | Decision |
|-------|----------|
| Week window | **Calendar week** Mon–Sun containing today (not rolling 7d) |
| Week dots | Past + goal met → **`accentPrimary`** dot; past + goal not met → **invisible** dot; future → **`neutralGray`** dot |
| Set goal | **Today + My Data** both remain until Story 5.10 |
| Inset / “inner card” color | **`AstraColors.bgSubtle`** (`#EEF0F4` light / `#3E4457` dark — Story 5.8 “Inner card / inset surface”) |

### Week strip logic (implement exactly)

**Calendar week** = Monday-start week containing `referenceToday` (`TimeProvider` / `LocalDayCalculator`).

| Pill background | Dot | Condition |
|-----------------|-----|-----------|
| `accentPrimary` fill | hidden or same as pill | `localDay == referenceToday` (today) |
| default (`bgElevated` / transparent on card) | **none** (invisible) | past day, `totalSteps < goal` |
| default | **`accentPrimary`** | past day, `totalSteps >= goal` |
| default | **`neutralGray`** | `localDay.isAfter(referenceToday)` (future) |

Goal for comparison: current `daily_step_goal` from prefs at refresh time (same as ring).

**Do not** use rolling "last 7 days" (Trends FR-17 only). **Do not** use `statusOk` green or `statusDanger` red for week dots — accent-only + invisible + neutral.

### Goal ring copy (Figma vs legacy)

| Element | Legacy (remove) | Figma (use) |
|---------|-----------------|-------------|
| Sublabel | "steps today" | **Steps** |
| Goal line | "goal 8 000" | **/8 000** (leading slash, same formatter) |
| Icon | none | `sneakerMove` Phosphor, ~20dp, muted |

### Surface tokens (cards vs inner card)

| Layer | Token | UX / Story 5.8 name |
|-------|--------|---------------------|
| Screen background | `bgBase` | App background |
| Card shell (Cards 1–3) | `bgElevated` | Card background |
| Inset wells (Set goal pill, stats row fill) | **`bgSubtle`** | **Inner card / inset surface** — Baptiste “innercard” |

### Set goal on Today vs My Data

- **5.9:** Add Set goal on Today; **keep** My Data goal editor until **5.10** (both entry points OK per Baptiste)  
- Reuse `showGoalEditorSheet` — do not duplicate sheet UI

### Library / framework

- `phosphoricons_flutter` already in `pubspec.yaml` (Story 5.6)  
- No new dependencies expected  
- `figma_squircle` not required for week pills (use `BorderRadius.circular(kRadiusFull)` vertical capsules)

### Testing requirements

| Area | Minimum tests |
|------|----------------|
| `today_screen_test.dart` | Title; no greeting; no SourceChip label |
| `activity_stats_row_test.dart` | Three `—` placeholders + icons |
| `week_progress_row_test.dart` | Today accent fill; past goal met → `accentPrimary` dot; past not met → no dot; future → `neutralGray` dot |
| `goal_ring_test.dart` | Update golden/copy expectations if existing |
| Regression | Full `flutter test` |

### Previous story intelligence (5.8)

- Accent presets wired: ring/nav/buttons use `accentPrimary` / `accentPrimaryMuted` / `accentSecondary`  
- Week strip dots use **`accentPrimary`** when visible (preset-aware), not `statusOk` green  
- **`bgSubtle`** = inner card inset (`#EEF0F4` / `#3E4457`) — use for Set goal pill background  
- Chart colors (`dataPositive`) are unrelated to Today stats placeholders

### Previous story intelligence (5.7)

- Floating nav: reserve bottom scroll padding; Today is scrollable now — verify on device with text scale 1.3  
- Tab icon `sneakerMove` matches ring center icon choice

### Git intelligence

Recent commits: accent preset theme (5.8), four-tab nav (5.7), Phosphor dependency (5.6). Follow established patterns: semantic colors, cubit refresh hooks in `app_scaffold.dart`, widget tests colocated under `test/presentation/`.

### Project context reference

- [Source: docs/project-context.md] — review-before-commit per sub-task  
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md §2.3] — layout order, widget names  
- [Source: _bmad-output/planning-artifacts/epics.md § Story 5.9]  
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-06-04.md] — stats placeholders until Epic 6  
- [Source: _bmad-output/implementation-artifacts/stories/5-8-accent-preset-theme-tokens.md] — token table  
- [Source: _bmad-output/implementation-artifacts/stories/4-8-local-display-name-and-today-greeting.md] — greeting **retired** here, name prefs untouched

---

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- Week aggregates use `getChartDailyAggregates(days: 30)` (API allows 7|30 only; not 14).

### Completion Notes List

- Today: scroll layout with title **Today's activity**, three elevated cards, no greeting/`SourceChip`.
- `GoalRing`: Phosphor sneaker, **Steps** label, `/goal` line, `accentPrimaryMuted` track.
- **Set goal** on Today via `showGoalEditorSheet` + `TodayCubit.updateDailyStepGoal` + `postGoalUpdate` → `HistoryCubit.refreshGoal()`.
- `ActivityStatsRow` + `WeekProgressRow` widgets; calendar week via `CalendarWeek` + `WeekDayStatus` in `TodayState`.
- `displayName` still loaded in cubit (unused on Today until story 5.11).
- `flutter test` (557 tests) and `flutter analyze` (info-only elsewhere) pass.

### File List

- lib/core/time/calendar_week.dart
- lib/presentation/models/week_day_status.dart
- lib/presentation/widgets/activity_stats_row.dart
- lib/presentation/widgets/week_progress_row.dart
- lib/presentation/screens/today_screen.dart
- lib/presentation/widgets/goal_ring.dart
- lib/presentation/cubits/today_cubit.dart
- lib/presentation/cubits/today_state.dart
- lib/presentation/screens/app_scaffold.dart
- test/core/time/calendar_week_test.dart
- test/presentation/widgets/activity_stats_row_test.dart
- test/presentation/widgets/week_progress_row_test.dart
- test/presentation/screens/today_screen_test.dart
- test/presentation/widgets/goal_ring_test.dart
- test/presentation/screens/app_scaffold_test.dart
- test/widget_test.dart

### Change Log

- 2026-06-04: Story 5.9 — Figma Today layout (no greeting), stats placeholders, calendar week strip, Set goal on Today.

---

## Story completion status

- **Status:** review  
- **Completion note:** Implemented 2026-06-04. Ready for code review (prefer different LLM than implementer).
