---
stepsCompleted: [1, 2, 3, 4, 5]
status: complete
completedAt: 2026-07-25
scope: Epics 1–33 (Phase 0 · Refacto · Post-audit · Data audit)
app_version: 0.15.2+40
project_name: astra-app
inputDocuments:
  - prds/prd-astra-app-2026-05-22/prd.md
  - architecture.md
  - ux-design-specification.md
  - refactoring-audit-master-v0.6.1.md
  - audits/README.md
  - audits/post-refacto/
  - audits/data-pipeline/
mergedFrom:
  - epics.md
  - epics-refacto.md
  - epics-post-audit.md
  - epics-audits-2.md
reprise:
  stepsCompleted: [1, 2, 3, 4]
  startedAt: 2026-08-31
  completedAt: 2026-08-31
  status: complete
  scope: Epics 34–35 (Phase 0 reprise)
  inputDocuments:
    - sprint-change-proposal-2026-08-31.md
    - prds/prd-astra-app-2026-05-22/prd.md
    - architecture.md
    - ux-design-specification.md
    - audits/phase0-reprise/audit-master-v0.15.2.md
---

# astra-app — Epic Breakdown (Epics 1–35)

## Overview

This document provides the complete epic and story breakdown for astra-app, decomposing the requirements from the PRD, UX Design, and Architecture into implementable stories.

**Scope:** Epics 1–33 delivered (Phase 0 through data-pipeline audit). Phase 1+ (SQLCipher, BLE/ADP, Health Connect, wearable, sync hub) remains out of scope here — see PRD and architecture.

**Scope amendment (user-confirmed, 2026-05-25):** System / light / dark theme with user choice on My Data. **System is first-launch default** (follows OS). PRD FR-31 and UX spec §1.1–1.2 aligned.

**Scope amendment (user-confirmed, 2026-06-02):** **Epic 5** is now the **design polish pass** (colors, spacing, visual cohesion). Former Epic 5 (OSS Credibility & Beta Readiness) moves to **Epic 7**. Functional theme selector remains Epic 4 Story 4.7; contrast/visual verification moves to Epic 5.

**Scope amendment (user-confirmed, 2026-06-04 — Sprint Change Proposal approved):** Four-tab shell (Today · Trends · Data · Profil), Figma layouts, six accent presets with bi-tone selector on Profil → Appearance, Phosphor icons. **Execution order locked** — see Epic 5. Today greeting removed. Data tab short label; screen title **My Data**. Profil section **Informations**. Today stats row (kcal / km / time) visible but empty until **Epic 6**. Source: `planning-artifacts/sprint-change-proposal-2026-06-04.md`.

**Scope amendment (user-confirmed, 2026-06-04 — Epic 6 metrics):** Profil stores `height_cm` + `weight_kg` only (no age, no sex/gender). Derived metrics: distance from stride (height × 0.414 or 0.76 m default); walking time from active buckets; kcal = MET 3.5 × weight (70 kg default) × duration. See FR-33.

**Scope amendment (user-confirmed, 2026-06-15 — Epic merge):** Former **Epic 13** merged into **Epic 10** (App Shell, Navigation & Settings Surfaces). One **moyen** version bump at Epic 10 close. Tranche is now **Epics 8–12** (5 epics, 18 stories).

**Scope amendment (user-confirmed, 2026-06-17 — Sprint Change Proposal approved):** **Epic 13** reintroduced for **Onboarding Redesign** (intro → weight → height; activity permission on intro Continue). Supersedes Story 1.5 UX. Version bump **moyen** at Epic 13 close (`0.6.0+11`). Source: `planning-artifacts/sprint-change-proposal-2026-06-17.md`.

**Scope amendment (2026-08-31 — Sprint Change Proposal approved):** Epic 34 = Phase 0 reprise hardening after post-pause audit. Source of truth for in/out = `sprint-change-proposal-2026-08-31.md` (not the raw audit matrix). Epic 35 = optional MyDataCubit split after 34. Phase 1 product (SQLCipher, BLE, Health Connect) still out of scope. Epics 1–33 stay `done`.

## Document map (Epics 1–33)

| Phase | Epics | Status | Primary source |
|-------|-------|--------|----------------|
| **Phase 0** | 1–13 | complete | PRD, UX, architecture |
| **Refacto** | 14–20 | complete | `refactoring-audit-master-v0.6.1.md` |
| **Post-audit** | 21–28 | complete | `audits/post-refacto/` diagnostics |
| **Data audit** | 29–33 | complete | `audits/data-pipeline/` diagnostics |
| **Phase 0 reprise** | 34–35 | AC written | `sprint-change-proposal-2026-08-31.md` |

**Tracker:** [`sprint-status.yaml`](../implementation-artifacts/sprint-status.yaml) · **Lookup:** [`EPIC-INDEX.md`](./EPIC-INDEX.md)

---

## Development Workflow (all stories)

Every sub-task follows **review before commit**. See [`docs/project-context.md`](../../docs/project-context.md).

| Step | Who | Action |
|------|-----|--------|
| 1 | Agent | Complete one sub-task |
| 2 | Agent | Post review brief (what / why / how to verify / learn) + suggested commit message |
| 3 | Baptiste | Read diff, learn, reply **OK commit** (or request changes) |
| 4 | Agent | Commit only after explicit approval — **one commit per sub-task** |

This gate is mandatory for Phase 0 unless Baptiste explicitly waives it for a given step.

## Versioning (all stories — Epics 8–12)

Every completed **work phase** (epic close, or standalone story) must bump the app version in `pubspec.yaml` and `README.md` before the phase is marked done.

**Pre-1.0:** Remain on **`0.x.y`** — do not ship **`1.0.0`** until public launch.

| Phase type | Semver | `+build` | Use when |
|------------|--------|----------|----------|
| **Fix / mineur** | `patch+1` | always `+1` | Bug fix, hotfix, no new user-facing capability (Epics **8**, **9**) |
| **Moyen** | `minor+1`, `patch=0` | always `+1` | New feature, UX tranche, new screens or nav (Epics **10**, **11**, **12**) |

**Epics 8–12:** bump at **each epic close**. Projected path from current `0.2.0+2`: Epic 8 → `0.2.1+3` · Epic 9 → `0.2.2+4` · Epic 10 (nav + menu + Profile/Settings/Data/Units/About) → `0.3.0+5` · Epic 11 → `0.4.0+6` · Epic 12 → `0.5.0+7`.

**Epic 10 note:** Nav-only stories (10.1–10.3) do not get a separate patch bump — they ship inside Epic 10; **one moyen bump** when the full epic closes (shell + secondary surfaces + units).

Source: `planning-artifacts/sprint-change-proposal-2026-06-15.md` · `docs/project-context.md` § Versioning.

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
FR18: Epic 7 — No network dependency + release manifest verification
FR19: Epic 4 — CSV export with OW-aligned columns
FR20: Epic 4 — Full local health-data purge
FR21: Epic 4 — Export-before-purge prompt
FR22: Epic 1 — Trust-first onboarding
FR23: Epic 1 — Goal setup onboarding (+ editable on My Data in Epic 4)
FR24: Epic 1 — Notification opt-in during onboarding
FR25: Epic 2 — Daily goal local notification
FR26: Epic 7 — Apache 2.0 open source
FR27: Epic 7 — Project documentation bundle
FR28: Epic 3 — Dev data inject & lifecycle simulator
FR29: Epic 7 — Beta acceptance checklist
FR30: Epic 4 — CSV import with idempotent reconciliation
FR31: Epic 4 — Theme selection (System / Light / Dark)

## Requirements Inventory — Phase 0 reprise (Epic 34+)

