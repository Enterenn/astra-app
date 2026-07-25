---
stepsCompleted: [1, 2, 3, 4]
status: complete
completedAt: 2026-06-18
scope: Refactoring v0.6.1 — branch `refacto`
baseVersion: 0.6.1+12
project_name: astra-app
inputDocuments:
  - planning-artifacts/refactoring-audit-master-v0.6.1.md
  - docs/project-context.md
  - planning-artifacts/epics.md
---

# astra-app — Refactoring Epic Breakdown (Epics 14–20)

## Overview

This document decomposes the consolidated refactoring master audit (`refactoring-audit-master-v0.6.1.md`) into implementable epics and stories for the dedicated **`refacto`** Git branch.

**Scope:** Post–Epic 13 brownfield refactoring — security hardening (P0/P1), targeted architecture fixes, 120 Hz performance, dependency slimming, deep architecture splits, i18n, and UX polish. Does **not** replace `epics.md` (Epics 1–13 product delivery).

**Execution order:** Strict priority P0 → P1 → P2 → P3. Do not start Epic 18+ until Epics 14–16 are stable.

**Diagnostic corrections applied (audit v0.6.1):**

| Flag | Item | Decision |
|------|------|----------|
| ❌ INEXACT | `AstraHorizontalRuler` debounce | No story — already snaps per graduation |
| ❌ INEXACT | Onboarding weight/height mandatory | No story — already skippable |
| ❌ CORRIGÉ | `IndexedStack` in `lib/presentation/trends/` | Target `app_scaffold.dart` instead |
| ➕ AJOUT | `_enqueueLifecycleTransition` deadlock | Story 14-2 |
| ➕ AJOUT | `share_plus` removable | Story 17-1 |
| ➕ AJOUT | `lib/dev/` → `test/dev/` (not `kDebugMode`) | Story 15-3 |

**Blocked dependencies:**

- Story **16-7** (cold-start shimmer) requires Story **15-2** (GoalRing → TodayCubit).
- Fast cubit unit tests (NFR-REF-04) require Story **16-1** (repository contracts).

## Development Workflow (all stories)

Every sub-task follows **review before commit**. See [`docs/project-context.md`](../../docs/project-context.md).

| Step | Who | Action |
|------|-----|--------|
| 1 | Agent | Complete one sub-task |
| 2 | Agent | Post review brief (what / why / how to verify / learn) + suggested commit message |
| 3 | Baptiste | Read diff, learn, reply **OK commit** (or request changes) |
| 4 | Agent | Commit only after explicit approval — **one commit per sub-task** |

## Versioning (refacto branch)

Bump `pubspec.yaml` + `README.md` at each **epic close** per `.cursor/rules/app-versioning.mdc`.

| Epic type | Semver | Build |
|-----------|--------|-------|
| Epic 14 (P0/P1 hotfix) | patch+1 | +1 |
| Epic 15 (P1 targeted) | patch+1 | +1 |
| Epic 16 (P2 perf + testability) | minor+1, patch=0 | +1 |
| Epic 17 (P2 deps) | patch+1 | +1 |
| Epic 18 (P3 deep arch) | minor+1, patch=0 | +1 |
| Epic 19 (P3 i18n) | minor+1, patch=0 | +1 |
| Epic 20 (P3 UX + APK) | minor+1, patch=0 | +1 |

Pre-1.0: remain on `0.x.y` — do not ship `1.0.0` until public launch.

## Requirements Inventory

### Functional Requirements (Refactoring)

REF-01: After a full data purge, the app must complete all post-purge refresh steps or surface a visible error — never leave the UI in a silent partial state (P0).

REF-02: Lifecycle pause/resume transitions must never deadlock; `_lifecycleTransitionInFlight` must always reset (P1).

REF-03: History goal resolution must use a single batch SQL query instead of N parallel `getGoalForLocalDay` calls (P1).

REF-04: GoalRing display-step persistence (`lastDisplayedSteps`) must live in `TodayCubit`/`TodayState`, not in the widget; `disableStepPersistence` flag removed (P1).

REF-05: Dev-only tooling under `lib/dev/` must be relocated to `test/dev/` so release bundles exclude them (P1).

REF-06: Bucket IDs must not depend on the `uuid` package; dependency removed from `pubspec.yaml` (P1).

REF-07: Cubits must depend on abstract repository contracts, not concrete classes (P2).

REF-08: Static inset shadows must not allocate `ImageFilter.blur` per frame; cache via `Picture.toImage()` (P2).

REF-09: Background tabs in `AppScaffold` must not repaint unnecessarily; `RepaintBoundary` per tab (P2).

REF-10: GoalRing animations must be isolated via `RepaintBoundary`; all controllers/timers disposed (P2).

REF-11: `TodayScreen` must use granular `BlocSelector` widgets instead of a global `BlocBuilder` (P2).

REF-12: Today must surface collection health (`isStale`, `permissionStatus`) and a clickable stale-data banner (P2).

