# Story 10.7: App-Wide Unit Formatters

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want all displayed measurements to respect my unit choices,
So that numbers feel natural everywhere.

## Acceptance Criteria

1. **Given** unit prefs set to Imperial / lb / ft+in (via Settings → Units from Story 10.6)  
   **When** user views the Today **stats row** (`ActivityStatsRow`)  
   **Then** distance value converts km→mi (one decimal, half-up) and label reads **Mi** (not **Km**)  
   **And** kcal and walking duration formatting are unchanged  
   **And** changing unit pref in Settings updates the stats row without app restart

2. **Given** unit prefs set to Imperial / lb / ft+in  
   **When** user views Profile **Informations** height/weight rows  
   **Then** labels use display formatters: `cm→ft/in`, `kg→lb` (same rules as `formatDisplayHeight` / `formatDisplayWeight`)  
   **And** null height/weight still show **Not set**

3. **Given** user opens Profile height editor  
   **When** `height_display_unit` is **cm**  
   **Then** sheet shows single numeric field labeled **Centimeters** (existing behavior preserved)  
   **When** `height_display_unit` is **ft_in**  
   **Then** sheet shows **two** integer fields: **Feet** and **Inches** (0–11)  
   **And** fields pre-fill from current canonical `height_cm` using the same rounding as display (`round(cm / 2.54)` total inches → ft/in)  
   **And** Save returns canonical **cm** to `ProfileCubit.updateHeightCm` (convert display input → cm before pop)  
   **And** validation enforces canonical range `100–250 cm` after conversion  
   **And** empty fields → clear (`-1` sentinel, unchanged contract)

4. **Given** user opens Profile weight editor  
   **When** `weight_display_unit` is **kg**  
   **Then** sheet shows kilogram field (existing behavior preserved)  
   **When** `weight_display_unit` is **lb**  
   **Then** sheet shows **Pounds** field (one decimal max, same input rules as kg field)  
   **And** field pre-fills from current `weight_kg` converted to lb for display  
   **And** Save returns canonical **kg** (one decimal, half-up) to `ProfileCubit.updateWeightKg`  
   **And** validation enforces canonical range `30–300 kg` after conversion

5. **Given** canonical storage contract  
   **When** any editor save or formatter runs  
   **Then** `user_preferences.height_cm`, `weight_kg`, and internal distance math remain **metric** — display conversion only  
   **And** `DerivedActivityMetrics` inputs unchanged (still reads cm/kg from repository)

6. **Given** Trends screen (Epic 12)  
   **When** inspected in current codebase  
   **Then** no Trends stats row exists yet — **out of scope** for 10.7  
   **And** `display_unit_formatter.dart` remains the single display conversion module so Epic 12 can import it later

7. **Given** implementation complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no new analyzer issues  
   **And** `display_unit_formatter_test.dart` covers display formatters **and** inverse conversion round-trips (cm↔ft/in, kg↔lb, km↔mi display)  
   **And** edge cases: null profile values, zero distance, boundary heights/weights at min/max  
   **And** `profile_editor_sheets_test.dart` covers imperial height (ft/in → cm) and imperial weight (lb → kg) save paths  
   **And** existing `activity_stats_row_test.dart`, `profile_screen_test.dart` imperial tests remain green

**Depends on:** Story 10.6 (done). **Enables:** Story 10.8 (Data/About — no unit dependency, parallel OK).

## Tasks / Subtasks