Source of truth: `sprint-change-proposal-2026-08-31.md`. No new PRD FRs. Epics 1–33 remain delivered. Audit `audits/phase0-reprise/audit-master-v0.15.2.md` is a constraint list, not a backlog.

### Functional Requirements

FR-R1: Types owned by presentation but consumed by `core/` (`PermissionRequestStatus`, `TrendsInsightAvailability`, and insight types `core/metrics` actually needs) live outside cubit/state files. No `lib/domain/` folder. iOS sensor vs activity permission mapping stays unchanged (`Platform.isIOS`).

FR-R2: Lifecycle code in `core/` does not import presentation cubits. Resume/refresh orchestration uses ports or callbacks on the existing `AppCubitCoordinator`. Do not create a second coordinator.

FR-R3: History refresh failure is visible on Trends. `HistoryStatus` includes `error`. If a usable cache remains, keep showing it. User can retry. Align with existing `StatusBanner` patterns on Today and My Data.

FR-R4: Trends batch-reads active buckets for a set of local days (`getActiveBucketsForLocalDays` or equivalent). Local-day truth matches the per-day path: `LocalDayCalculator` + stored `zone_offset`. No semantic change to kcal or derived metrics. Contract + tests in `step_repository_*`.

FR-R5: `getTodaySteps` hot path may use SQL/aggregation only if the Dart per-row local-day filter is preserved or proven equivalent. Existing `test/data/repositories/step_repository_today_test.dart` is the gate.

FR-R6: Split `MyDataCubit` along existing test seams (export / import / purge / footprint). Cubit becomes an orchestrator; feature tests stay dedicated.

FR-R7: Selective rebuilds on My Data via `BlocSelector` (and Profile if it still root-`watch`s). Runs after FR-R6, not in parallel.

Preserved (must not regress; not reopened): FR5 stale banners on Today/My Data, FR14 local-day daily totals, FR16 History charts, single ingestion writer (`BackgroundCollector`).

### NonFunctional Requirements

NFR1: Chart render latency — History/Trends query + render <100ms (KPI-01). Epic 34 batch reads must not regress this.

NFR9: Time semantics — UTC storage; immutable `zone_offset` at ingestion; daily totals and charts use `LocalDayCalculator` on stored offset per row — never device current timezone, never SQL `date(start_time, zone_offset)`.

NFR-R1: Stories 34.1–34.2 are compile-time import-graph changes only. No schema change. No ingestion writer change.

NFR-R2: Stories 34.4–34.5 are query-shape only. No change to NFR-9 day boundaries, double-count rules, or finest-resolution totals.

NFR-R3: Default verify `flutter test --tags critical`. SQL stories must also run `test/data/repositories/step_repository_today_test.dart` and History/chart cubit tests.

### Additional Requirements

- **D-22:** Pragmatic 3-layer (`core` / `data` / `presentation`) — no `lib/domain/`. Shared types and ports used by core live in `core/` (or `data/`). Presentation cubits must not be imported from `core/`.
- Refresh orchestration stays on existing `AppCubitCoordinator`.
- `BackgroundCollector` remains the only ingestion write caller; 34.x is reads, import graph, and UI.
- iOS: no new background collection stack.
- Version bump at epic close: **mineur** (`patch+1` + `build+1`). Projected Epic 34 close: `0.15.3+41`.
- First ready story is types (FR-R1), not SQL.

### UX Design Requirements

UX-DR1: Trends refresh failed with no usable cache — `StatusBanner` error variant + retry. No new screen or journey.

UX-DR2: Trends refresh failed with cache remaining — `StatusBanner` stale/info + retry; chart stays on screen.

UX-DR3: Reuse existing `StatusBanner` variants (Today compact / My Data full). Add EN/FR l10n keys. Collection stale >12h on Trends remains `—` (no new collection-stale banner on Trends).

### Out of scope (explicit)

- New `permanentlyDenied` funnel / `PermissionOutcome` enum (shipped Epic 31)
- `_initializePlatform` swallow (shipped 31-3)
- New `AppCubitCoordinator` (already exists)
- `lib/domain/` (violates D-22)
- Phase 1 product: SQLCipher, BLE, Health Connect
- Split `goal_ring` / `today_screen`
- Empty-folder test gaps (`test/data/models/`, `test/l10n/`)
- RepaintBoundary / SQL index / profiler-first items
- Reopen post-refacto-02 boot latency, WM TTL vs VACUUM (E21/E27/E30)
- About `Semantics` + Trends skeletons as a story

### FR Coverage Map

FR-R1: Epic 34 — Relocate presentation-owned types used by core/ (no lib/domain/)
FR-R2: Epic 34 — Lifecycle refresh without cubit imports (existing AppCubitCoordinator)
FR-R3: Epic 34 — History refresh failure visible on Trends
FR-R4: Epic 34 — Batch active-bucket reads for Trends (NFR-9 preserved)
FR-R5: Epic 34 — getTodaySteps hot path without changing local-day truth
FR-R6: Epic 35 — Split MyDataCubit along existing test seams
FR-R7: Epic 35 — BlocSelector on My Data (and Profile if still root-watch)

UX-DR1: Epic 34 — Trends StatusBanner error + retry (no usable cache)
UX-DR2: Epic 34 — Trends StatusBanner stale/info + retry (cache remains)
UX-DR3: Epic 34 — Reuse StatusBanner variants; EN/FR l10n

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
After functional epics ship, the app receives a dedicated visual pass — four-tab Figma shell, accent preset tokens, screen layouts, and on-device cohesion before beta. Includes early Android build-hygiene (Built-in Kotlin / plugin KGP migration).
**NFRs covered:** NFR5 (WCAG AA aspirational contrast in both themes)

### Epic 6: Derived Activity Metrics
Populate Today’s kcal / distance / walking-time row from steps and profile biometrics (formulas TBD). **Runs after Epic 5** cohesion pass.
**FRs covered:** FR-33 (see Sprint Change Proposal 2026-06-04)

### Epic 7: OSS Credibility & Beta Readiness
The repo is beta-ready and open-source credible — documentation, privacy audit, release hardening, and acceptance checklist.
**FRs covered:** FR18, FR26, FR27, FR29

### Epic 34: Honest Trends & layering integrity
The user sees a Trends refresh failure (banner + retry) instead of silent empty/cache; daily totals stay on stored local-day truth. `core/` no longer imports presentation cubits. Standalone; does not require Epic 35.
**FRs covered:** FR-R1, FR-R2, FR-R3, FR-R4, FR-R5

### Epic 35: Snappy My Data (optional)
My Data (and Profile if it still root-watches) rebuilds only the section that changed. Same export/import/purge/footprint actions. After Epic 34.
**FRs covered:** FR-R6, FR-R7

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

**Execution order (user-confirmed 2026-06-02):** Story **5.5** (Built-in Kotlin / KGP) **first**.

**Execution order (user-confirmed 2026-06-04 — story IDs match sequence):**

| Step | Story | Focus |
|------|-------|--------|
| 0 | **5.5** | Built-in Kotlin / KGP *(done)* |
| 1 | **5.6** | `phosphor_flutter` install |
| 2 | **5.7** | Four-tab floating navbar (TODAY · TRENDS · DATA · PROFIL) |
| 3 | **5.8** | Six accent preset theme tokens (+ contrast) |
| 4 | **5.9** | Today Figma layout; **no** `Hello, {name}`; stats row **visible, empty** until Epic 6 |
| 5 | **5.10** | Data screen (Background · Footprint · Your data); tab **DATA**; screen title **My Data** |
| 6 | **5.11** | Profil screen; section **Informations**; Appearance → tokens + bi-tone preset circles |
| 7 | **5.12** | Cross-screen cohesion audit |
| — | **5.13** | Goal overflow polish — backlog after 5.12 (optional) |

