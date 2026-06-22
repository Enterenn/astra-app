# Story 19.1: flutter_localizations Scaffold

Status: done

<!-- Refacto Epic 19 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 19-1 · refactoring-audit-master-v0.6.1.md §2.1 · REF-20 -->
<!-- Prerequisite: Epic 18 done (architecture stabilised — no more string-host file splits) -->
<!-- First story in Epic 19 — epic close bumps minor+1 (0.9.0+18) after all 19-x stories done -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want the app ready for multiple languages,
So that French and English strings are type-safe and generated at build time.

## Acceptance Criteria

1. **Given** project configuration  
   **When** i18n is initialised  
   **Then** (REF-20):
   - `pubspec.yaml` has `flutter: generate: true` and `flutter_localizations` dependency (`sdk: flutter`)
   - `l10n.yaml` points to `lib/l10n`, template `app_en.arb`
   - `lib/l10n/app_en.arb` and `lib/l10n/app_fr.arb` exist with matching starter keys

2. **Given** `flutter gen-l10n`  
   **When** run (or triggered via `flutter pub get` / `flutter analyze`)  
   **Then** `AppLocalizations` class generates without errors  
   **And** import path resolves in `lib/app.dart`

3. **Given** `MaterialApp` in `lib/app.dart`  
   **When** wired  
   **Then** `localizationsDelegates` and `supportedLocales` (`en`, `fr`) are configured  
   **And** device locale is used when supported; unsupported locales fall back to `en`  
   **And** **no** `locale:` property bound to user preference yet (Story 19-3)

4. **Given** existing UI copy in `lib/presentation/`  
   **When** scaffold lands  
   **Then** hardcoded strings remain unchanged — migration is Story 19-2 (REF-21)  
   **And** app behaviour and visible copy are identical to pre-scaffold (no user-facing regression)

5. **Given** lightweight formatters (`step_count_formatter.dart`, `relative_time_formatter.dart`, etc.)  
   **When** scaffold lands  
   **Then** they continue to work without adopting `intl` / `DateFormat` — number/date formatting stays manual per project convention

6. **Given** `flutter test --exclude-tags slow`  
   **When** run after changes  
   **Then** all tests pass  
   **And** at least one new fast test verifies `AppLocalizations` resolves under a `MaterialApp` with the new delegates

7. **Given** work completes on branch `refacto`  
   **When** story is marked done  
   **Then** **no version bump** yet — Epic 19 closes with **minor+1, patch=0, build+1** → `0.9.0+18` when all 19-x stories are done

**Covers:** REF-20 · Audit §2.1 · Architecture NFR-6 (i18n-ready structure)

**Depends on:** Epic 18 complete (Epics 14–18 stabilised architecture and repository splits).

**Out of scope:** Migrating hardcoded strings to ARB keys (19-2 / REF-21), persisting user locale preference (19-3 / REF-22), settings UI for language picker, changing number/date formatters to `intl`, translating audit §2.2 migration-table keys beyond starter scaffold keys.

## Tasks / Subtasks