REF-13: Cold start must show a loading shimmer until initial step data is ready (P2, after REF-04).

REF-14: CSV export must use `file_picker` direct write; `share_plus` removed (P2).

REF-15: `file_picker` must be pinned to exact version `12.0.0-beta.5` without caret (P2).

REF-16: Active nav item shape must use native `ClipPath`/`Path`; `figma_squircle` removed (P2).

REF-17: Live pipeline orchestration must be extracted from `_AstraAppState` into `AppLifecycleCoordinator` (P3).

REF-18: `UserPreferencesRepository` must split into settings vs health-metrics repositories (P3).

REF-19: `StepRepository` must split into ingestion, aggregation, and `CsvService` (P3).

REF-20: App must support `flutter_localizations` with English template ARB (P3).

REF-21: Hardcoded user-facing strings must migrate to generated l10n keys (P3).

REF-22: User locale choice (`en`/`fr`) must persist and apply at `MaterialApp` startup (P3).

REF-23: Onboarding must present product value before requesting activity permission (P3).

REF-24: Trends must show locally computed insight cards (weekly growth, active day, streak) (P3).

REF-25: Tab navigation must provide haptic feedback on change if not already present (P3).

REF-26: Charts must render via native `CustomPainter` instead of `fl_chart` (P3).

REF-27: Phosphor icons must load only required `.ttf` subsets from `/assets/fonts/` (P3).

### Non-Functional Requirements

NFR-REF-01: UI must sustain 120 Hz on Impeller — minimize per-frame GPU allocations and unnecessary widget rebuilds.

NFR-REF-02: Async lifecycle and purge flows must never fail silently; errors logged and surfaced to the user.

NFR-REF-03: Release APK size must be measured (`flutter build apk --release --analyze-size`) before and after dependency changes.

NFR-REF-04: Cubit unit tests must run without opening SQLite (`sqflite_common_ffi`) once contracts exist.

NFR-REF-05: Presentation layer must not read/write repositories directly from widgets (Clean Architecture).

NFR-REF-06: Essential packages (`sqflite`, `pedometer`, `workmanager`, `permission_handler`, `flutter_local_notifications`, `path_provider`, `package_info_plus`, `flutter_bloc`) must not be replaced.

### Additional Requirements

- All work on branch **`refacto`**; merge to main only after epic-level review.
- Baseline measurement before Epic 17 dependency removals.
- `AstraHorizontalRuler` (`lib/presentation/widgets/astra_horizontal_ruler.dart`): **no debounce work** — audit claim disproven.
- `lib/dev/` tree-shaking via `kDebugMode` is **insufficient** — physical relocation required.
- Epic 19 (i18n) runs **after** P1/P2 architecture stabilisation to avoid migrating strings in files being refactored.

### UX Design Requirements

UX-REF-01: Stale-data banner (`StatusBannerVariant.staleCompact` / `staleFull`) must be tappable — CTA to refresh or Android settings.

UX-REF-02: Collection health indicator above GoalRing: "Collecte active ●", "Dernière sync il y a Xh ⚠", "Accès capteur révoqué ✕".

UX-REF-03: Cold-start flash ("0 / 10 000") replaced by shimmer until `TodayStatus.loading` resolves.

UX-REF-04: Onboarding intro emphasises "100% offline, no account" before permission prompt.

UX-REF-05: Trends insight cards use calm, local-only copy — no cloud/analytics implication.

### FR Coverage Map

| Requirement | Epic | Story |
|-------------|------|-------|
| REF-01 | 14 | 14-1 |
| REF-02 | 14 | 14-2 |
| REF-03 | 15 | 15-1 |
| REF-04 | 15 | 15-2 |
| REF-05 | 15 | 15-3 |
| REF-06 | 15 | 15-4 |
| REF-07 | 16 | 16-1 |
| REF-08 | 16 | 16-2 |
| REF-09 | 16 | 16-3 |
| REF-10 | 16 | 16-4 |
| REF-11 | 16 | 16-5 |
| REF-12 | 16 | 16-6 |
| REF-13 | 16 | 16-7 |
| REF-14 | 17 | 17-1 |
| REF-15 | 17 | 17-2 |
| REF-16 | 17 | 17-3 |
| REF-17 | 18 | 18-1 |
| REF-18 | 18 | 18-2 |
| REF-19 | 18 | 18-3 |
| REF-20 | 19 | 19-1 |
| REF-21 | 19 | 19-2 |
| REF-22 | 19 | 19-3 |
| REF-23 | 20 | 20-1 |
| REF-24 | 20 | 20-2 |
| REF-25 | 20 | 20-3 |
| REF-26 | 20 | 20-4 |
| REF-27 | 20 | 20-5 |
| NFR-REF-01 | 16, 20 | 16-2–16-5, 20-4 |
| NFR-REF-02 | 14 | 14-1, 14-2 |
| NFR-REF-03 | 17, 20 | 17-1–17-3, 20-4–20-5 |
| NFR-REF-04 | 16 | 16-1 |
| NFR-REF-05 | 15, 16 | 15-2, 16-1 |
| UX-REF-01–03 | 16 | 16-6, 16-7 |
| UX-REF-04 | 20 | 20-1 |
| UX-REF-05 | 20 | 20-2 |

