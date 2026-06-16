# Story 11.4: Week Trophy and Historical Goal Dots

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want a weekly score and per-day goal dots based on each day's actual goal,
So that I see how many days I hit target this week.

## Acceptance Criteria

1. **Given** the current calendar week Mon–Sun  
   **When** the **This week** card renders  
   **Then** a trophy badge in the card header shows **`X/7`** where **X** = count of week days with `steps ≥ getGoalForLocalDay(day)` and the day is **not in the future**  
   **And** the denominator is always **7** (full week), not "days elapsed"

2. **Given** past days in the week strip  
   **When** dots render  
   **Then** `goalMet` uses **historical** goal resolution via `getGoalForLocalDay(thatDay)` (Epic 8) — accent dot when met, invisible when missed  
   **And** future days show neutral gray dot (existing behavior)

3. **Given** the user changes their daily goal mid-week  
   **When** the week strip re-renders (refresh / goal save / metadata refresh)  
   **Then** past days keep `goalMet` scored against the goal that applied **on that day**  
   **And** today and future comparisons use the **new** goal from the change date forward

4. **Given** today is not a future day and `goalMet` is true for today in `weekDays`  
   **When** the trophy badge renders  
   **Then** today counts toward **X** (even though today's pill hides its dot when selected or `isToday`)

5. **Given** unit/widget tests  
   **When** tests run  
   **Then** cover:
   - trophy shows correct `X/7` for mixed goal-met / missed / future days
   - mid-week goal change leaves past `goalMet` unchanged (regression guard for Story 8.2)
   - existing `week_progress_row_test` and `today_cubit_test` week-strip group stay green

**Depends on:** Stories 8.2, 11.1, 11.2, 11.3.  
**Mockup ref:** `Today-light` (trophy + **3/7** in **This week** header; accent dots Mon–Wed).  
**Closes:** Epic 11 feature surface (layout → picker → selected-day truth → trophy).

## Tasks / Subtasks

- [x] **Sub-task A — `WeekTrophyBadge` widget + `SectionCard` header row** (AC: #1, #4)
  - [x] Add optional `trailing` widget to `SectionCard` — headline row becomes `Row` with `Expanded` title + trailing (preserve existing call sites; `trailing` defaults to null)
  - [x] Create `lib/presentation/widgets/week_trophy_badge.dart`:
    - props: `goalsMetCount`, `totalDays` (default 7)
    - Phosphor trophy icon (`PhosphorIconsRegular.trophy` or `Fill` — match mockup weight; ~16–20dp)
    - Text: `X/7` using `AstraTypography.captionFor` / `labelFor` with muted primary or `textPrimary`
    - Semantics label: e.g. `Goals met 3 of 7 days this week`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Wire trophy on Steps week card** (AC: #1, #4)
  - [x] In `today_screen.dart`, pass `SectionCard.trailing`:
    - when `state.weekDays.isEmpty`: omit trailing (loading spinner only)
    - else: `WeekTrophyBadge(goalsMetCount: _countGoalsMet(state.weekDays))`
  - [x] Add top-level or private helper (screen or small util):
    ```dart
    int countWeekGoalsMet(List<WeekDayStatus> days) =>
        days.where((d) => !d.isFuture && d.goalMet).length;
    ```
  - [x] Do **not** add new cubit state unless computation becomes non-trivial — derive from existing `weekDays`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Historical dots verification (no duplicate logic)** (AC: #2, #3)
  - [x] **Read** `_loadWeekDays()` in `today_cubit.dart` — it already resolves per-day goals via `getGoalForLocalDay(localDayIsoFromDateOnly(day))` and sets `goalMet` (Story 8.2)
  - [x] **Do not** reimplement goal resolution in the trophy widget or a parallel code path
  - [x] If audit finds a gap (e.g. today's `goalMet` stale vs live ring): patch **only** today's entry in `state.weekDays` inside `_applyLiveSteps` when `_isViewingToday()` — update `goalMet` for today's pill using live step count vs today's resolved goal; recompute trophy via derived count. **Skip** if SQLite refresh already matches ring in manual QA
  - [x] After `updateDailyStepGoal`, ensure `_refreshImpl` reloads `weekDays` so trophy + dots reflect new goal on today forward (existing refresh path — verify, don't break)
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (skip commit if verification-only with zero code changes — note in review brief)

- [x] **Sub-task D — Tests** (AC: #5)
  - [x] Add `test/presentation/widgets/week_trophy_badge_test.dart`: renders `3/7`, semantics label
  - [x] Extend `test/presentation/screens/screen_smoke_test.dart`: week card shows trophy text pattern `N/7` when week data loaded
  - [x] Extend `test/presentation/widgets/section_card_test.dart` (create if missing): trailing appears in header row
  - [x] Confirm existing `today_cubit_test.dart` case `goalMet respects per-day goals after mid-week change` still passes — add trophy-count assertion only if cubit/state gains a field (prefer widget-level count tests)
  - [x] Run `flutter analyze` + targeted tests
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| Area | In scope (11.4) | Out of scope |
|------|-----------------|--------------|
| Trophy **X/7** badge | Header of **This week** card | Achievements screen / gamification |
| Per-day dots | Verify Story 8.2 behavior; optional today live patch | Red/green status colors (UX uses accent only) |
| `goalMet` computation | Reuse `_loadWeekDays` | New repository queries |
| Ring / stats | Unchanged (11.3) | Trends trophy or streaks |
| Version bump | None | Epic 11 close → `0.4.0+6` per sprint plan |

### Critical: historical dots are largely DONE

**Do not reinvent `_loadWeekDays`.** Story 8.2 already implemented per-day `getGoalForLocalDay` for week pills:

```720:751:lib/presentation/cubits/today_cubit.dart
  Future<List<WeekDayStatus>> _loadWeekDays() async {
    // ...
    final goals = await Future.wait<int>([
      for (final day in weekDayKeys)
        userPreferences.getGoalForLocalDay(localDayIsoFromDateOnly(day)),
    ]);

    return [
      for (var i = 0; i < weekDayKeys.length; i++)
        WeekDayStatus(
          // ...
          goalMet:
              goals[i] > 0 && (stepsByDay[weekDayKeys[i]] ?? 0) >= goals[i],
        ),
    ];
  }
```

Regression test already exists: `goalMet respects per-day goals after mid-week change` in `today_cubit_test.dart`.  
**11.4 primary deliverable = trophy UI + wire-up + tests.**

### Current code state (READ BEFORE EDITING)

| File | Current behavior | 11.4 change |
|------|------------------|-------------|
| `section_card.dart` | Headline text only | Optional `trailing` in header `Row` |
| `today_screen.dart` | `SectionCard(headline: 'This week', child: WeekProgressRow…)` | Add `trailing: WeekTrophyBadge(…)` |
| `week_progress_row.dart` | Dots from `WeekDayStatus.goalMet` | **No change** unless today-live patch in C |
| `week_day_status.dart` | `goalMet`, `isFuture`, `isToday` | **No change** |
| `today_cubit.dart` | `_loadWeekDays` on refresh paths | Verify only; optional today live `goalMet` patch |

**Dot visibility rules (unchanged):**

```68:75:lib/presentation/widgets/week_progress_row.dart
    Color? dotColor;
    if (selected || isToday) {
      dotColor = null;
    } else if (day.isFuture) {
      dotColor = colors.neutralGray;
    } else if (day.goalMet) {
      dotColor = colors.accentPrimary;
    }
```

Today/selected pills hide dots — trophy still counts today when `goalMet` is true.

### Trophy count semantics

| Day type | Counts toward X? | goalMet source |
|----------|------------------|----------------|
| Past, steps ≥ that day's goal | Yes | `_loadWeekDays` + SQLite aggregates |
| Today, steps ≥ today's goal | Yes | Same (see live note below) |
| Future | No (excluded from X) | `isFuture == true` → never counted |
| Past, missed | No | `goalMet == false` |

**Display:** Always `X/7`, not `X/daysElapsed`. Mockup shows **3/7** mid-week.

### Live steps vs trophy (known behavior)

- Ring/stats for **today** use live overlay (Story 2.9 / 11.3).
- `weekDays` / dots / trophy reload on `_refreshImpl`, `refreshMetadata`, `updateDailyStepGoal` — **not** on every `_applyLiveSteps` tick.
- **Default for 11.4:** trophy derives from `weekDays` at last refresh — consistent with dots.
- **Optional polish (Sub-task C):** when viewing today and live steps cross goal, patch today's `WeekDayStatus.goalMet` in emitted state so trophy increments without waiting for SQLite sync. Keep patch localized; do not reload full week from DB on every tick.

### Visual reference (mockup)

From Story 11.1 mockup table:

| Element | Spec |
|---------|------|
| Position | **This week** card header, right-aligned opposite title |
| Content | Trophy icon + `3/7` (example) |
| Dots | Accent purple (`accentPrimary`) on goal-met past days Mon–Wed |
| Colors | No red/green — accent + invisible + neutral gray only |

### Architecture compliance

| Rule | Application |
|------|-------------|
| Presentation-first | Trophy is UI; count derived from existing domain model |
| Goal history (Epic 8) | Trophy must use same `goalMet` flags as dots — single source in `_loadWeekDays` |
| No reactive streams | No new `StreamController` |
| Phosphor icons | `phosphoricons_flutter` already in `pubspec.yaml` — no new deps |
| Review-before-commit | One commit per sub-task A–D per `docs/project-context.md` |
| Accessibility | `WeekTrophyBadge` semantics; trophy is informative, not a button |

### Recommended `SectionCard` change (minimal)

```dart
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.headline,
    required this.child,
    this.trailing,
    this.padding = AstraSpacing.kCardPadding,
    super.key,
  });

  final String headline;
  final Widget? trailing;
  // ...

  // Header:
  Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Text(headline, style: AstraTypography.headline(context)),
      ),
      if (trailing != null) trailing!,
    ],
  ),
```

**Check all `SectionCard` call sites** — `trailing` is optional; no visual change elsewhere.

### Reuse — do NOT reinvent

| Need | Use existing |
|------|--------------|
| Week day data | `TodayState.weekDays` |
| goalMet logic | `_loadWeekDays()` — do not duplicate |
| Per-day goal API | `userPreferences.getGoalForLocalDay` |
| Day ISO keys | `localDayIsoFromDateOnly` |
| Week pills UI | `WeekProgressRow` — unchanged |
| Card shell | `SectionCard` / `ElevatedCard` |
| Icons | `PhosphorIconsRegular.trophy` (verify glyph in Phosphor set) |

### Testing requirements

| Test file | Coverage |
|-----------|----------|
| `week_trophy_badge_test.dart` | **NEW** — icon + text + semantics |
| `section_card_test.dart` | **NEW or UPDATE** — trailing layout |
| `screen_smoke_test.dart` | Trophy visible on Steps with seeded data |
| `week_progress_row_test.dart` | **No regression** |
| `today_cubit_test.dart` | **No regression** — especially `goalMet respects per-day goals after mid-week change` |

**Widget test pattern for trophy count:**

```dart
testWidgets('shows 2/7 when two past days met goal', (tester) async {
  await pumpBadge(tester, goalsMetCount: 2);
  expect(find.text('2/7'), findsOneWidget);
});
```

**Smoke test:** pump `TodayScreen` with mocked `TodayCubit` emitting 7 `weekDays` with 3 `goalMet` past days → expect `3/7`.

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/widgets/week_trophy_badge.dart` | **NEW** |
| `lib/presentation/widgets/section_card.dart` | **UPDATE** — optional `trailing` |
| `lib/presentation/screens/today_screen.dart` | **UPDATE** — wire badge |
| `lib/presentation/cubits/today_cubit.dart` | **UPDATE only if** Sub-task C live patch needed |
| `test/presentation/widgets/week_trophy_badge_test.dart` | **NEW** |
| `test/presentation/widgets/section_card_test.dart` | **NEW or UPDATE** |
| `test/presentation/screens/screen_smoke_test.dart` | **UPDATE** |

**Do not create** a new screen or rename `TodayScreen`.

### Library / framework requirements

- Flutter SDK per `pubspec.yaml` — **no new dependencies**
- `phosphoricons_flutter` for trophy icon
- Immutable `WeekDayStatus` — if patching today live, use `copyWith` on list element or rebuild list immutably

### Previous story intelligence (11.3)

- Ring/stats follow `selectedLocalDay`; week strip data independent of selection
- `_refreshImpl` reloads `weekDays` even when viewing past day — trophy updates on refresh
- `goalMet` on week strip already uses historical goals; 11.3 explicitly deferred trophy to 11.4
- Live guards do not block week strip refresh — trophy benefits from refresh after goal save

### Previous story intelligence (11.2 / 11.1)

- Week card is **first** content block; title **Steps**
- `SectionCard(headline: 'This week')` — trophy goes in header trailing slot
- `WeekProgressRow` selection UI complete — no picker changes

### Previous story intelligence (8.2)

- `_loadWeekDays` per-day `getGoalForLocalDay` is the **canonical** week scoring path
- Mid-week goal change: Mon–Wed keep old goal for `goalMet`; Thu+ use new goal
- Do not use `getDailyStepGoal()` for any week comparison

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `1a76ff6` | GoalRing `localDayIso` guard when week empty — trophy should hide when `weekDays.isEmpty` |
| `f174d92` | Selected-day + live guard tests — don't break |
| `07eb729` / `ac3ad22` | Display truth split — trophy uses `weekDays`, not `state.steps` |
| `3ca1018` | Future day selection blocked — future days still show gray dots |

Follow pattern: small widget + screen wiring + tests per sub-task.

### Latest technical notes (2026)

- **Phosphor Icons:** package already used app-wide; trophy glyph name may be `trophy` — confirm in IDE autocomplete before committing
- **Flutter Row:** use `crossAxisAlignment: CrossAxisAlignment.center` for icon + text badge
- **No `figma_squircle`** needed for badge — simple `Row` + `Icon` + `Text`

### Project context reference

- Review-before-commit: `docs/project-context.md` § Development Workflow
- Versioning: Epic 11 close → `0.4.0+6` — not per story
- Sprint sequencing: `sprint-change-proposal-2026-06-15.md` § Steps screen order (trophy in week card header)

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` § Epic 11, Story 11.4]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` § 4.3 Steps screen]
- [Source: `_bmad-output/implementation-artifacts/stories/11-1-steps-screen-layout-week-first.md` § mockup table]
- [Source: `_bmad-output/implementation-artifacts/stories/11-3-selected-day-indicators-and-live-guards.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/8-2-goal-history-consumer-migration.md`]
- [Source: `lib/presentation/cubits/today_cubit.dart` § `_loadWeekDays`]
- [Source: `lib/presentation/widgets/week_progress_row.dart`]
- [Source: `lib/presentation/widgets/section_card.dart`]
- [Source: `lib/presentation/screens/today_screen.dart`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Sub-task C audit: `_loadWeekDays()` already uses `getGoalForLocalDay` per day; `updateDailyStepGoal` → `refresh()` → `_refreshImpl` reloads `weekDays`. No live-patch in cubit (trophy derives from refresh-time `weekDays`, consistent with dots).

### Completion Notes List

- Added `WeekTrophyBadge` (Phosphor trophy + `X/7`, semantics via `ExcludeSemantics`).
- Extended `SectionCard` with optional `trailing` header slot (`?trailing` null-aware element).
- Wired trophy on **This week** card; hidden while `weekDays` loading.
- `countWeekGoalsMet()` counts `!isFuture && goalMet` — today included when met.
- Historical dots unchanged (Story 8.2 path verified); no cubit changes.
- Tests: badge, section card, smoke (3/7 + loading omit), count helper, full cubit regression green (85 tests).

### File List

- `lib/presentation/widgets/week_trophy_badge.dart` (NEW)
- `lib/presentation/widgets/section_card.dart` (UPDATE)
- `lib/presentation/screens/today_screen.dart` (UPDATE)
- `test/presentation/widgets/week_trophy_badge_test.dart` (NEW)
- `test/presentation/widgets/section_card_test.dart` (NEW)
- `test/presentation/screens/today_screen_trophy_test.dart` (NEW)
- `test/presentation/screens/screen_smoke_test.dart` (UPDATE)

## Change Log

- 2026-06-16: Story 11.4 — week trophy badge X/7 in This week header; tests and SectionCard trailing slot.

## Story completion status

- Status: **review**
- Ultimate context engine analysis completed — comprehensive developer guide created
