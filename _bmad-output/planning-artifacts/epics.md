---
stepsCompleted: [1, 2, 3, 4]
status: complete
completedAt: 2026-05-25
inputDocuments:
  - prds/prd-astra-app-2026-05-22/prd.md
  - architecture.md
  - ux-design-specification.md
scope: Phase 0 Sandbox
project_name: astra-app
---

# astra-app - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for astra-app, decomposing the requirements from the PRD, UX Design, and Architecture into implementable stories.

**Scope:** Phase 0 Sandbox only — Flutter Hub App (phone steps, SQLite lifecycle, three surfaces, CSV sovereignty). Excludes Phase 1+ items (SQLCipher, BLE/ADP functional, Health Connect, wearable, sync hub, official brand assets).

**Scope amendment (user-confirmed, 2026-05-25):** System / light / dark theme with user choice on My Data. **System is first-launch default** (follows OS). PRD FR-31 and UX spec §1.1–1.2 aligned.

**Scope amendment (user-confirmed, 2026-06-02):** **Epic 5** is now the **design polish pass** (colors, spacing, visual cohesion). Former Epic 5 (OSS Credibility & Beta Readiness) moves to **Epic 6**. Functional theme selector remains Epic 4 Story 4.7; contrast/visual verification moves to Epic 5.

## Development Workflow (all stories)

Every sub-task follows **review before commit**. See [`docs/project-context.md`](../../docs/project-context.md).

| Step | Who | Action |
|------|-----|--------|
| 1 | Agent | Complete one sub-task |
| 2 | Agent | Post review brief (what / why / how to verify / learn) + suggested commit message |
| 3 | Baptiste | Read diff, learn, reply **OK commit** (or request changes) |
| 4 | Agent | Commit only after explicit approval — **one commit per sub-task** |

This gate is mandatory for Phase 0 unless Baptiste explicitly waives it for a given step.

## Requirements Inventory

### Functional Requirements

FR1: The Hub App defines a **DataIngestionSource** interface that yields raw platform **StepReading** events plus source metadata; **StepNormalizer** is the only component that converts cumulative readings into storage-ready step **Timeseries Samples**. New sources register without modifying SQLite write logic. **PhonePedometerSource** and **AdpBleSource** stub both implement the interface.

FR2: **PhonePedometerSource** reads step counts from phone OS sensor APIs (Android = reference platform). Samples include `type=steps`, `unit=count`, `provider=internal_phone`, `device_id=smartphone`. Ingestion respects platform permission flows. Hardware counter reset handling computes delta from last baseline without negative/corrupted totals; unit test covers at least one simulated reset scenario.

FR3: **AdpBleSource** class implements **DataIngestionSource** but returns no data in Phase 0. Stub wired in dependency injection alongside **PhonePedometerSource**; documentation references ADP as Phase 1 activation point.

FR4: **BackgroundCollector** receives normalized **Time Buckets** and writes them to SQLite without requiring the user to open the Hub App. Android: continuous/near-continuous bucket writes via WorkManager/FGS. iOS: backfill on foreground and rare BGAppRefresh — no continuous 5-minute real-time collection. Android beta primary acceptance: same-day passive accumulation (walk ≥500 steps with app not in foreground, not force-stopped; total increases within 15 min WM cycle or on next open). Secondary: daily-goal morning check. Force-stop/OEM kill documented as lag until foreground backfill — not beta failure. 24h stress check remains SM-2 long-run only. Single writer path to **timeseries_samples**. iOS UI copy and My Data stale indicator reflect backfill model.

FR5: **My Data** displays background collection status (last successful collection timestamp, stale-data warning when threshold exceeded). Stale threshold: 12 hours Android, 4 hours iOS. Copy explains platform constraints without blaming the user.

FR6: On Android 14+, background health collection uses appropriate foreground service type (`health`). Manifest declares correct FGS type; no misuse of `dataSync` for health reads.

FR7: Hub persists **Timeseries Samples** in `timeseries_samples` table with OW-aligned columns (id, start_time, end_time, type, value, unit, resolution, provider, device_id, zone_offset). No raw sensor waveforms in any table. Composite index supports type + start_time DESC queries for chart rendering.

FR8: Step samples aggregated into **Time Buckets** of 5 minutes by default before insert. Consecutive samples do not exceed one row per 5-minute window per device. Dev tooling can override bucket size for benchmarks.

FR9: `user_preferences` table stores at minimum `daily_step_goal` (integer) and `theme_mode` (`system` | `light` | `dark`). Optional `display_name` (string, trimmed, local-only) may be stored for a calm Today greeting — no account, no cloud. Goal and theme preference persist across app restarts. Default goal 8000 if user skips setup. Default theme `system` on first launch.

FR10: Database schema changes use numbered migrations from project inception. Fresh install and upgrade from prior schema version both succeed without data loss in Phase 0 test matrix.

FR11: **DataLifecycleService** applies tiered downsampling: 0–30 days at 5min, 31–365 days at 1hour, >365 days at 1day. Downsampling is destructive and irreversible — finer-resolution rows deleted after compaction. Downsampled rows carry updated `resolution` field. Test confirms pre/post compaction export behavior.

FR12: Database maintenance runs weekly when platform permits (Android scheduled job; iOS opportunistic on foreground/resume and optional BGAppRefresh). File size does not grow unbounded after repeated purge/downsample cycles in 90-day inject test. No Phase 0 acceptance criterion assumes reliable iOS background VACUUM.

FR13: **My Data** shows approximate database size, total sample count, and **last database optimization** timestamp. Footprint updates after inject, export, import, purge, and lifecycle operations. "Last optimized" displays relative time after at least one VACUUM run.

FR14: **Today** displays circular progress ring comparing current day steps to **daily_step_goal**. Ring fills proportionally; reaches 100% at or above goal. Daily step total computed per UTC storage + stored `zone_offset`. Step source label visible (phone vs future wearable).

FR15: On first goal completion each calendar day, subtle pulse/celebration animation plays at most once per local calendar day. No gamification score or streak shame messaging.

FR16: **History** renders bar charts for 7-day and 30-day step totals with goal reference line. Chart query + render completes in <100ms with 90 days of continuous injected data (KPI-01). User can switch between 7-day and 30-day views.

FR17: **History** shows simple weekly trend (up/down vs prior week) derived from stored samples only; no network call.

FR18: Hub App performs **no outbound network requests** in the health data pipeline. Release APK manifest has no INTERNET permission. Debug builds may declare INTERNET for Flutter tooling only. `docs/DEPENDENCIES.md` audit lists zero network use in health pipeline. 24-hour airplane mode beta checklist passes on release build.

FR19: User can export **Timeseries Samples** to CSV with OW-aligned column headers. Export preserves `id` column exactly for idempotent import. Export includes all canonical columns. CSV written to local cache/temp before OS share sheet.

FR20: User can delete **all** local **Timeseries Samples** and derived collection state from **My Data**. Post-purge: sample count = 0, footprint ≈ 0 KB. Purge requires explicit confirmation. Purge preserves non-health setup preferences (daily_step_goal, theme_mode, display_name if set, onboarding completion, permission choices). Post-purge onboarding does not restart.

FR21: When user initiates purge, Hub encourages export first (non-blocking). Confirmation dialog mentions export option; user can cancel purge.

FR22: First launch presents local-only privacy explanation before requesting permissions. No account, email, or authentication screen exists. Permission requests occur after trust copy.

FR23: Onboarding collects **daily_step_goal** with set-once philosophy (editable later on My Data). Skipping applies default from FR9.

FR24: Onboarding offers optional local notification permission with explanation tied to goal-celebration use case. Hub functions fully if notifications denied.