## Epic List

### Epic 14: Lifecycle Safety & Silent Failure Prevention
Harden purge refresh and lifecycle transition handling so tracking and UI never fail silently.
**REFs covered:** REF-01, REF-02 · **NFRs:** NFR-REF-02

### Epic 15: Targeted Architecture & Build Hygiene
Fix the highest-impact architecture violations and reduce release bundle noise.
**REFs covered:** REF-03, REF-04, REF-05, REF-06 · **NFRs:** NFR-REF-05

### Epic 16: 120 Hz Performance & Testability Foundation
Deliver GPU/CPU optimisations and repository abstractions enabling fast cubit tests.
**REFs covered:** REF-07–REF-13 · **NFRs:** NFR-REF-01, NFR-REF-04, NFR-REF-05 · **UX:** UX-REF-01–03

### Epic 17: Dependency Slimming (Quick Wins)
Remove replaceable packages and pin fragile dependencies.
**REFs covered:** REF-14, REF-15, REF-16 · **NFRs:** NFR-REF-03

### Epic 18: Deep Architecture Decomposition
Extract god classes into injectable, testable services and focused repositories.
**REFs covered:** REF-17, REF-18, REF-19

### Epic 19: Internationalisation Infrastructure
Prepare the app for bilingual release with typed ARB-generated localisations.
**REFs covered:** REF-20, REF-21, REF-22

### Epic 20: UX Polish & Heavy APK Reduction
Product-value UX improvements and high-effort dependency replacements.
**REFs covered:** REF-23–REF-27 · **UX:** UX-REF-04, UX-REF-05 · **NFRs:** NFR-REF-01, NFR-REF-03

---

## Epic 14: Lifecycle Safety & Silent Failure Prevention

Eliminate silent UI corruption after data purge and lifecycle deadlock that stops step tracking without user feedback.

**Priority:** P0/P1 · **Version bump:** patch+1 at epic close.

### Story 14-1: Harden postPurgeRefresh Callback

As a **user**,
I want data purge to either fully refresh my dashboards or show a clear error,
So that I never see stale or inconsistent step counts after deleting my data.

**Acceptance Criteria:**

**Given** user completes a full data purge from My Data
**When** `postPurgeRefresh` runs in `AppScaffold`
**Then** all eight async steps execute inside a `try/catch` block (REF-01, NFR-REF-02)
**And** steps are: `clearLastDisplayedSteps` → `reconcileFromDatabase` → `TodayCubit.refresh` → `syncSteps` → `refreshMetadata` → `HistoryCubit.refresh` → `MyDataCubit.refresh` → `runMaintenance`

**Given** any step in `postPurgeRefresh` throws
**When** the exception is caught
**Then** error is logged with stack trace
**And** user sees a snackbar or equivalent non-blocking error message
**And** remaining steps after the failure are not silently skipped without logging

**Given** `postPurgeRefresh` is in progress
**When** user navigates away and widget unmounts
**Then** `if (!mounted) return` guards prevent `StateError` on cubit calls

**Target files:** `lib/presentation/screens/app_scaffold.dart`

---

### Story 14-2: Fix Lifecycle Transition Deadlock

As a **user**,
I want step tracking to resume reliably after app backgrounding,
So that foreground/background transitions never permanently stop persistence.

**Acceptance Criteria:**

**Given** `_enqueueLifecycleTransition` in `_AstraAppState`
**When** the chained `then()` callback throws an uncaught exception
**Then** `_lifecycleTransitionInFlight` is reset to `false` in a `finally` block (REF-02)
**And** subsequent lifecycle transitions are not silently ignored

**Given** rapid pause/resume cycles
**When** transitions are enqueued while one is in flight
**Then** serialisation behaviour is preserved (no regression to parallel transitions)

**Given** existing live-pipeline integration tests
**When** this story ships
**Then** tests pass without modification or with minimal expectation updates documented in review brief

**Target files:** `lib/app.dart` (lines 174–191, `_enqueueLifecycleTransition`)

---

## Epic 15: Targeted Architecture & Build Hygiene

Resolve the most impactful Clean Architecture violations and dev-tool bundle leakage without deep repository splits.

**Priority:** P1 · **Version bump:** patch+1 at epic close · **Blocks:** Story 16-7.

### Story 15-1: Batch SQL Goal Resolution for History

As a **user**,
I want Trends to load quickly even with 30 days of goal history,
So that opening the History tab feels instant on 120 Hz devices.

**Acceptance Criteria:**

**Given** `HistoryCubit._resolveGoalsForAggregates` needs goals for N distinct local days
**When** goals are fetched
**Then** a single batch query runs: `SELECT local_day, goal_steps FROM daily_goal_effective WHERE local_day IN (…)` (REF-03)
**And** result is a `Map<String, int>` keyed by ISO local day
**And** the `Future.wait` loop over individual `getGoalForLocalDay` calls is removed

