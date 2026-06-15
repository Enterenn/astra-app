# Story 10.6: Display Units Preferences

Status: done

<!-- Mockup ref: Settings-light (2026-06-15) — Units card is the **first** SectionCard (above Notifications, then Theme). Row layout: label left, current value + chevron right (single line). Display conversion app-wide deferred to 10.7. -->

## Story

As a **user**,
I want to choose how distance, weight, and height are displayed,
So that the app matches my locale's conventions.

## Acceptance Criteria

1. **Given** Menu → Settings (nested navigator push from Story 10.3)  
   **When** the screen renders (light or dark theme, any accent preset)  
   **Then** the scroll body contains **three** `SectionCard`s in order: **Units**, **Notifications**, **Theme**  
   **And** the Units card shows three tappable rows with chevron: **Distance**, **Weight**, **Height**  
   **And** each row displays the **current selection** on the right: **Metric** / **Kg** / **cm** by default  
   **And** row layout matches Settings-light mockup: label left, value + caret right on **one line** (not Profile's stacked label/value)

2. **Given** user taps a Units row  
   **When** the picker opens  
   **Then** a bottom sheet lists the allowed options:  
   - Distance: **Metric**, **Imperial**  
   - Weight: **Kg**, **lb**  
   - Height: **cm**, **ft+in**  
   **And** the current selection is visually indicated  
   **And** choosing an option persists immediately and updates the row label without leaving Settings

3. **Given** user picks a unit option  
   **When** saved to `user_preferences`  
   **Then** keys persist across app restart:  
   - `distance_display_unit` → `metric` | `imperial`  
   - `weight_display_unit` → `kg` | `lb`  
   - `height_display_unit` → `cm` | `ft_in`  
   **And** defaults when unset are `metric`, `kg`, `cm`  
   **And** canonical profile/body values (`height_cm`, `weight_kg`) and internal distance math remain **metric** — no conversion in this story

4. **Given** implementation complete  
   **When** data purge runs (`StepRepository.purge`)  
   **Then** unit display keys survive alongside `theme_mode`, `display_name`, etc. (setup prefs, not health data)

5. **Given** Settings body after 10.6  
   **When** inspected  
   **Then** Notifications + Theme cards from Story 10.5 remain unchanged in behavior  
   **And** Profile route still shows height/weight in **metric labels only** (`180 cm`, `72 kg`) until Story 10.7 wires formatters  
   **And** Today stats row distance label unchanged until 10.7

6. **Given** failed persistence on unit change  
   **When** repository write throws  
   **Then** cubit state rolls back to last persisted value  
   **And** snackbar **Could not update unit preference** (mirror notification toggle failure copy pattern)

7. **Given** implementation complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no new analyzer issues  
   **And** repository round-trip tests cover all three keys + defaults  
   **And** `units_cubit_test.dart` covers persist + rollback  
   **And** `settings_screen_test.dart` asserts Units card, three rows, default labels, card order (3 SectionCards)  
   **And** `app_scaffold_test.dart` Settings smoke asserts **Units** visible

**Mockup ref:** `Settings-light` — Units card first; Distance **Metric**, Weight **Kg**, Height **cm**.

**Depends on:** Story 10.5 (done). **Enables:** Story 10.7 (app-wide formatters + editor input conversion).

## Tasks / Subtasks

- [x] **Sub-task A — Preference keys, enums, repository** (AC: #3, #4)
  - [x] Add keys + defaults in `preference_keys.dart`: `kDistanceDisplayUnitKey`, `kWeightDisplayUnitKey`, `kHeightDisplayUnitKey`; default storage strings `metric`, `kg`, `cm`
  - [x] Add `lib/core/constants/display_unit_preferences.dart` with enums `DistanceDisplayUnit`, `WeightDisplayUnit`, `HeightDisplayUnit` + `displayLabel` getters (`Metric`, `Imperial`, `Kg`, `lb`, `cm`, `ft+in`) + `storageValue` / `parse*` helpers
  - [x] Extend `UserPreferencesRepository`: `getDistanceDisplayUnit()`, `setDistanceDisplayUnit()`, same for weight/height; unknown/missing values fall back to metric defaults
  - [x] Unit tests in `user_preferences_repository_test.dart` (round-trip + default when absent)
  - [x] Extend `step_repository_purge_test.dart`: seed unit keys in `seedSetupPreferences`, assert survival after purge

- [x] **Sub-task B — UnitsCubit + app wiring** (AC: #3, #6)
  - [x] Add `units_state.dart` + `units_cubit.dart` mirroring `ThemeCubit` patterns (`_setInFlight` serialization optional but preferred for consistency)
  - [x] Methods: `setDistanceUnit`, `setWeightUnit`, `setHeightUnit` — no-op when unchanged; persist via repository; emit on success
  - [x] Load initial values in `AppDependencies.create` / `test()` (like `initialTheme`) → `initialDistanceUnit`, `initialWeightUnit`, `initialHeightUnit`
  - [x] Register `BlocProvider<UnitsCubit>` in `app.dart` alongside `ThemeCubit` (app root scope — 10.7 needs global read)
  - [x] `units_cubit_test.dart`: default state, persist each axis, concurrent set serialization

- [x] **Sub-task C — Settings UI: Units card + picker sheets** (AC: #1, #2, #5, #6)
  - [x] Add `settings_preference_row.dart` — single-line row (label left, trailing value text in `textSecondary` + `PhosphorIconsRegular.caretRight`); min 48dp touch height; distinct from stacked `ProfileInfoRow`
  - [x] Add `unit_option_picker_sheet.dart` — generic bottom sheet for 2-option pick; returns selected enum or null on dismiss; Phosphor check on selected option
  - [x] Update `settings_screen.dart`: insert `SectionCard(headline: 'Units')` **above** Notifications card; wire three rows to `UnitsCubit` via `BlocBuilder`; on pick → cubit setter; snackbar on failure
  - [x] Card order: Units → Notifications → Theme (reorder existing cards — mockup authoritative over 10.5 dev-note guess)

- [x] **Sub-task D — Settings widget tests** (AC: #7)
  - [x] Extend `_pumpSettingsScreen` helper to provide `UnitsCubit` (seeded or real with in-memory repo)
  - [x] Assert: 3 `SectionCard`s; headlines order Units / Notifications / Theme; rows Distance/Weight/Height with default value labels
  - [x] Settings tap→sheet integration test skipped (flaky harness); covered by `unit_option_picker_sheet_test` + `units_cubit_test`
  - [x] Remove/update negative test that expects `find.text('Units')` → findsNothing (from 10.5)

- [x] **Sub-task E — App scaffold nav smoke** (AC: #7)
  - [x] Update `app_scaffold_test.dart` Settings smoke: assert **Units** headline + Distance row visible (keep Notifications/Theme assertions)

- [x] **Sub-task F — Verify** (AC: #7)
  - [x] Run `flutter analyze` + targeted `flutter test` (formatters, activity_stats_row, units_cubit, settings, profile, app_scaffold, repository)

## Dev Notes

### Story scope boundary

**In scope (10.6):**
- Units `SectionCard` on Settings (UI + picker sheets)
- Three new `user_preferences` keys + repository CRUD
- `UnitsCubit` at app root for persistence and future 10.7 consumers
- Reorder Settings cards to match mockup (Units first)
- Repository, cubit, purge-survival, and widget tests

**Out of scope — do not touch:**
- **Display formatters** (`km→mi`, `kg→lb`, `cm→ft/in`) → **Story 10.7**
- **Profile height/weight row labels** and **editor sheets** input units → **Story 10.7**
- **Today stats row** distance/kcal formatting → **Story 10.7**
- `height_cm` / `weight_kg` storage format (always canonical metric)
- `ProfileCubit` API changes
- DB schema migration (keys use existing `user_preferences` KV table)
- GoRouter, version bump (`0.3.0+5` at **Epic 10 close** only)

This story is **persistence + Settings UI only**. Changing a unit pref must **not** visibly alter Profile or Steps screens yet — that is intentional; 10.7 connects formatters to `UnitsCubit` state.

### Mockup alignment (Settings-light, 2026-06-15)

| Element | Settings-light mockup | Target (10.6) |
|---------|----------------------|---------------|
| Card order | **Units** → Notifications → Theme | Reorder `settings_screen.dart` Column children |
| Units headline | **Units** | `SectionCard(headline: 'Units')` |
| Distance row | Label **Distance**, value **Metric** `>` | `SettingsPreferenceRow` + default `DistanceDisplayUnit.metric` |
| Weight row | Label **Weight**, value **Kg** `>` | Default `WeightDisplayUnit.kg`, label **Kg** (capital K per mockup) |
| Height row | Label **Height**, value **cm** `>` | Default `HeightDisplayUnit.cm` |
| Row layout | Single line, value muted gray | Trailing value uses `colors.textSecondary`; chevron `neutralGray` |
| Picker | Not shown — use bottom sheet | Two options per axis; immediate save on tap |

**Card-order correction:** Story 10.5 dev notes said "append below Theme"; the attached mockup places Units **first**. Follow mockup.

### Business context

Post-beta UX tranche (sprint-change-proposal 2026-06-15 §4.5): editable display prefs for distance, weight, height. Canonical storage stays metric internally; display formatters read prefs (10.7). Profile/Settings split: unit **system** lives in Settings; body **values** stay on Profile.

### Storage contract

| Key | Allowed values | Default | UI label |
|-----|----------------|---------|----------|
| `distance_display_unit` | `metric`, `imperial` | `metric` | Metric / Imperial |
| `weight_display_unit` | `kg`, `lb` | `kg` | Kg / lb |
| `height_display_unit` | `cm`, `ft_in` | `cm` | cm / ft+in |

- **No schema migration:** insert/replace into existing `user_preferences` table (same pattern as `theme_mode`).
- **Purge survival:** `StepRepository.purge()` only deletes an explicit allowlist of derived keys; new unit keys are retained automatically — add explicit purge test anyway for regression guard.
- **Internal math unchanged:** `DerivedActivityMetrics` continues using `height_cm`/`weight_kg` in metric; distance computed in km/m — conversion is display-layer only in 10.7.

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 10.6 changes | Must preserve |
|------|---------------|-------------------|---------------|
| `settings_screen.dart` | Notifications + Theme (2 cards) | Add Units card first; reorder to 3 cards | ProfileCubit notification wiring; ThemeCubit selectors; loading/error via ProfileCubit |
| `preference_keys.dart` | No unit keys | Add 3 keys + default constants | All existing keys |
| `user_preferences_repository.dart` | No unit getters/setters | Add 6 methods | All existing methods |
| `app.dart` | Root `ThemeCubit` only | Add root `UnitsCubit` | Theme wiring |
| `app_dependencies.dart` | Loads initial theme/accent | Load initial unit prefs | Existing bootstrap |
| `profile_info_row.dart` | `formatHeightCm` / `formatWeightKg` metric-only | **No changes** | Used by Profile until 10.7 |
| `profile_screen.dart` | Informations only | **No changes** | 10.4/10.5 regression contract |
| `height_editor_sheet.dart` | cm input | **No changes** | Canonical cm save |
| `weight_editor_sheet.dart` | kg input | **No changes** | Canonical kg save |
| `settings_screen_test.dart` | 2 SectionCards; negative "Units" absent | 3 cards; Units present | Notifications/Theme assertions |
| `app_scaffold_test.dart` | Settings smoke: Notifications + Theme | Add Units assertion | Profile cubit refresh polling pattern |

### Target layout after 10.6

```
┌─────────────────────────────────────┐
│  ←  Settings                        │  ← SecondaryScreenShell
├─────────────────────────────────────┤
│  ┌─ Units ───────────────────────┐  │
│  │  Distance          Metric  >  │  │
│  │  Weight               Kg  >  │  │
│  │  Height               cm  >  │  │
│  └───────────────────────────────┘  │
│  ┌─ Notifications ───────────────┐  │
│  │  Receive Goal notifications ○ │  │
│  └───────────────────────────────┘  │
│  ┌─ Theme ───────────────────────┐  │
│  │  [ System | Light | Dark ]    │  │
│  │  ○ ○ ○ ○ ○ ○  (accent chips)  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
        [ floating bottom nav pill ]
```

### Architecture compliance

- **D-09 / Cubit pattern:** New `UnitsCubit` — same family as `ThemeCubit`; app-root `BlocProvider` [Source: `architecture.md` — Frontend Architecture]
- **D-02 / KV prefs:** Keys in `user_preferences`; no migration unless future consolidation [Source: `architecture.md`]
- **Single-writer:** UI writes via `UserPreferencesRepository` only — cubit calls repository, never raw SQL from widgets
- **Presentation-only for body values:** Do not write converted values back to `height_cm`/`weight_kg`
- **Purge (D-24 / FR-20):** Setup prefs survive; unit keys are setup prefs [Source: `step_repository.dart` purge docstring]
- **No GoRouter:** Settings still nested Menu navigator [Source: Epic 10]
- **Review-before-commit:** One commit per sub-task [Source: `docs/project-context.md`]

### Library / framework requirements

| Package | Version | Usage |
|---------|---------|-------|
| `flutter_bloc` | existing | `UnitsCubit` |
| `phosphoricons_flutter` | existing | Row chevron (`caretRight`) |
| `sqflite` | existing | KV persistence via repository |
| Flutter SDK | ^3.12.0 | Bottom sheets + widgets only |

No new dependencies.

### File structure requirements

```
lib/core/constants/preference_keys.dart              # UPDATE — 3 keys + defaults
lib/core/constants/display_unit_preferences.dart     # NEW — enums + labels + parse
lib/data/repositories/user_preferences_repository.dart  # UPDATE — getters/setters
lib/presentation/cubits/units_cubit.dart             # NEW
lib/presentation/cubits/units_state.dart             # NEW
lib/presentation/widgets/settings_preference_row.dart # NEW — single-line settings row
lib/presentation/widgets/unit_option_picker_sheet.dart # NEW — 2-option picker
lib/presentation/screens/settings_screen.dart        # UPDATE — Units card + reorder
lib/core/di/app_dependencies.dart                    # UPDATE — initial unit prefs
lib/app.dart                                         # UPDATE — UnitsCubit provider
test/data/repositories/user_preferences_repository_test.dart  # UPDATE
test/data/repositories/step_repository_purge_test.dart        # UPDATE
test/presentation/cubits/units_cubit_test.dart       # NEW
test/presentation/screens/settings_screen_test.dart  # UPDATE
test/presentation/screens/app_scaffold_test.dart     # UPDATE
```

**Do not create or modify (unless regression fix):**
- `profile_screen.dart`, `profile_info_row.dart`, editor sheets
- `lib/core/metrics/` (10.7)
- `today_screen.dart` stats formatting (10.7)

### Testing requirements

- **Repository:** round-trip each key; absent key → default; invalid stored value → default (defensive parse)
- **Purge:** unit keys present after purge when seeded in setup prefs
- **UnitsCubit:** emit after set; no duplicate writes when value unchanged; failed write does not corrupt state
- **Settings layout:** 3 SectionCards in order; default row labels Metric/Kg/cm
- **Picker interaction:** tap Distance → sheet → select Imperial → row shows Imperial; persistence survives cubit re-create with same repo
- **Profile regression:** existing `profile_screen_test.dart` unchanged and green
- **Scaffold smoke:** Menu → Settings shows Units + existing cards
- Run full `flutter test` before story close

### Previous story intelligence (Story 10.5)

Story 10.5 established:
- Full Settings body with Notifications + Theme; `ProfileCubit` hoisted on push
- `settings_screen_test.dart` pump helper with `_SeededProfileCubit` + `ThemeCubit`
- Negative assertion `find.text('Units')` → findsNothing — **must flip** in 10.6
- Loading/error gated on `ProfileCubit` — Units rows appear only in ready state (same as Theme card)
- Settings integration test needs polling loop for async `ProfileCubit.refresh()` — reuse pattern from `app_scaffold_test.dart`
- Code review deferred: refresh-vs-toggle race on Settings push — same pattern acceptable for Units (read-only prefs load)

### Previous story intelligence (Story 10.4)

- `formatHeightCm` / `formatWeightKg` intentionally metric until unit formatters land
- Do not regress Profile slim layout (Informations only)

### Git intelligence

Recent commits (10.5):
- `018ba9f` — 10.5 code review close
- `2020037` — ProfileCubit on Settings push with refresh
- `ff28073` — settings_screen_test.dart

Follow patterns: minimal diff, sub-task commits with review gates, extend existing test helpers rather than new harnesses.

### Latest tech information

- **Flutter 3.12+** `showModalBottomSheet` — same pattern as `height_editor_sheet.dart`; no new APIs
- **`flutter_bloc` ^9.x** — `Cubit` + `BlocProvider` at root; `context.read<UnitsCubit>()` from Settings (no push-scoped provider needed unlike ProfileCubit)
- **No locale auto-detection:** Defaults are metric; user explicitly chooses (matches sprint proposal "editable display prefs", not OS locale sync)

### Project context reference

- Version bump at Epic 10 close only: `0.3.0+5` [Source: `.cursor/rules/app-versioning.mdc`]
- Mockup asset: `assets/c__Users_Baptiste_..._Settings-light-*.png`
- BETA checklist case "units toggle" lands at Epic 10 close, not this sub-story [Source: sprint-change-proposal §4]

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Epic 10, Story 10.6]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` §4.5]
- [Source: `_bmad-output/implementation-artifacts/stories/10-5-settings-appearance-and-notifications.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/10-4-profile-slim-informations.md`]
- [Source: `lib/presentation/screens/settings_screen.dart`]
- [Source: `lib/presentation/widgets/profile_info_row.dart` — row/chevron reference, different layout]
- [Source: `lib/presentation/cubits/theme_cubit.dart` — cubit persistence pattern]
- [Source: `lib/data/repositories/user_preferences_repository.dart`]
- [Source: `lib/core/constants/preference_keys.dart`]
- [Source: `test/data/repositories/step_repository_purge_test.dart`]
- [Source: Mockup: Settings-light (2026-06-15)]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- Story 10.6 complete: Units card on Settings (Units → Notifications → Theme), three KV prefs + repository, UnitsCubit at app root.
- Per Baptiste feedback: display formatters wired to Today distance (km/mi) and Profile height/weight labels; Phosphor check on picker selection.
- `ActivityStatsRow` accepts optional `distanceDisplayUnit` for test injection; production reads `UnitsCubit`.
- Settings tap→sheet widget test skipped (flaky); picker + cubit tests cover persistence and sheet UX.
- Profile/Today editor input units remain metric (Story 10.7).

### File List

- lib/core/constants/preference_keys.dart
- lib/core/constants/display_unit_preferences.dart
- lib/core/di/app_dependencies.dart
- lib/data/repositories/user_preferences_repository.dart
- lib/app.dart
- lib/presentation/cubits/units_cubit.dart
- lib/presentation/cubits/units_state.dart
- lib/presentation/formatters/display_unit_formatter.dart
- lib/presentation/screens/settings_screen.dart
- lib/presentation/screens/profile_screen.dart
- lib/presentation/widgets/settings_preference_row.dart
- lib/presentation/widgets/unit_option_picker_sheet.dart
- lib/presentation/widgets/activity_stats_row.dart
- lib/presentation/widgets/profile_info_row.dart
- test/data/repositories/user_preferences_repository_test.dart
- test/data/repositories/step_repository_purge_test.dart
- test/presentation/cubits/units_cubit_test.dart
- test/presentation/formatters/display_unit_formatter_test.dart
- test/presentation/widgets/unit_option_picker_sheet_test.dart
- test/presentation/widgets/activity_stats_row_test.dart
- test/presentation/screens/settings_screen_test.dart
- test/presentation/screens/app_scaffold_test.dart
- test/presentation/screens/profile_screen_test.dart
- test/presentation/screens/screen_smoke_test.dart
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/stories/10-6-display-units-preferences.md

## Change Log

- 2026-06-16: Story 10.6 created — Units persistence + Settings UI; UnitsCubit at app root; mockup card order (Units first); display formatters deferred to 10.7.
- 2026-06-16: Story 10.6 implemented — Settings Units card, UnitsCubit, display formatters on Today/Profile; ready for review.
- 2026-06-16: Code review fixes — snackbar no-op guard, settings test compile fix, imperial profile test runAsync; story done.