FR25: When **BackgroundCollector** detects cumulative daily steps meet or exceed **daily_step_goal**, Hub fires at most one local notification per calendar day. Goal evaluation uses local-day aggregation from SQLite. No notification if permission denied. No notification spam after goal already met.

FR26: Application source code published under **Apache License 2.0**. `LICENSE` file in repo root; README states Apache 2.0.

FR27: Repo includes `docs/OPEN_WEARABLES_ALIGNMENT.md`, `docs/SERIES_TYPES.md`, `docs/DEPENDENCIES.md`, and `docs/REGULATORY_POSITION.md`. OW alignment doc lists column mapping and Phase 0 series types (`steps/count`). Dependencies doc confirms zero network use in health pipeline on release builds.

FR28: Developer tooling can inject 90 days of synthetic **Timeseries Samples** and simulate downsampling. Inject + lifecycle + chart render benchmark reproducible. KPI-01 validated on injected dataset.

FR29: Project maintains documented beta checklist covering accuracy, background, notifications, footprint, export, airplane mode, and visual cohesion. Checklist exists in repo; items trace to FRs. Includes release-build airplane mode, CSV export→purge→import round-trip, step-counter reset unit test.

FR30: User can import previously exported ASTRA CSV to repopulate **timeseries_samples**. Import validates column headers and rejects malformed rows with user-visible error. Idempotent import: preserve `id`, skip duplicate `id`, skip duplicate bucket identity. Round-trip test: export → purge → import restores chart-visible history.

FR31: User can choose **System**, **Light**, or **Dark** appearance from **My Data**. Selection applies immediately app-wide (Today, History, My Data, onboarding if shown). Preference stored in `user_preferences.theme_mode` and restored on cold start without incorrect theme flash. Default is `system` until user changes — app follows OS light/dark when `system` is selected and reacts to OS theme changes without restart.

### NonFunctional Requirements

NFR1: Chart render latency — History chart query + render <100ms (KPI-01) with 90 days of injected step data.

NFR2: Install artifact size — Release APK/IPA <50MB.

NFR3: Offline operation — 100% core features without network.

NFR4: Data at rest — Plaintext SQLite acceptable Phase 0; SQLCipher migration path documented for Phase 1.

NFR5: Accessibility — WCAG 2.1 AA aspirational for Phase 0; baseline semantics, contrast tokens, reduce-motion variants implemented (not blocking beta). Contrast pairs must pass AA in **both** light and dark themes.

NFR6: Localization — English UI for Phase 0 OSS; French copy in README acceptable; i18n-ready structure.

NFR7: Storage budget (1 year) — SQLite DB <50MB with lifecycle active (steps-only).

NFR8: Storage budget (5 years) — SQLite DB <200MB with lifecycle active (steps-only).

NFR9: Time semantics — UTC storage in `start_time`/`end_time`; immutable `zone_offset` per row at ingestion; daily goals and charts use stored offset per row, not device current timezone.

### Additional Requirements

- **Starter template (Epic 1 Story 1):** Initialize Flutter project from repo root via `flutter create . --org com.astraapp --project-name astra_app --platforms=android,ios --android-language=kotlin --empty`. Repo/product name `astra-app`; Dart package `astra_app`; DB file `astra_app.db`; bundle ID `com.astraapp` (locked D-18).
- **Locked dependencies:** sqflite, flutter_bloc, workmanager, pedometer, permission_handler, fl_chart, flutter_local_notifications, share_plus, path_provider, uuid — no analytics/cloud/HTTP packages in health pipeline.
- **Layered lib/ structure:** `core/` (database, di, time, services, constants), `data/` (datasources, models, repositories), `presentation/` (cubits, screens, widgets, onboarding), `dev/` (kDebugMode only).
- **Manual DI:** `AppDependencies` composition root in `main.dart` — no DI framework Phase 0; test factory `AppDependencies.test()`.
- **Single ingestion write path:** Only `BackgroundCollector` calls `StepRepository.upsertIngestionBucket()`; all SQLite writes through `StepRepository` methods.
- **StepNormalizer:** Dedicated component between `DataIngestionSource` and `BackgroundCollector` for cumulative sensor → bucket delta conversion (reboot, reset, overflow).
- **Isolate-safe DB:** UI and WorkManager isolates each open own connection via `getDatabasesPath()`; explicit `PRAGMA journal_mode=WAL` and `PRAGMA foreign_keys=ON` on every open.
- **Bucket identity UNIQUE index:** `(provider, device_id, type, start_time, end_time, resolution)`; ingestion upsert on conflict; CSV import `INSERT OR IGNORE` on UUID `id`.
- **LocalDayCalculator:** Compute `local_day` in Dart from UTC `start_time` + row's stored `zone_offset` — never SQL `date(start_time, zone_offset)` or device current timezone for historical rows.
- **ChartDayAggregate view model:** Repository returns pre-aggregated daily data (~7 or ~31 points); UI/widgets perform zero business aggregation.
- **TimeProvider injection:** No raw `DateTime.now()` in ingestion, lifecycle, or normalization code; `FakeTimeProvider` for tests.
- **Transaction boundaries:** All multi-row writes (CSV import, downsampling, batch inject, purge) in repository-owned `db.transaction()`.
- **WorkManager spike (Sprint 0 gate):** Callback with `@pragma('vm:entry-point')`, `WidgetsFlutterBinding.ensureInitialized()`, writes test bucket on physical Android; foreground backfill fallback if isolate init fails.
- **Android background model:** FGS health + WorkManager orchestration + foreground backfill — WorkManager alone is not realtime guarantee.
- **BackgroundHealthCapabilityEvaluator:** Centralizes activity recognition, battery optimization, notification, FGS health, OEM restriction checks.
- **State management:** Cubit only (`TodayCubit`, `HistoryCubit`, `MyDataCubit`, `OnboardingCubit`, `ThemeCubit`) — no Riverpod, no app-wide reactive streams Phase 0.
- **Theme architecture:** `ThemeData.light()` and `ThemeData.dark()` built from shared `AstraColors` semantic tokens; `MaterialApp.theme` + `MaterialApp.darkTheme` + `themeMode` driven by `ThemeCubit` reading `user_preferences.theme_mode` at startup. Map `system` → `ThemeMode.system`; load preference before first frame where feasible to avoid theme flash.
- **Navigation:** `AppScaffold` + `NavigationBar` (3 tabs) — no GoRouter Phase 0.
- **CSV export flow:** Write to cache/temp file first, then `share_plus` — never in-memory-only share.
- **VACUUM policy:** Never on UI thread; Android from background worker; iOS opportunistic after foreground/resume.
- **Release manifest hardening:** `test/release_manifest_test.dart` asserts no INTERNET in release `AndroidManifest.xml`.
- **Fonts bundled locally:** Figtree + Darker Grotesque in `assets/fonts/` — no runtime network font fetch.
- **Notification dedup:** `user_preferences.celebration_shown_date` for goal celebration/notification coordination.
- **Build variants:** Debug (INTERNET allowed for Flutter tooling) vs Release (no INTERNET, health pipeline audit pass).
- **Documentation bundle:** `docs/BETA_CHECKLIST.md` with FR traceability; update `docs/DEPENDENCIES.md` on any package addition.
- **Implementation sequence (Architecture):** flutter create → database/migrations → datasources/normalizer → BackgroundCollector/WorkManager → DataLifecycleService/dev inject → repositories → presentation → CSV export/import/purge → onboarding/notifications → release manifest + beta checklist.

### UX Design Requirements