**Given** a day with no matching row in batch result
**When** goal is resolved
**Then** fallback matches existing `getGoalForLocalDay` semantics (`kDefaultStepGoal` or latest effective row)

**Given** unit or integration test with 30-day window
**When** goal resolution runs
**Then** only one repository call (or one SQL round-trip) is made for goals — verifiable via mock call count or query log

**Target files:** `lib/presentation/cubits/history_cubit.dart` (lines 347–363), `lib/data/repositories/user_preferences_repository.dart`

---

### Story 15-2: Move GoalRing Display Persistence to TodayCubit

As a **developer**,
I want GoalRing to be a pure presentation widget,
So that step display state is testable via cubit mocks and architecture boundaries are respected.

**Acceptance Criteria:**

**Given** `GoalRing` widget
**When** refactored
**Then** `_loadLastDisplayedSteps()` and `_persistLastDisplayedSteps()` are removed from widget state (REF-04, NFR-REF-05)
**And** `GoalRing.disableStepPersistence` static flag is eliminated

**Given** `TodayState`
**When** extended
**Then** includes `lastDisplayedSteps` (or equivalent) field managed by `TodayCubit`
**And** cubit loads from / persists to `UserPreferencesRepository.get/setLastDisplayedSteps` on appropriate lifecycle hooks

**Given** existing GoalRing and Today tests
**When** updated
**Then** tests mock `TodayCubit` instead of toggling `disableStepPersistence`
**And** no widget imports `UserPreferencesRepository` directly

**Given** alternative `GoalRingDisplayStateService` was considered
**When** cubit approach is chosen
**Then** decision is documented in story review brief (display-state coupling accepted vs service injection)

**Target files:** `lib/presentation/widgets/goal_ring.dart`, `lib/presentation/cubits/today_cubit.dart`, `lib/data/repositories/user_preferences_repository.dart`

---

### Story 15-3: Relocate Dev Tooling to test/dev

As a **release engineer**,
I want dev-only simulation and benchmark code excluded from release APKs,
So that bundle size and attack surface are minimised without relying on runtime flags.

**Acceptance Criteria:**

**Given** files under `lib/dev/`
**When** relocated
**Then** move to `test/dev/`: `data_inject_service.dart`, `chart_benchmark.dart`, `chart_benchmark_dev_fab.dart`, `chart_benchmark_render_pump.dart`, `lifecycle_simulator.dart` (REF-05)
**And** `lib/dev/` directory is removed from `lib/` tree

**Given** production code imported dev utilities
**When** imports are updated
**Then** production `lib/` has zero imports from relocated files
**And** test files import from `test/dev/` paths

**Given** `flutter build apk --release`
**When** analysed
**Then** dev simulator and benchmark classes are not present in release binary (spot-check via `--analyze-size` or symbol search)

**Given** existing tests using `data_inject_service` or `lifecycle_simulator`
**When** run
**Then** all pass with updated import paths

**Target files:** `lib/dev/*` → `test/dev/`, call sites in `test/` and any `lib/` imports

---

### Story 15-4: Replace uuid with Timestamp-Based Bucket IDs

As a **maintainer**,
I want fewer runtime dependencies,
So that the APK is leaner and ID generation stays local-first.

**Acceptance Criteria:**

**Given** `StepRepository` bucket ID generation
**When** refactored
**Then** IDs use `DateTime.now().microsecondsSinceEpoch.toRadixString(36)` (or equivalent collision-safe local scheme) (REF-06)
**And** `uuid` package is removed from `pubspec.yaml`

**Given** existing ingestion and bucket merge tests
**When** run
**Then** all pass — no duplicate-ID collisions in normal ingest paths

**Given** `flutter pub get` after change
**When** dependency tree is inspected
**Then** `uuid` is not a transitive dependency

**Target files:** `lib/data/repositories/step_repository.dart`, `pubspec.yaml`

---

## Epic 16: 120 Hz Performance & Testability Foundation

Optimise rendering hot paths and introduce repository contracts so cubits can be unit-tested without SQLite.

**Priority:** P2 · **Version bump:** minor+1 at epic close · **Depends on:** Story 15-2 for 16-7.

### Story 16-1: Introduce Repository Abstraction Contracts

As a **developer**,
I want cubits to depend on interfaces,
So that I can write fast unit tests with mocks instead of `sqflite_common_ffi`.

**Acceptance Criteria:**

**Given** new `lib/domain/` (or `lib/data/contracts/`) module
**When** created
**Then** defines `StepRepositoryContract` and `UserPreferencesRepositoryContract` (REF-07, NFR-REF-04)
**And** existing concrete repositories implement these contracts

**Given** `TodayCubit`, `HistoryCubit`, `MyDataCubit`
**When** refactored
**Then** constructor types use abstract contracts, not concrete repository classes
**And** dependency injection wiring in app bootstrap passes concrete implementations

