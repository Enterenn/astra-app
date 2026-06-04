# Story 5.8: Accent Preset Theme Tokens

Status: done

<!-- Product owner locked palette 2026-06-04 (Baptiste). Replaces legacy amber `#EAD55E` accent. UI selector deferred to Story 5.11. -->

## Story

As a **user**,
I want six accent color presets that work in light and dark themes,
so that Appearance on Profil can theme the whole app consistently.

## Acceptance Criteria

1. **Given** `AstraColors` and `astra_theme.dart`  
   **When** tokens are defined for presets `orange | red | green | blue | magenta | pink`  
   **Then** each preset supplies **accent primary** and **accent secondary** hex values per the locked table below  
   **And** light/dark **surface** and **text** tokens match the locked neutrals table  
   **And** default preset is **`orange`**  
   **And** no ad-hoc `Color(0x…)` in widgets — only `context.astraColors.*` or `Theme.of(context)` (V-2)

2. **Given** `user_preferences.accent_preset`  
   **When** read at cold start  
   **Then** `ThemeCubit` (extended) applies the stored preset app-wide before first painted frame (same no-flash pattern as Story 4.7 `theme_mode`)  
   **And** invalid/missing DB values fall back to `orange`  
   **And** legacy stored values `cyan` → `blue`, `purple` → `magenta` (backward-compatible parse)

3. **Given** the user changes preset at runtime (dev/test hook or future 5.11 selector)  
   **When** `ThemeCubit.setAccentPreset` completes  
   **Then** `MaterialApp` rebuilds `theme` / `darkTheme` with the new `AstraColors` extension immediately (no restart)

4. **Given** primary buttons (`AstraButton` primary) and the floating nav bar (`AppBottomNav`)  
   **When** rendered in light and dark for each preset  
   **Then** label/icon contrast on `accentPrimary` fills uses **`accentSecondary`** (dark companion of the preset), not legacy `textInverse` on amber  
   **And** contrast meets UX §4.1 baseline (NFR5) — document any preset that fails WCAG AA in Dev Agent Record

5. **Given** goal-met semantics (field feedback 2026-06-03)  
   **When** Today ring or Trends bar reflects goal met  
   **Then** `statusOk` remains **`#7CEA89`** (success green) independent of accent preset

6. **Given** chart bars and trend indicators  
   **When** rendered with the active preset  
   **Then** `dataPositive` equals **`accentPrimary`** (full preset color)  
   **And** `dataNegative` equals **`accentPrimary` @ 33% opacity** (de-emphasis / secondary bar state per Figma)  
   **And** `step_bar_chart` bar fill uses `dataPositive` (not legacy `accentPrimaryMuted` or fixed green/red)

7. **Given** borders and secondary copy  
   **When** tokens are applied  
   **Then** **`borderPrimary`** uses the preset **`accentPrimary`**  
   **And** **`borderDefault`** (neutral / gray borders) uses **`neutralGray`** (`#A0A0AA`, same in light and dark)  
   **And** **`neutralGray`** is used for designated secondary **text** and **UI elements** (labels, icons, dividers) per mockups — not only borders

8. **Given** token work complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no regressions; `test/core/constants/astra_colors_test.dart` updated for new hex + preset matrix  
   **And** add `test/core/constants/astra_accent_presets_test.dart` (or equivalent) asserting all six presets × light/dark primary/secondary

**Depends on:** Story 5.7 (done).  
**Prerequisite for:** Stories 5.9, 5.10, 5.11 (`AccentPresetSelector` UI).  
**Out of scope:** Profil Appearance UI, bi-tone chips, height/weight rows → **5.11** only.

---

## Locked color specification (authoritative — Baptiste 2026-06-04)

All names below are **English** (code, docs, comments). Persisted enum / SQLite values match the **Enum ID** column.

### Accent presets (preset-dependent)

| Enum ID | Display name | Accent primary `#RRGGBB` | Accent secondary (on-primary) `#RRGGBB` |
|---------|--------------|--------------------------|----------------------------------------|
| `orange` | Orange | `FBB577` | `59402A` |
| `red` | Red | `DB5858` | `4C2020` |
| `green` | Green | `79D676` | `295128` |
| `blue` | Blue | `75BDE4` | `274758` |
| `magenta` | Magenta | `7D81EF` | `34355B` |
| `pink` | Pink | `E684C7` | `5D2D4E` |