UX-DR1: Implement `AstraColors` extension with **paired dark + light token sets** mirroring UX §1.2 semantic structure — surfaces, text hierarchy, accent amber `#EAD55E` (primary + muted @28%), data colors, semantic status. Dark palette per UX spec (`bg.base` `#0F1114`, etc.). Light palette: inverted surfaces (e.g. base `#F8F9FB`, elevated `#FFFFFF`, subtle `#EEF0F4`), dark text on light surfaces, accent usage unchanged (ring stroke, CTA fills, active tab). Wire to both `ThemeData.dark()` and `ThemeData.light()`; widgets consume semantic tokens only — no hardcoded hex per theme in components.

UX-DR2: Implement typography tokens — Figtree (UI shell) + Darker Grotesque (data hero) bundled locally in `assets/fonts/` with tokens: display 52sp, title 24sp, headline 18sp, body 16sp, label 14sp, caption 12sp, data 20sp. Max 2 font families per screen; sentence case everywhere.

UX-DR3: Implement spacing/radius tokens on 4px grid — space.xs through space.2xl; radius.sm/md/lg/full. Screen horizontal padding minimum 16dp; bottom tab bar 56dp + safe area; touch targets minimum 48×48dp.

UX-DR4: Build `AppScaffold` with persistent 3-tab `NavigationBar` (Today · History · My Data), elevated tab bar surface, amber active tab, muted inactive — no drawer, no settings tab.

UX-DR5: Build `GoalRing` widget — stroke ring 220–260dp diameter, 9dp stroke, center step count (Darker Grotesque display), sublabels "steps today" + "goal N", track accent-muted, progress arc accent primary, overflow shows actual count with ring capped at 100%, states: loading skeleton, empty, progress, goal met, overflow, no-permission dashed track.

UX-DR6: Build `GoalCelebration` composite (FR-15) — ring scale pulse 1.0→1.05→1.0 (600ms), glow halo 0→18%→0% (800ms), stroke shimmer (200–700ms), optional center count scale, micro-copy "Daily goal reached" 2s fade, haptic light impact Android, once per local calendar day, reduce-motion variant (static ring + micro-copy only).

UX-DR7: Build `SourceChip` pill under Today hero — "Phone sensor" caption with subtle bg; future-ready for wearable label.

UX-DR8: Build `StatusBanner` with variants ok/stale/info/error — 3px left accent, compact stale (~40dp single line) on Today, full stale banner on My Data when threshold exceeded; iOS info variant for backfill honesty.

UX-DR9: Build `StepBarChart` + `PeriodToggle` — vertical bars accent-muted fill, dashed goal reference line, 7d/30d segmented control 48dp height, empty state copy, loading skeleton (7 gray bars), no animation on 7d↔30d rebind (KPI-01).

UX-DR10: Build `TrendChip` (P1) — arrow + percentage vs prior week, positive/negative/muted colors, informational copy ("Up 12% from last week" — no coach language).

UX-DR11: Build My Data layout — scrollable order: BackgroundStatusCard → FootprintKpiRow (sample count, DB size, last optimized) → GoalEditor row → **Appearance** (`ThemeSelector`: System / Light / Dark segmented control) → Data actions (Export/Import/Purge). No README/external footer.

UX-DR12: Build `BackgroundStatusCard` — healthy/stale/ios_backfill/permission_denied states with dot indicator and platform-honest copy per UX §2.5.

UX-DR13: Build `GoalEditorSheet` — bottom sheet with free numeric field, validation 1,000–100,000 integer, Save disabled until valid; same pattern on onboarding step 3 with default 8000.

UX-DR14: Build data action flows — Export (outline primary → spinner → share sheet → snackbar), Import (file picker → validate → confirm if data exists → progress → snackbar), Purge (danger text → ConfirmDialog with export-first nudge per FR-21).

UX-DR15: Build `ConfirmDialog` — purge variant with Export first / Delete anyway / Cancel; import overwrite variant with row count preview.

UX-DR16: Build onboarding 3-step full-screen stack — Trust (local-only copy before permissions) → Permissions (activity first, optional notification toggle) → Goal (numeric field, skip applies 8000) → land on Today tab; back allowed steps 2–3 only; never show account/email.

UX-DR17: Build shared `AstraButton` variants — primary (amber fill + inverse text), secondary outline, ghost, danger (purge confirm only); min height 48dp.

UX-DR18: Implement motion spec — tab cross-fade 200ms, chart toggle 250ms or instant if reduce-motion; no pull-to-refresh, no confetti/streak animations.

UX-DR19: Implement accessibility baseline — Semantics labels for GoalRing ("Steps today: N of goal"), progress ring value/min/max, liveRegion polite for goal celebration, English labels (NFR-6), decorative celebration elements `excludeSemantics: true`, OS font scaling to 130% without hero count clipping.

UX-DR20: Implement copy/tone guardrails — calm factual voice per UX §4.6; no coach language, no clinical claims, no blame on stale banners; locale-aware number grouping for display.

UX-DR21: Visual polish checklist (FR-29) — items V-1 through V-13 traceable to beta handoff, updated for themes: system default on first launch, token consistency in light and dark, typography, tab cohesion, celebration once/day, chart perf, purge empty state, stale dual banner, theme preference survives purge, no theme flash on cold start.

UX-DR22: Build **`ThemeSelector`** on My Data (FR-31) — segmented control labeled "Appearance" with **System**, **Light**, and **Dark** options; 48dp touch height; default selection System; persists immediately to `user_preferences.theme_mode`; all surfaces respect active/effective theme without restart; when System selected, app follows OS and updates on OS theme change. Light theme: verify contrast per UX §4.1 adapted pairs. Beta checklist: pass criteria for light and dark effective themes on Today + My Data.

### FR Coverage Map

FR1: Epic 2 — DataIngestionSource interface abstraction
FR2: Epic 2 — PhonePedometerSource step ingestion with reset handling
FR3: Epic 2 — AdpBleSource stub (Phase 0 no-op)
FR4: Epic 2 — BackgroundCollector background step persistence
FR5: Epic 4 — Background collection status display on My Data
FR6: Epic 2 — Android 14+ FGS health type compliance
FR7: Epic 2 — timeseries_samples OW-aligned storage
FR8: Epic 2 — Five-minute default Time Buckets
FR9: Epic 1 — user_preferences (daily_step_goal + theme_mode)
FR10: Epic 2 — Versioned schema migrations
FR11: Epic 4 — DataLifecycleService tiered downsampling
FR12: Epic 4 — Weekly database maintenance (VACUUM)
FR13: Epic 4 — Storage footprint display on My Data
FR14: Epic 2 — Today goal ring dashboard
FR15: Epic 2 — Once-per-day goal celebration animation
FR16: Epic 3 — History bar charts (7d/30d)
FR17: Epic 3 — Weekly trend indicator
FR18: Epic 6 — No network dependency + release manifest verification
FR19: Epic 4 — CSV export with OW-aligned columns
FR20: Epic 4 — Full local health-data purge
FR21: Epic 4 — Export-before-purge prompt
FR22: Epic 1 — Trust-first onboarding
FR23: Epic 1 — Goal setup onboarding (+ editable on My Data in Epic 4)
FR24: Epic 1 — Notification opt-in during onboarding
FR25: Epic 2 — Daily goal local notification
FR26: Epic 6 — Apache 2.0 open source
FR27: Epic 6 — Project documentation bundle
FR28: Epic 3 — Dev data inject & lifecycle simulator
FR29: Epic 6 — Beta acceptance checklist
FR30: Epic 4 — CSV import with idempotent reconciliation
FR31: Epic 4 — Theme selection (System / Light / Dark)

## Epic List

### Epic 1: Trust Onboarding & App Shell
The user installs the app, understands the local-first privacy promise, sets a daily step goal and permissions, and lands on a themed three-tab shell — no account required.
**FRs covered:** FR9, FR22, FR23, FR24

