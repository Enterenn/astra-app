# Story 19.2: Migrate Hardcoded Strings to ARB Keys

Status: done

<!-- Refacto Epic 19 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 19-2 · refactoring-audit-master-v0.6.1.md §2.2 · REF-21 -->
<!-- Prerequisite: Story 19-1 done (flutter_localizations scaffold + MaterialApp delegates) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want UI copy in my chosen language,
So that menus, banners, and onboarding reflect locale.

## Acceptance Criteria

1. **Given** audit §2.2 migration table keys (minimum):
   - `menuPrivacyAndData`, `menuTrackingStatus`, `bannerStaleData`, `errorNoPermission`, `onboardingStartBtn`, `trendsWeeklyGrowth`
   **When** migrated
   **Then** each key exists in `app_en.arb` and `app_fr.arb` with the exact translations from REF-21 (audit §2.2 table)
   **And** each key is wired to a user-visible hook in `lib/presentation/` (see Dev Notes mapping table)

2. **Given** a full string scan of `lib/presentation/`
   **When** complete
   **Then** all user-visible strings in scope use `AppLocalizations` — no hardcoded English/French literals in widgets, cubit-emitted UI labels, or semantics labels
   **And** numeric/date fragments may still come from manual formatters (`step_count_formatter`, `relative_time_formatter`, etc.) but surrounding copy and unit words must be localized

3. **Given** device locale French (`Locale('fr')`)
   **When** app launches via existing `MaterialApp` delegates (no user preference yet — Story 19-3)
   **Then** migrated strings display in French on Today, Menu, Settings, My Data, Onboarding, and Trends screens

4. **Given** widget / integration tests under `test/presentation/`
   **When** they pump widgets that read localized copy
   **Then** tests wrap `MaterialApp` with the same localization delegates as production (shared helper)
   **And** assertions use `AppLocalizations` lookups or `find.text(l10n.key)` — not stale hardcoded English literals

5. **Given** `flutter test --exclude-tags slow`
   **When** run after migration
   **Then** all tests pass
   **And** at least one new fast test verifies a migrated audit key renders French copy under `locale: Locale('fr')`

6. **Given** work completes on branch `refacto`
   **When** story is marked done
   **Then** **no version bump** yet — Epic 19 closes with **minor+1, patch=0, build+1** → `0.9.0+18` when all 19-x stories are done

**Covers:** REF-21 · Audit §2.2 · Architecture NFR-6 (bilingual UI)

**Depends on:** Story 19-1 done (`l10n.yaml`, ARB scaffold, `MaterialApp` delegates, committed codegen under `lib/l10n/`).

**Out of scope:** User locale persistence / settings language picker (19-3 / REF-22), binding `MaterialApp.locale` from repository, `lib/core/` / `lib/data/` / `lib/dev/` strings, OS notification channel names, rewriting formatters to use `intl` `DateFormat`, version bump.

## Tasks / Subtasks