**Renumbering (2026-06-04):** IDs aligned to execution order. Legacy map: old 5.9→5.6, 5.2→5.7, 5.1→5.8, 5.6→5.9, 5.7→5.10, 5.8→5.11, 5.3→5.12, 5.4→5.13. Epic map: old 7→6 (metrics), old 6→7 (OSS); stories 7.1→6.1, 6.x→7.x.

Then **Epic 6** (derived metrics). Then **Epic 7** (OSS beta). Trends tab reuses Epic 3 chart screen (label **Trends**, same content).

## Epic 6: Derived Activity Metrics
Populate Today’s kcal / distance / walking-time row from steps and profile biometrics (formulas TBD). **Runs after Epic 5** cohesion pass.
**FRs covered:** FR-33 (see Sprint Change Proposal 2026-06-04)

## Epic 7: OSS Credibility & Beta Readiness
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

**Execution order (user-confirmed 2026-06-02):** Story **5.5** (Built-in Kotlin / KGP) **first**.

**Execution order (user-confirmed 2026-06-04 — story IDs match sequence):**

| Step | Story | Focus |
|------|-------|--------|
| 0 | **5.5** | Built-in Kotlin / KGP *(done)* |
| 1 | **5.6** | `phosphor_flutter` install |
| 2 | **5.7** | Four-tab floating navbar (TODAY · TRENDS · DATA · PROFIL) |
| 3 | **5.8** | Six accent preset theme tokens (+ contrast) |
| 4 | **5.9** | Today Figma layout; **no** `Hello, {name}`; stats row **visible, empty** until Epic 6 |
| 5 | **5.10** | Data screen (Background · Footprint · Your data); tab **DATA**; screen title **My Data** |
| 6 | **5.11** | Profil screen; section **Informations**; Appearance → tokens + bi-tone preset circles |
| 7 | **5.12** | Cross-screen cohesion audit |
| — | **5.13** | Goal overflow polish — backlog after 5.12 (optional) |

**Renumbering (2026-06-04):** IDs aligned to execution order. Legacy map: old 5.9→5.6, 5.2→5.7, 5.1→5.8, 5.6→5.9, 5.7→5.10, 5.8→5.11, 5.3→5.12, 5.4→5.13. Epic map: old 7→6 (metrics), old 6→7 (OSS); stories 7.1→6.1, 6.x→7.x.

Then **Epic 6** (derived metrics). Then **Epic 7** (OSS beta). Trends tab reuses Epic 3 chart screen (label **Trends**, same content).

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

**Implementation note:** Story 7.2 retains release-manifest and privacy audit scope; KGP resolution is **pulled forward** to Epic 5 per user decision (2026-06-02) — do not defer to beta hardening.

---

### Story 5.6: Phosphor Icons Dependency

As a **builder**,
I want Phosphor icons available app-wide,
So that navigation and screens match the Figma mockups.

**Acceptance Criteria:**

**Given** locked `pubspec.yaml`
**When** `phosphor_flutter` is added at a compatible version
**Then** `flutter pub get` succeeds and `docs/DEPENDENCIES.md` is updated (health pipeline unchanged)

**Given** the package is installed
**When** `flutter analyze` runs
**Then** no new analyzer errors

**Prerequisite for:** Story 5.7 (tab icons).

---

### Story 5.7: Four-Tab Floating Navigation Bar

As a **user**,
I want four clearly labeled tabs in a floating pill navigation bar,
So that I can reach Today, Trends, Data, and Profil quickly.

**Acceptance Criteria:**

**Given** onboarding complete
**When** main app loads
**Then** `AppScaffold` shows **four** destinations: **TODAY · TRENDS · DATA · PROFIL** (short tab labels per Figma)
**And** floating pill `NavigationBar` styling matches mockups (orange bar, white squircle on active tab)
**And** Phosphor icons: Footprints (Today), ChartBar (Trends), Database (Data), User (Profil)

**Given** fourth tab **DATA**
**When** selected
**Then** `DataScreen` (sovereignty layout — Story 5.10) is shown

**Given** fourth tab **PROFIL**
**When** selected
**Then** `ProfileScreen` placeholder or implementation (Story 5.11) is shown

**Given** tab **TRENDS**
**When** selected
**Then** existing History chart screen is shown (Epic 3 — same content; tab label **Trends** only in this story)

**Given** reduce-motion enabled
**When** switching tabs
**Then** cross-fade or instant swap preserved (UX-DR18)

**Depends on:** Story 5.6.

---

### Story 5.8: Accent Preset Theme Tokens

As a **user**,
I want six accent color presets that work in light and dark themes,
So that Appearance on Profil can theme the whole app consistently.

**Acceptance Criteria:**

**Given** `AstraColors` / `astra_theme.dart`
**When** tokens are defined for presets `orange | red | green | cyan | purple | pink`
**Then** each preset provides light + dark semantic mappings (accent primary, accent-muted, nav, ring, chart emphasis) per Figma theming matrix
**And** default preset is **orange** (continuity with `#EAD55E` family where applicable)
**And** no ad-hoc hex in widgets (V-2)

**Given** `user_preferences.accent_preset`
**When** read at startup
**Then** `ThemeCubit` (or equivalent) applies the stored preset app-wide

**Given** primary buttons on accent fill
**When** rendered in light and dark
**Then** label contrast meets UX §4.1 baseline (NFR5)

**Given** goal-met days (field feedback 2026-06-03)
**When** Today ring or Trends bar reflects goal met
**Then** optional `color.status.ok` semantic remains available alongside preset accents

**Given** token work complete
**When** `flutter analyze` and tests run
**Then** no regressions; UX spec token table updated if hex values change

**Depends on:** Story 5.7 (shell to validate nav accent). **Prerequisite for:** Stories 5.9, 5.10, 5.11.

---

### Story 5.9: Today Screen — Figma Layout (No Greeting)

As a **user**,
I want Today’s activity at a glance with goal, week progress, and reserved stats,
So that the home screen matches the redesigned layout.

**Acceptance Criteria:**

**Given** Today tab selected
**When** screen renders
**Then** layout matches Figma: title **Today's activity**, donut + center steps/goal, **Set goal** pill below donut
**And** **no** `Hello, {name}` or display-name greeting (Story 4.8 greeting retired)
**And** **This week** row: seven day pills with goal-met / missed / today / future states

**Given** stats row (kcal, distance, walking time)
**When** Epic 6 is not complete
**Then** three columns are **visible** with icons and labels but values show empty placeholder (`—` or equivalent) — not hidden

**Given** Set goal tapped
**When** editor opens
**Then** same validation as Story 4.6 / onboarding (1,000–100,000 integer)

**Given** stale threshold exceeded
**When** Today visible
**Then** compact stale banner may link user to Data tab (UX-DR8)

**Depends on:** Stories 5.8, 5.7.

---

### Story 5.10: Data Screen — Sovereignty Layout

As a **user**,
I want data sovereignty controls grouped on the Data tab,
So that background health, footprint, and CSV actions are easy to find.

**Acceptance Criteria:**

**Given** **DATA** tab selected
**When** screen renders
**Then** screen **title** reads **My Data** (once at top — not shortened to "Data" in body)
**And** only three sections exist: **Background**, **Footprint**, **Your data** (export / import / delete per Stories 4.2–4.5)

**Given** Data screen
**When** inspected
**Then** goal editor, theme selector, display-name row, and profile badge from old My Data are **absent** (moved to Today / Profil)

**Given** export, import, purge flows
**When** exercised
**Then** behavior unchanged from Epic 4 (FR-19–21, FR-30)

**Depends on:** Stories 5.8, 5.7.

