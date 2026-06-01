# Story 1.3: App Scaffold and Bottom Navigation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want a three-tab navigation shell (Today, History, My Data),
So that I can move between the main surfaces of the Hub App intuitively.

## Acceptance Criteria

1. **Given** onboarding is complete (or skipped in dev builds — see Dev Notes)
   **When** the main app loads
   **Then** `AppScaffold` displays a bottom `NavigationBar` with Today · History · My Data tabs (UX-DR4)
   **And** the active tab uses amber accent (`color.accent.primary`); inactive tabs use muted color (`color.text.muted`)
   **And** the tab bar surface uses `color.bg.elevated` with a top border `color.border.default`

2. **Given** the user taps a tab
   **When** navigation occurs
   **Then** content cross-fades in ~200ms (UX-DR18)
   **And** if OS reduce-motion is enabled (`MediaQuery.disableAnimations`), content swaps instantly with no fade
   **And** placeholder screens exist for each tab until feature epics implement them

3. **Given** the app shell is displayed
   **When** inspected on Android gesture-navigation devices
   **Then** bottom safe area inset is respected (56dp bar height + system inset per UX-DR3 / UX §1.4)

4. **Given** Story 1.2 theme system is in place
   **When** any tab placeholder renders
   **Then** backgrounds use `context.astraColors.bgBase`, titles use `AstraTypography.title`, horizontal padding uses `AstraSpacing.kScreenHorizontalPadding` (16dp)

## Tasks / Subtasks

