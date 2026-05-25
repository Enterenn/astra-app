# Story 1.1: Flutter Project Initialization

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **builder**,
I want the Flutter project scaffold initialized from the repo root with locked dependencies,
So that I have a clean, runnable mobile app foundation aligned with ASTRA architecture.

## Acceptance Criteria

1. **Given** the `astra-app` repo root contains planning docs but no Flutter scaffold yet (`pubspec.yaml` absent)
   **When** `flutter create . --org com.astraapp --project-name astra_app --platforms=android,ios --android-language=kotlin --empty` is run and locked `pubspec.yaml` dependencies are applied
   **Then** the app builds and launches on Android and/or iOS with Dart package name `astra_app` and bundle ID `com.astraapp`
   **And** `LICENSE` (Apache 2.0) exists in repo root per FR-26 *(already present — verify, do not replace)*

2. **Given** the project is initialized
   **When** a developer runs `flutter analyze`
   **Then** no analyzer errors are introduced by the scaffold setup

## Tasks / Subtasks

- [x] **Sub-task A — Flutter scaffold** (AC: #1)
  - [x] Confirm Flutter stable ≥ 3.44.0 (`flutter --version`)
  - [x] From repo root, run `flutter create .` with locked flags (see Dev Notes)
  - [x] Verify generated `pubspec.yaml` has `name: astra_app`
  - [x] Verify Android `applicationId` = `com.astraapp` in `android/app/build.gradle.kts` (or equivalent)
  - [x] Verify iOS bundle identifier = `com.astraapp` in Xcode project / `ios/Runner.xcodeproj`
  - [x] Confirm existing repo content preserved: `docs/`, `_bmad-output/`, `README.md`, `LICENSE`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Locked dependencies** (AC: #1)
  - [x] Replace/extend `pubspec.yaml` with locked dependency block from Architecture (see below)
  - [x] Run `flutter pub get` — must succeed with zero resolution errors
  - [x] Do **not** import or wire any new packages in Dart code yet (deps declared only)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Build & analyze verification** (AC: #1, #2)
  - [x] Run `flutter analyze` — zero issues
  - [x] Run `flutter build apk --debug` (or `flutter run` on device/emulator) — succeeds
  - [x] Optional: `flutter build ios --no-codesign` if macOS/Xcode available
  - [x] Document Flutter/Dart version used in Dev Agent Record
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

### Review Findings

- [x] [Review][Decision] **`pubspec.lock` — commit or keep gitignored?** — Resolved: **A** — added `!pubspec.lock` exception to `.gitignore`; lock file committed for reproducible builds.
- [x] [Review][Decision] **`flutter_lints` version drift** — Resolved: **B** — kept `^6.0.0` (Flutter 3.44 template default); spec baseline updated below.
- [x] [Review][Decision] **SDK constraint drift** — Resolved: **A** — kept `sdk: ^3.12.0`; spec baseline updated to match Flutter 3.44 / Dart 3.12.
- [x] [Review][Decision] **Gradle JVM heap 8G** — Resolved: **B** — kept `-Xmx8G` (32 GB dev workstation).

- [x] [Review][Patch] **Missing `test/widget_test.dart`** [test/widget_test.dart] — added widget test for empty app shell.
- [x] [Review][Patch] **`pubspec.yaml` missing trailing newline** [pubspec.yaml:28] — fixed.
- [x] [Review][Patch] **Story completion metadata incomplete** [1-1-flutter-project-initialization.md] — status, checkboxes, Dev Agent Record, and File List updated.

- [x] [Review][Defer] **Plugin manifest permissions not wired** [android/app/src/main/AndroidManifest.xml] — deferred, pre-existing; workmanager/pedometer/notifications wiring deferred to Epic 2 per story scope.
- [x] [Review][Defer] **Legacy Kotlin Gradle Plugin warnings** [android/gradle.properties] — deferred, pre-existing; `builtInKotlin=false` / `kotlin.incremental=false` tracked for Epic 5 Story 5.2.

## Dev Notes

### Story scope boundary (critical)

**In scope for 1.1:**
- Official `--empty` Flutter scaffold at repo root
- Locked `pubspec.yaml` name + dependencies declared (not wired)
- Build/analyze verification
- LICENSE presence check

**Out of scope — defer to later stories:**
- `lib/core/`, `lib/data/`, `lib/presentation/` folder structure → Story 1.2+
- Design tokens, themes, fonts → Story 1.2
- `AppDependencies`, Cubits, repositories → Epic 2+
- Release manifest INTERNET removal → Epic 5 (Story 5.2)
- `docs/DEPENDENCIES.md` full audit → when packages are actually used (Epic 2+); note declared deps only if file exists

Do not over-implement. Story 1.1 ends with a **runnable empty app** + **declared deps**, not ASTRA features.

### Mandatory dev workflow

Follow [`docs/project-context.md`](../../../docs/project-context.md):

- One commit per sub-task (A, B, C) after Baptiste review
- Review brief format required before each commit
- No push unless explicitly requested

### Current repo state (pre-implementation)

| Item | State |
|------|-------|
| `pubspec.yaml` | **Absent** — greenfield Flutter init |
| `lib/` | **Absent** |
| `LICENSE` | **Present** — Apache 2.0 at repo root; verify only |
| `README.md` | Present — notes "Pre-implementation" |
| `.gitignore` | Already contains Flutter/Dart entries |
| Planning artifacts | `docs/`, `_bmad-output/` coexist at repo root per Architecture |

### Flutter create command (locked — D-18, D-26)

Run from `astra-app/` repo root:

```bash
flutter channel stable
flutter upgrade
flutter create . \
  --org com.astraapp \
  --project-name astra_app \
  --platforms=android,ios \
  --android-language=kotlin \
  --empty
```

**Naming locks:**
| Concept | Value |
|---------|-------|
| Repo / product | `astra-app` |
| Dart package (`pubspec.yaml` `name:`) | `astra_app` |
| DB file (future) | `astra_app.db` |
| Bundle ID | `com.astraapp` |

**`flutter create .` in non-empty repo:** Flutter merges scaffold alongside existing files. Do not delete `docs/` or `_bmad-output/`. Review `git status` carefully — commit only Flutter scaffold + intentional changes, not accidental overwrites.

### Locked `pubspec.yaml` (apply after scaffold)

Replace the generated `pubspec.yaml` content with this locked baseline (verify versions resolve on target machine):

```yaml
name: astra_app
description: ASTRA — local-first health hub
publish_to: 'none'

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^9.1.1
  sqflite: ^2.4.2+1
  path: ^1.9.1
  uuid: ^4.4.0
  workmanager: ^0.9.0+3
  pedometer: ^4.2.0
  permission_handler: ^12.0.1
  fl_chart: ^1.2.0
  flutter_local_notifications: ^21.0.0
  share_plus: ^13.1.0
  path_provider: ^2.1.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

Keep default `--empty` `lib/main.dart` minimal (counter demo is removed by `--empty`). No package imports in Dart until Story 1.2+.

### Verification commands

```bash
flutter --version          # expect stable 3.44.x, Dart 3.12.x
flutter pub get
flutter analyze            # zero issues required
flutter run                # launches empty Material app
flutter build apk --debug  # Android build smoke test
```

### What `--empty` provides

- Minimal `lib/main.dart` (replaceable shell — full `lib/` layering comes later)
- `android/` (Kotlin), `ios/` (Swift, SwiftPM default on Flutter 3.44+)
- `analysis_options.yaml` + `flutter_lints`
- Default widget test scaffold in `test/widget_test.dart`

Update or remove the default widget test if it fails against the empty template — analyzer must stay clean.

### Anti-patterns (do not do in 1.1)

- ❌ Scaffold full `lib/core|data|presentation/` tree — premature for this story
- ❌ Add Riverpod, GoRouter, Dio, Firebase, analytics, or HTTP packages
- ❌ Wire `AppDependencies` or any Cubit
- ❌ Replace or regenerate `LICENSE` — already valid Apache 2.0
- ❌ Delete or relocate `docs/`, `_bmad-output/`, planning artifacts
- ❌ Batch sub-tasks A+B+C into one commit
- ❌ Commit without Baptiste review approval

### Epic 1 cross-story context

Epic 1 delivers trust onboarding + app shell. Story sequence:

| Story | Focus |
|-------|-------|
| **1.1** (this) | Flutter scaffold + locked deps |
| 1.2 | Design tokens, fonts, theme system |
| 1.3 | App scaffold + 3-tab navigation |
| 1.4 | user_preferences persistence |
| 1.5 | Trust-first onboarding flow |

No prior story exists — this is the first implementation story in the project.

### Project Structure Notes

Post-1.1 expected tree (minimal):

```
astra-app/
├── LICENSE                 # unchanged
├── README.md               # unchanged (may note "scaffold initialized" in commit msg only)
├── pubspec.yaml            # name: astra_app + locked deps
├── analysis_options.yaml   # from flutter create
├── lib/
│   └── main.dart           # empty template entry
├── android/                # com.astraapp
├── ios/                    # com.astraapp
├── test/
│   └── widget_test.dart    # default or adjusted
├── docs/                   # preserved
└── _bmad-output/           # preserved
```

Target `lib/` structure (Architecture) is documented for **future stories** — do not create these folders in 1.1:

```
lib/
├── core/          # Story 1.2+ / Epic 2
├── data/          # Epic 2
├── presentation/  # Story 1.2+
└── dev/           # Epic 3
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Story 1.1]
- [Source: _bmad-output/planning-artifacts/architecture.md — Starter Template Evaluation, Sprint 0 Initialization Reference, D-18, D-26]
- [Source: _bmad-output/planning-artifacts/implementation-readiness-report-2026-05-25.md — Story 1.1 readiness]
- [Source: docs/project-context.md — review-before-commit workflow]
- [Source: README.md — Developer setup section]

## Dev Agent Record

### Agent Model Used

Composer (code review workflow, 2026-05-25)

### Debug Log References

- Code review diff range: `6198f40..HEAD` (4 implementation commits)
- Post-review patch verification: `flutter analyze` (0 issues), `flutter test` (1 passed)

### Completion Notes List

- Flutter **3.44.0** stable / Dart **3.12.0** on Windows dev workstation (32 GB RAM)
- Sub-tasks A/B/C delivered in separate commits on `main` before code review
- Code review resolved: `pubspec.lock` tracked, widget test added, spec baseline aligned (`sdk ^3.12.0`, `flutter_lints ^6.0.0`)
- Android debug APK build verified during implementation; iOS build not attempted (Windows host)
- Gradle heap kept at 8G per dev machine spec

### File List

- `.gitignore` (modified — `!pubspec.lock` exception)
- `.metadata` (new)
- `pubspec.yaml` (new)
- `pubspec.lock` (new, tracked)
- `lib/main.dart` (new)
- `analysis_options.yaml` (new)
- `test/widget_test.dart` (new)
- `android/**` (new)
- `ios/**` (new)
- `_bmad-output/implementation-artifacts/stories/1-1-flutter-project-initialization.md` (new, updated)
- `_bmad-output/planning-artifacts/architecture.md` (Epic 5 KGP note)
- `_bmad-output/planning-artifacts/epics.md` (Epic 5 KGP note)

## Technical Requirements

1. Flutter stable channel ≥ **3.44.0**; Dart **3.12.x** bundled with that release
2. `--empty` template only — no skeleton/demo app UI
3. Platforms: **android, ios** only — no web/desktop
4. Android language: **Kotlin**
5. Package name `astra_app`; bundle ID `com.astraapp` on both platforms
6. All locked dependencies declared in `pubspec.yaml`; zero analyzer errors after `flutter pub get`
7. Existing Apache 2.0 `LICENSE` retained at repo root

## Architecture Compliance

| Decision | Requirement for 1.1 |
|----------|---------------------|
| D-18 | Bundle ID `com.astraapp` |
| D-26 | Repo `astra-app`, Dart package `astra_app`, DB name `astra_app.db` (DB not created yet) |
| Starter template | Official `flutter create --empty` — no third-party boilerplates |
| Locked deps | sqflite, flutter_bloc, workmanager, pedometer, permission_handler, fl_chart, flutter_local_notifications, share_plus, path_provider, uuid, path — **declare only** |
| Excluded packages | No http, dio, firebase_*, analytics, Hive, Isar, Riverpod |
| Repo layout | Git root = Flutter app root; planning docs remain alongside |

## Library & Framework Requirements

| Package | Version | 1.1 action |
|---------|---------|------------|
| flutter_bloc | ^9.1.1 | Declare in pubspec |
| sqflite | ^2.4.2+1 | Declare |
| workmanager | ^0.9.0+3 | Declare |
| pedometer | ^4.2.0 | Declare |
| permission_handler | ^12.0.1 | Declare |
| fl_chart | ^1.2.0 | Declare |
| flutter_local_notifications | ^21.0.0 | Declare |
| share_plus | ^13.1.0 | Declare |
| path_provider | ^2.1.5 | Declare |
| uuid | ^4.4.0 | Declare |
| path | ^1.9.1 | Declare |
| flutter_lints | ^6.0.0 | dev — Flutter 3.44 template default |

**Flutter 3.44 note:** iOS uses Swift Package Manager by default (SwiftPM replaces CocoaPods). First `flutter run` / `flutter build ios` may update Xcode project — expected; document if iOS build is attempted.

## Testing Requirements

- `flutter analyze` — **zero issues** (AC #2)
- Default `test/widget_test.dart` — must pass or be minimally adjusted for empty app; run `flutter test`
- No new feature tests required for 1.1
- Physical device not required for 1.1 (unlike WorkManager spike in Epic 2)

## Latest Tech Information

- **Flutter 3.44.0** stable released May 2026 (Google I/O); includes Dart 3.12.0
- **`flutter create --empty`**: minimal app, no counter demo — correct for ASTRA
- **SwiftPM default on iOS** (3.44+): CLI auto-migrates Xcode project; no manual CocoaPods setup required for new projects
- **APK size**: empty Flutter 3.38+ APKs are larger than pre-3.38 — expected, not a 1.1 defect (NFR-2 addressed in later optimization stories)
- **KGP / Built-in Kotlin (deferred):** First build with locked deps may warn that `pedometer`, `share_plus`, `workmanager_android` apply legacy Kotlin Gradle Plugin. Non-blocking in 1.1 (`android.builtInKotlin=false`). Tracked for **Epic 5 Story 5.2** — see `epics.md` and `architecture.md` gap notes.
- Verify local Flutter version before init; run `flutter upgrade` if below 3.44

## Project Context Reference

Mandatory for all stories — [`docs/project-context.md`](../../../docs/project-context.md):

- Review-before-commit gate (3 sub-task commits for this story)
- Commit message convention: `type(scope): imperative summary`
- Story completion: update `docs/DEPENDENCIES.md` when packages are **used** (not required for declare-only in 1.1 unless file already exists and team wants entries)

## Story Completion Status

- Status: **done**
- Code review completed 2026-05-25 — all decision-needed and patch findings resolved
- Epic 1 status: **in-progress** (story 1.1 complete; 1.2 next)
- Next story after completion: **1-2-design-tokens-and-theme-system**
