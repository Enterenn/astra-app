# Story 20.5: Phosphor Icons Selective Font Subsetting

Status: done

<!-- Refacto Epic 20 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 20-5 · refactoring-audit-master-v0.6.1.md §4 · REF-27 · NFR-REF-03 -->
<!-- Prerequisite: Story 20-4 done · Epic 20 final story — includes version bump -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **maintainer**,
I want only used Phosphor glyphs in the APK,
So that multi-font icon package overhead (~200–400 KB) is eliminated.

## Acceptance Criteria

- [ ] **AC #1 — Icon audit documented** — **Given** audit of all `PhosphorIconsRegular` / `PhosphorIconsFill` usages in `lib/`
  **When** complete
  **Then** required icon inventory and Unicode codepoints are documented in this story's Dev Notes (and optionally `docs/DEPENDENCIES.md`)
  **And** audit covers every production call site — grep `PhosphorIcons` across `lib/` with zero misses

- [ ] **AC #2 — Subset fonts bundled locally** — **Given** `/assets/fonts/`
  **When** populated
  **Then** only **two** subset `.ttf` files are bundled: Regular + Fill (REF-27)
  **And** `pubspec.yaml` registers `PhosphorRegular` and `PhosphorFill` families from app assets
  **And** `phosphoricons_flutter` is **removed** from `pubspec.yaml` (package ships 6 full fonts ~477–554 KB each; Flutter tree-shaking copies unreferenced package fonts as-is — removal is mandatory)

- [ ] **AC #3 — API compatibility preserved** — **Given** all screens and widgets
  **When** visually inspected on device (light + dark themes)
  **Then** no missing-icon tofu boxes
  **And** tab nav active/inactive Regular vs Fill swap unchanged (`AppBottomNav`)
  **And** `find.byIcon(PhosphorIconsRegular.*)` tests still pass after import path update

- [ ] **AC #4 — APK size measured** — **Given** post-change size analysis (NFR-REF-03)
  **When** compared to Story 20-4 baseline (~19.3 MB arm64 release per 20-4 completion notes)
  **Then** review brief notes estimated **200–400 KB** reduction (audit target)
  **And** command used: `flutter build apk --release --analyze-size --target-platform android-arm64`

- [ ] **AC #5 — Tests & docs** — **Given** dependency removal
  **When** story completes
  **Then** `flutter test --exclude-tags slow` passes
  **And** `flutter analyze` clean on touched files
  **And** `docs/DEPENDENCIES.md` updated (remove package row; document local subset fonts + MIT license)
  **And** subset regeneration steps documented (pyftsubset commands or script)

- [ ] **AC #6 — Epic 20 version bump** — **Given** this is the **last** Epic 20 story
  **When** story completes
  **Then** `pubspec.yaml` version → **`0.10.0+20`** (minor+1, patch=0, build+1 per refacto versioning)
  **And** `README.md` project status version row updated
  **And** Epic 20 can be marked `done` in `sprint-status-refacto.yaml` after code review

**Covers:** REF-27 · NFR-REF-03 · Audit §4 (~200–400 KB APK)

**Depends on:** Story 20-4 done · Story 5.6 original Phosphor install (`phosphoricons_flutter` ^1.0.0).

**Out of scope:** Changing which icons are used (no UX redesign); migrating to `phosphor_flutter` 2.x (incompatible with Dart 3.12); subsetting Figtree/Darker Grotesque variable fonts; adding new icon styles (Thin/Light/Bold/Duotone).

## Tasks / Subtasks