- [x] **Sub-task A — `AppScaffold` + tab chrome** (AC: #1, #3)
  - [x] Create `lib/presentation/screens/app_scaffold.dart` — `StatefulWidget` holding selected tab index (0 = Today default)
  - [x] Bottom `NavigationBar` with 3 destinations: labels **Today**, **History**, **My Data** (sentence case)
  - [x] Tab icons per UX §1.6 (Material outlined equivalents): Today = `Icons.circle_outlined`, History = `Icons.bar_chart_outlined`, My Data = `Icons.shield_outlined`
  - [x] Style via `NavigationBarTheme` in `astra_theme.dart` + top `borderDefault` on `DecoratedBox` wrapper
  - [x] Target bar height **56dp** via `NavigationBarThemeData(height: kBottomTabBarHeight)` in both themes
  - [x] Scaffold `backgroundColor: colors.bgBase`; **no** drawer, **no** AppBar on shell (per UX-DR4)
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (`e6011d2`)

- [x] **Sub-task B — Tab content + motion** (AC: #2, #4)
  - [x] Create placeholder screens: `today_screen.dart`, `history_screen.dart`, `my_data_screen.dart`
  - [x] Shared `TabPlaceholderBody` — title via `AstraTypography.title`, body via `AstraTypography.body`, explicit `bgBase`, `SingleChildScrollView` for large text scale
  - [x] `AnimatedSwitcher` + `ValueKey<int>(index)` cross-fade **200ms**; `layoutBuilder` top-aligns stack (code-review fix)
  - [x] Reduce-motion: `Duration.zero` via `MediaQuery.disableAnimationsOf(context)`
  - [x] Default selected tab on cold start: **Today** (index 0)
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (`bc272c0`, `7766ade`)

- [x] **Sub-task C — App entry wiring** (AC: #1)
  - [x] Update `lib/app.dart` — `MaterialApp.home: const AppScaffold()` (replaced `ThemePreviewScreen`)
  - [x] Delete `lib/presentation/screens/theme_preview_screen.dart`
  - [x] Dev onboarding skip: direct `AppScaffold` home until Story 1.5
  - [x] No `OnboardingCubit`, `GoRouter`, or new navigation packages
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (`de800bf`)

- [x] **Sub-task D — Tests & verification** (AC: #1–#4)
  - [x] `test/widget_test.dart` — `AstraApp` + `NavigationBar` labels; tab switch via icons
  - [x] `test/presentation/screens/app_scaffold_test.dart` — reduce-motion, text scale 2.5×, `navigationBarTheme` token assertions
  - [x] `Semantics` + `tooltip` on `NavigationDestination` icons (UX §4.3 baseline)
  - [x] `flutter analyze` (zero issues) and `flutter test` (13 pass)
  - [ ] Manual: Android emulator with gesture nav → confirm tab bar clears home indicator (deferred — Baptiste device check)
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (`20c6a3c`, `7766ade`)

### Review Findings

- [x] [Review][Patch] `AnimatedSwitcher` default center alignment caused vertical content jump during tab cross-fade [`lib/presentation/screens/app_scaffold.dart`] — **Resolved:** `layoutBuilder` with `Alignment.topCenter` (`7766ade`)

- [x] [Review][Patch] Placeholder `Column` could overflow at large text scale [`lib/presentation/screens/*_screen.dart`] — **Resolved:** `TabPlaceholderBody` with `SingleChildScrollView` + explicit `ColoredBox(bgBase)` (`7766ade`)

- [x] [Review][Patch] Navigation bar theme tokens not covered by automated tests [`test/presentation/screens/app_scaffold_test.dart`] — **Resolved:** height, colors, top border assertions (`7766ade`)

- [x] [Review][Patch] `widget_test` tab taps via label text (fragile on narrow layouts) [`test/widget_test.dart`] — **Resolved:** icon-based taps (`7766ade`)

- [x] [Review][Patch] Optional nav `Semantics` baseline missing [`lib/presentation/screens/app_scaffold.dart`] — **Resolved:** `Semantics` + `tooltip` per destination (`7766ade`)

- [ ] [Review][Defer] Manual gesture-navigation safe-area verification (AC #3) — deferred; spec requires Android emulator check by Baptiste

## Dev Notes

### Story scope boundary (critical)

**In scope for 1.3:**
- `AppScaffold` persistent 3-tab shell with Material 3 `NavigationBar`
- Three placeholder tab screens (minimal copy, token-compliant layout)
- Tab cross-fade 200ms + reduce-motion instant swap
- Wire `AstraApp` home to shell; remove theme preview screen
- `NavigationBarThemeData` in `astra_theme.dart` for bar height/surface colors
- Widget tests for nav + placeholders

**Out of scope — defer to later stories:**
- `OnboardingCubit` + full-screen onboarding stack → **Story 1.5** (will gate `MaterialApp.home` between onboarding vs `AppScaffold`)
- `user_preferences` / onboarding completion flag persistence → **Story 1.4** (DB) + **1.5** (UI)
- `TodayCubit`, `HistoryCubit`, `MyDataCubit` → **Epic 2–4**
- Feature widgets (`GoalRing`, charts, My Data cards) → **Epic 2–4**
- `AppDependencies` composition root → **Story 1.4+**
- GoRouter / deep links → **forbidden Phase 0**
- Custom icon font packages (Phosphor) → use Material `Icons.*_outlined` for Phase 0

Do not over-implement. Story 1.3 ends with a **themed tab shell + placeholders** — not data, onboarding, or feature UI.

### Onboarding gate (Story 1.5 prep)

Epics AC: *"Given onboarding is complete (or skipped in dev builds)"*.

**For 1.3 only:** Route `MaterialApp.home` directly to `AppScaffold`. This is the intentional **dev skip** until Story 1.5 adds:

```dart
// Future pattern (1.5) — do NOT implement now
home: onboardingComplete ? const AppScaffold() : const OnboardingFlow(),
```

Story 1.4 will persist `onboarding_complete` in `user_preferences`; Story 1.5 reads it. Do not add SQLite or fake onboarding UI in 1.3.

### Mandatory dev workflow

Follow [`docs/project-context.md`](../../../docs/project-context.md):

- One commit per sub-task (A, B, C, D) after Baptiste review
- Review brief format required before each commit
- No push unless explicitly requested

### Current repo state (post Story 1.3)

| Item | State |
|------|-------|
| `lib/app.dart` | `MaterialApp.home: const AppScaffold()` — dev onboarding skip until 1.5 |
| `lib/presentation/screens/` | `app_scaffold.dart` + three placeholder screens |
| `lib/presentation/widgets/` | `tab_placeholder_body.dart` — shared placeholder layout |
| `lib/core/constants/astra_theme.dart` | `navigationBarTheme` in light/dark builders |
| `lib/core/constants/astra_spacing.dart` | `kBottomTabBarHeight = 56` |
| `theme_preview_screen.dart` | **Deleted** (Story 1.2 temporary) |
| Navigation pattern | `AppScaffold` + local tab index — no GoRouter |
| `ThemeCubit` | Unchanged in `app.dart` |

### `AppScaffold` implementation pattern (recommended)

```dart
// app_scaffold.dart — structural guide (adapt to project style)
class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _index = 0; // Today default

  static const _tabs = [
    (label: 'Today', icon: Icons.circle_outlined, screen: TodayScreen()),
    (label: 'History', icon: Icons.bar_chart_outlined, screen: HistoryScreen()),
    (label: 'My Data', icon: Icons.shield_outlined, screen: MyDataScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [...previousChildren, ?currentChild],
        ),
        child: KeyedSubtree(
          key: ValueKey<int>(_index),
          child: _tabs[_index].screen,
        ),
      ),
      bottomNavigationBar: /* NavigationBar with token styling + top border */,
    );
  }
}
```

**Navigation state:** Local `StatefulWidget` index — **no** `NavigationCubit` Phase 0 (architecture: minimal friction for 3 tabs).

**Do not use `IndexedStack`** if you need visible cross-fade — `AnimatedSwitcher` matches UX-DR18. Accept that tab scroll position resets on revisit (placeholders only).

### NavigationBar theming (extend `astra_theme.dart`)

Add to both `buildAstraLightTheme()` and `buildAstraDarkTheme()`:

| Property | Token / value |
|----------|----------------|
| `height` | `AstraSpacing.kBottomTabBarHeight` (56) |
| `backgroundColor` | `colors.bgElevated` |
| `indicatorColor` | `Colors.transparent` or `colors.accentPrimaryMuted` (subtle; avoid heavy M3 pill) |
| `iconTheme` (selected) | `colors.accentPrimary` |
| `iconTheme` (unselected) | `colors.textMuted` |
| `labelTextStyle` | `AstraTypography.labelFor(colors)` with color overrides for selected/unselected |

Top border: wrap `NavigationBar` in `DecoratedBox` with `Border(top: BorderSide(color: colors.borderDefault))`.

### Placeholder screen copy (suggested)

| Screen | Title | Placeholder line |
|--------|-------|------------------|
| Today | Today | Step tracking and your goal ring will appear here. |
| History | History | Your 7-day and 30-day charts will appear here. |
| My Data | My Data | Data footprint, export, and settings will appear here. |

Use `SafeArea` on body content (top only); bottom inset handled by `NavigationBar` + scaffold.

### Suggested file tree after 1.3

```
lib/
├── app.dart                              # home: AppScaffold
├── presentation/
│   ├── screens/
│   │   ├── app_scaffold.dart
│   │   ├── today_screen.dart
│   │   ├── history_screen.dart
│   │   └── my_data_screen.dart
│   └── widgets/
│       └── tab_placeholder_body.dart
└── core/constants/
    ├── astra_spacing.dart                # kBottomTabBarHeight
    └── astra_theme.dart                  # navigationBarTheme

test/
├── widget_test.dart
└── presentation/screens/
    └── app_scaffold_test.dart
```

### Anti-patterns (do not do in 1.3)

- ❌ Add `go_router`, `auto_route`, or `Navigator 2.0` routing graph
- ❌ Add `NavigationCubit` / `TabCubit` without architecture mandate
- ❌ Build onboarding flow, permission dialogs, or SQLite — Stories 1.4 / 1.5
- ❌ Hardcode hex colors in shell/widgets — use `context.astraColors`
- ❌ Keep `ThemePreviewScreen` as home or dead code
- ❌ Import sqflite, workmanager, pedometer, etc.
- ❌ Add second bottom bar (no drawer + no duplicate nav)
- ❌ Batch sub-tasks A+B+C+D into one commit
- ❌ Commit without Baptiste review approval

### Epic 1 cross-story context

| Story | Focus | Depends on 1.3 |
|-------|-------|----------------|
| 1.2 (done) | Tokens, fonts, `ThemeCubit`, `AstraApp` | — |
| **1.3** (this) | Tab shell + placeholders | Uses `AstraColors`, spacing, typography |
| 1.4 | `user_preferences` DB + `AppDependencies` | Shell unchanged; may inject prefs into `ThemeCubit` |
| 1.5 | Onboarding → land on **Today tab** | Wraps `AppScaffold`; sets `_index = 0` on complete |

Epic 2+ screens replace placeholders **in place** (`today_screen.dart`, etc.) — keep file paths stable.

### Project Structure Notes

- Aligns with Architecture `lib/presentation/screens/app_scaffold.dart` + `today_screen.dart` + `history_screen.dart` + `my_data_screen.dart`
- Navigation: `AppScaffold` + `NavigationBar` — **no GoRouter** (Architecture Frontend §)
- Tests mirror `lib/` under `test/` per naming patterns

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Story 1.3, UX-DR4, UX-DR18]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — §1.4 Layout, §1.5 Motion, §1.6 Icons, §2.1 AppScaffold]
- [Source: _bmad-output/planning-artifacts/architecture.md — Navigation, lib/presentation/screens/]
- [Source: _bmad-output/implementation-artifacts/stories/1-2-design-tokens-and-theme-system.md — prior learnings]
- [Source: docs/project-context.md — review-before-commit workflow]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- Sub-tasks A–D delivered in five commits on `main` (`e6011d2` → `7766ade`) after Baptiste review gates
- Code review (2026-06-01): cross-fade top-alignment, scrollable placeholders, extended shell tests — patched in `7766ade`
- `flutter analyze` zero issues; `flutter test` 13/13 pass (includes `navigationBarTheme` and text-scale coverage)
- Dev onboarding intentionally skipped: `AstraApp` launches directly into `AppScaffold` until Story 1.5
- Manual AC #3 (gesture-nav safe area) left for device verification on Android emulator

### File List

- `lib/presentation/screens/app_scaffold.dart` (new)
- `lib/presentation/screens/today_screen.dart` (new)
- `lib/presentation/screens/history_screen.dart` (new)
- `lib/presentation/screens/my_data_screen.dart` (new)
- `lib/presentation/widgets/tab_placeholder_body.dart` (new)
- `lib/presentation/screens/theme_preview_screen.dart` (deleted)
- `lib/core/constants/astra_spacing.dart` (updated — `kBottomTabBarHeight`)
- `lib/core/constants/astra_theme.dart` (updated — `navigationBarTheme`)
- `lib/app.dart` (updated — `home: AppScaffold`)
- `test/widget_test.dart` (updated)
- `test/presentation/screens/app_scaffold_test.dart` (new)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (updated)
- `_bmad-output/implementation-artifacts/stories/1-3-app-scaffold-and-bottom-navigation.md` (updated)

## Technical Requirements

1. **AppScaffold:** Persistent frame; `Scaffold` + M3 `NavigationBar`; 3 tabs; no drawer/settings tab
2. **Tab styling:** Active amber `accentPrimary`; inactive `textMuted`; bar `bgElevated` + top `borderDefault`
3. **Bar height:** 56dp (`kBottomTabBarHeight`) + system safe area inset
4. **Motion:** Cross-fade 200ms on tab change; instant when `MediaQuery.disableAnimations`
5. **Placeholders:** Three minimal token-compliant screens with factual copy
6. **Entry:** `AstraApp` → `AppScaffold`; remove theme preview screen
7. **Onboarding:** Dev-skip direct to shell (1.5 will add gate)
8. **Analyzer:** `flutter analyze` zero issues; `flutter test` all pass

## Architecture Compliance

| Decision | Requirement for 1.3 |
|----------|----------------------|
| Navigation | `AppScaffold` + `NavigationBar` — **no GoRouter** Phase 0 |
| State management | Local tab index in `StatefulWidget` — no new Cubit for nav |
| Design tokens | `context.astraColors`, `AstraTypography`, `AstraSpacing` only |
| Theme | Extend `astra_theme.dart`; preserve `ThemeCubit` wiring in `app.dart` |
| File layout | Screens in `lib/presentation/screens/` per Architecture tree |
| DI | Inline `BlocProvider<ThemeCubit>` only — no `AppDependencies` yet |
| Offline / deps | No new packages |

## Library & Framework Requirements

| Package | Version | 1.3 action |
|---------|---------|------------|
| flutter (Material 3) | SDK | `NavigationBar`, `AnimatedSwitcher`, `Icons` outlined variants |
| flutter_bloc | ^9.1.1 | **Unchanged** — `ThemeCubit` only |
| All locked deps | unchanged | **Do not import** sqflite, workmanager, etc. |

**Do NOT add:** `go_router`, `auto_route`, icon packs, animation packages.

## File Structure Requirements

| Path | Action |
|------|--------|
| `lib/presentation/screens/app_scaffold.dart` | NEW |
| `lib/presentation/screens/today_screen.dart` | NEW |
| `lib/presentation/screens/history_screen.dart` | NEW |
| `lib/presentation/screens/my_data_screen.dart` | NEW |
| `lib/presentation/widgets/tab_placeholder_body.dart` | NEW |
| `lib/presentation/screens/theme_preview_screen.dart` | DELETE |
| `lib/core/constants/astra_spacing.dart` | UPDATE — `kBottomTabBarHeight = 56` |
| `lib/core/constants/astra_theme.dart` | UPDATE — `navigationBarTheme` |
| `lib/app.dart` | UPDATE — `home: AppScaffold` |
| `test/widget_test.dart` | UPDATE |
| `test/presentation/screens/app_scaffold_test.dart` | NEW |

## Testing Requirements

- **Widget:** `widget_test.dart` — `AstraApp` shows `NavigationBar` with Today/History/My Data; tab tap switches placeholder text
- **Widget:** `app_scaffold_test.dart` — reduce-motion path uses zero-duration switch (no pump-and-settle timeout on 200ms animation)
- **Manual:** Gesture-nav Android emulator — bottom inset clear
- **Manual:** OS reduce-motion → instant tab swap
- **Commands:** `flutter analyze` (0 issues), `flutter test` (all pass)
- **Not required:** Golden tests, onboarding flow tests (Story 1.5)

## Previous Story Intelligence

From **Story 1.2** (done):

- `AstraApp` + `ThemeCubit` + `BlocProvider` pattern established in `app.dart` — **preserve** when changing `home`
- `context.astraColors` extension on `BuildContext` — use in all new widgets
- `AstraTypography.title(context)` for screen titles; Figtree label for tab labels
- `ThemePreviewScreen` was explicitly temporary — **delete**, do not leave orphaned
- Review-before-commit: **4 sub-tasks** (A–D), Baptiste OK before each commit
- Widget test pattern: pump `AstraApp`, use `Key` for touch targets — update for nav assertions
- `flutter analyze` / `flutter test` must stay clean
- No SQLite, no `AppDependencies`, no feature cubits yet

From **Story 1.1** (done):

- Flutter **3.44.0** / Dart **3.12.0**
- Package name `astra_app`; import prefix `package:astra_app/...`

## Git Intelligence Summary

Recent commits (Story 1.3):

| Commit | Relevance |
|--------|-----------|
| `e6011d2` | `feat(shell):` AppScaffold + NavigationBar theme |
| `bc272c0` | `feat(nav):` placeholders + AnimatedSwitcher |
| `de800bf` | `feat(app):` home → AppScaffold; delete theme preview |
| `20c6a3c` | `test(shell):` widget + reduce-motion tests |
| `7766ade` | `fix(shell):` code-review hardening (layout, placeholders, tests) |

**Convention:** `feat(shell): ...`, `feat(nav): ...`, `test(shell): ...`, `fix(shell): ...` scoped commits.

## Latest Tech Information

- **Flutter 3.44 / Material 3 `NavigationBar`:** Prefer `NavigationBar` + `NavigationDestination` (not deprecated `BottomNavigationBar`) for M3 alignment
- **Reduce motion:** `MediaQuery.disableAnimationsOf(context)` returns true when platform requests reduced motion — use for `Duration.zero` on `AnimatedSwitcher` [Flutter MediaQuery](https://api.flutter.dev/flutter/widgets/MediaQuery/disableAnimationsOf.html)
- **AnimatedSwitcher:** `KeyedSubtree` + `ValueKey(tabIndex)` required for child identity; default fade works for cross-fade; 200ms matches UX-DR18
- **Safe area:** `NavigationBar` inside `Scaffold.bottomNavigationBar` respects bottom inset automatically on current Flutter; verify on API 34+ gesture-nav emulator
- **NavigationBarThemeData.height:** Supported in Material 3 themes — set to 56 for UX compliance
- **No GoRouter:** Intentional Phase 0 — index state only

## Project Context Reference

Mandatory for all stories — [`docs/project-context.md`](../../../docs/project-context.md):

- Review-before-commit gate (4 sub-task commits)
- Commit message convention: `type(scope): imperative summary`
- Story file path: `_bmad-output/implementation-artifacts/stories/1-3-app-scaffold-and-bottom-navigation.md`

## Story Completion Status

- Status: **done**
- Code review completed 2026-06-01; patch findings resolved in `7766ade`
- Epic 1 status: **in-progress** (stories 1.1–1.3 done; 1.4 next)
- Next story: **1-4-user-preferences-persistence**
- Open manual check: gesture-navigation safe area on Android emulator (AC #3)