### Epic 2: Passive Step Tracking & Today Dashboard
The user's steps accumulate in the background; they see today's progress via the goal ring, celebration, and optional goal notification without constantly opening the app.
**FRs covered:** FR1, FR2, FR3, FR4, FR6, FR7, FR8, FR10, FR14, FR15, FR25

### Epic 3: History & Trends
The user reviews 7-day and 30-day step trends with fast charts and a simple weekly comparison indicator.
**FRs covered:** FR16, FR17, FR28

### Epic 4: Data Sovereignty & Lifecycle (My Data)
The user controls their health data — footprint, CSV export/import, purge, background status, goal editing, theme preference, and optional local display name (no account). Primary product differentiator.
**FRs covered:** FR5, FR9, FR11, FR12, FR13, FR19, FR20, FR21, FR23, FR30, FR31

### Epic 5: Design Polish & Visual Cohesion
After functional epics ship, the app receives a dedicated visual pass — accent/contrast tokens, navigation spacing, and cross-screen cohesion verified on device before beta. Includes early Android build-hygiene (Built-in Kotlin / plugin KGP migration) so Gradle debt does not accumulate while UI polish runs.
**NFRs covered:** NFR5 (WCAG AA aspirational contrast in both themes)

### Epic 6: OSS Credibility & Beta Readiness
The repo is beta-ready and open-source credible — documentation, privacy audit, release hardening, and acceptance checklist.
**FRs covered:** FR18, FR26, FR27, FR29

---

## Epic 1: Trust Onboarding & App Shell

The user installs the app, understands the local-first privacy promise, sets a daily step goal and permissions, and lands on a themed three-tab shell — no account required.

### Story 1.1: Flutter Project Initialization

As a **builder**,
I want the Flutter project scaffold initialized from the repo root with locked dependencies,
So that I have a clean, runnable mobile app foundation aligned with ASTRA architecture.

**Acceptance Criteria:**

**Given** the `astra-app` repo root contains planning docs but no Flutter scaffold yet
**When** `flutter create . --org com.astraapp --project-name astra_app --platforms=android,ios --android-language=kotlin --empty` is run and locked `pubspec.yaml` dependencies are applied
**Then** the app builds and launches on Android/iOS with package name `astra_app` and bundle ID `com.astraapp`
**And** `LICENSE` (Apache 2.0) exists in repo root per FR26

**Given** the project is initialized
**When** a developer runs `flutter analyze`
**Then** no analyzer errors are introduced by the scaffold setup

---

### Story 1.2: Design Tokens and Theme System

As a **user**,
I want the app to respect my OS light/dark setting by default with consistent ASTRA visual tokens,
So that the interface feels polished in either appearance from first launch.

**Acceptance Criteria:**

**Given** Figtree and Darker Grotesque fonts are bundled in `assets/fonts/` (no network fetch)
**When** the app launches for the first time
**Then** `ThemeMode.system` is active and `AstraColors` semantic tokens apply for both light and dark palettes (UX-DR1, UX-DR2, UX-DR3)
**And** `theme_mode` defaults to `system` in memory before preferences DB exists (FR9, FR31 infrastructure)

**Given** the OS switches between light and dark while `theme_mode` is `system`
**When** the app is in foreground
**Then** the UI updates to match the OS theme without restart

**Given** spacing and radius tokens are defined
**When** any scaffold screen renders
**Then** horizontal padding uses the 4px grid minimum 16dp and touch targets meet 48dp where interactive (UX-DR3)

---

### Story 1.3: App Scaffold and Bottom Navigation

As a **user**,
I want a three-tab navigation shell (Today, History, My Data),
So that I can move between the main surfaces of the Hub App intuitively.

**Acceptance Criteria:**

**Given** onboarding is complete (or skipped in dev builds)
**When** the main app loads
**Then** `AppScaffold` displays a bottom `NavigationBar` with Today · History · My Data tabs (UX-DR4)
**And** the active tab uses amber accent; inactive tabs use muted color

**Given** the user taps a tab
**When** navigation occurs
**Then** content cross-fades in ~200ms (UX-DR18) or swaps instantly if reduce-motion is enabled
**And** placeholder screens exist for each tab until feature epics implement them

**Given** the app shell is displayed
**When** inspected on Android gesture navigation devices
**Then** bottom safe area inset is respected (56dp + inset)

---

### Story 1.4: User Preferences Persistence

As a **user**,
I want my daily step goal and theme preference saved locally,
So that my choices persist across app restarts.

**Acceptance Criteria:**

**Given** migration v1 runs on fresh install
**When** the database is created
**Then** only `user_preferences` table exists (key/value) — no `timeseries_samples` yet (database incremental principle)
**And** defaults are `daily_step_goal=8000` and `theme_mode=system` (FR9)

**Given** `UserPreferencesRepository` is wired via `AppDependencies`
**When** a preference is written and the app restarts
**Then** the stored value is read back correctly

**Given** a preference update occurs
**When** saved
**Then** only `UserPreferencesRepository` writes to `user_preferences` — no direct SQL from UI/Cubits

---

### Story 1.5: Trust-First Onboarding Flow

As a **privacy pragmatist (Alex)**,
I want a trust-first onboarding that explains local-only storage before any permission prompt,
So that I feel confident granting activity access without creating an account.

**Acceptance Criteria:**

**Given** first launch with no onboarding completion flag
**When** the app opens
**Then** a full-screen onboarding stack appears (not tabs): Trust → Permissions → Goal (FR22, UX-DR16)
**And** no account, email, or authentication screen exists

**Given** the Trust step is displayed
**When** the user taps Continue
**Then** permission requests have not yet been shown (trust copy before permissions)

**Given** the Permissions step
**When** the user taps "Allow activity access"
**Then** the OS activity recognition dialog is triggered via `permission_handler`
**And** optional notification opt-in is offered separately with skip path (FR24)

**Given** the Goal step with default 8000 pre-filled
**When** the user taps "Start tracking" or skips
**Then** `daily_step_goal` is saved (8000 if skipped) and onboarding completion flag is set (FR23)
**And** the user lands on the Today tab (UX D-10)

**Given** onboarding controls
**When** rendered
**Then** `AstraButton` variants (primary/secondary/ghost) meet 48dp min height (UX-DR17)

---

## Epic 2: Passive Step Tracking & Today Dashboard

The user's steps accumulate passively (Android FGS + WorkManager; iOS foreground backfill); they see today's progress via the goal ring, celebration, and optional goal notification without constantly opening the app. Real-time step display while the app is open is a UX bonus layered on persisted SQLite totals — see Stories 2.8–2.10 for the corrected passive contract.

### Story 2.1: SQLite Schema for Timeseries Samples

As a **builder**,
I want the `timeseries_samples` table created with OW-aligned schema and indexes,
So that step buckets can be persisted correctly for charts and export later.

**Acceptance Criteria:**

**Given** Story 1.4 migration v1 exists
**When** migration v2 runs
**Then** `timeseries_samples` table matches PRD §4.3.1 columns including `zone_offset` (FR7)
**And** indexes `idx_timeseries_query` and UNIQUE `idx_bucket_identity` are created

**Given** the database connection opens in any isolate
**When** initialized
**Then** `PRAGMA journal_mode=WAL` and `PRAGMA foreign_keys=ON` execute explicitly

**Given** step samples will use 5-minute buckets
**When** schema constraints are inspected
**Then** `value >= 0` and integer check for `type=steps` are enforced (FR8)

**Given** fresh install and upgrade from v1
**When** migrations run in test
**Then** both paths succeed without data loss (FR10)

---

