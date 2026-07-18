# Story 24.5: Clean Orphan Preference Default Constants

Status: review

<!-- Post-audit Epic 24 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 24-5 · diagnostic-code-mort.md §6 · AUD-38 · audits README nuance -->
<!-- Version bump deferred to Epic 24 close (patch+1, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **developer**,
I want truly orphan preference defaults cleaned without deleting live defaults,
So that dead constants do not confuse future prefs work.

## Acceptance Criteria

1. **Given** `kDefaultDistanceDisplayUnit`, `kDefaultWeightDisplayUnit`, and `kDefaultHeightDisplayUnit` in `preference_keys.dart` are defined but unused (parsers use string literals)
   **When** this story ships
   **Then** `parseDistanceDisplayUnit`, `parseWeightDisplayUnit`, and `parseHeightDisplayUnit` in `display_unit_preferences.dart` reference those constants for default/fallback paths (AUD-38)
   **And** invalid or null raw values still resolve to the same enum defaults as today (`metric`, `kg`, `cm`)

2. **Given** `kDefaultAccentPresetStorage` in `preference_keys.dart` is defined but never imported
   **When** this story ships
   **Then** it is wired in `astra_accent_preset.dart` — used in `parseAccentPreset` for the orange branch and in `accentPresetToStorage(AstraAccentPreset.orange)` (AUD-38)
   **And** `parseAccentPreset` legacy aliases (`cyan`, `purple`) and invalid fallbacks to `kDefaultAccentPreset` remain unchanged

3. **Given** `kDefaultStepGoal` and `kDefaultAccentPreset` are widely used live defaults
   **When** this story ships
   **Then** they are **not** deleted or renamed (README correction — audit false positive)

4. **Given** `DistanceDisplayUnit.displayLabel`, `WeightDisplayUnit.displayLabel`, and `HeightDisplayUnit.displayLabel` are unused in `lib/` (production uses localized labels)
   **When** this story ships
   **Then** the three getters are removed from `display_unit_preferences.dart`
   **And** `unit_option_picker_sheet_test.dart` is updated to use `localizedDistanceUnitPreferenceLabel` (matching `settings_screen.dart` and the semantics tests in the same file)
   **And** the functional picker test taps/selects via localized strings (`l10n.unitDistanceImperial`), not hardcoded `'Imperial'`

5. **Given** verification runs after cleanup
   **When** `dart analyze` and `flutter test --exclude-tags slow` execute
   **Then** both pass with zero regressions
   **And** repo grep under `lib/` finds **zero** `displayLabel` on display-unit enums
   **And** repo grep confirms `kDefaultDistanceDisplayUnit`, `kDefaultWeightDisplayUnit`, `kDefaultHeightDisplayUnit`, and `kDefaultAccentPresetStorage` each have ≥1 reference outside `preference_keys.dart`
   **And** `kDefaultStepGoal` / `kDefaultAccentPreset` remain present and unchanged

**Covers:** AUD-38 · diagnostic-code-mort.md §6 (Moyenne) · audits README §Nuances

**Depends on:** Stories 24-1 through 24-4 done (constants-only; no cubit/schema/DI changes).

**Out of scope:** `AstraTypography.*(BuildContext)` dead wrappers (24-2), chart/nav typography tokens (24-4), PeriodToggle loading gate (24-6), migrating Settings to new label helpers, ARB key additions for unit labels (already done in 19-2), deleting `kDefaultStepGoal` / `kDefaultAccentPreset`, version bump until Epic 24 closes.

## Tasks / Subtasks

- [x] **Sub-task A — Wire orphan default constants into parsers** (AC: #1, #2, #3)
  - [x] Add `import 'preference_keys.dart';` to `display_unit_preferences.dart`
  - [x] In each `parse*` switch: replace literal default cases with `kDefault*DisplayUnit` constant; keep `_` fallback returning same enum as today
  - [x] Add `import 'preference_keys.dart';` to `astra_accent_preset.dart`
  - [x] Wire `kDefaultAccentPresetStorage` in `parseAccentPreset` orange case and `accentPresetToStorage` orange arm
  - [x] Do **not** touch `kDefaultStepGoal`, `kDefaultAccentPreset`, or repository call sites
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Remove dead `displayLabel` getters + fix test** (AC: #4)
  - [x] Delete three `displayLabel` getters from `display_unit_preferences.dart` (keep `storageValue` and all `parse*` helpers)
  - [x] Update `test/presentation/widgets/unit_option_picker_sheet_test.dart` bottom test (`showUnitOptionPickerSheet returns selected distance unit`):
    - Use `AppLocalizations.of(context)` + `localizedDistanceUnitPreferenceLabel(sheetL10n, unit)` for `labelFor`
    - Replace `find.text('Imperial')` with `find.text(l10n.unitDistanceImperial)` (or semantics label — consistent with file's other tests)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests + regression guards** (AC: #5)
  - [x] Add `test/core/constants/display_unit_preferences_test.dart` — assert invalid/null raw → default enums; assert wired constants match `storageValue` of default enum members
  - [x] Extend or verify `test/core/constants/astra_accent_presets_test.dart` still passes (orange default unchanged)
  - [x] Run `flutter test test/presentation/widgets/unit_option_picker_sheet_test.dart`
  - [x] Run `dart analyze` + `flutter test --exclude-tags slow`
  - [x] Grep guards listed in AC #5
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Wire 4 orphan `kDefault*` string constants into parsers | Delete `kDefaultStepGoal` / `kDefaultAccentPreset` |
| Remove 3 unused `displayLabel` enum getters | Add new ARB keys or change visible Settings labels |
| Update one widget test to match production l10n pattern | Repository/schema/migration changes |
| Optional small unit tests for parse defaults | Version bump (Epic 24 close) |
| Constants + tests only | PeriodToggle / loading work (24-6) |

### Root cause (read before editing)

**Audit finding:** Four string constants in `preference_keys.dart` are never referenced; display-unit parsers hardcode `'metric'`, `'kg'`, `'cm'`; accent storage default `'orange'` is duplicated in `astra_accent_preset.dart` instead of using `kDefaultAccentPresetStorage`. Three `displayLabel` getters are dead in production — Settings uses `localized*UnitPreferenceLabel` from ARB [Source: diagnostic-code-mort.md §6, §1 displayLabel rows].

**README nuance:** `kDefaultStepGoal` / `kDefaultAccentPreset` were incorrectly flagged as orphan — **do not delete** [Source: audits/README.md §Partially vrai].

**Story 24-2 explicitly deferred** orphan pref constants and `displayLabel` cleanup to **this story** [Source: 24-2 out-of-scope list].

### Current implementation (UPDATE — read completely before editing)

**Orphan constants (wire, do not delete):**

```5:24:lib/core/constants/preference_keys.dart
const kDefaultAccentPresetStorage = 'orange';
// ...
const kDefaultDistanceDisplayUnit = 'metric';
const kDefaultWeightDisplayUnit = 'kg';
const kDefaultHeightDisplayUnit = 'cm';
```

**Live defaults (preserve untouched):**

```26:27:lib/core/constants/preference_keys.dart
const kDefaultStepGoal = 8000;
```

```11:12:lib/core/constants/astra_accent_preset.dart
const kDefaultAccentPreset = AstraAccentPreset.orange;
```

**Parsers with hardcoded literals (replace with constants):**

```51:73:lib/core/constants/display_unit_preferences.dart
DistanceDisplayUnit parseDistanceDisplayUnit(String? raw) {
  return switch (raw?.trim()) {
    'imperial' => DistanceDisplayUnit.imperial,
    'metric' => DistanceDisplayUnit.metric,
    _ => DistanceDisplayUnit.metric,
  };
}
// parseWeightDisplayUnit: 'kg' / 'lb' — same pattern
// parseHeightDisplayUnit: 'cm' / 'ft_in' — same pattern
```

**Accent parser/storage (wire `kDefaultAccentPresetStorage`):**

```15:37:lib/core/constants/astra_accent_preset.dart
AstraAccentPreset parseAccentPreset(String? raw) {
  // 'orange' => ... and _ => kDefaultAccentPreset
}
String accentPresetToStorage(AstraAccentPreset preset) => switch (preset) {
  AstraAccentPreset.orange => 'orange',
  // ...
};
```

**Dead getters (remove after test fix):**

```10:43:lib/core/constants/display_unit_preferences.dart
  String get displayLabel => switch (this) { ... }; // ×3 enums
```

**Production label path (keep — do not revert to displayLabel):**

```105:109:lib/presentation/screens/settings_screen.dart
  final picked = await showUnitOptionPickerSheet<DistanceDisplayUnit>(
    // ...
    labelFor: (unit) => localizedDistanceUnitPreferenceLabel(l10n, unit),
```

**Only test still using `displayLabel`:**

```149:154:test/presentation/widgets/unit_option_picker_sheet_test.dart
                  result = await showUnitOptionPickerSheet<DistanceDisplayUnit>(
                    // ...
                    labelFor: (unit) => unit.displayLabel,
```

### Recommended approach

| Decision | Rationale |
|----------|-----------|
| **Wire** constants into parsers (preferred over delete) | Single source of truth for SQLite storage defaults; satisfies AUD-38 "remove or use" |
| Import `preference_keys.dart` from constants files | No circular deps — `preference_keys.dart` has no upstream imports |
| Replace `'metric'` case with `kDefaultDistanceDisplayUnit` + keep `_` fallback | Invalid values still default safely; constant gets a real reference |
| Wire accent storage via `kDefaultAccentPresetStorage` | Links string default to `kDefaultAccentPreset` enum default without duplicating magic `'orange'` |
| Remove `displayLabel`, not `storageValue` | `storageValue` is used by repos/settings persistence |
| Align last picker test with l10n helpers | Matches production + semantics tests in same file; no user-visible change |
| No repository edits expected | `user_settings_repository.dart` already calls `parse*` — behavior must stay identical |

### Architecture compliance

- **Core constants only** — no presentation cubit, schema, migration, or DI changes [Source: architecture layering]
- **NFR-AUD-08:** no new hardcoded user-visible strings in `lib/`; test uses existing ARB keys
- **OK commit gate** — one commit per sub-task; wait for Baptiste OK [Source: docs/project-context.md]
- **A11y preserved:** semantics tests in `unit_option_picker_sheet_test.dart` (Story 23-2) must remain green after label helper migration

### File structure requirements

| File | Action |
|------|--------|
| `lib/core/constants/preference_keys.dart` | **NO change** — constants stay; wiring happens at call sites |
| `lib/core/constants/display_unit_preferences.dart` | UPDATE — wire parse defaults; remove `displayLabel` getters |
| `lib/core/constants/astra_accent_preset.dart` | UPDATE — wire `kDefaultAccentPresetStorage` |
| `test/presentation/widgets/unit_option_picker_sheet_test.dart` | UPDATE — last test uses localized labels |
| `test/core/constants/display_unit_preferences_test.dart` | **NEW** — parse default + constant wiring assertions |
| `test/core/constants/astra_accent_presets_test.dart` | VERIFY — existing parse tests still pass |

**No changes expected:** `user_settings_repository.dart`, `settings_screen.dart`, `display_unit_l10n.dart`, cubits, `pubspec.yaml`

### Testing requirements

- Default verify: `flutter test --exclude-tags slow` [Source: project-context.md]
- Targeted:
  - `flutter test test/core/constants/display_unit_preferences_test.dart`
  - `flutter test test/core/constants/astra_accent_presets_test.dart`
  - `flutter test test/presentation/widgets/unit_option_picker_sheet_test.dart`
- New test suggestions:
  - `parseDistanceDisplayUnit(null)` → `DistanceDisplayUnit.metric`
  - `parseDistanceDisplayUnit('bogus')` → `DistanceDisplayUnit.metric`
  - `DistanceDisplayUnit.metric.storageValue == kDefaultDistanceDisplayUnit`
  - Same pattern for weight/height
- Manual smoke (optional): Settings → Distance/Weight/Height unit pickers show same labels; theme accent default unchanged on fresh install

### Previous story intelligence

**From Story 24-4 (done 2026-07-18):**
- Constants-only refactor pattern: wire shared source → remove duplicates → grep guards → full test suite
- 927 tests green with `--exclude-tags slow`
- Sprint tracker: **`sprint-status-post-audit.yaml`**

**From Story 24-2 (done 2026-07-18):**
- Explicitly deferred orphan `kDefault*DisplayUnit` and `displayLabel` to **this story**
- Dead API removal pattern: delete unused surface → grep guard → verify live APIs untouched
- Sub-task OK commit gate with `refactor(design-system):` / `test(design-system):` commit style

**From Story 23-2 (done):**
- `unit_option_picker_sheet_test.dart` semantics tests already use `localizedDistanceUnitPreferenceLabel` — only the bottom functional test still uses `displayLabel`

### Git intelligence summary

Recent commits (Epic 24):
- `279eeff` — close story 24-4 (chart/typography tokens)
- `dcad3b0` / `696c2ad` — story 24-2 dead typography/color token cleanup
- Orphan pref constants and `displayLabel` were **not** touched in 24-1/24-2/24-3/24-4 — clean, focused surface

Commit style: `refactor(constants): …`, `test(constants): …`, `chore(review): …`

### Latest tech information

- **Dart 3 switch patterns:** `var v when v == kDefaultDistanceDisplayUnit` or direct `kDefaultDistanceDisplayUnit =>` case arms are valid
- **No package upgrades** required
- **No Flutter API changes** — enum getter removal is compile-time cleanup only

### Project context reference

- OK commit gate + diff-only delivery: `docs/project-context.md`
- Sprint tracker: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`
- Audit source: `_bmad-output/planning-artifacts/audits/diagnostic-code-mort.md` §6
- Epic source: `_bmad-output/planning-artifacts/epics-post-audit.md` Story 24-5
- Current app version: `0.11.0+25` (`pubspec.yaml`) — do not bump in this story

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-5

### Debug Log References

### Completion Notes List

- Sub-task A: wired kDefaultDistanceDisplayUnit/kDefaultWeightDisplayUnit/kDefaultHeightDisplayUnit into parse* switch cases; wired kDefaultAccentPresetStorage into parseAccentPreset orange arm and accentPresetToStorage orange arm. Zero behavior change.
- Sub-task B: removed 3 dead displayLabel getters (DistanceDisplayUnit, WeightDisplayUnit, HeightDisplayUnit); migrated last picker test from unit.displayLabel/find.text('Imperial') to localizedDistanceUnitPreferenceLabel + l10n.unitDistanceImperial.
- Sub-task C: new display_unit_preferences_test.dart (12 tests); astra_accent_presets_test.dart still green (3 tests); 939 total tests pass; dart analyze clean; grep guards all satisfied.

### File List

- lib/core/constants/display_unit_preferences.dart
- lib/core/constants/astra_accent_preset.dart
- test/presentation/widgets/unit_option_picker_sheet_test.dart
- test/core/constants/display_unit_preferences_test.dart (new)

### Change Log

- 2026-07-18: Story context created — ready-for-dev (create-story workflow)
- 2026-07-18: Implemented all sub-tasks; status → review
