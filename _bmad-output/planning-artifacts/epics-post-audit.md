---
stepsCompleted: [1, 2, 3, 4, 5]
status: in-progress
completedAt: 2026-07-16
validatedAt: 2026-07-19
validationNotes: |
  Epics 21–26 delivered (37 stories). Re-audit 0.11.3+28 adds Epics 27–28 (7 stories).
  Sprint status aligned (44 stories total). AUD-11, AUD-13–15 → E27; AUD-24, AUD-43,
  My Data stale tap parity → E28. Still deferred: AUD-09–10, AUD-12, AUD-21–23, AUD-33,
  AUD-41–42, AUD-49, unified AppFailure.

storiesCompletedAt: 2026-07-16
storyCounts:
  epic-21: 8
  epic-22: 5
  epic-23: 7
  epic-24: 6
  epic-25: 5
  epic-26: 6
  epic-27: 4
  epic-28: 3
  total: 44
scopeDecision: |
  Core = sprint-status stories + AUD-05 (21-8), AUD-31 folded into 23-3,
  AUD-32 (23-7), AUD-40 (24-6). E27 = AUD-11, AUD-13–15. E28 = AUD-24, AUD-43,
  My Data stale banner tap (diagnostic 04 §4). Deferred: AUD-09–10, AUD-12, AUD-21–23,
  AUD-33, AUD-41–42, AUD-49, AppFailure.
extractedAt: 2026-07-16
extendedAt: 2026-07-19
scope: Post-audit Epics 21–28 — technical hardening after Epics 14–20
baseVersion: 0.11.3+28
project_name: astra-app
inputDocuments:
  - planning-artifacts/audits/README.md
  - planning-artifacts/audits/diagnostic-acces-concurrents.md
  - planning-artifacts/audits/diagnostic-cold-start.md
  - planning-artifacts/audits/diagnostic-cycle-de-vie-ressoruce.md
  - planning-artifacts/audits/diagnostic-gestion-etat-erreur.md
  - planning-artifacts/audits/diagnostic-accessibilité-statique.md
  - planning-artifacts/audits/diagnostic-etat-chargement.md
  - planning-artifacts/audits/diagnostic-coherence-design-system.md
  - planning-artifacts/audits/diagnostic-code-mort.md
  - planning-artifacts/audits/diagnostic-convention-structure.md
  - planning-artifacts/audits/diagnostic-couverture-structurelle.md
  - planning-artifacts/audits/diagnostic-dependance.md
  - planning-artifacts/architecture.md
  - planning-artifacts/ux-design-specification.md
  - implementation-artifacts/sprint-status-post-audit.yaml
  - docs/project-context.md
---

# astra-app — Post-Audit Epic Breakdown (Epics 21–28)

## Overview

This document decomposes the **post-refacto technical audits** (`planning-artifacts/audits/`) into implementable epics and stories for Epics **21–28**.

**Scope:** Brownfield hardening after Epics 14–20 (cold start, robustness, a11y, design/loading consistency, structural debt, orchestration tests, boot polish, targeted UX coherence). Does **not** replace `epics.md` (Epics 1–13) or `epics-refacto.md` (Epics 14–20).

**Execution order:** P0 Epic 21 → P1 Epics 22 + 23 + 26 → P2 Epic 24 → P3 Epic 25 → P0 polish Epic 27 → P1 UX Epic 28.

**Tracker:** `implementation-artifacts/sprint-status-post-audit.yaml`

## Development Workflow (all stories)

Every sub-task follows **review before commit**. See [`docs/project-context.md`](../../docs/project-context.md).

| Step | Who | Action |
|------|-----|--------|
| 1 | Agent | Complete one sub-task |
| 2 | Agent | Post review brief (what / why / how to verify / learn) + suggested commit message |
| 3 | Baptiste | Read diff, learn, reply **OK commit** (or request changes) |
| 4 | Agent | Commit only after explicit approval — **one commit per sub-task** |

## Versioning (post-audit)

Bump `pubspec.yaml` + `README.md` at each **epic close** per `.cursor/rules/app-versioning.mdc`. Stay on `0.x.y` (no `1.0.0` until public launch).

| Epic | Semver | Build |
|------|--------|-------|
| Epic 21 (performance + visible behavior) | minor+1, patch=0 | +1 |
| Epic 22 (robustesse / fix) | patch+1 | +1 |
| Epic 23 (a11y improvements) | minor+1, patch=0 | +1 |
| Epic 24 (design / loading consistency) | patch+1 (or minor if UX expands) | +1 |
| Epic 25 (architecture debt) | patch+1 (or minor if broad UX-visible) | +1 |
| Epic 26 (tests only) | patch+1 | +1 |
| Epic 27 (boot polish, perf visible) | patch+1 | +1 |
| Epic 28 (UX coherence — errors & permissions) | minor+1, patch=0 | +1 |

## Requirements Inventory

### Functional Requirements

#### E21 — Cold Start & SQLite (diagnostics 01, 02)

AUD-01: On first Today pipeline start, paint local SQLite Today data before awaiting foreground ingestion backfill (`await _foregroundBackfill` must not gate first data emit). (P0 — cold-start A1)

AUD-02: Add `TodayCubit.refreshFastPath()` that loads at most 3 queries (`getTodaySteps`, today’s goal, `getLastDisplayedSteps`), emits with `lastDisplayedStepsLoaded: true`, and defers week banner, active buckets/metrics, and last-ingestion/stale work. (P0 — cold-start A2)

AUD-03: Eliminate redundant cold-start `getTodaySteps()` / `getBaseline()` re-reads by seeding `LiveStepMonitor.start` from the fast-path result. (P0 — acces-concurrents §3 / cold-start A3)

AUD-04: Route `IngestionCollectionLock` SQL (`tryAcquire` / `release`) through `AstraDatabaseSession.withRetry` (or equivalent session reopen path), not raw `StepIngestionRepository.db`. (P0 — acces-concurrents §1)

AUD-05: On cold-start persist cycle when the live monitor is not yet running, avoid blocking pedometer drain (zero/skip source timeout). (P1 — cold-start A4)

AUD-06: Replace week N+1 `getGoalForLocalDay` ×7 with a single batch `getGoalsForLocalDays(...)`. (P1 — cold-start B1)

AUD-07: Add SQLite index on `timeseries_samples (type, end_time DESC)` for last-ingestion queries (migration). (P1 — cold-start B2)

AUD-08: Guard `_onIngestionComplete` so `HistoryCubit.refresh` runs only when the Trends tab is selected. (P1 — cold-start C2)

AUD-09: Optionally add an index covering active-bucket filters (`type, resolution, start_time` / partial `value > 0`). (P2 — cold-start B3)

AUD-10: Provide SQL-side daily chart aggregation so Trends does not pull 9k+ raw rows into Dart. (P2 — cold-start B4)

AUD-11: Lazily create `HistoryCubit` on first Trends selection instead of eager create + always-mounted IndexedStack child. (P2 — cold-start C1)

AUD-12: Defer Trends `_buildDayMetricsCache` (kcal insights) after first ready emit of aggregates/charts. (P2 — cold-start C3)

AUD-13: Parallelize the seven initial preference reads in `AppDependencies.create` via `Future.wait`. (P2 — cold-start D1)

AUD-14: Register WorkManager after first frame / `runApp`, not on the critical path before UI. (P2 — cold-start D2)

AUD-15: Initialize `NotificationService` in parallel with DI (or after first frame), not as a hard serial block before `runApp`. (P2 — cold-start D3)

#### E22 — Runtime Robustness & UI Errors (diagnostics 03, 04; loading ghost from 06)

AUD-16: Harden `LiveStepMonitor.dispose()` so `stop()` completes (or a `_disposed` flag blocks `start`) before closing `_stepsController`. (P1 — cycle-de-vie)

AUD-17: Disable the Today “Set goal” action while `TodayStatus.loading` or `lastDisplayedStepsLoaded == false`. (P1 — etat-chargement §3.1)

