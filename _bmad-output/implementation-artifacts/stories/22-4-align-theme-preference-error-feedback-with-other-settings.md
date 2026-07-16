# Story 22.4: Align Theme Preference Error Feedback with Other Settings

Status: review

<!-- Post-audit Epic 22 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 22-4 · diagnostic-gestion-etat-erreur.md Synthèse #4 · AUD-19 -->
<!-- Prerequisite: Story 22-3 — done -->
<!-- Version bump: deferred to Epic 22 close (patch+1, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want theme/accent save failures to show the same feedback as locale/units failures,
So that preference errors are never silent only for theme.

## Acceptance Criteria

1. **Given** `ThemeCubit` persist fails
   **When** user changes theme mode or accent on Settings
   **Then** UI shows SnackBar consistent with locale/units/notification preference failures (AUD-19)
   **And** `ThemeCubit` catches persist errors and returns `false` (mirror `LocaleCubit` / `UnitsCubit`)

2. **Given** persist succeeds
   **When** preference changes
   **Then** no error feedback is shown
   **And** theme/accent state and DB remain in sync (existing behaviour)

3. **Given** persist fails
   **When** user retries the same change
   **Then** cubit state stays on the last successful value (no optimistic emit)
   **And** SnackBar can appear again on repeated failure

4. **Given** existing `theme_cubit_test.dart` and `settings_screen_test.dart`
   **When** this story ships
   **Then** cubit tests cover failed theme-mode and accent writes
   **And** widget tests cover SnackBar on theme-mode and accent persist failure
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-19 · diagnostic-gestion-etat-erreur.md Synthèse #4 (ThemeCubit sans catch ni feedback) · diagnostic-gestion-etat-erreur.md §2 Settings ThemeCubit rows

**Depends on:** Story 22-3 — **done** · `LocaleCubit` / `UnitsCubit` `Future<bool>` + SnackBar pattern — **already established**

**Out of scope:** Enable `discarded_futures` lint (Story 22-5 / AUD-20), Profile screen theme UI (removed in 10-4), version bump until Epic 22 closes, new error-state enum on `ThemeState`, optimistic UI rollback beyond "don't emit on failure".

## Tasks / Subtasks

- [x] **Sub-task A — ThemeCubit bool contract + catch** (AC: #1, #2, #3)
  - [x] Read fully: `theme_cubit.dart`, `locale_cubit.dart`, `units_cubit.dart` — mirror `_setInFlight` + `Future<bool>` pattern
  - [x] Change `setThemePreference` / `setAccentPreset` to `Future<bool>`
  - [x] Wrap `userSettings.setThemeMode` / `setAccentPreset` in `try/catch (_) { return false; }` inside `_persistThemeAndEmit` / `_persistAccentAndEmit`
  - [x] Return `true` only after successful persist + emit; `false` on catch, early exit, or unchanged value (match Locale/Units no-op semantics)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Settings SnackBar wiring + l10n** (AC: #1, #2)
  - [x] Add `settingsThemeUpdateError` to `app_en.arb` + `app_fr.arb` with `@settingsThemeUpdateError` metadata in **both** files (ARB parity per 22-3 review)
    - EN: `"Could not update theme preference"`
    - FR: `"Impossible de mettre à jour le thème"`
  - [x] Run `flutter gen-l10n`
  - [x] Add `_setThemePreference` / `_setAccentPreset` helpers in `settings_screen.dart` (mirror `_pickLanguage` / notification switch pattern):
    - `final saved = await themeCubit.setThemePreference(...)` / `setAccentPreset(...)`
    - `if (!saved && context.mounted) { ScaffoldMessenger... SnackBar(l10n.settingsThemeUpdateError) }`
  - [x] Wire `ThemeSelector.onChanged` and `AccentPresetSelector.onSelected` through helpers; use `unawaited(...)` at call site until Story 22-5
  - [x] **Do not** add SnackBar inside `ThemeCubit` — screen-level feedback only (project convention)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests** (AC: #4)
  - [x] `theme_cubit_test.dart`: add `_ThrowingThemeModeSettingsRepository` / `_ThrowingAccentSettingsRepository` stubs (pattern from `units_cubit_test.dart` L11–17)
    - Failed theme write → `setThemePreference` returns `false`, state unchanged, DB unchanged
    - Failed accent write → `setAccentPreset` returns `false`, state unchanged
  - [x] `settings_screen_test.dart`: add throwing-repo harness + widget tests
    - Tap theme segment (e.g. Dark) → expect `settingsThemeUpdateError` SnackBar, `ThemeCubit` state still initial
    - Tap accent chip → same SnackBar assertion
  - [x] Run: `flutter test test/presentation/cubits/theme_cubit_test.dart`
  - [x] Run: `flutter test test/presentation/screens/settings_screen_test.dart`
  - [x] Run: `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| `ThemeCubit` `Future<bool>` + catch on persist | `discarded_futures` lint enablement (22-5) |
| Settings SnackBar on theme/accent failure | Profile / My Data theme entry points (none exist) |
| `settingsThemeUpdateError` l10n key | Separate keys for mode vs accent (one message is enough — matches units pattern) |
| Cubit + widget tests for failure path | `debugPrint` logging in catch (Locale/Units omit it) |

### Root cause (read before editing)

**ThemeCubit is the only preference cubit without error containment:**

Diagnostic §1: `ThemeCubit` — pas d'état erreur, **pas de try/catch**, exception propagée à l'appelant [Source: diagnostic-gestion-etat-erreur.md L40].

Diagnostic §2: Settings `BlocBuilder` ×2 for ThemeCubit — aucune récupération UI [Source: diagnostic-gestion-etat-erreur.md L57].

Synthèse #4: ThemeCubit — seul cubit de préférences sans catch ni feedback UI [Source: diagnostic-gestion-etat-erreur.md L167].

**Contrast — working pattern in same screen:**

```88:93:lib/presentation/screens/settings_screen.dart
  final saved = await localeCubit.setLanguagePreference(preference);
  if (!saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsLanguageUpdateError)),
    );
  }
```

Notification switch uses identical `saved == false` → SnackBar (`settingsNotificationUpdateError`).

**Current gap — fire-and-forget, no feedback:**

```302:320:lib/presentation/screens/settings_screen.dart
                BlocBuilder<ThemeCubit, ThemeState>(
                  builder: (context, themeState) {
                    return ThemeSelector(
                      selected: themeState.preference,
                      onChanged: (preference) => context
                          .read<ThemeCubit>()
                          .setThemePreference(preference),
                    );
                  },
                ),
                // ...
                BlocBuilder<ThemeCubit, ThemeState>(
                  builder: (context, themeState) {
                    return AccentPresetSelector(
                      selected: themeState.accentPreset,
                      onSelected: (preset) => context
                          .read<ThemeCubit>()
                          .setAccentPreset(preset),
                    );
                  },
                ),
```

**ThemeCubit today — uncaught persist:**

```59:74:lib/presentation/cubits/theme_cubit.dart
  Future<void> _persistThemeAndEmit(
    AstraThemePreference preference,
    Future<void>? waitFor,
  ) async {
    // ...
    await userSettings.setThemeMode(preference);  // throws → unhandled
    // ...
    emit(ThemeState(preference: preference, accentPreset: state.accentPreset));
  }
```

### Target implementation (guidance)

**Mirror LocaleCubit contract exactly** — do not invent a new error model:

```20:40:lib/presentation/cubits/locale_cubit.dart
  Future<bool> setLanguagePreference(String? languageCode) async {
    if (state.explicitLanguageCode == languageCode) {
      return false;
    }
    // _setInFlight chain...
    var success = false;
    operation = () async {
      success = await _persistLanguagePreferenceAndEmit(languageCode, waitFor);
    }();
    // ...
    return success;
  }
```

**ThemeCubit sketch (persist helper):**

```dart
Future<bool> _persistThemeAndEmit(...) async {
  // waitFor + isClosed guards unchanged
  try {
    await userSettings.setThemeMode(preference);
  } catch (_) {
    return false;
  }
  if (isClosed || state.preference == preference) {
    return false;
  }
  emit(ThemeState(preference: preference, accentPreset: state.accentPreset));
  return true;
}
```

Apply same structure to `_persistAccentAndEmit`.

**Settings helper sketch:**

```dart
Future<void> _setThemePreference(
  BuildContext context, {
  required AstraThemePreference preference,
}) async {
  final l10n = AppLocalizations.of(context);
  final saved = await context.read<ThemeCubit>().setThemePreference(preference);
  if (!saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsThemeUpdateError)),
    );
  }
}
```

Wire: `onChanged: (p) => unawaited(_setThemePreference(context, preference: p))`

**Single l10n key** for both mode and accent failures — aligns with `settingsUnitPreferenceUpdateError` reused across distance/weight/height.

### Regression cautions

| Risk | Mitigation |
|------|------------|
| Callers expect `Future<void>` from ThemeCubit | Grep shows only `settings_screen.dart` — no other production callers |
| `theme_cubit_test.dart` awaits void return | Update tests to assert `isTrue`/`isFalse` where applicable |
| Rapid concurrent theme+accent changes | Existing `_setInFlight` serialization preserved — failure tests should not break rapid-change tests |
| Optimistic emit on failure | Never emit before successful persist (current order is correct — keep it) |
| ARB parity | Include `@settingsThemeUpdateError` in **both** EN and FR arb files (22-3 review finding) |
| Widget tap targets | `ThemeSelector` uses `AstraSegmentedControl` — tap segment label text; accent uses `_AccentChip` GestureDetector — use `find.text` / `find.byType` patterns from existing settings tests |

### Architecture compliance

- **Preference error pattern:** `Future<bool>` cubit + screen SnackBar — no `BlocConsumer`, no error enum on cubit state [Source: diagnostic-gestion-etat-erreur.md §2, Synthèse #3].
- **Cubit boundary:** `ThemeCubit` swallows exceptions; UI owns feedback — same as Locale/Units/Profile notification.
- **Repository sole writer:** Still via `userSettings.setThemeMode` / `setAccentPreset` only.
- **OK-commit gate:** One commit per sub-task [Source: docs/project-context.md].

### Project structure notes

| Path | Role |
|------|------|
| `lib/presentation/cubits/theme_cubit.dart` | **UPDATE** — `Future<bool>`, try/catch in persist helpers |
| `lib/presentation/screens/settings_screen.dart` | **UPDATE** — helpers + SnackBar wiring |
| `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb` | **UPDATE** — `settingsThemeUpdateError` |
| `test/presentation/cubits/theme_cubit_test.dart` | **UPDATE** — failure-path cubit tests |
| `test/presentation/screens/settings_screen_test.dart` | **UPDATE** — SnackBar widget tests |
| `lib/presentation/cubits/locale_cubit.dart` | **READ** — bool contract reference |
| `lib/presentation/cubits/units_cubit.dart` | **READ** — catch pattern reference |
| `test/presentation/cubits/units_cubit_test.dart` | **READ** — `_ThrowingDistanceSettingsRepository` stub pattern |

### Testing requirements

- **Primary:** `flutter test test/presentation/cubits/theme_cubit_test.dart`
- **Primary:** `flutter test test/presentation/screens/settings_screen_test.dart`
- **Full:** `flutter test --exclude-tags slow`

**Cubit failure stub (from units_cubit_test):**

```dart
class _ThrowingThemeModeSettingsRepository extends UserSettingsRepository {
  _ThrowingThemeModeSettingsRepository(Database super.db);
  @override
  Future<void> setThemeMode(AstraThemePreference preference) async {
    throw StateError('write failed');
  }
}
```

**Widget test flow (theme mode):**

1. Seed `ThemeCubit` with `_ThrowingThemeModeSettingsRepository`, initial `light`
2. Pump Settings with ready ProfileCubit
3. Tap `Dark` segment in `ThemeSelector`
4. `await tester.pumpAndSettle()`
5. Expect `find.text('Could not update theme preference')` (use l10n string from test locale)
6. Expect `themeCubit.state.preference` still `light`

Repeat for accent with `_ThrowingAccentSettingsRepository` + tap non-selected preset chip.

### Previous story intelligence (22-3)

- **Tracker:** Use `sprint-status-post-audit.yaml`, not legacy `sprint-status.yaml`.
- **ARB parity:** `@key` metadata required in both EN and FR arb files.
- **unawaited:** Use at UI callback sites until 22-5 enables lint.
- **Test harness:** `_SeededProfileCubit` pattern in settings tests — reuse for theme failure tests.
- **Commit pattern:** `fix(settings-ui):` or `fix(robustness):` prefix; sub-task OK-commit gate.
- **22-3 done:** Profile/Settings load retry — unrelated; do not regress `ProfileLoadErrorPanel`.

### Git intelligence

Recent commits:
- `3df9e1e` — `chore(review): close story 22-3 - fix ARB metadata parity...`
- `760faa7` — `test(profile-ui): add retry widget tests...`
- `aec4aa2` — `fix(profile-ui): add shared ProfileLoadErrorPanel...`

Pattern: cubit contract change + screen wiring + focused tests; story reference in commit message.

### Latest tech notes

- **Flutter 3.x / flutter_bloc ^9.1.1** — no API changes needed; `Future<bool>` return is backward-compatible at call sites that `await`.
- **`unawaited` from `dart:async`** — required at `onChanged` / `onSelected` callbacks until Story 22-5.
- **No new packages.**

### Project context reference

- OK-commit gate: sub-task → review brief → Baptiste OK → commit
- Tests: `flutter test --exclude-tags slow`
- Commit example: `fix(settings-ui): add SnackBar on theme preference persist failure (story 22-4)`
- Version bump: Epic 22 close only (`patch+1, build+1`)

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` — Story 22-4, AUD-19, Epic 22]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-gestion-etat-erreur.md` — §1 ThemeCubit, §2 Settings, Synthèse #4]
- [Source: `_bmad-output/implementation-artifacts/stories/22-3-add-retry-path-for-profile-and-settings-load-errors.md` — epic patterns, ARB parity, test harness]
- [Source: `lib/presentation/cubits/theme_cubit.dart`]
- [Source: `lib/presentation/cubits/locale_cubit.dart`]
- [Source: `lib/presentation/cubits/units_cubit.dart`]
- [Source: `lib/presentation/screens/settings_screen.dart`]
- [Source: `test/presentation/cubits/units_cubit_test.dart`]
- [Source: `test/presentation/cubits/theme_cubit_test.dart`]
- [Source: `docs/project-context.md`]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

- Sub-task A: `ThemeCubit.setThemePreference` / `setAccentPreset` → `Future<bool>`; `_persistThemeAndEmit` / `_persistAccentAndEmit` wrapped in try/catch, return `false` on failure — mirrors `UnitsCubit` exactly.
- Sub-task B: `settingsThemeUpdateError` l10n key added to EN + FR ARB (with `@` metadata); `_setThemePreference` / `_setAccentPreset` helpers added to `settings_screen.dart`; `ThemeSelector.onChanged` and `AccentPresetSelector.onSelected` wired via `unawaited`.
- Sub-task C: `_ThrowingThemeModeSettingsRepository` / `_ThrowingAccentSettingsRepository` stubs added; 2 cubit failure tests + 2 widget SnackBar tests added; `ensureVisible` used to scroll theme section into view before tapping. All 879 tests pass.

### File List

- `lib/presentation/cubits/theme_cubit.dart` — `Future<bool>` contract + try/catch
- `lib/l10n/app_en.arb` — `settingsThemeUpdateError` + metadata
- `lib/l10n/app_fr.arb` — `settingsThemeUpdateError` + metadata
- `lib/presentation/screens/settings_screen.dart` — helpers + unawaited wiring
- `test/presentation/cubits/theme_cubit_test.dart` — failure stubs + 2 tests
- `test/presentation/screens/settings_screen_test.dart` — throwing stubs + 2 widget tests

## Change Log

- 2026-07-17: Story context created (ready-for-dev) — ultimate context engine analysis completed
- 2026-07-17: Story implemented (review) — Sub-tasks A/B/C complete; 879 tests pass
