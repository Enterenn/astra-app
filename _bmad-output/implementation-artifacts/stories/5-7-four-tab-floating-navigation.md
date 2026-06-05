# Story 5.7: Four-Tab Floating Navigation Bar

Status: done

<!-- Epic 5 — shell navigation redesign. Mockups: Today light, Today dark, History/Trends light (Baptiste 2026-06-04). Dimensions locked by product. -->

## Story

As a **user**,
I want four clearly labeled tabs in a floating pill navigation bar,
so that I can reach Today, Trends, Data, and Profil quickly.

## Acceptance Criteria

1. **Given** onboarding is complete  
   **When** the main app loads  
   **Then** `AppScaffold` shows **four** destinations with short tab labels: **TODAY · TRENDS · DATA · PROFIL** (all-caps per Figma / UX D-17)  
   **And** the bar is a **floating pill** above the bottom safe area (capsule radius, fill `color.accent.primary`)  
   **And** the pill is **72px** tall with **24px** horizontal padding inside the bar (left/right)  
   **And** each tab control is a **52×52px** hit area with icon + label **centered**, **6px** gap between icon and label  
   **And** the **active** tab shows a **squircle** behind the full 52×52 content (icon + label): corner radius **16px**, Figma **corner smoothing 100%** (continuous / superellipse curve — not a plain circular arc)  
   **And** squircle fill is **white** in light theme, **charcoal** in dark theme (best-effort with current tokens; full dark polish deferred to **5.8**)  
   **And** active icon + label use `color.accent.primary` on the squircle  
   **And** **inactive** tabs have no squircle; icon + label use `color.text.primary` on the orange bar (light mockup)

2. **Given** the Phosphor dependency from Story 5.6  
   **When** tab icons render  
   **Then** **inactive** tabs use `PhosphorIconsRegular`: `sneakerMove`, `chartBar`, `database`, `user`  
   **And** the **active** tab uses the matching **`PhosphorIconsFill`** glyph for the same four icons (regular → fill on selection)  
   **And** icon size remains **24dp** (UX §1.6)

3. **Given** tab **TRENDS**  
   **When** selected  
   **Then** the existing `HistoryScreen` is shown (Epic 3 chart content unchanged)  
   **And** the **tab** label is **TRENDS** with active squircle + fill icon (History/Trends light mockup)  
   **And** the **screen** header may still read **History** until a later polish story — do not block 5.7 on renaming in-screen copy

4. **Given** tab **DATA**  
   **When** selected  
   **Then** the existing `MyDataScreen` is shown (sovereignty layout refactor is **Story 5.10**; screen title **My Data** unchanged for now)

5. **Given** tab **PROFIL**  
   **When** selected  
   **Then** a new `ProfileScreen` placeholder is shown (full Informations / Appearance UI is **Story 5.11**)

6. **Given** `TodayScreen` stale compact banner  
   **When** the user taps it  
   **Then** navigation still opens the **DATA** tab (index **2** after 4-tab remap)

7. **Given** reduce-motion is enabled (`MediaQuery.disableAnimationsOf`)  
   **When** switching tabs  
   **Then** `AnimatedSwitcher` uses zero duration (instant swap) — preserve UX-DR18 behavior from Story 1.3

8. **Given** Android gesture navigation  
   **When** the shell is inspected  
   **Then** bottom safe area is respected (floating bar sits above system inset, not under it)

9. **Given** implementation complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no new analyzer issues; all updated navigation tests pass

**Depends on:** Story 5.6 (done).  
**Prerequisite for:** Stories 5.8 (accent presets on nav), 5.9–5.12 (screen layouts using the new shell).

## Tasks / Subtasks

