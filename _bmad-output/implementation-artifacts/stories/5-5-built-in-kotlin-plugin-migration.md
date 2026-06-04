# Story 5.5: Built-in Kotlin Plugin Migration (KGP)

Status: done

<!-- Epic 5 entry story (user-confirmed 2026-06-02): run before 5.1–5.4 visual polish. Ultimate context engine analysis completed — comprehensive developer guide created. -->

## Story

As a **builder**,
I want Phase 0 Android plugins migrated off legacy Kotlin Gradle Plugin (KGP) application,
So that `flutter build` stays compatible with Flutter Built-in Kotlin and we do not accumulate Gradle debt from the start of the project.

## Acceptance Criteria

1. **Given** `flutter run` or `flutter build apk` on Android with current locked deps
   **When** the build completes after this story
   **Then** Flutter emits **no** warning that `pedometer`, `share_plus`, or `workmanager_android` apply KGP (field observation 2026-06-02)
   **And** any other Phase 0 plugin added in Epics 2–4 is included in the audit

2. **Given** plugin changelogs and [Flutter Built-in Kotlin migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)
   **When** compatible versions exist on pub.dev
   **Then** `pubspec.yaml` / lockfile are upgraded to those versions
   **And** `docs/DEPENDENCIES.md` records version bumps and rationale

3. **Given** no compatible plugin release exists
   **When** migration is blocked for a dependency
   **Then** an upstream issue is filed (or existing issue linked) per Flutter guidance
   **And** the story documents the blocker and temporary workaround in `docs/DEPENDENCIES.md` — no silent deferral

4. **Given** `android/gradle.properties` currently sets `android.builtInKotlin=false` (Story 1.1 scaffold workaround)
   **When** all audited plugins support Built-in Kotlin
   **Then** that flag is removed (or narrowed to a documented exception only)
   **And** `android.newDsl=false` is re-evaluated against Flutter 3.44+ defaults
   **And** `kotlin.incremental=false` is removed if no longer required

5. **Given** migration complete
   **When** `flutter build apk --debug` and `flutter build apk --release` run on CI or local
   **Then** both succeed without KGP incompatibility warnings
   **And** existing Android tests (`test/android/`, manifest tests) still pass

## Tasks / Subtasks