---

### Story 5.11: Profil Screen — Informations & Appearance

As a **user**,
I want profile and appearance settings on the Profil tab,
So that personal info and theming are separate from raw data controls.

**Acceptance Criteria:**

**Given** **PROFIL** tab selected
**When** screen renders
**Then** screen title **My Profile** (or consistent copy key) and section **Informations** (not "Profile" as section title — user-confirmed 2026-06-04)
**And** Informations rows: **display name**, **height** (cm), **weight** (kg) — label + value + chevron; edits persist locally
**And** **no** age or sex/gender fields (2026-06-04)

**Given** migration runs (e.g. v3 or next `user_preferences` migration)
**When** Profil fields are stored
**Then** keys `height_cm` and `weight_kg` persist via `UserPreferencesRepository` (nullable; validated ranges e.g. height 100–250 cm, weight 30–300 kg)

**Given** Notifications card
**When** toggle changes
**Then** `goal_notifications_enabled` (or equivalent) persists and respects FR-24/25 permission state

**Given** Appearance card
**When** user interacts
**Then** (1) **System / Light / Dark** segmented control persists `theme_mode` (migrate Story 4.7)
**And** (2) row of **six bi-tone circles** per Sprint Change Proposal FR-32 — base half reflects effective light/dark, top-right half = preset color; selection wired to **Story 5.8** tokens
**And** changing preset or mode updates app chrome without restart

**Given** purge all health data on Data tab
**When** completed
**Then** Informations + appearance prefs survive per FR-20 amended list

**Depends on:** Story 5.8 (tokens). **Completes:** migration of 4.7, 4.8 (name only on Profil), 4.9 affordances as applicable.

---

### Story 5.12: Cross-Screen Visual Cohesion Audit

As a **builder**,
I want every surface verified against the UX visual checklist on device,
So that the app feels cohesive before OSS beta release.

**Acceptance Criteria:**

**Given** UX spec §4.7 checklist V-1–V-13
**When** executed on release or profile build on physical device
**Then** each item passes or has documented exception with fix plan (UX-DR21)

**Given** Today, Trends, Data, Profil, and onboarding
**When** reviewed in system, light, dark, and each **accent preset**
**Then** typography uses bundled Figtree + Darker Grotesque only (V-3); no layout jumps on Today sync (V-5)

**Given** Today (Story 5.9)
**When** user opens Today
**Then** **no** `Hello, {name}` greeting is shown; ring remains sole step-count hero

**Given** Data tab (Story 5.10)
**When** screen title is read
**Then** body title is **My Data**; tab label remains short **DATA**

**Given** Profil (Story 5.11)
**When** Informations section is read
**Then** section title is **Informations** (not "Profile")

**Given** screenshot / README GIF readiness (SM-7 prep)
**When** Today and Data are framed
**Then** hero layouts are presentation-ready (V-13)

**Given** findings from Epics 1–5 device testing
**When** logged in story completion notes
**Then** residual polish items are either fixed in this story or explicitly deferred with rationale

**Given** Data background status copy (field feedback 2026-06-03)
**When** user reads "Last sync {relative time}" on device
**Then** checklist documents expected semantics: **last successful ingestion** timestamp (WM/FGS/collect), **not** the 60s foreground persist timer — optional UX copy tweak if confusion persists after doc pass

---

### Story 5.13: Goal Overflow Animation Polish

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

## Epic 6: Derived Activity Metrics

The user sees estimated kcal, distance, and walking-time on Today’s stats row (General Wellness estimates — FR-33).

### Story 6.1: Derived Activity Metrics

As a **user**,
I want distance, calories, and walking time estimated from my steps and optional height/weight,
So that Today’s stats row shows meaningful numbers instead of placeholders.

**Acceptance Criteria:**

**Given** Story **5.11** shipped (`height_cm`, `weight_kg` in `user_preferences`)
**When** `DerivedActivityMetrics.compute()` runs
**Then** **distance_km** = `displaySteps × stride_m / 1000` where `stride_m = (height_cm/100)×0.414` if height set, else **0.76**
**And** **walking_duration** = sum of bucket durations for today's local day where `type=steps` and `value > 0`
**And** **kcal** = `3.5 × (weight_kg ?? 70) × (walking_seconds / 3600)` (MET moderate walking)

**Given** `TodayCubit` displays stats
**When** live step overlay increases `displaySteps` above SQLite-only total
**Then** **distance** and displayed step count stay consistent (scale distance with live steps)
**And** **kcal** and **duration** reflect latest persisted buckets (acceptable lag until ingest)

**Given** no height/weight in preferences
**When** metrics compute
**Then** defaults **0.76 m** stride and **70 kg** apply without error

**Given** unit tests in `test/core/metrics/derived_activity_metrics_test.dart`
**When** run
**Then** cover defaults, custom profile, zero buckets, single active bucket, and live-step scaling rule

**Depends on:** Stories 5.9, 5.11, 5.12 (cohesion sign-off). **Do not start** until 5.12 passes.

**Implementation notes:** `lib/core/metrics/derived_activity_metrics.dart`; `StepRepository.getTodayActiveBuckets()` (or equivalent); wire `TodayCubit` / `TodayState`. No age/gender fields.

---

## Epic 7: OSS Credibility & Beta Readiness

The repo is beta-ready and open-source credible — documentation, privacy audit, release hardening, and acceptance checklist.

### Story 7.1: Open Source License and Documentation Bundle

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

### Story 7.2: Release Manifest Hardening and Privacy Audit

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

### Story 7.3: Beta Acceptance Checklist

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

**Given** field regression items from 2026-06-03 device pass (fix in post-checklist hotfix batch — Baptiste sequencing)
**When** checklist is authored and executed on release APK
**Then** explicit manual cases exist for: (1) goal local notification — app **killed** during walk, reopen after goal crossed, **notification permission granted in OS settings** → one notification same day (FR25); (2) walk repro — kill mid-walk → reopen shows goal met; screen-off with app alive → no spurious steps; **kill+reopen at home** → count must **not decrease**; (3) Delete all local data — **2 consecutive** attempts succeed (FR20); (4) purge + footprint empty state on all tabs
**And** failures are logged with device model / Android version / build type for the consolidated debug pass after checklist
**And** README demo GIF capture is documented as checklist item

**Given** install size check
**When** release APK built
**Then** artifact size is <50MB (NFR2, SM-6)

---

## Epic 8: Goal Time Semantics

Daily step goals are effective-dated; changing a goal updates today immediately and never retroactively alters past days.

**Depends on:** Epics 1–7 done. **Blocks:** Epic 11, Epic 12 (goal line / week dots).

### Story 8.1: Daily Goal History Schema and Repository

As a **user**,
I want my daily step goal changes recorded with an effective date,
So that historical days keep the goal that applied when I walked them.

**Acceptance Criteria:**

**Given** fresh install or upgrade from DB v2
**When** migration v3 runs
**Then** table `daily_goal_effective (effective_from_local_day TEXT PRIMARY KEY, goal INTEGER NOT NULL CHECK (goal > 0))` exists
**And** one seed row is inserted for today's local day with the current `daily_step_goal` preference value (default 8000 if unset)

**Given** `UserPreferencesRepository.getGoalForLocalDay(localDay)`
**When** called for any local calendar day
**Then** returns the `goal` from the latest row where `effective_from_local_day ≤ localDay` (ISO date string)
**And** falls back to `kDefaultStepGoal` when no row applies

**Given** `UserPreferencesRepository.setDailyStepGoal(goal)` with valid positive integer
**When** today's local day already has a row in `daily_goal_effective`
**Then** that row is **updated** to the new goal
**When** today has no row yet
**Then** a row is **inserted** with `effective_from_local_day = today`
**And** `user_preferences.daily_step_goal` cache is kept in sync

