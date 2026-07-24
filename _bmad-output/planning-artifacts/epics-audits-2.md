---
stepsCompleted: [1, 2, 3, 4]
status: complete
validatedAt: 2026-07-24
completedAt: 2026-07-24
validationNotes: |
  34/34 AUD2-FR covered. 8/8 NFR addressed via story ACs. 5/5 UX-DR covered.
  22 stories across E29–E33. No forward within-epic dependencies detected.
  File overlap (background_collector, live_step_monitor) justified by sequential stories.
  Open product decision: 32-3 disclaimer vs SQLCipher. FR34 notification rethrow in 31-3.
epicsApprovedAt: 2026-07-24
storiesDraftAt: 2026-07-24
storyCounts:
  epic-29: 5
  epic-30: 4
  epic-31: 6
  epic-32: 5
  epic-33: 2
  total: 22
requirementsConfirmedAt: 2026-07-24
extractedAt: 2026-07-24
scope: audits_2 — data pipeline integrity & hardening (post E28)
baseVersion: 0.12.1+31
project_name: astra-app
inputDocuments:
  - planning-artifacts/audits_2/README.md
  - planning-artifacts/audits_2/diagnostic-couche-donnees.md
  - planning-artifacts/audits_2/diagnostic-permissions-notifications.md
  - planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md
  - planning-artifacts/audits_2/diagnostic-downsampling-compaction-fr11.md
  - planning-artifacts/audits_2/diagnostic-fuseaux-jours-locaux.md
  - planning-artifacts/audits_2/diagnostic-preferences-utilisateur.md
  - planning-artifacts/audits_2/diagnostic-ingestion-pedometer.md
  - planning-artifacts/audits_2/diagnostic-charts-agregation-daily-monthly.md
  - planning-artifacts/audits_2/diagnostic-live-step-monitor.md
---

# astra-app - Epic Breakdown (audits_2)

## Overview

Epic and story breakdown derived exclusively from **audits_2** data-pipeline diagnostics (`0.12.1+31`, `pubspec.yaml`). Scope: 11 P0 findings, P1–P3 debt, and documentation gaps. Continuity with `epics-post-audit.md` (E21–E28 delivered); proposed epic numbering E29+.

**Out of scope:** PRD Phase 0 features, audits v1 backlog (E27–E28 deferred AUDs), unrelated refactors.

## Requirements Inventory

### Functional Requirements

AUD2-FR1: `StepNormalizer` must persist `terminalBaseline` as the internal accepted baseline (`baseline ?? initialBaseline`), not `lastCumulative`, so rejected noise readings do not corrupt the next collection cycle (`step_normalizer.dart:108`).

AUD2-FR2: `LiveStepMonitor.drainReadingsForCollection` must not silently discard hardware-reset readings (cumulative ≤ persisted baseline/2); reset events must reach `StepNormalizer`/`StepIncrementCalculator` for persist path (`live_step_monitor.dart:333-346`).

AUD2-FR3: `BackgroundCollector._collectOnce` must commit bucket upserts and `setBaseline` atomically per source so partial failure cannot cause additive double-counting on the next cycle (`background_collector.dart:116-128`).

AUD2-FR4: `SampleCompactionRunner` must verify aggregated insert succeeded before deleting source buckets; `ConflictAlgorithm.ignore` + unconditional delete is forbidden (`sample_compaction_runner.dart:51-56,145-254`).

AUD2-FR5: `SampleIdGenerator.deterministicFromIngestionBucket` must include `type` and `resolution` in the PK hash, aligned with `idx_bucket_identity` (`sample_id_generator.dart:30-37`).

AUD2-FR6: `insertDevSamplesBatch` must use a release-safe runtime guard (`if (!kDebugMode) throw`), not `assert`, to block dev-only inserts in production (`step_ingestion_repository.dart:92-99`).

AUD2-FR7: Permission model must distinguish `permanentlyDenied` from reversible `denied` for activity and notifications, with CTA `openAppSettings()` when permanent (`onboarding_state.dart`, `profile_cubit.dart`, `settings_screen.dart`).

AUD2-FR8: After the intro activity-permission OS dialog, the app must **surface visible post-denial feedback** on intro (inline copy + Retry for reversible `denied`, Settings CTA for `permanentlyDenied`) before the user explicitly continues to weight. **Silent auto-advance on deny is forbidden.** Advance after deny remains allowed per Epic 13 Story 13.1 — via an explicit second Continue, not immediate `nextStep()` (`onboarding_flow.dart:52-55`).

AUD2-FR9: Post-onboarding activity permission must support `.request()` retry when not permanently denied (Today/Settings), not only `openAppSettings()`.

AUD2-FR10: `NotificationService._initializePlatform` must propagate init failures (`rethrow` or explicit failure signal) so callers and boot sequence can detect broken notification setup (`notification_service.dart:105-122`).

AUD2-FR11: `DataLifecycleService.runMaintenanceOnConnection` (WM maintenance path) must acquire a cross-isolate lock before downsample/VACUUM to prevent collision with 15-min step collection (`data_lifecycle_service.dart:41-59`, `workmanager_callback.dart:129-156`).