### Story 2.2: Data Ingestion Abstraction and Step Normalizer

As a **builder**,
I want a pluggable ingestion pipeline with step normalization,
So that phone (and future ADP) sources can feed buckets without duplicating delta logic.

**Acceptance Criteria:**

**Given** `DataIngestionSource` interface exists
**When** `PhonePedometerSource` and no-op `AdpBleSource` stub are registered in `AppDependencies`
**Then** both implement the interface and stub returns no data (FR1, FR3)

**Given** cumulative pedometer readings including a simulated counter reset
**When** `StepNormalizer` processes the stream
**Then** correct non-negative bucket increments are produced without corrupted totals (FR2)
**And** unit test covers at least one reset/reboot scenario

**Given** normalized bucket output
**When** persisted later by BackgroundCollector
**Then** samples include `type=steps`, `unit=count`, `provider=internal_phone`, `device_id=smartphone`

---

### Story 2.3: Step Repository and Time Semantics

As a **user**,
I want today's step total computed correctly across timezone boundaries,
So that my daily goal reflects my local calendar day even when traveling.

**Acceptance Criteria:**

**Given** `TimeProvider` is injected (no raw `DateTime.now()` in repository/normalizer)
**When** samples are written and read
**Then** timestamps are ISO 8601 UTC with immutable per-row `zone_offset` (NFR9)

**Given** samples with different stored `zone_offset` values
**When** `getTodaySteps()` is called
**Then** `LocalDayCalculator` groups by each row's stored offset — not device current timezone
**And** `local_day` is never computed via SQL `date(start_time, zone_offset)`

**Given** ingestion bucket upsert
**When** `BackgroundCollector` calls `StepRepository.upsertIngestionBucket()`
**Then** upsert uses bucket identity UNIQUE constraint — only ingestion path may call this method

---

### Story 2.4: Background Collector and Android WorkManager

As a **user**,
I want steps to accumulate while the app is closed on Android,
So that I get value without opening the app constantly.

**Acceptance Criteria:**

**Given** a physical Android device (reference platform)
**When** WorkManager callback runs with `@pragma('vm:entry-point')` and `WidgetsFlutterBinding.ensureInitialized()`
**Then** a test bucket is written and readable by UI after resume (WorkManager spike)

**Given** activity permission granted and app backgrounded or removed from recents (not force-stopped from Settings)
**When** user walks ≥500 steps over ≥30 minutes without opening the app on Android beta
**Then** step count increases within 15 minutes (one WorkManager cycle) OR on next app open (FR4 primary)

**Given** user did not open the app since prior evening
**When** first open of the local day after walking
**Then** Today shows today's steps > 0 when phone sensor recorded steps (FR4 secondary — daily goal morning check)

**Given** app was force-stopped from system Settings
**When** user reopens after walking
**Then** foreground backfill eventually reflects steps — documented platform limit, not Story 2.4 failure

**Given** Android 14+ manifest
**When** inspected
**Then** `FOREGROUND_SERVICE_HEALTH` is declared correctly — not `dataSync` misuse (FR6)

**Given** WorkManager isolate and UI isolate
**When** both access SQLite
**Then** each opens its own connection via isolate-safe factory with WAL

**Given** iOS build
**When** background collection runs
**Then** backfill-on-foreground model is implemented — no false promise of Android-parity 5-min cadence (FR4)

---

### Story 2.5: Today Dashboard with Goal Ring

As a **user**,
I want to see today's steps versus my daily goal in a clear ring dashboard,
So that I can check progress at a glance.

**Acceptance Criteria:**

**Given** step samples exist for today
**When** the Today tab is opened
**Then** `GoalRing` shows proportional arc, center count (Darker Grotesque), "steps today" and "goal N" labels (FR14, UX-DR5)
**And** `SourceChip` displays "Phone sensor" (UX-DR7)

**Given** steps exceed the daily goal
**When** the ring renders
**Then** arc caps at 100% and center count shows actual total (overflow via number, not second lap)

**Given** no permission or no samples yet
**When** Today loads
**Then** empty/loading/no-permission states render per UX spec (dashed track, `--`, skeleton)

**Given** stale threshold exceeded (12h Android / 4h iOS)
**When** Today is visible
**Then** compact `StatusBanner` stale line appears linking user to My Data (UX-DR8 compact)

---

### Story 2.6: Goal Celebration Animation

As a **user**,
I want a calm once-per-day celebration when I reach my step goal,
So that I feel acknowledged without gamified pressure.

**Acceptance Criteria:**

**Given** today's steps first cross `daily_step_goal` for the local calendar day
**When** the user views Today (or deferred from background crossing)
**Then** `GoalCelebration` plays once: ring pulse, glow, shimmer per UX §2.3.1 (FR15, UX-DR6)
**And** `celebration_shown_date` preference prevents repeat until next local day

**Given** reduce-motion OS setting enabled
**When** celebration triggers
**Then** static full ring + micro-copy fade only (no scale/glow animation)

**Given** goal already met earlier today
**When** user reopens Today
**Then** no celebration replay and no coach language toast

---

### Story 2.7: Daily Goal Local Notification

As a **user**,
I want at most one local notification when my daily step goal is reached,
So that I can celebrate offline without notification spam.

**Acceptance Criteria:**

**Given** notification permission granted during onboarding
**When** `BackgroundCollector` detects cumulative daily steps ≥ goal from SQLite aggregation
**Then** at most one local notification fires per local calendar day (FR25)
**And** evaluation uses `LocalDayCalculator` daily sum — not a single bucket

**Given** notification permission denied
**When** goal is reached
**Then** no notification is attempted and app functions normally

**Given** goal notification fired
**When** user opens app later
**Then** no duplicate notification on subsequent opens the same day

---

### Story 2.8: Android FGS Health Passive Pipeline

As a **user**,
I want steps to accumulate while the app is closed on Android without keeping it open,
So that my daily goal progresses passively.

**Acceptance Criteria:**

**Given** Android 14+ with activity permission granted
**When** app is backgrounded or removed from recents (not force-stopped)
**Then** a foreground service with type `health` runs `BackgroundCollector` on a periodic cadence while OS permits (FR6, architecture D-04)

**Given** FGS is active
**When** user walks ≥500 steps over ≥30 min without opening the app
**Then** buckets are written to SQLite and Today reflects increase on next open or within one collection cycle (FR4 primary)

**Given** app returns to foreground
**When** FGS and `LiveStepMonitor` would both read the pedometer
**Then** single-writer rule holds — FGS pauses or delegates; `LiveStepMonitor` remains sole stream owner in UI isolate when process alive

**Given** user force-stops from Settings
**When** app reopens
**Then** foreground backfill recovers steps — documented limit, not Story failure

**Given** release manifest
**When** inspected
**Then** `FOREGROUND_SERVICE_HEALTH` declared; persistent notification copy is honest (not disguised as unrelated sync)

---

### Story 2.9: Today Display Truth Model & Live Overlay

As a **user**,
I want Today to show my real progress without confusing backward jumps,
So that I trust the ring whether the app was open or closed.

**Acceptance Criteria:**

**Given** documented display contract
**When** reviewed in architecture / story notes
**Then** persisted SQLite daily sum = **source of truth**; `LiveStepMonitor` = **real-time overlay bonus** when process alive; UI never shows a lower step count within the same local day except at day rollover

**Given** cold start with permission granted
**When** Today loads
**Then** sequence is: foreground backfill → reconcile from DB → attach live monitor → sync live total (no stale DB-only refresh overwriting live)

**Given** app resume (process alive)
**When** user returns from background
**Then** live stream recovers and steps update within 5s without force-stop (field test B)

