# Story 5.11: Profile Screen — Informations & Appearance

Status: done

<!-- Sprint Change Proposal 2026-06-04 + Baptiste mockups 2026-06-05. Nav label corrected: PROFIL → PROFILE. -->

## Story

As a **user**,
I want profile and appearance settings on the Profile tab,
so that personal info and theming are separate from raw data controls.

## Acceptance Criteria

1. **Given** the **PROFILE** tab is selected  
   **When** the screen renders in light or dark theme with any accent preset (Story 5.8)  
   **Then** the screen **title** reads **My Profile** once at the top (same scroll shell as Today/Data: horizontal padding + bottom nav clearance)  
   **And** three `SectionCard` sections exist in order: **Informations** → **Notifications** → **Appearance**  
   **And** layout matches Baptiste mockups (light + dark references below)

2. **Given** the **Informations** card  
   **When** inspected  
   **Then** section headline is **Informations** (not "Profile" — locked 2026-06-04)  
   **And** three tappable rows exist: **Display name**, **Height**, **Weight** — each with label (body), value (headline), chevron right  
   **And** empty values show **Not set** (same pattern as `DisplayNameEditorRow`)  
   **And** set values format as: name plain text; height `{n} cm`; weight `{n} kg`  
   **And** **no** Age or sex/gender rows (mockups show Age — **ignore**; product decision 2026-06-04)

3. **Given** a row in Informations is tapped  
   **When** the edit sheet opens and user saves a valid value  
   **Then** the value persists locally via `UserPreferencesRepository` and the row updates immediately  
   **And** display name reuses `showDisplayNameEditorSheet` (max 32 chars, trim, empty clears)  
   **And** height accepts integer **100–250** cm (nullable — clear allowed)  
   **And** weight accepts number **30–300** kg, one decimal max (nullable — clear allowed)

4. **Given** the **Notifications** card  
   **When** the screen renders  
   **Then** a single row **Receive Goal notifications** appears with a `Switch` on the right (mockup: green when on)  
   **And** toggling persists `goal_notifications_enabled` in `user_preferences`  
   **And** enabling when OS notification permission is denied prompts permission request (reuse `NotificationService` / `permission_handler` pattern from onboarding)  
   **And** disabling only updates the preference — does not revoke OS permission

5. **Given** the **Appearance** card  
   **When** user interacts  
   **Then** (1) existing `ThemeSelector` renders System / Light / Dark, wired to `ThemeCubit.setThemePreference` (migrate from old My Data — Story 4.7)  
   **And** (2) new `AccentPresetSelector` renders **six bi-tone circles** below the theme control (FR-32)  
   **And** each chip: ~44–48dp touch target; diagonal split TL→BR — **bottom-left** = effective surface base for current brightness; **top-right** = preset `accentPaletteFor(preset).primary`  
   **And** chips re-render when theme mode or OS theme changes under System  
   **And** selected preset shows accent border/ring (per mockups)  
   **And** selection calls `ThemeCubit.setAccentPreset` — app chrome updates without restart

6. **Given** bottom navigation (Story 5.7)  
   **When** any tab renders  
   **Then** fourth tab label reads **PROFILE** (English — user correction 2026-06-05; replaces **PROFIL**)  
   **And** Phosphor `User` icon unchanged

7. **Given** purge all health data on Data tab  
   **When** completed  
   **Then** Informations + appearance + notification prefs survive per FR-20: `display_name`, `height_cm`, `weight_kg`, `goal_notifications_enabled`, `theme_mode`, `accent_preset`, `daily_step_goal`, onboarding flags

8. **Given** implementation complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no regressions; new widget/cubit tests cover layout, persistence, theme/accent wiring, nav label **PROFILE**

**Depends on:** Stories 5.8 (done), 5.7 (done), 5.10 (done — sovereignty-only Data screen).  
**Completes:** migration of 4.7 (theme), 4.8 (display name on Profile only), appearance affordances from Epic 4.  
**Prerequisite for:** Story 5.12 (cohesion audit).  
**Out of scope:** `ProfileInitialsBadge` / avatar header (mockups omit — do not add); Epic 6 derived metrics; cubit rename `MyDataCubit` → `DataCubit`.