**Given** at least one cubit unit test (e.g. `TodayCubit`)
**When** run with mocked contracts
**Then** test completes without opening SQLite and runs in &lt;1s locally

**Given** existing integration test suite
**When** run
**Then** all pass — contracts are drop-in replacements, no behaviour change

**Target files:** new `lib/domain/contracts/`, `lib/data/repositories/step_repository.dart`, `lib/data/repositories/user_preferences_repository.dart`, `lib/presentation/cubits/today_cubit.dart`, `history_cubit.dart`, `my_data_cubit.dart`, app DI wiring

---

### Story 16-2: Cache Static GPU Inset Shadows

As a **user**,
I want smooth 120 Hz scrolling on Today,
So that static visual effects do not allocate GPU save-layers every frame.

**Acceptance Criteria:**

**Given** `goal_ring_effects.dart` and `astra_inset_shadow.dart`
**When** painting inset shadows
**Then** first `paint()` renders shadow via `Picture.toImage()` and caches result (REF-08, NFR-REF-01)
**And** subsequent frames use `canvas.drawImage()` with cached bitmap

**Given** widget size changes (`oldDelegate.size != size`)
**When** layout updates
**Then** shadow cache is invalidated and re-rendered once

**Given** visual comparison before/after
**When** inspected on device
**Then** shadow appearance is perceptually identical at default sizes

**Target files:** `lib/presentation/widgets/goal_ring_effects.dart`, `lib/presentation/widgets/astra_inset_shadow.dart`

---

### Story 16-3: Tab Repaint Isolation in AppScaffold

As a **user**,
I want switching tabs to feel instant,
So that inactive screens do not repaint when Today updates live steps.

**Acceptance Criteria:**

**Given** `IndexedStack` in `AppScaffold` (lines 280–283)
**When** each tab child is wrapped
**Then** `RepaintBoundary` isolates Today, History, and MenuHub subtrees (REF-09)
**And** live step updates on Today do not trigger repaint of off-screen tab roots (verifiable via Flutter DevTools repaint rainbow)

**Given** optional `PageView` + `AutomaticKeepAliveClientMixin` enhancement
**When** evaluated
**Then** implement only if repaint isolation alone is insufficient — document decision in review brief

**Given** tab state (scroll position, selected day)
**When** user switches tabs and returns
**Then** state is preserved as before refactor

**Target files:** `lib/presentation/screens/app_scaffold.dart`

**Note:** Charts inside `HistoryScreen` use conditional `if/else` — they are **not** the source of background repaint; do not add spurious `RepaintBoundary` around chart widgets for this story.

---

### Story 16-4: GoalRing RepaintBoundary and Controller Lifecycle Audit

As a **user**,
I want GoalRing animations to be GPU-efficient and leak-free,
So that long sessions do not degrade performance or memory.

**Acceptance Criteria:**

**Given** `GoalRing` widget tree
**When** built
**Then** entire ring subtree is wrapped in `RepaintBoundary` (REF-10)

**Given** five `AnimationController`s and two `Timer`s in GoalRing
**When** widget is disposed
**Then** all controllers call `dispose()` and all timers are cancelled
**And** debug build optionally asserts zero dangling controllers (document approach in review brief)

**Given** 10-minute Today screen session with live steps
**When** memory profiled in debug
**Then** no monotonic growth attributable to GoalRing controllers

**Target files:** `lib/presentation/widgets/goal_ring.dart`

---

### Story 16-5: Granular BlocSelector on TodayScreen

As a **user**,
I want the Today dashboard to update only the widgets that changed,
So that live step ticks do not rebuild the entire screen 120 times per second.

**Acceptance Criteria:**

**Given** `TodayScreen` global `BlocBuilder`
**When** refactored
**Then** replaced with targeted `BlocSelector` widgets (REF-11, NFR-REF-01):
- `WeekProgressRow` → rebuilds only on weekly structure change
- `GoalRing` → rebuilds only on `todaySteps` and `dailyGoal`
- Stats cards → rebuild only on `derivedMetrics` change

**Given** live step increment
**When** observed in DevTools
**Then** only GoalRing (and dependent micro-widgets) mark needs-repaint — not full screen scaffold

**Given** goal or week structure change
**When** emitted by cubit
**Then** only affected selectors rebuild

**Target files:** `lib/presentation/screens/today_screen.dart` and child widgets (`WeekProgressRow`, stats row, etc.)

---

### Story 16-6: Collection Health Indicator and Stale Banner CTA

As a **user**,
I want to know when step collection is stale or permission is denied,
So that I can fix tracking issues without guessing.

**Acceptance Criteria:**

**Given** `TodayState.isStale` and `TodayState.permissionStatus` already computed
**When** Today screen renders
**Then** health indicator appears above GoalRing with states (UX-REF-02, REF-12):
- Active collection: "Collecte active ●" (or English per current app language)
- Stale: "Dernière sync il y a Xh ⚠"
- Permission denied: "Accès capteur révoqué ✕"