**Default:** `orange`.  
**Legacy DB aliases:** `cyan` → `blue`, `purple` → `magenta` in `parseAccentPreset()`.  
**Supersedes:** legacy single accent `#EAD55E` (Story 1.2). Update UX spec §1.2 when hex land in code.

### Neutral & semantic tokens (mostly theme-independent)

| Token name | `AstraColors` field | Hex / rule | Light / dark |
|------------|---------------------|------------|--------------|
| App background | `bgBase` | `F8F9FB` / `101115` | Per brightness |
| Card background | `bgElevated` | `FFFFFF` / `1A1D26` | Per brightness |
| Inner card / inset surface | `bgSubtle` | `EEF0F4` / `3E4457` | Per brightness |
| Primary text | `textPrimary` | `323337` / `C8C8D7` | Per brightness |
| Neutral gray | `neutralGray` | `A0A0AA` | **Same both themes** — secondary text, icons, gray borders |
| Success / validation | `statusOk` | `7CEA89` | Same both themes — goal-met, healthy status |
| Error / danger | `statusDanger` | `E52F2F` | Same both themes — destructive actions |

### Derived accent tokens (preset-dependent)

| Token name | `AstraColors` field | Rule |
|------------|---------------------|------|
| Accent primary | `accentPrimary` | From preset table — ring stroke, CTA fill, nav pill, **chart bar (positive)** |
| Accent secondary | `accentSecondary` | From preset table — text/icons **on** `accentPrimary` surfaces |
| Accent primary muted | `accentPrimaryMuted` | `accentPrimary` @ **28%** — ring **track** only (not chart bars) |
| Chart bar positive | `dataPositive` | **`accentPrimary`** (100%) |
| Chart bar negative / de-emphasis | `dataNegative` | **`accentPrimary` @ 33%** |
| Goal reference line | `dataGoalLine` | `accentPrimary` @ **35%** (dashed goal line — keep unless Figma says otherwise) |
| Primary border | `borderPrimary` | **`accentPrimary`** (**new** field) |
| Default / gray border | `borderDefault` | **`neutralGray`** — replaces old `#D1D5DB` / `#2E3340` |

### Tokens to drop or stop using in 5.8

| Old field | Action |
|---------|--------|
| `borderFocus` | Remove or alias to `borderPrimary` — no separate gray focus hex |
| Fixed `dataPositive` green / `dataNegative` pink | **Remove** — chart/trend colors follow preset per AC #6 |
| `textSecondary` / `textMuted` | Keep fields for backward compat in `AstraColors`, but **new** secondary copy/icons should prefer **`neutralGray`** where mockups use gray |

---

## Tasks / Subtasks

