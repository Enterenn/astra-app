# Story 25.3: Remove Presentation Dependency from Core DI Layer

Status: done

<!-- Post-audit Epic 25 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 25-3 · diagnostic-convention-structure.md §1.3 · AUD-46 -->
<!-- Prerequisite: Stories 25-1, 25-2 done; Epic 26 not required first -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **developer**,
I want `core/di` free of `presentation/` imports,
So that dependency direction stays Clean Architecture–compliant.

## Acceptance Criteria

1. **Given** `lib/core/di/app_dependencies.dart` line 19 imports `../../presentation/cubits/theme_state.dart` for `AstraThemePreference`
   **When** this story ships
   **Then** `app_dependencies.dart` has **zero** imports from `lib/presentation/` (AUD-46)
   **And** `AstraThemePreference` lives in `lib/core/constants/` (same layer as `AstraAccentPreset`, `DisplayUnitPreferences`)
   **And** `ThemeState` (Flutter `ThemeMode` mapping) remains in `presentation/cubits/theme_state.dart`

2. **Given** cold-start DI loads persisted theme before first frame
   **When** `AppDependencies.create()` / `AppDependencies.test()` run
   **Then** `initialTheme` is still populated via `userSettings.getThemeMode()` with identical enum values (`system`, `light`, `dark`)
   **And** `AstraApp` still passes `widget.deps.initialTheme` into `ThemeCubit(initialPreference: …)` unchanged
   **And** Settings theme selector, persistence round-trip, and dark/light/system behaviour are user-invisible (no UX regression)

3. **Given** data layer currently imports presentation for the same enum (`user_settings_repository.dart`, `user_settings_repository_contract.dart`)
   **When** enum moves to core
   **Then** those data files import `core/constants/astra_theme_preference.dart` instead of `presentation/cubits/theme_state.dart`
   **And** DB string mapping (`'light'` / `'dark'` / `'system'`) is unchanged — reuse or centralize parse/encode helpers in the new core file (mirror `parseAccentPreset` / `accentPresetToStorage` pattern)

4. **Given** existing test suites
   **When** `dart analyze` and `flutter test --exclude-tags slow` run
   **Then** all pass with zero behavioural regressions
   **And** targeted suites green:
   - `flutter test test/core/di/app_dependencies_test.dart`
   - `flutter test test/data/repositories/user_settings_repository_test.dart`
   - `flutter test test/presentation/cubits/theme_cubit_test.dart test/presentation/widgets/theme_selector_test.dart test/presentation/screens/settings_screen_test.dart`
   - `flutter test test/widget_test.dart` (boot + persisted dark theme)

5. **Given** OK-commit gate per `docs/project-context.md`
   **When** implementing
   **Then** work is split into reviewable sub-tasks (extract type → rewire imports → verify) with one commit per sub-task after Baptiste approval
   **And** no version bump until Epic 25 closes

**Covers:** AUD-46 · diagnostic-convention-structure.md §1.3 (Haute / Architecture)

**Depends on:** Stories 25-1, 25-2 **done**. Independent of 25-4 (MyDataCubit dialog decoupling) and 25-5 (doc comments).

**Out of scope:** Moving `ThemeState` class out of presentation, changing theme UX, MyDataCubit / FilePicker / `PurgeConfirmAction` (25-4), `AppLifecycleCoordinator` → cubit coupling (separate audit item §3.1), adding layer-violation CI lint, version bump, Epic 26 test authoring.

## Tasks / Subtasks