**Given** uncommitted lifecycle hardening work
**When** Story 2.9 is implemented
**Then** keep: monotonic merge, `syncSteps`, cold-start ordering, `_persistOnPause` best-effort
**And** revert: threshold persist (`onPersistRequested` / +5 steps debounce) — caused regression 1273→1254

**Given** unit and widget tests
**When** `flutter test` runs
**Then** monotonic display, cold-start order, and resume sync are covered

---

### Story 2.10: WorkManager Orchestration & OEM Deferral Hardening

As a **builder**,
I want WorkManager and background health checks to be reliable on reference Android devices,
So that passive collection survives OEM battery policies.

**Acceptance Criteria:**

**Given** `BackgroundHealthCapabilityEvaluator` (new, per architecture D-23)
**When** instantiated from `AppDependencies`
**Then** it reports: activity permission, notification permission, battery optimization exemption status, FGS declaration presence — no scattered permission logic in screens

**Given** WorkManager periodic task registered
**When** FGS is unavailable (permission revoked, OS killed service)
**Then** WM still runs reconciliation as fallback orchestrator (architecture: WM ≠ realtime guarantee)

**Given** Samsung/Xiaomi/Huawei-style battery deferral detected
**When** evaluator runs
**Then** capability flag is exposed for future My Data UI (Epic 4.2) — **no user-facing copy in this story**

**Given** physical Android device
**When** WM callback executes with `@pragma('vm:entry-point')`
**Then** isolate-safe DB write succeeds; foreground backfill remains mandatory fallback if isolate init fails

---

## Epic 3: History & Trends

The user reviews 7-day and 30-day step trends with fast charts and a simple weekly comparison indicator.

### Story 3.1: Dev Data Inject and Lifecycle Simulator

As a **builder**,
I want to inject 90 days of synthetic step data and simulate lifecycle aging,
So that I can benchmark charts and validate storage behavior without walking for months.

**Acceptance Criteria:**

**Given** `lib/dev/` tools gated by `kDebugMode`
**When** inject command runs
**Then** 90 days of valid `timeseries_samples` rows are written inside a transaction (FR28)
**And** canonical sample shape and UUID ids are respected

**Given** injected data spans multiple resolution tiers after lifecycle simulation
**When** downsampling simulator runs
**Then** row counts drop predictably per FR11 tiers (dev-only preview of Epic 4 service)

**Given** inject + simulate completes
**When** documented in dev README or script comment
**Then** steps are reproducible for CI/manual benchmark (FR28)

---

### Story 3.2: History Chart Data Aggregation

As a **user**,
I want history queries to return pre-aggregated daily totals,
So that charts load instantly even with months of data.

**Acceptance Criteria:**

**Given** 90 days of injected step samples
**When** `StepRepository.getChartDailyAggregates(days: 7)` and `(days: 30)` are called
**Then** `List<ChartDayAggregate>` returns at most ~7 or ~31 items (NFR1, architecture D-21)
**And** UI/widgets perform zero business aggregation

**Given** samples with mixed `zone_offset` (travel scenario test)
**When** daily totals are computed
**Then** grouping uses each row's stored offset via `LocalDayCalculator`

**Given** repository read methods
**When** called from `HistoryCubit`
**Then** no direct SQL from presentation layer

---

### Story 3.3: History Screen with Bar Chart and Trend

As a **user**,
I want to toggle 7-day and 30-day bar charts with a weekly trend indicator,
So that I can understand my movement patterns over time.

**Acceptance Criteria:**

**Given** the History tab is selected
**When** data exists
**Then** `PeriodToggle` switches 7d/30d views and `StepBarChart` renders accent-muted bars with dashed goal line (FR16, UX-DR9)
**And** chart rebind on toggle has no loading animation (KPI-01 UX)

**Given** sufficient history exists
**When** the screen loads
**Then** `TrendChip` shows informational weekly comparison vs prior week — no coach copy (FR17, UX-DR10)

**Given** no history yet
**When** History opens
**Then** empty state copy displays: "No history yet. Walk a bit — data stays on this device."

**Given** chart semantics
**When** inspected with screen reader
**Then** baseline Semantics labels apply per UX §4.3 (UX-DR19 partial)

---

### Story 3.4: Chart Performance Benchmark (KPI-01)

As a **builder**,
I want a reproducible benchmark proving chart render <100ms on 90-day data,
So that History meets NFR1 before beta.

**Acceptance Criteria:**

**Given** 90 days of injected data loaded
**When** benchmark harness toggles 7d↔30d on mid-range Android reference device
**Then** query + render p95 completes in <100ms (FR16, FR28, NFR1, SM-1)

**Given** benchmark script in `lib/dev/`
**When** run manually or documented for CI
**Then** output logs p50/p95 timings for regression tracking

**Given** KPI-01 pass
**When** recorded
**Then** result is traceable in beta checklist prep (FR29 precursor)

---

## Epic 4: Data Sovereignty & Lifecycle (My Data)

The user controls their health data — footprint, CSV export/import, purge, background status, goal editing, theme preference, and optional local display name (no account). Primary product differentiator.

### Story 4.1: Data Lifecycle Service (Downsampling and Maintenance)

As a **user**,
I want old step data compressed automatically,
So that storage stays bounded without manual cleanup.

**Acceptance Criteria:**

**Given** samples older than 30/365 day thresholds
**When** `DataLifecycleService` runs inside repository-owned transactions
**Then** downsampling applies FR11 tiers destructively and updates `resolution` field (FR11)
**And** finer rows are deleted after compaction — irreversible

**Given** maintenance is due
**When** Android weekly job or iOS foreground/resume opportunistic run executes
**Then** `PRAGMA optimize` and `VACUUM` run off UI thread (FR12)
**And** Phase 0 does not require reliable iOS background VACUUM for acceptance

**Given** 90-day inject test with repeated lifecycle cycles
**When** complete
**Then** DB file size does not grow unbounded (FR12, NFR7)

---

### Story 4.2: My Data Footprint and Background Status

As a **user**,
I want to see storage footprint and honest background collection status,
So that I can trust the app is working and understand storage use.

**Acceptance Criteria:**

**Given** samples exist in SQLite
**When** My Data footprint section loads
**Then** sample count, approximate DB size, and "last optimized" relative time display (FR13, UX-DR11)
**And** values update after lifecycle, import, export, purge operations

**Given** background collection state
**When** My Data renders
**Then** `BackgroundStatusCard` shows healthy/stale/ios_backfill/permission_denied variants (FR5, UX-DR12)
**And** full stale banner appears here; Today shows compact stale line (UX-DR8)

**Given** stale thresholds
**When** last sample exceeds 12h (Android) or 4h (iOS)
**Then** stale copy explains platform constraints without blaming user

---

### Story 4.3: CSV Export

As a **user**,
I want to export my step history to CSV,
So that I own a portable copy of my data.

**Acceptance Criteria:**

**Given** samples in `timeseries_samples`
**When** user taps Export CSV on My Data
**Then** OW-aligned CSV including `id` column is written to cache/temp file first (FR19, UX-DR14)
**And** `share_plus` opens OS share sheet on the local file path

**Given** export completes
**When** on device without network
**Then** export succeeds (SM-3 / NFR3)

**Given** export button state
**When** in progress
**Then** spinner shows and duplicate tap is disabled; success snackbar shows for 3s

---

### Story 4.4: CSV Import

As a **user**,
I want to import a previously exported ASTRA CSV,
So that I can restore data after reinstall or device change.

**Acceptance Criteria:**

**Given** a valid ASTRA export CSV
**When** user selects file via picker
**Then** rows import inside a single transaction with `INSERT OR IGNORE` on UUID `id` (FR30, D-16)
**And** duplicate bucket identity increments skip count — not silent corruption