**Given** unit tests in `test/data/repositories/user_preferences_repository_test.dart` (or dedicated goal history test)
**When** run
**Then** cover: seed on migration, same-day update, new-day insert, resolution for past/future days, invalid goal rejected

**Mockup ref:** N/A (data layer).

---

### Story 8.2: Goal History Consumer Migration

As a **user**,
I want every goal comparison in the app to use the goal that applied on that day,
So that week dots, charts, and notifications stay truthful after I change my goal.

**Acceptance Criteria:**

**Given** goal was 8000 Mon–Wed and user changes to 10000 on Thu
**When** `TodayCubit._loadWeekDays` runs
**Then** Mon–Wed `goalMet` uses 8000; Thu+ uses 10000 (Thu change is immediate on current day)

**Given** `HistoryCubit` renders bar chart
**When** goal reference line is drawn
**Then** each bar day uses `getGoalForLocalDay(thatDay)` — not a single global goal

**Given** `BackgroundCollector.maybeNotifyGoalReachedIfGoalMet`
**When** evaluating today's steps
**Then** uses `getGoalForLocalDay(today)` only

**Given** in-app goal celebration on Today/Steps
**When** steps cross threshold
**Then** threshold is today's resolved goal from history API

**Given** existing step-ingestion and FGS tests
**When** this story ships
**Then** `background_collector_test`, `today_cubit_test`, chart tests pass with no changes to ingest write path

**Depends on:** Story 8.1.

---

## Epic 9: Android FGS Notification

Reduce intrusive visibility of the health foreground service notification without breaking background step collection.

**Depends on:** Epics 1–7 done. **Parallel with:** Epic 10.

### Story 9.1: Android FGS Notification Visibility

As a **user**,
I want the step-tracking notification to be as discreet as Android allows,
So that passive tracking feels honest but not nagging.

**Acceptance Criteria:**

**Given** `HealthStepForegroundService` is running on Android
**When** the foreground notification is displayed
**Then** channel importance is minimized (`IMPORTANCE_MIN` or lowest compatible with FGS health on target SDK)
**And** notification uses `PRIORITY_MIN` / low visibility flags, `setShowBadge(false)`, `setOnlyAlertOnce(true)`
**And** copy remains honest (not disguised as sync/backup) — title/body may be shortened vs current

**Given** FGS health collection loop
**When** this story ships
**Then** `COLLECTION_INTERVAL_MS` and Dart collection bridge unchanged
**And** `test/core/services/fgs_step_collection_test.dart` and `health_foreground_notification_test.dart` pass (updated expectations if copy/channel change)

**Given** manual test on physical Android device
**When** app backgrounded with activity permission granted
**Then** steps still accumulate within expected WM/FGS interval

**Mockup ref:** N/A (system notification).

---

## Epic 10: App Shell, Navigation & Settings Surfaces

Replace four-tab navigation with three tabs, menu hub, secondary screens (Profile, Data, Settings, About), Profile/Settings split, and display Units — **presentation layer only**; no change to step ingestion core.

**Depends on:** Epics 1–7 done. **Parallel with:** Epic 9 after Epic 8. **Version bump:** **moyen** once when entire epic closes (merged former Epic 13).

### Story 10.1: Three-Tab Bottom Navigation

As a **user**,
I want a simpler bottom bar with Steps, Trends, and Menu,
So that primary actions stay visible and secondary screens don't clutter the bar.

**Acceptance Criteria:**

**Given** authenticated onboarding complete user on main shell
**When** bottom navigation renders
**Then** exactly **three** tabs display: **STEPS**, **TRENDS**, **MENU** (Phosphor icons per mockup)
**And** DATA and PROFILE tabs are removed from `AppBottomNav`

**Given** tab labels
**When** compared to mockup
**Then** STEPS replaces TODAY; TRENDS unchanged; MENU uses hamburger/list icon

**Given** `AppScaffold` `IndexedStack`
**When** refactored
**Then** primary tabs index 0 = Steps screen, 1 = Trends, 2 = Menu hub (stub acceptable until 10.2)

**Mockup ref:** Steps / Trends / Menu bottom bar (`Today-light`, `History-light`, `Menu-light`).

---

### Story 10.2: Menu Hub Full-Screen List

As a **user**,
I want a menu page listing Profile, Data, Settings, and About,
So that I can reach secondary screens from one place.

**Acceptance Criteria:**

**Given** MENU tab selected
**When** screen renders
**Then** title reads **Menu** (menu hub — aligns with MENU tab; not the Data sovereignty screen)
**And** section **Informations** lists: **Profile**, **Data** (chevron rows)
**And** section **Other** lists: **Settings**, **About**
**And** **Achievements** and **Help** rows are **absent** (deferred backlog)

**Given** list row tap
**When** user selects an item
**Then** navigation pushes the target screen (implementation in 10.3)

**Mockup ref:** `Menu-light`.

---

### Story 10.3: Secondary Screen Navigator Stack

As a **user**,
I want back navigation from Profile, Data, Settings, and About,
So that I return to the menu without losing my tab context.

**Acceptance Criteria:**

**Given** Menu hub row tap
**When** Profile, Data, Settings, or About opens
**Then** screen pushes on a `Navigator` stack with back arrow + screen title matching mockups
**And** popping returns to Menu hub with MENU tab still selected

**Given** `AppScaffold` lifecycle hooks (refresh on tab switch)
**When** returning from secondary screen
**Then** Steps/Trends cubits refresh rules remain correct (no duplicate cubit disposal)

**Given** smoke tests
**When** run
**Then** `screen_smoke_test` covers Menu → Profile and Menu → Data navigation

**Depends on:** Stories 10.1, 10.2. **Enables:** Stories 10.4–10.8.

**Mockup ref:** Profile, Data, Settings, About headers with back arrow.

---

### Story 10.4: Profile Slim Informations

As a **user**,
I want Profile to show only my personal info,
So that settings and appearance live in one dedicated place.

**Acceptance Criteria:**

**Given** Menu → Profile
**When** screen renders
**Then** title **Profile**, section **Informations** with rows: Display name, Height, Weight (chevron editors)
**And** theme selector, accent presets, and goal notification toggle are **removed** from Profile

**Given** existing Profile cubit editors
**When** user edits name/height/weight
**Then** persistence unchanged (canonical cm/kg storage)

**Mockup ref:** `Profil-light`.

**Depends on:** Story 10.3.

---

### Story 10.5: Settings Appearance and Notifications

As a **user**,
I want theme and notification controls in Settings,
So that appearance is grouped with other app preferences.

**Acceptance Criteria:**

**Given** Menu → Settings
**When** screen renders
**Then** **Notifications** card with **Receive Goal notifications** toggle (same behavior as current Profile)
**And** **Theme** card with System/Light/Dark segmented control + bi-tone accent preset circles (migrated from Profile)

**Given** toggle/theme changes
**When** saved
**Then** same persistence keys and `ThemeCubit` wiring as pre-split Profile

**Mockup ref:** `Settings-light`.

**Depends on:** Story 10.3.

---

### Story 10.6: Display Units Preferences

As a **user**,
I want to choose how distance, weight, and height are displayed,
So that the app matches my locale's conventions.

**Acceptance Criteria:**

**Given** Settings → Units section
**When** screen renders
**Then** three rows with chevron: **Distance** (Metric/Imperial), **Weight** (Kg/lb), **Height** (cm/ft+in)
**And** current selection displayed on each row

**Given** user picks a unit option
**When** saved to `user_preferences`
**Then** keys persist across restart (e.g. `distance_display_unit`, `weight_display_unit`, `height_display_unit`)
**And** canonical stored values remain metric internally