---

## Visual reference (authoritative mockups — Baptiste 2026-06-05)

| Theme | Workspace asset |
|-------|-----------------|
| Light | `assets/c__Users_Baptiste_AppData_Roaming_Cursor_User_workspaceStorage_838eccf53fbdedd221dd14ed672601e5_images_Profil-light-f43f021c-dc2f-4b23-b613-90d24379dfce.png` |
| Dark | `assets/c__Users_Baptiste_AppData_Roaming_Cursor_User_workspaceStorage_838eccf53fbdedd221dd14ed672601e5_images_Profil-dark-508f0d6a-2f03-433d-b6c6-c17de6778b86.png` |

**Mockup vs locked spec (follow spec when they differ):**

| Mockup shows | Implement |
|--------------|-----------|
| Age row ("33 yrs") | **Omit** — not in FR-9 / Epic 6 scope |
| Dark card title "Profile" | **Informations** (light mockup is correct) |
| Nav label "PROFIL" | **PROFILE** (English correction) |
| Weight "90 Kg" | Prefer **`{n} kg`** lowercase unit |

**Target layout (top → bottom):**

1. Title **My Profile** (`AstraTypography.captionFor` — mirror Today/Data)
2. `SectionCard` **Informations** → 3 `ProfileInfoRow`s (or `DisplayNameEditorRow` + 2 new rows)
3. `SectionCard` **Notifications** → `SwitchListTile` **Receive Goal notifications**
4. `SectionCard` **Appearance** → `ThemeSelector` + spacing + `AccentPresetSelector`
5. Floating nav (PROFILE tab active = white squircle)