**Given** `StatusBannerVariant.staleCompact` / `staleFull` stubs
**When** data is stale
**Then** banner is visible and tappable (UX-REF-01)
**And** tap triggers forced refresh or navigates to Android permission / tracking settings as appropriate

**Given** fresh data and granted permission
**When** Today loads
**Then** indicator shows active state or is hidden per design decision documented in review brief

**Target files:** `lib/presentation/screens/today_screen.dart`, `TodayState`, status banner widgets

---

### Story 16-7: Cold-Start Loading Shimmer for Today

As a **user**,
I want the step counter to avoid flashing "0" on cold start,
So that the first impression matches my actual progress.

**Acceptance Criteria:**

**Given** Story 15-2 is complete (display state in cubit)
**When** app cold-starts
**Then** `TodayCubit` emits `TodayStatus.loading` until initial steps and `lastDisplayedSteps` are loaded (REF-13, UX-REF-03)

**Given** `TodayStatus.loading`
**When** Today screen renders
**Then** GoalRing and step counter show a light shimmer placeholder — not "0 / 10 000"

**Given** initial load completes
**When** cubit emits ready state
**Then** shimmer transitions to actual step count without jarring flash

**Depends on:** Story 15-2.

**Target files:** `lib/presentation/cubits/today_cubit.dart`, `lib/presentation/screens/today_screen.dart`, `lib/presentation/widgets/goal_ring.dart`

---

## Epic 17: Dependency Slimming (Quick Wins)

Remove replaceable packages and stabilise fragile dependency pins with measured APK impact.

**Priority:** P2 · **Version bump:** patch+1 at epic close.

### Story 17-1: Replace share_plus with file_picker CSV Export

As a **user**,
I want to export my data to a file I choose,
So that export works local-first without a share-sheet dependency.

**Acceptance Criteria:**

**Given** baseline `flutter build apk --release --analyze-size` captured before changes
**When** CSV export is triggered
**Then** file is written via `file_picker` SAF / direct path (REF-14)
**And** Android uses `FileProvider` where required
**And** `share_plus` is removed from `pubspec.yaml` and all imports

**Given** export on Android device
**When** user picks destination
**Then** CSV content matches previous export format (no data loss, same columns)

**Given** post-change size analysis
**When** compared to baseline
**Then** APK size reduction is noted in review brief (NFR-REF-03)

**Target files:** `lib/data/repositories/step_repository.dart` (`exportCsv`), associated cubit/UI, `pubspec.yaml`, Android `FileProvider` manifest if needed

---

### Story 17-2: Pin file_picker to Exact Beta Version

As a **maintainer**,
I want `file_picker` locked to a known-good version,
So that `flutter pub upgrade` cannot silently break CSV export.

**Acceptance Criteria:**

**Given** `pubspec.yaml`
**When** updated
**Then** dependency reads `file_picker: 12.0.0-beta.5` without caret `^` (REF-15)

**Given** `flutter pub get`
**When** lockfile resolves
**Then** exactly `12.0.0-beta.5` is used

**Target files:** `pubspec.yaml`, `pubspec.lock` (if committed)

---

### Story 17-3: Replace figma_squircle with Native ClipPath

As a **maintainer**,
I want nav bar active-item masking without a third-party squircle package,
So that APK size decreases with no visual regression.

**Acceptance Criteria:**

**Given** active bottom-nav item uses `figma_squircle`
**When** refactored
**Then** shape uses `ClipPath` + `Path` standard Flutter APIs (REF-16)
**And** `figma_squircle` removed from `pubspec.yaml`

**Given** side-by-side screenshot comparison
**When** reviewed
**Then** active tab indicator shape is acceptable per Baptiste visual review

**Target files:** bottom navigation widgets, `pubspec.yaml`

---

## Epic 18: Deep Architecture Decomposition

Split god classes into focused, injectable components after P0–P2 stabilisation.

**Priority:** P3 · **Version bump:** minor+1 at epic close · **High destabilisation risk** — run full regression suite at epic close.

### Story 18-1: Extract AppLifecycleCoordinator from app.dart

As a **developer**,
I want live pipeline orchestration isolated from `MaterialApp` state,
So that lifecycle logic is unit-testable without widget harnesses.

**Acceptance Criteria:**

**Given** `_AstraAppState` pipeline methods (see audit §1.2a inventory)
**When** extracted
**Then** new injectable `AppLifecycleCoordinator` owns (REF-17):
- `_ensureLivePipelineAttached`, `_startLivePipelineFirstTime`, `_reattachLivePipeline`
- `_bindLiveMonitorToToday`, `_resumeLivePipeline`
- `_runPersistCycle`, `_enqueuePersistCycle`
- `_wireLiveMonitorDayBoundaryCallbacks`, `_startActivityBasedPersist`
- `_runLocalDayBoundary*`, midnight and staleness timers

