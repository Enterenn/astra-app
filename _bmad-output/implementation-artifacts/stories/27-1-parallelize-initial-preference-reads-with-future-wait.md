# Story 27.1: Parallelize Initial Preference Reads with Future.wait

Status: done

<!-- Post-audit Epic 27 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 27-1 · diagnostic-cold-start.md §Phase D1 · AUD-13 -->
<!-- First story in Epic 27 — epic-27 transitions backlog → in-progress -->
<!-- Prerequisite: Epics 21 (fast path) and 25 (DI/scaffold splits) done -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want app startup to read my saved preferences in parallel,
So that DI creation does not wait on seven sequential SQLite round-trips.

## Acceptance Criteria

1. **Given** `AppDependencies.create` (and `AppDependencies.test` paths that mirror the same reads)
   **When** initial theme, accent, units, onboarding, and locale prefs are loaded
   **Then** the seven reads run via a single `Future.wait` batch instead of seven serial `await`s (AUD-13, diagnostic-cold-start §D1)
   **And** parsed values match prior single-read semantics (same defaults on missing rows)

2. **Given** persisted prefs seeded in SQLite (theme, accent, distance/weight/height units, onboarding, locale)
   **When** `AppDependencies.test` completes
   **Then** `deps.initialTheme`, `initialAccentPreset`, `initialDistanceUnit`, `initialWeightUnit`, `initialHeightUnit`, `initialOnboardingComplete`, and `initialAppLocale` match the seeded values
   **And** defaults apply when rows are absent (see Dev Notes defaults table)

3. **Given** one pref read throws unexpectedly (e.g. DB error mid-batch)
   **When** the batch completes
   **Then** failure behaviour matches or improves on current serial behaviour (`Future.wait` propagates first error — boot fails, no partial/corrupt `AppDependencies`)
   **And** no silent substitution of unrelated pref fields

4. **Given** Epic 21 fast path is in place
   **When** this story ships
   **Then** Today cold-start paint path is unchanged — this optimizes DI only (no `TodayCubit`, `main.dart`, or lifecycle coordinator edits)

5. **Given** unit tests
   **When** story verification runs
   **Then** new/updated tests in `test/core/di/app_dependencies_test.dart` prove seeded initial-pref round-trip through `AppDependencies.test`
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-13 · diagnostic-cold-start.md §Phase D1

**Depends on:** Epics 21 (fast path), 25 (DI layer clean). First story in Epic 27.

**Out of scope:** `main.dart` notification/WorkManager deferral (27-2, 27-3), lazy `HistoryCubit` (27-4), new repository APIs, batch SQL for prefs (each key is a separate row — parallel reads are sufficient), version bump (Epic 27 close → patch+1, build+1).

## Tasks / Subtasks

