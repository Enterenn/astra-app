# Story 23.6: Add Goal-Achieved Semantics in Week Day Pills

Status: in-progress

<!-- Post-audit Epic 23 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 23-6 · diagnostic-accessibilité-statique.md week_progress Majeur · AUD-30 · UX-AUD-05 · NFR-AUD-05 -->
<!-- Prerequisite: Story 23-5 — done (chart keyboard + selection semantics) -->
<!-- Version bump: deferred to Epic 23 close (minor+1, patch=0, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **TalkBack user**,
I want week day pills to announce whether the daily goal was achieved,
So that the coloured indicator is not color-only information.

## Acceptance Criteria

1. **Given** a past (or today) `_DayPill` with evaluable `WeekDayStatus.goalMet`
   **When** the semantics label is built
   **Then** the label includes day identity **and** achieved / not-achieved status (AUD-30)
   **And** identity uses localized weekday via `l10n.weekdayPillLabel(day.localDay)` + `day.dayNumber` (same as today)

2. **Given** `day.goalMet == true` (past or today — including when the accent **dot is visually suppressed** because selected or today)
   **When** TalkBack reads the pill
   **Then** label status fragment matches goal-met wording (reuse `chartGoalStatusMet` → `"goal met"` / `"objectif atteint"`, or equivalent dedicated key)
   **And** status is driven by `day.goalMet`, **not** by whether `dotColor != null`

3. **Given** a past or today pill with `day.goalMet == false`
   **When** semantics label is built
   **Then** label includes an explicit not-achieved fragment (new ARB — chart `BelowGoal` needs a step delta DayPill does not have)
   **And** EN ≈ `"goal not met"` · FR ≈ `"objectif non atteint"`

4. **Given** a future pill (`day.isFuture == true`)
   **When** semantics label is built
   **Then** label stays identity-only (`todayWeekDaySemantics` or equivalent without false "not met")
   **And** `button: false` / `onTap == null` behaviour is unchanged

5. **Given** existing `Semantics(selected:, button:)` on `_DayPill`
   **When** this story ships
   **Then** `selected` and `button` flags remain correct
   **And** visual children (weekday `Text`, day-number `Text`, decorative dot) are wrapped in `ExcludeSemantics` so the parent label is announced once (23-1 / 23-2 pattern)
   **And** visual goal-dot rules are unchanged (past + unselected + non-today + `goalMet` → accent dot; today/selected/future → no dot)

6. **Given** EN + FR ARB updates
   **When** keys are added/extended
   **Then** both `app_en.arb` and `app_fr.arb` are updated + `flutter gen-l10n`
   **And** preferred shape: extend or add sibling to `todayWeekDaySemantics` with a `{status}` placeholder (e.g. `todayWeekDaySemanticsWithStatus: "{weekdayLabel} {dayNumber}, {status}"`) — do **not** invent step/goal counts on the pill

7. **Given** widget tests in `week_progress_row_test.dart`
   **When** this story ships
   **Then** assert goal-met past pill label contains identity + met status
   **And** assert goal-not-met past pill label contains not-met status
   **And** assert future pill label has **no** goal status fragment
   **And** existing selected-semantics test still passes — after `ExcludeSemantics`, prefer `find.bySemanticsLabel(...)` over `find.text('2')` for `getSemantics`
   **And** visual dot / future-tap / French label tests still pass
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-30 · UX-AUD-05 (status never color-only) · NFR-AUD-05 · diagnostic-accessibilité-statique.md L255–258, L353

**Depends on:** Story 23-5 — **done** (Epic 23 a11y patterns established; no code dependency)

**Out of scope:** Keyboard focus on pills (not in AUD-30), `liveRegion` on pills (not required — avoid announcing seven pills on live step ticks), `WeekTrophyBadge` / `todayWeekGoalsMetSemantics` (already labelled), cubit/`WeekDayStatus` shape / goal math, settings `MergeSemantics` (23-7), red “missed” visual marker, version bump until Epic 23 closes.

## Tasks / Subtasks

- [x] **Sub-task A — ARB + label builder** (AC: #1, #2, #3, #4, #6)
  - [x] Add `todayWeekDaySemanticsWithStatus` (or extend existing key carefully — prefer sibling to avoid breaking future identity-only callers)
  - [x] Add `todayWeekDayGoalNotMet` (EN/FR); reuse `chartGoalStatusMet` for met fragment
  - [x] Helper in `_DayPill` (or small private function): if `day.isFuture` → `todayWeekDaySemantics`; else → withStatus(met ? chartGoalStatusMet : todayWeekDayGoalNotMet)
  - [x] `flutter gen-l10n`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — `_DayPill` Semantics + ExcludeSemantics** (AC: #1–#5)
  - [x] Set `Semantics.label` from helper; keep `selected` / `button`
  - [x] Wrap Column (or InkWell child content) in `ExcludeSemantics`
  - [x] Do **not** change `dotColor` rules, selection fill, or future `onTap: null`
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task C — Widget tests + regression** (AC: #7)
  - [ ] Extend `test/presentation/widgets/week_progress_row_test.dart`
  - [ ] Update selected-semantics finder if `ExcludeSemantics` breaks `getSemantics(find.text(...))`
  - [ ] `dart analyze` + `flutter test test/presentation/widgets/week_progress_row_test.dart` + `flutter test --exclude-tags slow`
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| `_DayPill` label includes goal status | Cubit / repository / SQL |
| ARB EN+FR + gen-l10n | Trophy badge copy |
| `ExcludeSemantics` on visual children | `liveRegion` / keyboard |
| Widget tests for label + regression | Story 23-7 MergeSemantics |

### Root cause (read before editing)

**Audit finding:** Goal-achieved accent **dot** is visual-only; `_DayPill` `Semantics.label` is `"{weekdayLabel} {dayNumber}"` with no status — Majeur / color-only info [Source: diagnostic-accessibilité-statique.md L255–258, L353 · AUD-30 · UX-AUD-05].

**Epic AC:** Label must include achieved / not-achieved **and** keep day identity [Source: epics-post-audit.md Story 23-6].

### Current implementation (UPDATE — do not rewrite)

```72:85:lib/presentation/widgets/week_progress_row.dart
    Color? dotColor;
    if (selected || isToday || day.isFuture) {
      dotColor = null;
    } else if (day.goalMet) {
      dotColor = colors.accentPrimary;
    }

    final weekdayLabel = l10n.weekdayPillLabel(day.localDay);

    return Semantics(
      label: l10n.todayWeekDaySemantics(weekdayLabel, day.dayNumber),
      selected: selected,
      button: onTap != null,
```

**Data already available — no model change:**

```18:19:lib/presentation/models/week_day_status.dart
  /// Past or today with `totalSteps >= daily goal`.
  final bool goalMet;
```

**Existing ARB (extend / sibling):**

- `todayWeekDaySemantics`: `"{weekdayLabel} {dayNumber}"` — keep for future / identity base
- `chartGoalStatusMet`: `"goal met"` / `"objectif atteint"` — **reuse** for met fragment
- Trophy (do not touch): `todayWeekGoalsMetSemantics`

### Recommended implementation approach

```dart
String _dayPillSemanticsLabel(AppLocalizations l10n, WeekDayStatus day) {
  final weekdayLabel = l10n.weekdayPillLabel(day.localDay);
  if (day.isFuture) {
    return l10n.todayWeekDaySemantics(weekdayLabel, day.dayNumber);
  }
  final status = day.goalMet
      ? l10n.chartGoalStatusMet
      : l10n.todayWeekDayGoalNotMet;
  return l10n.todayWeekDaySemanticsWithStatus(
    weekdayLabel,
    day.dayNumber,
    status,
  );
}

return Semantics(
  label: _dayPillSemanticsLabel(l10n, day),
  selected: selected,
  button: onTap != null,
  child: Material(
    child: InkWell(
      onTap: onTap,
      child: ExcludeSemantics(
        child: /* existing Container + Column unchanged */,
      ),
    ),
  ),
);
```

**Critical edge case — today / selected:** Dot is hidden when `selected || isToday`, but `goalMet` can still be true. Announce from **data**, not from `dotColor`, or TalkBack users lose status exactly when they focus the selected/today pill (common path).

**Do not:**

- Pass step/goal counts into pill labels (no data on widget)
- Use `chartGoalStatusBelowGoal(count)` (needs count)
- Add `liveRegion: true` on each pill
- Change `_loadWeekDays` / `_patchTodayGoalMetForLiveSteps`
- Break future `button: false` / tap no-op
- Invent a red missed-goal visual without product ask

### Consumers (verify — no edits expected outside pill + ARB + tests)

| Widget / file | Role |
|---------------|------|
| `WeekProgressRow` / `_DayPill` | **Primary edit** |
| `today_screen.dart` `_WeekSection` | Passes `vm.weekDays` — read-only |
| `WeekTrophyBadge` | Aggregate goals-met — unchanged |
| `TodayCubit` | Owns `goalMet` — unchanged |

### Architecture compliance

- **Presentation-only** — no cubit, repository, schema [Source: architecture.md layering]
- **OK commit gate** — one commit per sub-task; wait for Baptiste OK [Source: docs/project-context.md]
- **Design tokens** — no new colors; reuse existing accent dot
- **Localization** — ARB EN+FR + `flutter gen-l10n` only

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/widgets/week_progress_row.dart` | UPDATE — label helper, ExcludeSemantics |
| `lib/l10n/app_en.arb` | ADD status key(s) |
| `lib/l10n/app_fr.arb` | ADD status key(s) |
| `lib/l10n/app_localizations*.dart` | GENERATED via gen-l10n |
| `test/presentation/widgets/week_progress_row_test.dart` | ADD / UPDATE semantics assertions |

**No changes expected:** `today_cubit.dart`, `week_day_status.dart`, `week_trophy_badge.dart`, `today_screen.dart` (unless a finder-only test lives there)

### Testing requirements

- Default verify: `flutter test --exclude-tags slow` [Source: project-context.md § Test commands]
- Target file: `week_progress_row_test.dart`
- Pattern from existing selected test (adapt finder after ExcludeSemantics):

```225:237:test/presentation/widgets/week_progress_row_test.dart
  testWidgets('selected pill exposes semantics selected state', (tester) async {
    // ...
    final selected = tester.getSemantics(find.text('2'));
    expect(selected.flagsCollection.isSelected, Tristate.isTrue);
```

- New asserts (EN locale via default `TestMaterialApp`):
  - Past `goalMet: true` → label contains weekday + day number + `goal met` (or FR equivalent if locale fr)
  - Past `goalMet: false` → contains not-met phrase
  - Future → does **not** contain not-met / met phrases
- Keep visual tests: accent dot, no-dot past miss, future no-dot, French `MER`, future tap ignored

### Previous story intelligence

**From 23-5 (predecessor):**
- Status phrases live in ARB; charts reuse `chartGoalStatusMet` — pills should reuse the same met string for consistency
- Container-level `Semantics` + `ExcludeSemantics` on visuals is the Epic 23 standard
- Review lesson: clamp/edge cases matter — here the edge is **today/selected without visible dot** still needing status in the label
- Version bump still deferred to Epic 23 close

**From 23-2 / 23-1:**
- Closest structural twin: `button` + `selected` + `ExcludeSemantics` on text
- After ExcludeSemantics, tests must find nodes by semantics label, not by child `Text`

**From 23-3:**
- `liveRegion` is for continuous value widgets — **do not** apply to static week pills

### Git intelligence summary

Recent Epic 23 (23-5) commits:
- `fix(a11y): close story 23-5 — harden chart keyboard focus`
- `test(a11y): cover chart keyboard and selection semantics`
- `fix(a11y): add monthly chart selection semantics and ARB`
- `fix(a11y): announce daily chart selection via liveRegion`

Week pills untouched in 23-5. Last week-strip related churn: trophy icon migration. Existing `week_progress_row_test.dart` covers visuals + selected flag — **no** goal-status label coverage yet.

### Latest tech information

- **WCAG 1.4.1 Use of Color:** Information conveyed by color (accent goal dot) must also be available in text/semantics — label status fragment satisfies this for assistive tech [Source: UX-AUD-05 · AUD-30].
- **Flutter `ExcludeSemantics`:** Hides descendant Text from a11y tree so parent `Semantics.label` is not merged with `"TUE\n2"` duplicates [Flutter API docs].
- **Reuse over reinvent:** Prefer existing `chartGoalStatusMet` for the met fragment; only add not-met + with-status template keys.
- **No new dependencies** — Flutter SDK + existing l10n only.

### Project context reference

- OK commit gate + diff-only delivery: `docs/project-context.md`
- Version bump at Epic 23 close only: `sprint-status-post-audit.yaml` WORKFLOW NOTES
- Sprint tracker for post-audit: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` (**not** `sprint-status.yaml`)
- Audit source: `_bmad-output/planning-artifacts/audits/diagnostic-accessibilité-statique.md`
- Epic source: `_bmad-output/planning-artifacts/epics-post-audit.md` Story 23-6

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent)

### Debug Log References

### Completion Notes List

- Sub-task A: Added sibling ARB keys + `_dayPillSemanticsLabel` (future = identity-only; past/today = status from `goalMet`, reusing `chartGoalStatusMet`).
- Sub-task B: Wrapped pill visual content in `ExcludeSemantics`; kept `selected` / `button` / dot rules unchanged.

### File List

- `lib/l10n/app_en.arb`
- `lib/l10n/app_fr.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_fr.dart`
- `lib/presentation/widgets/week_progress_row.dart`
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`
- `_bmad-output/implementation-artifacts/stories/23-6-add-goal-achieved-semantics-in-week-day-pills.md`

### Change Log

- 2026-07-17: Story context created — ready-for-dev (create-story workflow)
- 2026-07-17: Sub-task A — ARB status keys + day-pill semantics label helper
- 2026-07-17: Sub-task B — ExcludeSemantics on day-pill visuals
