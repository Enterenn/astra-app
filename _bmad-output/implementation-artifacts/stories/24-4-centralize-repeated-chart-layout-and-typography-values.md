# Story 24.4: Centralize Repeated Chart Layout and Typography Values

Status: done

<!-- Post-audit Epic 24 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 24-4 · diagnostic-coherence-design-system.md Reco #2–3 · AUD-37 · AUD-39 -->
<!-- Version bump deferred to Epic 24 close (patch+1, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **developer**,
I want chart axis reserved sizes and repeated nav/week typography to live in one token source,
So that layout tweaks do not drift across charts.

## Acceptance Criteria

1. **Given** duplicated `_kLeftAxisReserved` / `_kBottomAxisReserved` in chart widgets and existing `kAstraBarChart*` in `astra_bar_chart_core.dart`
   **When** this story ships
   **Then** chart axis reserved sizes use **one shared source** — `kAstraBarChartLeftAxisReserved` (36) and `kAstraBarChartBottomAxisReserved` (24) from `astra_bar_chart_core.dart` (AUD-37)
   **And** private `_kLeftAxisReserved` / `_kBottomAxisReserved` constants are removed from `step_bar_chart.dart` and `trends_monthly_bar_chart.dart`
   **And** `GoalStepLinePainter` default `leftReserved` / `bottomReserved` reference the same shared constants (not magic `36` / `24` literals)

2. **Given** inline `TextStyle` for bottom-nav label (Figtree 10 / w700 / letterSpacing 0.4)
   **When** styles are applied in `app_bottom_nav.dart`
   **Then** `AstraTypography.navLabelFor(AstraColors)` exists and is used (AUD-39)
   **And** selected/inactive **colors** remain applied via `.copyWith(color: …)` at the call site (token defines metrics only)

3. **Given** inline typography overrides for week day number (16 / w900) in `week_progress_row.dart`
   **When** day number text renders
   **Then** `AstraTypography.weekDayNumberFor(AstraColors)` exists and is used (AUD-39)
   **And** existing tests asserting `fontSize: 16` and `FontWeight.w900` on day numbers still pass (color overrides unchanged)

4. **Given** week weekday abbrev still uses `captionFor` + inline `fontSize: 10` / `w600`
   **When** this story ships
   **Then** behavior is **unchanged** (weekday label weight stays w600, not w700 — distinct from nav label)
   **And** optional cleanup: add `weekWeekdayLabelFor` only if it removes all inline fontSize/fontWeight overrides without visual change

5. **Given** verification runs after centralization
   **When** `dart analyze` and `flutter test --exclude-tags slow` execute
   **Then** both pass with zero regressions
   **And** repo grep under `lib/` finds **zero** `_kLeftAxisReserved`, `_kBottomAxisReserved`, and no duplicate `static const … = 36.0` / `24.0` axis literals in chart widget files
   **And** repo grep under `lib/presentation/widgets/app_bottom_nav.dart` and `week_progress_row.dart` finds **zero** inline `fontSize: 10` / `fontSize: 16` for the migrated labels

**Covers:** AUD-37 · AUD-39 · diagnostic-coherence-design-system.md Reco #2–3

**Depends on:** Stories 24-1, 24-2, 24-3 done (presentation-only; no cubit/schema changes).

**Out of scope:** Chart **heights** (`kDailyChartHeight`, `_kMonthlyChartHeight` — separate future token pass), bar top radius / spacing orphan `4`/`8` cleanup (Reco #4), `dataBoldFor` for trends stat cards, loading skeleton work (24-3), orphan pref constants (24-5), PeriodToggle loading gate (24-6), version bump until Epic 24 closes.

## Tasks / Subtasks

- [x] **Sub-task A — Deduplicate chart axis reserved constants** (AC: #1)
  - [x] In `step_bar_chart.dart` `_ReadyChartState`: delete `_kLeftAxisReserved` / `_kBottomAxisReserved`; import and use `kAstraBarChartLeftAxisReserved` / `kAstraBarChartBottomAxisReserved` from `chart/astra_bar_chart_core.dart`
  - [x] Same migration in `trends_monthly_bar_chart.dart` `_ReadyChartState`
  - [x] In `goal_step_line_painter.dart`: import shared constants; set default param values to `kAstraBarChartLeftAxisReserved` / `kAstraBarChartBottomAxisReserved`
  - [x] Verify `plotWidth = constraints.maxWidth - kAstraBarChartLeftAxisReserved` math unchanged
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Add typography tokens and migrate call sites** (AC: #2, #3, #4)
  - [x] Add to `lib/core/constants/astra_typography.dart`:
    - `navLabelFor(AstraColors)` — Figtree, 10px, w700, letterSpacing 0.4, height 1.2, `color: colors.textPrimary` (or neutral — match current nav: color applied at call site)
    - `weekDayNumberFor(AstraColors)` — Figtree, 16px, w900, height 1.0, base color `colors.textPrimary` (call sites override color for future days)
  - [x] Migrate `app_bottom_nav.dart` `_NavItem`: replace inline `TextStyle(...)` with `AstraTypography.navLabelFor(colors).copyWith(color: …)`
  - [x] Migrate `week_progress_row.dart` day number `Text`: replace `labelFor(...).copyWith(fontSize: 16, fontWeight: w900, …)` with `weekDayNumberFor(colors).copyWith(color: dayNumberColor, height: 1)`
  - [x] Do **not** change weekday abbrev weight (w600) unless adding explicit `weekWeekdayLabelFor`
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests + regression guards** (AC: #5)
  - [x] Add `test/core/constants/astra_typography_tokens_test.dart` — assert navLabel metrics (10/w700/letterSpacing 0.4) and weekDayNumber metrics (16/w900)
  - [x] Run existing `week_progress_row_test.dart` (fontSize/w900 assertions must pass unchanged)
  - [x] Run `step_bar_chart_test.dart`, `trends_monthly_bar_chart_test.dart` (touch/plot math uses `kAstraBarChartLeftAxisReserved` — should remain green)
  - [x] Run `dart analyze` + `flutter test --exclude-tags slow`
  - [x] Grep guards listed in AC #5
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Unify axis reserved 36 / 24 across charts | `kDailyChartHeight` / `_kMonthlyChartHeight` centralization |
| Add `navLabelFor` + `weekDayNumberFor` | `dataBoldFor` for trends cards |
| Migrate `app_bottom_nav` + week day number | Week loading skeleton (24-3) |
| Optional `weekWeekdayLabelFor` if zero visual drift | Bar chart top radius `4` → spacing token |
| Presentation/constants only | Cubit, repository, schema, DI |
| Green analyze + test suite | Version bump (Epic 24 close) |

### Root cause (read before editing)

**Audit finding:** Chart axis reserved sizes exist in three places — `kAstraBarChart*` in core plus identical private `_k*` copies in both chart widgets; nav/week typography uses inline `TextStyle` overrides instead of named tokens [Source: diagnostic-coherence-design-system.md §2 widget constants, §3 table, Reco #2–3].

**Epic AC:** Single token source for chart layout constants; `navLabel` + `weekDayNumber` typography tokens [Source: epics-post-audit.md Story 24-4 L878–884].

**Story 24-2 explicitly deferred** `navLabel` / `weekDayNumber` to this story [Source: 24-2 out-of-scope list].

### Current implementation (UPDATE — read completely before editing)

**Shared constants already exist (canonical source):**

```11:15:lib/presentation/widgets/chart/astra_bar_chart_core.dart
/// Default width reserved for the left Y-axis column in chart layouts.
const kAstraBarChartLeftAxisReserved = 36.0;

/// Default height reserved for the bottom X-axis row in chart layouts.
const kAstraBarChartBottomAxisReserved = 24.0;
```

**Duplicates to remove — daily chart:**

```115:118:lib/presentation/widgets/step_bar_chart.dart
  static const _kBelowGoalBarAlpha = 0.66;
  static const _kSelectedBarAlpha = 0.8;
  static const _kLeftAxisReserved = 36.0;
  static const _kBottomAxisReserved = 24.0;
```

Used at L192, L218–219, L257–258 for plot width, `AstraBarChartCore` params, and `GoalStepLinePainter.leftReserved` / `bottomReserved`.

**Duplicates to remove — monthly chart:**

```121:124:lib/presentation/widgets/trends_monthly_bar_chart.dart
  static const _kBelowGoalBarAlpha = 0.66;
  static const _kSelectedBarAlpha = 0.8;
  static const _kLeftAxisReserved = 36.0;
  static const _kBottomAxisReserved = 24.0;
```

**Painter defaults still magic literals:**

```16:17:lib/presentation/widgets/chart/goal_step_line_painter.dart
    this.leftReserved = 36,
    this.bottomReserved = 24,
```

**Bottom nav inline style (replace with token):**

```119:125:lib/presentation/widgets/app_bottom_nav.dart
    final labelStyle = TextStyle(
      fontFamily: AstraTypography.figtree,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      height: 1.2,
    );
```

**Week day number inline overrides (replace with token):**

```140:147:lib/presentation/widgets/week_progress_row.dart
                  Text(
                    '${day.dayNumber}',
                    style: AstraTypography.labelFor(colors).copyWith(
                      color: dayNumberColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
```

**Week weekday abbrev — preserve w600 (do not use navLabel):**

```130:137:lib/presentation/widgets/week_progress_row.dart
                  Text(
                    weekdayLabel,
                    style: AstraTypography.captionFor(colors).copyWith(
                      color: mutedColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
```

### Recommended approach

| Decision | Rationale |
|----------|-----------|
| Keep constants in `astra_bar_chart_core.dart` | Already exported; tests import `kAstraBarChartLeftAxisReserved` directly |
| Do not move constants to `core/constants/` | Minimize churn; chart shell owns layout contract |
| `*For(AstraColors)` pattern | Matches 24-2 surviving API; theme mapping optional (these are widget-specific, not TextTheme roles) |
| Token = metrics; color at call site | Nav selected/inactive colors and future-day gray must stay dynamic |
| `weekDayNumberFor` uses Figtree w900 | Matches pill tests; do not switch to Darker Grotesque |
| Leave `_kBelowGoalBarAlpha` local | Out of AUD-37 scope (bar alpha, not axis layout) |
| No cubit/screen changes | Pure constants + typography refactor |

### Architecture compliance

- **Presentation + constants only** — no repository, schema, cubit, or DI changes [Source: architecture layering]
- **NFR-AUD-08:** typography tokens use `AstraColors` for default text color; no new hardcoded hex
- **OK commit gate** — one commit per sub-task; wait for Baptiste OK [Source: docs/project-context.md]
- **A11y preserved:** week pill semantics tests (23-6) must remain green — typography token swap must not alter semantics labels

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/widgets/chart/astra_bar_chart_core.dart` | **NO change** — canonical axis constants stay here |
| `lib/presentation/widgets/step_bar_chart.dart` | UPDATE — remove duplicate axis consts, use shared imports |
| `lib/presentation/widgets/trends_monthly_bar_chart.dart` | UPDATE — same |
| `lib/presentation/widgets/chart/goal_step_line_painter.dart` | UPDATE — default params use shared consts |
| `lib/core/constants/astra_typography.dart` | UPDATE — add `navLabelFor`, `weekDayNumberFor` |
| `lib/presentation/widgets/app_bottom_nav.dart` | UPDATE — use `navLabelFor` |
| `lib/presentation/widgets/week_progress_row.dart` | UPDATE — use `weekDayNumberFor` for day number |
| `test/core/constants/astra_typography_tokens_test.dart` | **NEW** — token metric assertions |
| `test/presentation/widgets/week_progress_row_test.dart` | VERIFY — fontSize 16 / w900 tests |
| `test/presentation/widgets/step_bar_chart_test.dart` | VERIFY — plot/touch math |
| `test/presentation/widgets/trends_monthly_bar_chart_test.dart` | VERIFY |

**No changes expected:** `today_cubit.dart`, `history_cubit.dart`, `history_screen.dart`, `astra_bar_loading_skeleton.dart`, `pubspec.yaml`

### Testing requirements

- Default verify: `flutter test --exclude-tags slow` [Source: project-context.md]
- Targeted:
  - `flutter test test/core/constants/astra_typography_tokens_test.dart`
  - `flutter test test/presentation/widgets/week_progress_row_test.dart`
  - `flutter test test/presentation/widgets/step_bar_chart_test.dart test/presentation/widgets/trends_monthly_bar_chart_test.dart`
- `step_bar_chart_test.dart` already subtracts `kAstraBarChartLeftAxisReserved` for plot width — dedup should not change behavior
- `week_progress_row_test.dart` L190–216 asserts day number `fontSize: 16`, `FontWeight.w900` — must pass after token migration
- Manual smoke (optional): Trends daily + monthly charts render identical axis padding; bottom nav labels unchanged; week pills unchanged in light/dark

### Previous story intelligence

**From Story 24-3 (done 2026-07-18):**
- Shared widget extraction pattern: new file → migrate call sites → delete duplicates → widget tests
- Chart widgets now use `AstraBarLoadingSkeleton`; axis layout code in `_ReadyChart` untouched — safe to edit now
- 918 tests green with `--exclude-tags slow`
- Sprint tracker: **`sprint-status-post-audit.yaml`** (not `sprint-status.yaml`)

**From Story 24-2 (done 2026-07-18):**
- Only remove dead APIs; keep live `*For(AstraColors)` helpers
- Explicitly deferred `navLabel` / `weekDayNumber` to **this story**
- Constants-only sub-task pattern: analyze + grep guards + full test suite

**From Story 24-1 (done 2026-07-17):**
- Shared extraction in `presentation/widgets/` or `core/constants/` depending on domain
- Presentation-only; OK commit gate per sub-task

### Git intelligence summary

Recent commits (Epic 24):
- `2781bb6` — close story 24-3 (loading skeleton unification)
- `dcad3b0` / `696c2ad` — story 24-2 dead token cleanup in typography/colors
- `389d1e3` — story 24-1 `SheetDragHandle`

Commit style: `refactor(design-system): …`, `test(design-system): …`, `chore(review): …`

Chart axis duplicates and inline nav/week typography were **not** touched in 24-1/24-2/24-3 — clean, focused surface.

### Latest tech information

- **Flutter typography:** Continue `TextStyle` + `copyWith(color:)` pattern; no `ThemeExtension` required for two widget-specific tokens.
- **Const defaults in painters:** Use top-level `const` from `astra_bar_chart_core.dart` for default constructor params (valid in Dart 3).
- **No package upgrades** required.

### Project context reference

- OK commit gate + diff-only delivery: `docs/project-context.md`
- Sprint tracker: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`
- Audit source: `_bmad-output/planning-artifacts/audits/diagnostic-coherence-design-system.md` Reco #2–3
- Epic source: `_bmad-output/planning-artifacts/epics-post-audit.md` Story 24-4
- Current app version: `0.11.0+25` (`pubspec.yaml`) — do not bump in this story

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-5

### Completion Notes List

- Sub-task A: Removed `_kLeftAxisReserved` / `_kBottomAxisReserved` from `step_bar_chart.dart` and `trends_monthly_bar_chart.dart`; migrated 3 usages each to `kAstraBarChartLeftAxisReserved` / `kAstraBarChartBottomAxisReserved`. Added import + shared-constant defaults to `goal_step_line_painter.dart`.
- Sub-task B: Added `navLabelFor` (10px/w700/ls0.4/h1.2) and `weekDayNumberFor` (16px/w900/h1.0) to `AstraTypography`. Migrated `app_bottom_nav.dart` inline `TextStyle` → `navLabelFor`. Migrated `week_progress_row.dart` day-number `labelFor.copyWith(fontSize:16,w900)` → `weekDayNumberFor.copyWith(color:,height:1)`. Weekday abbrev (captionFor+w600) unchanged per AC #4.
- Sub-task C: New `astra_typography_tokens_test.dart` (9 assertions). All guards pass. 927/927 suite green.

### File List

- `lib/presentation/widgets/step_bar_chart.dart`
- `lib/presentation/widgets/trends_monthly_bar_chart.dart`
- `lib/presentation/widgets/chart/goal_step_line_painter.dart`
- `lib/core/constants/astra_typography.dart`
- `lib/presentation/widgets/app_bottom_nav.dart`
- `lib/presentation/widgets/week_progress_row.dart`
- `test/core/constants/astra_typography_tokens_test.dart`

### Change Log

- 2026-07-18: Story context created — ready-for-dev (create-story workflow)
- 2026-07-18: Sub-task A — deduplicated chart axis constants (3 commits A+B+C)
- 2026-07-18: Sub-task B — added navLabelFor / weekDayNumberFor tokens, migrated 2 call sites
- 2026-07-18: Sub-task C — token metric tests; 927/927 suite green; story → review
