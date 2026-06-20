# Story 20.2: Local Trends Insight Cards

Status: review

<!-- Refacto Epic 20 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 20-2 · refactoring-audit-master-v0.6.1.md §5.3 · REF-24 · UX-REF-05 -->
<!-- Prerequisite: Story 20-1 done · Epic 19 l10n complete (0.9.0+19) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want plain-language insights about my walking habits,
So that Trends feels valuable without cloud analytics.

## Acceptance Criteria

- [ ] **AC #1** — **Given** at least 7 calendar days of step history in the 30-day aggregate window
  **When** Trends loads (7d or 30d period, not 12-month)
  **Then** three locally computed insight cards display below the chart block (UX-REF-05, REF-24):
  1. **Weekly change** — week-over-week step total comparison (reuse existing `TrendSnapshot` logic)
  2. **Most active weekday** — weekday with highest average steps across available history in window
  3. **Goal streak** — count of consecutive calendar days (newest-first from today) where `totalSteps >= resolvedGoalForDay`

- [ ] **AC #2** — **Given** fewer than 7 calendar days with any step data in the 30-day window
  **When** insights cannot be computed reliably
  **Then** insight cards show a **calm empty state** (single localized message per card or shared section) — **not** errors, spinners, or red banners
  **And** chart + existing average/peak widgets behave unchanged

- [ ] **AC #3** — **Given** weekly comparison needs 14 days of history
  **When** 7–13 days exist
  **Then** weekly-change card shows calm empty copy (e.g. "Not enough history for weekly comparison") — **not** the general `<7 days` empty state
  **And** weekday + streak cards still render when their own thresholds are met

- [ ] **AC #4** — **Given** all insight calculations
  **When** inspected in code or tests
  **Then** they run in Dart from cached `getChartDailyAggregates` + `_cachedGoalsByDay` — **zero network calls**
  **And** period toggle (7d ↔ 30d) recomputes insights from cache without extra repository reads

- [ ] **AC #5** — **Given** copy on insight cards
  **When** rendered in `en` or `fr`
  **Then** strings come from ARB keys only (UX-REF-05)
  **And** tone is calm and factual — no exclamation marks, coach language, streak shame, or cloud/analytics implication
  **And** streak copy states fact only (e.g. "3 consecutive days above goal") — never "Keep it up!" or gamification

- [ ] **AC #6** — **Given** 12-month period selected
  **When** Trends renders
  **Then** insight cards are **hidden** (monthly view unchanged — insights are daily-window only)

- [ ] **AC #7** — **Given** `flutter test --exclude-tags slow`
  **When** run after implementation
  **Then** all tests pass
  **And** new cubit tests cover: weekday tie-break, streak with varying goals, `<7` empty, `7–13` weekly empty, cache-only period toggle

- [ ] **AC #8** — **Given** work completes on branch `refacto`
  **When** story is marked done
  **Then** **no version bump** — Epic 20 closes with minor+1 (`0.10.0+20`) when story 20-5 is done

**Covers:** REF-24 · UX-REF-05 · Audit §5.3 (local Trends insights)

**Depends on:** Story 20-1 done · Epic 16 repository contracts (`StepAggregationRepositoryContract`, `UserHealthMetricsRepositoryContract`) · Epic 12 Trends stats foundation.

**Out of scope:** Replacing `fl_chart` (20-4); tab haptics (20-3); Phosphor subsetting (20-5); 12-month insight cards; moving/removing Epic 12 `TrendsAverageStatsRow` or `TrendsPeakDayCard`; version bump; extracting `CaptionPill` from `trend_chip.dart` (deferred to 20-5 per 20-1 review).

## Tasks / Subtasks