**Mockup ref:** `Settings-light` (Units card).

**Depends on:** Story 10.5.

---

### Story 10.7: App-Wide Unit Formatters

As a **user**,
I want all displayed measurements to respect my unit choices,
So that numbers feel natural everywhere.

**Acceptance Criteria:**

**Given** unit prefs set to Imperial / lb / ft+in
**When** user views Steps stats row, Profile height/weight labels, and Trends kcal/distance labels where applicable
**Then** values convert for **display only** (km→mi, kg→lb, cm→ft/in)
**And** editors accept input in display unit and convert to canonical on save

**Given** unit tests
**When** run
**Then** cover conversion round-trip and formatter edge cases (null profile, zero values)

**Depends on:** Story 10.6.

---

### Story 10.8: Data and About Screens

As a **user**,
I want Data sovereignty and About info reachable from Menu,
So that secondary tasks stay organized.

**Acceptance Criteria:**

**Given** Menu → Data
**When** screen renders
**Then** matches mockup: Background status, Footprint KPIs, Your data (Export CSV, Import CSV, Delete all local data)
**And** reuses existing `MyDataCubit` / widgets; title **Data** with back navigation

**Given** Menu → About
**When** screen renders
**Then** app icon placeholder, **Astra Health** title, **Version: {versionName}** from `package_info_plus` (matches `pubspec.yaml`)

**Given** purge/export flows
**When** executed from Data screen
**Then** FR-19–FR-21 behavior unchanged; goal history table survives purge policy as defined in architecture (goal prefs preserved like FR-20 non-health prefs)

**Mockup ref:** `Data-light`, `About-light`.

**Depends on:** Stories 10.3, 10.4, 10.5.

---

## Epic 11: Steps Dashboard

Rename Today to Steps, week-first layout, day selection, and historical goal-aware week strip.

**Depends on:** Epic 8, Epic 10 (10.1 minimum).

### Story 11.1: Steps Screen Layout Week-First

As a **user**,
I want the week summary at the top of Steps,
So that I see weekly context before today's detail.

**Acceptance Criteria:**

**Given** Steps tab (index 0)
**When** screen renders
**Then** screen title is **Steps** (not "Today's activity")
**And** **This week** `SectionCard` is the **first** content block below title/stale banner
**And** goal ring + stats row appear **below** the week card
**And** **Set goal** pill remains below the ring

**Mockup ref:** `Today-light` (layout order).

---

### Story 11.2: Day Picker and Selected Day State

As a **user**,
I want to tap a day in the week strip to inspect that day,
So that I can review past activity without leaving Steps.

**Acceptance Criteria:**

**Given** week strip rendered
**When** user taps a day pill (past, today, or future)
**Then** `TodayState.selectedLocalDay` updates (add field to state/cubit)
**And** selected pill has distinct visual (mockup: filled accent for selected/today)
**And** future days show zero/empty indicators without live overlay

**Given** cold start or app resume from background
**When** Steps tab shown
**Then** `selectedLocalDay` defaults to **today** automatically

**Given** unit tests
**When** run
**Then** cover day selection, default-on-resume, future-day empty state

**Mockup ref:** `Today-light` (THU highlighted).

---

### Story 11.3: Selected Day Indicators and Live Guards

As a **user**,
I want the ring, stats, and goal to reflect the selected day,
So that the dashboard is truthful for any day I pick.

**Acceptance Criteria:**

**Given** a past local day selected
**When** Steps refreshes
**Then** ring shows that day's step total and `getGoalForLocalDay(thatDay)`
**And** `ActivityStatsRow` shows metrics computed from that day's steps + buckets + profile
**And** **Set goal** still edits **current** goal (applies from today per Epic 8 rules)

**Given** `selectedLocalDay == today`
**When** live step pipeline emits
**Then** ring/stats update live; celebration and foreground catch-up **enabled**

**Given** `selectedLocalDay != today`
**When** live step pipeline emits
**Then** displayed steps/metrics **do not** change from live overlay; no celebration

**Depends on:** Stories 8.2, 11.2.

**Mockup ref:** `Today-light`.

---

### Story 11.4: Week Trophy and Historical Goal Dots

As a **user**,
I want a weekly score and per-day goal dots based on each day's actual goal,
So that I see how many days I hit target this week.

**Acceptance Criteria:**

**Given** current calendar week Mon–Sun
**When** week card renders
**Then** trophy badge shows **X/7** where X = count of days (Mon–Sun) with `steps ≥ getGoalForLocalDay(day)` and day not in the future
**And** past-day dots use historical goal resolution (Epic 8)

**Given** user changes goal mid-week
**When** week strip re-renders
**Then** only today and future goal comparisons use new goal; past days unchanged

**Mockup ref:** `Today-light` (3/7 trophy, purple dots Mon–Wed).

---

## Epic 12: Trends Analytics

Expand Trends with summary stats, peak day, 12-month monthly chart, and per-day goal line.

**Depends on:** Epic 8.

### Story 12.1: Trends Average Stats Cards

As a **user**,
I want average calories and steps for my selected period,
So that I understand typical daily activity at a glance.

**Acceptance Criteria:**

**Given** Trends tab with 7d or 30d toggle selected
**When** data exists for the window
**Then** two cards display below the chart:
- **Average kcal burned per day** (flame icon)
- **Average steps taken per day** (footprint icon)

**Given** kcal average computation
**When** calculated for each day in window
**Then** uses `DerivedActivityMetrics.compute()` with that day's step total, active buckets, and current height/weight profile
**And** window average = mean of daily kcal values (days with zero steps count as 0)

**Given** period toggle change
**When** user switches 7d ↔ 30d
**Then** both cards recalculate for the active window

**Mockup ref:** `History-light` (167 kcal / 3532 steps cards).

---

### Story 12.2: Trends Peak Day Card

As a **user**,
I want to see my best day in the selected period,
So that I know my peak performance.

**Acceptance Criteria:**

**Given** 7d or 30d period active
**When** at least one day in window has steps > 0
**Then** a **Peak day** stat displays the local date label and step count of the day with maximum `totalSteps` in that window
**And** ties break to most recent day

**Given** empty window (all zero)
**When** Trends renders
**Then** peak day card hidden or shows em dash (consistent with empty state patterns)

**Mockup ref:** Not in mockup — product spec 2026-06-15.

---

### Story 12.3: Trends Twelve-Month Monthly Chart

As a **user**,
I want a yearly view of my walking habit,
So that I see long-term trends without daily noise.

**Acceptance Criteria:**

**Given** Trends screen
**When** user selects **12 months** view (new period toggle or section — UX TBD in implementation; not 7d/30d bar chart)
**Then** chart shows **12 bars** (one per calendar month) where bar height = **average daily steps** for that month (total steps in month ÷ days in month with data, or calendar days — document choice in story file)
**And** query completes without KPI-01 regression on existing 7d/30d chart path

**Given** `StepRepository`
**When** monthly aggregation added
**Then** uses stored samples + zone offsets; no network

**Mockup ref:** Not in mockup — product spec 2026-06-15.

---

### Story 12.4: Trends Historical Goal Line

As a **user**,
I want the goal reference on the bar chart to reflect each day's goal,
So that past bars are judged against the goal I had then.

**Acceptance Criteria:**

**Given** 7d or 30d bar chart
**When** goal reference rendered
**Then** each day's bar is compared to `getGoalForLocalDay(thatDay)` — dashed line may be stepped or per-bar threshold per existing chart UX
**And** changing global goal today does not shift past days' reference

**Depends on:** Story 8.2.

**Mockup ref:** `History-light` (2k dashed line — per-day resolution post Epic 8).