- [x] **Sub-task A — Extract shared initial-prefs loader** (AC: #1, #3)
  - [x] Read fully: `lib/core/di/app_dependencies.dart` (`create` L93–192, `test` L252–381)
  - [x] Add private static helper (e.g. `_loadInitialUserPreferences`) on `AppDependencies` that accepts `UserSettingsRepository` and returns a record/typedef with all seven parsed values
  - [x] Implement single `Future.wait` for: `getThemeMode`, `getAccentPreset`, `getDistanceDisplayUnit`, `getWeightDisplayUnit`, `getHeightDisplayUnit`, `getOnboardingComplete`, `getAppLocale` — fixed order documented in helper
  - [x] Unpack with explicit casts (same pattern as `TodayCubit` / `HistoryCubit` `Future.wait<Object>` sites)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Wire create() and test() through helper** (AC: #1, #4)
  - [x] Replace serial awaits in `create()` L105–111 with helper call
  - [x] Replace serial awaits in `test()` L282–289 with helper call
  - [x] Preserve test override: when `initialOnboardingComplete` param is non-null, use override value and **do not** call `getOnboardingComplete` (keep current 6-read + override semantics — do not waste a 7th query)
  - [x] No changes to `_buildDependencies`, ingestion wiring, or anything after pref load
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests + regression** (AC: #2, #5)
  - [x] Extend `test/core/di/app_dependencies_test.dart` with group `initial preference batch load`:
    - Seed all seven keys via `UserSettingsRepository` setters / direct inserts
    - Assert `AppDependencies.test` initial* fields match seeded values
    - Optional second case: empty DB → assert defaults (theme system, accent orange, units metric/kg/cm, onboarding false, locale null)
  - [x] Run `flutter test test/core/di/app_dependencies_test.dart --exclude-tags slow`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Parallelize 7 pref reads in `AppDependencies.create` | Defer WorkManager / notification init (`main.dart`) |
| Mirror batch in `AppDependencies.test` (with onboarding override rule) | Lazy `HistoryCubit` (27-4) |
| Private helper extraction in `app_dependencies.dart` | New `UserSettingsRepository` batch API |
| Unit tests for initial pref values on `AppDependencies.test` | Changing Today fast path or coordinator |
| OK-commit sub-task gate | Version bump until Epic 27 close |

### Root cause (read before editing)

**Serial DI gate (AUD-13):** `AppDependencies.create` awaits seven preference reads one after another before building repos/collectors [Source: `app_dependencies.dart` L105–111]. Each read is an independent `user_preferences` row query via `UserPreferencesKvStore.readValue` → `AstraDatabaseSession.withRetry` [Source: `_user_preferences_kv_store.dart` L15–28].

Diagnostic estimate: **50–500 ms** saved on pre-`runApp()` path when combined with D2–D3; D1 alone removes ~6 extra round-trip latencies [Source: `diagnostic-cold-start.md` §Phase D, §C5].

**Epic 21 explicitly deferred** pre-`runApp()` parallelization to Epic 27 [Source: `21-1-fast-path-today-refresh-for-cold-start.md` Out of scope L51].

### Current implementation (MUST preserve semantics)

**Serial reads today — `create()`:**

```105:111:lib/core/di/app_dependencies.dart
    final initialTheme = await userSettings.getThemeMode();
    final initialAccentPreset = await userSettings.getAccentPreset();
    final initialDistanceUnit = await userSettings.getDistanceDisplayUnit();
    final initialWeightUnit = await userSettings.getWeightDisplayUnit();
    final initialHeightUnit = await userSettings.getHeightDisplayUnit();
    final initialOnboardingComplete = await userSettings.getOnboardingComplete();
    final initialAppLocale = await userSettings.getAppLocale();
```

**Same pattern in `test()`** L282–289, except onboarding:

```287:289:lib/core/di/app_dependencies.dart
    final onboardingComplete =
        initialOnboardingComplete ?? await settings.getOnboardingComplete();
    final initialAppLocale = await settings.getAppLocale();
```

**Consumers of initial* fields (do not break):**

| Field | Consumer | Impact |
|-------|----------|--------|
| `initialOnboardingComplete` | `AstraApp` L73 — `_showMainShell` | Onboarding vs main shell routing |
| `initialTheme`, `initialAccentPreset` | `ThemeCubit` providers L127–128 | First-frame theme/accent |
| `initialDistanceUnit`, `initialWeightUnit`, `initialHeightUnit` | `UnitsCubit` L134–136 | Unit formatters |
| `initialAppLocale` | `LocaleCubit` L142 | Locale before async reload |

### Default semantics (missing rows — must not change)

| Read method | Default when null/invalid | Parser |
|-------------|---------------------------|--------|
| `getThemeMode()` | `AstraThemePreference.system` | `parseThemePreference` |
| `getAccentPreset()` | `AstraAccentPreset.orange` | `parseAccentPreset` |
| `getDistanceDisplayUnit()` | `DistanceDisplayUnit.metric` | `parseDistanceDisplayUnit` |
| `getWeightDisplayUnit()` | `WeightDisplayUnit.kg` | `parseWeightDisplayUnit` |
| `getHeightDisplayUnit()` | `HeightDisplayUnit.cm` | `parseHeightDisplayUnit` |
| `getOnboardingComplete()` | `false` | `value == 'true'` |
| `getAppLocale()` | `null` | only `'en'` / `'fr'` accepted |

Existing round-trip tests: `test/data/repositories/user_settings_repository_test.dart` — reuse seed patterns, do not duplicate repository coverage.

### Recommended implementation pattern

Extract helper (names illustrative — match file style):

```dart
typedef _InitialUserPreferences = ({
  AstraThemePreference theme,
  AstraAccentPreset accent,
  DistanceDisplayUnit distanceUnit,
  WeightDisplayUnit weightUnit,
  HeightDisplayUnit heightUnit,
  bool onboardingComplete,
  String? appLocale,
});

static Future<_InitialUserPreferences> _loadInitialUserPreferences(
  UserSettingsRepository settings, {
  bool? onboardingCompleteOverride,
}) async {
  if (onboardingCompleteOverride != null) {
    final results = await Future.wait<Object>([
      settings.getThemeMode(),
      settings.getAccentPreset(),
      settings.getDistanceDisplayUnit(),
      settings.getWeightDisplayUnit(),
      settings.getHeightDisplayUnit(),
      settings.getAppLocale(),
    ]);
    return (
      theme: results[0] as AstraThemePreference,
      accent: results[1] as AstraAccentPreset,
      distanceUnit: results[2] as DistanceDisplayUnit,
      weightUnit: results[3] as WeightDisplayUnit,
      heightUnit: results[4] as HeightDisplayUnit,
      onboardingComplete: onboardingCompleteOverride,
      appLocale: results[5] as String?,
    );
  }
  final results = await Future.wait<Object>([
    settings.getThemeMode(),
    settings.getAccentPreset(),
    settings.getDistanceDisplayUnit(),
    settings.getWeightDisplayUnit(),
    settings.getHeightDisplayUnit(),
    settings.getOnboardingComplete(),
    settings.getAppLocale(),
  ]);
  return (
    theme: results[0] as AstraThemePreference,
    // ... indices 1–6
  );
}
```

**Why two branches:** `test()` allows skipping onboarding read when override supplied — preserve that optimization.

**Concurrency safety:** Reads are independent SELECTs on `user_preferences` by key. `AstraDatabaseSession.withRetry` uses one connection; sqflite serializes writes but concurrent reads on the same open DB are supported. No repository write during DI create. Do **not** add a mutex — parallel reads are the point.

**Error propagation:** Serial code stopped at first thrown error. `Future.wait` fails on first error — equivalent or stricter (no partial field assignment). Do not catch/swallow per-read errors.

### Architecture compliance

- **DI:** Manual composition root — no GetIt/Provider at DI layer [Source: `architecture.md` §DI]
- **Layering:** Change stays in `lib/core/di/` — no presentation imports (Epic 25-3 guard)
- **Repository boundary:** Call existing `UserSettingsRepository` getters only — no new keys, no KV store changes
- **Testing:** Use `AppDependencies.test` + in-memory SQLite via `openAstraDatabase` / `setUpSqfliteFfi` [Source: existing `app_dependencies_test.dart`]

### File structure requirements

| File | Action |
|------|--------|
| `lib/core/di/app_dependencies.dart` | **UPDATE** — helper + wire create/test |
| `test/core/di/app_dependencies_test.dart` | **UPDATE** — initial pref batch tests |
| `lib/main.dart` | **DO NOT TOUCH** (27-2/27-3) |
| `lib/presentation/**` | **DO NOT TOUCH** |
| `lib/data/repositories/user_settings_repository.dart` | **DO NOT TOUCH** unless bug found |

### Testing requirements

- Default gate: `flutter test --exclude-tags slow`
- Targeted: `flutter test test/core/di/app_dependencies_test.dart --exclude-tags slow`
- No slow-tagged files affected
- OK-commit gate per `docs/project-context.md` — one commit per sub-task A/B/C

### Cross-story context (Epic 27)

| Story | Scope | Interaction |
|-------|-------|-------------|
| **27-1 (this)** | Parallel pref reads in DI | Independent — ship first |
| 27-2 | WorkManager after `runApp` | Touches `main.dart` only |
| 27-3 | Non-blocking notification init | Touches `main.dart` + maybe `NotificationService` |
| 27-4 | Lazy `HistoryCubit` | Touches `app_scaffold.dart` |

Complete D1–D3 for full pre-`runApp()` polish [Source: diagnostic-cold-start §Priorisation item 6].

### Git intelligence (recent patterns)

Recent Epic 26 close at `0.11.3+28`:
- Test-only stories extended existing files (`live_step_monitor_test.dart`) rather than new harnesses
- Sub-task OK-commit gate enforced per story
- Sprint tracker updates in `sprint-status-post-audit.yaml`

Apply same: minimal diff in one production file + targeted test extension.

### Latest tech notes

- **Dart `Future.wait`:** Standard library; no package bump. Typed `Future.wait<Object>` + casts matches project convention (`today_refresh_service.dart`, `history_cubit.dart`).
- **Records:** Dart 3 records for return type are OK if project already uses them elsewhere; typedef on record is fine in private static helper.
- **sqflite:** Concurrent read queries on one connection — no API change needed for D1.

### Project context reference

- OK-commit gate: `docs/project-context.md` §Development Workflow
- Version bump deferred to Epic 27 close: patch+1, build+1 — `.cursor/rules/app-versioning.mdc`
- Test command: `flutter test --exclude-tags slow`

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` §Story 27-1]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-cold-start.md` §Phase D1, §C5]
- [Source: `_bmad-output/planning-artifacts/audits/README.md` §Ouvert E27]
- [Source: `lib/core/di/app_dependencies.dart`]
- [Source: `lib/data/repositories/user_settings_repository.dart`]
- [Source: `lib/app.dart` — initial* consumers]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- `_loadInitialUserPreferences` batches 7 pref reads via `Future.wait` in `create()` and `test()` (6 when onboarding override set).
- Added 3 unit tests: seeded round-trip, empty DB defaults, onboarding override.

### File List

- `lib/core/di/app_dependencies.dart`
- `test/core/di/app_dependencies_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` — status review → done

## Change Log

- 2026-07-19: Story context created — AUD-13 parallel pref reads (ready-for-dev).
- 2026-07-19: Implemented `_loadInitialUserPreferences` Future.wait batch + 3 unit tests.
- 2026-07-19: Code review passed — mark 27-1 done (AUD-13).