- [x] **Sub-task A — Project config + ARB template files** (AC: #1, #2)
  - [x] Read `pubspec.yaml`, confirm no existing `generate:` or `flutter_localizations` entry
  - [x] Add `flutter_localizations` under `dependencies` (`sdk: flutter`)
  - [x] Add `generate: true` under `flutter:` (keep existing `uses-material-design: false` and font entries)
  - [x] Create root `l10n.yaml` per audit §2.1 (see Dev Notes for exact content)
  - [x] Create `lib/l10n/app_en.arb` (template) and `lib/l10n/app_fr.arb` with matching starter keys
  - [x] Run `flutter pub get` then `flutter gen-l10n` — confirm zero errors
  - [x] Update `docs/DEPENDENCIES.md` with `flutter_localizations` row (SDK package, no network)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Wire `MaterialApp` delegates** (AC: #3, #4)
  - [x] Read `lib/app.dart` **fully** before editing — only touch `MaterialApp` configuration inside `build()`
  - [x] Import generated `AppLocalizations` (path per `l10n.yaml` / Dev Notes)
  - [x] Add `localizationsDelegates` and `supportedLocales`
  - [x] Add `localeResolutionCallback` — match device `languageCode` to `en`/`fr`, else `const Locale('en')`
  - [x] Do **not** set `locale:` from repository (19-3)
  - [x] Do **not** replace hardcoded UI strings in this sub-task
  - [x] Run `flutter analyze`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Test + regression** (AC: #5, #6)
  - [x] Add `test/l10n/app_localizations_scaffold_test.dart` — pump minimal `MaterialApp` with delegates; assert `AppLocalizations.of(context)` non-null for `en` and `fr`
  - [x] Run `flutter test test/l10n/app_localizations_scaffold_test.dart`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] Manual smoke: cold start app — confirm identical UI copy, no layout regressions, no analyzer warnings on missing delegates
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| `flutter_localizations` SDK setup + codegen | String migration across `lib/presentation/` (19-2) |
| Root `l10n.yaml` + starter `.arb` files | Audit §2.2 migration-table keys (19-2) |
| `MaterialApp` delegates + supported locales | `UserSettingsRepository.get/setLocale` (19-3) |
| Device-locale resolution with `en` fallback | Settings language picker UI (19-3) |
| One fast l10n scaffold test | Rewriting formatters to use `intl` |
| `docs/DEPENDENCIES.md` update | Version bump (Epic 19 close) |
| Branch `refacto` only | Changing `uses-material-design: false` |

### Critical baseline — `lib/app.dart` today

`MaterialApp` is built inside `BlocBuilder<ThemeCubit, ThemeState>` with theme/accent wiring only — **no** localization delegates:

```138:168:lib/app.dart
          return MaterialApp(
            title: 'ASTRA',
            theme: buildAstraLightTheme(preset: themeState.accentPreset),
            darkTheme: buildAstraDarkTheme(preset: themeState.accentPreset),
            themeMode: themeState.materialThemeMode,
            themeAnimationDuration: const Duration(milliseconds: 120),
            home: _showMainShell
                ? AppScaffold(
                    deps: widget.deps,
                    ...
                  )
                : OnboardingFlow(
                    deps: widget.deps,
                    onComplete: _onOnboardingComplete,
                    createCubit: widget.createOnboardingCubit,
                  ),
          );
```

**Preserve exactly:** theme cubit wiring, onboarding vs main shell routing, coordinator callbacks, test constructor knobs (`enablePeriodicPersist`, etc.), re-exports at top of file.

**Change only:** add localization imports + `MaterialApp` i18n properties (and optional `localeResolutionCallback`).

### Recommended `l10n.yaml` (audit §2.1 aligned)

Place at project root:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

**Import path:** With default Flutter codegen (`synthetic-package: true`), use:

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

If codegen fails to resolve, run `flutter pub get` first. Do **not** hand-create `app_localizations.dart` — it is generated.

**Alternative (only if Baptiste prefers committed generated files):** set `synthetic-package: false` and `output-dir: lib/l10n/generated` — then import `package:astra_app/l10n/generated/app_localizations.dart`. Default path above is preferred unless analyze fails.

### Starter ARB keys (scaffold only — not migration table)

Use minimal keys to prove codegen; Story 19-2 adds audit §2.2 keys.

**`lib/l10n/app_en.arb`:**

```json
{
  "@@locale": "en",
  "appTitle": "ASTRA",
  "@appTitle": {
    "description": "Application title shown in task switcher / OS shell"
  }
}
```

**`lib/l10n/app_fr.arb`:**

```json
{
  "@@locale": "fr",
  "appTitle": "ASTRA"
}
```

Optional: wire `MaterialApp.title` to `AppLocalizations.of(context)?.appTitle ?? 'ASTRA'` — only if it does not require migrating other strings. Hardcoded `'ASTRA'` title is acceptable for this story.

### `pubspec.yaml` changes

Current `flutter:` block (no `generate:` today):

```39:47:pubspec.yaml
flutter:
  uses-material-design: false
  fonts:
    - family: Figtree
      ...
```

Add under `dependencies`:

```yaml
  flutter_localizations:
    sdk: flutter
```

Add under `flutter:`:

```yaml
  generate: true
```

**Do not** add standalone `intl:` dependency — `flutter_localizations` pulls `intl` transitively for codegen. Project rule remains: presentation formatters stay manual (no `DateFormat` in widgets).

**Do not** bump `version:` (still `0.8.0+17` until Epic 19 closes).

### `MaterialApp` wiring pattern

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

MaterialApp(
  // existing theme props unchanged
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [
    Locale('en'),
    Locale('fr'),
  ],
  localeResolutionCallback: (locale, supportedLocales) {
    if (locale != null) {
      for (final supported in supportedLocales) {
        if (supported.languageCode == locale.languageCode) {
          return supported;
        }
      }
    }
    return const Locale('en');
  },
  // Do NOT set locale: here — Story 19-3 reads UserSettingsRepository
  home: ...
)
```

`uses-material-design: false` is unrelated to localization delegates — keep it.

### Cross-story roadmap (Epic 19)

| Story | Responsibility |
|-------|----------------|
| **19-1 (this)** | Infrastructure: codegen, ARB scaffold, `MaterialApp` delegates |
| **19-2** | Migrate hardcoded strings; add audit §2.2 keys (`menuPrivacyAndData`, `bannerStaleData`, etc.) |
| **19-3** | `UserSettingsRepository.get/setLocale('en'\|'fr')`; bind `MaterialApp.locale` from saved preference at cold start |

Story 18-2 explicitly deferred locale to 19-3:

> add `get/setLocale` to `UserSettingsRepository` in Story 19-3 — **do not** add locale in this story

### Previous story intelligence (Epic 18 close)

| Learning | Application |
|----------|-------------|
| Architecture stabilised — no more god-class splits | Safe to add `lib/l10n/` without files moving |
| `app.dart` is a thin shell post-18-1 | Localization wiring is a small, focused diff |
| Sub-task stop → review → commit | Follow project-context gate per sub-task |
| `UserSettingsRepository` owns theme/units/onboarding prefs | Locale persistence lands in 19-3 on same repo |
| 805+ tests green at Epic 18 close | Regression bar — run `flutter test --exclude-tags slow` |
| No mid-epic version bump | Defer to Epic 19 close (`0.9.0+18`) |
| Sprint tracker is `sprint-status-refacto.yaml` | Update that file, not legacy `sprint-status.yaml` |

### Git intelligence

Recent commits (2026-06-20):

- `e6a0a42` — Epic 18 closed at `0.8.0+17`
- `858b3bf`–`eaed703` — Story 18-3 step repo split complete

No in-flight i18n work expected. Branch `refacto` per epics-refacto workflow notes.

### Architecture compliance

| Rule | Application |
|------|-------------|
| NFR-6 i18n-ready structure | Typed ARB + codegen satisfies Phase 0 readiness |
| No runtime JSON parsing for strings | `flutter gen-l10n` at build time (audit §2.1) |
| SDK-only i18n (no third-party i18n package) | Use `flutter_localizations` only |
| Presentation does not touch repositories for i18n scaffold | No locale pref reads in 19-1 |
| `lib/app.dart` owns `MaterialApp` | Wire delegates here — not in `main.dart` |
| Keep manual formatters | Do not introduce `intl` usage in formatters for this story |

### Test impact

Most widget tests pump a bare `MaterialApp` without app delegates — they should **keep passing** because they test isolated widgets, not full `AstraApp`.

Add one focused test file rather than updating every widget test:

```dart
// test/l10n/app_localizations_scaffold_test.dart
testWidgets('resolves AppLocalizations for en and fr', (tester) async { ... });
```

Pump with explicit `locale: const Locale('fr')` in second case; assert `AppLocalizations.of(context)!.appTitle == 'ASTRA'`.

Do **not** require `AstraApp` / `AppDependencies` for this test — keeps it fast and sqflite-free.

### Project structure notes

- Story file: `_bmad-output/implementation-artifacts/stories/19-1-flutter-localizations-scaffold.md`
- Sprint tracker: `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml`
- New files: `l10n.yaml`, `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`, `test/l10n/app_localizations_scaffold_test.dart`
- Modified files: `pubspec.yaml`, `lib/app.dart`, `docs/DEPENDENCIES.md`, `pubspec.lock` (via pub get)
- Generated (not committed): `.dart_tool/flutter_gen/gen_l10n/app_localizations.dart` unless team chooses `synthetic-package: false`
- Do **not** rewrite `docs/BETA_CHECKLIST.md` historical rows

### Testing requirements

Default verification (project-context):

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test test/l10n/app_localizations_scaffold_test.dart
flutter test --exclude-tags slow
```

Manual: launch on device/emulator with system language FR — app copy unchanged (strings not migrated yet), no crash, no missing-delegate warnings in debug console.

### References

- [Source: _bmad-output/planning-artifacts/epics-refacto.md#Story 19-1]
- [Source: _bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md#2.1]
- [Source: _bmad-output/planning-artifacts/architecture.md — NFR-6]
- [Source: lib/app.dart — MaterialApp baseline]
- [Source: pubspec.yaml — current dependencies]
- [Source: _bmad-output/implementation-artifacts/stories/18-2-split-user-preferences-repository.md — locale deferred to 19-3]
- [Source: _bmad-output/implementation-artifacts/stories/18-1-extract-app-lifecycle-coordinator-from-app-dart.md — app.dart scope]
- [Source: docs/project-context.md — review-before-commit, test commands]
- [Source: docs/DEPENDENCIES.md — package inventory pattern]

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent)

### Debug Log References

- Codegen outputs to `lib/l10n/app_localizations*.dart` (not `flutter_gen/`) — import `package:astra_app/l10n/app_localizations.dart`
- `flutter gen-l10n` + `flutter analyze` — zero l10n errors
- `flutter test --exclude-tags slow` — 806 pass, 2 skipped

### Completion Notes List

- Sub-task A (`af51418`): `flutter_localizations` SDK dep, `generate: true`, `l10n.yaml`, starter ARB files, DEPENDENCIES.md row
- Sub-task B (`f6dd602`): `MaterialApp` delegates + `localeResolutionCallback` in `lib/app.dart`; no `locale:` binding; UI strings unchanged
- Sub-task C (`f444b88`): fast l10n scaffold test for `en`/`fr`; full fast suite green
- No version bump (Epic 19 close → `0.9.0+18`)

### File List

- `l10n.yaml` (new)
- `lib/l10n/app_en.arb` (new)
- `lib/l10n/app_fr.arb` (new)
- `lib/l10n/app_localizations.dart` (generated, committed)
- `lib/l10n/app_localizations_en.dart` (generated, committed)
- `lib/l10n/app_localizations_fr.dart` (generated, committed)
- `lib/app.dart` (modified)
- `pubspec.yaml` (modified)
- `pubspec.lock` (modified)
- `docs/DEPENDENCIES.md` (modified)
- `test/l10n/app_localizations_scaffold_test.dart` (new)

### Change Log

- 2026-06-20: Story 19-1 implemented — i18n scaffold (ARB + codegen + MaterialApp delegates + test). Three commits: A/B/C.

## Story Completion Status

Ultimate context engine analysis completed - comprehensive developer guide created

**Status:** done
