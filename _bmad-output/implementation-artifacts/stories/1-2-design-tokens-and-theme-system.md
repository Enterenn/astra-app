# Story 1.2: Design Tokens and Theme System

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want the app to respect my OS light/dark setting by default with consistent ASTRA visual tokens,
So that the interface feels polished in either appearance from first launch.

## Acceptance Criteria

1. **Given** Figtree and Darker Grotesque fonts are bundled in `assets/fonts/` (no network fetch)
   **When** the app launches for the first time
   **Then** `ThemeMode.system` is active and `AstraColors` semantic tokens apply for both light and dark palettes (UX-DR1, UX-DR2, UX-DR3)
   **And** `theme_mode` defaults to `system` in memory before preferences DB exists (FR9, FR31 infrastructure)

2. **Given** the OS switches between light and dark while `theme_mode` is `system`
   **When** the app is in foreground
   **Then** the UI updates to match the OS theme without restart

3. **Given** spacing and radius tokens are defined
   **When** any scaffold screen renders
   **Then** horizontal padding uses the 4px grid minimum 16dp and touch targets meet 48dp where interactive (UX-DR3)

## Tasks / Subtasks

- [x] **Sub-task A — Font assets (offline-first)** (AC: #1)
  - [x] Download Figtree and Darker Grotesque variable fonts from [Google Fonts](https://fonts.google.com/) into `assets/fonts/` — **commit the `.ttf` files**; no `google_fonts` package, no runtime CDN fetch (UX §1.3, FR-18)
  - [x] Register font files in `pubspec.yaml` under `flutter: fonts:` with exact filenames
  - [x] Add fonts section to `docs/DEPENDENCIES.md` (create file if absent): family names, file paths, SIL OFL license note, confirm zero network use
  - [x] Run `flutter pub get` — must succeed
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Design token constants** (AC: #1, #3)
  - [x] Create `lib/core/constants/astra_spacing.dart` — `AstraSpacing.kSpaceXs` (4) through `AstraSpacing.kSpace2xl` (48), `AstraSpacing.kRadiusSm` (8) through `AstraSpacing.kRadiusFull` (999), `AstraSpacing.kMinTouchTarget` (48), `AstraSpacing.kScreenHorizontalPadding` (16)
  - [x] Create `lib/core/constants/astra_typography.dart` — token helpers mapping UX §1.3 sizes/weights to Figtree / Darker Grotesque (`type.display` 52sp through `type.caption` 12sp)
  - [x] Create `lib/core/constants/astra_colors.dart` — `AstraColors extends ThemeExtension<AstraColors>` with **paired** light + dark factory constructors (`AstraColors.light()`, `AstraColors.dark()`); implement `copyWith` + `lerp`; all hex values from UX §1.2 (see Dev Notes table)
  - [x] Add `extension AstraThemeContext on BuildContext` → `astraColors` accessor
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Theme builders + app wiring** (AC: #1, #2, #3)
  - [x] Create `lib/core/constants/astra_theme.dart` — `ThemeData buildAstraLightTheme()` and `buildAstraDarkTheme()` wiring:
    - `useMaterial3: true`
    - `ColorScheme` mapped per UX Flutter mapping note (`primary` = accent, `surface` = bg.elevated, `error` = status.danger, `scaffoldBackgroundColor` = bg.base)
    - `extensions: [AstraColors.light()]` / `[AstraColors.dark()]`
    - `TextTheme` from `astra_typography.dart` tokens
    - `fontFamily: 'Figtree'` default; Darker Grotesque only on display/title/data styles
  - [x] Create `lib/presentation/cubits/theme_cubit.dart` + `theme_state.dart`:
    - `enum AstraThemePreference { system, light, dark }` (maps 1:1 to future DB `theme_mode` string values)
    - **Default state:** `AstraThemePreference.system` (in-memory only — no SQLite yet)
    - `ThemeMode get materialThemeMode` derived from preference
    - **Do not** add `setThemeMode()` persistence API yet — deferred to Story 4.7 (ThemeSelector); Story 1.4 will add repository load at startup
  - [x] Create `lib/app.dart` — `AstraApp` widget: `BlocProvider<ThemeCubit>`, `MaterialApp` with `theme`, `darkTheme`, `themeMode: context.watch<ThemeCubit>().state.materialThemeMode`
  - [x] Update `lib/main.dart` — `runApp(const AstraApp())`; remove Hello World demo
  - [x] Create minimal `lib/presentation/screens/theme_preview_screen.dart` (temporary until Story 1.3 replaces with tab shell):
    - `Scaffold` using `context.astraColors.bgBase` via tokens (not hardcoded hex)
    - Horizontal padding `AstraSpacing.kScreenHorizontalPadding` (16dp)
    - Sample text at each typography token
    - One interactive `FilledButton` with min height `AstraSpacing.kMinTouchTarget` (48dp) demonstrating accent + inverse text
    - Swatch row showing accent, status, data tokens
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Tests & verification** (AC: #1, #2, #3)
  - [x] `test/core/constants/astra_colors_test.dart` — spot-check 3+ light and 3+ dark token hex values match UX spec; verify `lerp` at t=0 and t=1
  - [x] `test/presentation/cubits/theme_cubit_test.dart` — initial state is `system`; `materialThemeMode == ThemeMode.system`
  - [x] Update `test/widget_test.dart` — pump `AstraApp`, verify preview screen renders, button meets 48dp min height constraint, no "Hello World"
  - [x] Manual: toggle OS light/dark on device/emulator while app foregrounded → preview screen colors update without hot restart
  - [x] Run `flutter analyze` (zero issues) and `flutter test` (all pass)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

### Review Findings

- [x] [Review][Decision] Variable fonts vs five static font files — **Resolved:** keep 2 variable-font files; update spec file tree to match.

- [x] [Review][Decision] Spacing constant namespace — **Resolved:** keep `AstraSpacing.k*` namespace (consistent with `AstraTypography`, preserves `k` prefix, avoids global pollution); update spec Sub-task B wording.

- [x] [Review][Patch] Update spec file tree and font requirements for variable-font approach [`1-2-design-tokens-and-theme-system.md`]

- [x] [Review][Patch] Update spec Sub-task B spacing naming to document `AstraSpacing.k*` pattern [`1-2-design-tokens-and-theme-system.md`]

- [x] [Review][Patch] TextTheme duplicated instead of sourced from typography tokens [`lib/core/constants/astra_theme.dart:6-36`]

- [x] [Review][Patch] Opacity-derived color tokens untested (28%, 80%, 35%) [`test/core/constants/astra_colors_test.dart`]

- [x] [Review][Patch] Incomplete hex coverage for semantic color tokens [`test/core/constants/astra_colors_test.dart`]

- [x] [Review][Patch] Widget test 48dp assertion uses first SizedBox ancestor (brittle) [`test/widget_test.dart:16-21`]

- [x] [Review][Patch] Widget test missing AC #3 horizontal padding assertion (16dp) [`test/widget_test.dart`]

- [x] [Review][Patch] Missing trailing newlines in modified text files [`pubspec.yaml`, `docs/DEPENDENCIES.md`, `lib/core/constants/astra_colors.dart`]

- [x] [Review][Patch] Mis-indented `@override` before `copyWith` [`lib/core/constants/astra_colors.dart:664`]

- [x] [Review][Defer] Unrelated `.gitignore` JetBrains entries bundled with story [`.gitignore`] — deferred, pre-existing

- [x] [Review][Defer] Preview screen safe-area / text-scale / overflow edge cases [`lib/presentation/screens/theme_preview_screen.dart`] — deferred, pre-existing

- [x] [Review][Defer] Partial Material 3 ColorScheme role mapping [`lib/core/constants/astra_theme.dart:64-72`] — deferred, pre-existing

- [x] [Review][Defer] `copyWith` and mid-range `lerp` tests not added [`test/core/constants/astra_colors_test.dart`] — deferred, pre-existing

- [x] [Review][Defer] No widget tests asserting bundled font families applied [`test/widget_test.dart`] — deferred, pre-existing

- [x] [Review][Defer] No dedicated unit tests for `astra_theme`, `astra_spacing`, `astra_typography` — deferred, pre-existing

- [x] [Review][Defer] AC #2 OS brightness toggle has no automated widget test (spec requires manual verification) — deferred, pre-existing

## Dev Notes

### Story scope boundary (critical)

**In scope for 1.2:**
- Bundled fonts + pubspec registration
- `AstraColors` ThemeExtension with full light/dark semantic token sets
- Spacing, radius, typography token constants
- `ThemeData.light()` / `ThemeData.dark()` builders
- Minimal `ThemeCubit` with in-memory default `system` → `ThemeMode.system`
- `MaterialApp` wired for OS-reactive system theme
- Temporary theme preview screen proving tokens render correctly
- Unit + widget tests for tokens and theme default

**Out of scope — defer to later stories:**
- `AppScaffold` + 3-tab `NavigationBar` → **Story 1.3**
- `user_preferences` table + `UserPreferencesRepository` + DB persistence → **Story 1.4**
- `ThemeSelector` UI on My Data + `setThemeMode()` persistence + cold-start flash prevention → **Story 4.7**
- Full `AppDependencies` composition root → **Story 1.4+** (use inline `BlocProvider` in `app.dart` for now)
- Feature widgets (`GoalRing`, `AstraButton`, `StatusBanner`, etc.) → **Epic 2+**
- `google_fonts` package → **forbidden** (offline-first)

Do not over-implement. Story 1.2 ends with a **themed empty shell** that follows OS appearance — not navigation, onboarding, or database.

### Mandatory dev workflow

Follow [`docs/project-context.md`](../../../docs/project-context.md):

- One commit per sub-task (A, B, C, D) after Baptiste review
- Review brief format required before each commit
- No push unless explicitly requested

### Current repo state (post Story 1.1)

| Item | State |
|------|-------|
| `lib/main.dart` | Minimal Hello World `MaterialApp` — **replace** |
| `lib/core/` | **Absent** — create constants layer |
| `assets/fonts/` | **Absent** — create and populate |
| `pubspec.yaml` | Locked deps declared; **no font assets yet** |
| `flutter_bloc` | Declared in pubspec, **not imported** yet — first use in this story |
| Flutter / Dart | **3.44.0 / 3.12.0** (verified in Story 1.1) |

### Color token reference (UX §1.2 — implement exactly)

#### Dark palette surfaces & text

| Token | Hex | Dart field (suggested) |
|-------|-----|------------------------|
| `color.bg.base` | `#0F1114` | `bgBase` |
| `color.bg.elevated` | `#1A1D23` | `bgElevated` |
| `color.bg.subtle` | `#252830` | `bgSubtle` |
| `color.border.default` | `#2E3340` | `borderDefault` |
| `color.border.focus` | `#4A5568` | `borderFocus` |
| `color.text.primary` | `#F4F5F7` | `textPrimary` |
| `color.text.secondary` | `#9CA3AF` | `textSecondary` |
| `color.text.muted` | `#6B7280` | `textMuted` |
| `color.text.inverse` | `#0F1114` | `textInverse` |

#### Light palette surfaces & text

| Token | Hex | Dart field |
|-------|-----|------------|
| `color.bg.base` | `#F8F9FB` | `bgBase` |
| `color.bg.elevated` | `#FFFFFF` | `bgElevated` |
| `color.bg.subtle` | `#EEF0F4` | `bgSubtle` |
| `color.border.default` | `#D1D5DB` | `borderDefault` |
| `color.border.focus` | `#9CA3AF` | `borderFocus` |
| `color.text.primary` | `#0F1114` | `textPrimary` |
| `color.text.secondary` | `#4B5563` | `textSecondary` |
| `color.text.muted` | `#6B7280` | `textMuted` |
| `color.text.inverse` | `#F4F5F7` | `textInverse` |

#### Shared across themes (same hex in both factories)

| Token | Hex / opacity | Dart field |
|-------|---------------|------------|
| `color.accent.primary` | `#EAD55E` | `accentPrimary` |
| `color.accent.primary-muted` | `#EAD55E` @ 28% | `accentPrimaryMuted` |
| `color.accent.secondary` | `#94A3B8` | `accentSecondary` |
| `color.data.positive` | `#A3E635` @ 80% | `dataPositive` |
| `color.data.negative` | `#FCA5A5` | `dataNegative` |
| `color.data.goal-line` | `#EAD55E` @ 35% | `dataGoalLine` |
| `color.status.ok` | `#86EFAC` | `statusOk` |
| `color.status.stale` | `#FBBF24` | `statusStale` |
| `color.status.danger` | `#F87171` | `statusDanger` |
| `color.status.info` | `#93C5FD` | `statusInfo` |

**Opacity implementation:** Use `Color(0xFFEAD55E).withValues(alpha: 0.28)` (Dart 3.12 / Flutter 3.44). Do not hardcode pre-multiplied ARGB unless documented.

**Widget rule:** Components read colors via `context.astraColors.*` or `Theme.of(context).colorScheme.*` — **never** inline `Color(0xFF...)` in presentation widgets.

### Typography token reference (UX §1.3)

| Token | Family | Size | Weight | Usage |
|-------|--------|------|--------|-------|
| `type.display` | Darker Grotesque | 52 | 600 | Hero step count |
| `type.title` | Darker Grotesque | 24 | 600 | Screen titles |
| `type.headline` | Figtree | 18 | 600 | Section headers |
| `type.body` | Figtree | 16 | 400 | Body copy |
| `type.label` | Figtree | 14 | 500 | Tab labels, buttons |
| `type.caption` | Figtree | 12 | 400 | Sublabels, timestamps |
| `type.data` | Darker Grotesque | 20 | 500 | KPI numbers |

Expose as `TextStyle` getters on a class (e.g. `AstraTypography.display(BuildContext context)`) so font family + color pull from active theme.

### Spacing & radius reference (UX §1.4)

| Token | Value (dp) | Constant |
|-------|------------|----------|
| `space.xs` | 4 | `AstraSpacing.kSpaceXs` |
| `space.sm` | 8 | `AstraSpacing.kSpaceSm` |
| `space.md` | 16 | `AstraSpacing.kSpaceMd` / `AstraSpacing.kScreenHorizontalPadding` |
| `space.lg` | 24 | `AstraSpacing.kSpaceLg` |
| `space.xl` | 32 | `AstraSpacing.kSpaceXl` |
| `space.2xl` | 48 | `AstraSpacing.kSpace2xl` |
| `radius.sm` | 8 | `AstraSpacing.kRadiusSm` |
| `radius.md` | 12 | `AstraSpacing.kRadiusMd` |
| `radius.lg` | 16 | `AstraSpacing.kRadiusLg` |
| `radius.full` | 999 | `AstraSpacing.kRadiusFull` |

### ThemeCubit architecture (Story 1.2 minimal → future wiring)

```
Story 1.2 (this):  ThemeCubit() → default system → MaterialApp.themeMode
Story 1.4:         ThemeCubit loads theme_mode from UserPreferencesRepository at startup
Story 4.7:         ThemeSelector calls cubit.setThemeMode() + repository save
```

**Pattern for 1.2:**

```dart
// theme_state.dart
enum AstraThemePreference { system, light, dark }

class ThemeState {
  const ThemeState({this.preference = AstraThemePreference.system});
  final AstraThemePreference preference;

  ThemeMode get materialThemeMode => switch (preference) {
        AstraThemePreference.system => ThemeMode.system,
        AstraThemePreference.light => ThemeMode.light,
        AstraThemePreference.dark => ThemeMode.dark,
      };
}

// theme_cubit.dart
class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit() : super(const ThemeState());
}
```

When `ThemeMode.system` is set, Flutter automatically resolves light/dark from OS `MediaQuery.platformBrightness` — **no manual listener needed** for AC #2. Verify with manual OS toggle test.

### Suggested file tree after 1.2

```
lib/
├── main.dart                          # runApp(AstraApp())
├── app.dart                           # MaterialApp + BlocProvider
├── core/
│   └── constants/
│       ├── astra_colors.dart
│       ├── astra_spacing.dart
│       ├── astra_typography.dart
│       └── astra_theme.dart
└── presentation/
    ├── cubits/
    │   ├── theme_cubit.dart
    │   └── theme_state.dart
    └── screens/
        └── theme_preview_screen.dart  # temporary — removed/replaced in 1.3

assets/
└── fonts/
    ├── Figtree-VariableFont_wght.ttf       # variable; weights 400/500/600 via FontWeight
    └── DarkerGrotesque-VariableFont_wght.ttf  # variable; weights 500/600 via FontWeight

test/
├── core/constants/astra_colors_test.dart
├── presentation/cubits/theme_cubit_test.dart
└── widget_test.dart                   # updated
```

### Anti-patterns (do not do in 1.2)

- ❌ Add `google_fonts` package or fetch fonts at runtime
- ❌ Use `ColorScheme.fromSeed()` — ASTRA palette is **explicit hex**, not generated
- ❌ Hardcode hex colors in widgets instead of `AstraColors` tokens
- ❌ Build `AppScaffold`, bottom nav, or onboarding — Story 1.3 / 1.5
- ❌ Create SQLite schema or `UserPreferencesRepository` — Story 1.4
- ❌ Add `ThemeSelector` or manual light/dark toggle UI — Story 4.7
- ❌ Create full `AppDependencies` DI graph prematurely
- ❌ Batch sub-tasks A+B+C+D into one commit
- ❌ Commit without Baptiste review approval

### Epic 1 cross-story context

| Story | Focus | Depends on 1.2 |
|-------|-------|----------------|
| **1.2** (this) | Tokens, fonts, theme system | — |
| 1.3 | App scaffold + 3-tab nav | Uses `AstraColors`, spacing, `ThemeCubit` |
| 1.4 | user_preferences persistence | Extends `ThemeCubit` with repository load |
| 1.5 | Trust-first onboarding | Uses tokens + `AstraButton` variants |

FR-31 user-facing theme selection is split: **infrastructure in 1.2**, **persistence in 1.4**, **UI in 4.7**.

### Project Structure Notes

- Aligns with Architecture target layout: tokens in `lib/core/constants/` per D-structure
- `app.dart` separation matches Architecture (`main.dart` entry + `app.dart` widget tree)
- Tests mirror `lib/` under `test/` per Architecture naming patterns
- Font files in `assets/fonts/` per Architecture complete directory structure

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Story 1.2, UX-DR1–3, FR9/FR31 infrastructure]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — §1.2 Color Tokens, §1.3 Typography, §1.4 Spacing, §4.1 Contrast]
- [Source: _bmad-output/planning-artifacts/architecture.md — Theming, lib/core/constants/, fonts bundled locally]
- [Source: _bmad-output/implementation-artifacts/stories/1-1-flutter-project-initialization.md — prior story learnings]
- [Source: docs/project-context.md — review-before-commit workflow]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

## Technical Requirements

1. **Fonts:** Figtree + Darker Grotesque variable fonts committed under `assets/fonts/` (weights 400/500/600 and 500/600 via `FontWeight`); registered in `pubspec.yaml`; zero runtime network font fetch
2. **AstraColors:** `ThemeExtension<AstraColors>` with `light()` / `dark()` factories; full semantic token set per UX §1.2; `copyWith` + `lerp` implemented
3. **ThemeData:** Explicit `ColorScheme` mapping (not seed-generated); `useMaterial3: true`; both themes registered on `MaterialApp`
4. **Default theme:** `ThemeMode.system` via `ThemeCubit` in-memory default `AstraThemePreference.system`
5. **OS reactivity:** UI updates when OS toggles light/dark while app is foregrounded and preference is `system`
6. **Spacing:** 4px grid constants; screen horizontal padding ≥ 16dp; interactive targets ≥ 48dp
7. **Typography:** All seven type tokens wired to correct font family, size, weight per UX §1.3
8. **Analyzer:** `flutter analyze` zero issues; `flutter test` all pass

## Architecture Compliance

| Decision | Requirement for 1.2 |
|----------|----------------------|
| Design tokens location | `lib/core/constants/` — `astra_colors.dart`, `astra_typography.dart`, spacing in dedicated file |
| Theming pattern | `ThemeData.light()` + `ThemeData.dark()` + `AstraColors` extension |
| ThemeCubit | Minimal cubit in `lib/presentation/cubits/`; drives `MaterialApp.themeMode` |
| State management | `flutter_bloc` Cubit — first real usage in project |
| Fonts | Bundled in `assets/fonts/` — strict offline-first (Architecture line 365, 681) |
| No google_fonts | Forbidden — matches FR-18 offline pipeline |
| Naming | Files `snake_case.dart`; classes `PascalCase`; spacing constants `AstraSpacing.k*` prefix pattern |
| FR-9 / FR-31 infra | In-memory `theme_mode=system` default before DB exists |

## Library & Framework Requirements

| Package | Version | 1.2 action |
|---------|---------|------------|
| flutter_bloc | ^9.1.1 | **First use** — `ThemeCubit` + `BlocProvider` in `app.dart` |
| flutter (Material 3) | SDK | `useMaterial3: true`; `ThemeExtension` API |
| All other locked deps | unchanged | **Do not import** sqflite, workmanager, etc. yet |

**Do NOT add:** `google_fonts`, `flex_color_scheme`, `adaptive_theme`, or any theming package — custom tokens only.

## File Structure Requirements

| Path | Action |
|------|--------|
| `assets/fonts/*.ttf` | NEW — 2 variable-font files (Figtree + Darker Grotesque) |
| `lib/core/constants/astra_colors.dart` | NEW |
| `lib/core/constants/astra_spacing.dart` | NEW |
| `lib/core/constants/astra_typography.dart` | NEW |
| `lib/core/constants/astra_theme.dart` | NEW |
| `lib/presentation/cubits/theme_cubit.dart` | NEW |
| `lib/presentation/cubits/theme_state.dart` | NEW |
| `lib/app.dart` | NEW |
| `lib/presentation/screens/theme_preview_screen.dart` | NEW (temporary) |
| `lib/main.dart` | UPDATE — wire `AstraApp` |
| `pubspec.yaml` | UPDATE — fonts assets |
| `docs/DEPENDENCIES.md` | NEW or UPDATE — font licensing entry |
| `test/core/constants/astra_colors_test.dart` | NEW |
| `test/presentation/cubits/theme_cubit_test.dart` | NEW |
| `test/widget_test.dart` | UPDATE |

## Testing Requirements

- **Unit:** `astra_colors_test.dart` — verify hex values for representative light/dark/shared tokens
- **Unit:** `theme_cubit_test.dart` — default `system` preference and `ThemeMode.system` mapping
- **Widget:** `widget_test.dart` — app pumps, preview screen visible, button min height 48dp
- **Manual:** OS light/dark toggle while app foregrounded (AC #2)
- **Commands:** `flutter analyze` (0 issues), `flutter test` (all pass)
- **Not required:** Golden tests, contrast automation (manual beta check in UX V-1/V-2 for Story 4.7)

## Previous Story Intelligence

From **Story 1.1** (done):

- Flutter **3.44.0** / Dart **3.12.0** verified on Windows dev workstation
- `pubspec.lock` is tracked (`.gitignore` exception) — commit lock file if pub get changes it
- Review-before-commit gate: **4 sub-tasks** for 1.2 (A–D), each needs Baptiste OK before commit
- Story 1.1 explicitly deferred design tokens → this story; do not recreate scaffold
- `flutter_lints ^6.0.0` — keep analyzer clean
- Android KGP warnings deferred to Epic 5 Story 5.2 — ignore for 1.2
- Plugin manifest permissions deferred to Epic 2 — no AndroidManifest changes in 1.2
- Default widget test exists for Hello World — **must update** for new app structure

## Git Intelligence Summary

Recent commits (post-1.1):

| Commit | Relevance |
|--------|-----------|
| `027a8af` fix(test): track pubspec.lock and add empty app widget test | Widget test pattern to follow; update assertions |
| `ea824a8` docs(story): complete 1-1 code review | Story file lives in `implementation-artifacts/stories/` |
| `bbcea2f` fix(android): desugaring + kotlin incremental | Android build works; no theme impact |

**Convention:** `feat(theme): ...`, `feat(tokens): ...`, `test(theme): ...` scoped commit messages.

## Latest Tech Information

- **Flutter 3.44 / Dart 3.12:** `Color.withValues(alpha: ...)` preferred over deprecated `withOpacity`
- **ThemeExtension:** Standard Flutter API for custom semantic colors beyond `ColorScheme`; requires `copyWith` + `lerp` for theme interpolation [Flutter API ThemeExtension](https://api.flutter.dev/flutter/material/ThemeExtension-class.html)
- **Material 3:** Set `useMaterial3: true`; map ASTRA tokens to `ColorScheme` roles explicitly — **do not** rely on `ColorScheme.fromSeed` (would diverge from locked UX hex palette)
- **ThemeMode.system:** Built-in OS reactivity — when `MaterialApp.themeMode == ThemeMode.system`, Flutter listens to platform brightness changes automatically; no `WidgetsBindingObserver` needed for AC #2
- **BlocProvider scope:** Provide `ThemeCubit` above `MaterialApp` in `app.dart` so `themeMode` can be read from cubit state
- **Font bundling:** Download `.ttf` from Google Fonts website; filenames may vary — register exact committed filenames in pubspec

## Project Context Reference

Mandatory for all stories — [`docs/project-context.md`](../../../docs/project-context.md):

- Review-before-commit gate (4 sub-task commits for this story)
- Commit message convention: `type(scope): imperative summary`
- Update `docs/DEPENDENCIES.md` when adding font assets (licensing + offline confirmation)
- Story file path: `_bmad-output/implementation-artifacts/stories/1-2-design-tokens-and-theme-system.md`

## Story Completion Status

- Status: **done**
- Code review completed 2026-05-28; all patch findings resolved
- Epic 1 status: **in-progress** (story 1.1 done; 1.2 done)
- Next story after completion: **1-3-app-scaffold-and-bottom-navigation**
