# Story 10.5: Settings Appearance and Notifications

Status: review

<!-- Mockup ref: Settings-light (2026-06-15) — Notifications + Theme cards only. Units card deferred to 10.6; version footer deferred to About (10.8). Dark theme: no mockup-specific behavior — reuse existing `context.astraColors` / theme tokens. -->

## Story

As a **user**,
I want theme and notification controls in Settings,
So that appearance is grouped with other app preferences.

## Acceptance Criteria

1. **Given** Menu → Settings (nested navigator push from Story 10.3)  
   **When** the screen renders (light or dark theme, any accent preset)  
   **Then** the secondary header title reads **Settings** (via `SecondaryScreenShell` — unchanged from 10.3)  
   **And** the scroll body contains **two** `SectionCard`s in order: **Notifications**, then **Theme**  
   **And** the Notifications card shows label **Receive Goal notifications** with a `Switch` bound to `ProfileState.goalNotificationsEnabled`  
   **And** the Theme card shows `ThemeSelector` (System / Light / Dark) followed by `AccentPresetSelector` (six bi-tone preset circles)

2. **Given** the Settings body  
   **When** inspected  
   **Then** no **Units** section, no **Informations** rows, and no version footer (`ASTRA v…`) are present  
   **And** Profile route (Menu → Profile) still shows **Informations** only — no notification toggle or theme controls (regression guard from 10.4)

3. **Given** user toggles **Receive Goal notifications**  
   **When** save succeeds  
   **Then** `ProfileCubit.setGoalNotificationsEnabled` persists to `user_preferences.goal_notifications_enabled` (key `kGoalNotificationsEnabledKey`)  
   **And** permission flow is unchanged: enabling requests OS notification permission when not granted; denied permission leaves toggle off and returns `false`  
   **And** failed persistence shows snackbar **Could not update notification setting**

4. **Given** user changes theme mode or accent preset  
   **When** selection changes  
   **Then** `ThemeCubit.setThemePreference` / `ThemeCubit.setAccentPreset` persist to `theme_mode` and `accent_preset` respectively  
   **And** app chrome updates immediately (same `ThemeCubit` wiring as pre-split Profile)  
   **And** no repository or schema changes

5. **Given** Menu → Settings navigation  
   **When** route builds  
   **Then** `AppScaffold` calls `_profileCubit.refresh()` before push (same as Profile)  
   **And** route provides `BlocProvider.value(value: _profileCubit)` so Settings can read notification state  
   **And** `ThemeCubit` remains available from app root (`app.dart`) — no duplicate provider  
   **And** bottom scroll padding matches Profile embedded mode (`kBottomNavBottomOffset + kBottomNavBarHeight + kSpaceMd`)

6. **Given** `ProfileCubit` is loading or errored  
   **When** Settings renders  
   **Then** loading shows centered `CircularProgressIndicator`; error shows centered message (mirror Profile loading/error UX)

7. **Given** implementation complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no new analyzer issues  
   **And** new `settings_screen_test.dart` asserts Notifications + Theme cards, toggle, selectors  
   **And** `app_scaffold_test.dart` Menu → Settings smoke asserts cards visible (replaces stub-only header check)  
   **And** `profile_screen_test.dart` negative assertions still pass (no notification/theme on Profile)

**Mockup ref:** `Settings-light` — Notifications card + Theme card (no Units).

**Depends on:** Story 10.4 (done). **Enables:** Story 10.6 (Units section appended below Theme).

## Tasks / Subtasks