**Given** malformed headers or rows
**When** import validates
**Then** entire transaction aborts with user-visible `StatusBanner` error (FR30)

**Given** existing data in DB
**When** import starts
**Then** `ConfirmDialog` asks to replace with row count preview (UX-DR15)

**Given** successful import
**When** complete
**Then** Today and History cubits refresh and footprint updates

---

### Story 4.5: Full Data Purge with Export Nudge

As a **user**,
I want to delete all local health data with a safety prompt,
So that I can wipe my history while keeping my preferences.

**Acceptance Criteria:**

**Given** user taps "Delete all local data"
**When** `ConfirmDialog` appears
**Then** copy mentions export option with Export first / Delete anyway / Cancel (FR21, UX-DR15)
**And** Export first triggers export flow without closing dialog

**Given** user confirms delete
**When** purge executes in transaction
**Then** all `timeseries_samples` and derived collection state are removed (FR20)
**And** `daily_step_goal`, `theme_mode`, `display_name` (if set), onboarding flag, permission choices persist (D-11)

**Given** purge completes
**When** user views Today/History/My Data
**Then** empty states show 0 samples / ~0 KB; goal row unchanged; Today greeting unchanged if display name was set; no re-onboarding

---

### Story 4.6: Daily Goal Editor on My Data

As a **user**,
I want to change my daily step goal from My Data,
So that I can adjust my target without repeating onboarding.

**Acceptance Criteria:**

**Given** My Data goal row
**When** user taps it
**Then** `GoalEditorSheet` opens with numeric field and 1,000–100,000 validation (FR23, UX-DR13)

**Given** invalid input
**When** displayed
**Then** Save is disabled with inline helper/error text

**Given** valid save
**When** sheet closes
**Then** Today ring recalculates percentage against new goal immediately

---

### Story 4.7: Theme Selector and My Data Integration

As a **user**,
I want to choose System, Light, or Dark appearance from My Data,
So that the app looks the way I prefer regardless of OS settings.

**Acceptance Criteria:**

**Given** My Data Appearance section
**When** user selects System, Light, or Dark via `ThemeSelector` segmented control (UX-DR22)
**Then** `theme_mode` persists and applies immediately app-wide (FR31)
**And** cold start restores preference without theme flash

**Given** `theme_mode` is `system`
**When** OS theme changes
**Then** app UI updates without restart

**Given** complete My Data screen
**When** scrolled
**Then** section order is: Background → Footprint → Goal → Appearance → Data actions (UX-DR11)
**And** copy/tone follows UX §4.6 guardrails (UX-DR20)

**Given** theme selector is functional
**When** Epic 5 design polish runs
**Then** contrast and visual cohesion are verified per UX §4.1 and V-1–V-13 (NFR5, UX-DR21) — not blocking Story 4.7 delivery

---

### Story 4.8: Local Display Name and Today Greeting

As a **user**,
I want to optionally tell the app my first name and see a calm greeting on Today,
So that the app feels personal without creating an account or sending data anywhere.

**Acceptance Criteria:**

**Given** first launch onboarding
**When** user completes trust, permissions, and goal steps
**Then** an optional display-name step asks what to call them (English copy only in Phase 0)
**And** user can skip without blocking completion
**And** trimmed non-empty input persists to `user_preferences.display_name` via `UserPreferencesRepository`

**Given** no display name stored
**When** Today loads
**Then** no greeting line is shown (ring layout unchanged)

**Given** a display name is stored
**When** Today loads
**Then** a single caption line above the goal ring shows **"Hello, {name}"** (Figtree `type.caption`, `text.secondary`)
**And** step count is **not** duplicated under the greeting (ring remains sole step total)

**Given** My Data is available (this story may ship before full My Data sections)
**When** user edits display name from My Data
**Then** value persists immediately and Today greeting updates on next refresh without restart

**Given** full health-data purge (Story 4.5)
**When** purge completes
**Then** `display_name` is retained like `daily_step_goal` and `theme_mode`

**Given** copy and tone
**When** greeting is shown
**Then** voice stays calm and factual per UX §4.6 — no coach language, exclamation marks, or streak messaging

**Out of scope for 4.8:** i18n / `flutter_localizations` (deferred); personalized celebration or notifications; step count subtitle under greeting; profile initials avatar → Story 4.9.

---

### Story 4.9: Profile Initials on My Data (Settings Entry)

As a **user**,
I want a simple profile affordance on My Data using my initials,
So that I have a recognizable entry point for preferences even without an account.

**Acceptance Criteria:**

**Given** a display name is stored
**When** My Data profile header renders
**Then** a circular initials badge shows one or two letters derived from the trimmed name (uppercase)
**And** tap opens or scrolls to profile/preferences rows (display name, goal, appearance) per integrated My Data layout

**Given** no display name
**When** My Data profile header renders
**Then** a neutral placeholder glyph is shown (no fake initials)
**And** tap still reaches display-name edit affordance

**Given** display name changes
**When** save completes
**Then** initials update immediately without app restart

**Out of scope for 4.9:** photo upload, account linking, cloud avatar, i18n.

---

## Epic 5: Design Polish & Visual Cohesion

After Epics 1–4 deliver functional surfaces, a dedicated pass revisits tokens, spacing, on-device visual quality, and Android build plugin hygiene before OSS beta hardening.

**Execution order (user-confirmed 2026-06-02):** Story **5.5** (Built-in Kotlin / KGP — build hygiene) **first**, then **5.1–5.4** (visual polish). Do not accumulate Gradle debt before the UI pass.

### Story 5.5: Built-in Kotlin Plugin Migration (KGP)

As a **builder**,
I want Phase 0 Android plugins migrated off legacy Kotlin Gradle Plugin (KGP) application,
So that `flutter build` stays compatible with Flutter Built-in Kotlin and we do not accumulate Gradle debt from the start of the project.

**Acceptance Criteria:**

**Given** `flutter run` or `flutter build apk` on Android with current locked deps
**When** the build completes after this story
**Then** Flutter emits **no** warning that `pedometer`, `share_plus`, or `workmanager_android` apply KGP (field observation 2026-06-02)
**And** any other Phase 0 plugin added in Epics 2–4 is included in the audit

**Given** plugin changelogs and [Flutter Built-in Kotlin migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)
**When** compatible versions exist on pub.dev
**Then** `pubspec.yaml` / lockfile are upgraded to those versions
**And** `docs/DEPENDENCIES.md` records version bumps and rationale

**Given** no compatible plugin release exists
**When** migration is blocked for a dependency
**Then** an upstream issue is filed (or existing issue linked) per Flutter guidance
**And** the story documents the blocker and temporary workaround in `docs/DEPENDENCIES.md` — no silent deferral

**Given** `android/gradle.properties` currently sets `android.builtInKotlin=false` (Story 1.1 scaffold workaround)
**When** all audited plugins support Built-in Kotlin
**Then** that flag is removed (or narrowed to a documented exception only)
**And** `android.newDsl=false` is re-evaluated against Flutter 3.44+ defaults

**Given** migration complete
**When** `flutter build apk --debug` and `flutter build apk --release` run on CI or local
**Then** both succeed without KGP incompatibility warnings
**And** existing Android tests (`test/android/`, manifest tests) still pass

**Implementation note:** Story 6.2 retains release-manifest and privacy audit scope; KGP resolution is **pulled forward** to Epic 5 per user decision (2026-06-02) — do not defer to beta hardening.

---

### Story 5.1: Accent Color & Contrast Token Revision

As a **user**,
I want accent colors readable in both light and dark themes,
So that the interface stays calm and legible on my phone in any appearance mode.

**Acceptance Criteria:**