Also: [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` §2.6 Profil Surface, §2.2 `AccentPresetSelector`]

---

## Tasks / Subtasks

- [x] **A — Nav label: PROFILE** (AC: #6)
  - [x] Change `AppBottomNav` fourth tab label `PROFIL` → `PROFILE`
  - [x] Update tests: `app_bottom_nav_test.dart`, `app_scaffold_test.dart`, `widget_test.dart`
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **B — Preferences + ProfileCubit** (AC: #3, #4, #7)
  - [x] Add keys: `height_cm`, `weight_kg`, `goal_notifications_enabled` in `preference_keys.dart`
  - [x] Extend `UserPreferencesRepository`: get/set for all three (nullable height/weight; bool default `false` for notifications)
  - [x] Create `ProfileCubit` + `ProfileState` (load on tab select; methods: `updateDisplayName`, `updateHeightCm`, `updateWeightKg`, `setGoalNotificationsEnabled`)
  - [x] Move display-name persistence off `MyDataCubit` for Profile UI — ProfileCubit owns writes; keep `MyDataCubit.updateDisplayName` only if still needed elsewhere, or delegate to shared repo calls
  - [x] Wire `OnboardingCubit.completeOnboarding` to persist `goal_notifications_enabled` from `notificationOptIn` (currently ephemeral — fix gap)
  - [x] Extend purge survival test in `step_repository_purge_test.dart` for new keys
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **C — Profile screen shell + Informations** (AC: #1, #2, #3)
  - [x] Replace `ProfileScreen` placeholder with scroll layout (reuse Today/Data bottom padding formula)
  - [x] Informations card with display name + height + weight rows
  - [x] Create `ProfileInfoRow` widget (match `DisplayNameEditorRow` visual pattern: label, value, chevron)
  - [x] Create `showHeightEditorSheet` / `showWeightEditorSheet` (numeric validation, Save/Cancel — mirror `display_name_editor_sheet.dart`)
  - [x] Wire `AppScaffold` index 3: `BlocProvider.value` for `ProfileCubit`; register cubit in `app_dependencies.dart`
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **D — Notifications card** (AC: #4)
  - [x] `SectionCard` **Notifications** with `SwitchListTile` copy **Receive Goal notifications**
  - [x] On enable: persist + request notification permission if not granted
  - [x] On disable: persist only
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **E — Appearance card + AccentPresetSelector** (AC: #5)
  - [x] `SectionCard` **Appearance** hosting `ThemeSelector` bound to `ThemeCubit` via `BlocBuilder`
  - [x] New `AccentPresetSelector` widget — six presets in `AstraAccentPreset.values` order: orange, red, green, blue, magenta, pink
  - [x] Bi-tone chip: `CustomPainter` or `ClipPath` diagonal; base = `colors.bgElevated` (or mockup white/near-white light, dark charcoal dark)
  - [x] Selected ring: `colors.accentPrimary` border 2dp
  - [x] Widget test: chips reflect preset colors; selection callback fires
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **F — Tests & regression** (AC: #8)
  - [x] `test/presentation/screens/profile_screen_test.dart` — title, three sections, row labels, no Age row, Appearance widgets present
  - [x] `test/presentation/cubits/profile_cubit_test.dart` — persistence + validation boundaries
  - [x] `test/presentation/widgets/accent_preset_selector_test.dart`
  - [x] Smoke: Profile tab in `app_scaffold_test.dart` renders real screen (not placeholder)
  - [x] Full `flutter test` + `flutter analyze`
  - [x] **Stop → review brief → Baptiste OK → commit**

---

## Dev Notes

### Product intent (why this story)

Story 5.10 stripped goal, theme, and display name from the Data tab. This story completes the four-tab split by building the **Profile** tab as the home for personal info, notification preference, and appearance — matching Figma mockups Baptiste attached (2026-06-05).

### Architecture compliance

- **Presentation + preferences only** — no schema changes to `timeseries_samples`; new prefs are KV rows in existing `user_preferences` table (no `kDbVersion` bump required unless seeding defaults)
- **`ProfileCubit`** per [Source: `architecture.md` § Frontend Architecture] — Profil tab state owner; do not overload `MyDataCubit` with profile UI
- **`ThemeCubit`** remains global appearance owner — Profile screen **reads/writes** via existing `setThemePreference` / `setAccentPreset` (Story 5.8)
- **Tokens:** `context.astraColors.*` only; bi-tone chip accent half from `accentPaletteFor(preset).primary` (V-2)
- **Single writer:** `UserPreferencesRepository` for all preference keys
- **Review-before-commit:** one commit per sub-task A–F ([Source: `docs/project-context.md`])

### Current code state (READ before editing)

| File | Today | Change in 5.11 | Preserve |
|------|-------|----------------|----------|
| `lib/presentation/screens/profile_screen.dart` | Placeholder `TabPlaceholderBody` | Full scroll UI | — |
| `lib/presentation/widgets/app_bottom_nav.dart` | Label `PROFIL` | → `PROFILE` | Floating pill styling, Phosphor icons |
| `lib/presentation/widgets/theme_selector.dart` | Standalone widget | Reuse on Profile | Segment UX, accent underline |
| `lib/presentation/widgets/display_name_editor_row.dart` | Was on My Data | Reuse on Profile | Row layout, semantics |
| `lib/presentation/widgets/display_name_editor_sheet.dart` | Existing | Reuse for name edit | Validation |
| `lib/presentation/cubits/theme_cubit.dart` | theme + accent persist | No change | Mutex on concurrent writes |
| `lib/presentation/cubits/my_data_cubit.dart` | Has `updateDisplayName` | Profile UI uses `ProfileCubit` instead | Sovereignty methods untouched |
| `lib/presentation/screens/app_scaffold.dart` | Index 3 = bare `ProfileScreen` | Provide `ProfileCubit` | Tab indices 0–2 unchanged |
| `lib/core/di/app_dependencies.dart` | No ProfileCubit | Register + expose | Existing cubit wiring |
| `lib/data/repositories/user_preferences_repository.dart` | No height/weight/notifications | Add getters/setters | Existing methods |
| `lib/presentation/cubits/onboarding_cubit.dart` | `notificationOptIn` ephemeral | Persist on complete | Permission flow |

**Does not exist yet (create):**

- `lib/presentation/cubits/profile_cubit.dart` + `profile_state.dart`
- `lib/presentation/widgets/profile_info_row.dart`
- `lib/presentation/widgets/accent_preset_selector.dart`
- `lib/presentation/widgets/height_editor_sheet.dart` / `weight_editor_sheet.dart` (or single numeric sheet)

### Copy locks (exact strings)

| Element | Copy |
|---------|------|
| Tab label (nav) | **PROFILE** |
| Screen title | **My Profile** |
| Card 1 headline | **Informations** |
| Row labels | **Display name**, **Height**, **Weight** |
| Empty value | **Not set** |
| Card 2 headline | **Notifications** |
| Toggle label | **Receive Goal notifications** |
| Card 3 headline | **Appearance** |
| Theme segments | **System**, **Light**, **Dark** |

### AccentPresetSelector implementation guide

```dart
// Effective brightness for bi-tone base half:
final brightness = Theme.of(context).brightness; // respects ThemeCubit + system
final baseColor = brightness == Brightness.dark
    ? colors.bgElevated  // dark charcoal per mockup
    : colors.bgElevated; // white/near-white card surface in light mode

// Accent half:
final accent = accentPaletteFor(preset).primary;

// Diagonal split: clip bottom-left triangle = base, top-right = accent
// Selected: Container decoration BoxDecoration(shape: circle, border: Border.all(color: colors.accentPrimary, width: 2))
```

Preset order left→right: Orange, Red, Green, Blue, Magenta (display "Purple" in Figma copy maps to `magenta` enum), Pink.

Use `Semantics` labels: `"Accent color, Orange"` etc.

### ProfileCubit state shape (suggested)

```dart
class ProfileState {
  final ProfileStatus status; // loading | ready | error
  final String? displayName;
  final int? heightCm;
  final double? weightKg;
  final bool goalNotificationsEnabled;
}
```

Load all fields in `refresh()` on first tab visit (mirror `MyDataCubit.refresh()` pattern).

### What NOT to break

- **Data tab** — remains sovereignty-only (Story 5.10)
- **Today** — no greeting; Set goal unchanged
- **Theme/accent global apply** — `MaterialApp` in `app.dart` already rebuilds from `ThemeCubit`
- **Purge** — health data deleted; setup prefs preserved (extend test, do not delete new keys in `StepRepository.purge`)
- **Onboarding notification flow** — opt-in during onboarding must now survive app restart

### Testing requirements

| Area | Minimum tests |
|------|----------------|
| Nav | `PROFILE` label in bottom nav + scaffold smoke |
| Layout | Title **My Profile**; sections Informations / Notifications / Appearance; no Age row |
| Informations | Row tap opens sheet; valid save updates displayed value |
| Notifications | Toggle persists; enable triggers permission path (mock `NotificationService`) |
| Appearance | `ThemeSelector` + `AccentPresetSelector` present; accent change calls cubit |
| Purge | `height_cm`, `weight_kg`, `goal_notifications_enabled` survive purge |
| Regression | Full `flutter test` |

Widget test pattern: seeded `ProfileCubit` emitting fixed `ProfileState` — no async DB in widget tests (same as Today/My Data).

### Previous story intelligence (5.10)

- Data screen uses scroll + `bottomScrollPadding = kBottomNavBottomOffset + kBottomNavBarHeight + kSpaceMd` — **reuse on Profile**
- `MyDataCubit.updateDisplayName` still exists for cross-tab hooks — Profile should own UI; consider calling `_postDisplayNameUpdate` from ProfileCubit via `AppScaffold` callback if Today ever needs name again (currently unused on Today)
- Title typography on Data: `AstraTypography.captionFor(colors)` — **use same on Profile**

### Previous story intelligence (5.8)

- Six presets locked in `astra_accent_palette.dart` — selector UI was explicitly deferred to 5.11
- `ThemeCubit.setAccentPreset` already persists + emits — wire selector only
- Legacy DB aliases `cyan`→`blue`, `purple`→`magenta` handled in parse — no selector change needed

### Previous story intelligence (5.7)

- Profile tab = index **3**
- Active tab squircle: dark mode `bgBase`, light mode `bgElevated`

### Git intelligence

Recent commits (5.10): sovereignty-only Data layout, CSV hardening, cubit slim refresh. Pattern: focused commits per sub-task, colocated tests under `test/presentation/`, semantic colors only.

### Latest tech information

- **Flutter Bloc ^8.x** — `Cubit` + `BlocProvider.value` in scaffold (existing pattern)
- **phosphoricons_flutter** — already installed (Story 5.6); Profile uses Material chevron like `DisplayNameEditorRow` (mockup) — do not swap to Phosphor caret unless cohesion audit requests
- **sqflite** — KV prefs need no migration for new keys; insert on first write
- **permission_handler** — reuse for notification permission on toggle enable

### Project context reference

- [Source: `docs/project-context.md`] — review-before-commit per sub-task
- [Source: `_bmad-output/planning-artifacts/epics.md` § Story 5.11]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` §2.6, §2.2 AccentPresetSelector]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` §4.7b Profil Surface, FR-31, FR-32]
- [Source: `_bmad-output/planning-artifacts/architecture.md` § Frontend Architecture]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-04.md` §4.1, §4.2]
- [Source: `_bmad-output/implementation-artifacts/stories/5-10-data-screen-sovereignty-layout.md`] — removed widgets land here
- [Source: `_bmad-output/implementation-artifacts/stories/5-8-accent-preset-theme-tokens.md`] — locked preset hex table