AUD-18: Add a user-visible retry path when Profile/Settings show `ProfileStatus.error`. (P1 — gestion-etat-erreur)

AUD-19: Give `ThemeCubit` persist failures the same SnackBar (or equivalent) feedback as locale/units/notification preference failures. (P1 — gestion-etat-erreur)

AUD-20: Enable `discarded_futures` and wrap remaining UI callback Futures with `unawaited`/`await`. (P2 — convention-structure §2.2)

AUD-21: Add `HealthForegroundServiceCoordinator.dispose()` that clears the MethodChannel handler for tests/hot restart. (P3 — cycle-de-vie)

AUD-22: Surface History refresh failures as an explicit error state (or banner) instead of silent cache/`empty` only. (P2 — gestion-etat-erreur)

AUD-23: Show an onboarding message when activity permission is denied; wrap `completeWithHeight` in error handling. (P2 — gestion-etat-erreur)

AUD-24: Reduce fragmented “activity permission denied” UI on Today toward one primary pattern + CTA. (P2 — gestion-etat-erreur)

#### E23 — Accessibility WCAG (diagnostic 05)

AUD-25: Wrap Today goal InkWell (`_GoalRingCard`) in `Semantics(button: true, label: …)`. (P0 — a11y Bloquant)

AUD-26: Wrap `_UnitOptionTile` InkWell in `Semantics(button: true, label: …)`. (P0 — a11y Bloquant)

AUD-27: Add `liveRegion` (polite) for GoalRing / AnimatedStepCount and ActivityStatsRow value updates. (P1 — a11y Majeur)

AUD-28: Restore visible keyboard focus feedback on `AstraSegmentedControl`. (P1 — a11y Majeur)

AUD-29: Make chart bar interaction focusable/keyboard-accessible with role + announced selection. (P1 — a11y Majeur)

AUD-30: Include goal-achieved status in `_DayPill` semantic labels. (P1 — a11y Majeur)

AUD-31: Add `liveRegion` for CollectionHealthIndicator and BackgroundStatusCard dynamic status text. (P1 — a11y Majeur)

AUD-32: MergeSemantics (or equivalent) for Settings notifications Switch + label. (P1 — a11y Majeur)

AUD-33: Systematically `ExcludeSemantics` decorative icons inside already-labeled Semantics nodes. (P3 — a11y Mineur)

#### E24 — Design System & Loading States (diagnostics 06, 07, 08)

AUD-34: Extract shared `SheetDragHandle` (32×4, radius 2) used by all editor sheets. (P2 — coherence-ds)

AUD-35: Remove or wire dead `AstraTypography.*(BuildContext)` wrappers and unused `AstraColors.borderPrimary`. (P2 — code-mort)

AUD-36: Unify loading visuals for local SQLite waits across Today week strip, Trends chart skeletons, and My Data section spinners. (P2 — etat-chargement)

AUD-37: Centralize duplicated chart axis reserved sizes / heights into one token source. (P2 — coherence-ds)

AUD-38: Remove or use orphan preference defaults (`kDefaultAccentPresetStorage`, `kDefault*DisplayUnit`); carefully clean unused `displayLabel` getters (still referenced in tests). (P2 — code-mort; do NOT delete `kDefaultStepGoal` / `kDefaultAccentPreset`)

AUD-39: Add typography tokens `navLabel` (10/w700) and `weekDayNumber` (16/w900) and stop inline TextStyles. (P2 — coherence-ds)

AUD-40: Disable or defer `PeriodToggle` interaction while History is `loading`. (P2 — etat-chargement §3.6)

AUD-41: Migrate `kAstraInsetShadowColor` to theme token for dark-mode safety. (P3 — coherence-ds)

AUD-42: Replace orphan hardcoded `4`/`8` paddings with `AstraSpacing` where semantically identical. (P3 — coherence-ds)

AUD-43: Stop gating Settings locale/units/theme UI behind `ProfileCubit` full-screen loading when those prefs are already in memory. (P3 — etat-chargement)

#### E25 — Architecture & Structural Debt (diagnostics 09, 11)

AUD-44: Split `TodayCubit` (~1104 LOC) along responsibility boundaries (refresh, live attach, celebration, multi-day). (P3 — convention-structure)

AUD-45: Split `AppLifecycleCoordinator` (~848 LOC) into focused services (midnight boundary, persist cycle, live pipeline). (P3 — convention-structure)

AUD-46: Remove `presentation/` import from `core/di/app_dependencies.dart`. (P3 — convention-structure)

AUD-47: Move `PurgeConfirmAction` / FilePicker defaults out of `MyDataCubit` into core/data or injected callbacks. (P3 — convention-structure)

AUD-48: Add `///` doc comments on listed public `core/`/`data/` classes without docs. (P3 — convention-structure)

AUD-49: Harmonize multi-class / file-name mismatches (low-risk housekeeping). (P3 — convention-structure)

#### E26 — Orchestration Tests & Resilience (diagnostic 10)