- [x] **Sub-task A — Baseline & move plan** (AC: #1, #3)
  - [x] Confirm sole presentation import in `lib/core/di/`: `app_dependencies.dart:19` → `theme_state.dart`
  - [x] Grep `AstraThemePreference` and `theme_state.dart` across `lib/` and `test/` — inventory all import sites (see Dev Notes table)
  - [x] Read `lib/core/constants/astra_accent_preset.dart` as the canonical pattern for persisted preference enums in core
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (plan-only commit optional; otherwise proceed to B after brief)

- [x] **Sub-task B — Extract `AstraThemePreference` to core** (AC: #1, #2, #3)
  - [x] Create `lib/core/constants/astra_theme_preference.dart`:
    - `enum AstraThemePreference { system, light, dark }`
    - `const kDefaultThemePreference = AstraThemePreference.system`
    - `AstraThemePreference parseThemePreference(String? raw)` — same switch as `_parseThemeMode` today
    - `String themePreferenceToStorage(AstraThemePreference preference)` — inverse of encode switch
  - [x] Update `lib/presentation/cubits/theme_state.dart`: remove enum definition; import from core; keep `ThemeState` + `materialThemeMode` getter (needs `package:flutter/material.dart`)
  - [x] Optional backward compat: `export` the enum from `theme_state.dart` so presentation widgets that import `theme_state.dart` need zero edits — **prefer this** to minimize diff noise
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Rewire core/di and data imports** (AC: #1, #2, #3)
  - [x] `lib/core/di/app_dependencies.dart`: replace presentation import with `../constants/astra_theme_preference.dart`
  - [x] `lib/data/repositories/user_settings_repository.dart`: import core enum; delegate `_parseThemeMode` / encode switch to shared helpers (delete duplicate private parser if fully replaced)
  - [x] `lib/data/contracts/user_settings_repository_contract.dart`: import core enum instead of presentation
  - [x] Verify `grep presentation lib/core/di` returns **empty**
  - [x] Verify `grep presentation lib/data` returns **empty** for theme_state (only expected presentation imports elsewhere if any — flag if new violations found)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Regression verification** (AC: #4, #5)
  - [x] Run `dart analyze`
  - [x] Run targeted tests listed in AC #4
  - [x] Run `flutter test --exclude-tags slow` (expect ~947+ passing — same bar as 25-1/25-2)
  - [x] Manual smoke (optional): cold start with persisted dark theme → GoalRing visible with dark tokens
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Remove `presentation/` import from `core/di/app_dependencies.dart` | MyDataCubit / `confirm_dialog.dart` (25-4) |
| Move `AstraThemePreference` enum to `core/constants/` | Move `ThemeState` to core (needs Flutter) |
| Fix data-layer imports that exist only because enum lived in presentation | Lifecycle coordinator cubit references |
| Mechanical import rewires + shared parse/encode helpers | New architecture lint rule |
| OK-commit sub-task gate | Version bump (Epic 25 close) |

### Root cause (read before editing)

**Layer violation:** `AppDependencies` (composition root in `core/di/`) imports `presentation/cubits/theme_state.dart` solely for `AstraThemePreference` on `initialTheme` field [Source: diagnostic-convention-structure.md §1.3 L61, Synthèse Haute L187].

**Why it happened:** Story 1-2 placed `enum AstraThemePreference` in `theme_state.dart` alongside `ThemeState` before persistence existed. Story 1-4 wired repository + DI to the enum without relocating it. `AstraAccentPreset` was later added correctly in `core/constants/` (Story 5-8) — theme enum was never migrated [Source: 1-2, 1-4, 5-8].

**Secondary leak (fix opportunistically in same story):** `UserSettingsRepository` and `UserSettingsRepositoryContract` also import `presentation/cubits/theme_state.dart`. Moving the enum to core fixes both without expanding scope beyond "moved types" [Source: user_settings_repository.dart L8, user_settings_repository_contract.dart L3].

### Current state — files to read fully before editing

**`lib/core/di/app_dependencies.dart`** (378 LOC):
- **Today:** Line 19 `import '../../presentation/cubits/theme_state.dart'`; fields `initialTheme: AstraThemePreference` (L63); loaded in `create()` L101 and `test()` L278; passed through `_buildDependencies`.
- **Change:** Import path only + ensure type resolves from core.
- **Preserve:** All other deps wiring, `AppLifecycleCoordinator` lazy init, test factory defaults — **no behavioural edits**.

**`lib/presentation/cubits/theme_state.dart`** (21 LOC):
- **Today:** Defines enum + `ThemeState` with `materialThemeMode` → `ThemeMode` mapping.
- **Change:** Enum moves out; file keeps presentation-only `ThemeState`.
- **Preserve:** `ThemeState` defaults, switch mapping, public API for `ThemeCubit` / `BlocBuilder`.

**`lib/data/repositories/user_settings_repository.dart`**:
- **Today:** `_parseThemeMode` private switch (L292–295); encode in `setThemeMode` (L47–50).
- **Change:** Use `parseThemePreference` / `themePreferenceToStorage` from core.
- **Preserve:** KV key `kThemeModeKey`, default `system` when absent/invalid.

**`lib/app.dart`** (L125–128):
- **Today:** `ThemeCubit(initialPreference: widget.deps.initialTheme, …)` — **no signature change expected**.

### Import inventory (`AstraThemePreference` / `theme_state.dart`)

| File | Action |
|------|--------|
| `lib/core/di/app_dependencies.dart` | **UPDATE** → core import |
| `lib/data/repositories/user_settings_repository.dart` | **UPDATE** → core import |
| `lib/data/contracts/user_settings_repository_contract.dart` | **UPDATE** → core import |
| `lib/presentation/cubits/theme_state.dart` | **UPDATE** — enum out, optional re-export |
| `lib/presentation/cubits/theme_cubit.dart` | No change if re-export kept |
| `lib/presentation/widgets/theme_selector.dart` | No change if re-export kept |
| `lib/presentation/screens/settings_screen.dart` | No change if re-export kept |
| `lib/app.dart` | No change (imports theme_state for ThemeState/ThemeCubit) |
| `test/data/repositories/user_settings_repository_test.dart` | **UPDATE** → core import (cleaner) |
| `test/helpers/coordinator_unit_test_deps.dart` | **UPDATE** → core import |
| Other tests importing `theme_state.dart` | Optional update; pass if re-export retained |

### Recommended implementation (follow `AstraAccentPreset` precedent)

```dart
// lib/core/constants/astra_theme_preference.dart
enum AstraThemePreference { system, light, dark }

const kDefaultThemePreference = AstraThemePreference.system;

AstraThemePreference parseThemePreference(String? raw) => switch (raw) {
  'light' => AstraThemePreference.light,
  'dark' => AstraThemePreference.dark,
  _ => kDefaultThemePreference,
};

String themePreferenceToStorage(AstraThemePreference preference) =>
    switch (preference) {
      AstraThemePreference.light => 'light',
      AstraThemePreference.dark => 'dark',
      AstraThemePreference.system => 'system',
    };
```

```dart
// lib/presentation/cubits/theme_state.dart (after)
import 'package:flutter/material.dart';
import '../../core/constants/astra_accent_preset.dart';
import '../../core/constants/astra_theme_preference.dart';

export '../../core/constants/astra_theme_preference.dart';

class ThemeState { /* unchanged except enum removed */ }
```

**Do not** add `ThemeMode` conversion to core — that stays presentation-only (`ThemeState.materialThemeMode`).

### Architecture compliance

| Rule | Source | This story |
|------|--------|------------|
| `core/` must not import `presentation/` | epics-post-audit.md AUD-46, architecture D-22 | Primary goal |
| Pragmatic 3-layer (core / data / presentation) | architecture.md L112, L229 | Enum belongs in core constants |
| `AppDependencies` = composition root | architecture.md L610 | Stays in `core/di/` |
| Repository typed prefs API | architecture.md FR-31 | Unchanged signatures |
| OK-commit gate, one commit per sub-task | docs/project-context.md | Mandatory |

**Layer table** (architecture.md L823–826): `presentation/` may call repositories; `core/di` wires concrete implementations — must not depend upward on presentation.

### File structure requirements

| Path | Action |
|------|--------|
| `lib/core/constants/astra_theme_preference.dart` | **NEW** |
| `lib/core/di/app_dependencies.dart` | **UPDATE** — import core only |
| `lib/presentation/cubits/theme_state.dart` | **UPDATE** — enum out, optional export |
| `lib/data/repositories/user_settings_repository.dart` | **UPDATE** — core import + shared helpers |
| `lib/data/contracts/user_settings_repository_contract.dart` | **UPDATE** — core import |
| `lib/app.dart` | **NO** functional change |
| `lib/presentation/cubits/theme_cubit.dart` | **NO** change if re-export |
| `test/core/di/app_dependencies_test.dart` | **NO** change expected (doesn't assert theme type today) |

### Testing requirements

| Command | When |
|---------|------|
| `dart analyze` | Every sub-task |
| `flutter test test/core/di/app_dependencies_test.dart test/data/repositories/user_settings_repository_test.dart` | Sub-task C |
| `flutter test test/presentation/cubits/theme_cubit_test.dart test/presentation/widgets/theme_selector_test.dart` | Sub-task D |
| `flutter test test/widget_test.dart` | Sub-task D — boot with persisted dark theme |
| `flutter test --exclude-tags slow` | Final verification |

**Verification grep (manual):**
```bash
rg "presentation/" lib/core/di/
# expect: no matches

rg "theme_state.dart" lib/core/ lib/data/
# expect: no matches after Sub-task C
```

No new tests strictly required if full suite passes — behaviour is import-path only. Optional: add a one-line `app_dependencies_test` asserting `deps.initialTheme` round-trips from repository (low value — covered by widget + repository tests).

### Previous story intelligence (25-2, 25-1)

- **Mechanical-first:** Extract/move types verbatim; no algorithm changes during import rewires (25-1, 25-2 pattern).
- **Precedent for core constants:** `AstraAccentPreset` + `parseAccentPreset` / `accentPresetToStorage` already used by `AppDependencies.initialAccentPreset` without presentation import — **mirror exactly for theme**.
- **Regression bar:** 947/947 tests green after 25-2; run full `--exclude-tags slow` before final OK commit.
- **25-2 left `AppDependencies` untouched** — this story is the first Epic 25 edit to `app_dependencies.dart`; keep coordinator wiring identical.
- **Code review pattern:** Document import inventory in story dev notes; split into ≤4 sub-tasks with OK-commit gate.

### Git intelligence (recent work)

Recent commits (25-2): lifecycle coordinator split into `lib/core/services/lifecycle/` — no DI changes. Safe to edit `app_dependencies.dart` in isolation. Last theme-related story: 22-4 (error feedback alignment) — `ThemeCubit.setThemePreference` rollback semantics must remain untouched.

### Latest tech information

- **No new packages** — pure refactor / file move.
- **flutter_bloc ^8.x:** `ThemeCubit` / `ThemeState` unchanged.
- **Flutter `ThemeMode`:** Stays in presentation layer only; core enum has zero Flutter dependency.
- **Dart 3.x:** `switch` expressions for parse/encode — match existing accent preset style.

### Project context reference

- OK-commit gate: `docs/project-context.md`
- Test default: `flutter test --exclude-tags slow`
- Version bump: Epic 25 close only (`patch+1`, `build+1`) — update `pubspec.yaml` + `README.md` then, not in this story
- Tracker: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`

### References

- [Source: _bmad-output/planning-artifacts/epics-post-audit.md#Story 25-3]
- [Source: _bmad-output/planning-artifacts/audits/diagnostic-convention-structure.md §1.3 L59–63, Synthèse Haute L187]
- [Source: lib/core/di/app_dependencies.dart L19, L63, L101]
- [Source: lib/core/constants/astra_accent_preset.dart — enum + parse/encode pattern]
- [Source: lib/presentation/cubits/theme_state.dart — enum + ThemeState]
- [Source: lib/data/repositories/user_settings_repository.dart — persistence mapping]
- [Source: lib/app.dart L125–128 — ThemeCubit bootstrap]
- [Source: _bmad-output/implementation-artifacts/stories/25-2-split-app-lifecycle-coordinator-into-focused-services.md]
- [Source: _bmad-output/planning-artifacts/architecture.md — D-22 layering, AppDependencies L610]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

### Completion Notes List

- Sub-task A: Baseline confirmed — sole `presentation/` import in `core/di/` is `app_dependencies.dart:19`. Data layer also leaks via `user_settings_repository*.dart`. Plan mirrors `astra_accent_preset.dart` pattern; re-export from `theme_state.dart` to minimize presentation diff.
- Sub-task B: Created `astra_theme_preference.dart` with enum + parse/encode helpers; `theme_state.dart` re-exports from core.
- Sub-task C: Rewired `app_dependencies.dart`, `user_settings_repository.dart`, contract + 2 test helpers to core import; `grep presentation lib/core/di` and `theme_state lib/data` both empty.
- Sub-task D: `dart analyze` clean (warnings pre-existing only); 947/947 tests green (`--exclude-tags slow`, 2 skipped).

Code review: approved — clean mechanical refactor; no behavioral regressions. Optional follow-up: dedicated `astra_theme_preference_test.dart` for parse/encode parity with accent preset.

### File List

- lib/core/constants/astra_theme_preference.dart (NEW)
- lib/presentation/cubits/theme_state.dart (UPDATE)
- lib/core/di/app_dependencies.dart (UPDATE)
- lib/data/repositories/user_settings_repository.dart (UPDATE)
- lib/data/contracts/user_settings_repository_contract.dart (UPDATE)
- test/data/repositories/user_settings_repository_test.dart (UPDATE)
- test/helpers/coordinator_unit_test_deps.dart (UPDATE)

### Change Log

- 2026-07-19: Moved `AstraThemePreference` to core; removed presentation dependency from `core/di` and data layer (AUD-46).
- 2026-07-19: Code review passed; story → done.