**Given** `lib/app.dart`
**When** refactored
**Then** `_AstraAppState` delegates to coordinator — file reduced substantially from 864 lines

**Given** live-pipeline integration tests
**When** run
**Then** all pass; coordinator testable with injected mocks in at least one new unit test

**Target files:** `lib/app.dart` → new `lib/core/services/app_lifecycle_coordinator.dart` (or equivalent per project conventions)

---

### Story 18-2: Split UserPreferencesRepository

As a **developer**,
I want preferences split by domain,
So that each repository has a single responsibility.

**Acceptance Criteria:**

**Given** `UserPreferencesRepository` (420 lines)
**When** split
**Then** creates (REF-18):
- `UserSettingsRepository`: theme, accent, units, notifications, onboarding, celebration dedup, DB maintenance timestamps
- `UserHealthMetricsRepository`: display name, height, weight, daily step goal APIs

**Given** `getLastDisplayedSteps` / `setLastDisplayedSteps`
**When** Story 15-2 already moved display state to cubit
**Then** these methods are removed or deprecated with no remaining widget callers

**Given** all cubits and services
**When** updated
**Then** inject appropriate repository; no behaviour change from user perspective

**Given** repository tests
**When** run
**Then** split test files mirror new boundaries

**Target files:** `lib/data/repositories/user_preferences_repository.dart` → new repositories + DI updates

---

### Story 18-3: Split StepRepository and Extract CsvService

As a **developer**,
I want step ingestion, aggregation, and CSV I/O separated,
So that each class stays under ~250 lines and is easier to test.

**Acceptance Criteria:**

**Given** `StepRepository` (679 lines)
**When** split
**Then** creates (REF-19):
- `StepIngestionRepository`: `upsertIngestionBucket`, dev samples, purge hooks
- `StepAggregationRepository`: today reads, chart aggregates, footprint, compaction
- `CsvService`: `exportCsv`, `importCsv`, `importSamples`

**Given** cubits and `BackgroundCollector`
**When** updated
**Then** depend on appropriate split repository or service via contracts from Story 16-1

**Given** CSV export/import user flows
**When** tested manually and automatically
**Then** identical behaviour to pre-split

**Target files:** `lib/data/repositories/step_repository.dart` → new files + DI wiring

---

## Epic 19: Internationalisation Infrastructure

Add bilingual support after architecture stabilisation to avoid migrating strings in files still being refactored.

**Priority:** P3 · **Version bump:** minor+1 at epic close · **Run after Epics 14–18.**

### Story 19-1: flutter_localizations Scaffold

As a **user**,
I want the app ready for multiple languages,
So that French and English strings are type-safe and generated at build time.

**Acceptance Criteria:**

**Given** project configuration
**When** i18n is initialised
**Then** (REF-20):
- `pubspec.yaml` has `flutter: generate: true` and `flutter_localizations` dependency
- `l10n.yaml` points to `lib/l10n`, template `app_en.arb`
- `lib/l10n/app_en.arb` and `lib/l10n/app_fr.arb` exist with starter keys

**Given** `flutter gen-l10n`
**When** run
**Then** `AppLocalizations` class generates without errors

**Given** `MaterialApp` in `lib/app.dart`
**When** wired
**Then** `localizationsDelegates` and `supportedLocales` (`en`, `fr`) are configured

**Target files:** `pubspec.yaml`, `l10n.yaml`, `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`, `lib/app.dart`

---

### Story 19-2: Migrate Hardcoded Strings to ARB Keys

As a **user**,
I want UI copy in my chosen language,
So that menus, banners, and onboarding reflect locale.

**Acceptance Criteria:**

**Given** audit §2.2 migration table keys (minimum):
- `menuPrivacyAndData`, `menuTrackingStatus`, `bannerStaleData`, `errorNoPermission`, `onboardingStartBtn`, `trendsWeeklyGrowth`
**When** migrated
**Then** each key exists in `app_en.arb` and `app_fr.arb` with correct translations (REF-21)

**Given** full string scan of `lib/presentation/`
**When** complete
**Then** all user-visible strings in scope use `AppLocalizations` — no hardcoded French/English in migrated screens

**Given** device locale French
**When** app launches
**Then** migrated strings display in French

**Target files:** Settings/Menu, Today banners, Onboarding, Trends screens + ARB files

---

### Story 19-3: Persist and Apply User Locale Preference

As a **user**,
I want to choose my language in settings,
So that the app remembers my choice across restarts.

**Acceptance Criteria:**

**Given** user selects locale in settings
**When** saved
**Then** preference persists in repository (`en` or `fr`) (REF-22)

**Given** cold start
**When** `MaterialApp` builds
**Then** saved locale applies before first frame of localised content
**And** overrides device locale when preference is set

**Given** no preference saved
**When** app starts
**Then** device locale is used if supported, else falls back to `en`

**Target files:** `user_preferences_repository.dart` (or `UserSettingsRepository` post-18-2), settings screen, `lib/app.dart`