AUD2-FR12: Product must either implement SQLCipher Phase 1 for local DB encryption or display an explicit privacy disclaimer that health data is stored in plaintext (NFR-4 Phase 0 gap) (`app_database.dart`, `pubspec.yaml`).

AUD2-FR13: Provider and device identity strings in sample ID generation must be normalized with `.toLowerCase()` before regex stripping (`sample_id_generator.dart:35`).

AUD2-FR14: `PRAGMA busy_timeout` must be configured on DB open to reduce multi-isolate contention failures (`app_database.dart:16-21`).

AUD2-FR15: Permission status mapping must be centralized per permission type (notification vs activity); `isLimited`/`isProvisional` must not be applied to activity recognition (`activity_permission_resolver.dart`, `onboarding_cubit.dart`, `notification_service.dart`).

AUD2-FR16: Onboarding permission resolution must not map all platform exceptions to `denied`; distinguish technical failures for logging/diagnostics (`onboarding_cubit.dart:108-113`).

AUD2-FR17: Boot sequence must structurally gate WorkManager cancel → notification init (await or explicit barrier), not rely on implicit ordering in `main.dart` (`main.dart:61-63`).

AUD2-FR18: iOS background step collection gap (no WorkManager scheduling) must be documented with resume/backfill strategy (`workmanager_callback.dart:174-176`).

AUD2-FR19: My Data goal display must load via `getGoalForLocalDay(today)`; `getDailyStepGoal()` must be deprecated or removed to eliminate dual source-of-truth (`user_health_metrics_repository.dart`).

AUD2-FR20: `isDatabaseOpen` must return a safe boolean without throwing when DB is null/closed; fix `today_live_pipeline.dart:198` guard (`_user_preferences_kv_store.dart:13`).

AUD2-FR21: Persist-path credit rules (`drain gate` vs `StepIncrementCalculator`) must be unified or explicitly documented as a single source of truth (`live_step_monitor.dart:345` vs `step_increment_calculator.dart:37-56`).

AUD2-FR22: `testHookAfterDeleteSamples` must be removed from the public ingestion repository contract; expose only via test-only implementation hook (`step_ingestion_repository_contract.dart`).

AUD2-FR23: Migration v3 `effective_from_local_day` seed must use injectable `TimeProvider` for deterministic migration tests (`migrations.dart:119-123`).

AUD2-FR24: `ProfileCubit.setGoalNotificationsEnabled` must guard against concurrent toggles (pattern parity with `_refreshInFlight`).

AUD2-FR25: `NotificationService.initializeForBackground` timeout must cancel or ignore late init results to avoid `_initialized` flip-flop (`notification_service.dart:67-79`).

AUD2-FR26: Maintenance lock must use a dedicated key and longer TTL (or explicit release) if reusing `IngestionCollectionLock` pattern for VACUUM (`ingestion_collection_lock.dart:14`).

AUD2-FR27: `_TimeoutBoundedSource` must use injected `TimeProvider` instead of `DateTime.now()` for deterministic collection timeout tests (`background_collector.dart:220,227`).

AUD2-FR28: Compaction `hourlyCreated`/`dailyCreated` counters must increment only on confirmed successful insert (`sample_compaction_runner.dart:146,196,249`).

AUD2-FR29: Chart SQL queries may add an upper-bound UTC filter aligned with local-day window to reduce unnecessary row load (`_step_chart_queries.dart:10-14`).

AUD2-FR30: `lifecycle_compaction.dart` must document that DST transition days intentionally skip compaction (do not relax 12/24/288 counts without offset-aware math).

AUD2-FR31: `_step_chart_queries.dart` must document intentional `DateTime.utc` month/day rollover patterns.

AUD2-FR32: User goal architecture must document single-writer contract (`setDailyStepGoal` → journal + prefs txn) and prefs-vs-journal roles.

AUD2-FR33: If plaintext DB is maintained, document NFR-4 Phase 0 footprint explicitly in product-facing copy (My Data / privacy).

AUD2-FR34: Regression tests required: terminalBaseline after rejected noise; drain reboot post-high-baseline; compaction insert-ignored + no source delete; mid-cycle collect fault injection; notification init failure rethrow.

### NonFunctional Requirements

AUD2-NFR1: **Step count integrity** — no silent over-counting (double upsert, corrupted baseline, compaction loss) or under-counting (drain filter dropping resets) in persist path.

AUD2-NFR2: **SQLite concurrency** — UI, WorkManager, and maintenance tasks must not corrupt or deadlock the shared `astra_app.db` file under normal Android scheduling.

AUD2-NFR3: **Privacy at rest honesty** — stored health data protection level must match user-facing privacy claims (encrypt or disclose plaintext).

AUD2-NFR4: **Permission UX reliability** — permission toggles and onboarding CTAs must never appear broken/silent after permanent denial or init failure.

AUD2-NFR5: **Compaction safety (FR11)** — re-running compaction on modified source data must not delete fine-grained samples while retaining stale aggregates.

AUD2-NFR6: **Observability** — dropped drain readings and compaction insert conflicts must be loggable for field diagnosis.

