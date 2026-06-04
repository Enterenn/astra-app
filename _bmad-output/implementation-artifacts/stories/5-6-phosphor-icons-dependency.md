# Story 5.6: Phosphor Icons Dependency

Status: review

<!-- Epic 5 — dependency-only story before 5.7 nav/icon wiring. Ultimate context engine analysis completed — comprehensive developer guide created. -->

## Story

As a **builder**,
I want Phosphor icons available app-wide,
So that navigation and screens match the Figma mockups.

## Acceptance Criteria

1. **Given** locked `pubspec.yaml`
   **When** `phosphor_flutter` is added at a compatible version
   **Then** `flutter pub get` succeeds
   **And** `docs/DEPENDENCIES.md` is updated (health pipeline / network policy unchanged)

2. **Given** the package is installed
   **When** `flutter analyze` runs
   **Then** no **new** analyzer issues (existing `info` in `data_lifecycle_service.dart` only is acceptable)

**Prerequisite for:** Story 5.7 (four-tab floating nav + Phosphor tab icons).

## Tasks / Subtasks

- [x] **Sub-task A — Add dependency** (AC: #1)
  - [x] Add `phosphor_flutter: ^2.1.0` under `dependencies:` in `pubspec.yaml` (match architecture D-27 / `architecture.md` sample)
  - [x] Run `flutter pub get` and commit `pubspec.lock` (lockfile is tracked per Story 1.1)
  - [x] Confirm resolve: locked version `2.1.0` in `pubspec.lock`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Document dependency** (AC: #1)
  - [x] Add a **Phosphor Icons** subsection under `## Dart / Flutter packages` in `docs/DEPENDENCIES.md`:
    - Package name, locked version, license (MIT per pub.dev), purpose (Figma-aligned iconography)
    - **Network:** No — icon font bundled in package; no runtime fetch
    - **Usage scope:** Story 5.6 = install only; tab/screen wiring starts in 5.7+
    - **API note for 5.7:** `PhosphorIconsRegular` — `footprints`, `chartBar`, `database`, `user` (UX §1.6)
    - **Deferred icon migration:** Material `Icons.*` elsewhere remain until stories 5.7–5.12 call them out
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Verification** (AC: #2)
  - [x] `flutter analyze` — zero new issues vs baseline (6 existing `prefer_initializing_formals` info in `data_lifecycle_service.dart`)
  - [x] `flutter test` — full suite green (dependency-only; no `lib/` edits expected)
  - [x] Optional sanity (not required for AC): create a **temporary** dev-only import in a scratch file or run `dart pub deps` — **do not** commit scratch code
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope:**
- `pubspec.yaml` + `pubspec.lock`
- `docs/DEPENDENCIES.md` Phosphor entry
- `flutter pub get`, `flutter analyze`, `flutter test`

**Out of scope — defer to later stories:**

| Deferred item | Story |
|---------------|-------|
| Replace `NavigationBar` Material tab icons | **5.7** |
| Four-tab shell (TODAY · TRENDS · DATA · PROFIL) | **5.7** |
| Floating pill nav styling | **5.7** |
| Today stats row icons (`Flame`, `MapPin`, `Clock`) | **5.9** + **Epic 6** values |
| Data screen action icons (export/import/purge) | **5.10** |
| Profil / Appearance icons | **5.11** |
| Cross-screen Material → Phosphor sweep | **5.12** |
| `phosphoricons_flutter` package switch | **Not planned** — architecture locks `phosphor_flutter` |

**Critical:** Do **not** edit `lib/` in this story. Adding an import anywhere triggers test/widget expectations and scope creep into 5.7. Story 5.6 ends when the package resolves cleanly and docs are updated.

### Pipeline position (Epic 5)

```text
5.5 KGP / Built-in Kotlin ✅
        │
        v
5.6 Phosphor dependency   ← THIS STORY (install only)
        │
        v
5.7 Four-tab floating nav + Phosphor tab icons
        │
        v
5.8 Accent presets → 5.9 Today → 5.10 Data → 5.11 Profil → 5.12 Cohesion → 5.13 (optional)
```

### Architecture contracts

| Source | Requirement for 5.6 |
|--------|---------------------|
| D-27 | `phosphor_flutter` regular weight for tabs and primary actions (consumption starts 5.7) |
| D-10 | Four-tab Phosphor icons listed in UX — **implementation** is 5.7, not 5.6 |
| UX §1.6 | Default **24dp**; tab set: Footprints · ChartBar · Database · User |
| Network policy | No runtime network; Phosphor fonts ship inside package — consistent with Phase 0 |
| `uses-material-design: true` | **Keep** — Material widgets remain; Phosphor is additive |

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 5.6 changes | Must preserve |
|------|---------------|------------------|---------------|
| `pubspec.yaml` | No Phosphor dep (Phase 0 Material icons) | Add `phosphor_flutter: ^2.1.0` | All existing deps/versions unless pub get forces unrelated resolution (unlikely) |
| `pubspec.lock` | Tracked | New transitive entries for phosphor | Do not drop unrelated pins |
| `docs/DEPENDENCIES.md` | Fonts, health pipeline, KGP §5.5 | New Phosphor package row + usage note | Existing tables and network policy |
| `lib/presentation/screens/app_scaffold.dart` | 3 tabs: `Icons.circle_outlined`, `bar_chart_outlined`, `shield_outlined` | **No change in 5.6** | Tests in `app_scaffold_test.dart` still expect current labels/icons |
| `lib/core/constants/astra_theme.dart` | `NavigationBarThemeData` for 3-tab shell | **No change in 5.6** | Theme tokens used by widget tests |
| Android KGP patch pipeline | `settings.gradle.kts` auto-patch | **No change** | Story 5.5 regression guard |

### Package selection (verified 2026-06-04)

| Package | Version | Decision |
|---------|---------|----------|
| **`phosphor_flutter`** | **^2.1.0** (locks **2.1.0**) | **Use** — matches `architecture.md`, epics, sprint proposal; `flutter pub get` + `flutter analyze` succeed on Flutter 3.44 / Dart 3.12 |
| `phosphoricons_flutter` | 1.0.0 | **Do not adopt** without architecture/PRD amendment — community fork for Dart 3 `IconData` final-class issue; not in locked planning artifacts |

**API preview for Story 5.7** (do not implement here):

```dart
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Regular weight, 24dp default per UX §1.6
PhosphorIconsRegular.footprints
PhosphorIconsRegular.chartBar
PhosphorIconsRegular.database
PhosphorIconsRegular.user
```

Use as `Icon(PhosphorIconsRegular.footprints)` or `PhosphorIcon(PhosphorIconsRegular.footprints)` per widget needs in 5.7.

### Regression guardrails

- **Do not** modify `android/`, Gradle, or KGP patch scripts — unrelated to icon font.
- **Do not** change `AppScaffold`, routes, cubits, or onboarding.
- **Do not** remove `uses-material-design: true` from `pubspec.yaml`.
- After `pub get`, run `flutter test` — WM/FGS/DB tests must stay green.
- `flutter build apk --debug` is optional for 5.6; required again when 5.7 touches UI on device.

### Project Structure Notes

- Story file: `_bmad-output/implementation-artifacts/stories/5-6-phosphor-icons-dependency.md`
- Implementation touches repo root `pubspec.yaml`, `pubspec.lock`, `docs/DEPENDENCIES.md` only

### References

- [Source: _bmad-output/planning-artifacts/epics.md § Story 5.6]
- [Source: _bmad-output/planning-artifacts/architecture.md — D-27, pubspec sample ~line 520]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md §1.6 Iconography]
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-06-04.md — execution order, Phosphor lock]
- [Source: _bmad-output/implementation-artifacts/stories/5-5-built-in-kotlin-plugin-migration.md — review/commit workflow]
- [Source: _bmad-output/implementation-artifacts/stories/1-3-app-scaffold-and-bottom-navigation.md — Material icons Phase 0 deferral]
- [pub.dev phosphor_flutter 2.1.0](https://pub.dev/packages/phosphor_flutter)
- [docs/project-context.md](../../../docs/project-context.md) — review-before-commit, DEPENDENCIES updates

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- `flutter pub get` — success; `phosphor_flutter` 2.1.0 in lockfile
- `flutter analyze` — 6 pre-existing `info` in `data_lifecycle_service.dart` only (exit 1 from info count; no new issues)
- `flutter test` — full suite green

### Completion Notes List

- Added `phosphor_flutter: ^2.1.0` to `pubspec.yaml`; lockfile pins 2.1.0. No `lib/` changes (scope boundary for 5.7).
- Documented Phosphor in `docs/DEPENDENCIES.md` with network policy, 5.7 API preview, deferred Material migration.
- AC #1 and #2 satisfied; prerequisite ready for Story 5.7 four-tab nav.

### File List

- `pubspec.yaml`
- `pubspec.lock`
- `docs/DEPENDENCIES.md`

### Change Log

- 2026-06-04: Story 5.6 — add `phosphor_flutter` dependency and DEPENDENCIES documentation (install-only; no lib edits).

## Previous Story Intelligence

**Story 5.5 (Built-in Kotlin / KGP)** — patterns to carry forward:

- Sub-tasks with **stop → review brief → Baptiste OK → commit** (mandatory per `docs/project-context.md`)
- `docs/DEPENDENCIES.md` updated whenever packages change
- `pubspec.lock` committed with `pubspec.yaml`
- Infra-only discipline: no drive-by `lib/` edits
- Verification baseline: `flutter analyze` (6 pre-existing info only), full `flutter test` green, Android builds KGP-clean

**Not applicable from 5.5:** Gradle, pub-cache patches, `android/gradle.properties`.

**Story 1.3** explicitly deferred Phosphor to Epic 5 — Material `Icons.*_outlined` in `app_scaffold.dart` was intentional. Replacing them is **5.7**, not 5.6.

## Git Intelligence Summary

Recent commits (2026-06-04) are planning/docs alignment for Epic 5/6/7 execution order — no in-flight Phosphor work:

- `8864bc8` — docs(planning): align Epic 5/6/7 IDs with execution order
- `91b57cc` — docs(planning): Figma 4-tab sprint change approved
- `e2b6c6e` / `cd8d83a` — Story 5.5 KGP migration complete

Safe to add `phosphor_flutter` without conflicting dependency work.

## Latest Tech Information

| Topic | Detail |
|-------|--------|
| `phosphor_flutter` 2.1.0 | Latest on pub.dev (2024-05); MIT; 772+ icons, weights thin/light/regular/bold/fill |
| Dart 3.12 / Flutter 3.44 | `flutter pub add phosphor_flutter:^2.1.0` resolves; `flutter analyze` introduces **no** new issues when package is present but unused in `lib/` |
| `phosphoricons_flutter` 1.0.0 | Newer community package (May 2026) — **out of scope** unless planning docs amended |
| Icon import | `package:phosphor_flutter/phosphor_flutter.dart` |
| v2 API | `PhosphorIconsRegular.iconName` (not v1 `PhosphorIcons.iconStyle`) |

## Project Context Reference

Follow [`docs/project-context.md`](../../../docs/project-context.md):

- One commit per sub-task after Baptiste review
- Update `docs/DEPENDENCIES.md` when packages added
- No push unless Baptiste requests
- Story completion: all AC verified; state how in final review brief