- [x] **Sub-task A — Inverse conversion helpers** (AC: #3, #4, #5, #7)
  - [x] Extend `lib/presentation/formatters/display_unit_formatter.dart` with canonical conversion helpers (keep constants `_kmPerMile`, `_lbPerKg`, `_cmPerInch` in one file):
    - `({int feet, int inches}) heightCmToFtIn(int heightCm)` — mirror display rounding
    - `int heightFtInToCm({required int feet, required int inches})` — validate inches 0–11
    - `double weightKgToDisplayLb(double weightKg)` / `double displayLbToWeightKg(double lb)` — one decimal kg storage
  - [x] Add round-trip + boundary tests in `display_unit_formatter_test.dart`
  - [x] Update stale comment in `display_unit_preferences.dart` (remove "until Story 10.7")
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Height editor unit-aware input** (AC: #3, #5, #7)
  - [x] Add `heightUnit` parameter to `showHeightEditorSheet` (default `HeightDisplayUnit.cm` for tests)
  - [x] Metric mode: keep existing single `TextField` + validation
  - [x] ft+in mode: two digit-only fields (Feet, Inches); inches 0–11; error copy in imperial terms but validate canonical cm range
  - [x] Pre-fill from `currentHeightCm` via `heightCmToFtIn` when unit is ft+in
  - [x] Save still pops `int?` cm (or `-1` clear) — **no API change** to `ProfileCubit`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Weight editor unit-aware input** (AC: #4, #5, #7)
  - [x] Add `weightUnit` parameter to `showWeightEditorSheet` (default `WeightDisplayUnit.kg`)
  - [x] lb mode: label **Pounds**, validate lb range derived from `kMinWeightKg`/`kMaxWeightKg`, convert to kg on Save
  - [x] Pre-fill from `currentWeightKg` via `weightKgToDisplayLb`
  - [x] Save still pops `double?` kg (or `-1.0` clear)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Profile screen wiring** (AC: #3, #4)
  - [x] In `profile_screen.dart` `editHeight` / `editWeight`, pass current unit from `context.read<UnitsCubit>().state`
  - [x] No changes to save handlers — they already expect canonical cm/kg
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Verify display surfaces already wired (10.6 bleed)** (AC: #1, #2, #7)
  - [x] Confirm `ActivityStatsRow` + Profile labels still use `UnitsCubit` / `formatDisplay*` — fix only if regression found
  - [x] Remove or deprecate unused metric-only wrappers `formatHeightCm` / `formatWeightKg` in `profile_info_row.dart` if nothing imports them (avoid dual code paths)
  - [x] Extend `profile_editor_sheets_test.dart` with imperial editor cases
  - [x] Run targeted tests + full `flutter test`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**Already implemented in Story 10.6 (do not redo — verify only):**
- `lib/presentation/formatters/display_unit_formatter.dart` — display formatters (`formatDisplayDistanceValue`, `formatDisplayHeight`, `formatDisplayWeight`, `displayDistanceUnitLabel`)
- `ActivityStatsRow` — `BlocBuilder<UnitsCubit>` + optional test injection param `distanceDisplayUnit`
- `ProfileScreen` Informations rows — `formatDisplayHeight` / `formatDisplayWeight` with `unitsState`
- `UnitsCubit` at app root + persistence (Story 10.6)
- Baseline formatter + imperial widget tests (`display_unit_formatter_test.dart`, `activity_stats_row_test.dart`, `profile_screen_test.dart` imperial case)

**In scope (10.7 — primary work):**
- **Inverse conversion** helpers (display input → canonical)
- **Height/weight editor sheets** accept display-unit input, convert on save
- **Profile screen** passes current `UnitsCubit` unit into editor sheets
- **Round-trip + editor tests** per AC #7

**Out of scope — do not touch:**
- Settings Units card / `UnitsCubit` persistence (10.6)
- `height_cm` / `weight_kg` storage keys or DB schema
- `DerivedActivityMetrics` formulas (`lib/core/metrics/`)
- Trends / History distance labels (Epic 12 — no stats row yet; History chart is steps-only)
- GoRouter, version bump (`0.3.0+5` at **Epic 10 close** only)
- Distance editor (distance is derived from steps, not user-edited)

### Partial implementation note (critical)

Commit `201611a` landed display formatters + Profile/Today label wiring under Story 10.6. **10.7 is not greenfield** — treat display wiring as done; focus on **editors + inverse conversion + test gaps**. Do not duplicate formatter logic or re-wire `ActivityStatsRow` unless tests fail.

### Conversion rules (single source of truth)

| Axis | Constants | Display | Storage |
|------|-----------|---------|---------|
| Distance | `_kmPerMile = 1.609344` | mi, 1 decimal half-up | km internally |
| Weight | `_lbPerKg = 2.2046226218` | lb, 0 or 1 decimal | kg, 1 decimal (`×10` round) |
| Height | `_cmPerInch = 2.54` | `N ft M in` (total inches rounded) | cm integer |

**Height ft+in display rounding (must match editor pre-fill):**
```dart
final totalInches = (heightCm / _cmPerInch).round();
final feet = totalInches ~/ 12;
final inches = totalInches % 12;
```

**Inverse height:** `heightCm = ((feet * 12) + inches) * _cmPerInch` → round to nearest int cm → validate `kMinHeightCm`–`kMaxHeightCm`.

**Weight lb input:** same decimal rules as kg editor (one decimal place, comma/dot tolerant) → convert to kg → `(kg * 10).round() / 10` → validate range.

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 10.7 changes | Must preserve |
|------|---------------|-------------------|---------------|
| `display_unit_formatter.dart` | Display-only formatters | Add inverse conversion helpers | Existing display functions + constants |
| `height_editor_sheet.dart` | cm-only field, label **Centimeters** | ft+in two-field mode when unit param is `ftIn` | Return type `Future<int?>`; `-1` clear sentinel; `kMinHeightCm`/`kMaxHeightCm` |
| `weight_editor_sheet.dart` | kg-only field, label **Kilograms** | lb mode when unit param is `lb` | Return type `Future<double?>`; `-1.0` clear; 1 decimal kg |
| `profile_screen.dart` | Labels unit-aware; editors ignore unit | Pass `heightUnit`/`weightUnit` into sheet calls | `ProfileCubit` save flow + snackbars |
| `profile_info_row.dart` | Widget + metric-only wrapper fns | Remove dead `formatHeightCm`/`formatWeightKg` if unused | `ProfileInfoRow` widget API |
| `activity_stats_row.dart` | Unit-aware distance | **Verify only** | `distanceDisplayUnit` test injection |
| `display_unit_preferences.dart` | Enums + parse | Update header comment only | Enum values / storage strings |

### Editor UX (no mockup — follow sprint proposal)

| Mode | Fields | Labels | Save contract |
|------|--------|--------|---------------|
| Height cm | 1 × integer | Centimeters | pop `int` cm |
| Height ft+in | 2 × integer | Feet, Inches | pop `int` cm (converted) |
| Weight kg | 1 × decimal | Kilograms | pop `double` kg |
| Weight lb | 1 × decimal | Pounds | pop `double` kg (converted) |

Use existing sheet chrome: drag handle, title **Height** / **Weight**, `profileSheetFieldDecoration`, `AstraButton` Save/Cancel, `isScrollControlled: true`, keyboard inset padding — mirror current sheets.

**Pass unit via parameter** (not `BlocBuilder` inside sheet) so `profile_editor_sheets_test.dart` stays simple:

```dart
showHeightEditorSheet(
  context,
  currentHeightCm: profileState.heightCm,
  heightUnit: context.read<UnitsCubit>().state.heightUnit,
);
```

### Architecture compliance

- **D-09 / Cubit pattern:** Read units from app-root `UnitsCubit`; do not persist from editor sheets [Source: `architecture.md` — Frontend Architecture]
- **Presentation-only conversion:** Editors convert input → canonical before `ProfileCubit` write — never store lb or ft/in in `user_preferences` [Source: sprint-change-proposal §4.5]
- **Single formatter module:** All conversion math in `display_unit_formatter.dart`; `activity_metrics_formatter.dart` stays metric-only for raw km [Source: sprint-change-proposal impacted files]
- **Derived metrics unchanged:** `height_cm`/`weight_kg` remain canonical; `TodayCubit` metrics pipeline untouched [Source: `architecture.md` — Derived activity metrics]
- **Review-before-commit:** One commit per sub-task [Source: `docs/project-context.md`]
- **No GoRouter:** Profile still nested Menu navigator [Source: Epic 10]

### Library / framework requirements

| Package | Version | Usage |
|---------|---------|-------|
| `flutter_bloc` | existing | Read `UnitsCubit` in Profile screen |
| Flutter SDK | ^3.12.0 | Bottom sheets + `TextField` / `FilteringTextInputFormatter` |

No new dependencies.

### File structure requirements

```
lib/presentation/formatters/display_unit_formatter.dart     # UPDATE — inverse helpers
lib/presentation/widgets/height_editor_sheet.dart             # UPDATE — ft+in mode
lib/presentation/widgets/weight_editor_sheet.dart             # UPDATE — lb mode
lib/presentation/screens/profile_screen.dart                    # UPDATE — pass unit params
lib/core/constants/display_unit_preferences.dart              # UPDATE — comment only
lib/presentation/widgets/profile_info_row.dart                # UPDATE — remove dead wrappers (if safe)
test/presentation/formatters/display_unit_formatter_test.dart # UPDATE — round-trip + edges
test/presentation/widgets/profile_editor_sheets_test.dart     # UPDATE — imperial editor tests
```

**Verify only (likely no edits):**
- `activity_stats_row.dart`, `settings_screen.dart`, `units_cubit.dart`, `user_preferences_repository.dart`

**Do not create or modify:**
- `lib/core/metrics/derived_activity_metrics.dart`
- History/Trends screens (Epic 12)
- Settings Units UI (10.6)

### Testing requirements

**Formatter unit tests (`display_unit_formatter_test.dart`):**
- Round-trip: `180 cm` → ft/in → back to cm within ±1 cm (display rounding tolerance)
- Round-trip: `72.5 kg` ↔ lb ↔ kg (one decimal)
- Round-trip: `10 km` → mi display → not applicable for input (distance read-only) — test display value only
- Edge: `formatDisplayHeight(null, …)` → **Not set**; zero distance → `0.0` mi/km
- Boundary: height at `100 cm` and `250 cm` in ft+in mode; weight at `30 kg` / `300 kg` in lb mode
- Invalid: inches > 11 rejected; out-of-range after conversion rejected

**Editor widget tests (`profile_editor_sheets_test.dart`):**
- Height ft+in: enter 5 ft 11 in → pop cm ≈ 180 (allow rounding)
- Weight lb: enter `159.8` → pop `72.5` kg (or nearest 1-decimal canonical)
- Metric paths unchanged (regression)

**Regression (must stay green):**
- `profile_screen_test.dart` — imperial label formatting
- `activity_stats_row_test.dart` — imperial distance injection
- `profile_screen_test.dart` — no notification/theme on Profile

Run full `flutter test` before story close.

### Previous story intelligence (Story 10.6)

Story 10.6 delivered:
- `UnitsCubit` + three KV keys + Settings Units card
- Display formatters wired to Profile labels and Today stats row (landed early — see partial implementation note)
- `ActivityStatsRow.distanceDisplayUnit` optional param for tests (prefer injection over mocking `UnitsCubit` in row tests)
- Code review fixes: snackbar no-op guard, imperial profile test uses `tester.runAsync` for async cubit sets
- **Intentionally deferred to 10.7:** editor input units; inverse conversion helpers

Do not revert 10.6 display wiring. Do not re-add "metric only" assertions on Profile/Today.

### Previous story intelligence (Story 10.4)

- Profile editors return canonical values; `-1` / `-1.0` clear sentinels — **keep contract**
- `profile_editor_sheets_test.dart` exists — extend, don't duplicate new test file
- Validation messages reference cm/kg today — update copy for lb/ft+in modes but keep canonical range enforcement

### Git intelligence

Recent commits:
- `1d3ba43` — Story 10.6 code review close (display formatters + Units UI)
- `201611a` — Units prefs + partial formatter wiring (labeled 10.6)
- `018ba9f` — Story 10.5 close

Follow patterns: minimal diff, sub-task commits with review gates, extend existing test helpers.

### Latest tech information

- **Flutter 3.12+** — `showModalBottomSheet` + dual `TextField` layout for ft+in; no new APIs
- **`flutter_bloc` ^9.x** — `context.read<UnitsCubit>()` at tap time (unit won't change mid-sheet — acceptable)
- **No `intl` package** — manual formatting matches existing `activity_metrics_formatter.dart` approach
- **Conversion constants** — use same values as NIST/US customary (already in codebase); no locale auto-detection

### Project context reference

- Version bump at Epic 10 close only: `0.3.0+5` [Source: `.cursor/rules/app-versioning.mdc`]
- BETA checklist "units toggle" validates Profile + Steps display at Epic 10 close [Source: sprint-change-proposal §4]
- Success criterion: "Units change updates Profile + Steps stats display" — display part done in 10.6; editors complete the user journey [Source: sprint-change-proposal §5]

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Epic 10, Story 10.7]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` §4.5, §5]
- [Source: `_bmad-output/implementation-artifacts/stories/10-6-display-units-preferences.md`]
- [Source: `lib/presentation/formatters/display_unit_formatter.dart`]
- [Source: `lib/presentation/widgets/height_editor_sheet.dart`]
- [Source: `lib/presentation/widgets/weight_editor_sheet.dart`]
- [Source: `lib/presentation/screens/profile_screen.dart`]
- [Source: `lib/presentation/widgets/activity_stats_row.dart`]
- [Source: `lib/core/constants/preference_keys.dart` — `kMinHeightCm`, `kMaxHeightCm`, `kMinWeightKg`, `kMaxWeightKg`]
- [Source: `test/presentation/widgets/profile_editor_sheets_test.dart`]
- [Source: `test/presentation/formatters/display_unit_formatter_test.dart`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Height round-trip at kMinHeightCm (100): display rounds to 3 ft 3 in → 99 cm inverse; editor validation correctly rejects (documented in test).

### Completion Notes List

- Added inverse conversion helpers (`heightCmToFtIn`, `heightFtInToCm`, `weightKgToDisplayLb`, `displayLbToWeightKg`) in single formatter module; refactored display formatters to reuse `heightCmToFtIn`.
- Height editor: `heightUnit` param; ft+in mode with Feet/Inches fields, pre-fill, canonical cm on save.
- Weight editor: `weightUnit` param; lb mode with Pounds field, lb range validation, canonical kg on save.
- Profile screen passes `UnitsCubit` units into editor sheets; save handlers unchanged.
- Removed unused `formatHeightCm`/`formatWeightKg` wrappers from `profile_info_row.dart`.
- Display wiring from 10.6 verified (no regressions). Full suite: 695 tests passed, 15 skipped.

### File List

- `lib/presentation/formatters/display_unit_formatter.dart`
- `lib/core/constants/display_unit_preferences.dart`
- `lib/presentation/widgets/height_editor_sheet.dart`
- `lib/presentation/widgets/weight_editor_sheet.dart`
- `lib/presentation/screens/profile_screen.dart`
- `lib/presentation/widgets/profile_info_row.dart`
- `test/presentation/formatters/display_unit_formatter_test.dart`
- `test/presentation/widgets/profile_editor_sheets_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/stories/10-7-app-wide-unit-formatters.md`

## Change Log

- 2026-06-16: Story 10.7 created — completes unit formatter rollout (editors + inverse conversion); display wiring from 10.6 documented as pre-done; ready for dev.
- 2026-06-16: Story 10.7 implemented — inverse conversion helpers, unit-aware height/weight editors, Profile wiring, tests extended; ready for review.
- 2026-06-16: Code review fixes — lb validation via canonical kg, imperial height error copy, boundary/clear editor tests; story done.