AUD2-NFR7: **Test determinism** — migrations, collection timeouts, and baseline persistence paths must support injected clocks in tests.

AUD2-NFR8: **Preserve existing strengths** — offset-per-row local-day model, `finestResolutionTotal` read path, WAL + ingestion lock for collection, live vs persist separation in `LiveStepMonitor`.

### Additional Requirements

- **Base version:** `0.12.1+31` (`pubspec.yaml`); line references in diagnostics are acceptance anchors — re-verify if files shifted.
- Epic numbering continues from `epics-post-audit.md` — draft E29–E33 in audits_2 README.
- Quick fixes (Q1–Q6) may ship in one PR before epic stories: terminalBaseline, drain reset, dev batch guard, ID multi-type, lowercase identity, notification rethrow.
- **Preserve:** `ON CONFLICT DO UPDATE value += excluded.value` additive upsert, `IngestionCollectionLock` for collection, `finestResolutionTotal` for charts, offset-immutable rows, FR11 completeness guards in compaction.
- **Do not:** relax DST compaction bucket counts without offset-aware math; sum all resolutions for same local day; strip `assert`-only guards without runtime replacement; **re-fix drain reset (FR2) and normalizer baseline (FR1) in isolation without addressing AUD2-FR21** — persist-path credit rules (reset vs noise vs forward) must stay unified via shared helper or single documented source of truth, not duplicated again across `live_step_monitor`, `StepIncrementCalculator`, and collector paths.
- **Epic 29 = atomic E-B bundle (diagnostics 07 + 09 + 03 + 04):** stories 29-1→29-5 should ship in dependency order within one epic; avoid merging 29-1/29-2/29-3 as independent PRs out of sequence.
- Verify after changes: `flutter test --tags critical` for normalizer; localized tests per touched file per workspace rules.
- Cross-diagnostic dependency order for implementation: 01 → 07 → 09 → 03 → 04 → 05 → 08 → 06 → 02.
- Stories must update diagnostic status in `audits_2/` README and individual `.md` files when fixed.

### UX Design Requirements

AUD2-UX1: Settings screen notification toggle failure must show distinct UI for permanent denial with CTA opening system app settings (not generic snackbar only).

AUD2-UX2: Today screen and My Data background-status card must distinguish permanent vs reversible activity denial and offer appropriate action (retry `.request()` vs `openAppSettings()`).

AUD2-UX3: On onboarding intro, after activity permission is denied, show **non-blocking feedback** (Retry for reversible deny, Settings for permanent deny, explanatory copy). User may still reach weight via explicit Continue — Epic 13. **No silent skip to weight step.** UX §3.7 "Skip notifications" = superseded notification opt-in only.

AUD2-UX4: My Data privacy/footprint section must reflect actual data-at-rest protection (encrypted vs plaintext disclaimer per AUD2-FR12/FR33).

AUD2-UX5: Permission-related error states must not masquerade platform bugs as user denial (align with AUD2-FR16 logging; UI shows actionable message where safe).

### FR Coverage Map

| FR | Epic | Description |
|----|------|-------------|
| FR1 | E29 | terminalBaseline normalizer |
| FR2 | E29 | drain reset matériel |
| FR3 | E29 | txn collecte atomique |
| FR4 | E29 | compaction insert-before-delete |
| FR5 | E32 | ID multi-type |
| FR6 | E32 | garde dev batch release-safe |
| FR7–FR10 | E31 | permissions + notif init |
| FR11 | E30 | lock maintenance VACUUM |
| FR12 | E32 | privacy at rest |
| FR13 | E32 | lowercase identity |
| FR14 | E30 | busy_timeout |
| FR15–FR17 | E31 | mapping centralisé, boot gate |
| FR18 | E30 | doc gap iOS |
| FR19–FR20 | E32 | goal single-source, isDatabaseOpen |
| FR21 | E29 | règles drain unifiées |
| FR22–FR23 | E32 | hook test, TimeProvider migration |
| FR24–FR25 | E31 | dedup toggle, timeout background |
| FR26–FR27 | E30 | TTL maintenance, TimeProvider collecte |
| FR28 | E29 | compteurs compaction |
| FR29–FR31 | E33 | SQL charts, doc DST/rollover |
| FR32–FR33 | E32 | doc goal, disclaimer plaintext |
| FR34 | E29 | tests régression comptage |

## Epic List

### Epic 29: Accurate Step Tracking (Persist Path)
Users see reliable step counts that survive sensor noise, hardware reboots, background collection, and FR11 compaction.
**FRs covered:** FR1, FR2, FR3, FR4, FR21, FR28, FR34 · **NFRs:** NFR1, NFR5, NFR6, NFR8

### Epic 30: Stable Database Under Background Load
The app maintains SQLite integrity during WorkManager maintenance, VACUUM, and multi-isolate access without corruption or deadlock.
**FRs covered:** FR11, FR14, FR18, FR26, FR27 · **NFRs:** NFR2, NFR7

### Epic 31: Clear Permission & Notification Flows
Users always understand why tracking or goal notifications fail and how to fix them (retry vs system Settings).
**FRs covered:** FR7, FR8, FR9, FR10, FR15, FR16, FR17, FR24, FR25 · **UX:** UX1–UX3, UX5 · **NFRs:** NFR4