- [x] **Sub-task A — Settings screen body** (AC: #1, #2, #3, #4, #5, #6)
  - [x] Replace `SizedBox.shrink()` stub in `settings_screen.dart` with scroll body: Notifications `SectionCard` + Theme `SectionCard`
  - [x] Migrate notification toggle + theme widgets from pre-10.4 `profile_screen.dart` (git `729ebf0^`) — reuse exact Switch styling, snackbar copy, `BlocBuilder` patterns
  - [x] Wire `ProfileCubit` for notification toggle; wire `ThemeCubit` for `ThemeSelector` + `AccentPresetSelector`
  - [x] Add loading/error handling via `BlocBuilder<ProfileCubit, ProfileState>`
  - [x] Use `SectionCard` headline **Theme** (not "Appearance") per epic AC
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — App scaffold Settings push wiring** (AC: #5)
  - [x] In `app_scaffold.dart` `MenuHubDestination.settings` case: add `unawaited(_profileCubit.refresh())` before push
  - [x] Wrap `SettingsScreen` push with `BlocProvider.value(value: _profileCubit, child: const SettingsScreen())`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Settings screen widget tests** (AC: #7)
  - [x] Create `test/presentation/screens/settings_screen_test.dart`
  - [x] Pump helper: `MaterialApp` + `buildAstraLightTheme` + seeded `ProfileCubit` (ready) + `ThemeCubit`
  - [x] Assert: headlines "Notifications" and "Theme"; text "Receive Goal notifications"; `Switch`, `ThemeSelector`, `AccentPresetSelector` present
  - [x] Assert absent: "Informations", "Units", "ASTRA v", Display name rows
  - [x] Optional smoke: toggle switch calls cubit (mock `UserPreferencesRepository` if needed — prefer extending existing test patterns from `profile_cubit_test.dart`)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — App scaffold nav smoke update** (AC: #7)
  - [x] Update `app_scaffold_test.dart` "Menu pushes Settings and About stubs" test: for Settings, assert "Notifications", "Theme", "Receive Goal notifications" visible (About remains stub)
  - [x] Confirm Profile smoke still asserts notification/theme absent on Profile route
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Verify** (AC: #7)
  - [x] Run `flutter analyze` + `flutter test`
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (if any fixups)

## Dev Notes

### Story scope boundary

**In scope (10.5):**
- Full Settings scroll body: Notifications + Theme cards
- Migrate notification toggle and theme/accent selectors from legacy Profile layout
- `AppScaffold` ProfileCubit provider + refresh on Settings push
- Widget tests for Settings; update app scaffold smoke test

**Out of scope — do not touch:**
- **Units** card (Distance / Weight / Height) → **Story 10.6**
- Unit formatters / imperial display → **Stories 10.6–10.7**
- About version footer → **Story 10.8**
- `profile_screen.dart` body (slim Informations only — stay as 10.4 left it)
- `ProfileCubit` / `ThemeCubit` API changes — reuse existing methods only
- `ThemeSelector`, `AccentPresetSelector` widget implementations — reuse as-is
- `user_preferences` schema changes
- GoRouter
- Version bump (`0.3.0+5` at **Epic 10 close**, not per sub-story)

This is a **presentation-layer migration** — wire existing cubits/widgets into Settings; no new persistence keys.

### Mockup alignment (Settings-light, 2026-06-15)

| Element | Settings-light mockup | Target (10.5) |
|---------|----------------------|---------------|
| Header | Back arrow + **Settings** | Unchanged — `SecondaryScreenShell` in `settings_screen.dart` |
| Card 1 | **Notifications** + goal toggle | `SectionCard(headline: 'Notifications')` + Switch row |
| Card 2 | **Theme** + mode + accent circles | `SectionCard(headline: 'Theme')` + `ThemeSelector` + `AccentPresetSelector` |
| Units card | Present on mockup | **Deferred to 10.6** — do not add placeholder |
| Profile content | N/A | Stays on Profile route only |
| Dark theme | *(no mockup)* | Existing `AstraColors` tokens |

**Headline note:** Pre-split Profile used SectionCard headline **Appearance** for theme controls. Epic 10.5 AC specifies **Theme** card — use **Theme** as the `SectionCard` headline.

### Business context

Post-beta UX tranche (sprint-change-proposal 2026-06-15 §4.5): move goal notifications toggle, theme mode segmented control, and accent preset circles from Profile to Settings. Story 10.4 removed these from Profile intentionally; 10.5 is the **re-home**, not a rewrite.

### Migration source (copy, don't reinvent)

Pre-10.4 `profile_screen.dart` (commit parent of `729ebf0`) contains the exact UI to migrate:

```dart
// Notifications SectionCard — copy Switch row + onChanged handler
SectionCard(
  headline: 'Notifications',
  child: Row(
    children: [
      Expanded(child: Text('Receive Goal notifications', ...)),
      Switch(
        value: profileState.goalNotificationsEnabled,
        activeTrackColor: colors.accentPrimary.withValues(alpha: 0.5),
        activeThumbColor: colors.accentPrimary,
        onChanged: (enabled) async {
          final saved = await profileCubit.setGoalNotificationsEnabled(enabled);
          if (!saved && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not update notification setting')),
            );
          }
        },
      ),
    ],
  ),
),

// Theme SectionCard — copy BlocBuilder<ThemeCubit> blocks
SectionCard(
  headline: 'Theme',  // was 'Appearance' on Profile — use 'Theme' per epic
  child: Column(
    children: [
      BlocBuilder<ThemeCubit, ThemeState>(... ThemeSelector ...),
      SizedBox(height: AstraSpacing.kSpaceLg),
      BlocBuilder<ThemeCubit, ThemeState>(... AccentPresetSelector ...),
    ],
  ),
),
```

Do **not** copy `_ProfileVersionFooter` or Informations card.

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 10.5 changes | Must preserve |
|------|---------------|-------------------|---------------|
| `settings_screen.dart` | Stub: `SecondaryScreenShell` + `SizedBox.shrink()` | Add scroll body with 2 SectionCards | Self-contained shell pattern (shell stays in this file, unlike Profile) |
| `app_scaffold.dart` | Settings push: bare `SettingsScreen()` | Add `_profileCubit.refresh()` + `BlocProvider.value` | Profile/Data push patterns, duplicate-push guard, menu stack tracking |
| `profile_screen.dart` | Slim Informations only (10.4) | **No changes** | Negative test contract |
| `profile_cubit.dart` | `setGoalNotificationsEnabled` intact | **No changes** | Permission gating, persistence key |
| `theme_cubit.dart` | `setThemePreference`, `setAccentPreset` | **No changes** | In-flight serialization |
| `theme_selector.dart` | Segmented System/Light/Dark | **No changes** | Reuse widget |
| `accent_preset_selector.dart` | Six bi-tone circles | **No changes** | Reuse widget |
| `app.dart` | Root `BlocProvider<ThemeCubit>` | **No changes** | ThemeCubit scope covers Settings |
| `app_scaffold_test.dart` | Settings stub header-only smoke | Assert Notifications/Theme content | About stub test unchanged |
| `profile_screen_test.dart` | Negative: no notification/theme on Profile | **No changes** unless regression | Keep passing |

### Target layout after 10.5

```
┌─────────────────────────────────────┐
│  ←  Settings                        │  ← SecondaryScreenShell
├─────────────────────────────────────┤
│  ┌─ Notifications ───────────────┐  │
│  │  Receive Goal notifications ○ │  │
│  └───────────────────────────────┘  │
│  ┌─ Theme ───────────────────────┐  │
│  │  [ System | Light | Dark ]    │  │
│  │  ○ ○ ○ ○ ○ ○  (accent chips)  │  │
│  └───────────────────────────────┘  │
│                                     │
└─────────────────────────────────────┘
        [ floating bottom nav pill ]
```

### Architecture compliance

- **D-10 / Phase 0 nav:** Settings reached via Menu nested `Navigator` — **no GoRouter** [Source: `architecture.md`]
- **Presentation-only:** No repository, collector, or schema changes
- **Cubit ownership:** Notification writes stay on `ProfileCubit`; theme/accent writes stay on `ThemeCubit` [Source: `architecture.md` — Cubit table]
- **Persistence keys unchanged:** `theme_mode`, `accent_preset`, `goal_notifications_enabled` [Source: `preference_keys.dart`]
- **ThemeCubit at app root:** Settings reads via `context.read<ThemeCubit>()` — same as pre-split Profile when embedded under `MaterialApp`
- **ProfileCubit hoisted in AppScaffold:** Settings must receive cubit via `BlocProvider.value` on push — **critical**; bare push will throw `ProviderNotFoundException`
- **Review-before-commit:** One commit per sub-task; stop for Baptiste approval [Source: `docs/project-context.md`]

### Library / framework requirements

| Package | Version | Usage |
|---------|---------|-------|
| `flutter_bloc` | existing | `ProfileCubit` + `ThemeCubit` reads |
| `phosphoricons_flutter` | ^1.0.0 | Unchanged (Settings body has no new icons) |
| Flutter SDK | ^3.12.0 | Widget migration only |

No new dependencies.

### File structure requirements

```
lib/presentation/screens/settings_screen.dart     # UPDATE — full body
lib/presentation/screens/app_scaffold.dart        # UPDATE — ProfileCubit on Settings push
test/presentation/screens/settings_screen_test.dart  # NEW
test/presentation/screens/app_scaffold_test.dart  # UPDATE — Settings content smoke
```

**Do not create or modify:**
- `profile_screen.dart` (unless regression fix)
- `profile_cubit.dart` / `theme_cubit.dart` / selector widgets
- Unit prefs files (10.6)
- `about_screen.dart` (10.8)

### Testing requirements

- **Settings layout:** pump `SettingsScreen` with seeded `ProfileCubit(ready, goalNotificationsEnabled: true/false)` + `ThemeCubit` + Astra theme → find "Notifications", "Theme", "Receive Goal notifications", `Switch`, `ThemeSelector`, `AccentPresetSelector`
- **Negative:** no "Informations", "Units", "ASTRA v", `DisplayNameEditorRow`
- **Menu → Settings integration:** tap Settings row → header + both cards visible
- **Profile regression:** existing `profile_screen_test.dart` + Profile branch of `app_scaffold_test.dart` still assert notification/theme absent on Profile
- **Cubit tests:** existing `profile_cubit_test.dart` + `theme_cubit_test.dart` cover persistence — no duplicate cubit tests unless Settings-specific edge found
- Run full `flutter test` before story close

### Previous story intelligence (Story 10.4)

Story 10.4 explicitly:
- Removed Notifications, Appearance, version footer from Profile
- Left `ProfileCubit.setGoalNotificationsEnabled` and `goalNotificationsEnabled` field intact for 10.5
- Left `ThemeSelector` / `AccentPresetSelector` widgets untouched — only removed Profile usage
- Documented `settings_screen.dart` as stub for 10.5
- Tests assert Profile has **no** notification/theme UI — **must not regress**

### Previous story intelligence (Story 10.3)

Story 10.3 established:
- Menu tab nested `Navigator`; Settings pushes via `MenuHubDestination.settings`
- `SettingsScreen` is self-contained with internal `SecondaryScreenShell` (differs from Profile where shell is in `app_scaffold` push)
- Duplicate-push guard via `_menuStackTopDestination`
- Sub-task commit + review gate pattern — follow same rhythm

### Previous story intelligence (Story 5.11)

Story 5.11 originally built Notifications + Appearance on Profile for four-tab shell. Epic 10 supersedes:
- Controls migrate to Settings (10.5), not My Data (theme removed from My Data in 5.10)
- Widget implementations (`ThemeSelector`, `AccentPresetSelector`, Switch row) are **reuse targets** — do not rebuild

### Git intelligence

Recent commits (Epic 10):
- `6725518` — 10.4 test tightening + story done
- `729ebf0` — Profile slim (removed sections to migrate back in Settings)
- `3f062c8` — 10.3 review fixes + nested nav

Follow patterns: minimal diff (migrate UI blocks, don't refactor cubits), sub-task commits with review gates, extend existing tests.

**Migration reference command:** `git show 729ebf0^:lib/presentation/screens/profile_screen.dart`

### Latest tech information

- No new APIs — widget migration from git history
- `ThemeCubit` serializes concurrent `setThemePreference` / `setAccentPreset` via `_setInFlight` — do not bypass with direct repository calls from Settings
- `ProfileCubit.setGoalNotificationsEnabled` returns `false` when permission denied or persistence fails — Switch must reflect cubit state after failed enable (do not optimistically flip)
- Flutter 3.12+ `Switch` uses `activeTrackColor` / `activeThumbColor` (already used in legacy Profile)

### Project context reference

- Version bump at Epic 10 close only: `0.3.0+5` [Source: `.cursor/rules/app-versioning.mdc`]
- Mockup asset (light): `assets/c__Users_Baptiste_..._Settings-light-*.png` (referenced in sprint-change-proposal 2026-06-15)
- Purge survival: `theme_mode`, `accent_preset`, `goal_notifications_enabled` persist through data purge [Source: FR-20, Story 4.7 / 5.11]

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Epic 10, Story 10.5]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` §4.5]
- [Source: `_bmad-output/implementation-artifacts/stories/10-4-profile-slim-informations.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/10-3-secondary-screen-navigator-stack.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/5-11-profil-informations-and-appearance.md`]
- [Source: `lib/presentation/screens/settings_screen.dart`]
- [Source: `lib/presentation/screens/app_scaffold.dart` — Settings push case]
- [Source: `lib/presentation/cubits/profile_cubit.dart` — `setGoalNotificationsEnabled`]
- [Source: `lib/presentation/cubits/theme_cubit.dart`]
- [Source: `lib/presentation/widgets/theme_selector.dart`]
- [Source: `lib/presentation/widgets/accent_preset_selector.dart`]
- [Source: `lib/core/constants/preference_keys.dart`]
- [Source: Mockup: Settings-light (2026-06-15)]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Settings integration test required polling loop for `ProfileCubit.refresh()` async completion (fixed delay insufficient).
- `Switch` widget tests need `Scaffold` ancestor for Material — wrapped pump helper accordingly.

### Completion Notes List

- Migrated Notifications + Theme controls from legacy Profile (`729ebf0^`) into `settings_screen.dart` with loading/error UX mirroring Profile.
- `AppScaffold` Settings push now refreshes and provides hoisted `ProfileCubit` via `BlocProvider.value` (same pattern as Profile/Data).
- Added `settings_screen_test.dart` (layout, negative assertions, loading/error).
- Updated `app_scaffold_test.dart`: Settings smoke asserts full cards; About remains stub-only.
- `flutter test` full suite green; `flutter analyze` — no new issues (pre-existing infos only).

### File List

- `lib/presentation/screens/settings_screen.dart` — full scroll body (Notifications + Theme)
- `lib/presentation/screens/app_scaffold.dart` — ProfileCubit refresh + provider on Settings push
- `test/presentation/screens/settings_screen_test.dart` — new widget tests
- `test/presentation/screens/app_scaffold_test.dart` — Settings nav smoke update

## Change Log

- 2026-06-15: Story 10.5 created — migrate Notifications + Theme controls from legacy Profile to Settings; AppScaffold ProfileCubit wiring; widget + nav tests.
- 2026-06-15: Story 10.5 implemented — Settings body, scaffold wiring, widget + integration tests; status → review.
