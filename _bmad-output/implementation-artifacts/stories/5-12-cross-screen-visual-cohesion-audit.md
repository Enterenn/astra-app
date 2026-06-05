# Story 5.12: Cross-Screen Visual Cohesion Audit

Status: ready-for-dev

<!-- Epic 5 final gate before Epic 6. Executes UX §4.7 checklist V-1–V-13 on device; fixes code-level gaps found in pre-audit scan. -->

## Story

As a **builder**,
I want every surface verified against the UX visual checklist on device,
so that the app feels cohesive before OSS beta release.

## Acceptance Criteria

1. **Given** UX spec §4.7 checklist V-1–V-13  
   **When** executed on release or profile build on a physical device  
   **Then** each item passes or has a **documented exception** with rationale in this story's completion notes (UX-DR21)  
   **And** checklist rows V-4, V-8, V-11 are updated in `ux-design-specification.md` to reflect the four-tab shell and Story 5.10 sovereignty layout (no longer "3 tabs" or goal-on-Data hierarchy)

2. **Given** Today, Trends, Data, Profile, and onboarding  
   **When** reviewed in **system**, **light**, **dark**, and each of the **six accent presets** (Story 5.8)  
   **Then** typography uses bundled Figtree + Darker Grotesque only (V-3)  
   **And** no layout jump on Today sync refresh (V-5)  
   **And** all screens use `context.astraColors` tokens — no ad-hoc `Color(0x…)` in `lib/presentation/` (V-2)

3. **Given** Today (Story 5.9)  
   **When** user opens Today with or without `display_name` stored  
   **Then** **no** `Hello, {name}` greeting is shown; ring remains sole step-count hero  
   **And** screen title reads **Today's activity** via `AstraTypography.screenTitleFor`

4. **Given** Data tab (Story 5.10)  
   **When** screen title is read  
   **Then** body title is **My Data**; tab label remains short **DATA**

5. **Given** Profile (Story 5.11)  
   **When** Informations section is read  
   **Then** section title is **Informations** (not "Profile")  
   **And** tab label is **PROFILE**

6. **Given** Trends tab (UX §2.4 — title TBD)  
   **When** screen renders  
   **Then** screen title is locked to **Trends** (matches tab label TRENDS)  
   **And** title uses `static const _kScreenTitle` + `AstraTypography.screenTitleFor` + `Semantics(label:)` — same pattern as Today/Profile

7. **Given** cross-screen shell consistency  
   **When** all four tab screens are compared  
   **Then** each uses the same outer wrapper pattern (`ColoredBox` + `SafeArea(bottom: false)` — **not** nested `Scaffold` on Profile)  
   **And** scrollable tabs apply identical bottom clearance: `kBottomNavBottomOffset + kBottomNavBarHeight + kSpaceMd` (104px)  
   **And** History/Trends chart area respects bottom nav clearance (no content hidden under floating pill)

8. **Given** Phosphor dependency (Story 5.6)  
   **When** production UI is scanned (`lib/presentation/`, excluding `lib/dev/`)  
   **Then** remaining Material `Icons.*` in user-facing widgets are migrated to Phosphor equivalents:  
   - `trend_chip.dart` — trend arrows  
   - `profile_info_row.dart`, `display_name_editor_row.dart` — chevrons  
   - `onboarding_*_page.dart` — back arrows  
   **And** orphan `source_chip.dart` is deleted or explicitly excluded with comment (widget unused since 5.9)

9. **Given** card surface consistency on Today  
   **When** Cards 1–3 are inspected  
   **Then** `_ElevatedCard` private widget is consolidated into `SectionCard` (or a shared `ElevatedCard` in `presentation/widgets/`) so radius, padding, and `bgElevated` match Data/Profile cards

10. **Given** screenshot / README GIF readiness (V-13 / SM-7 prep)  
    **When** Today and My Data are framed on device  
    **Then** hero layouts are presentation-ready above the floating nav (16px offset per `ef2332b`)

11. **Given** findings from Epics 1–5 device testing and pre-audit code scan  
    **When** logged in story completion notes  
    **Then** residual polish items are either fixed in this story or explicitly deferred with rationale in `deferred-work.md`