### Epic 32: Trustworthy Local Data Storage
Local health data uses correct IDs, production-safe guards, a single goal source of truth, and honest privacy disclosure.
**FRs covered:** FR5, FR6, FR12, FR13, FR19, FR20, FR22, FR23, FR32, FR33 · **UX:** UX4 · **NFRs:** NFR3, NFR7

### Epic 33: Maintainable Charts & Time-Zone Pipeline
History and Trends remain correct long-term; DST and chart date math are documented to prevent maintainer regressions.
**FRs covered:** FR29, FR30, FR31

---

## Epic 29: Accurate Step Tracking (Persist Path)

Users trust persisted step counts — no silent over- or under-counting after sensor noise, hardware reboot, background sync, or compaction.

**Priority:** P0 · **Version bump:** minor+1 at epic close (data integrity) · **Diagnostics:** 07, 09, 03, 04  
**Prerequisite:** Epics 21–28 delivered · **Atomic bundle:** E-B (07+09+03+04) — one epic, ordered stories, no out-of-sequence merges · **Recommended order:** 29-1 → 29-2 → 29-3 → 29-4 → 29-5

### Story 29-1: Fix terminalBaseline After Rejected Sensor Noise

As a **user**,
I want my step baseline to stay correct when the pedometer sends noisy readings,
So that the next background sync does not over-count steps.

**Acceptance Criteria:**

**Given** `StepNormalizer.normalizeReadings` with an accepted increment followed by a rejected noise dip as the **last** reading in the batch
**When** normalization completes
**Then** `terminalBaseline` equals the internal accepted `baseline` (not `lastCumulative`) — AUD2-FR1
**And** `BackgroundCollector` persists that value via `setBaseline`

**Given** the regression test in `step_normalizer_test.dart` (`rejects small counter dips`)
**When** extended for this story
**Then** it asserts `terminalBaseline` when the final reading is rejected noise — AUD2-FR34

**Given** existing `@Tags critical` normalizer tests
**When** this story ships
**Then** `flutter test --tags critical` passes

**Target files:** `lib/data/datasources/step_normalizer.dart`, `test/data/datasources/step_normalizer_test.dart`  
**Diagnostic:** `diagnostic-ingestion-pedometer.md` #1 · Quick fix Q1

---

### Story 29-2: Forward Hardware Reset Readings Through Live Drain

As a **user**,
I want steps after a phone reboot to be saved even when the hardware counter resets below my stored baseline,
So that my daily total is not permanently under-counted.

**Acceptance Criteria:**

**Given** a persisted baseline of 10 000 and post-reboot readings 50, 100, 150
**When** `drainReadingsForCollectionGated()` runs
**Then** reset readings pass through to `StepNormalizer` (not silently discarded by `>` filter alone) — AUD2-FR2
**And** persist path credits steps consistent with `StepIncrementCalculator` reset rule (`current <= baseline/2`)

**Given** a small dip above reset threshold (noise, not hardware reset)
**When** drain runs
**Then** behaviour matches prior intent — noise still filtered appropriately

**Given** readings dropped by the drain gate
**When** filtering occurs
**Then** `livePipelineLog` records the drop reason — AUD2-NFR6

**Given** baseline 10 000 and readings 50/100/150 post-reboot
**When** covered by a new test in `idle_flush_persist_test.dart` or `live_step_monitor_test.dart`
**Then** persist path credits the reset — AUD2-FR34

**Target files:** `lib/core/services/live_step_monitor.dart`, `test/core/services/idle_flush_persist_test.dart` (or `live_step_monitor_test.dart`)  
**Diagnostic:** `diagnostic-live-step-monitor.md` #1 · Quick fix Q2

---

### Story 29-3: Atomic Bucket Upsert and Baseline Commit Per Source

As a **user**,
I want background step collection to commit buckets and baseline together,
So that a mid-cycle failure cannot double-count steps on the next sync.

**Acceptance Criteria:**

**Given** `BackgroundCollector._collectOnce` processing one source with multiple bucket upserts
**When** upserts and `setBaseline` run
**Then** they execute inside a single database transaction per source — AUD2-FR3
**And** partial upsert without baseline commit cannot survive a crash/exception within that source cycle

**Given** an exception after some upserts in the **prior** implementation
**When** the next collection cycle runs
**Then** the same deltas are not additively merged a second time (regression test or fault-injection test) — AUD2-FR34

**Given** `ON CONFLICT DO UPDATE value += excluded.value` additive semantics
**When** this story ships
**Then** additive upsert behaviour is preserved — AUD2-NFR8

**Target files:** `lib/core/services/background_collector.dart`, `test/core/services/background_collector_test.dart`  
**Diagnostic:** `diagnostic-workmanager-maintenance-db.md` #1

---

### Story 29-4: Guard Compaction Delete Until Insert Succeeds

As a **user**,
I want downsampling to never delete fine-grained step data unless the aggregated bucket was actually written,
So that re-compaction cannot silently lose my history.

**Acceptance Criteria:**

