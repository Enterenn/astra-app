# Story 10.4: Profile Slim Informations

Status: review

<!-- Mockup ref: Profil-light (2026-06-15) — body shows **Informations** card only. Notifications, Appearance, and version footer move to Settings (10.5) and About (10.8). Dark theme: no mockup-specific behavior — reuse existing `context.astraColors` / theme tokens. -->

## Story

As a **user**,
I want Profile to show only my personal info,
So that settings and appearance live in one dedicated place.

## Acceptance Criteria

1. **Given** Menu → Profile (nested navigator push from Story 10.3)  
   **When** the screen renders (light or dark theme, any accent preset)  
   **Then** the secondary header title reads **Profile** (via `SecondaryScreenShell` — unchanged from 10.3)  
   **And** the scroll body contains **one** `SectionCard` with headline **Informations**  
   **And** three tappable rows appear in order: **Display name**, **Height**, **Weight** — each with label, value, chevron (`caretRight`)  
   **And** empty values show **Not set**; set values format as `{name}`, `{n} cm`, `{n} kg` (metric display — unit prefs deferred to Stories 10.6–10.7)

2. **Given** the slim Profile body  
   **When** inspected  
   **Then** the **Notifications** `SectionCard` is **absent**  
   **And** the **Appearance** `SectionCard` (`ThemeSelector`, `AccentPresetSelector`) is **absent**  
   **And** the `_ProfileVersionFooter` (`ASTRA v…`) is **absent**  
   **And** no `Switch`, `ThemeSelector`, or `AccentPresetSelector` widgets render on Profile

3. **Given** existing Profile cubit editors  
   **When** user taps Display name, Height, or Weight and saves via the existing bottom sheets  
   **Then** persistence is unchanged — canonical `display_name`, `height_cm`, `weight_kg` in `user_preferences`  
   **And** `ProfileCubit.updateDisplayName`, `updateHeightCm`, `updateWeightKg` wiring is unchanged  
   **And** validation rules unchanged: name max 32 trim; height 100–250 cm nullable; weight 30–300 kg one decimal nullable

4. **Given** `ProfileScreen(showInlineTitle: false)` embedded under `SecondaryScreenShell`  
   **When** the route builds  
   **Then** no duplicate inline title renders (header owns title — same as 10.3)  
   **And** bottom scroll padding formula preserved (`kBottomNavBottomOffset + kBottomNavBarHeight + kSpaceMd`)  
   **And** loading/error states unchanged (`CircularProgressIndicator`, error message center)

5. **Given** implementation complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no new analyzer issues  
   **And** `profile_screen_test.dart` asserts slim layout (Informations only; no Notifications/Appearance/version footer)  
   **And** `app_scaffold_test.dart` Menu → Profile smoke still passes (header "Profile", "Informations" visible; no "Receive Goal notifications")

**Mockup ref:** `Profil-light` — Informations card only below back-arrow header.

**Depends on:** Story 10.3 (done). **Enables:** Story 10.5 (Settings receives migrated controls).

## Tasks / Subtasks