---

## Dev Agent Record

### Agent Model Used

Composer (dev-story workflow)

### Debug Log References

### Completion Notes List

- Built full Profile tab: Informations (display name, height, weight), Notifications toggle, Appearance (ThemeSelector + AccentPresetSelector bi-tone chips).
- Added `ProfileCubit` with tab-select refresh; display-name writes moved to Profile UI (`MyDataCubit.updateDisplayName` retained for legacy callers).
- Persisted `height_cm`, `weight_kg`, `goal_notifications_enabled`; onboarding now saves notification opt-in.
- Nav label corrected to **PROFILE**; purge survival extended for new preference keys.
- `flutter analyze` clean (info-level lints only). `flutter test`: 562 pass, 1 pre-existing failure in `my_data_cubit_purge_test.dart` (file_picker binding in export-first path).

### File List

- lib/core/constants/preference_keys.dart
- lib/data/repositories/user_preferences_repository.dart
- lib/presentation/cubits/profile_cubit.dart
- lib/presentation/cubits/profile_state.dart
- lib/presentation/cubits/onboarding_cubit.dart
- lib/presentation/screens/profile_screen.dart
- lib/presentation/screens/app_scaffold.dart
- lib/presentation/widgets/app_bottom_nav.dart
- lib/presentation/widgets/profile_info_row.dart
- lib/presentation/widgets/height_editor_sheet.dart
- lib/presentation/widgets/weight_editor_sheet.dart
- lib/presentation/widgets/accent_preset_selector.dart
- test/presentation/widgets/app_bottom_nav_test.dart
- test/widget_test.dart
- test/presentation/screens/app_scaffold_test.dart
- test/presentation/screens/profile_screen_test.dart
- test/presentation/cubits/profile_cubit_test.dart
- test/presentation/cubits/onboarding_cubit_test.dart
- test/presentation/widgets/accent_preset_selector_test.dart
- test/data/repositories/user_preferences_repository_test.dart
- test/data/repositories/step_repository_purge_test.dart
- _bmad-output/implementation-artifacts/sprint-status.yaml

### Change Log

- 2026-06-05: Story 5.11 — Profile screen (Informations, Notifications, Appearance), PROFILE nav label, new user preferences and ProfileCubit.

---

## Story completion status

- **Status:** done
- **Completion note:** Profile tab shipped; code-review fixes (Data AC alignment, export fallback, notification re-prompt, dead BackgroundStatusCard removed).