**Given** `SampleCompactionRunner` tier passes (5min→hourly, hourly→daily, catch-up)
**When** `insertCompactedSample` uses `ConflictAlgorithm.ignore` and PK already exists
**Then** source buckets are **not** deleted unless insert succeeded or aggregate value is verified current — AUD2-FR4, AUD2-NFR5

**Given** a re-run on modified source data with a stale existing aggregate PK
**When** compaction executes
**Then** fine-grained sources are preserved (no silent loss) — regression test — AUD2-FR34

**Given** a successful insert
**When** compaction completes
**Then** `hourlyCreated` / `dailyCreated` increment only on confirmed insert — AUD2-FR28

**Given** insert conflict with divergent aggregate value
**When** detected
**Then** anomaly is logged — AUD2-NFR6

**Target files:** `lib/core/lifecycle/sample_compaction_runner.dart`, `test/data/repositories/step_repository_downsample_test.dart`  
**Diagnostic:** `diagnostic-downsampling-compaction-fr11.md` #1

---

### Story 29-5: Unify Persist Credit Rules (Drain vs Calculator)

As a **developer maintaining step integrity**,
I want a single documented rule for whether a reading is forwarded to persist,
So that drain gate and `StepIncrementCalculator` cannot diverge again.

**Acceptance Criteria:**

**Given** `live_step_monitor.dart` drain gate and `step_increment_calculator.dart`
**When** this story ships
**Then** either (a) a shared helper `shouldForwardReadingForPersistence(current, baseline)` is used by both paths, or (b) drain pre-filter is removed and anti-double-credit is documented in one place — AUD2-FR21

**Given** hardware reset, noise dip, and normal increment scenarios
**When** evaluated by the unified rule
**Then** persist path matches calculator semantics from Story 29-2

**Given** UI live path (`_applyReadingToDelta`)
**When** unchanged by refactor
**Then** live display behaviour is preserved — AUD2-NFR8

**Target files:** `lib/core/services/live_step_monitor.dart`, `lib/data/datasources/step_increment_calculator.dart` (+ shared helper if extracted)  
**Diagnostic:** `diagnostic-live-step-monitor.md` #2

---

## Epic 30: Stable Database Under Background Load

SQLite stays consistent when WorkManager runs 15-min collection and weekly maintenance concurrently with the UI isolate.

**Priority:** P0–P1 · **Version bump:** patch+1 at epic close · **Diagnostics:** 03, 01  
**Prerequisite:** Epic 29 recommended first (shared `BackgroundCollector` / compaction paths)

### Story 30-1: Cross-Isolate Lock for Maintenance and VACUUM

As a **user**,
I want database maintenance not to collide with background step collection,
So that my data file is not corrupted during VACUUM or downsampling.

**Acceptance Criteria:**

**Given** `DataLifecycleService.runMaintenanceOnConnection` with `maintenanceOnCurrentConnection: true` (WM path)
**When** maintenance runs downsample + VACUUM
**Then** a cross-isolate lock is acquired before work begins — AUD2-FR11
**And** the 15-min step collection task waits or skips while lock is held (same pattern as `IngestionCollectionLock`)

**Given** maintenance lock implementation
**When** configured
**Then** it uses a dedicated lock key and TTL suited to VACUUM duration (not 35s collection TTL) — AUD2-FR26

**Given** UI-triggered maintenance via `compute` offload
**When** WM maintenance is not running
**Then** existing UI path behaviour is preserved — AUD2-NFR8

**Target files:** `lib/core/services/data_lifecycle_service.dart`, `lib/core/services/workmanager_callback.dart`, `lib/core/services/ingestion_collection_lock.dart`  
**Diagnostic:** `diagnostic-workmanager-maintenance-db.md` #2

---

### Story 30-2: Configure PRAGMA busy_timeout on Database Open

As a **user**,
I want the app to retry briefly when SQLite is busy across isolates,
So that background tasks and UI do not fail with avoidable `database_locked` errors.

**Acceptance Criteria:**

**Given** `AppDatabase` / `onConfigure` (or equivalent open hook)
**When** the database connection opens
**Then** `PRAGMA busy_timeout=5000` (or project-standard value) is set — AUD2-FR14

**Given** concurrent WM collection and UI read under test
**When** contention occurs
**Then** `AstraDatabaseSession.withRetry` can recover without user-visible failure in happy-path tests

**Target files:** `lib/core/database/app_database.dart`  
**Diagnostic:** `diagnostic-couche-donnees.md` #5

---

### Story 30-3: Document iOS Background Collection Gap

As an **iOS user**,
I want clear product documentation on how steps sync when the app is closed for days,
So that expectations match actual resume/backfill behaviour.

**Acceptance Criteria:**

**Given** WorkManager registration is Android-only (`!Platform.isAndroid` early return)
**When** documentation is updated
**Then** iOS background collection gap and resume/backfill strategy are documented in `docs/project-context.md` or architecture addendum — AUD2-FR18
**And** no code change implies iOS has 15-min WM collection

**Target files:** `docs/project-context.md` (or linked architecture section)  
**Diagnostic:** `diagnostic-workmanager-maintenance-db.md` #3

---