12. **Given** Data background status copy (field feedback 2026-06-03)  
    **When** user reads "Last sync {relative time}" on device  
    **Then** completion notes document expected semantics: **last successful ingestion** timestamp (WM/FGS/collect), **not** the 60s foreground persist timer  
    **And** optional UX copy tweak only if confusion persists after documentation pass

13. **Given** implementation complete  
    **When** `flutter analyze` and `flutter test` run  
    **Then** no regressions; widget tests updated for Trends title, Phosphor icons, History bottom padding, Profile shell change

**Depends on:** Stories 5.9, 5.10, 5.11 (all done).  
**Prerequisite for:** Epic 6 (derived metrics), Story 5.13 (optional animation polish), Epic 7 beta checklist (FR-29 references this sign-off).  
**Out of scope:** Epic 6 stats values; functional hotfixes (step decrease, notification miss) — post–Epic 7 checklist per `deferred-work.md`; `ProfileInitialsBadge` header; `MyDataCubit` rename.

---

## Pre-Audit Findings (code scan — fix or document in this story)

| # | Finding | Severity | Recommended action |
|---|---------|----------|-------------------|
| P1 | `history_screen.dart` — no bottom nav clearance; chart may sit under pill | High | Add bottom padding or safe inset matching Today formula |
| P2 | `profile_screen.dart` — nested `Scaffold` vs `ColoredBox` on other tabs | High | Align to `ColoredBox` + `SafeArea` pattern |
| P3 | Material `Icons.*` in `trend_chip`, chevron rows, onboarding back | Medium | Phosphor migration (AC #8) |
| P4 | `today_screen.dart` — `_ElevatedCard` duplicates `SectionCard` styling | Medium | Consolidate (AC #9) |
| P5 | History title inline `'History'`; no `Semantics`; no `static const` | Medium | Lock title + parity (AC #6) |
| P6 | My Data title lacks `Semantics` wrapper | Low | Add for a11y parity |
| P7 | V-11 stale dual banner — Today banner removed (`01a9319`); `staleCompact` unwired | Doc | Document exception; update UX §4.7 V-11 |
| P8 | `deferred-work.md` "Hello greeting too small" — **superseded** by 2026-06-04 removal | Doc | Close item; do **not** restore greeting |
| P9 | UX §4.7 V-4 says "3 tabs"; V-8 includes goal-on-Data | Doc | Update checklist (AC #1) |
| P10 | `app_bottom_nav.dart` label uses ad-hoc `TextStyle` w600 vs spec w700 | Low | Optional token or document delta |
| P11 | `source_chip.dart` orphan with Material icon | Low | Delete or exclude |
| P12 | Onboarding uses `kSpace2xl` (48px) horizontal padding vs tabs 16px | Low | Verify Figma; document if intentional |

---

## Tasks / Subtasks

- [x] **A — UX checklist doc refresh** (AC: #1, #11, #12)
  - [x] Update `ux-design-specification.md` §4.7: V-4 → four-tab floating pill; V-8 → Background → Footprint → Your data (no goal/theme); V-11 → document Today banner removal + Data-only stale path (or "deferred — product TBD")
  - [x] Lock Trends screen title decision with Baptiste (recommend **Trends**); update UX §2.4
  - [x] Add completion-note template for V-1–V-13 device pass results
  - [x] Document "Last sync" semantics in completion notes
  - [x] Close superseded greeting item in `deferred-work.md`
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **B — Shell & spacing fixes** (AC: #6, #7)
  - [x] `history_screen.dart`: add `_kScreenTitle` const, `Semantics`, bottom nav clearance
  - [x] `profile_screen.dart`: replace nested `Scaffold` with `ColoredBox` + `SafeArea` (preserve scroll + loading/error states)
  - [x] `my_data_screen.dart`: add `Semantics(label: _kScreenTitle)` if missing
  - [x] `app_bottom_nav.dart`: nav label `w600` → `w700` (point 6)
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **C — Phosphor icon migration** (AC: #8)
  - [x] `trend_chip.dart`: `arrowUp` / `arrowDown` / `minus` Phosphor equivalents
  - [x] `profile_info_row.dart`, `display_name_editor_row.dart`: `caretRight` Phosphor
  - [x] Onboarding back pages: `arrowLeft` Phosphor
  - [x] Remove or exclude `source_chip.dart`; update imports/tests
  - [x] Delete orphan `goal_editor_row.dart`, `profile_initials_badge.dart` + tests
  - [x] **Stop → review brief → Baptiste OK → commit**

- [ ] **D — Today card consolidation** (AC: #9)
  - [x] Extract shared elevated card widget or extend `SectionCard` for headline-optional use
  - [x] Replace `_ElevatedCard` in `today_screen.dart` with shared widget
  - [ ] **Stop → review brief → Baptiste OK → commit**

- [ ] **E — Device checklist pass** (AC: #2, #3–#5, #10, #13)
  - [ ] Run V-1–V-13 on physical device: system + light + dark × 6 accent presets on all surfaces
  - [ ] Record pass/fail/exception per item in Dev Agent Record
  - [ ] Fix any failures not covered by B–D
  - [ ] Verify V-13 screenshot framing for Today + My Data
  - [ ] **Stop → review brief → Baptiste OK → commit**

- [ ] **F — Tests & regression** (AC: #13)
  - [ ] Update `history_screen_test.dart`, `profile_screen_test.dart`, `trend_chip_test.dart`, `app_scaffold_test.dart`
  - [ ] Full `flutter test` + `flutter analyze`
  - [ ] **Stop → review brief → Baptiste OK → commit**

---

## Dev Notes

### Product intent (why this story)

Stories 5.6–5.11 rebuilt the four-tab Figma shell (nav, accents, Today, Data, Profile). This story is the **quality gate**: verify every surface against the UX visual checklist on a real device, fix code-level inconsistencies the scan already found, and produce documented sign-off for Epic 6 and Epic 7 beta checklist (FR-29).

This is **not** a functional epic — no new features, no schema changes, no new preferences. Scope is visual parity, token compliance, icon consistency, spacing, and checklist documentation.

### Architecture compliance

- **Presentation layer only** — no `data/` or `core/metrics/` changes unless a checklist fix requires copy-only tweak in a repository string
- **Design tokens:** `context.astraColors.*`, `AstraTypography.*`, `AstraSpacing.*` — hex only in `astra_colors.dart` / `astra_accent_palette.dart` (V-2)
- **No navigation changes** — tab indices 0–3 unchanged; `AppScaffold` + `AnimatedSwitcher` preserved
- **ThemeCubit** — audit reads/writes only via existing Profile appearance UI; do not add new theme keys
- **Review-before-commit:** one commit per sub-task A–F ([Source: `docs/project-context.md`])

### Current code state (READ before editing)

| File | Today | Change in 5.12 | Preserve |
|------|-------|----------------|----------|
| `lib/presentation/screens/today_screen.dart` | Figma layout, `_ElevatedCard`, no greeting | Consolidate cards; verify V-5 | Goal ring, celebration, Set goal, stats placeholders |
| `lib/presentation/screens/history_screen.dart` | Title `'History'`, no bottom clearance | Title lock + padding + Semantics | Chart, period toggle, trend chip, KPI-01 perf |
| `lib/presentation/screens/my_data_screen.dart` | Sovereignty layout, `screenTitleFor` | Semantics parity | Background, footprint, CSV, purge — no goal/theme |
| `lib/presentation/screens/profile_screen.dart` | Full Profile UI, nested `Scaffold` | Shell alignment to `ColoredBox` | Three SectionCards, cubit wiring |
| `lib/presentation/widgets/trend_chip.dart` | Material trend icons | Phosphor migration | Trend colors from semantic tokens |
| `lib/presentation/widgets/profile_info_row.dart` | Material chevron | Phosphor chevron | Row layout, tap → sheet |
| `lib/presentation/widgets/display_name_editor_row.dart` | Material chevron | Phosphor chevron | Reuse on Profile |
| `lib/presentation/widgets/section_card.dart` | Shared card + headline | May extend for headline-optional | `kCardPadding`, `kRadiusMd`, `bgElevated` |
| `lib/presentation/widgets/app_bottom_nav.dart` | 4-tab Phosphor pill | No structural change | Active squircle, accent colors |
| `lib/presentation/onboarding/onboarding_*_page.dart` | Material back arrows | Phosphor back | Trust-first flow, padding |
| `lib/presentation/widgets/source_chip.dart` | Orphan, unused | Delete | — |
| `_bmad-output/planning-artifacts/ux-design-specification.md` | Stale V-4, V-8, V-11 | Update §4.7 + §2.4 title | Rest of spec unchanged |

### UX checklist V-1–V-13 — execution guide

| # | Check | How to verify on device | Known delta / exception |
|---|-------|-------------------------|-------------------------|
| V-1 | Theme default | Fresh install → System theme; toggle light/dark on Profile | — |
| V-2 | Token consistency | `rg "Color\\(0x" lib/presentation/` → zero matches | `Colors.transparent` OK |
| V-3 | Typography | Visual scan all screens; no Roboto/system fallback | — |
| V-4 | Tab cohesion | **Update spec:** 4 tabs, same pill, accent active squircle | Was "3 tabs" |
| V-5 | Today hero | Open Today → pull refresh / resume → ring stable, no jump | — |
| V-6 | GoalCelebration | Hit goal once/day; test reduce-motion | — |
| V-7 | History perf | Debug FAB KPI-01 if needed; release skips FAB | Debug-only tool |
| V-8 | My Data hierarchy | **Update spec:** Background → Footprint → Your data | Goal/theme moved to Profile |
| V-9 | Purge empty state | Purge → Today 0 steps, goal retained | — |
| V-10 | Onboarding once | Complete → never re-shows | — |
| V-11 | Stale dual banner | **Exception:** Today compact banner removed 2026-06-05; Data may still show full stale | Document; product TBD |
| V-12 | Destructive clarity | Purge dialog mentions export; danger on confirm only | — |
| V-13 | Screenshot readiness | Frame Today + My Data above nav for README GIF | 16px nav offset |

**Accent preset matrix (minimum):** For each preset (orange, red, green, blue, magenta, pink), spot-check Today ring arc, nav active squircle, theme selector underline, accent chips on Profile, chart goal-met bars (`status.ok` from 5.8).

### Copy locks (unchanged — verify only)

| Element | Copy |
|---------|------|
| Tab labels | **TODAY**, **TRENDS**, **DATA**, **PROFILE** |
| Screen titles | **Today's activity**, **Trends**, **My Data**, **My Profile** |
| Profile section | **Informations**, **Notifications**, **Appearance** |
| Data sections | **Background**, **Footprint**, **Your data** (per 5.10) |

### Phosphor migration map

| Material | Phosphor (suggested) | File |
|----------|---------------------|------|
| `Icons.arrow_upward` | `PhosphorIconsRegular.arrowUp` | `trend_chip.dart` |
| `Icons.arrow_downward` | `PhosphorIconsRegular.arrowDown` | `trend_chip.dart` |
| `Icons.remove` | `PhosphorIconsRegular.minus` | `trend_chip.dart` |
| `Icons.chevron_right` | `PhosphorIconsRegular.caretRight` | profile/display rows |
| `Icons.arrow_back` | `PhosphorIconsRegular.arrowLeft` | onboarding pages |

Import: `package:phosphor_flutter/phosphor_flutter.dart` (already in pubspec from 5.6).

### Shell pattern (canonical — all tabs must match)

```dart
return ColoredBox(
  color: colors.bgBase,
  child: SafeArea(
    bottom: false,
    child: Semantics(
      label: _kScreenTitle,
      child: SingleChildScrollView( // or Column+Expanded for History
        padding: EdgeInsets.fromLTRB(
          AstraSpacing.kScreenHorizontalPadding,
          AstraSpacing.kSpaceSm,
          AstraSpacing.kScreenHorizontalPadding,
          bottomScrollPadding, // scrollable tabs only
        ),
        // ...
      ),
    ),
  ),
);

// bottomScrollPadding =
//   kBottomNavBottomOffset + kBottomNavBarHeight + kSpaceMd  // 16+72+16=104
```

**History exception:** Uses `Column` + `Expanded` chart, not `SingleChildScrollView`. Apply bottom padding on the outer `Padding` or add `SizedBox` below chart equal to `bottomScrollPadding`.

### What NOT to break

- **Today** — no greeting restoration; stats placeholders until Epic 6
- **Data** — sovereignty-only; no goal/theme/display name reintroduction
- **Profile** — Informations/Notifications/Appearance intact; purge survival keys
- **Chart performance** — KPI-01 benchmark path unchanged
- **Accent preset persistence** — six presets + legacy DB aliases (`cyan`→`blue`, `purple`→`magenta`)
- **Onboarding** — trust-before-permission order; wider padding may be intentional for hero layout

### Testing requirements

| Area | Minimum tests |
|------|----------------|
| History | Title const + Semantics; bottom padding prevents overlap (layout test or golden) |
| Profile | Renders without nested Scaffold assertion; scroll clearance |
| Phosphor | `trend_chip_test.dart` finds Phosphor icons, not Material |
| Regression | Full `flutter test`; `flutter analyze` clean |
| Checklist | Manual device matrix logged in completion notes (not automatable) |

Widget test pattern: seeded cubits, no async DB — same as 5.9–5.11.

### Previous story intelligence (5.11)

- Profile uses `screenTitleFor` + `Semantics` — **reuse as template** for History/My Data
- Scroll padding formula proven on Today/Data/Profile — **copy to History**
- `AccentPresetSelector` bi-tone chips re-render on theme change — verify in accent matrix pass
- Nav label **PROFILE** locked; Phosphor `User` icon

### Previous story intelligence (5.10)

- Data title **My Data**; tab **DATA**; sections Background → Footprint → Your data
- Goal editor removed from Data — lives on Today only
- `BackgroundStatusCard` semantics for "Last sync" — document, don't change unless copy tweak approved

### Previous story intelligence (5.9)

- No `Hello, {name}` — product decision 2026-06-04; **do not restore** per deferred-work triage
- `_ElevatedCard` was intentional for headline-less cards — consolidate without losing `bgSubtle` inset on ring card
- Stats row shows `—` placeholders until Epic 6

### Previous story intelligence (5.7 / 5.8)

- `kBottomNavBottomOffset` = 16px (was 32px)
- Active tab squircle: dark `bgBase`, light `bgElevated`
- Goal-met chart bars use `status.ok` semantic green (5.8)

### Git intelligence

Recent cohesion commits (2026-06-05):

| Commit | Change |
|--------|--------|
| `c4c9b5d` | `screenTitleFor` token; unified titles; History top padding 8px |
| `ef2332b` | Nav offset 32→16px |
| `fd626e3` | Chart elevated surface + primary text labels |
| `da99fff` | Theme selector inactive segments `textPrimary` |
| `0a3758f` | CSV button hover fills |
| `01a9319` | Removed Today stale banner |

Pattern: small focused fixes per surface; colocated tests; semantic colors only.

### Latest tech information

- **phosphoricons_flutter** — already installed (5.6); use `PhosphorIconsRegular` / `PhosphorIconsFill` consistently
- **Flutter 3.44+** — Built-in Kotlin resolved in 5.5; no Gradle changes in this story
- **WCAG AA** — aspirational (NFR5); baseline §4.1–4.5; inverse dark text on amber fills (D-13)
- **Reduce motion** — `MediaQuery.disableAnimations` affects `GoalCelebration` (V-6)

### Project context reference

- [Source: `docs/project-context.md`] — review-before-commit per sub-task
- [Source: `_bmad-output/planning-artifacts/epics.md` § Story 5.12]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` §4.7, §2.4 Trends]
- [Source: `_bmad-output/planning-artifacts/architecture.md` § Frontend Architecture]
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md`] — close greeting item; hotfixes post–Epic 7
- [Source: `_bmad-output/implementation-artifacts/stories/5-11-profil-informations-and-appearance.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/5-10-data-screen-sovereignty-layout.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/5-9-today-figma-layout-no-greeting.md`]

---

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

**Last sync semantics (AC #12):** The "Last sync {relative time}" label on My Data reflects the timestamp of the **last successful step ingestion** (WorkManager / FGS / foreground collect writing to SQLite) — **not** the 60s foreground persist timer. Copy change deferred unless device pass shows persistent user confusion.

**Trends title locked:** **Trends** (matches tab label TRENDS; Story 5.12 Task A).

**V-11 exception:** Today compact stale banner removed (`01a9319`); Data-only full stale path may still appear. Documented in UX §4.7.

**Deferred-work triage:** Greeting item closed as superseded by 5.9 removal.

**Task E workflow (point 5):** Code fixes land in B–D+F first; device matrix V-1–V-13 is filled by Baptiste on a physical release/profile build after those tasks merge. Agent leaves the table ready; no blocker to ship code without device rows filled.

**Last sync copy (point 7):** No copy change in this story — semantics documented above. If device pass still confuses users, optional copy tweak tracked in Epic 7 checklist (`deferred-work.md` line 47).

### V-1–V-13 Device Pass Results

> **Device pass (Task E):** Run after Tasks B–D+F on physical device (release or profile build). System + light + dark × 6 accent presets. Mark Pass / Fail / Exception per row.

| # | Result | Notes |
|---|--------|-------|
| V-1 | | |
| V-2 | | |
| V-3 | | |
| V-4 | | |
| V-5 | | |
| V-6 | | |
| V-7 | | |
| V-8 | | |
| V-9 | | |
| V-10 | | |
| V-11 | | |
| V-12 | | |
| V-13 | | |

### File List

- `_bmad-output/planning-artifacts/ux-design-specification.md` (modified — §2.4, §4.7 V-4/V-8/V-11)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified — greeting superseded)
- `_bmad-output/implementation-artifacts/stories/5-12-cross-screen-visual-cohesion-audit.md` (modified — completion notes, Task A)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified — in-progress)
- `lib/presentation/screens/history_screen.dart` (modified — Trends title, Semantics, bottom padding)
- `lib/presentation/screens/profile_screen.dart` (modified — ColoredBox shell)
- `lib/presentation/screens/my_data_screen.dart` (modified — Semantics)
- `lib/presentation/widgets/app_bottom_nav.dart` (modified — w700 label)
- `lib/presentation/widgets/trend_chip.dart` (modified — Phosphor icons)
- `lib/presentation/widgets/profile_info_row.dart` (modified — Phosphor caretRight)
- `lib/presentation/widgets/display_name_editor_row.dart` (modified — Phosphor caretRight)
- `lib/presentation/onboarding/onboarding_permissions_page.dart` (modified — Phosphor arrowLeft)
- `lib/presentation/onboarding/onboarding_display_name_page.dart` (modified — Phosphor arrowLeft)
- `lib/presentation/onboarding/onboarding_goal_page.dart` (modified — Phosphor arrowLeft)
- `lib/presentation/widgets/source_chip.dart` (deleted — orphan)
- `lib/presentation/widgets/goal_editor_row.dart` (deleted — orphan)
- `lib/presentation/widgets/profile_initials_badge.dart` (deleted — orphan)
- `test/presentation/widgets/trend_chip_test.dart` (modified — Phosphor assertions)
- `test/presentation/widgets/status_banner_test.dart` (modified — removed SourceChip tests)
- `test/presentation/widgets/profile_initials_badge_test.dart` (deleted)
- `test/presentation/screens/my_data_screen_test.dart` (modified — removed orphan type asserts)
- `lib/presentation/widgets/elevated_card.dart` (new — shared elevated surface)
- `lib/presentation/widgets/section_card.dart` (modified — composes ElevatedCard)
- `lib/presentation/screens/today_screen.dart` (modified — uses ElevatedCard)

---

## Story completion status

- **Status:** ready-for-dev
- **Completion note:** Ultimate context engine analysis completed — comprehensive developer guide created