- [x] **Sub-task A — Slim `ProfileScreen` body** (AC: #1, #2, #4)
  - [x] In `profile_screen.dart`: remove Notifications `SectionCard`, Appearance `SectionCard`, and `_ProfileVersionFooter` widget class
  - [x] Remove unused imports: `ThemeCubit`, `ThemeState`, `accent_preset_selector`, `theme_selector`, `package_info_plus`
  - [x] Keep single Informations `SectionCard` with `DisplayNameEditorRow` + two `ProfileInfoRow`s — no layout refactor beyond removal
  - [x] Update `_kScreenTitle` constant from `'My Profile'` → `'Profile'` (semantics consistency when `showInlineTitle: true` in isolated tests)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Profile screen tests** (AC: #5)
  - [x] Update `profile_screen_test.dart`: pump with `ProfileScreen(showInlineTitle: false)` to match production embedded mode
  - [x] Replace "three section cards" test → assert **one** `SectionCard` / headline Informations only
  - [x] Remove notification switch test and version footer test (behaviors move to 10.5 / 10.8)
  - [x] Add negative assertions: `find.text('Notifications')`, `find.text('Appearance')`, `find.text('Receive Goal notifications')`, `find.byType(Switch)`, `find.byType(ThemeSelector)`, `find.byType(AccentPresetSelector)` → `findsNothing`
  - [x] Keep: ColoredBox shell test, Not set formatting, height/weight format tests, editor row presence
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — App scaffold nav smoke assertions** (AC: #5)
  - [x] Update `app_scaffold_test.dart` Menu → Profile test: assert Notifications/Appearance absent on pushed Profile route
  - [x] Confirm existing assertions still pass: header "Profile", "Informations", back pop → Menu hub
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Verify** (AC: #5)
  - [x] Run `flutter analyze` + `flutter test`
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (if any fixups)

## Dev Notes

### Story scope boundary

**In scope (10.4):**
- Remove Notifications, Appearance, and version footer from `ProfileScreen` body
- Clean dead imports and `_ProfileVersionFooter` class
- Update `_kScreenTitle` to `'Profile'`
- Update widget tests for slim layout

**Out of scope — do not touch:**
- `ProfileCubit` / `ProfileState` — keep `setGoalNotificationsEnabled` and `goalNotificationsEnabled` field (Settings 10.5 reuses cubit method)
- `ThemeCubit`, `ThemeSelector`, `AccentPresetSelector` widgets themselves — only remove Profile usage
- `settings_screen.dart` content → **Story 10.5**
- Display unit prefs / formatters → **Stories 10.6–10.7** (keep `{n} cm` / `{n} kg` hardcoded metric labels)
- `height_editor_sheet.dart`, `weight_editor_sheet.dart`, `display_name_editor_sheet.dart` — unchanged
- Navigation shell (`app_scaffold.dart` push route) — unchanged unless test-only import cleanup
- About version layout → **Story 10.8**
- Version bump (`0.3.0+5` at **Epic 10 close**, not per sub-story)
- GoRouter

This is a **presentation-layer layout trim** only — no repository, schema, or cubit API changes.

### Mockup alignment (Profil-light, 2026-06-15)

| Element | Profil-light mockup | Target (10.4) |
|---------|---------------------|---------------|
| Header | Back arrow + **Profile** | Unchanged — `SecondaryScreenShell` (10.3) |
| Body sections | **Informations** card only | Single `SectionCard` |
| Rows | Display name, Height, Weight + chevrons | Reuse existing row widgets |
| Notifications toggle | **Absent** on mockup | Remove from Profile |
| Theme / accent | **Absent** on mockup | Remove from Profile |
| Version footer | **Absent** on mockup | Remove — About gets it in 10.8 |
| Dark theme | *(no mockup)* | Existing `AstraColors` tokens |

### Business context

Post-beta UX tranche (sprint-change-proposal 2026-06-15 §1 item 5): Profile/Settings split. Story 10.3 wired Menu → Profile push with full legacy body. Story 10.4 trims Profile to personal info only; Story 10.5 migrates Notifications + Appearance to Settings.

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 10.4 changes | Must preserve |
|------|---------------|-------------------|---------------|
| `profile_screen.dart` | Informations + Notifications + Appearance + version footer | Remove 3 trailing sections + `_ProfileVersionFooter` class; clean imports; rename `_kScreenTitle` | Editor callbacks, cubit reads, loading/error, scroll padding, `showInlineTitle` param |
| `profile_cubit.dart` | Full CRUD incl. `setGoalNotificationsEnabled` | **No changes** | All methods — Settings 10.5 needs notification toggle |
| `profile_state.dart` | Includes `goalNotificationsEnabled` | **No changes** | Field stays for cubit + future Settings |
| `display_name_editor_row.dart` | Display name row | **No changes** | Reuse as-is |
| `profile_info_row.dart` | Height/Weight rows + `formatHeightCm`/`formatWeightKg` | **No changes** | Metric formatters until 10.7 |
| `height_editor_sheet.dart` | cm editor | **No changes** | Canonical cm save |
| `weight_editor_sheet.dart` | kg editor | **No changes** | Canonical kg save |
| `app_scaffold.dart` | Pushes `ProfileScreen(showInlineTitle: false)` | **No changes** unless dead import | Route wiring, cubit refresh |
| `settings_screen.dart` | Stub placeholder | **No changes** | 10.5 adds content |
| `profile_screen_test.dart` | Asserts 3 sections + switch + footer | Rewrite for slim layout | Shell, formatting tests |
| `app_scaffold_test.dart` | Menu → Profile smoke | Add negative assertions | Existing push/pop flow |

### Target layout after 10.4

```
┌─────────────────────────────────────┐
│  ←  Profile                         │  ← SecondaryScreenHeader (10.3)
├─────────────────────────────────────┤
│  ┌─ Informations ────────────────┐  │
│  │  Display name          >      │  │
│  │  Height                >      │  │
│  │  Weight                >      │  │
│  └───────────────────────────────┘  │
│                                     │
└─────────────────────────────────────┘
        [ floating bottom nav pill ]
```

### Architecture compliance

- **D-10 / Phase 0 nav:** Profile reached via Menu nested `Navigator` — **no GoRouter** [Source: `architecture.md`]
- **Presentation-only:** No repository, collector, or schema changes
- **ProfileCubit ownership:** Informations writes stay on `ProfileCubit`; notification/theme writes stay on same cubit API but UI moves to Settings in 10.5 [Source: `architecture.md` — Cubit table]
- **Review-before-commit:** One commit per sub-task; stop for Baptiste approval [Source: `docs/project-context.md`]

### Library / framework requirements

| Package | Version | Usage |
|---------|---------|-------|
| `flutter_bloc` | existing | `ProfileCubit` reads in `ProfileScreen` — unchanged |
| `phosphoricons_flutter` | ^1.0.0 | Chevrons on row widgets — unchanged |
| Flutter SDK | ^3.12.0 | Stateless layout trim |

No new dependencies. Removing `ThemeCubit`/`package_info_plus` imports from `profile_screen.dart` only.

### File structure requirements

```
lib/presentation/screens/profile_screen.dart            # UPDATE — slim body
test/presentation/screens/profile_screen_test.dart      # UPDATE — slim assertions
test/presentation/screens/app_scaffold_test.dart        # UPDATE — negative assertions
```

**Do not create or modify:**
- `settings_screen.dart` (10.5)
- `profile_cubit.dart` / `profile_state.dart`
- Editor sheets / row widgets

### Testing requirements

- **Slim layout:** pump `ProfileScreen(showInlineTitle: false)` + seeded `ProfileCubit` → find "Informations", Display name/Height/Weight rows; **not** Notifications, Appearance, Switch, ThemeSelector, AccentPresetSelector, version string
- **Formatting:** `180 cm`, `72.5 kg`, `Not set` ×3 for empty profile — unchanged
- **Menu → Profile integration:** tap Profile row → header + Informations; no notification toggle visible
- **Editors:** optional smoke — tap row opens sheet (existing `profile_editor_sheets_test.dart` covers sheets; no new sheet tests required unless regression found)
- Run full `flutter test` before story close

### Previous story intelligence (Story 10.3)

Story 10.3 established:
- Menu tab nested `Navigator`; Profile pushes with `SecondaryScreenShell(title: 'Profile')` + `ProfileScreen(showInlineTitle: false)`
- `ProfileCubit.refresh()` on push; cubit hoisted in `AppScaffold`
- Full legacy Profile body intentionally left intact — **10.4 trims it**
- Code review fixes: double SafeArea skip when embedded, duplicate-push guard, header overflow — preserve embedded scroll behavior
- Sub-task commit + review gate pattern — follow same rhythm

### Previous story intelligence (Story 5.11)

Story 5.11 originally built the full Profile (Informations + Notifications + Appearance) for the four-tab shell. Epic 10 supersedes:
- Profile no longer a bottom tab — Menu push only
- Notifications + Appearance migrate to Settings (10.5)
- Informations row widgets and editor sheets from 5.11 are **reuse targets** — do not rebuild

### Git intelligence

Recent commits (Epic 10 nav):
- `3f062c8` — 10.3 review fixes + story done
- `1843f30` — nested Menu Navigator + Profile/Data pushes
- `0b868e4` — Menu hub list (10.2)

Follow patterns: minimal diff (delete sections, don't refactor cubit), sub-task commits with review gates, extend existing tests rather than new test files.

### Latest tech information

- No new APIs — pure widget tree deletion
- `ProfileCubit.setGoalNotificationsEnabled` remains tested in `profile_cubit_test.dart` — do not remove cubit tests
- `formatHeightCm` / `formatWeightKg` in `profile_info_row.dart` stay metric until Story 10.7 wires unit prefs

### Project context reference

- Version bump at Epic 10 close only: `0.3.0+5` [Source: `.cursor/rules/app-versioning.mdc`]
- Mockup asset (light): `assets/c__Users_Baptiste_..._Profil-light-*.png` (referenced in sprint-change-proposal 2026-06-15)
- Purge survival: `display_name`, `height_cm`, `weight_kg` prefs unchanged — FR-20 [Source: Story 5.11 AC #7]

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Epic 10, Story 10.4]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` §1 item 5, §4.2]
- [Source: `_bmad-output/implementation-artifacts/stories/10-3-secondary-screen-navigator-stack.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/5-11-profil-informations-and-appearance.md`]
- [Source: `lib/presentation/screens/profile_screen.dart`]
- [Source: `lib/presentation/widgets/profile_info_row.dart`]
- [Source: `lib/presentation/widgets/display_name_editor_row.dart`]
- [Source: Mockup: Profil-light (2026-06-15)]

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- Tests initially failed without `buildAstraLightTheme` in pump helper — `context.astraColors` requires Astra theme extension.

### Completion Notes List

- Slimmed `ProfileScreen` to single Informations `SectionCard` (Display name, Height, Weight).
- Removed Notifications, Appearance sections and `_ProfileVersionFooter` class + dead imports.
- Renamed `_kScreenTitle` to `'Profile'`.
- Updated widget tests for embedded mode (`showInlineTitle: false`) with negative assertions for removed UI.
- Extended `app_scaffold_test.dart` Menu → Profile smoke with Notifications/Appearance absence checks.
- `flutter analyze`: no new issues. Full `flutter test`: all pass.

### File List

- `lib/presentation/screens/profile_screen.dart` — slim body, removed footer/sections
- `test/presentation/screens/profile_screen_test.dart` — slim layout assertions
- `test/presentation/screens/app_scaffold_test.dart` — negative nav smoke assertions

## Change Log

- 2026-06-15: Story 10.4 created — Profile slim Informations only; remove Notifications/Appearance/version footer; tests updated for embedded Menu push layout.
- 2026-06-15: Story 10.4 implemented — Profile slim layout + test updates; ready for review.