---

## Epic 20: UX Polish & Heavy APK Reduction

Deliver remaining product-value UX and high-effort dependency replacements at the end of the refactoring programme.

**Priority:** P3 · **Version bump:** minor+1 at epic close.

### Story 20-1: Onboarding Permission After Value Proposition

As a **new user**,
I want to understand why Astra needs activity access before the system permission dialog,
So that I trust the app and am more likely to grant permission.

**Acceptance Criteria:**

**Given** `OnboardingIntroPage` (index 0)
**When** user lands on onboarding
**Then** screen emphasises "100% offline, no account required" (UX-REF-04, REF-23)
**And** activity permission is **not** requested on first paint

**Given** user taps Continue on intro
**When** they have seen product value
**Then** activity permission is requested (moved from premature timing)

**Given** weight/height steps (indices 1–2)
**When** unchanged
**Then** Skip remains available — no regression to mandatory biometrics

**Target files:** `lib/presentation/onboarding/onboarding_flow.dart`, `onboarding_intro_page.dart`

---

### Story 20-2: Local Trends Insight Cards

As a **user**,
I want plain-language insights about my walking habits,
So that Trends feels valuable without cloud analytics.

**Acceptance Criteria:**

**Given** existing chart aggregates in SQLite
**When** Trends loads
**Then** locally computed insight cards display (UX-REF-05, REF-24), e.g.:
- Weekly average change percentage
- Most active weekday
- Consecutive days above goal (streak)

**Given** insufficient data (&lt;7 days)
**When** insights cannot be computed
**Then** cards show calm empty state — not errors

**Given** calculations
**When** inspected
**Then** all run in Dart from existing `getChartDailyAggregates` / repository APIs — no network calls

**Target files:** `lib/presentation/cubits/history_cubit.dart`, `lib/presentation/screens/history_screen.dart` (or Trends section)

---

### Story 20-3: Tab Navigation Haptic Feedback

As a **user**,
I want subtle haptic feedback when switching tabs,
So that navigation feels tactile and responsive.

**Acceptance Criteria:**

**Given** `AppScaffold` tab change handler
**When** implementation starts
**Then** verify whether `HapticFeedback.selectionClick()` already exists (REF-25)
**And** add only if absent

**Given** user switches bottom tab
**When** new tab is selected
**Then** one `selectionClick` fires — not on re-tap of active tab

**Target files:** `lib/presentation/screens/app_scaffold.dart`

---

### Story 20-4: Replace fl_chart with CustomPainter Charts

As a **user**,
I want charts that render natively on Impeller,
So that Trends scrolls smoothly and APK size drops ~500 KB.

**Acceptance Criteria:**

**Given** baseline size analysis (NFR-REF-03)
**When** charts are reimplemented
**Then** native `CustomPainter` (~250 lines per chart type) replaces `fl_chart` usage (REF-26, NFR-REF-01)
**And** `fl_chart` removed from `pubspec.yaml`

**Given** History/Trends screens
**When** compared visually to pre-change screenshots
**Then** bar chart, trend line, and 12-month chart are functionally equivalent (data, axes, goal line)

**Given** chart performance
**When** profiled on device
**Then** no regression vs fl_chart on 120 Hz scroll

**Target files:** History/Trends chart widgets, `pubspec.yaml`

---

### Story 20-5: Phosphor Icons Selective Font Subsetting

As a **maintainer**,
I want only used Phosphor glyphs in the APK,
So that multi-font icon package overhead (~200–400 KB) is eliminated.

**Acceptance Criteria:**

**Given** audit of all `PhosphorIcons` usages in `lib/`
**When** complete
**Then** list of required icon codepoints is documented

**Given** `/assets/fonts/`
**When** populated
**Then** only required `.ttf` subsets are bundled (REF-27)
**And** `phosphoricons_flutter` dependency removed or reduced to asset-only approach

**Given** all screens
**When** visually inspected
**Then** no missing-icon tofu boxes

**Given** post-change size analysis
**When** compared to baseline
**Then** estimated 200–400 KB reduction noted in review brief

**Target files:** `pubspec.yaml`, `assets/fonts/`, all Phosphor icon call sites

---

## Intentionally Out of Scope

| Item | Reason |
|------|--------|
| `AstraHorizontalRuler` debounce | Audit ❌ INEXACT — snap already implemented |
| Replacing core packages (sqflite, pedometer, etc.) | Audit §7 — essential and stable |
| `kDebugMode` guard for `lib/dev/` | Insufficient — relocation only (Story 15-3) |
| SQLCipher, BLE, Health Connect | Phase 1+ product scope per `epics.md` |

## Next Steps

1. **[SP] Sprint Planning** — `bmad-sprint-planning` to generate `sprint-status-refacto.yaml` from this document.
2. **[CS] Create Story** — `bmad-create-story` for **14-1** as first `ready-for-dev` story file.
3. Execute on branch **`refacto`**; merge after Epic 14 review at minimum.