- [x] **Sub-task A — Audit §2.2 ARB keys + codegen** (AC: #1)
  - [x] Add the six mandatory keys to `lib/l10n/app_en.arb` (template) with `@` metadata descriptions
  - [x] Mirror all keys in `lib/l10n/app_fr.arb` with audit French translations
  - [x] Add parameterized form for `trendsWeeklyGrowth` (`{percentage}` placeholder) plus companion keys for down/flat/no-prior-week trend variants used today
  - [x] Run `flutter gen-l10n` — confirm zero errors; commit regenerated `lib/l10n/app_localizations*.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Today + banners + permission CTA** (AC: #1, #2, #3)
  - [x] Read `status_banner.dart`, `today_screen.dart`, `collection_health_indicator.dart`, `goal_ring.dart` fully before editing
  - [x] Wire `bannerStaleData` → `StatusBannerVariant.staleCompact` copy + semantics
  - [x] Wire `errorNoPermission` → `_PermissionCta` label (replace `'Open settings to allow step access'`)
  - [x] Migrate remaining Today strings (`Steps`, `Set goal`, collection health templates, goal ring semantics, week trophy, etc.)
  - [x] Localize `relative_time_formatter.dart` output OR wrap with ARB templates in `CollectionHealthIndicator` (see Dev Notes)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Onboarding flow** (AC: #1, #2, #3)
  - [x] Read all files under `lib/presentation/onboarding/` fully
  - [x] Wire `onboardingStartBtn` → step-0 primary button in `onboarding_flow.dart` (audit copy: Start / Démarrer)
  - [x] Migrate intro headline/paragraphs, weight/height page copy, shell back button, Continue/Skip/Let's Go labels
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Trends / History** (AC: #1, #2, #3)
  - [x] Read `history_screen.dart`, `history_cubit.dart`, `trend_chip.dart`, chart widgets fully
  - [x] Refactor trend labels: cubit stores `TrendDirection` + `percent` only; `TrendChip` builds localized label via `AppLocalizations.trendsWeeklyGrowth(percentage)` (and down/flat/no-prior variants)
  - [x] Migrate History screen title, period toggle, chart empty states, peak day card, average stats row, month names in chart tooltips
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Menu / Settings / Profile / My Data / About / bottom nav** (AC: #1, #2, #3)
  - [x] Read menu, settings, profile, my_data, about screens + related widgets fully
  - [x] Wire `menuPrivacyAndData` → My Data screen title (replacing `'My Data'`)
  - [x] Wire `menuTrackingStatus` → My Data Background section headline (replacing `'Background'`)
  - [x] Migrate Menu hub, Settings, Profile, About, app bottom nav, confirm dialogs, data export/import/purge, footprint KPIs, background status card
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task F — Shared widgets + formatters + tests** (AC: #2, #4, #5)
  - [x] Create `test/helpers/l10n_test_helper.dart` — `pumpLocalizedWidget(tester, child, {locale})` wrapping `MaterialApp` with production delegates
  - [x] Update affected widget tests to use helper; fix string assertions
  - [x] Add `test/l10n/migrated_strings_fr_test.dart` — pump a migrated widget (e.g. `StatusBanner` staleCompact) with `locale: fr`, assert French audit copy
  - [x] Run `flutter analyze` + `flutter test --exclude-tags slow`
  - [x] Manual smoke: emulator system language FR — spot-check Today banner, Menu, Onboarding step 0, Trends trend chip
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| All user-visible copy in `lib/presentation/` | `MaterialApp.locale` from user prefs (19-3) |
| Audit §2.2 six mandatory ARB keys + wiring | Settings language picker UI (19-3) |
| Additional ARB keys for remaining presentation strings | `lib/core/`, `lib/data/`, `lib/dev/` debug/log strings |
| Parameterized ARB (`trendsWeeklyGrowth`, relative-time templates) | Rewriting formatters to `intl` `DateFormat` |
| `test/helpers/l10n_test_helper.dart` + test updates | Version bump (Epic 19 close) |
| French translations for unit labels shown in Settings | Changing `uses-material-design: false` |

### Critical baseline — i18n infrastructure from Story 19-1

**Import path (committed codegen, NOT `flutter_gen/`):**

```dart
import 'package:astra_app/l10n/app_localizations.dart';
```

**`l10n.yaml` today:**

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
synthetic-package: false
```

Generated files are **committed** under `lib/l10n/`. After every ARB edit: `flutter gen-l10n` then commit regenerated Dart.

**Access pattern in widgets:**

```dart
final l10n = AppLocalizations.of(context);
Text(l10n.bannerStaleData);
```

`nullable-getter: false` → `AppLocalizations.of(context)` is non-null when delegates are wired (always true under `AstraApp`).

### Mandatory audit §2.2 keys (REF-21) — exact translations

| Key | English (`app_en.arb`) | French (`app_fr.arb`) | Wire to |
|-----|------------------------|----------------------|---------|
| `menuPrivacyAndData` | Privacy & My Data | Confidentialité & Mes Données | `MyDataScreen` title (`_kScreenTitle`) + semantics label |
| `menuTrackingStatus` | Step Tracking Status | État du suivi des pas | My Data `SectionCard` headline for Background block |
| `bannerStaleData` | Data outdated. Tap to refresh. | Données obsolètes. Toucher pour actualiser. | `StatusBanner` `staleCompact` `_copy` + semantics |
| `errorNoPermission` | Step access denied. Tap to fix. | Accès aux pas refusé. Toucher pour régler. | `TodayScreen` `_PermissionCta` button label |
| `onboardingStartBtn` | Start | Démarrer | Onboarding step 0 `primaryLabel` in `onboarding_flow.dart` |
| `trendsWeeklyGrowth` | Up {percentage}% from last week | En hausse de {percentage}% la semaine dernière | `TrendChip` when `TrendDirection.up` |

**Important:** Current English UI copy differs from audit exemplars for several keys (e.g. stale banner says `'Steps may be delayed — tap to refresh'` today). **Use audit copy** for the six mandatory keys — this is an intentional product alignment with REF-21.

**Additional trend keys** (not in audit table but required by current UI — add alongside `trendsWeeklyGrowth`):

| Suggested key | English | French | Wire to |
|---------------|---------|--------|---------|
| `trendsWeeklyDecline` | Down {percentage}% from last week | En baisse de {percentage}% la semaine dernière | `TrendDirection.down` |
| `trendsWeeklyFlat` | Same as last week | Identique à la semaine dernière | `TrendDirection.flat`, percent == 0 |
| `trendsNoPriorWeek` | No prior week data | Pas de données la semaine précédente | prior week sum == 0 |

**ARB placeholder example (template `app_en.arb`):**

```json
"trendsWeeklyGrowth": "Up {percentage}% from last week",
"@trendsWeeklyGrowth": {
  "description": "Weekly step trend chip when steps increased",
  "placeholders": {
    "percentage": { "type": "int" }
  }
}
```

### Trend label architecture — move localization to presentation

**Problem:** `history_cubit.dart` builds English labels in `_computeTrend`:

```424:428:lib/presentation/cubits/history_cubit.dart
      return TrendSnapshot(
        direction: TrendDirection.up,
        percent: percent,
        label: 'Up $percent% from last week',
      );
```

**Required pattern:** Cubit emits structural data only; widget localizes.

1. Refactor `TrendSnapshot` — keep `direction` + `percent`, **remove `label`** (or make `@visibleForTesting` deprecated).
2. `TrendChip.build` reads `AppLocalizations.of(context)` and selects the correct getter based on `direction` / edge cases.
3. Update `test/presentation/widgets/trend_chip_test.dart` to pump with `l10n_test_helper` and assert via `l10n.trendsWeeklyGrowth(12)`.

Do **not** inject `AppLocalizations` into cubits or repositories.

### Relative time formatter — localize user-visible fragments

`relative_time_formatter.dart` returns English-only strings (`'minutes ago'`, `'never'`, etc.) consumed by `CollectionHealthIndicator`:

```21:27:lib/presentation/widgets/collection_health_indicator.dart
  String get _label => switch (display) {
        CollectionHealthDisplay.loading => '',
        CollectionHealthDisplay.active => 'Collection active ●',
        CollectionHealthDisplay.stale =>
          'Last sync ${formatRelativeTime(...)} ⚠',
        CollectionHealthDisplay.permissionDenied => 'Sensor access revoked ✕',
      };
```

**Approach (keep manual formatter, no `intl`):**

- Add ARB keys for templates: `collectionHealthActive`, `collectionHealthStale` (`Last sync {relativeTime}`), `collectionHealthPermissionDenied`
- Add ARB keys for relative-time units: `relativeTimeNever`, `relativeTimeJustNow`, `relativeTimeMinutesAgo` (`{count}` + plural), etc.
- Extend `formatRelativeTime` with optional `RelativeTimeLabels` parameter (struct of localized unit strings) **or** add `formatRelativeTimeLocalized(AppLocalizations l10n, ...)` in the same file
- Widget passes `l10n` into formatter helper; formatter returns only the time fragment; widget wraps with ARB template

Do **not** add standalone `intl:` to `pubspec.yaml`.

### Audit key wiring vs current UI — copy changes expected

| Location | Current copy | After migration |
|----------|--------------|-----------------|
| `StatusBanner.staleCompact` | Steps may be delayed — tap to refresh | Data outdated. Tap to refresh. (audit) |
| `_PermissionCta` | Open settings to allow step access | Step access denied. Tap to fix. (audit) |
| Onboarding step 0 primary | Continue | Start / Démarrer (audit) |
| My Data title | My Data | Privacy & My Data (audit) |
| My Data Background headline | Background | Step Tracking Status (audit) |

Document these in the review brief so Baptiste expects visible English copy changes on audit-key surfaces.

### Full presentation inventory (~65 files with string literals)

Migrate **all** user-visible strings in these areas (non-exhaustive file list — scan entire `lib/presentation/` tree):

**Screens:** `today_screen.dart`, `history_screen.dart`, `menu_hub_screen.dart`, `settings_screen.dart`, `profile_screen.dart`, `my_data_screen.dart`, `about_screen.dart`, `app_scaffold.dart`

**Onboarding:** `onboarding_flow.dart`, `onboarding_intro_page.dart`, `onboarding_weight_page.dart`, `onboarding_height_page.dart`, `onboarding_shell.dart`, `onboarding_metric_picker_layout.dart`

**High-traffic widgets:** `app_bottom_nav.dart`, `status_banner.dart`, `collection_health_indicator.dart`, `activity_stats_row.dart`, `goal_ring.dart`, `goal_editor_sheet.dart`, `confirm_dialog.dart`, `background_status_card.dart`, `footprint_kpi_row.dart`, `data_export_button.dart`, `data_import_button.dart`, `data_purge_button.dart`, `step_bar_chart.dart`, `trends_monthly_bar_chart.dart`, `trends_peak_day_card.dart`, `trends_average_stats_row.dart`, `period_toggle.dart`, `theme_selector.dart`, `accent_preset_selector.dart`, `settings_preference_row.dart`, `display_name_editor_row.dart`, `display_name_editor_sheet.dart`, `height_editor_sheet.dart`, `weight_editor_sheet.dart`, `unit_option_picker_sheet.dart`, `week_progress_row.dart`, `week_trophy_badge.dart`, `secondary_screen_shell.dart`, `section_card.dart` (headlines passed as params — localize at call site)

**Formatters with user-visible output:** `relative_time_formatter.dart` (see above). `display_unit_formatter.dart` / `display_unit_preferences.dart` — Settings shows `km`/`mi`/`kg`/`lb`; localize via ARB lookup in Settings rather than enum `displayLabel` if product wants French labels.

**Exclude from migration:** `debugPrint` strings, `@visibleForTesting` probe names, chart internal math labels not shown to users, `Key('...')` debug keys.

### ARB key naming conventions

- camelCase keys matching audit where specified
- Group by feature prefix: `menu*`, `banner*`, `onboarding*`, `trends*`, `today*`, `settings*`, `profile*`, `myData*`, `common*`
- Every `app_en.arb` key needs matching `app_fr.arb` entry
- Add `@key` description metadata in template for non-obvious strings
- Keep `appTitle` from 19-1 unchanged

### Widget test helper pattern

Create `test/helpers/l10n_test_helper.dart`:

```dart
import 'package:astra_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const kTestLocalizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<void> pumpLocalizedWidget(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}
```

Most existing tests use bare `MaterialApp(theme: buildAstraLightTheme(), ...)` — add delegates without changing test intent. Prefer looking up expected strings:

```dart
final l10n = lookupAppLocalizations(const Locale('fr'));
expect(find.text(l10n.bannerStaleData), findsOneWidget);
```

Use `lookupAppLocalizations` from generated code for unit tests without pumping.

### Previous story intelligence (19-1)

| Learning | Application |
|----------|-------------|
| Codegen outputs to `lib/l10n/` (committed) | Regenerate and commit after ARB edits |
| Import `package:astra_app/l10n/app_localizations.dart` | Same — do not use `flutter_gen/` path |
| `MaterialApp` delegates already wired in `lib/app.dart` | Do not add `locale:` binding (19-3) |
| Device locale resolution works (`en`/`fr`, fallback `en`) | French smoke test uses system locale OR test `locale:` param only in tests |
| 806 tests green at 19-1 close | Regression bar unchanged |
| Sub-task stop → review → commit | Follow project-context gate per sub-task |
| Manual formatters stay manual | Localize templates/units via ARB; do not adopt `DateFormat` |
| Sprint tracker is `sprint-status-refacto.yaml` | Update that file when story moves to ready-for-dev / done |

### Git intelligence

Recent commits (2026-06-20):

- `742f14d` — Story 19-1 done after code review polish
- `f444b88` — l10n scaffold test (`test/l10n/app_localizations_scaffold_test.dart`)
- `f6dd602` — MaterialApp delegates wired
- `af51418` — ARB scaffold + `l10n.yaml`

No in-flight string migration expected. Branch `refacto`.

### Architecture compliance

| Rule | Application |
|------|-------------|
| NFR-6 bilingual UI | Full `lib/presentation/` migration satisfies Phase 0 i18n |
| Typed ARB + build-time codegen | All new strings via `.arb` only — no runtime JSON |
| SDK-only i18n | No third-party i18n packages |
| Presentation reads l10n via `BuildContext` | Cubits emit data, not localized strings |
| `lib/app.dart` owns `MaterialApp` | Do not move delegates; do not bind `locale:` yet |
| Keep manual numeric formatters | Numbers/durations formatted manually; surround with ARB |

### Cross-story roadmap (Epic 19)

| Story | Responsibility |
|-------|----------------|
| 19-1 (done) | Infrastructure: codegen, ARB scaffold, delegates |
| **19-2 (this)** | Migrate all presentation strings; audit §2.2 keys |
| 19-3 | `UserSettingsRepository.get/setLocale`; bind `MaterialApp.locale`; settings language picker |

### Testing requirements

```bash
flutter gen-l10n
flutter analyze
flutter test test/l10n/
flutter test test/presentation/   # after helper rollout
flutter test --exclude-tags slow
```

**New tests:**

- `test/l10n/migrated_strings_fr_test.dart` — French rendering of at least one audit key
- Update `test/presentation/widgets/status_banner_test.dart`, `trend_chip_test.dart`, `collection_health_indicator_test.dart`, etc.

**Manual:** Set emulator/device to French → cold start → verify Today stale banner, permission CTA, Menu/My Data titles, Onboarding Start button, Trends chip show French.

### Project structure notes

- Story file: `_bmad-output/implementation-artifacts/stories/19-2-migrate-hardcoded-strings-to-arb-keys.md`
- Sprint tracker: `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml`
- Primary modified: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`, `lib/l10n/app_localizations*.dart`, all touched `lib/presentation/**`, `test/helpers/l10n_test_helper.dart`, affected `test/presentation/**`
- Do **not** bump `pubspec.yaml` version
- Do **not** rewrite `docs/BETA_CHECKLIST.md` historical rows

### Latest technical notes (Flutter gen-l10n)

- Placeholders: `{paramName}` in ARB; declare `"placeholders"` in `@key` metadata with `"type": "int"` / `"String"` / `"num"`
- Plurals: use `"type": "plural"` metadata if needed for relative-time units (optional — simple `{count}` string may suffice for Phase 0)
- After ARB changes, `flutter pub get` triggers codegen; verify with `flutter gen-l10n` explicitly
- `lookupAppLocalizations(Locale('fr'))` available in generated code for unit tests
- French typography: existing `AstraTypography` handles accented characters — no font changes needed

### References

- [Source: _bmad-output/planning-artifacts/epics-refacto.md#Story 19-2]
- [Source: _bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md#2.2]
- [Source: _bmad-output/planning-artifacts/architecture.md — NFR-6]
- [Source: _bmad-output/implementation-artifacts/stories/19-1-flutter-localizations-scaffold.md]
- [Source: lib/l10n/app_en.arb — current scaffold]
- [Source: l10n.yaml — codegen config]
- [Source: lib/app.dart — MaterialApp delegates baseline]
- [Source: lib/presentation/widgets/status_banner.dart — banner copy baseline]
- [Source: lib/presentation/cubits/history_cubit.dart — trend label anti-pattern]
- [Source: test/l10n/app_localizations_scaffold_test.dart — delegate list pattern]
- [Source: docs/project-context.md — review-before-commit, test commands]

## Dev Agent Record

### Agent Model Used

Composer

### Completion Notes List

- **Sub-task A (2026-06-20):** Added 10 ARB keys (6 audit §2.2 mandatory + 4 trend variants). Regenerated `app_localizations*.dart`. Commit `5ab54ae`.
- **Sub-task B (2026-06-20):** Migrated Today screen, status banners, collection health, goal ring, relative time formatter. Audit keys `bannerStaleData` and `errorNoPermission` wired. Commit `a22dc09`.
- **Sub-task C (2026-06-20):** Onboarding flow fully localized; step 0 uses audit copy Start/Démarrer. Commit `3ca78e6`.
- **Sub-task D (2026-06-20):** Trends/History migrated; `TrendSnapshot.label` removed; localization in `TrendChip` via `l10n_date_labels.dart`. Commit `5d415fa`.
- **Sub-task E (2026-06-20):** Menu/Settings/Profile/My Data/About/bottom nav migrated; cubit errors refactored to enums. Commit `6a13705`.
- **Sub-task F (2026-06-20):** `l10n_test_helper.dart`, `TestMaterialApp`, 45 test files updated, `migrated_strings_fr_test.dart` added. `flutter test --exclude-tags slow` → 808 pass. Commit `3aa1293`.
- **No version bump** per story AC #6 (Epic 19 close).

### File List

- `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`, `lib/l10n/app_localizations*.dart`
- `lib/presentation/formatters/relative_time_formatter.dart`, `display_unit_formatter.dart`
- `lib/presentation/l10n/l10n_date_labels.dart`, `display_unit_l10n.dart`, `my_data_error_messages.dart`, `profile_error_messages.dart`
- `lib/presentation/cubits/history_cubit.dart`, `history_state.dart`, `my_data_cubit.dart`, `my_data_state.dart`, `my_data_errors.dart`, `profile_cubit.dart`, `profile_state.dart`, `profile_errors.dart`
- `lib/presentation/screens/` — today, history, menu_hub, app_scaffold, settings, profile, my_data, about
- `lib/presentation/onboarding/` — all 6 files
- `lib/presentation/widgets/` — 30+ widgets migrated
- `test/helpers/l10n_test_helper.dart`, `test/helpers/astra_theme_test_helper.dart`
- `test/l10n/migrated_strings_fr_test.dart`
- `test/presentation/**` — 40+ test files updated

### Change Log

- 2026-06-20: Story 19-2 complete — full `lib/presentation/` i18n migration (6 commits A–F)

## Story Completion Status

Ultimate context engine analysis completed - comprehensive developer guide created

**Status:** done