- [x] **Sub-task A — Audit & subset font generation** (AC: #1, #2 partial)
  - [x] Grep `lib/` for `PhosphorIconsRegular` and `PhosphorIconsFill` — confirm inventory matches Dev Notes table below
  - [x] Copy source TTFs from pub-cache `phosphoricons_flutter-1.0.0/lib/fonts/`:
    - `Phosphor.ttf` → subset Regular
    - `Phosphor-Fill.ttf` → subset Fill
  - [x] Generate subsets with `pyftsubset` (fonttools) using documented Unicode list — **not** all 1500+ glyphs
  - [x] Write subset files to `assets/fonts/Phosphor-Regular-subset.ttf` and `assets/fonts/Phosphor-Fill-subset.ttf`
  - [x] Add optional `tool/subset_phosphor_icons.ps1` (and `.sh`) so regeneration is repeatable when icons are added
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Local IconData module + pubspec** (AC: #2, #3 partial)
  - [x] Create `lib/core/icons/phosphor_icons.dart`:
    - `PhosphorIconsRegular` — 18 icons (production `lib/` audit)
    - `PhosphorIconsFill` — 3 icons (tab active state + goal ring fill sneaker)
    - `IconData` constants: same `fontFamily`, **no** `fontPackage` (loads from app assets)
    - Preserve `matchTextDirection: true` where package had it (directional arrows/carets)
  - [x] Register fonts in `pubspec.yaml` under `flutter.fonts` (keep existing Figtree + Darker Grotesque)
  - [x] Remove `phosphoricons_flutter: ^1.0.0`; run `flutter pub get`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Migrate imports** (AC: #3, #5 partial)
  - [x] Replace `import 'package:phosphoricons_flutter/phosphoricons_flutter.dart'` with `import 'package:astra_app/core/icons/phosphor_icons.dart'` in all `lib/` files (16 files — see File Structure)
  - [x] Update all `test/` files that import phosphor package (app_scaffold_test, trend_chip_test, widget_test, etc.)
  - [x] Update `test/dev/chart_benchmark_dev_fab.dart` — uses `PhosphorIconsRegular.speedometer` (dev-only; include in Regular subset **or** swap to an already-used icon to avoid extra glyph — prefer swap to `chartBar` if dev FAB is non-critical)
  - [x] Grep entire repo for `phosphoricons_flutter` — zero hits except lockfile removal + docs
  - [x] Run `flutter analyze` on touched paths
  - [x] Run `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Size analysis, docs, version bump, epic close prep** (AC: #4, #5, #6)
  - [x] Run `flutter build apk --release --analyze-size --target-platform android-arm64`; note delta vs 20-4 baseline in review brief
  - [x] Update `docs/DEPENDENCIES.md` — remove `phosphoricons_flutter` row; add local Phosphor subset section (MIT, no network, regeneration steps)
  - [x] Bump `pubspec.yaml` → `0.10.0+20`; update `README.md` version row
  - [x] Manual device checklist: all 3 tabs (Regular/Fill swap), onboarding arrows, Trends icons, My Data chevrons, goal ring sneaker
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Remove `phosphoricons_flutter`; bundle 2 subset TTFs | Switching to `phosphor_flutter` 2.x |
| Local `PhosphorIconsRegular` / `PhosphorIconsFill` constants | Adding Thin/Light/Bold/Duotone styles |
| Import migration in `lib/` + `test/` | Changing icon choices or sizes |
| APK size measurement (NFR-REF-03) | Subsetting text fonts (Figtree, Darker Grotesque) |
| Epic 20 version bump `0.10.0+20` | Epic retrospective (optional, separate) |

### Critical baseline — why package removal is mandatory

`phosphoricons_flutter` 1.0.0 registers **six** full icon fonts in its pubspec:

| Package font file | Uncompressed size |
|-------------------|-------------------|
| `Phosphor.ttf` (Regular) | ~477 KB |
| `Phosphor-Fill.ttf` | ~439 KB |
| `Phosphor-Thin.ttf` | ~523 KB |
| `Phosphor-Light.ttf` | ~524 KB |
| `Phosphor-Bold.ttf` | ~484 KB |
| `Phosphor-Duotone.ttf` | ~554 KB |

ASTRA uses **only Regular + Fill** (21 glyph references across both styles). Flutter release **icon tree shaking** subsets fonts that have referenced `IconData` codepoints, but **unreferenced fonts in a dependency are copied as-is** into the APK ([flutter#63920](https://github.com/flutter/flutter/issues/63920)). Therefore **four unused styles still ship today** (~2 MB uncompressed). Removing the package and bundling two app-owned subsets is the only reliable fix.

### Production icon audit (`lib/` only — APK-relevant)

**PhosphorIconsRegular (18 icons):**

| Icon | Codepoint | Used in |
|------|-----------|---------|
| `arrowDown` | `0xe03e` | `trend_chip.dart` |
| `arrowLeft` | `0xe058` | `onboarding_shell.dart`, `secondary_screen_header.dart` |
| `arrowRight` | `0xe06c` | `onboarding_shell.dart` |
| `arrowUp` | `0xe08e` | `trend_chip.dart` |
| `calendar` | `0xe108` | `trends_insight_cards.dart` |
| `caretRight` | `0xe13a` | `display_name_editor_row.dart`, `profile_info_row.dart`, `menu_nav_row.dart`, `settings_preference_row.dart` |
| `chartBar` | `0xe150` | `app_bottom_nav.dart` |
| `chartLineUp` | `0xe156` | `trends_insight_cards.dart` |
| `check` | `0xe182` | `unit_option_picker_sheet.dart` |
| `clock` | `0xe19a` | `activity_stats_row.dart` |
| `fire` | `0xe242` | `activity_stats_row.dart`, `trends_average_stats_row.dart` |
| `footprints` | `0xea88` | `about_screen.dart`, `trends_average_stats_row.dart` |
| `list` | `0xe2f0` | `app_bottom_nav.dart` |
| `mapPin` | `0xe316` | `activity_stats_row.dart` |
| `minus` | `0xe32a` | `trend_chip.dart` |
| `sneakerMove` | `0xed60` | `app_bottom_nav.dart` |
| `target` | `0xe47c` | `trends_insight_cards.dart` |
| `trophy` | `0xe67e` | `trends_peak_day_card.dart`, `week_trophy_badge.dart` |

**PhosphorIconsFill (3 icons):**

| Icon | Codepoint | Used in |
|------|-----------|---------|
| `chartBar` | `0xe150` | `app_bottom_nav.dart` (active tab) |
| `list` | `0xe2f0` | `app_bottom_nav.dart` (active tab) |
| `sneakerMove` | `0xed60` | `app_bottom_nav.dart`, `goal_ring.dart` |

**Regular subset unicodes** (single `--unicodes=` argument):

```
U+E03E,U+E058,U+E06C,U+E08E,U+E108,U+E13A,U+E150,U+E156,U+E182,U+E19A,U+E242,U+EA88,U+E2F0,U+E316,U+E32A,U+ED60,U+E47C,U+E67E
```

**Fill subset unicodes:**

```
U+E150,U+E2F0,U+ED60
```

Source codepoints verified against `phosphoricons_flutter` 1.0.0 pub-cache (`phosphor_icons_regular.dart`, `phosphor_icons_fill.dart`).

### Recommended subset generation (pyftsubset)

Install once: `pip install fonttools` (or use `py -m pip install fonttools` on Windows).

```powershell
$pkg = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\phosphoricons_flutter-1.0.0\lib\fonts"
$regular = "U+E03E,U+E058,U+E06C,U+E08E,U+E108,U+E13A,U+E150,U+E156,U+E182,U+E19A,U+E242,U+EA88,U+E2F0,U+E316,U+E32A,U+ED60,U+E47C,U+E67E"
$fill = "U+E150,U+E2F0,U+ED60"

pyftsubset "$pkg\Phosphor.ttf" --unicodes=$regular --output-file=assets/fonts/Phosphor-Regular-subset.ttf --layout-features=* --glyph-names --symbol-cmap --legacy-cmap --notdef-glyph --notdef-outline --recommended-glyphs --name-IDs=* --name-legacy --name-languages=*
pyftsubset "$pkg\Phosphor-Fill.ttf" --unicodes=$fill --output-file=assets/fonts/Phosphor-Fill-subset.ttf --layout-features=* --glyph-names --symbol-cmap --legacy-cmap --notdef-glyph --notdef-outline --recommended-glyphs --name-IDs=* --name-legacy --name-languages=*
```

Expected output: two small TTFs (typically **5–30 KB each** vs **477 KB + 439 KB** full fonts). Total APK savings ~200–400 KB after compression (audit estimate); four unused package styles eliminated entirely.

### Local IconData module pattern

```dart
// lib/core/icons/phosphor_icons.dart
import 'package:flutter/widgets.dart';

@staticIconProvider
class PhosphorIconsRegular {
  const PhosphorIconsRegular();
  static const IconData chartBar = IconData(
    0xe150,
    fontFamily: 'PhosphorRegular',
    matchTextDirection: true,
  );
  // ... remaining 17 icons — NO fontPackage key
}

@staticIconProvider
class PhosphorIconsFill {
  const PhosphorIconsFill();
  static const IconData chartBar = IconData(
    0xe150,
    fontFamily: 'PhosphorFill',
    matchTextDirection: true,
  );
  // ... list, sneakerMove
}
```

**Critical:** Omit `fontPackage: 'phosphoricons_flutter'` — otherwise Flutter looks in the removed package path.

### pubspec.yaml font registration (add alongside existing fonts)

```yaml
flutter:
  fonts:
    # ... Figtree, Darker Grotesque unchanged ...
    - family: PhosphorRegular
      fonts:
        - asset: assets/fonts/Phosphor-Regular-subset.ttf
    - family: PhosphorFill
      fonts:
        - asset: assets/fonts/Phosphor-Fill-subset.ttf
```

Family names **must** match `fontFamily` in IconData (`PhosphorRegular`, `PhosphorFill` — same as package convention).

### Previous story intelligence (20-4)

| Learning | Application |
|----------|-------------|
| Review-before-commit per sub-task | Same gate — A/B/C/D commits |
| `flutter test --exclude-tags slow` (~830 tests) | Run full suite in Sub-task C |
| APK baseline **19.3 MB** arm64 (post fl_chart removal) | Use as NFR-REF-03 comparison point |
| No version bump in 20-4 | **This story owns** Epic 20 bump → `0.10.0+20` |
| Sub-task D pattern: deps + docs + size analysis | Mirror for phosphor removal |
| Branch `refacto` only | Do not merge to main from this story |

### Previous story intelligence (5-6)

| Learning | Application |
|----------|-------------|
| `phosphor_flutter` 2.1.0 fails on Dart 3.12 | Do **not** regress to `phosphor_flutter` |
| `phosphoricons_flutter` ^1.0.0 is production package | Remove entirely — replace with local assets |
| Story 5.6 noted deferred APK font size check | This story closes that debt |
| DEPENDENCIES.md is living inventory | Update with subset policy + MIT license |

### Git intelligence

Recent commits (2026-06-21):

- `d8c0418` — Story 20-4 review fixes + done
- `49ab326` — fl_chart removal + docs (20-4-D)
- Pattern: scoped commits `feat(charts):`, `chore(deps):`, review-before-commit gates

Suggested commit messages:

- `chore(icons): generate Phosphor Regular/Fill subset fonts (story 20-5-A)`
- `feat(icons): add local PhosphorIcons module and pubspec fonts (story 20-5-B)`
- `refactor(icons): migrate imports off phosphoricons_flutter (story 20-5-C)`
- `chore(release): bump 0.10.0+20, docs, APK size note (story 20-5-D)`

### Architecture compliance

| Rule | Application |
|------|-------------|
| REF-27 | Only required `.ttf` subsets in `/assets/fonts/` |
| NFR-REF-03 | Measure APK before/after in review brief |
| D-27 (architecture.md) | Still Phosphor regular weight for UI — implementation becomes local assets, not package |
| Offline / no network | Icon fonts bundled locally — unchanged policy |
| Review-before-commit | One commit per sub-task after Baptiste OK |
| Versioning (Epic 20) | minor+1 → `0.10.0+20` at story close |

### Library / framework requirements

| Package | Action |
|---------|--------|
| `phosphoricons_flutter` ^1.0.0 | **Remove** |
| `fonttools` (pyftsubset) | Dev-time only — not a Dart dependency; optional script in `tool/` |
| — | **No new Dart icon packages** |

### File structure requirements

| Action | Path |
|--------|------|
| **NEW** | `assets/fonts/Phosphor-Regular-subset.ttf` |
| **NEW** | `assets/fonts/Phosphor-Fill-subset.ttf` |
| **NEW** | `lib/core/icons/phosphor_icons.dart` |
| **NEW** (optional) | `tool/subset_phosphor_icons.ps1`, `tool/subset_phosphor_icons.sh` |
| **UPDATE** | `pubspec.yaml` — fonts + remove dependency + version `0.10.0+20` |
| **UPDATE** | `docs/DEPENDENCIES.md` |
| **UPDATE** | `README.md` version row |
| **UPDATE** | 16 `lib/` widgets/screens (import swap only — see grep list) |
| **UPDATE** | ~10 test files importing phosphor package |
| **READ ONLY** | `lib/presentation/widgets/app_bottom_nav.dart` — verify Regular/Fill swap behavior preserved |

**lib/ files requiring import migration:**

- `lib/presentation/widgets/app_bottom_nav.dart`
- `lib/presentation/widgets/activity_stats_row.dart`
- `lib/presentation/widgets/display_name_editor_row.dart`
- `lib/presentation/widgets/goal_ring.dart`
- `lib/presentation/widgets/menu_nav_row.dart`
- `lib/presentation/widgets/profile_info_row.dart`
- `lib/presentation/widgets/secondary_screen_header.dart`
- `lib/presentation/widgets/settings_preference_row.dart`
- `lib/presentation/widgets/trend_chip.dart`
- `lib/presentation/widgets/trends_average_stats_row.dart`
- `lib/presentation/widgets/trends_insight_cards.dart`
- `lib/presentation/widgets/trends_peak_day_card.dart`
- `lib/presentation/widgets/unit_option_picker_sheet.dart`
- `lib/presentation/widgets/week_trophy_badge.dart`
- `lib/presentation/onboarding/onboarding_shell.dart`
- `lib/presentation/screens/about_screen.dart`

### Testing requirements

```bash
flutter analyze lib/core/icons/ lib/presentation/
flutter test --exclude-tags slow
flutter build apk --release --analyze-size --target-platform android-arm64
```

**Test migration:** Only change import path — `PhosphorIconsRegular` / `PhosphorIconsFill` API names unchanged, so `find.byIcon(PhosphorIconsRegular.chartBar)` etc. should work without assertion changes.

**Manual checklist (physical device):**

1. Bottom nav: tap Steps / Trends / Menu — active tab shows Fill icon on squircle; inactive shows Regular
2. Onboarding: back arrow + continue arrow visible
3. Trends: trend chip arrows, insight card icons, trophy, fire/footprints stats
4. Today: activity stats fire/mapPin/clock; goal ring fill sneaker when applicable
5. Menu → Settings / Profile rows: caretRight chevrons
6. Unit picker sheet: check mark on selected option
7. About screen: footprints icon

### Cross-story roadmap (Epic 20)

| Story | Responsibility |
|-------|----------------|
| 20-1 | Onboarding trust ✅ |
| 20-2 | Trends insight cards ✅ |
| 20-3 | Tab haptics ✅ |
| 20-4 | CustomPainter charts ✅ |
| **20-5 (this)** | Phosphor subsetting + **version bump `0.10.0+20`** + epic close |

### Latest technical notes (Flutter icon fonts, 2026)

- Flutter release builds run icon tree shaking via engine `font-subset` binary — effective for **referenced** fonts only; unreferenced fonts in dependencies still ship whole.
- Subclassing `IconData` or using `fontPackage` does not prevent tree shaking of **used** codepoints, but cannot eliminate **unused font files** from a multi-font package.
- Pre-subsetting with `pyftsubset` before bundling reduces source TTF size and build-time work; combine with Flutter tree shaking for defense in depth.
- Keep `@staticIconProvider` on icon classes — matches package convention and analyzer hints.
- Phosphor Icons license: MIT ([phosphor-icons/core](https://github.com/phosphor-icons/core)).

### Project context reference

- [Source: docs/project-context.md] Review-before-commit gate — stop after each sub-task.
- [Source: docs/project-context.md] Default test command: `flutter test --exclude-tags slow`.
- [Source: .cursor/rules/app-versioning.mdc] Epic 20 close → minor+1, build+1.
- [Source: _bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md §4] ~200–400 KB APK gain rationale.
- [Source: _bmad-output/planning-artifacts/epics-refacto.md REF-27, NFR-REF-03]

### References

- [Source: _bmad-output/planning-artifacts/epics-refacto.md#story-20-5-phosphor-icons-selective-font-subsetting]
- [Source: _bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md §4]
- [Source: _bmad-output/implementation-artifacts/stories/5-6-phosphor-icons-dependency.md]
- [Source: _bmad-output/implementation-artifacts/stories/20-4-replace-fl-chart-with-custom-painter-charts.md]
- [Source: lib/presentation/widgets/app_bottom_nav.dart]
- [Source: pubspec.yaml]

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- Audit grep confirmed 18 Regular + 3 Fill icons in `lib/` — matches Dev Notes inventory exactly.
- Subset fonts: Regular 5644 B → 4340 B tree-shaken; Fill 2280 B → 1320 B tree-shaken in release build.
- APK arm64: **19.3 MB** (20-4 baseline) → **18.5 MB** (~800 KB reduction, exceeds 200–400 KB audit target).

### Completion Notes List

- Removed `phosphoricons_flutter`; bundled two app-owned subset TTFs (18 Regular + 3 Fill glyphs).
- Created `lib/core/icons/phosphor_icons.dart` with `@staticIconProvider` classes — no `fontPackage`.
- Migrated 16 `lib/` + 9 `test/` files; dev FAB swapped `speedometer` → `chartBar`.
- Added regeneration scripts: `tool/subset_phosphor_icons.ps1` / `.sh`.
- Version bumped to `0.10.0+20`; DEPENDENCIES.md + README updated.
- `flutter test --exclude-tags slow`: 832 passed, 2 skipped.
- `flutter analyze lib/core/icons/ lib/presentation/`: clean (1 pre-existing info in profile_cubit.dart).

### File List

- `assets/fonts/Phosphor-Regular-subset.ttf` (NEW)
- `assets/fonts/Phosphor-Fill-subset.ttf` (NEW)
- `lib/core/icons/phosphor_icons.dart` (NEW)
- `tool/subset_phosphor_icons.ps1` (NEW)
- `tool/subset_phosphor_icons.sh` (NEW)
- `pubspec.yaml`
- `pubspec.lock`
- `docs/DEPENDENCIES.md`
- `README.md`
- `lib/presentation/widgets/app_bottom_nav.dart`
- `lib/presentation/widgets/activity_stats_row.dart`
- `lib/presentation/widgets/display_name_editor_row.dart`
- `lib/presentation/widgets/goal_ring.dart`
- `lib/presentation/widgets/menu_nav_row.dart`
- `lib/presentation/widgets/profile_info_row.dart`
- `lib/presentation/widgets/secondary_screen_header.dart`
- `lib/presentation/widgets/settings_preference_row.dart`
- `lib/presentation/widgets/trend_chip.dart`
- `lib/presentation/widgets/trends_average_stats_row.dart`
- `lib/presentation/widgets/trends_insight_cards.dart`
- `lib/presentation/widgets/trends_peak_day_card.dart`
- `lib/presentation/widgets/unit_option_picker_sheet.dart`
- `lib/presentation/widgets/week_trophy_badge.dart`
- `lib/presentation/onboarding/onboarding_shell.dart`
- `lib/presentation/screens/about_screen.dart`
- `test/presentation/screens/app_scaffold_test.dart`
- `test/presentation/widgets/activity_stats_row_test.dart`
- `test/presentation/widgets/secondary_screen_header_test.dart`
- `test/presentation/widgets/trend_chip_test.dart`
- `test/presentation/widgets/trends_average_stats_row_test.dart`
- `test/presentation/widgets/trends_peak_day_card_test.dart`
- `test/presentation/widgets/unit_option_picker_sheet_test.dart`
- `test/dev/chart_benchmark_dev_fab.dart`
- `test/widget_test.dart`

## Change Log

- 2026-06-21 — Story 20-5 created: comprehensive Phosphor subsetting guide — package removal, icon audit, pyftsubset workflow, Epic 20 version bump.
- 2026-06-21 — Story 20-5 implemented: local Phosphor subset fonts, import migration, APK ~800 KB reduction, version `0.10.0+20`.