- [x] **Sub-task A — Nav tokens + `AppBottomNav` widget** (AC: #1, #2, #8)
  - [x] Add constants in `astra_spacing.dart` (do **not** reuse legacy `kBottomTabBarHeight` = 56 for this bar):
    - `kBottomNavBarHeight` = **72**
    - `kBottomNavHorizontalPadding` = **24**
    - `kBottomNavItemSize` = **52**
    - `kBottomNavIconLabelGap` = **6**
    - `kBottomNavSquircleRadius` = **16** (equals existing `kRadiusLg`; Figma squircle corner radius)
  - [x] Add `lib/presentation/widgets/app_bottom_nav.dart` (UX `AppBottomNav`, P0)
  - [x] Floating pill: `SafeArea` → outer screen margin if needed → inner bar `height: 72`, `padding: EdgeInsets.symmetric(horizontal: 24)`, `color.accent.primary`, `radius: kRadiusFull`
  - [x] Row of 4 items; each tab: fixed **52×52** `SizedBox`, centered `Column` with `SizedBox(height: 6)` between icon and label
  - [x] Active squircle: **52×52** `ShapeDecoration` with **16px** continuous corners (Figma smoothing 100%):
    - **Preferred:** `ContinuousRectangleBorder(borderRadius: BorderRadius.circular(kBottomNavSquircleRadius))` — matches iOS/Figma “smoothed” corners
    - **If SDK supports it:** `RoundedSuperellipseBorder` (Flutter 3.27+) for closer Figma superellipse; verify on project Flutter 3.44
    - **Do not** use a plain `BoxDecoration` + `BorderRadius.circular(16)` only — that skips corner smoothing and will look sharper than Figma
  - [x] Squircle fill: `bgElevated` (light) / charcoal surface token (dark, best-effort; **5.8** owns final nav squircle token)
  - [x] Active icon: `PhosphorIconsFill.*`; inactive: `PhosphorIconsRegular.*`; label color `accentPrimary` (active) / `textPrimary` (inactive)
  - [x] Labels: uppercase TODAY, TRENDS, DATA, PROFIL
  - [x] Extend `phosphoricons_flutter_test.dart` with `PhosphorIconsFill` compile guard for the four tab icons *(file removed 2026-06-05 — compile guard via `app_bottom_nav.dart` imports; see `spec-test-suite-cleanup.md`)*
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **Sub-task B — Wire `AppScaffold` to 4 tabs** (AC: #3–#7)
  - [x] Replace Material `NavigationBar` + top `DecoratedBox` border with `AppBottomNav`
  - [x] Tab order: `0 Today`, `1 Trends → HistoryScreen`, `2 Data → MyDataScreen`, `3 Profil → ProfileScreen`
  - [x] Update `_onDestinationSelected` refresh hooks: Trends=index 1, Data=index 2; add Profil index 3 (no cubit refresh yet)
  - [x] Keep `_navigateToMyData` → `_selectedIndex = 2`
  - [x] Preserve cubit lifecycle, `ChartBenchmarkDevFab` on Trends (index 1), `AnimatedSwitcher`, debug FAB rules
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **Sub-task C — `ProfileScreen` placeholder** (AC: #5)
  - [x] Add `lib/presentation/screens/profile_screen.dart` using `TabPlaceholderBody` (title **Profil**, short placeholder copy)
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **Sub-task D — Theme / token cleanup** (AC: #1, #9)
  - [x] Decide: either repoint `navigationBarTheme` for tests that still find `NavigationBar`, **or** update tests to target `AppBottomNav` / semantics (preferred: tests assert new widget + tokens, not obsolete M3 bar theme)
  - [x] Remove dead top-border nav styling from `app_scaffold.dart`; document that floating nav colors come from `AstraColors.accentPrimary` until Story 5.8 preset wiring
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **Sub-task E — Tests** (AC: #9)
  - [x] Update `test/presentation/screens/app_scaffold_test.dart`: Phosphor icon finders (not `Icons.circle_outlined` / `bar_chart_outlined` / `shield_outlined`); labels TODAY/TRENDS/DATA/PROFIL; stale banner → DATA tab; optional golden-less widget test for active squircle
  - [x] Update `test/widget_test.dart` navigation expectations (4 tabs, TRENDS label)
  - [x] Run `flutter analyze` + `flutter test`
  - [x] **Stop → review brief → Baptiste OK → commit**

## Dev Notes

### Visual spec (Figma — Baptiste locked dimensions)

| Mockup | Workspace asset (session) |
|--------|---------------------------|
| Today light | `Today-light-89a9509b-7065-41bf-b25b-cec339039a7d.png` |
| Today dark | `Today-dark-ec96ba5e-5582-4baa-91c8-1e83f9bf4f95.png` |
| History / Trends light | `History-light-37de9970-368d-4e81-b0b1-1e8dcc792402.png` |

#### Dimensions (locked — do not approximate)

| Token | Value | Notes |
|-------|-------|-------|
| Bar height | **72px** | Total pill height |
| Bar horizontal padding | **24px** | Inside the orange pill (left + right) |
| Tab item box | **52×52px** | One destination control |
| Icon ↔ label gap | **6px** | Vertical spacing, both centered in 52×52 |
| Icon size | **24dp** | Unchanged from UX §1.6 |
| Bar corner radius | `kRadiusFull` | Stadium / capsule ends (outer pill only) |
| **Active squircle radius** | **16px** | `kBottomNavSquircleRadius` (= `kRadiusLg`) |
| **Squircle corner smoothing** | **100%** (Figma) | Flutter: `ContinuousRectangleBorder` or `RoundedSuperellipseBorder` — see implementation note below |

#### Squircle shape (Figma → Flutter)

Figma **corner smoothing 100%** is not the same as a standard rounded rectangle. Approximate it in Flutter:

```dart
// Recommended default (continuous corners / “squircle” feel)
decoration: ShapeDecoration(
  color: squircleFill,
  shape: ContinuousRectangleBorder(
    borderRadius: BorderRadius.circular(AstraSpacing.kBottomNavSquircleRadius),
  ),
)

// Optional closer superellipse (Flutter 3.27+, project on 3.44 — try in dev, keep Continuous as fallback)
// shape: RoundedSuperellipseBorder(
//   borderRadius: BorderRadius.circular(AstraSpacing.kBottomNavSquircleRadius),
// ),
```

Sign-off target: active tab background visually matches mockup squircle (smooth corners), not a hard circular-arc rounded rect.

#### States

| State | Squircle | Icon weight | Icon + label color |
|-------|----------|-------------|-------------------|
| **Active** | Yes — **52×52**, radius **16**, smoothing **100%** | **Fill** (`PhosphorIconsFill`) | `accentPrimary` on squircle |
| **Inactive** | No | **Regular** (`PhosphorIconsRegular`) | `textPrimary` on orange bar |

#### Theme variants

| Theme | Bar background | Active squircle | Priority in 5.7 |
|-------|----------------|-----------------|-----------------|
| **Light** | `accentPrimary` (orange) | **White** (`bgElevated`) | **Primary** — match Today + History mockups |
| **Dark** | `accentPrimary` (orange, unchanged) | **Charcoal** (use `bgBase` / dark surface token — not white) | **Best-effort** only; Baptiste: dark nav polish deferred to **5.8** accent/token pass |

**Do not** recreate Today / History screen content in this story — **shell nav only**.

#### Trends tab vs History screen

- **Tab label:** always **TRENDS** (all caps).
- **Screen body:** keep existing `HistoryScreen` (title “History”, 7/30 days chart) — mockup shows tab TRENDS active while header still says History; renaming in-screen copy is **out of scope** for 5.7.

### Story scope boundary

| In scope | Out of scope (later stories) |
|----------|------------------------------|
| 4-tab shell, floating pill, squircle active state, Phosphor tab icons | Six accent presets on nav (**5.8**) |
| Tab labels TODAY/TRENDS/DATA/PROFIL | Today Figma layout / stats row (**5.9**) |
| `ProfileScreen` placeholder | Profil Informations + Appearance (**5.11**) |
| Remap indices + stale → DATA navigation | Data screen sovereignty layout (**5.10**) |
| Test updates for navigation | Rename `HistoryScreen` in-screen title to “Trends” (deferred — tab label only in 5.7) |
| | Material → Phosphor sweep on non-tab UI (**5.12**) |

### Architecture compliance

| Source | Requirement |
|--------|-------------|
| D-10 | Four-tab floating pill shell; Phosphor tab icons; no GoRouter Phase 0 |
| D-27 | Phosphor **regular** (inactive) + **fill** (active) for tabs via **`phosphoricons_flutter`** |
| UX §2.1 | Floating pill, squircle active, safe area, 4 tabs |
| UX §4.3 | Tab hit area **52×52** (exceeds 48dp minimum) |
| Baptiste 2026-06-04 | Bar **72px**, padding **24px**, item **52×52**, gap **6px** |
| UX-DR18 | Reduce-motion → instant tab switch |

**Navigation state:** Keep local `StatefulWidget` index in `AppScaffold` — **no** `NavigationCubit` Phase 0.

### Package / API (Story 5.6 outcome)

```dart
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

// Inactive — 24dp
PhosphorIconsRegular.sneakerMove
PhosphorIconsRegular.chartBar
PhosphorIconsRegular.database
PhosphorIconsRegular.user

// Active — same names, Fill weight
PhosphorIconsFill.sneakerMove
PhosphorIconsFill.chartBar
PhosphorIconsFill.database
PhosphorIconsFill.user
```

Compile-time guard: `app_bottom_nav.dart` imports **both** `PhosphorIconsRegular` and `PhosphorIconsFill` for the four tab icons. Do **not** recreate `phosphoricons_flutter_test.dart` (removed Phase A — `spec-test-suite-cleanup.md`).

**Do not** switch to `phosphor_flutter` 2.x without planning doc amendment (Dart 3.12 `IconData` final).

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 5.7 changes | Must preserve |
|------|---------------|------------------|---------------|
| `lib/presentation/screens/app_scaffold.dart` | 3 tabs; Material icons; `NavigationBar` in `DecoratedBox` with **top border**; indices 0–2 | 4 tabs; `AppBottomNav`; Phosphor icons; remove top border | Cubit hoisting, ingestion callbacks, `onNavigateToMyData` → index **2**, FAB on Trends tab, `AnimatedSwitcher` |
| `lib/core/constants/astra_theme.dart` | `navigationBarTheme` → `bgElevated`, transparent indicator, accent/muted selected states | Likely **obsolete** for shell; update or leave for tests until Sub-task D | Light/dark `ThemeData` otherwise unchanged |
| `lib/presentation/screens/my_data_screen.dart` | Full My Data UI on tab 3 today → becomes tab **2** DATA | **Routing only** | All sovereignty features until 5.10 splits UI |
| `lib/presentation/screens/history_screen.dart` | History charts | Shown on tab **1**; tab label TRENDS only | Chart logic, cubit refresh |
| `lib/presentation/screens/today_screen.dart` | `onNavigateToMyData` callback | Still navigates to DATA tab | Truth model, goal ring |
| `profile_screen.dart` | **Missing** | **New** placeholder | — |

### Tab index map (after 5.7)

| Index | Label | Screen | Cubit |
|-------|-------|--------|-------|
| 0 | TODAY | `TodayScreen` | `TodayCubit` |
| 1 | TRENDS | `HistoryScreen` | `HistoryCubit` |
| 2 | DATA | `MyDataScreen` | `MyDataCubit` |
| 3 | PROFIL | `ProfileScreen` (placeholder) | — (5.11) |

### Recommended `AppBottomNav` structure

```dart
// Structural guide — adapt to project style
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  // Row of 4 Expanded children; each tab SizedBox(52, 52)
  // selected: ShapeDecoration 52×52, ContinuousRectangleBorder r=16 + Column(icon Fill, gap 6, label)
  // unselected: Column(icon Regular, gap 6, label) — no squircle
}
```

**Scaffold integration:**

```dart
bottomNavigationBar: AppBottomNav(
  selectedIndex: _selectedIndex,
  onSelected: _onDestinationSelected,
),
```

Consider `extendBody: false` and bottom **padding** on scrollable screens if content is obscured — verify on Today mockup (week strip above bar). Minimum: ensure last Today card is not hidden under floating bar.

### Theming note (until Story 5.8)

- Pill background: always `accentPrimary` (orange in default preset).
- Active squircle: light → `bgElevated` (white); dark → charcoal surface token (best-effort).
- **Story 5.8** will introduce preset-aware nav/squircle tokens — use semantic colors only, **no hardcoded hex** (V-2).
- Baptiste: **dark theme nav is not a 5.7 acceptance blocker**; light mockups are the sign-off target.

### Regression guardrails

- Do not add GoRouter or new global navigation cubit.
- Do not move theme/display-name/goal editors off `MyDataScreen` in this story (5.10 / 5.11).
- Do not change onboarding shell (no `NavigationBar` on onboarding — existing tests).
- Keep `ChartBenchmarkDevFab` on **index 1** (Trends).
- Run full `flutter test` — WM/FGS/DB suites must stay green.

### Project Structure Notes

- New: `lib/presentation/widgets/app_bottom_nav.dart`
- New: `lib/presentation/screens/profile_screen.dart`
- Update: `app_scaffold.dart`, tests listed in Sub-task E
- **Required:** `astra_spacing.dart` — `kBottomNavBarHeight`, `kBottomNavHorizontalPadding`, `kBottomNavItemSize`, `kBottomNavIconLabelGap`, `kBottomNavSquircleRadius` (16)
- Optional: outer float margin constant if needed beyond 24px inner padding

### References

- [Source: _bmad-output/planning-artifacts/epics.md § Story 5.7]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md §1.6, §2.1, D-17]
- [Source: _bmad-output/planning-artifacts/architecture.md — D-10, Navigation, Cubit refresh table]
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-06-04.md — floating pill AC]
- [Source: _bmad-output/implementation-artifacts/stories/5-6-phosphor-icons-dependency.md]
- [Source: _bmad-output/implementation-artifacts/stories/1-3-app-scaffold-and-bottom-navigation.md — AnimatedSwitcher, reduce motion]
- [Source: docs/project-context.md — review-before-commit workflow]
- Mockups: Today light, Today dark, History/Trends light (session assets / Figma)

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- Used `ContinuousRectangleBorder` for active squircle (Figma smoothing 100%); `RoundedSuperellipseBorder` not required on Flutter 3.44.
- Dark squircle fill: `bgBase`; light: `bgElevated`.

### Completion Notes List

- Implemented floating 72px pill `AppBottomNav` with 4 tabs (TODAY/TRENDS/DATA/PROFIL), Phosphor Regular/Fill icons, 52×52 squircle active state.
- Wired `AppScaffold` to 4 tabs; `ProfileScreen` placeholder; stale banner → DATA (index 2).
- Updated navigation tests; full `flutter test` green; `flutter analyze` no new issues.

### File List

- lib/core/constants/astra_spacing.dart
- lib/core/constants/astra_theme.dart
- lib/presentation/widgets/app_bottom_nav.dart
- lib/presentation/screens/app_scaffold.dart
- lib/presentation/screens/profile_screen.dart
- ~~test/dependencies/phosphoricons_flutter_test.dart~~ (removed 2026-06-05)
- ~~test/presentation/widgets/app_bottom_nav_test.dart~~ (removed 2026-06-05)
- test/presentation/screens/app_scaffold_test.dart
- test/widget_test.dart

### Change Log

- 2026-06-04: Story 5.7 implemented — four-tab floating navigation, tests updated, status → review.
- 2026-06-05: Dedicated nav/phosphor test files removed — coverage via `app_scaffold_test.dart` + `widget_test.dart` (`spec-test-suite-cleanup.md`).

- 2026-06-04: Baptiste refinements — 72px bar, 24px padding, 52×52 items, 6px icon-label gap, Regular→Fill active icons, dark squircle charcoal (best-effort), History screen mockup, Profil placeholder confirmed.
- 2026-06-04: Squircle radius **16px**, Figma corner smoothing **100%** → `ContinuousRectangleBorder` / optional `RoundedSuperellipseBorder`.

## Previous Story Intelligence

**Story 5.6 (Phosphor dependency — done):**

- Installed **`phosphoricons_flutter` ^1.0.0** (not `phosphor_flutter` — Dart 3.12 compat).
- **No `lib/` changes** in 5.6 — all icon/nav work is **this story**.
- API smoke test locks four tab icon names for 5.7.
- Review/commit discipline: sub-tasks + Baptiste OK before each commit.

**Story 1.3 (App scaffold — done):**

- `AnimatedSwitcher` + reduce-motion guard is mandatory — do not regress.
- Phase 0 used Material outlined icons **intentionally** until Epic 5.
- `navigationBarTheme` on `bgElevated` + top border — **replaced** by floating accent pill in 5.7.

## Git Intelligence Summary

Recent commits (2026-06-04):

- `30b9d65` — Story 5.6 done (phosphoricons_flutter + DEPENDENCIES + API test)
- `d03b6c2` — Dart 3.12 IconData fix (package swap)
- `8864bc8` / `91b57cc` — Epic 5 planning alignment (4-tab order)

No in-flight nav UI work — safe to refactor `app_scaffold.dart`.

## Latest Tech Information

| Topic | Detail |
|-------|--------|
| `phosphoricons_flutter` 1.0.0 | `PhosphorIconsRegular` (inactive) + `PhosphorIconsFill` (active) for same four tab icons |
| Material `NavigationBar` | M3 indicator is a pill behind **icon only** — poor fit for Figma squircle around icon+label; **custom `AppBottomNav` preferred** |
| Flutter 3.44 | `SafeArea` on `bottomNavigationBar` respects gesture inset |
| Accent presets | Deferred to 5.8 — use current `AstraColors` factories |

## Project Context Reference

Follow [`docs/project-context.md`](../../../docs/project-context.md):

- One commit per sub-task after Baptiste review brief
- No push unless requested
- Do not edit `docs/DEPENDENCIES.md` unless adding packages (not expected in 5.7)