### Story 30-4: Inject TimeProvider into Collection Timeout Source

As a **developer**,
I want collection timeout boundaries to use the injected clock,
So that background collector timeout tests are deterministic.

**Acceptance Criteria:**

**Given** `_TimeoutBoundedSource` in `background_collector.dart`
**When** enforcing `maxCollectionDuration`
**Then** it uses injected `TimeProvider` (same as lock/notification paths), not raw `DateTime.now()` — AUD2-FR27, AUD2-NFR7

**Given** a unit test with a fake clock
**When** deadline elapses
**Then** timeout behaviour is asserted without real time delays

**Target files:** `lib/core/services/background_collector.dart`, `test/core/services/background_collector_test.dart`  
**Diagnostic:** `diagnostic-workmanager-maintenance-db.md` #6

---

## Epic 31: Clear Permission & Notification Flows

Permission and notification flows never feel broken — users get retry or Settings guidance for every denial mode.

**Priority:** P0 · **Version bump:** minor+1 at epic close (UX + onboarding) · **Diagnostics:** 02  
**Prerequisite:** None (can parallel Epic 29 after 29-1)

### Story 31-1: Model permanentlyDenied with Settings CTA

As a **user**,
I want the app to tell me when a permission is permanently denied and open Settings,
So that I am not stuck with a silent toggle or button.

**Acceptance Criteria:**

**Given** activity or notification permission in `permanentlyDenied` state
**When** user interacts with Settings notification toggle, Today permission slot, or My Data background card
**Then** UI distinguishes permanent vs reversible denial — AUD2-FR7, AUD2-UX1, AUD2-UX2
**And** permanent denial shows CTA calling `openAppSettings()` with clear copy

**Given** reversible `denied` (not permanent)
**When** user taps CTA on Today / My Data
**Then** `.request()` retry is offered where platform allows — AUD2-FR9

**Target files:** `lib/presentation/cubits/onboarding_state.dart`, `profile_cubit.dart`, `settings_screen.dart`, `today_screen.dart`, `background_status_card.dart`  
**Diagnostic:** `diagnostic-permissions-notifications.md` #1

---

### Story 31-2: Onboarding Intro — Post-Denial Feedback (Epic 13–aligned)

As a **new user**,
I want visible feedback and the right action when I deny activity permission on intro,
So that I know tracking is limited and can retry or open Settings before continuing.

**Acceptance Criteria:**

**Given** user taps Continue on intro (Epic 13 permission bridge)
**When** OS dialog returns `granted`
**Then** flow advances to weight immediately (unchanged happy path)

**Given** OS dialog returns reversible `denied`
**When** dialog dismisses
**Then** user **stays on intro** — `nextStep()` is **not** called automatically — AUD2-FR8
**And** visible inline feedback explains that step tracking requires activity access — AUD2-UX3
**And** a **Retry** control re-triggers `.request()` (primary action while denied)
**And** Continue (or equivalent explicit control) lets user proceed to weight without granting — Epic 13 Story 13.1

**Given** OS dialog returns `permanentlyDenied`
**When** dialog dismisses
**Then** user stays on intro with feedback — no silent advance — AUD2-FR8
**And** copy explains permission was permanently denied and Settings is required to enable tracking — AUD2-UX3
**And** **Open Settings** CTA calls `openAppSettings()` — AUD2-FR7 partial
**And** explicit Continue still allows reaching weight; Today `no permission` handles degraded tracking (UX §1001)

**Given** user taps Retry and grants on second dialog
**When** permission becomes `granted`
**Then** flow advances to weight (feedback UI dismissed)

**Given** current bug (`onboarding_flow.dart:52-55`)
**When** this story ships
**Then** `await requestActivityPermission()` is followed by branch on `activityPermissionStatus`, not unconditional `nextStep()`

**Given** widget or cubit test for denied + permanentlyDenied paths
**When** dialog simulated as denied
**Then** intro feedback is visible and weight step is not shown until explicit Continue — AUD2-FR34 (partial)

**Given** Epic 13 scope
**When** this story ships
**Then** no dedicated Permissions/Goal onboarding screens reintroduced (superseded 2026-06-17)

**Out of scope:** blocking onboarding completion entirely on deny.

**Authority:** `sprint-change-proposal-2026-06-17.md` + Epic 13 Story 13.1 (explicit continue after deny OK) > UX §3.7 (obsolete)

**Target files:** `lib/presentation/onboarding/onboarding_flow.dart`, `onboarding_intro_page.dart`, `onboarding_cubit.dart`, tests  
**Diagnostic:** `diagnostic-permissions-notifications.md` #2

---

### Story 31-3: Propagate Notification Platform Init Failures

As a **developer**,
I want notification init failures to surface to boot and tests,
So that broken plugin setup is not silently swallowed.

**Acceptance Criteria:**

**Given** `_initializePlatform` throws or fails natively
**When** `NotificationService.initialize()` runs
**Then** failure propagates (`rethrow` or explicit failure on `_initFuture`) — AUD2-FR10
**And** `main()` / boot can log or handle the failure (no swallowed catch in `_initializePlatform`)