- [x] **Sub-task A — State models + cubit computations** (AC: #1, #2, #3, #4)
  - [x] Read `history_state.dart`, `history_cubit.dart`, `history_cubit_test.dart` fully before editing
  - [x] Add immutable models to `history_state.dart`:
    - `TrendsMostActiveWeekday { int weekday; int averageSteps; }` — `weekday` is `DateTime.monday`…`DateTime.sunday`
    - `TrendsGoalStreak { int consecutiveDays; }` — 0 means no active streak; card hidden or empty when 0
    - `TrendsInsightAvailability { bool hasMinimumHistory; bool hasWeeklyComparison; }` — drives empty states
  - [x] Extend `HistoryState` with nullable `mostActiveWeekday`, `goalStreak`, `insightAvailability`
  - [x] Implement pure computation helpers in `history_cubit.dart` (or extract to `lib/core/metrics/trends_insights.dart` if >~40 lines):
    - `_countDaysWithSteps(List<ChartDayAggregate>)` — days where `totalSteps > 0`
    - `_computeMostActiveWeekday(aggregates, period)` — bucket by `localDay.weekday`, average steps per weekday across days that have steps; tie-break: higher average wins, then later calendar occurrence in window
    - `_computeGoalStreak(newestFirst aggregates, goalsByDay, fallbackGoal)` — walk from index 0 (today); stop at first day where `totalSteps < goalForDay`; skip zero-step days **without breaking streak** only if product decision matches audit (default: **zero-step day breaks streak**)
    - `_computeInsightAvailability(aggregates)` — `hasMinimumHistory = daysWithSteps >= 7`; `hasWeeklyComparison = daysWithSteps >= 14` (30-day cache is always length 30)
  - [x] Wire into `_emitReady` for 7d/30d periods; clear insight fields on `months12` branch
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — ARB keys + l10n helpers** (AC: #5)
  - [x] Add ARB keys (minimum):

    | Key | English | French |
    |-----|---------|--------|
    | `trendsInsightWeeklyTitle` | Weekly change | Évolution hebdomadaire |
    | `trendsInsightWeekdayTitle` | Most active day | Jour le plus actif |
    | `trendsInsightStreakTitle` | Goal streak | Série au-dessus de l'objectif |
    | `trendsInsightInsufficientData` | Not enough history yet. Keep walking — data stays on this device. | Pas assez d'historique. Continuez à marcher — les données restent sur cet appareil. |
    | `trendsInsightWeeklyInsufficientData` | Not enough history for weekly comparison. | Pas assez d'historique pour comparer les semaines. |
    | `trendsInsightMostActiveWeekday` | {weekday} averages the most steps | {weekday} est votre jour le plus actif en moyenne |
    | `trendsInsightGoalStreak` | {count} consecutive days above goal | {count} jours consécutifs au-dessus de l'objectif |
    | `trendsInsightGoalStreakOne` | 1 consecutive day above goal | 1 jour consécutif au-dessus de l'objectif |
    | `trendsInsightWeeklyUp` | Up {percentage}% from last week | En hausse de {percentage} % la semaine dernière |
    | `trendsInsightWeeklyDown` | Down {percentage}% from last week | En baisse de {percentage} % la semaine dernière |
    | `trendsInsightWeeklyFlat` | Same as last week | Identique à la semaine dernière |
    | `trendsInsightWeeklyNoPrior` | No prior week data | Pas de données la semaine précédente |

  - [x] Reuse `weekdayShort()` from `l10n_date_labels.dart` for `{weekday}` placeholder — add `formatMostActiveWeekdayInsight(int weekday)` helper if needed
  - [x] Run `flutter gen-l10n`; commit generated Dart with ARB
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Insight card widgets + screen layout** (AC: #1, #2, #5, #6)
  - [x] Read `trends_peak_day_card.dart`, `elevated_card.dart`, `history_screen.dart` fully
  - [x] Create `lib/presentation/widgets/trends_insight_cards.dart`:
    - `TrendsInsightCardsSection` — column of up to 3 `ElevatedCard` insights
    - Each card: small Phosphor icon (reuse set: `chartLineUp`, `calendar`, `target` or similar — note glyphs for 20-5), title (`AstraTypography.labelFor`), body (`AstraTypography.captionFor` or `dataFor` for streak count)
    - Empty card variant: muted caption using `trendsInsightInsufficientData` / weekly-specific key
    - Full `Semantics` labels per card
  - [x] Integrate in `history_screen.dart`:
    - Place **below** `TrendsPeakDayCard` block (after averages + peak), **above** bottom padding
    - Show only when `state.period != HistoryPeriod.months12` and `state.status == HistoryStatus.ready`
    - **Remove or keep** existing standalone `TrendChip` above chart — **recommended: remove duplicate** and fold weekly change into insight card #1 to avoid two weekly widgets; if kept, ensure copy differs (chip vs card). Prefer **single weekly insight in card section only**.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Tests** (AC: #7)
  - [x] Extend `test/presentation/cubits/history_cubit_test.dart`:
    - `mostActiveWeekday`: Tue wins when Tue avg > others; tie-break test
    - `goalStreak`: 3 days above goal then miss → streak 3; varying goals via `goalsByDay`
    - `<7` days with steps → insight fields null + `hasMinimumHistory == false`
    - `7–13` days → weekday/streak available, weekly comparison empty
    - `selectPeriod` updates insights without incrementing spy `chartAggregateCallCount`
  - [x] Optional widget smoke: pump `HistoryScreen` with mocked `HistoryCubit` state — assert insight card semantics labels visible
  - [x] Run `flutter analyze` + `flutter test test/presentation/cubits/history_cubit_test.dart` + `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Three local insight cards (weekly, weekday, streak) | 12-month insights |
| Cubit computation from cached SQLite aggregates | New repository methods or SQL |
| Calm empty states for insufficient data | Error banners or retry CTAs |
| EN/FR ARB keys + gen-l10n | Additional locales |
| Cubit unit tests | Chart rewrite (20-4) |
| Consolidate weekly UI into insight cards (remove duplicate TrendChip if redundant) | Removing Epic 12 average/peak cards |

### Critical baseline — what already exists (do NOT reinvent)

Epic 12 shipped Trends analytics UI. Story 20-2 **adds audit §5.3 insights**, not a full Trends rewrite.

| Feature | Status | Location |
|---------|--------|----------|
| Weekly week-over-week % | **Done** — `TrendSnapshot` + `_computeTrend()` | `history_cubit.dart:379-423` |
| Weekly UI pill | **Done** — `TrendChip` above chart | `history_screen.dart:73-79`, `trend_chip.dart` |
| Period averages | **Done** — `TrendsPeriodAverages` | Epic 12-1 |
| Peak day card | **Done** — `TrendsPeakDayCard` | Epic 12-2 |
| ARB weekly strings | **Done** — `trendsWeeklyGrowth/Decline/Flat/NoPriorWeek` | `app_en.arb` lines 27-52 |

**Gap vs REF-24 / audit §5.3:**

1. **Most active weekday** — not implemented anywhere
2. **Goal streak** — not implemented (UX spec forbids streak *shame* but factual streak count is explicitly requested in audit)
3. **Formal insight cards** — weekly change is a small pill, not an `ElevatedCard` insight; weekday + streak missing entirely
4. **`<7` day calm empty state** — no insight-specific empty handling

### Critical baseline — HistoryCubit data flow

```94:173:lib/presentation/cubits/history_cubit.dart
  Future<void> _refreshImpl({required bool silent}) async {
    ...
      final fetchResults = await Future.wait<Object>([
        stepAggregation.getChartDailyAggregates(days: 30),
        stepAggregation.getChartMonthlyAggregates(months: 12),
      ]);
    ...
      _cachedAggregates30d = aggregates;
      _cachedGoalsByDay = goalsByDay;
      _cachedDayMetrics30d = dayMetrics;
      _emitReady(...);
```

- Aggregates are **newest-first** (`ChartDayAggregate.localDay`)
- `_cachedGoalsByDay` keyed by `YYYY-MM-DD` ISO — use `localDayIsoFromDateOnly(aggregate.localDay)` for lookup; fallback to `state.dailyGoal`
- `_emitReady` for 7d/30d already computes `trend`, `periodAverages`, `peakDay` — **extend here** for insight fields
- `selectPeriod` must recompute insights from cache (same pattern as `peakDay` / `periodAverages`)

### Computation specifications

#### Minimum history threshold

- **`hasMinimumHistory`:** count distinct calendar days in `_cachedAggregates30d` where `totalSteps > 0` ≥ **7**
- When false: all three cards show `trendsInsightInsufficientData` (calm, identical copy OK per UX-REF-05)

#### Weekly change card

- Reuse `_computeTrend(_cachedAggregates30d)` — requires **14** rows (not 7)
- Map `TrendSnapshot` → card body using existing `trendLabel()` or new insight-specific ARB keys
- When `trend == null` and `hasMinimumHistory` but `<14` days: show `trendsInsightWeeklyInsufficientData`
- When prior week empty: reuse `trendsNoPriorWeek` / `trendsInsightWeeklyNoPrior` copy

#### Most active weekday

- Use full `_cachedAggregates30d` (not period slice) for stable weekday signal — **or** slice to active period; **recommended: use 30d window always** for weekday insight regardless of 7d/30d chart toggle (document in review brief if Baptiste prefers period-scoped)
- Group by `localDay.weekday` (1=Mon … 7=Sun)
- For each weekday: `averageSteps = sum(steps on that weekday) / count(days on that weekday)` — only days with `totalSteps > 0` in denominator
- Pick max average; tie-break: higher sum wins, then prefer more recent day in window

#### Goal streak

- Walk `_cachedAggregates30d` newest-first (index 0 = today)
- For each day: `goal = goalsByDay[iso] ?? dailyGoal`; if `totalSteps >= goal` increment streak, else **break**
- **Zero-step days:** break streak (conservative, factual — user did not exceed goal)
- Emit `TrendsGoalStreak(consecutiveDays: n)`; when `n == 0`, card shows empty state or hides body (prefer empty state for layout consistency)

### Recommended UI layout

```
[Trends title]
[PeriodToggle 7d | 30d | 12m]
[Chart — StepBarChart or Monthly]
[TrendsAverageStatsRow]        ← Epic 12, keep
[TrendsPeakDayCard]            ← Epic 12, keep
[TrendsInsightCardsSection]    ← NEW Story 20-2
  ┌ Weekly change ─────────┐
  │ Up 12% from last week  │
  └────────────────────────┘
  ┌ Most active day ───────┐
  │ Tuesday averages most  │
  └────────────────────────┘
  ┌ Goal streak ───────────┐
  │ 3 consecutive days...  │
  └────────────────────────┘
```

- Remove standalone `TrendChip` row above chart when weekly insight card ships (avoid duplicate weekly messaging)
- Spacing: `kSpaceMd` between insight cards; match `TrendsPeakDayCard` horizontal stretch
- Icons: minimal Phosphor set — document glyph names in review brief for story 20-5 inventory

### Reuse existing components

| Component | Reuse |
|-----------|-------|
| `ElevatedCard` | Insight card shell — same as peak/average cards |
| `AstraTypography.*For(colors)` | Title, body, caption |
| `l10n_date_labels.weekdayShort()` | Weekday name in insight copy |
| `CaptionPill` / `TrendChip` | **Do not reuse for insights** — insights are full cards per audit |

### Previous story intelligence (20-1)

| Learning | Application |
|----------|-------------|
| ARB + `flutter gen-l10n` for all user strings | New insight keys in `app_en.arb` / `app_fr.arb` only |
| `CaptionPill` in `trend_chip.dart` — extraction deferred to 20-5 | Insight cards use `ElevatedCard`, not `CaptionPill` |
| Sub-task stop → review → commit gate | Follow for each sub-task A–D |
| Sprint tracker: `sprint-status-refacto.yaml` | Update when story moves to done |
| 815+ fast tests at 20-1 close | Regression bar unchanged |
| No mid-epic version bump | Epic 20 bumps at **20-5 close** only |
| Branch `refacto` only | Do not merge to main from this story |

### Previous story intelligence (Epic 12 — Trends foundation)

| Learning | Application |
|----------|-------------|
| `history_cubit_test.dart` uses sqflite FFI + inject fixtures | Extend same test patterns for insight computations |
| Period toggle reads from cache — spy confirms no extra DB calls | Insight recompute must follow same cache-only pattern |
| `TrendsPeakDayCard` + `TrendsAverageStatsRow` shipped and tested via cubit | Keep untouched unless layout spacing adjustment needed |
| Peak day hidden when zero-step window | Insight section still shows empty states, not hidden entirely |

### Git intelligence

Recent commits (2026-06-20):

- `c66796d` — Story 20-1 closed after code review
- `ab11427`–`2a5e0cf` — onboarding trust pills + tests
- Trends module stable since Epic 12; no in-flight HistoryCubit work expected

Branch: `refacto`. Base version: `0.9.0+19`.

### Architecture compliance

| Rule | Application |
|------|-------------|
| REF-24 | Local insight cards from SQLite aggregates |
| UX-REF-05 | Calm, local-only copy — no cloud/analytics wording |
| UX §4.6 | Factual tone — no coach language or exclamation marks |
| FR-16/17 | Trends chart unchanged; insights are additive |
| NFR-1 / KPI-01 | Insight compute on cached data — no chart bind regression |
| Repository contracts | Use injected `stepAggregation` / `userHealthMetrics` — no concrete repo imports in cubit |
| Presentation l10n via ARB | No hardcoded insight strings |
| Review-before-commit | One commit per sub-task after Baptiste OK |

### Cross-story roadmap (Epic 20)

| Story | Responsibility |
|-------|----------------|
| 20-1 | Onboarding trust emphasis ✅ |
| **20-2 (this)** | Local Trends insight cards |
| 20-3 | Tab haptic feedback |
| 20-4 | Replace fl_chart with CustomPainter — **do not touch chart widgets here** |
| 20-5 | Phosphor subsetting + **Epic 20 version bump** `0.10.0+20` |

### Testing requirements

```bash
flutter gen-l10n
flutter analyze
flutter test test/presentation/cubits/history_cubit_test.dart
flutter test --exclude-tags slow
```

**New cubit tests (minimum):**

| Test | Asserts |
|------|---------|
| `mostActiveWeekday` winner | Correct weekday from seeded Mon–Sun pattern |
| `mostActiveWeekday` tie-break | Higher average / sum wins |
| `goalStreak` consecutive | 3 days above goal → streak 3 |
| `goalStreak` varying goals | `goalsByDay` map respected per day |
| `goalStreak` break on miss | Day below goal stops count |
| `<7` days with steps | `hasMinimumHistory == false`; cards get empty state |
| `7–13` days | Weekly card empty; weekday/streak may render |
| `selectPeriod` insights | Insights update; spy `chartAggregateCallCount` unchanged |

**Manual checklist:**

1. Fresh install / empty DB → Trends shows chart empty state; insight cards show calm insufficient copy (not errors)
2. Inject 7+ days → three insight cards populate with factual copy
3. Toggle 7d ↔ 30d → insights update without loading flash
4. Switch to 12 months → insight cards hidden
5. Device language FR → insight copy in French
6. Verify no network calls (airplane mode — insights still work from local DB)

### Project structure notes

- Story file: `_bmad-output/implementation-artifacts/stories/20-2-local-trends-insight-cards.md`
- Sprint tracker: `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml`
- **Primary modified:** `history_state.dart`, `history_cubit.dart`, `history_screen.dart`, `trends_insight_cards.dart` (new), `app_*.arb`, `l10n_date_labels.dart` (optional helper), `history_cubit_test.dart`
- **Likely unchanged:** chart widgets, repository layer, `TrendsAverageStatsRow`, `TrendsPeakDayCard`
- Optional extract: `lib/core/metrics/trends_insights.dart` if cubit grows — pure functions ease unit testing
- Do **not** rewrite `docs/BETA_CHECKLIST.md` historical rows

### Anti-patterns — do NOT

- Add network calls or cloud analytics APIs for insights
- Use coach copy ("Great job!", "Keep your streak alive!")
- Show errors/exception text in insight cards for insufficient data
- Import concrete repositories in `HistoryCubit` — keep contracts
- Add SQL queries for insights — use existing aggregates + goals map
- Remove Epic 12 average/peak cards without explicit approval
- Bump `pubspec.yaml` version — Epic 20 closes on story 20-5
- Refactor `fl_chart` or chart painters — that's story 20-4
- Hardcode weekday names in English/French in widgets

### Latest technical notes

- `HistoryCubit._computeTrend` already handles edge cases (prior week empty → flat with null percent) — mirror in weekly insight card
- `flutter_bloc` Cubit — extend state immutably via `copyWith`; add new fields to `copyWith` signature
- `inject90Days` test fixture provides 14+ days for weekly comparison tests
- Phosphor icons: keep glyph count minimal; list new icons in review brief for 20-5 subsetting inventory

### References

- [Source: _bmad-output/planning-artifacts/epics-refacto.md#Story 20-2]
- [Source: _bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md#5.3]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#2.4, #4.6]
- [Source: _bmad-output/implementation-artifacts/stories/20-1-onboarding-permission-after-value-proposition.md]
- [Source: lib/presentation/cubits/history_cubit.dart]
- [Source: lib/presentation/cubits/history_state.dart]
- [Source: lib/presentation/screens/history_screen.dart]
- [Source: lib/presentation/widgets/trends_peak_day_card.dart]
- [Source: lib/presentation/l10n/l10n_date_labels.dart]
- [Source: test/presentation/cubits/history_cubit_test.dart]
- [Source: docs/project-context.md — review-before-commit]

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent)

### Debug Log References

- `hasWeeklyComparison` uses `countDaysWithSteps >= 14` (not `aggregates.length`) because the 30-day cache is always zero-filled to 30 rows.

### Completion Notes List

- Added three local insight cards (weekly change, most active weekday, goal streak) computed from cached 30-day aggregates + goals map — zero network calls.
- Removed duplicate `TrendChip` above chart; weekly change lives in insight card #1.
- Insight section hidden on 12-month period; calm empty states for `<7` days and `7–13` weekly comparison.
- 5 new cubit tests; `flutter test --exclude-tags slow` → 814 passed.

### File List

- `lib/core/metrics/trends_insights.dart` (new)
- `lib/presentation/cubits/history_state.dart`
- `lib/presentation/cubits/history_cubit.dart`
- `lib/presentation/screens/history_screen.dart`
- `lib/presentation/widgets/trends_insight_cards.dart` (new)
- `lib/presentation/l10n/l10n_date_labels.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_fr.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_fr.dart`
- `test/presentation/cubits/history_cubit_test.dart`

## Change Log

- 2026-06-20 — Story 20-2 implemented: local Trends insight cards (cubit + UI + l10n + tests).