**Given** device testing on light theme (user feedback 2026-06-02)
**When** accent `#EAD55E` is used on light elevated surfaces (ring stroke, active tab, CTA fill)
**Then** revised tokens improve visibility without breaking dark-mode-first calm tone (UX §1.2, D-1)
**And** changes are centralized in `AstraColors` / `astra_theme.dart` — no ad-hoc hex in widgets (V-2)

**Given** primary buttons on amber fill
**When** rendered in light and dark themes
**Then** label uses `color.text.inverse` with contrast meeting UX §4.1 baseline (D-13, NFR5)

**Given** goal ring, chart bars, and status colors
**When** viewed on light `bg.base` and dark `bg.base`
**Then** accent-muted tracks and data semantics remain distinguishable (UX-DR21)

**Given** token changes
**When** `flutter analyze` and existing widget tests run
**Then** no regressions; update UX spec token table if hex values change

---

### Story 5.2: Navigation Bar & Spacing Polish

As a **user**,
I want comfortable spacing in the bottom navigation and consistent screen padding,
So that labels and icons are not cramped against screen edges.

**Acceptance Criteria:**

**Given** `AppScaffold` bottom `NavigationBar` (user feedback 2026-06-02)
**When** viewed on a physical device
**Then** icon and label vertical padding meet minimum touch comfort — not flush to bar top/bottom (UX-DR3, V-4)

**Given** all three tabs (Today, History, My Data)
**When** compared side by side
**Then** bar height, indicator, and inactive/active states are visually consistent (V-4)

**Given** screen body layouts from Epics 1–4
**When** spacing audit runs against `astra_spacing.dart` 4px grid
**Then** horizontal padding ≥16dp; interactive targets ≥48dp where applicable (UX-DR3)

**Given** reduce-motion enabled
**When** navigation transitions run
**Then** existing instant-swap behavior preserved (UX-DR18)

---

### Story 5.3: Cross-Screen Visual Cohesion Audit

As a **builder**,
I want every surface verified against the UX visual checklist on device,
So that the app feels cohesive before OSS beta release.

**Acceptance Criteria:**

**Given** UX spec §4.7 checklist V-1–V-13
**When** executed on release or profile build on physical device
**Then** each item passes or has documented exception with fix plan (UX-DR21)

**Given** Today, History, My Data, and onboarding
**When** reviewed in system, light, and dark effective themes
**Then** typography uses bundled Figtree + Darker Grotesque only (V-3); no layout jumps on Today sync (V-5)

**Given** screenshot / README GIF readiness (SM-7 prep)
**When** Today and My Data are framed
**Then** hero layouts are presentation-ready (V-13)

**Given** findings from Epics 1–4 device testing
**When** logged in story completion notes
**Then** residual polish items are either fixed in this story or explicitly deferred with rationale

---

### Story 5.4: Goal Overflow Animation Polish

As a **user**,
I want a calm, satisfying visual when my steps exceed the daily goal,
So that continued walking feels acknowledged without gamified pressure.

**Acceptance Criteria:**

**Given** today's steps exceed `daily_step_goal` (`TodayStatus.overflow`)
**When** the user views Today after the once-per-day celebration (Story 2.6) has already played or been dismissed
**Then** the goal ring shows a distinct beyond-goal treatment — e.g. subtle continued pulse or shimmer on the full ring, not a static capped arc (field feedback 2026-06-02)
**And** the center count continues updating live with each step

**Given** reduce-motion OS setting enabled
**When** steps are in overflow
**Then** animation uses a static full ring with optional calm micro-copy only — no scale/glow loops

**Given** Story 2.6 celebration triggers at first goal crossing
**When** steps continue increasing into overflow
**Then** celebration does not replay; overflow animation is separate and non-modal

**Given** token and motion patterns are defined
**When** implemented
**Then** changes live in `GoalRing` / dedicated overflow widget and `AstraColors` — no ad-hoc hex in screens (V-2)

---

## Epic 6: OSS Credibility & Beta Readiness

The repo is beta-ready and open-source credible — documentation, privacy audit, release hardening, and acceptance checklist.

### Story 6.1: Open Source License and Documentation Bundle

As a **contributor**,
I want clear OSS licensing and technical documentation,
So that I can understand, audit, and extend the project confidently.

**Acceptance Criteria:**

**Given** the public repo
**When** inspected
**Then** `LICENSE` is Apache 2.0 and README states license and project pitch (FR26)

**Given** `docs/` folder
**When** reviewed
**Then** `OPEN_WEARABLES_ALIGNMENT.md`, `SERIES_TYPES.md`, `DEPENDENCIES.md`, and `REGULATORY_POSITION.md` exist (FR27)
**And** OW doc lists Phase 0 `steps/count` mapping; regulatory doc states General Wellness boundary

**Given** README
**When** read by a new visitor
**Then** airplane mode proof protocol and local-first positioning are explained (SM-3/SM-7 prep)

---

### Story 6.2: Release Manifest Hardening and Privacy Audit

As a **privacy pragmatist**,
I want the release build provably free of network access in the health pipeline,
So that I can verify "proof over promises" on a sideload APK.

**Acceptance Criteria:**

**Given** release `AndroidManifest.xml`
**When** parsed by `test/release_manifest_test.dart`
**Then** no `INTERNET` permission is declared (FR18)

**Given** debug vs release variants
**When** compared
**Then** debug may declare INTERNET for Flutter tooling only; release must not (A-14)

**Given** `docs/DEPENDENCIES.md`
**When** audited
**Then** all pub packages are listed with confirmation of zero network use in health pipeline on release builds
**And** `flutter_local_notifications` confirmed local-only (no FCM/Firebase)

**Given** 24-hour airplane mode on release build
**When** beta protocol runs
**Then** Today, History, and export work offline (FR18, SM-3)

**Given** Flutter 3.44+ Android Gradle Plugin 9.x with legacy Kotlin Gradle Plugin (KGP) compatibility flags
**When** release APK is built after plugin ecosystem migration
**Then** `android/gradle.properties` no longer requires `android.builtInKotlin=false` solely to support unmigrated plugins
**And** `flutter build apk --release` succeeds without KGP incompatibility warnings for Phase 0 plugins (verified in **Story 5.5** — not re-done here)
**And** migration guide reference remains valid: [Flutter Built-in Kotlin for app developers](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)

**Implementation note (Story 1.1 discovery, 2026-05-25):** Phase 0 scaffold builds with `android.builtInKotlin=false` and `android.newDsl=false` (Flutter 3.44 defaults). First `flutter build apk --debug` after locked deps surfaced KGP warnings for `pedometer`, `share_plus`, `workmanager_android`. **Resolved in Story 5.5** (Epic 5, user-confirmed 2026-06-02); this story verifies release build still clean at beta gate.

---

### Story 6.3: Beta Acceptance Checklist

As a **builder**,
I want a comprehensive beta checklist tracing to FRs and visual polish items,
So that Phase 0 exit criteria are objectively verifiable before sharing the OSS beta.

**Acceptance Criteria:**

**Given** `docs/BETA_CHECKLIST.md`
**When** reviewed
**Then** items cover background persistence, notifications, footprint, export, import, purge, airplane mode, counter-reset unit test, CSV round-trip, and reference Epic 5 visual cohesion sign-off (FR29, UX-DR21)

**Given** each checklist item
**When** traced
**Then** at least one FR or UX-DR reference is cited

**Given** checklist execution on release APK
**When** run by Baptiste or ≥1 external beta tester
**Then** 100% pass is required for Phase 0 exit (SM-7)
**And** README demo GIF capture is documented as checklist item

**Given** install size check
**When** release APK built
**Then** artifact size is <50MB (NFR2, SM-6)