---

## Epic 13: Onboarding Redesign

Replace trust/permissions/goal/display-name stack with intro → weight → height flow per Figma mockups. Activity permission requested on intro **Continue** (OS dialog bridge, no dedicated permission screen). Collect optional body metrics for derived activity estimates.

**Depends on:** Epics 1, 6, 10 done. **Version bump:** **moyen** once when entire epic closes (`0.6.0+11` from `0.5.2+10`).

**Supersedes:** Story 1.5 presentation (persistence keys and onboarding gate pattern remain).

### Story 13.1: Onboarding Shell & Intro Screen

As a **user**,
I want a clear trust-first intro before body metrics,
So that I understand local-only tracking before granting sensor access.

**Acceptance Criteria:**

**Given** first launch (`onboarding_complete` false)  
**When** onboarding renders  
**Then** 3-segment progress bar shows step 1 active  
**And** headline reads **Your Health. Your Phone. Period.**  
**And** card copy matches: *Astra tracks your movement, habits, and health metrics using only your device's built-in sensors. No accounts, no cloud leakage. Your personal evolution belongs to you—and only you.*  
**And** optional disclaimer expands/collapses without blocking Continue  
**And** footer shows primary Continue (no Back on step 1)

**Given** user taps Continue on intro  
**When** activity permission has not been granted  
**Then** system activity recognition dialog appears **before** weight step is shown  
**And** flow advances to weight after dialog dismisses (grant or deny)  
**And** Continue shows loading/disabled state while request is in flight

**Mockup ref:** `onboarding-light`.

---

### Story 13.2: AstraHorizontalRuler Widget

As a **developer**,
I want a reusable horizontal ruler picker,
So that weight and height onboarding (and future editors) share one interaction pattern.

**Acceptance Criteria:**

**Given** ruler with min/max/step configured  
**When** user scrolls horizontally  
**Then** centered value updates with snap-to-tick behavior  
**And** major labels render at configured intervals  
**And** semantics announce value + unit  
**And** widget test covers snap and bounds

**Mockup ref:** `Weight-light`, `Height-light`.

---

### Story 13.3: Weight & Height Onboarding Steps

As a **user**,
I want to set my weight and height with familiar unit toggles and a ruler,
So that derived metrics are accurate from day one.

**Acceptance Criteria:**

**Given** weight step  
**When** user selects kg or lb via `AstraSegmentedControl`  
**Then** ruler range and labels update; stored value is canonical kg  
**Given** height step  
**When** user selects cm or inches  
**Then** stored value is canonical cm  
**Given** Skip on either step  
**When** user continues  
**Then** corresponding pref is `null`  
**Given** Let's Go on height step  
**When** onboarding completes  
**Then** `onboarding_complete=true`, `daily_step_goal=8000`, metrics saved

**Mockup ref:** `Weight-light`, `Height-light`.

**Depends on:** Stories 13.1, 13.2.

---

### Story 13.4: Flow Completion & Cleanup

As a **maintainer**,
I want the old onboarding steps removed and tests updated,
So that the codebase reflects the new 3-step flow only.

**Acceptance Criteria:**

**Given** user denied activity on intro Continue  
**When** they complete weight + height and land on Steps  
**Then** existing permission-denied / empty-state patterns apply (no second onboarding gate)  
**Given** removed pages  
**When** codebase is searched  
**Then** `OnboardingPermissionsPage`, `OnboardingGoalPage`, `OnboardingDisplayNamePage` are not in active flow  
**Given** tests  
**When** `flutter test` runs  
**Then** onboarding flow tests reflect 3 steps  
**Given** beta checklist FUNC-10  
**When** updated  
**Then** repro: trust copy on intro → Continue → grant activity → complete onboarding

**Depends on:** Story 13.3.

---

## Future Backlog (not Epics 8–13)

| Item | Notes |
|------|-------|
| **Achievements** | Menu row + screen — mockup TBD |
| **Help** | Menu row + screen — mockup TBD |

---

# Phase: Refacto (Epics 14–20)

> complete 2026-06-21 · branch `refacto`

## Epic 14: Lifecycle Safety & Silent Failure Prevention
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

---

# Phase: Post-audit (Epics 21–28)

> complete 2026-07-19

## Epic 21: Cold Start & SQLite
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

---

# Phase: Data audit (Epics 29–33)

> complete 2026-07-25

## Epic 29: Accurate Step Tracking (Persist Path)
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
**Then** decision recorded in story notes and `audits/data-pipeline/README.md` P0-01 status updated

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

---

## Epic 34: Honest Trends & layering integrity

The user sees a Trends refresh failure (banner + retry) instead of silent empty/cache; daily totals stay on stored local-day truth. `core/` no longer imports presentation cubits.

**Priority:** P0 · **Version bump:** patch+1 + build+1 at epic close (mineur, e.g. `0.15.3+41`) · **Source:** `sprint-change-proposal-2026-08-31.md` (not the raw audit matrix)

**FRs covered:** FR-R1, FR-R2, FR-R3, FR-R4, FR-R5  
**UX-DRs:** UX-DR1, UX-DR2, UX-DR3  
**NFRs:** NFR9, NFR1, NFR-R1, NFR-R2, NFR-R3

**Prerequisite:** Epics 1–33 done. **Does not require Epic 35.** First story is types (34-1), not SQL.

### Story 34-1: Relocate presentation-owned types used by core/

As a **maintainer**,
I want permission and Trends insight types to live outside cubit state files,
So that `core/` can use them without importing presentation.

**Acceptance Criteria:**

**Given** `PermissionRequestStatus` today lives in `onboarding_state.dart`
**When** this story ships
**Then** the enum lives in `core/` (e.g. `core/permissions/`)
**And** `activity_permission_resolver.dart` / `notification_permission_resolver.dart` import that location — not `presentation/`
**And** onboarding, Today, My Data, and the background card keep the same enum values and iOS `Permission.sensors` vs Android `activityRecognition` mapping

**Given** `core/metrics/trends_insights.dart` imports `history_state.dart`
**When** this story ships
**Then** `TrendsInsightAvailability`, `TrendsMostActiveWeekday`, and `TrendsGoalStreak` live in `core/metrics/` (or `core/` adjacent) — not `history_state.dart`
**And** `history_state.dart` / Trends widgets re-export or import those types; behaviour of `computeInsightAvailability` is unchanged
**And** **no** `lib/domain/` directory is created

**Given** `flutter test --tags critical`
**When** story closes
**Then** the suite is green; `core/` permission + metrics files have zero `presentation/` imports

**Out of scope:** cubit imports in lifecycle (34-2); `TodayStatus` if still only used by 34-2.

**Target files:** `lib/core/permissions/*`, `lib/core/metrics/trends_insights.dart`, `onboarding_state.dart`, `history_state.dart`, tests that import those types  
**Source:** FR-R1 · D-22

---

### Story 34-2: Lifecycle refresh without cubit imports

As a **maintainer**,
I want resume/refresh to go through the existing coordinator,
So that `core/` lifecycle never imports cubits.

**Acceptance Criteria:**

**Given** `app_lifecycle_coordinator.dart` and `lifecycle_session_state.dart` import `TodayCubit` / `HistoryCubit` / `MyDataCubit`
**When** this story ships
**Then** those files have **zero** `package:astra_app/presentation/` (or relative `presentation/`) imports
**And** `lifecycle_live_pipeline_service.dart` no longer imports `today_state.dart`

**Given** `AppCubitCoordinator` already exists
**When** implementing
**Then** add ports/callbacks **on that class** — do not create a second coordinator
**And** silent Today / History / My Data refresh on resume still runs (same triggers as today)