**Given** `notification_service_test.dart`
**When** extended
**Then** init failure rethrow is covered — AUD2-FR34 (partial)

**Target files:** `lib/core/services/notification_service.dart`, `test/core/services/notification_service_test.dart`  
**Diagnostic:** `diagnostic-permissions-notifications.md` #3 · Quick fix Q6

---

### Story 31-4: Centralize Permission Status Mapping by Type

As a **developer**,
I want one permission mapper per permission kind,
So that notification `isLimited`/`isProvisional` rules are not wrongly applied to activity recognition.

**Acceptance Criteria:**

**Given** notification vs activity permission checks
**When** status is mapped to app enum
**Then** a centralized resolver applies type-correct rules — AUD2-FR15
**And** duplicated `_mapPermissionStatus` copies in onboarding/profile/notification paths are removed or delegate to resolver

**Given** a platform exception during permission resolution
**When** onboarding resolves permission
**Then** it is logged distinctly and not always mapped to `denied` — AUD2-FR16, AUD2-UX5

**Target files:** `lib/core/permissions/activity_permission_resolver.dart`, `notification_service.dart`, `onboarding_cubit.dart`  
**Diagnostic:** `diagnostic-permissions-notifications.md` #4, #5

---

### Story 31-5: Structural Boot Gate — Cancel WM Before Notification Init

As a **developer**,
I want boot to serialize WorkManager cancel and notification init,
So that isolate races cannot regress silently when `main.dart` changes.

**Acceptance Criteria:**

**Given** app boot sequence
**When** `cancelStepCollectionWorkmanager` and notification init run
**Then** order is encapsulated (cancel → await init or explicit barrier) — AUD2-FR17
**And** behaviour matches current intentional ordering documented in `workmanager_callback.dart`

**Given** a boot regression test or documented integration check
**When** reviewed
**Then** parallel unawaited init cannot precede cancel without test failure

**Target files:** `lib/main.dart`, optionally `lib/core/services/boot_sequence.dart` (if extracted)  
**Diagnostic:** `diagnostic-workmanager-maintenance-db.md` #4, `diagnostic-permissions-notifications.md`

---

### Story 31-6: Harden Profile Notification Toggle Concurrency

As a **user**,
I want rapid taps on the goal-notification toggle to behave predictably,
So that the switch does not flip back or drop requests.

**Acceptance Criteria:**

**Given** concurrent calls to `ProfileCubit.setGoalNotificationsEnabled`
**When** a toggle is in flight
**Then** subsequent calls are deduplicated or queued (pattern parity with `_refreshInFlight`) — AUD2-FR24

**Given** `initializeForBackground` hits timeout
**When** underlying init completes later
**Then** late result does not flip `_initialized` inconsistently — AUD2-FR25

**Target files:** `lib/presentation/cubits/profile_cubit.dart`, `lib/core/services/notification_service.dart`  
**Diagnostic:** `diagnostic-permissions-notifications.md` #6, #7

---

## Epic 32: Trustworthy Local Data Storage

IDs, dev guards, goal storage, and privacy copy reflect how data is actually stored on device.

**Priority:** P0–P2 · **Version bump:** patch+1 at epic close · **Diagnostics:** 01, 06

### Story 32-1: Align Ingestion Sample IDs with Bucket Identity Index

As a **developer**,
I want ingestion sample IDs to include type and resolution,
So that future multi-type samples cannot collide on the same primary key.

**Acceptance Criteria:**

**Given** `SampleIdGenerator.deterministicFromIngestionBucket`
**When** generating an ID
**Then** `type` and `resolution` participate in the hash, aligned with `idx_bucket_identity` — AUD2-FR5
**And** provider/device identity strings are lowercased before regex normalization — AUD2-FR13

**Given** existing step-only ingestion
**When** this ships
**Then** IDs remain stable for current data **or** migration path is documented if IDs change (prefer backward-compatible suffix addition only for new writes)

**Target files:** `lib/core/ids/sample_id_generator.dart`, `lib/data/repositories/step/step_ingestion_repository.dart`  
**Diagnostic:** `diagnostic-couche-donnees.md` #2, #4 · Quick fixes Q4, Q5

---

### Story 32-2: Release-Safe Guard on Dev Sample Batch Insert

As a **product owner**,
I want dev-only sample injection blocked in release builds,
So that production builds cannot accidentally bypass ingestion safeguards.

**Acceptance Criteria:**

**Given** a release build (`!kDebugMode`)
**When** `insertDevSamplesBatch` is called
**Then** a runtime `StateError` (or equivalent) is thrown — not an stripped `assert` — AUD2-FR6

**Given** debug/test builds
**When** dev batch insert is used
**Then** existing test/dev behaviour is preserved

**Target files:** `lib/data/repositories/step/step_ingestion_repository.dart`  
**Diagnostic:** `diagnostic-couche-donnees.md` #3 · Quick fix Q3

---

### Story 32-3: Privacy at Rest — Product Decision (Disclaimer or SQLCipher)

As a **user**,
I want the app to honestly state how my health data is protected on device,
So that privacy claims match actual storage.

**Acceptance Criteria:**