- [x] **Sub-task A — Plugin audit & version check** (AC: #1, #2)
  - [x] Run baseline build and capture KGP warnings:
    ```powershell
    flutter build apk --debug 2>&1 | Select-String -Pattern "Kotlin Gradle Plugin|KGP|builtInKotlin"
    ```
    Expected baseline (2026-06-03): warnings for `pedometer`, `share_plus`, `workmanager_android`.
  - [x] Audit **all** Phase 0 Android plugins from `pubspec.lock` (not only the three known warners). Scan each `android/build.gradle(.kts)` in pub-cache for `kotlin-android` / `org.jetbrains.kotlin.android`.
  - [x] Record audit table in Dev Agent Record (plugin name, locked version, KGP applied?, AGP9-aware?, action).
  - [x] Run `flutter pub outdated` for `pedometer`, `share_plus`, `workmanager`, `file_picker`, `permission_handler`, `flutter_local_notifications`, `sqflite`, `path_provider`.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Upgrade compatible pub releases** (AC: #2)
  - [x] Bump `pubspec.yaml` only where changelog confirms Built-in Kotlin / AGP 9 migration (verify on pub.dev + plugin `android/` build file after `flutter pub get`).
  - [x] Run `flutter pub get` and commit `pubspec.lock` (lockfile is tracked per Story 1.1 decision).
  - [x] Re-run debug build; note remaining KGP warners.
  - [x] Update `docs/DEPENDENCIES.md` with any version bumps + rationale.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — App-level Built-in Kotlin enablement** (AC: #4, #5)
  - [x] **App module is already migrated** — do not rework unless broken:
    - `android/app/build.gradle.kts` uses `kotlin { compilerOptions { jvmTarget = JVM_17 } }` and does **not** apply `kotlin-android`.
  - [x] Remove legacy opt-out flags from `android/gradle.properties` once plugin audit passes (Sub-task D):
    - Remove `android.builtInKotlin=false`
    - Remove `kotlin.incremental=false`
    - Re-evaluate `android.newDsl=false` — remove if build succeeds without it (Flutter 3.44+ default path).
  - [x] Remove unused KGP declaration from `android/settings.gradle.kts`:
    - Delete line: `id("org.jetbrains.kotlin.android") version "2.3.20" apply false`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Resolve blocking plugins** (AC: #1, #3, #5)
  - [x] For each plugin still applying KGP after Sub-task B, follow [plugin-author migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors):
    1. Remove `apply plugin: 'kotlin-android'` (or `id("org.jetbrains.kotlin.android")`).
    2. Replace `kotlinOptions { jvmTarget = ... }` with:
       ```groovy
       kotlin {
           compilerOptions {
               jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
           }
       }
       ```
       (Use `JVM_1_8` for plugins still on Java 8 — match existing `compileOptions`.)
  - [x] **Known blockers at audit time (2026-06-03)** — all at latest pub.dev, main branch not migrated:
    | Plugin | Locked version | KGP in pub cache | Upstream |
    |--------|----------------|------------------|----------|
    | `pedometer` | 4.2.0 | Yes (`apply plugin: 'kotlin-android'`) | File or link issue on [cachet.dk/pedometer](https://github.com/cph-cachet/flutter-plugins/tree/master/packages/pedometer) |
    | `share_plus` | 13.1.0 | Yes | Link [plus_plugins#3745](https://github.com/fluttercommunity/plus_plugins/issues/3745) or comment with ASTRA repro |
    | `workmanager_android` | 0.9.0+2 (transitive) | Yes | File on [flutter_workmanager](https://github.com/fluttercommunity/flutter_workmanager) using Flutter issue template |
  - [x] **Resolution order (mandatory):**
    1. Prefer official pub release or `dependency_overrides` → git ref with merged migration PR.
    2. If no release: apply plugin-author diff to pub-cache **via a committed repo script** (e.g. `scripts/patch_kgp_plugins.ps1` + `.sh`) so `flutter pub get && ./scripts/patch_kgp_plugins.*` is reproducible — **not** silent manual cache edits.
    3. Document every override/patch in `docs/DEPENDENCIES.md` with upstream issue URL and removal criteria.
  - [x] **Do not** fork plugins into `astra-app` unless Baptiste explicitly approves in review.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Verification & docs cleanup** (AC: #5)
  - [x] `flutter analyze` — zero issues
  - [x] `flutter test` — full suite green
  - [x] `flutter test test/android/android_manifest_test.dart`
  - [x] `flutter build apk --debug` and `flutter build apk --release` — **zero KGP warnings**
  - [x] Update `docs/DEPENDENCIES.md` § Android Built-in Kotlin / KGP (new subsection)
  - [x] Update `_bmad-output/implementation-artifacts/deferred-work.md` — mark KGP item resolved or document remaining upstream blockers (was Epic 7 Story 7.2; now Epic 5.5)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope:**
- Android Gradle / plugin KGP migration only
- `pubspec.yaml` / lockfile upgrades for plugin compatibility
- `android/gradle.properties`, `android/settings.gradle.kts` flag cleanup
- Reproducible patch/override strategy for unmigrated plugins
- `docs/DEPENDENCIES.md` audit trail
- Upstream issue filing/linking

**Out of scope — defer:**
- Visual polish (Stories 5.1–5.4)
- iOS / SwiftPM changes
- Release manifest INTERNET audit (Story 7.2)
- Functional changes to step pipeline, WorkManager, share, or notifications
- Upgrading Flutter SDK beyond current stable (3.44.0) unless required for plugin fix

### Pipeline position (Epic 5)

```text
Epic 4 complete ✅
        │
        v
5.5 KGP / Built-in Kotlin   ← THIS STORY (first in Epic 5)
        │
        v
5.6 Phosphor → 5.7 Nav → 5.8 Accent → 5.9 Today → 5.10 Data → 5.11 Profil → 5.12 Cohesion → 5.13 Animation (optional)
        │
        v
Epic 7 beta hardening (6.2 verifies release build still KGP-clean — no re-migration)
```

### Architecture contracts

| Source | Requirement for 5.5 |
|--------|---------------------|
| Story 1.1 discovery | KGP warnings for `pedometer`, `share_plus`, `workmanager_android`; workaround flags in `gradle.properties` |
| Epics §5.5 | Zero KGP warnings; upgrade path; upstream issues if blocked; no silent deferral |
| Epics §6.2 | KGP verification **not** re-done at beta — must be clean after 5.5 |
| Architecture gap note | Built-in Kotlin migration pulled forward from Epic 7.2 to Epic 5.5 (user 2026-06-02) |
| D-18 / project-context | One commit per sub-task; review brief before each commit; update DEPENDENCIES.md |

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 5.5 changes | Must preserve |
|------|---------------|------------------|---------------|
| `android/gradle.properties` | `android.newDsl=false`, `android.builtInKotlin=false`, `kotlin.incremental=false` | Remove KGP workaround flags when plugins clean | `org.gradle.jvmargs`, `android.useAndroidX=true` |
| `android/settings.gradle.kts` | AGP 9.0.1; declares `org.jetbrains.kotlin.android` 2.3.20 `apply false` | Remove KGP plugin declaration when enabling built-in Kotlin | `dev.flutter.flutter-plugin-loader`, `com.android.application` |
| `android/app/build.gradle.kts` | Already on built-in Kotlin DSL (`kotlin { compilerOptions }`); no `kotlin-android` plugin | Verify only — likely no change | FGS desugaring, `core-ktx`, namespace, signing |
| `pubspec.yaml` | Locked Phase 0 deps at versions in lockfile | Bump only for KGP-compatible releases | No new unrelated deps |
| `docs/DEPENDENCIES.md` | Health pipeline + fonts; no KGP section yet | Add KGP audit + version/patch notes | Existing permission/FGS tables |
| `test/android/android_manifest_test.dart` | Manifest permission tests for health FGS | Must still pass unchanged | No INTERNET assertion |

### Plugin audit snapshot (2026-06-03 — re-verify after `flutter pub get`)

| Plugin | Version | Applies KGP? | Notes |
|--------|---------|--------------|-------|
| `pedometer` | 4.2.0 | **Yes** | Primary blocker; latest pub.dev |
| `share_plus` | 13.1.0 | **Yes** | Primary blocker; latest pub.dev |
| `workmanager` → `workmanager_android` | 0.9.0+3 / 0.9.0+2 | **Yes** (android impl) | Primary blocker; latest pub.dev |
| `file_picker` | 12.0.0-beta.5 | Conditional | AGP9-aware: applies KGP only when `android.builtInKotlin=false` — **not a blocker** when flags removed |
| `permission_handler_android` | 13.0.1 | No | Java-only Android impl |
| `flutter_local_notifications` | 21.0.0 | No | Re-audit android subfolder |
| `sqflite_android` | 2.4.2+3 | No | Java |
| `path_provider_android` | (transitive) | No | Re-audit if warnings appear |

**Baseline build command output (2026-06-03):**
```
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP):
  pedometer, share_plus, workmanager_android
```

### App-level migration status

Story 1.1 deferred KGP; subsequent Kotlin work (Stories 2.8, 2.10) added **app-owned** Kotlin under `android/app/src/main/kotlin/` (FGS, method channels). Those files compile via the app module's built-in Kotlin setup — **do not** re-add `kotlin-android` to the app module.

Custom Kotlin files (preserve behavior):
- `HealthStepForegroundService.kt`
- `HealthForegroundChannel.kt`
- `BackgroundHealthCapabilityChannel.kt`
- `MainActivity.kt`

### Regression guardrails

- **Do not** change Dart ingestion, WorkManager callback, FGS, or share/export logic — build-only story.
- **Do not** remove `android/app` Kotlin sources or method channels.
- After flag removal, run `flutter test test/core/services/workmanager_callback_test.dart` — WM isolate bootstrap must still pass.
- Physical-device WM spike is **not** required for 5.5; CI + analyze + unit/widget tests suffice.

### Upstream issue template (when filing)

Use Flutter's template from [migration guide § Report incompatible KGP](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers#report-incompatible-kotlin-gradle-plugin-usage-to-plugin-authors):

**Title:** Migrate Plugin to Built-in Kotlin

**Body:** Include ASTRA repro: Flutter 3.44.0, AGP 9.0.1, plugin version, KGP warning text, link to plugin-author migration guide.

### Project Structure Notes

- Story files live in `_bmad-output/implementation-artifacts/stories/`
- Patch scripts (if needed) → `scripts/` at repo root (match existing tooling patterns)
- No changes under `lib/` expected unless a dependency upgrade forces API migration (unlikely for Gradle-only work)

### References

- [Source: _bmad-output/planning-artifacts/epics.md § Story 5.5]
- [Source: _bmad-output/planning-artifacts/epics.md § Story 7.2 — KGP verified in 5.5]
- [Source: _bmad-output/planning-artifacts/architecture.md — gap note line ~903]
- [Source: _bmad-output/implementation-artifacts/stories/1-1-flutter-project-initialization.md — KGP deferral]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md — legacy KGP item]
- [Source: docs/project-context.md — review-before-commit workflow]
- [Flutter Built-in Kotlin for app developers](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)
- [Flutter Built-in Kotlin for plugin authors](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors)
- [share_plus upstream #3745](https://github.com/fluttercommunity/plus_plugins/issues/3745)
- [Flutter ecosystem AGP 9 umbrella #181383](https://github.com/flutter/flutter/issues/181383)

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- Baseline KGP warning capture: 2026-06-03 local `flutter build apk --debug`
- Flutter SDK: 3.44.0 stable, Dart 3.12.0
- AGP: 9.0.1 (`android/settings.gradle.kts`)
- Sub-task A audit re-run: 2026-06-03 (this session)

**Baseline build output (confirmed):**
```
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): pedometer, share_plus, workmanager_android
Future versions of Flutter will fail to build if your app uses plugins that apply KGP.
```

**Plugin audit table (pub-cache scan, `android.builtInKotlin=false` baseline):**

| Plugin | Locked version | KGP applied? | AGP9-aware? | Action |
|--------|----------------|--------------|-------------|--------|
| `pedometer` | 4.2.0 | **Yes** (`apply plugin: 'kotlin-android'`) | No | Patch script (Sub-task D); file/link upstream issue |
| `share_plus` | 13.1.0 | **Yes** | No | Patch script; link [plus_plugins#3745](https://github.com/fluttercommunity/plus_plugins/issues/3745) |
| `workmanager_android` | 0.9.0+2 (via `workmanager` 0.9.0+3) | **Yes** | No | Patch script; file upstream on flutter_workmanager |
| `file_picker` | 12.0.0-beta.5 | Conditional | **Yes** — applies KGP only when `builtInKotlin=false` | No patch needed once flags removed |
| `permission_handler_android` | 13.0.1 | No (Java) | N/A | None |
| `flutter_local_notifications` | 21.0.0 | No (Java) | N/A | None |
| `sqflite_android` | 2.4.2+3 | No (Java) | N/A | None |
| `path_provider_android` | 2.3.1 | No (jnigen/Java, no `android/build.gradle`) | N/A | None |
| `flutter_plugin_android_lifecycle` | 2.0.35 | No (Java/Kotlin DSL, no KGP) | N/A | None |

**`flutter pub outdated` summary (KGP-relevant deps):**

| Package | Current | Latest | KGP fix via upgrade? |
|---------|---------|--------|----------------------|
| `pedometer` | 4.2.0 | 4.2.0 | **No** — already latest |
| `share_plus` | 13.1.0 | 13.1.0 | **No** — already latest |
| `workmanager` | 0.9.0+3 | 0.9.0+3 | **No** — already latest |
| `file_picker` | 12.0.0-beta.5 | 12.0.0-beta.5 | **No** — AGP9-aware already |
| `permission_handler` | 12.0.1 | 12.0.3 | No KGP impact (Java impl) |
| `flutter_local_notifications` | 21.0.0 | 21.0.0 | N/A |
| `sqflite` | 2.4.2+1 | 2.4.3 | No KGP impact (Java impl) |
| `path_provider` | 2.1.5 | 2.1.5 | N/A |

**Sub-task A conclusion:** No pub.dev upgrade resolves the three KGP warners. Migration path = Sub-task D patch script + Sub-task C flag removal after patches verified.

### Completion Notes List

- Sub-task B: No pub.dev release migrates the three KGP warners; `pubspec.yaml` unchanged.
- Sub-task D: Added `scripts/patch_kgp_plugins.ps1` + `.sh` with version-locked templates in `scripts/kgp-patches/`; upstream issues linked in DEPENDENCIES (no new issues filed — existing trackers sufficient).
- Sub-task C: Removed `android.builtInKotlin`, `android.newDsl`, `kotlin.incremental` from `gradle.properties`; removed KGP from `settings.gradle.kts`. App module unchanged.
- Code review fix (2026-06-03): Commit `242150d` had only removed `kotlin.incremental`; `builtInKotlin`/`newDsl` opt-outs were still present. Removed both flags; added automatic patch hook in `settings.gradle.kts`; aligned shell scripts with manifest + `PUB_CACHE`.
- Sub-task E: `flutter build apk --debug` and `--release` succeed with **zero** Flutter KGP plugin warnings; full test suite green (1101 tests); `flutter analyze` — 6 pre-existing `info` in `data_lifecycle_service.dart` only (no new issues).

### File List

- `android/gradle.properties` — removed legacy KGP opt-out flags; pins `kotlin_version=2.3.20` for Flutter/AGP built-in Kotlin toolchain
- `android/settings.gradle.kts` — removed `org.jetbrains.kotlin.android` plugin declaration; auto-applies pub-cache KGP patches before plugin load
- `scripts/patch_kgp_plugins.ps1` — pub-cache patch runner (Windows)
- `scripts/patch_kgp_plugins.sh` — pub-cache patch runner (Unix)
- `scripts/kgp-patches/manifest.json` — patch manifest
- `scripts/kgp-patches/pedometer-4.2.0-build.gradle` — built-in Kotlin template
- `scripts/kgp-patches/share_plus-13.1.0-build.gradle` — built-in Kotlin template
- `scripts/kgp-patches/workmanager_android-0.9.0+2-build.gradle` — built-in Kotlin template
- `scripts/README.md` — patch script usage
- `docs/DEPENDENCIES.md` — § Android Built-in Kotlin / KGP
- `_bmad-output/implementation-artifacts/deferred-work.md` — KGP item marked resolved
- `_bmad-output/implementation-artifacts/stories/5-5-built-in-kotlin-plugin-migration.md` — story completion
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — story → review

### Change Log

- 2026-06-03: Story 5.5 implementation — built-in Kotlin enabled; reproducible pub-cache patches for three blocking plugins; docs updated.
- 2026-06-03: Code review — removed remaining `builtInKotlin`/`newDsl` flags; Gradle auto-patch hook; script/manifest alignment.
- 2026-06-03: Pin `kotlin_version=2.3.20` in `gradle.properties` — silences Flutter KGP 2.2.10 deprecation warning on AGP 9 built-in Kotlin.

### Review Findings

- [x] [Review][Patch] AC #4 — `android.builtInKotlin=false` and `android.newDsl=false` still in `gradle.properties` despite prior commit message [`android/gradle.properties`]
- [x] [Review][Patch] Patch script not enforced on clean builds — added auto-apply in `android/settings.gradle.kts`
- [x] [Review][Patch] `patch_kgp_plugins.sh` ignored `manifest.json` — now reads manifest via Python
- [x] [Review][Patch] `patch_kgp_plugins.ps1` ignored `PUB_CACHE` — now honors env var
- [x] [Review][Patch] `pedometer` upstream tracker weak — linked Flutter #181383 in DEPENDENCIES.md
- [x] [Review][Patch] Dead `buildscript` KGP classpath in pedometer/share_plus patch templates — removed

## Previous Story Intelligence

Epic 4 last story (**4.9 Profile Initials**) established patterns relevant to workflow, not Gradle:

- Sub-tasks A→D with **stop → review brief → Baptiste OK → commit** between each
- `docs/DEPENDENCIES.md` updated when touching dependencies
- Story file Dev Agent Record filled on completion
- No drive-by refactors outside story scope

**Carry forward for 5.5:** Same review gate; this story is infra-only — review briefs should emphasize Gradle/KGP concepts for Baptiste's learning (what `builtInKotlin` means, why plugin cache patches are temporary).

## Git Intelligence Summary

Recent commits (2026-06-03) are Epic 4 polish + sprint sequencing docs — no Gradle changes:

- `05c3faa` — field feedback triage, Epic 5 before hotfix sequencing
- `4170155` / `1c18452` — Story 4.9 profile initials (My Data UI)

No conflicting in-flight Android build work. Safe to modify `android/gradle.properties` and plugin versions.

## Latest Tech Information

| Topic | Detail |
|-------|--------|
| Flutter 3.44.0 | Defaults `android.builtInKotlin=false` + `android.newDsl=false` via migrator (Issue #183910) — legacy KGP mode until ecosystem migrates |
| AGP 9.0.1 | Built-in Kotlin default; explicit `kotlin-android` plugin **conflicts** when `builtInKotlin=true` |
| KGP sunset | Opt-out removed in AGP 10.0 (expected 2026) — flags are temporary debt |
| Ecosystem status (2026-06) | Many community plugins still on `kotlin-android`; Flutter tracking via [#184836](https://github.com/flutter/flutter/issues/184836) |
| Pub-cache patch | Documented workaround in [#181383](https://github.com/flutter/flutter/issues/181383) for local verification — **must be scripted + documented** for ASTRA, not one-off manual edits |
| `file_picker` 12.0.0-beta.5 | Already AGP9-aware (conditional KGP) — model for what migrated plugins look like |

## Project Context Reference

Follow [`docs/project-context.md`](../../../docs/project-context.md):

- One commit per sub-task after Baptiste review
- Update `docs/DEPENDENCIES.md` when packages change or patches applied
- No push unless Baptiste requests
- Story completion: all AC verified; state how in final review brief