**Given** `flutter test --tags critical` including lifecycle / coordinator tests
**When** story closes
**Then** the suite is green

**Depends on:** 34-1 (types already moved).

**Target files:** `app_lifecycle_coordinator.dart`, `lifecycle_session_state.dart`, `lifecycle_live_pipeline_service.dart`, `app_cubit_coordinator.dart`, DI/wiring, existing lifecycle tests  
**Source:** FR-R2 · D-22 · NFR-R1

---

### Story 34-3: History refresh failure is visible

As a **user**,
I want Trends to tell me when history failed to refresh and let me retry,
So that I do not think I have no data when the load failed.

**Acceptance Criteria:**

**Given** History refresh throws and `_cachedAggregates30d` is empty (or no usable cache)
**When** recovery runs
**Then** `HistoryStatus` includes `error` and Trends shows `StatusBanner` **error** + retry — UX-DR1
**And** empty-state copy is **not** shown as if the user simply has no history

**Given** refresh throws and a usable cache remains
**When** recovery runs
**Then** chart/insights stay on cached data
**And** `StatusBanner` stale or info + retry — UX-DR2
**And** status is not silent `ready` with no signal

**Given** user taps retry
**When** `onTap` (existing `StatusBanner` callback) fires
**Then** History refresh runs again (non-silent or equivalent)

**Given** EN + FR arb
**When** story ships
**Then** new keys exist in both locales; collection stale >12h on Trends stays `—` (no new collection-stale banner)

**Out of scope:** new screen; About Semantics; Trends skeletons.

**Target files:** `history_state.dart`, `history_cubit.dart`, `history_screen.dart`, `status_banner.dart` (reuse), l10n, `test/presentation/cubits/history_*`  
**Source:** FR-R3 · UX-DR1 · UX-DR2 · UX-DR3

---

### Story 34-4: Batch active-bucket reads for Trends

As a **user**,
I want Trends to load 7d/30d buckets in one query,
So that the chart stays fast without changing what a day means.

**Acceptance Criteria:**

**Given** `HistoryCubit` today `Future.wait`s 30× `getActiveBucketsForLocalDay`
**When** this story ships
**Then** the contract adds `getActiveBucketsForLocalDays` (or equivalent) used by History
**And** each returned day uses the **same** per-row `LocalDayCalculator` + stored `zone_offset` as the 1-day path — NFR9
**And** SQL `date(start_time, zone_offset)` is forbidden; a UTC window may bound the query, Dart still filters by stored offset

**Given** mixed `zone_offset` rows (travel) and DST edges already covered by `step_repository_*`
**When** tests run
**Then** batch results **equal** N sequential `getActiveBucketsForLocalDay` calls for the same days
**And** kcal / derived metrics are unchanged (same buckets → same metrics)

**Given** KPI-01
**When** 90-day inject
**Then** chart query + render still < 100 ms — NFR1

**Out of scope:** `getTodaySteps` (34-5); schema; ingestion writer.

**Target files:** `step_aggregation_repository_contract.dart`, `step_aggregation_repository.dart`, `history_cubit.dart`, `test/data/repositories/step_repository_*`  
**Source:** FR-R4 · NFR9 · NFR1 · NFR-R2

---

### Story 34-5: getTodaySteps hot path without changing local-day truth

As a **user**,
I want today’s step total to stay correct if the query is sped up,
So that Today and notifications still match stored local days.

**Acceptance Criteria:**

**Given** `getTodaySteps` today loads rows then filters with `LocalDayCalculator` per row
**When** SQL/`GROUP BY` (or other aggregation) is introduced
**Then** it is **only** if that filter is preserved **or** proven equivalent on mixed offsets — NFR9 / NFR-R2
**And** finest-resolution total / no double-count rules are unchanged

**Given** `test/data/repositories/step_repository_today_test.dart`
**When** story closes
**Then** that file is the gate — must stay green; add cases if a SQL path is taken

**Given** no safe equivalent
**When** implementing
**Then** keep the Dart per-row filter; do not ship a “faster” query that drops `zone_offset`

**Out of scope:** schema; ingestion writer; Trends buckets (34-4).

**Target files:** `step_aggregation_repository.dart`, contract if needed, `step_repository_today_test.dart`  
**Source:** FR-R5 · NFR9 · NFR-R2 · NFR-R3

---

## Epic 35: Snappy My Data (optional)

My Data (and Profile if it still root-watches) rebuilds only the section that changed. Same export/import/purge/footprint actions.

**Priority:** P2 (structural debt) · **Version bump:** patch+1 + build+1 at epic close (mineur) · **Source:** `sprint-change-proposal-2026-08-31.md`

**FRs covered:** FR-R6, FR-R7

**Prerequisite:** Epic 34. Sequence locked: 35-1 then 35-2 (not in parallel). Rebuild reference: `today_screen.dart` (`BlocSelector` + view models).

### Story 35-1: Split MyDataCubit along existing test seams

As a **maintainer**,
I want export / import / purge / footprint extracted from `MyDataCubit`,
So that the cubit only orchestrates state and existing tests stay the gate.

**Acceptance Criteria:**

**Given** `my_data_cubit.dart` inlines CSV export, import, purge, and footprint refresh
**When** this story ships
**Then** each seam has a dedicated collaborator (controller/service) owned by presentation or data — not a new `lib/domain/`
**And** `MyDataCubit` remains the public API used by the screen, coordinator, and lifecycle ports: `exportAndShare`, `pickAndImport`, `confirmAndPurge`, `refresh`, goal/display-name updates

**Given** existing cubit tests (`my_data_cubit_export`, `_import`, `_purge`, `_field_log_export`, `_goal_refresh`)
**When** story closes
**Then** they stay green without rewriting scenarios; collaborators are injected so tests can still drive the cubit
**And** `flutter test --tags critical` is green

**Given** user-visible My Data behaviour
**When** export / import / purge / footprint refresh run
**Then** errors, success pending, and banners are unchanged

**Out of scope:** `BlocSelector` (35-2); goal ring / Today split; field-log export **must** stay working (existing test) even if folded into the export collaborator.

**Target files:** `my_data_cubit.dart`, new collaborator files next to cubit or `presentation/my_data/`, `app_dependencies.dart` / coordinator wiring, existing `test/presentation/cubits/my_data_cubit_*`  
**Source:** FR-R6 · D-22

---

### Story 35-2: BlocSelector on My Data (and Profile if still root-watch)

As a **user**,
I want My Data (and Profile) to redraw only the section that changed,
So that typing a goal or refreshing footprint does not rebuild the whole tab.

**Acceptance Criteria:**

**Given** `my_data_screen.dart` uses `context.watch<MyDataCubit>().state` at the root
**When** this story ships
**Then** sections use `BlocSelector` (or equivalent) on the slices they need — pattern = `today_screen.dart`
**And** footprint, background status, export/import/purge controls, and goal editor do not all rebuild on every emit

**Given** `profile_screen.dart` still `watch`es `ProfileCubit` at the content root (and `settings_screen.dart` if it still does)
**When** this story ships
**Then** those screens use selectors for the slices they display **or** a short note in the story file explains why Profile/Settings stay on `BlocBuilder`/`watch` (only if a selector would not cut rebuilds)

**Given** `test/presentation/screens/my_data_screen_test.dart` (+ profile screen tests if touched)
**When** story closes
**Then** the suite is green; no behaviour change to editors, banners, or navigation

**Depends on:** 35-1 (stable state slices after the split). **Not in parallel.**

**Out of scope:** Trends skeletons; `goal_ring` split; `RepaintBoundary` charts.

**Target files:** `my_data_screen.dart`, optionally `profile_screen.dart` / `settings_screen.dart`, screen tests  
**Source:** FR-R7