**Given** Phase 0 plaintext SQLite (`sqflite` without SQLCipher) — AUD2-FR12
**When** product chooses **disclaimer path** (default for this epic unless Baptiste selects SQLCipher)
**Then** My Data / privacy copy states health data is stored locally without encryption — AUD2-FR33, AUD2-UX4
**And** marketing-facing docs aligned with NFR-4 Phase 0 stance

**Given** product chooses **SQLCipher path** instead
**When** implemented
**Then** `sqlcipher_flutter_libs` (or project-standard package) encrypts `astra_app.db` with Keystore-derived passphrase per architecture Phase 1 notes
**And** UX4 copy reflects encrypted storage

**Given** either path
**When** story closes
**Then** decision recorded in story notes and `audits_2/README.md` P0-01 status updated

**Target files:** `pubspec.yaml`, `lib/core/database/app_database.dart`, My Data privacy UI, `docs/project-context.md`  
**Diagnostic:** `diagnostic-couche-donnees.md` #1

---

### Story 32-4: Single Goal Source and Safe Database Open Check

As a **user**,
I want my daily goal and live pipeline to read one authoritative value,
So that My Data and Today never disagree after refresh.

**Acceptance Criteria:**

**Given** My Data goal display on refresh
**When** goal is loaded
**Then** it uses `getGoalForLocalDay(todayIso)` not legacy `getDailyStepGoal()` — AUD2-FR19
**And** `getDailyStepGoal()` is deprecated or removed from production call paths

**Given** `UserSettingsRepository.isDatabaseOpen` / KV store guard
**When** database is null or closed
**Then** predicate returns `false` without throwing — AUD2-FR20
**And** `today_live_pipeline.dart` guard works as intended

**Given** goal architecture
**When** documented
**Then** single-writer contract (`setDailyStepGoal` → journal + prefs txn) is documented — AUD2-FR32

**Target files:** `lib/data/repositories/user_health_metrics_repository.dart`, `_user_preferences_kv_store.dart`, `user_settings_repository.dart`, My Data cubit/screen, `today_live_pipeline.dart`  
**Diagnostic:** `diagnostic-preferences-utilisateur.md` #1, #2

---

### Story 32-5: Test Hook and Deterministic Migration v3

As a **developer**,
I want test-only hooks off public contracts and migrations injectable clocks,
So that repository alternatives and migration tests stay clean and deterministic.

**Acceptance Criteria:**

**Given** `StepIngestionRepositoryContract`
**When** reviewed after this story
**Then** `testHookAfterDeleteSamples` is not on the public interface — AUD2-FR22
**And** test access uses `@visibleForTesting` on concrete impl or test subclass only

**Given** migration v3 seed of `effective_from_local_day`
**When** `runMigrations` executes v3 upgrade
**Then** date uses injectable `TimeProvider` — AUD2-FR23, AUD2-NFR7

**Target files:** `lib/data/contracts/step_ingestion_repository_contract.dart`, `lib/data/repositories/step/step_ingestion_repository.dart`, `lib/core/database/migrations.dart`  
**Diagnostic:** `diagnostic-couche-donnees.md` #6, #7

---

## Epic 33: Maintainable Charts & Time-Zone Pipeline

Document DST compaction intent and chart date math so future changes do not break History/Trends.

**Priority:** Doc / P3 · **Version bump:** patch+1 at epic close · **Diagnostics:** 05, 08

### Story 33-1: Document DST Non-Compaction Intent

As a **maintainer**,
I want explicit comments that DST days skip FR11 compaction by design,
So that no one “fixes” bucket counts and reintroduces double-counting.

**Acceptance Criteria:**

**Given** `lifecycle_compaction.dart` near `kHourlyBucketsPerDay` / `isComplete*` helpers
**When** this story ships
**Then** comment states DST transition days intentionally skip compaction — do not relax 12/24/288 without offset-aware math — AUD2-FR30

**Given** optional follow-up test
**When** simulated DST incomplete day runs through compaction
**Then** 0 merges occur and fine buckets preserved (optional AC — implement if low cost)

**Target files:** `lib/core/lifecycle/lifecycle_compaction.dart`  
**Diagnostic:** `diagnostic-fuseaux-jours-locaux.md` #1

---

### Story 33-2: Document Chart Date Rollover and Optional SQL Upper Bound

As a **maintainer**,
I want chart window math documented and optionally bounded in SQL,
So that History/Trends queries stay efficient and correct.

**Acceptance Criteria:**

**Given** `_step_chart_queries.dart` month rollover via `DateTime.utc(year, month ± n, day)`
**When** this story ships
**Then** inline comments mark intentional UTC rollover patterns — AUD2-FR31

**Given** chart sample queries using `start_time >= lowerBound` only
**When** optional upper bound is implemented
**Then** `sqlUpperBoundUtc` aligns with local-day window (+ buffer per `_step_sample_bounds.dart`) — AUD2-FR29
**And** existing chart aggregate tests pass unchanged

**Target files:** `lib/data/repositories/step/_step_chart_queries.dart`, `test/data/repositories/step_repository_chart_*_test.dart`  
**Diagnostic:** `diagnostic-charts-agregation-daily-monthly.md` #1, #2