AUD-50: Add direct tests for `AppLifecycleCoordinator.onTodayCubitReady` cold-start orchestration. (P1 — couverture Top #2)

AUD-51: Add direct tests for `onLifecycleStateResumed` including forced failure/recovery of `_resumeLivePipeline` catch. (P1 — couverture Top #1)

AUD-52: Cover `maybeNotifyGoalReachedIfGoalMet` (eval + preference rollback if `showGoalReached` fails) by name. (P1 — couverture Top #3)

AUD-53: Cover `TodayCubit.refreshAfterDayRollover` contract (midnight UI reset). (P1 — couverture Top #5)

AUD-54: Cover `createIsolateBackgroundCollector` factory bootstrap directly. (P1 — couverture Top #4)

AUD-55: Add fault-injection tests for `LiveStepMonitor.start` stream `onError` (and peek timeout/error paths). (P1 — couverture LiveStepMonitor)

### NonFunctional Requirements

NFR-AUD-01: First GoalRing paint with local SQLite steps target &lt;100 ms after fast path (A1–A3); full cold start may remain &gt;100 ms. (P0)

NFR-AUD-02: Complete Today refresh (week + metrics) target ~100–200 ms after B1 + indexes. (P1)

NFR-AUD-03: UI isolate uses one shared `AstraDatabaseSession`; background isolates use separate connections + `withRetry`/`ensureOpen` on resume — preserve this model. (P0)

NFR-AUD-04: Trends chart bind stays within architecture KPI (p95 &lt;100 ms with pre-aggregated points); prefer SQL aggregation over shipping raw buckets. (P2)

NFR-AUD-05: Accessibility: WCAG 2.1 AA aspirational; baseline Semantics/liveRegion/focus/contrast from UX §4 — static audit is not a TalkBack/VoiceOver substitute. (P1)

NFR-AUD-06: Prefer unit/fault-injection coverage for critical lifecycle/orchestration paths that today are FFI-only or name-missing. (P1)

NFR-AUD-07: Touch targets remain ≥48 dp for interactive chrome (tabs, period toggle, buttons) per UX §4.2. (P1)

NFR-AUD-08: Design token consistency: no new hardcoded hex in widgets; use `AstraColors` / `AstraSpacing` / `AstraTypography`. (P2)

### Additional Requirements

- **Today Display Truth Model:** SQLite daily aggregate = source of truth; `LiveStepMonitor` = live overlay; foreground backfill = recovery. Fast path may show SQLite first, then overlay after monitor bind — do not invert truth (UI must stay monotonic within a local day).
- **Single-writer (ingestion):** Only `BackgroundCollector` performs ingestion writes (`upsertIngestionBucket`). Fast path / UI must not write buckets.
- **`IngestionCollectionLock`:** Cross-isolate lock on shared DB file; must survive reopen via session retry (AUD-04).
- **No reactive SQLite in this phase:** Do not migrate to reactive streams to “fix” duplicate reads — optimize orchestration instead (README hors Sprint 1).
- **Repository-owned transactions:** Multi-row writes stay in repository transactions; Cubits never open DB transactions.
- **DI / contracts:** Cubits depend on `*RepositoryContract`; isolates may `new` concrete repos — preserve invalidate-on-ingestion callbacks when splitting.
- **Layering:** `core/` must not import `presentation/` (AUD-46).
- **Shared-repo split risk:** `UserSettings` / `UserHealthMetrics` / `StepAggregation` multi-consumers — avoid repository splits without cross-invalidation (diagnostic-dependance is constraint, not a split mandate).
- **Clock:** Injected `TimeProvider` for ingestion/lifecycle timestamps.
- **Unified `AppFailure` model:** Deferred (hors Sprint 1 / not in E22 stories yet).

### UX Design Requirements

UX-AUD-01: GoalRing loading = muted track pulse skeleton until first sample / last-displayed prefs resolved — not a blank full-screen gate. (P0)

UX-AUD-02: Semantics for GoalRing: `"Steps today: {n} of {goal}"` (overflow variant per UX §4.3); announce final count, not intermediate count-up frames. (P1)

UX-AUD-03: `GoalCelebration` keeps `liveRegion: polite` once/day; decorative glow `excludeSemantics`. (P1)

UX-AUD-04: Trends loading = 7 gray bar skeletons (12 for monthly); keep PeriodToggle chrome visible but do not leave it fully interactive while skeleton (align AUD-40). (P2)

UX-AUD-05: Token-lite: semantic colors via theme extension; no amber paragraph text; status never color-only. (P2)

UX-AUD-06: Respect reduce-motion: skip ring pulse/glow/celebration motion; instant data swap. (P2)

UX-AUD-07: Support OS text scale to 130% without clipping hero step count. (P2)

UX-AUD-08: Sheet handles and repeated micro-layout values should become shared DS components/tokens (SheetDragHandle, spacing 4/8). (P2)

### Explicitly Out of Scope / Deferred

| Item | Why |
|------|-----|
| Reactive SQLite migration | README hors Sprint 1 |
| Unified `AppFailure` model | README hors Sprint 1 |
| Complete fault-injection beyond Top-5 + LiveStepMonitor | README hors Sprint 1; E26 = prioritized subset |
| `AstraPressable._release()` mounted guard | Already `fixed` |
| Charts with “no Semantics at all” | Base Semantics exist; remaining = keyboard/role (AUD-29) |
| Delete `kDefaultStepGoal` / `kDefaultAccentPreset` | Still used (README correction) |
| Full TalkBack/VoiceOver + measured contrast audit | Deferred by a11y diagnostic |
| Threshold-based mid-walk RAM persist | Architecture explicitly rejected |

### FR Coverage Map

AUD-01: Epic 21 — Decouple backfill from first Today paint
AUD-02: Epic 21 — Fast-path Today refresh
AUD-03: Epic 21 — Deduplicate cold-start getTodaySteps
AUD-04: Epic 21 — Ingestion lock via session withRetry
AUD-05: Epic 21 — Non-blocking pedometer on cold backfill
AUD-06: Epic 21 — Batch week goal resolution
AUD-07: Epic 21 — end_time index for last-ingestion query
AUD-08: Epic 21 — Guard Trends refresh by active tab
AUD-09…10: Deferred (optional index, SQL chart aggregation)
AUD-11: Epic 27 — Lazy HistoryCubit on first Trends tab
AUD-12: Deferred (defer kcal insights cache)
AUD-13: Epic 27 — Parallelize initial preference reads
AUD-14: Epic 27 — WorkManager after runApp
AUD-15: Epic 27 — Non-blocking notification init
AUD-16: Epic 22 — Harden LiveStepMonitor.dispose
AUD-17: Epic 22 — Disable goal CTA during Today loading
AUD-18: Epic 22 — Profile/Settings load error retry
AUD-19: Epic 22 — Theme preference error feedback
AUD-20: Epic 22 — discarded_futures lint + fix sites
AUD-21: Deferred (HealthForegroundServiceCoordinator.dispose for tests)
AUD-22: Deferred (History refresh explicit error state)
AUD-23: Deferred (onboarding permission-denied message)
AUD-24: Epic 28 — Unify Today permission-denied messaging + CTA
AUD-25: Epic 23 — Today goal Semantics button
AUD-26: Epic 23 — Unit option tile Semantics
AUD-27: Epic 23 — liveRegion GoalRing + ActivityStats
AUD-28: Epic 23 — Segmented control keyboard focus
AUD-29: Epic 23 — Chart keyboard + semantic selection
AUD-30: Epic 23 — Week day pill goal-achieved Semantics
AUD-31: Epic 23 — liveRegion health/status cards (folded into 23.3)
AUD-32: Epic 23 — Settings notifications Switch MergeSemantics
AUD-33: Deferred (decorative ExcludeSemantics sweep)
AUD-34: Epic 24 — Shared SheetDragHandle
AUD-35: Epic 24 — Dead typography/color tokens
AUD-36: Epic 24 — Unify week/Trends loading patterns
AUD-37: Epic 24 — Centralize chart layout constants
AUD-38: Epic 24 — Orphan preference default constants
AUD-39: Epic 24 — navLabel / weekDayNumber typography tokens (with 24.4)
AUD-40: Epic 24 — PeriodToggle ghost during History loading
AUD-41…42: Deferred (shadow token, spacing sweep)
AUD-43: Epic 28 — Decouple Settings prefs from Profile loading gate
AUD-44: Epic 25 — Split TodayCubit
AUD-45: Epic 25 — Split AppLifecycleCoordinator
AUD-46: Epic 25 — Remove presentation from core DI
AUD-47: Epic 25 — Decouple MyDataCubit from UI dialog types
AUD-48: Epic 25 — Core/data public class doc comments
AUD-49: Deferred (file/class naming housekeeping)
AUD-50: Epic 26 — onTodayCubitReady tests
AUD-51: Epic 26 — onLifecycleStateResumed failure/recovery tests
AUD-52: Epic 26 — Goal notification eval/rollback tests
AUD-53: Epic 26 — refreshAfterDayRollover tests
AUD-54: Epic 26 — Isolate collector factory bootstrap tests
AUD-55: Epic 26 — LiveStepMonitor stream fault-injection tests
My-Data-stale-tap: Epic 28 — Tap-to-refresh on My Data stale banner (diagnostic 04 §4)

NFR-AUD-01…03: Epic 21 (+ E27 D1–D3 boot path)
NFR-AUD-04: Deferred with AUD-10
NFR-AUD-05, 07: Epic 23
NFR-AUD-06: Epic 26
NFR-AUD-08: Epic 24
UX-AUD-01: Epic 21 / 24 (fast path + loading unify)
UX-AUD-02, 03: Epic 23
UX-AUD-04: Epic 24 (PeriodToggle + Trends skeletons)
UX-AUD-05, 08: Epic 24
UX-AUD-06, 07: Deferred (reduce-motion / text-scale polish — not audit blockers)

## Epic List

### Epic 21: Cold Start & SQLite
Users see local Today step data immediately on launch; SQLite access is safer and cheaper on the hot path.
**FRs covered:** AUD-01…08 (+ AUD-05 delivery story)
**NFRs:** NFR-AUD-01, NFR-AUD-02, NFR-AUD-03
**Deferred within inventory:** AUD-09…10, AUD-12 (AUD-11, AUD-13…15 → Epic 27)

### Epic 22: Runtime Robustness & UI Error Handling
Users get stable live-pipeline teardown and recoverable preference/profile errors instead of silent or stuck UI.
**FRs covered:** AUD-16…20
**Deferred:** AUD-21…23 (AUD-24 → Epic 28)

### Epic 23: Accessibility WCAG
Users of assistive tech can activate goal/units controls, hear live updates, focus segmented controls, and use charts/week pills.
**FRs covered:** AUD-25…32
**UX:** UX-AUD-02, UX-AUD-03
**NFRs:** NFR-AUD-05, NFR-AUD-07
**Deferred:** AUD-33

### Epic 24: Design System & Loading States
Loading and sheet/chrome visuals are consistent; dead tokens are cleaned; Trends PeriodToggle is not interactively “ghost”.
**FRs covered:** AUD-34…40
**UX:** UX-AUD-01, UX-AUD-04, UX-AUD-05, UX-AUD-08
**NFRs:** NFR-AUD-08
**Deferred:** AUD-41…42 (AUD-43 → Epic 28)

### Epic 25: Architecture & Structural Debt
Maintainers can evolve Today/lifecycle/DI/My Data without presentation leaks or god-classes (after hardening epics).
**FRs covered:** AUD-44…48
**Deferred:** AUD-49
**Note:** Execute after Epics 21, 22, and 26 touch the same files.

### Epic 26: Orchestration Tests & Resilience
Critical cold-start, resume, notification, day-rollover, and live-monitor failure paths are covered by named unit/fault-injection tests.
**FRs covered:** AUD-50…55
**NFRs:** NFR-AUD-06

### Epic 27: Boot Polish & Lazy Trends
Cold start sheds serial pre-`runApp()` work; Trends cubit is created only when the user opens the tab.
**FRs covered:** AUD-11, AUD-13…15
**NFRs:** NFR-AUD-01 (boot path), cold-start Phase D targets
**Deferred:** AUD-09…10, AUD-12
**Prerequisite:** Epics 21 and 25 (fast path + scaffold/cubit splits stable)

### Epic 28: UX Coherence (Errors & Permissions)
Stale-data and permission-denied patterns are consistent; Settings prefs are not blocked by Profile load.
**FRs covered:** AUD-24, AUD-43, My Data stale tap parity (diagnostic 04 §4)
**Deferred:** AUD-22, AUD-23, unified `AppFailure`
**Prerequisite:** Epic 27 recommended first (shared `app_scaffold` / screen touch points)

## Epic 21: Cold Start & SQLite

Users see local Today step data immediately on launch; SQLite access is safer and cheaper on the hot path.

**Priority:** P0 · **Version bump:** minor+1, patch=0, build+1 at epic close · **Diagnostics:** 01, 02

### Story 21-1: Fast-Path Today Refresh for Cold Start

As a **user**,
I want Today to load only the data needed for the first GoalRing paint,
So that I see my local steps within ~100 ms instead of waiting for week metrics and stale checks.

**Acceptance Criteria:**

**Given** cold start needs first Today paint
**When** `TodayCubit.refreshFastPath()` runs
**Then** at most 3 queries run: `getTodaySteps`, today’s goal, `getLastDisplayedSteps` (AUD-02, NFR-AUD-01)
**And** state emits with `lastDisplayedStepsLoaded: true` using distance-only live metrics
**And** `weekDays` may be empty/placeholders until deferred work completes

**Given** fast path has emitted
**When** deferred work runs
**Then** `_loadWeekDays`, active buckets + derived metrics, and last-ingestion/stale banner load via `unawaited` (or equivalent non-blocking schedule)
**And** Today Display Truth Model is preserved (SQLite aggregate remains source of truth)

**Given** existing Today refresh paths (`refresh` / metadata)
**When** this story ships
**Then** full refresh behaviour remains available for non-cold-start callers

**Target files:** `lib/presentation/cubits/today_cubit.dart`  
**Diagnostic:** `diagnostic-cold-start.md` §A2

---

### Story 21-2: Decouple Foreground Backfill from First Today Paint

As a **user**,
I want to see my stored steps before background catch-up finishes,
So that cold start is never blocked 1–2 s on ingestion backfill.

**Acceptance Criteria:**

**Given** first live-pipeline start (`_startLivePipelineFirstTime` or equivalent)
**When** cold-start orchestration runs
**Then** `refreshFastPath()` (or equivalent local paint) completes **before** awaiting `_foregroundBackfill` (AUD-01)
**And** `_foregroundBackfill` is scheduled without blocking first paint (`unawaited` or post-paint)

**Given** backfill later completes
**When** Today is already showing SQLite data
**Then** subsequent refresh/sync may update steps without regressing monotonic same-day display rules

**Given** Story 21-1 is done
**When** this story ships
**Then** coordinator calls the fast-path API rather than inventing a second load path

**Target files:** `lib/core/services/app_lifecycle_coordinator.dart`  
**Diagnostic:** `diagnostic-cold-start.md` §A1 / C1

---

### Story 21-3: Deduplicate Cold-Start getTodaySteps Queries

As a **user**,
I want cold start to avoid re-reading the same day aggregate repeatedly,
So that first paint is not delayed by redundant SQLite round-trips.

**Acceptance Criteria:**

**Given** fast-path already loaded today’s steps
**When** `LiveStepMonitor.start` binds on cold start
**Then** monitor is seeded from the fast-path result (e.g. `start(seedSteps: …)`) and does not re-issue an identical `getTodaySteps` before first paint (AUD-03)
**And** baseline/getTodaySteps duplicate serial calls on the cold-start path are removed or reduced to a single authoritative read

**Given** resume / non-cold-start monitor starts
**When** no seed is available
**Then** existing read behaviour remains correct (no broken live overlay)

**Target files:** `lib/core/services/app_lifecycle_coordinator.dart`, `lib/core/services/live_step_monitor.dart`  
**Diagnostic:** `diagnostic-cold-start.md` §A3 · `diagnostic-acces-concurrents.md` §3

---

### Story 21-4: Route Ingestion Lock Through Session withRetry

As a **user**,
I want background collection locks to survive brief DB reconnects,
So that multi-isolate ingestion does not fail spuriously after session reopen.

**Acceptance Criteria:**

**Given** `IngestionCollectionLock.tryAcquire` / `release` perform SQL
**When** the UI or isolate session needs reopen/retry
**Then** lock SQL runs through `AstraDatabaseSession.withRetry` (or equivalent session API), not raw `StepIngestionRepository.db` (AUD-04, NFR-AUD-03)
**And** single-writer ingestion rule is unchanged (only `BackgroundCollector` writes buckets)

**Given** lock contention between isolates
**When** acquire fails
**Then** behaviour matches current lock semantics (no silent permanent lock leak introduced)

**Target files:** `lib/core/services/background_collector.dart` (and lock/session helpers as needed)  
**Diagnostic:** `diagnostic-acces-concurrents.md` §1

---

### Story 21-5: Batch Week Goal Resolution and Reduce N+1

As a **user**,
I want the week strip under Today to load without seven separate goal queries,
So that post–fast-path enrichment stays snappy (NFR-AUD-02).

**Acceptance Criteria:**

**Given** `_loadWeekDays` (or equivalent) needs goals for 7 local days
**When** goals are resolved
**Then** a single batch API is used (`getGoalsForLocalDays` or repository equivalent) (AUD-06)
**And** the per-day `getGoalForLocalDay` ×7 loop is removed from this path

**Given** a day with no goal row
**When** batch map is applied
**Then** default goal behaviour matches prior single-query semantics

**Target files:** `lib/presentation/cubits/today_cubit.dart`, health-metrics repository as needed  
**Diagnostic:** `diagnostic-cold-start.md` §B1

---

### Story 21-6: Add end_time Index for Last Ingestion Query

As a **user**,
I want stale/last-ingestion checks to stay fast as data grows,
So that Today metadata refresh does not scan the full timeseries table.

**Acceptance Criteria:**

**Given** last-ingestion queries use `MAX(end_time)` (or equivalent) filtered by type
**When** schema migrates
**Then** index `timeseries_samples (type, end_time DESC)` (or documented equivalent name) is added via migration (AUD-07)
**And** migration is incremental and safe on existing installs

**Given** existing queries and tests using timeseries
**When** migration applies
**Then** no functional regression in last-ingestion / stale banner logic

**Target files:** `lib/core/database/migrations.dart` (and schema constants if any)  
**Diagnostic:** `diagnostic-cold-start.md` §B2

---

### Story 21-7: Guard Trends Refresh on Ingestion by Active Tab

As a **user**,
I want background ingestion completion not to refresh Trends while I am on Today,
So that invisible tab work does not steal CPU after catch-up.

**Acceptance Criteria:**

**Given** `_onIngestionComplete` (or equivalent) runs after ingestion
**When** selected tab is not Trends
**Then** `HistoryCubit.refresh` is **not** called (AUD-08)
**And** Today metadata refresh may still run as today

**Given** Trends tab is selected (`_selectedIndex == 1` or equivalent)
**When** ingestion completes
**Then** `HistoryCubit.refresh(silent: true)` (or equivalent) still runs

**Target files:** `lib/presentation/screens/app_scaffold.dart`  
**Diagnostic:** `diagnostic-cold-start.md` §C2

---

### Story 21-8: Non-Blocking Pedometer Drain on Cold Backfill

As a **user**,
I want cold-start catch-up not to wait on empty pedometer drains,
So that background backfill finishes faster when the live monitor is not yet running.

**Acceptance Criteria:**

**Given** cold-start persist/backfill runs before live monitor is active
**When** source drain would block (~timeout per source)
**Then** cold path uses zero/skip source timeout (or skips pedometer drain) so empty drains do not add multi-second waits (AUD-05)
**And** once monitor is active, normal source timeouts remain for genuine drains

**Given** phone source has nothing to drain
**When** cold backfill runs with this optimisation
**Then** ingestion lock + single-writer rules still hold

**Target files:** `lib/core/services/app_lifecycle_coordinator.dart` (persist cycle path)  
**Diagnostic:** `diagnostic-cold-start.md` §A4

---

## Epic 22: Runtime Robustness & UI Error Handling

Users get stable live-pipeline teardown and recoverable preference/profile errors instead of silent or stuck UI.

**Priority:** P1 · **Version bump:** patch+1, build+1 at epic close · **Diagnostics:** 03, 04 (+ loading ghost for 22-2)

### Story 22-1: Harden LiveStepMonitor Dispose Sequencing

As a **user**,
I want live step streaming to tear down cleanly when the pipeline stops,
So that dispose never races with a late `start` or closes the controller too early.

**Acceptance Criteria:**

**Given** `LiveStepMonitor.dispose()` is called
**When** teardown runs
**Then** `stop()` completes (or a `_disposed` flag blocks subsequent `start`) before `_stepsController` is closed (AUD-16)
**And** no unhandled async gap allows `start` after dispose

**Given** existing live monitor tests
**When** this story ships
**Then** tests updated/pass for dispose ordering

**Target files:** `lib/core/services/live_step_monitor.dart`  
**Diagnostic:** `diagnostic-cycle-de-vie-ressoruce.md` Reco #1

---

### Story 22-2: Disable Goal CTA During Today Loading States

As a **user**,
I want the “set goal” control disabled until Today data is ready,
So that I cannot open the goal editor on a ghost/loading ring.

**Acceptance Criteria:**

**Given** `TodayStatus.loading` **or** `lastDisplayedStepsLoaded == false`
**When** Today goal action is rendered
**Then** the CTA is disabled / non-interactive (AUD-17)
**And** semantics reflect disabled state if exposed as a button

**Given** Today is ready with last-displayed loaded
**When** user taps the goal action
**Then** existing editor sheet behaviour is unchanged

**Target files:** `lib/presentation/screens/today_screen.dart` (and related widgets)  
**Diagnostic:** `diagnostic-etat-chargement.md` §3.1

---

### Story 22-3: Add Retry Path for Profile and Settings Load Errors

As a **user**,
I want a way to retry when Profile/Settings fail to load,
So that a transient error does not leave me stuck on static error text.

**Acceptance Criteria:**

**Given** `ProfileStatus.error` is shown on Profile or Settings
**When** the error UI renders
**Then** a visible retry control is available (AUD-18)
**And** activating retry calls `ProfileCubit.refresh()` (or equivalent) and returns to loading/ready

**Given** retry succeeds
**When** refresh completes
**Then** normal Profile/Settings content is shown

**Target files:** Profile/Settings screens + `profile_cubit.dart` as needed  
**Diagnostic:** `diagnostic-gestion-etat-erreur.md` §2

---

### Story 22-4: Align Theme Preference Error Feedback with Other Settings

As a **user**,
I want theme/accent save failures to show the same feedback as locale/units failures,
So that preference errors are never silent only for theme.

**Acceptance Criteria:**

**Given** `ThemeCubit` persist fails
**When** user changes theme mode or accent
**Then** UI shows SnackBar (or equivalent) consistent with locale/units/notification preference failures (AUD-19)
**And** ThemeCubit either catches and reports failure or screen handles the thrown error uniformly

**Given** persist succeeds
**When** preference changes
**Then** no error feedback is shown

**Target files:** `theme_cubit.dart`, `settings_screen.dart`  
**Diagnostic:** `diagnostic-gestion-etat-erreur.md` Synthèse #4

---

### Story 22-5: Enable discarded_futures Lint and Fix Callback Sites

As a **developer**,
I want `discarded_futures` enabled with call sites fixed,
So that fire-and-forget Futures in UI callbacks are explicit and reviewable.

**Acceptance Criteria:**

**Given** `analysis_options.yaml`
**When** this story ships
**Then** `discarded_futures` is enabled (AUD-20)
**And** known callback sites (`my_data_screen`, Today stale tap, Settings theme/accent, onboarding flow, etc.) use `unawaited`/`await` appropriately
**And** `flutter analyze` is clean for these sites

**Target files:** `analysis_options.yaml` + listed UI call sites  
**Diagnostic:** `diagnostic-convention-structure.md` §2.2

---

## Epic 23: Accessibility WCAG

Users of assistive tech can activate goal/units controls, hear live updates, focus segmented controls, and use charts/week pills.

**Priority:** P1 · **Version bump:** minor+1, patch=0, build+1 · **Diagnostic:** 05

### Story 23-1: Add Semantic Button Label for Today Goal Action

As a **TalkBack/VoiceOver user**,
I want the Today goal control announced as a labelled button,
So that I can set my goal without relying on visual layout alone.

**Acceptance Criteria:**

**Given** Today goal InkWell / `_GoalRingCard` action
**When** semantics tree is built
**Then** node is `Semantics(button: true, label: …)` with a clear action label (AUD-25)
**And** label aligns with UX-AUD-02 intent where applicable

**Target files:** `lib/presentation/screens/today_screen.dart`  
**Diagnostic:** `diagnostic-accessibilité-statique.md` Bloquant

---

### Story 23-2: Add Semantic Coverage for Unit Option Tiles

As a **TalkBack/VoiceOver user**,
I want each unit option tile announced as a button with its unit name,
So that I can change units without unlabeled tappable areas.

**Acceptance Criteria:**

**Given** `_UnitOptionTile` InkWell
**When** semantics tree is built
**Then** `Semantics(button: true, label: …)` wraps the tile (AUD-26)
**And** selected state is reflected when applicable

**Target files:** `lib/presentation/widgets/unit_option_picker_sheet.dart` (or actual path)  
**Diagnostic:** `diagnostic-accessibilité-statique.md` Bloquant

---

### Story 23-3: Introduce Live Region for Goal Ring, Activity Stats, and Health Status

As a **TalkBack/VoiceOver user**,
I want step count, activity stats, and collection health changes announced politely,
So that live updates are audible without flooding intermediate animation frames.

**Acceptance Criteria:**

**Given** GoalRing / AnimatedStepCount and ActivityStatsRow update values
**When** the committed value changes
**Then** a polite `liveRegion` announces the final value, not every count-up tick (AUD-27, UX-AUD-02)

**Given** CollectionHealthIndicator and BackgroundStatusCard status text changes
**When** status updates
**Then** polite `liveRegion` announces the new status (AUD-31)

**Given** GoalCelebration
**When** celebration fires once/day
**Then** existing polite liveRegion + decorative excludeSemantics remain correct (UX-AUD-03)

**Target files:** GoalRing / ActivityStats / collection health / background status widgets  
**Diagnostic:** `diagnostic-accessibilité-statique.md` LiveRegion Majeur

---

### Story 23-4: Restore Visible Keyboard Focus on Segmented Controls

As a **keyboard user**,
I want a visible focus indicator on segmented controls,
So that I know which segment is focused.

**Acceptance Criteria:**

**Given** `AstraSegmentedControl` (PeriodToggle and similar)
**When** focused via keyboard
**Then** visible focus/highlight feedback is not neutralized (AUD-28, NFR-AUD-07)
**And** existing selected styling still distinguishes selection from focus

**Target files:** `astra_segmented_control.dart` (or equivalent)  
**Diagnostic:** `diagnostic-accessibilité-statique.md` Focus Majeur

---

### Story 23-5: Complete Chart Keyboard and Semantic Selection Support

As a **keyboard / TalkBack user**,
I want chart bars to be focusable with announced selection,
So that Trends charts are not touch-only.

**Acceptance Criteria:**

**Given** `StepBarChart` / `TrendsMonthlyBarChart` / `AstraBarChartCore`
**When** user focuses and activates a bar
**Then** interaction uses a focusable pattern (`FocusableActionDetector` or Semantics + shortcuts) (AUD-29)
**And** selected bar is announced
**And** existing Semantics already present are extended, not removed

**Target files:** chart widgets under `lib/presentation/`  
**Diagnostic:** `diagnostic-accessibilité-statique.md` charts Majeur

---

### Story 23-6: Add Goal-Achieved Semantics in Week Day Pills

As a **TalkBack user**,
I want week day pills to announce whether the daily goal was achieved,
So that the coloured indicator is not color-only information.

**Acceptance Criteria:**

**Given** `_DayPill` shows a visual goal-achieved marker
**When** semantics label is built
**Then** label includes achieved / not-achieved status (AUD-30)
**And** day identity remains in the label

**Target files:** week progress widget / today week strip  
**Diagnostic:** `diagnostic-accessibilité-statique.md` week_progress Majeur

---

### Story 23-7: Merge Semantics for Settings Notifications Switch

As a **TalkBack user**,
I want the notifications switch and its label exposed as one control,
So that I am not forced to navigate label and switch separately.

**Acceptance Criteria:**

**Given** Settings notifications Switch + adjacent label
**When** semantics tree is built
**Then** `MergeSemantics` (or equivalent) combines them into one actionable node (AUD-32)
**And** toggle state is announced

**Target files:** `settings_screen.dart`  
**Diagnostic:** `diagnostic-accessibilité-statique.md` settings Majeur

---

## Epic 24: Design System & Loading States

Loading and sheet/chrome visuals are consistent; dead tokens are cleaned; Trends PeriodToggle is not interactively “ghost”.

**Priority:** P2 · **Version bump:** patch+1 (or minor if UX expands) · **Diagnostics:** 06, 07, 08

### Story 24-1: Extract Shared SheetDragHandle Component

As a **user**,
I want editor sheets to share the same drag handle,
So that sheet chrome feels consistent and duplicated magic numbers disappear.

**Acceptance Criteria:**

**Given** display-name / goal / weight / height editor sheets
**When** drag handle is rendered
**Then** a shared `SheetDragHandle` widget is used (32×4, radius 2) (AUD-34, UX-AUD-08)
**And** duplicated local handle widgets/constants are removed

**Target files:** `*_editor_sheet.dart` + new shared widget  
**Diagnostic:** `diagnostic-coherence-design-system.md` Reco #1

---

### Story 24-2: Remove or Wire Dead Typography and Color Tokens

As a **developer**,
I want unused typography wrappers and `borderPrimary` resolved,
So that the design system does not advertise dead APIs.

**Acceptance Criteria:**

**Given** dead `AstraTypography.*(BuildContext)` wrappers and unused `AstraColors.borderPrimary`
**When** this story ships
**Then** they are removed **or** wired to real call sites (AUD-35)
**And** `flutter analyze` / tests remain green

**Target files:** `astra_typography.dart`, `astra_colors.dart`  
**Diagnostic:** `diagnostic-code-mort.md` Haute

---

### Story 24-3: Unify Loading Patterns for Week and Trends Surfaces

As a **user**,
I want Today week and Trends chart loading to use the same visual language for local SQLite waits,
So that loading does not feel like three different apps.

**Acceptance Criteria:**

**Given** Today week strip and Trends charts wait on local data
**When** loading UI shows
**Then** patterns are unified (skeleton family consistent with UX-AUD-01 / UX-AUD-04) (AUD-36)
**And** My Data long I/O may keep spinners but local-wait surfaces share one approach

**Target files:** today week UI, history/trends chart loading  
**Diagnostic:** `diagnostic-etat-chargement.md` §2.1

---

### Story 24-4: Centralize Repeated Chart Layout and Typography Values

As a **developer**,
I want chart axis reserved sizes and repeated nav/week typography to live in one token source,
So that layout tweaks do not drift across charts.

**Acceptance Criteria:**

**Given** duplicated `_kLeftAxisReserved` / `kAstraBarChart*` values
**When** this story ships
**Then** a single shared constant/token source is used (AUD-37)

**Given** inline `TextStyle` for nav label (10/w700) and week day number (16/w900)
**When** styles are applied
**Then** `AstraTypography.navLabel` and `weekDayNumber` (or equivalent) exist and are used (AUD-39)

**Target files:** chart constants, `astra_typography.dart`, call sites  
**Diagnostic:** `diagnostic-coherence-design-system.md` Reco #2–3

---

### Story 24-5: Clean Orphan Preference Default Constants

As a **developer**,
I want truly orphan preference defaults cleaned without deleting live defaults,
So that dead constants do not confuse future prefs work.

**Acceptance Criteria:**

**Given** `kDefaultAccentPresetStorage` and `kDefault*DisplayUnit` orphans
**When** cleaned
**Then** they are removed or used in parsers (AUD-38)
**And** `kDefaultStepGoal` / `kDefaultAccentPreset` are **not** deleted (README correction)
**And** unused `displayLabel` getters are removed only with matching test updates

**Target files:** preference/constants files + tests  
**Diagnostic:** `diagnostic-code-mort.md` §6 · audits README nuance

---

### Story 24-6: Disable PeriodToggle During History Loading

As a **user**,
I want the Trends period toggle disabled while History is loading,
So that I cannot change period on a ghost skeleton state.

**Acceptance Criteria:**

**Given** `HistoryStatus.loading` (or equivalent)
**When** PeriodToggle is shown above skeletons
**Then** interaction is disabled or deferred (AUD-40, UX-AUD-04)
**And** chrome may remain visible

**Given** History becomes ready
**When** toggle is enabled
**Then** period changes work as before

**Target files:** `history_screen.dart` / PeriodToggle usage  
**Diagnostic:** `diagnostic-etat-chargement.md` §3.6

---

## Epic 25: Architecture & Structural Debt

Maintainers can evolve Today/lifecycle/DI/My Data without presentation leaks or god-classes.

**Priority:** P3 · **Version bump:** patch+1 (or minor if broad UX-visible) · **Diagnostics:** 09, 11  
**Prerequisite:** Prefer after Epics 21, 22, 26 stabilize shared files.

### Story 25-1: Split TodayCubit by Responsibility Boundaries

As a **developer**,
I want TodayCubit split along clear responsibilities,
So that cold-start/live/celebration changes do not risk a 1100-line god class.

**Acceptance Criteria:**

**Given** `today_cubit.dart` ~1100 LOC
**When** split completes
**Then** responsibilities are separated (e.g. refresh/fast-path, live attach, celebration, multi-day) behind clear APIs (AUD-44)
**And** public behaviour for Today screen remains equivalent
**And** tests updated for new types/entry points

**Target files:** `lib/presentation/cubits/today_cubit.dart` (+ extracted collaborators)  
**Diagnostic:** `diagnostic-convention-structure.md` Synthèse Haute

---

### Story 25-2: Split AppLifecycleCoordinator into Focused Services

As a **developer**,
I want lifecycle orchestration split into focused services,
So that midnight, persist, and live-pipeline changes stay isolated.

**Acceptance Criteria:**

**Given** `app_lifecycle_coordinator.dart` ~848 LOC
**When** split completes
**Then** focused services exist (midnight boundary, persist cycle, live pipeline) with a thin coordinator or facade (AUD-45)
**And** existing public entry points used by app/scaffold keep working
**And** Epic 26 tests still target the public contracts (update imports as needed)

**Target files:** `lib/core/services/app_lifecycle_coordinator.dart` (+ extracts)  
**Diagnostic:** `diagnostic-convention-structure.md` Synthèse Haute

---

### Story 25-3: Remove Presentation Dependency from Core DI Layer

As a **developer**,
I want `core/di` free of `presentation/` imports,
So that dependency direction stays Clean Architecture–compliant.

**Acceptance Criteria:**

**Given** `app_dependencies.dart` imports presentation types (e.g. theme)
**When** this story ships
**Then** those types live outside presentation (core/domain) or DI receives them without importing presentation (AUD-46)
**And** app still boots with theme/accent wiring intact

**Target files:** `lib/core/di/app_dependencies.dart` + moved types  
**Diagnostic:** `diagnostic-convention-structure.md` §1.3

---

### Story 25-4: Decouple MyDataCubit from UI Dialog Types

As a **developer**,
I want MyDataCubit free of UI dialog enums/FilePicker defaults,
So that data lifecycle logic can be tested without presentation widgets.

**Acceptance Criteria:**

**Given** `MyDataCubit` imports `confirm_dialog.dart` / embeds FilePicker defaults
**When** this story ships
**Then** `PurgeConfirmAction` (or equivalent) lives in core/data and FilePicker is injected/callback-based (AUD-47)
**And** My Data UI behaviour is unchanged for users

**Target files:** `my_data_cubit.dart`, dialog/types locations  
**Diagnostic:** `diagnostic-convention-structure.md` §3.2

---

### Story 25-5: Add Core Data Class Doc Comments for Public Services

As a **developer**,
I want public core/data classes documented,
So that new contributors understand contracts without reading every call site.

**Acceptance Criteria:**

**Given** the public `core/`/`data/` classes listed without `///` in diagnostic §2.1
**When** this story ships
**Then** each listed class has a concise `///` doc comment (AUD-48)
**And** comments describe responsibility, not narrate implementation line-by-line

**Target files:** listed classes in diagnostic-convention-structure §2.1  
**Diagnostic:** `diagnostic-convention-structure.md` §2.1

---

## Epic 26: Orchestration Tests & Resilience

Critical cold-start, resume, notification, day-rollover, and live-monitor failure paths are covered by named unit/fault-injection tests.

**Priority:** P1 · **Version bump:** patch+1 · **Diagnostic:** 10  
**Note:** Can run in parallel with E22/E23 after E21 stabilizes hot paths; update if E25 renames types.

### Story 26-1: Cover onTodayCubitReady Cold-Start Orchestration

As a **developer**,
I want `onTodayCubitReady` tested by name,
So that cold-start live-pipeline attachment regressions are caught without relying on widget-only coverage.

**Acceptance Criteria:**

**Given** `AppLifecycleCoordinator.onTodayCubitReady`
**When** unit/orchestration tests run
**Then** at least one test invokes the method by name and asserts attach/backfill/bind sequencing expectations (AUD-50, NFR-AUD-06)
**And** tests do not require a full app widget tree if fakes/contracts suffice

**Target files:** new/updated tests under `test/` · coordinator  
**Diagnostic:** `diagnostic-couverture-structurelle.md` Top #2

---

### Story 26-2: Cover onLifecycleStateResumed Failure and Recovery

As a **developer**,
I want resume orchestration tested including forced pipeline failure,
So that the resume `catch` path cannot regress silently.

**Acceptance Criteria:**

**Given** `onLifecycleStateResumed`
**When** `_resumeLivePipeline` (or equivalent) is forced to fail in test
**Then** catch/recovery behaviour is asserted (AUD-51)
**And** happy-path resume still has a named coverage test

**Target files:** coordinator tests  
**Diagnostic:** `diagnostic-couverture-structurelle.md` Top #1

---

### Story 26-3: Cover Goal Notification Evaluation and Rollback Path

As a **developer**,
I want `maybeNotifyGoalReachedIfGoalMet` covered including rollback,
So that FR goal-notification failures do not leave prefs inconsistent.

**Acceptance Criteria:**

**Given** `maybeNotifyGoalReachedIfGoalMet`
**When** tests run by method name
**Then** evaluation when goal met/not met is covered (AUD-52)
**And** when `showGoalReached` fails, preference rollback is asserted

**Target files:** `background_collector` tests  
**Diagnostic:** `diagnostic-couverture-structurelle.md` Top #3

---

### Story 26-4: Cover refreshAfterDayRollover Contract

As a **developer**,
I want `TodayCubit.refreshAfterDayRollover` covered directly,
So that midnight UI reset contracts do not rely only on day-boundary monitor tests.

**Acceptance Criteria:**

**Given** `refreshAfterDayRollover`
**When** unit tests invoke it by name
**Then** catch-up / celebration reset / SQLite refresh contract is asserted (AUD-53)

**Target files:** `today_cubit` tests  
**Diagnostic:** `diagnostic-couverture-structurelle.md` Top #5

---

### Story 26-5: Cover Isolate Background Collector Factory Bootstrap

As a **developer**,
I want `createIsolateBackgroundCollector` tested directly,
So that WorkManager/FGS isolate bootstrap regressions are caught early.

**Acceptance Criteria:**

**Given** `createIsolateBackgroundCollector`
**When** tests invoke the factory by name
**Then** bootstrap wiring (sources/repos/notifications as applicable) is asserted without requiring a device isolate if fakes suffice (AUD-54)

**Target files:** `background_collector_factory` tests  
**Diagnostic:** `diagnostic-couverture-structurelle.md` Top #4

---

### Story 26-6: Add Fault-Injection Tests for Live Monitor Stream Errors

As a **developer**,
I want LiveStepMonitor stream errors fault-injected in tests,
So that `onError` / peek timeout paths cannot regress unnoticed.

**Acceptance Criteria:**

**Given** `LiveStepMonitor.start`
**When** the steps stream errors in a test double
**Then** `onError` handling is asserted (AUD-55)
**And** peek timeout/error paths have at least minimal coverage if reachable via the same harness

**Target files:** `live_step_monitor` tests  
**Diagnostic:** `diagnostic-couverture-structurelle.md` LiveStepMonitor error paths

---

## Epic 27: Boot Polish & Lazy Trends

Cold start sheds serial pre-`runApp()` work; `HistoryCubit` is created only when the user opens Trends.

**Priority:** P0 polish · **Version bump:** patch+1, build+1 at epic close · **Diagnostics:** 02 (Phase C1, Phase D)  
**Prerequisite:** Epics 21 (fast path) and 25 (scaffold/cubit splits) done.

### Story 27-1: Parallelize Initial Preference Reads with Future.wait

As a **user**,
I want app startup to read my saved preferences in parallel,
So that DI creation does not wait on seven sequential SQLite round-trips.

**Acceptance Criteria:**

**Given** `AppDependencies.create` (and test factory paths that mirror the same reads)
**When** initial theme, accent, units, onboarding, and locale prefs are loaded
**Then** the seven reads run via `Future.wait` (or equivalent single parallel batch) instead of seven serial `await`s (AUD-13)
**And** parsed values match prior single-read semantics (same defaults on missing rows)

**Given** one pref read fails unexpectedly
**When** the batch completes
**Then** failure behaviour matches or improves on current behaviour (no silent corruption of unrelated prefs)

**Given** Epic 21 fast path is in place
**When** this story ships
**Then** Today cold-start paint path is unchanged — this optimizes DI only

**Target files:** `lib/core/di/app_dependencies.dart`  
**Diagnostic:** `diagnostic-cold-start.md` §Phase D1

---

### Story 27-2: Defer WorkManager Registration Until After runApp

As a **user**,
I want background task registration not to block the first frame,
So that cold start reaches the GoalRing faster.

**Acceptance Criteria:**

**Given** app boot in `main.dart`
**When** `runApp` is invoked
**Then** `registerStepCollectionWorkmanager` and `registerDatabaseMaintenanceWorkmanager` are **not** awaited on the critical path before `runApp` (AUD-14)
**And** registration is scheduled post-`runApp` (e.g. post-frame callback or `unawaited` after first frame) with the same `databasePath` argument

**Given** registration completes after first frame
**When** the user interacts with Today immediately
**Then** foreground live pipeline and fast path still work (WorkManager is reconciliation fallback, not first-frame dependency)

**Given** registration fails
**When** error is logged
**Then** app remains usable on UI isolate (no crash on boot)

**Target files:** `lib/main.dart`  
**Diagnostic:** `diagnostic-cold-start.md` §Phase D2

---

### Story 27-3: Non-Blocking Notification Init Before First Frame

As a **user**,
I want notification channel setup not to serially block app launch for up to 3 seconds,
So that cold start is not gated on platform notification init.

**Acceptance Criteria:**

**Given** `NotificationService.initialize()` in `main.dart`
**When** boot runs
**Then** notification init is not a hard serial gate before `AppDependencies.create` / `runApp` (AUD-15)
**And** init runs in parallel with DI, or is deferred until after first frame, preserving the existing 3s timeout guard where applicable

**Given** notification init times out or fails
**When** the app continues boot
**Then** behaviour matches current resilience (debug log, app still launches)
**And** goal-notification migration in `main.dart` still receives a `NotificationService` instance (may be partially initialized)

**Given** notifications later become ready
**When** goal-reached or preference flows need the service
**Then** existing call sites tolerate late init or no-op safely (no new crash paths)

**Target files:** `lib/main.dart`, `lib/core/services/notification_service.dart` (if init contract adjusted)  
**Diagnostic:** `diagnostic-cold-start.md` §Phase D3

---

### Story 27-4: Lazy Instantiate HistoryCubit on First Trends Tab

As a **user**,
I want Trends data work to start only when I open the Trends tab,
So that cold start does not pay for History cubit setup and IndexedStack mount cost.

**Acceptance Criteria:**

**Given** app launch with default Today tab selected
**When** `AppScaffold` initializes
**Then** `HistoryCubit` is **not** constructed eagerly in `initState` (AUD-11)
**And** cubit is created on first navigation to Trends (`_selectedIndex == 1`) via existing `createHistoryCubit` / `onHistoryCubitReady` hooks

**Given** user opens Trends for the first time
**When** cubit is created
**Then** `onHistoryCubitReady` fires and first `refresh()` behaviour matches current first-visit contract
**And** Epic 21 guard (`_onIngestionComplete` only refreshes History when Trends selected) still holds

**Given** user switches away and back to Trends
**When** tab is reselected
**Then** scroll position / period selection persist (session behaviour unchanged)
**And** cubit instance is retained (not recreated each visit)

**Given** widget tests or integration tests construct `AppScaffold`
**When** this story ships
**Then** tests updated for lazy init (no assumption that History cubit exists before Trends selection)

**Target files:** `lib/presentation/screens/app_scaffold.dart`, related tests  
**Diagnostic:** `diagnostic-cold-start.md` §Phase C1 · `diagnostic-etat-chargement.md` §4 (History zombie loading note)

---

## Epic 28: UX Coherence (Errors & Permissions)

Stale-data recovery and permission-denied messaging are consistent; Settings appearance prefs are not gated on Profile load.

**Priority:** P1 UX · **Version bump:** minor+1, patch=0, build+1 at epic close · **Diagnostics:** 04, 06  
**Scope note:** Targeted UX only — **no** unified `AppFailure` model (AUD-22, AUD-23 remain deferred).

### Story 28-1: Add Tap-to-Refresh on My Data Stale Banner

As a **user**,
I want to tap the stale-data banner on My Data to trigger a refresh,
So that stale recovery matches Today’s compact stale banner behaviour.

**Acceptance Criteria:**

**Given** `MyDataCubit` state has `isStale == true`
**When** the `StatusBanner` with `StatusBannerVariant.staleFull` renders
**Then** the banner is tappable and calls `MyDataCubit.refresh(silent: false)` (or equivalent non-silent refresh) on tap
**And** semantics expose it as an actionable control (button or tappable banner label)

**Given** user taps the stale banner
**When** refresh runs
**Then** section loading indicators appear per existing My Data loading pattern
**And** banner hides or updates when refresh completes and stale clears

**Given** Today stale banner (`_StaleBannerSlot`)
**When** this story ships
**Then** Today behaviour is unchanged — parity only on My Data

**Target files:** `lib/presentation/screens/my_data_screen.dart`, `MyDataCubit` if refresh contract needs adjustment  
**Diagnostic:** `diagnostic-gestion-etat-erreur.md` §4 (stale — My Data sans `onTap`)

---

### Story 28-2: Unify Today Permission-Denied Messaging and CTA

As a **user**,
I want one clear permission-denied message and settings action on Today,
So that I am not confused by four different visual treatments for the same condition.

**Acceptance Criteria:**

**Given** activity permission is denied (`TodayStatus.noPermission`)
**When** Today screen renders
**Then** **one primary** user-facing permission pattern is shown with a single CTA to open app settings (AUD-24)
**And** redundant inline captions / duplicate CTAs for the same condition are removed or demoted to non-interactive supporting text

**Given** permission is denied
**When** GoalRing and ActivityStatsRow render
**Then** they may keep neutral placeholders (`--`, zeros) but must not introduce a second competing CTA
**And** `CollectionHealthIndicator` caption aligns with the primary message (no contradictory copy)

**Given** permission is granted later
**When** Today refreshes
**Then** primary CTA and health indicator update without layout regressions

**Given** My Data permission UI
**When** this story ships
**Then** My Data `BackgroundStatusCard` is unchanged (Today-only unification scope)

**Target files:** `lib/presentation/screens/today_screen.dart`, collection health / goal ring widgets as needed  
**Diagnostic:** `diagnostic-gestion-etat-erreur.md` §4 (permission refusée — fragmentation Today)

---

### Story 28-3: Decouple Settings Theme, Locale, and Units from Profile Loading Gate

As a **user**,
I want to change theme, locale, and units even while Profile is still loading,
So that independent preferences are not blocked by profile fetch.

**Acceptance Criteria:**

**Given** `ProfileCubit` is in `ProfileStatus.loading`
**When** Settings screen renders
**Then** locale, units, theme mode, accent, and notification preference sections are visible and interactive (AUD-43)
**And** only profile-dependent sections (if any) remain behind the profile loading gate

**Given** `ProfileStatus.error`
**When** Settings is open
**Then** preference sections remain usable (existing retry for profile error unchanged from Story 22-3)
**And** preference persist failures still use SnackBar feedback (22-4 pattern)

**Given** user changes locale/units/theme while profile loads
**When** persist succeeds
**Then** cubits update immediately without waiting for profile ready

**Given** widget tests for Settings
**When** this story ships
**Then** tests cover interactive prefs during `ProfileStatus.loading`

**Target files:** `lib/presentation/screens/settings_screen.dart`, tests  
**Diagnostic:** `diagnostic-etat-chargement.md` §3 item 10 · `diagnostic-gestion-etat-erreur.md` (Settings vs Profile gate)
