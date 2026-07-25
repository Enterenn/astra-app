---
title: 'Remove Material Icons from build'
type: 'chore'
created: '2026-06-06'
status: 'done'
route: 'one-shot'
---

## Intent

**Problem:** The debug/release build still bundles `MaterialIcons-Regular.otf` (~1.6 MB) via `uses-material-design: true`, even though the app UI uses Phosphor icons exclusively.

**Approach:** Audit all `Icons.*` usages, migrate the single remaining dev-only reference to Phosphor, and set `uses-material-design: false` to stop bundling the Material Icons font.

## Suggested Review Order

1. [pubspec.yaml](pubspec.yaml) — confirm `uses-material-design: false` and no Material Icons asset entry
2. [lib/dev/chart_benchmark_dev_fab.dart](lib/dev/chart_benchmark_dev_fab.dart) — sole former `Icons.*` usage replaced with Phosphor
3. [build/app/intermediates/flutter/debug/flutter_assets/FontManifest.json](build/app/intermediates/flutter/debug/flutter_assets/FontManifest.json) — verify MaterialIcons absent after rebuild

## Code Map

- `pubspec.yaml` — `uses-material-design` flag controls Material Icons font bundling
- `lib/dev/chart_benchmark_dev_fab.dart` — debug-only KPI-01 FAB; had the only `Icons.speed` reference
- `lib/presentation/**/*.dart` — all production icons already use `PhosphorIconsRegular` / `PhosphorIconsFill`

## Tasks & Acceptance

**Execution:**
- [x] `lib/dev/chart_benchmark_dev_fab.dart` — replace `Icons.speed` with `PhosphorIconsRegular.speedometer`
- [x] `pubspec.yaml` — set `uses-material-design: false`

**Acceptance Criteria:**
- Given a full codebase search, when scanning for `Icons.` references, then zero production usages remain (dev file migrated)
- Given `uses-material-design: false`, when building the app, then `FontManifest.json` contains no MaterialIcons entry
- Given the change, when running `flutter analyze`, then no new errors are introduced

## Verification

**Commands:**
- `flutter pub get && flutter analyze` — expected: no new errors (pre-existing info/warnings only)
- `flutter test` — expected: no regressions from this change (4 pre-existing failures unrelated)
- Inspect `build/.../FontManifest.json` after build — expected: Figtree, Darker Grotesque, Phosphor fonts only