- [x] **Sub-task A — Preset model + palette table** (AC: #1, #2)
  - [x] Add `lib/core/constants/astra_accent_preset.dart`: `enum AstraAccentPreset { orange, red, green, blue, magenta, pink }` + `parseAccentPreset(String?)` defaulting to `orange`, aliases `cyan`→`blue`, `purple`→`magenta`
  - [x] Add `lib/core/constants/astra_accent_palette.dart`: `AccentPalette { Color primary, Color secondary }` for all six presets
  - [x] Unit tests: every preset hex matches locked table; legacy aliases parse correctly
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **Sub-task B — Refactor `AstraColors` factories** (AC: #1, #5–#7)
  - [x] `AstraColors.light({AstraAccentPreset preset})` / `.dark({...})` — neutrals + preset palette
  - [x] Add `neutralGray`, `borderPrimary`; set `borderDefault` = `neutralGray`
  - [x] Set `dataPositive` = `accentPrimary`, `dataNegative` = `accentPrimary.withValues(alpha: 0.33)`
  - [x] Keep `accentPrimaryMuted` @ 28% for ring track only
  - [x] Update `statusOk` / `statusDanger` hex; update dark/light surfaces and `textPrimary` per neutrals table
  - [x] Remove hardcoded `#EAD55E`; remove obsolete `borderFocus` or map to `borderPrimary`
  - [x] Update `copyWith`, `lerp` for new/removed fields
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **Sub-task C — Theme builders take preset** (AC: #1, #3)
  - [x] `buildAstraLightTheme({AstraAccentPreset preset})` / `buildAstraDarkTheme({...})`
  - [x] `ColorScheme.primary` = `accentPrimary`; `onPrimary` = `accentSecondary`; `outline` = `borderDefault` (`neutralGray`)
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **Sub-task D — Persistence + `ThemeCubit`** (AC: #2, #3)
  - [x] `kAccentPresetKey = 'accent_preset'`, default `orange`
  - [x] `UserPreferencesRepository`: `getAccentPreset()` / `setAccentPreset()` — persist English enum names (`blue`, not `cyan`)
  - [x] Extend `ThemeState` + `ThemeCubit.setAccentPreset`
  - [x] `AppDependencies.initialAccentPreset`; `app.dart` rebuilds themes from state
  - [x] Purge preserves `accent_preset` (FR-30)
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **Sub-task E — Widget token wiring** (AC: #4, #6, #7)
  - [x] `AstraButton` primary: label → `accentSecondary`
  - [x] `AppBottomNav`: inactive on-accent labels/icons → `accentSecondary` or `neutralGray` per mockup
  - [x] `step_bar_chart`: bar `color` → `dataPositive` (verify goal-line still `dataGoalLine`)
  - [x] `trend_chip`: up → `dataPositive`, down → `dataNegative` (preset-tinted, not fixed green/red)
  - [x] Grep `textSecondary` / hardcoded borders — migrate gray UI to `neutralGray`, accent borders to `borderPrimary`
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **Sub-task F — Tests + docs** (AC: #8)
  - [x] Update `astra_colors_test.dart` (neutrals, borders, dataPositive/negative derivation, presets)
  - [x] Add preset matrix tests
  - [x] Extend `theme_cubit_test.dart`; test `cyan`/`purple` legacy parse
  - [x] Run `flutter analyze` + `flutter test`
  - [x] **Stop → review brief → Baptiste OK → commit**

---

## Dev Notes

### Story scope boundary

**In scope:** Token definitions, preset matrix (English IDs), DB persistence + legacy aliases, `ThemeCubit` wiring, border/chart/trend token consumers listed in Sub-task E.

**Out of scope:** `AccentPresetSelector` UI → **5.11**; screen layouts → **5.9–5.11**; full cohesion audit → **5.12**.

### `neutralGray` usage (product rule)

Use `neutralGray` (`#A0A0AA`) for:

- **Gray borders** → `borderDefault`
- **Secondary text** where mockups show gray (captions, helper lines, inactive metadata) — prefer over legacy `textSecondary` hex
- **Secondary UI elements** — muted icons, divider lines, disabled-looking chrome that is not `textMuted` disabled state

Do **not** use `neutralGray` for text on `accentPrimary` fills — use `accentSecondary` (AC #4).

### Border tokens (product rule)

| Use case | Token |
|----------|--------|
| Accent / primary outline (focus, active card edge, accent divider) | `borderPrimary` (= preset `accentPrimary`) |
| Neutral / gray outline (card dividers, subtle separators) | `borderDefault` (= `neutralGray`) |

### Chart & trend colors (product rule)

Per Figma bar chart mockups:

| Visual | Token | Value |
|--------|--------|--------|
| Main / emphasis bar | `dataPositive` | `accentPrimary` |
| De-emphasis / secondary bar | `dataNegative` | `accentPrimary` @ **33%** |
| Ring track | `accentPrimaryMuted` | `accentPrimary` @ **28%** (unchanged role) |
| Dashed goal line | `dataGoalLine` | `accentPrimary` @ **35%** |

### Current code state (read before editing)

| File | Today | This story |
|------|-------|------------|
| `astra_colors.dart` | Amber accent; `dataPositive`/`dataNegative` fixed green/pink; old border hex | Full token refactor per tables above |
| `step_bar_chart.dart` | Bars use `accentPrimaryMuted` | Bars → `dataPositive` |
| `trend_chip.dart` | Up/down use old green/pink data tokens | Up/down → `dataPositive` / `dataNegative` |
| `theme_cubit.dart` | `theme_mode` only | + `accent_preset` |

### Architecture / PRD note on enum rename

PRD/architecture drafts used `cyan` and `purple`. This story standardizes on English **`blue`** and **`magenta`** in code and SQLite going forward, with **parse aliases** for existing rows. Update `AccentPresetSelector` copy in **5.11** to match English display names.

### Preserved behaviors

- `theme_mode` (system/light/dark) from Story 4.7 — independent of preset
- `statusOk` for goal-met — stays `#7CEA89`, not preset green
- Goal ring progress stroke → `accentPrimary`; track → `accentPrimaryMuted`

### Implementation sketch

```dart
// Derived in AstraColors factory for a given preset:
final primary = palette.primary;
final colors = AstraColors(
  accentPrimary: primary,
  accentSecondary: palette.secondary,
  accentPrimaryMuted: primary.withValues(alpha: 0.28),
  dataPositive: primary,
  dataNegative: primary.withValues(alpha: 0.33),
  dataGoalLine: primary.withValues(alpha: 0.35),
  borderPrimary: primary,
  borderDefault: neutralGray, // const Color(0xFFA0A0AA)
  neutralGray: const Color(0xFFA0A0AA),
  // ... surfaces, textPrimary, statusOk, statusDanger
);
```

---

## References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 5.8] (update enum names to blue/magenta when implementing)
- [Source: `lib/core/constants/astra_colors.dart`]
- [Source: `lib/presentation/widgets/step_bar_chart.dart`]
- [Source: `lib/presentation/widgets/trend_chip.dart`]
- [Source: `_bmad-output/implementation-artifacts/stories/5-7-four-tab-floating-navigation.md`]

---

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

### Completion Notes List

- Six accent presets (`orange` default) with locked hex table; legacy DB aliases `cyan`→`blue`, `purple`→`magenta`.
- `AstraColors` refactored: `neutralGray`, `borderPrimary`, preset-derived chart tokens; removed `borderFocus` and amber `#EAD55E`.
- `ThemeCubit` + cold-start `AppDependencies.initialAccentPreset`; `MaterialApp` rebuilds themes on `setAccentPreset`.
- Widgets: primary button + nav inactive on-accent use `accentSecondary`; chart bars use `dataPositive`.
- WCAG: preset on-accent pairs use dark `accentSecondary` companions; `statusOk` stays `#7CEA89` for goal-met (independent of green preset). No preset flagged as failing AA on primary fill + secondary label in manual spot-check.
- `flutter test` — all pass; `flutter analyze` — no errors (pre-existing infos only).

### File List

- lib/core/constants/astra_accent_preset.dart (new)
- lib/core/constants/astra_accent_palette.dart (new)
- lib/core/constants/astra_colors.dart
- lib/core/constants/astra_theme.dart
- lib/core/constants/preference_keys.dart
- lib/core/di/app_dependencies.dart
- lib/data/repositories/user_preferences_repository.dart
- lib/presentation/cubits/theme_cubit.dart
- lib/presentation/cubits/theme_state.dart
- lib/app.dart
- lib/presentation/widgets/astra_button.dart
- lib/presentation/widgets/app_bottom_nav.dart
- lib/presentation/widgets/step_bar_chart.dart
- test/core/constants/astra_accent_presets_test.dart (new)
- test/core/constants/astra_colors_test.dart
- test/presentation/cubits/theme_cubit_test.dart
- test/data/repositories/user_preferences_repository_test.dart
- test/data/repositories/step_repository_purge_test.dart

### Change Log

- 2026-06-04: Story 5.8 — accent preset theme tokens, persistence, and widget wiring.

---

## Story completion status

- **Status:** done
- **Completion note:** Code review follow-ups: goal ring track `bgSubtle`, progress `accentPrimary` 66%/100%; `textSecondary` → `neutralGray`; tests for preset trim, invalid DB value, concurrent ThemeCubit, nav/trend colors.
