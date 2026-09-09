---
stepsCompleted:
  - step-01-document-discovery
  - step-02-prd-analysis
  - step-03-epic-coverage-validation
  - step-04-ux-alignment
  - step-05-epic-quality-review
  - step-06-final-assessment
status: complete
date: 2026-08-31
project: astra-app
readiness: READY
filesIncluded:
  prd: _bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md
  prdCompanions:
    - _bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/addendum.md
    - _bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/reconcile-external-prd-v3.md
    - _bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/reconcile-market-research.md
    - _bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/reconcile-domain-research.md
    - _bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/reconcile-brainstorming.md
    - _bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/review-rubric.md
    - _bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/.decision-log.md
  architecture: _bmad-output/planning-artifacts/architecture.md
  epics: _bmad-output/planning-artifacts/epics.md
  ux: _bmad-output/planning-artifacts/ux-design-specification.md
excluded:
  - _bmad-output/planning-artifacts/EPIC-INDEX.md
  - _bmad-output/planning-artifacts/archive/**
---

# Implementation Readiness Assessment Report

**Date:** 2026-08-31
**Project:** astra-app

## Document Inventory (confirmed 2026-08-31)

| Type | File | Role |
|------|------|------|
| PRD | `prds/prd-astra-app-2026-05-22/prd.md` | Primary |
| PRD companions | `addendum.md`, reconcile-*, `review-rubric.md`, `.decision-log.md` | Folder coverage |
| Architecture | `architecture.md` | Primary |
| Epics & Stories | `epics.md` | Primary (AC source of truth) |
| UX | `ux-design-specification.md` | Primary |

**Excluded:** `EPIC-INDEX.md` (navigation only), `archive/**` (historical).

## PRD Analysis

**Source:** `prds/prd-astra-app-2026-05-22/prd.md` (final, updated 2026-06-04). Companions: `addendum.md` (technical DDL/lifecycle; no additional Phase 0 FRs). Reconcile/review/decision-log files are archived audit trail, superseded by `prd.md`.

### Functional Requirements

FR-1: The Hub App defines a **DataIngestionSource** interface that yields raw platform **StepReading** events plus source metadata. **StepNormalizer** is the only component that converts cumulative readings, resets, and rollovers into storage-ready step **Timeseries Samples**. Consequences: a new source can be registered without modifying SQLite write logic or duplicating step-delta logic; **PhonePedometerSource** and **AdpBleSource** stub both implement the interface.

FR-2: **PhonePedometerSource** reads step counts from the phone OS sensor APIs. **Android is the reference platform** for Phase 0 and Phase 1; iOS is secondary. Consequences: samples include `type=steps`, `unit=count`, `provider=internal_phone`, `device_id=smartphone`; ingestion respects platform permission flows (Health Connect deferred to Phase 1); when the OS step counter resets (reboot, rollover, or value lower than last read), ingestion computes a **delta** from the last known baseline without negative or corrupted totals; unit test covers at least one simulated reset scenario.

FR-3: An **AdpBleSource** class implements **DataIngestionSource** but returns no data in Phase 0. Consequences: stub is wired in DI/factory alongside **PhonePedometerSource**; documentation references ADP as Phase 1 activation point.

FR-4: **BackgroundCollector** receives normalized **Time Buckets** and writes them to SQLite without requiring the user to open the Hub App. Android: continuous or near-continuous bucket writes via WorkManager / FGS when OS permits. iOS: **no continuous 5-minute real-time collection** — **PhonePedometerSource** backfills on app foreground and rare `BGAppRefresh`. Consequences: Android beta primary — walk ≥500 steps over ≥30 min with app not in foreground (not force-stopped); within 15 min or on next open, Today's total increases by ≥80% of walked steps. Secondary: morning check after not opening since prior evening. Force-stop/OEM kill is a documented lag, not a beta failure. 24h without opening is SM-2 long-run only. Single writer path to **timeseries_samples**. iOS copy and My Data stale indicator reflect backfill model.

FR-5: **My Data** displays background collection status (last successful collection timestamp, stale-data warning when threshold exceeded). Consequences: stale warning is **12 hours** Android (A-4), **4 hours** iOS; copy does not blame the user; explains iOS backfill vs continuous collection.

FR-6: On Android 14+, background health collection uses the appropriate foreground service type (`health`) when required. Consequences: Manifest declares correct FGS type; no misuse of `dataSync` for health reads.

FR-7: The Hub persists **Timeseries Samples** in a `timeseries_samples` table with OW-aligned columns (id, start_time, end_time, type, value, unit, resolution, provider, device_id, zone_offset). Consequences: no raw sensor waveforms in any table; composite index supports type + start_time DESC queries for charts.

FR-8: Step samples are aggregated into **Time Buckets** of 5 minutes by default before insert. Consequences: consecutive samples for the same type do not exceed one row per 5-minute window per device; dev tooling can override bucket size for benchmarks.

FR-9: A `user_preferences` table stores at minimum `daily_step_goal` (integer), `theme_mode` (`system` | `light` | `dark`), and `accent_preset` (`orange` | `red` | `green` | `cyan` | `purple` | `pink`, default `orange`). Optional local-only: `display_name`, `height_cm`, `weight_kg`, `goal_notifications_enabled`. **No** age or sex/gender in Phase 0. Derived-metrics defaults: stride **0.76 m**; weight **70 kg**. Consequences: goal, theme, accent, and profile fields persist across restarts; default goal 8000 if skip (A-3); default `theme_mode` is `system`; `display_name` is **not** shown as a Today greeting in Phase 0 redesign (Profil only).

FR-10: Database schema changes use numbered migrations from project inception. Consequences: fresh install and upgrade from prior schema version both succeed without data loss in Phase 0 test matrix.

FR-11: **DataLifecycleService** applies resolution reduction: 0–30 days 5 min; 31–365 days 1 hour (12× five-minute → hourly); >365 days 1 day. Compaction is **destructive and irreversible** — finer-resolution source rows deleted after coarser aggregates written. Consequences: after simulated aging + lifecycle, row count drops predictably; downsampled rows carry updated `resolution`; pre-compaction export contains finer buckets, post-compaction does not.

FR-12: Database maintenance runs weekly when the platform permits. Android: scheduled background job. iOS: opportunistic after foreground/resume and optionally `BGAppRefresh`. No Phase 0 AC assumes reliable iOS background `VACUUM`. Consequences: file size does not grow unbounded after repeated purge/downsample cycles in 90-day inject test.

FR-13: **My Data** shows approximate database size, total sample count, and **last database optimization** timestamp (from FR-12). Consequences: footprint updates after inject, export, import, purge, and lifecycle; "Last optimized" displays relative time after at least one VACUUM run.

FR-14: **Today** displays: screen title **Today's activity**; circular **donut** of current day steps vs **daily_step_goal**; **Set goal** below the donut (integer 1,000–100,000); **This week** row of seven day pills (goal-met / missed / today / future); **Activity stats row** (kcal, distance, walking time) visible with placeholders (`—`) until FR-33. Consequences: donut fills proportionally, 100% at or above goal; daily total per §1.3 / NFR-9; **no** `Hello, {display_name}` greeting; Set goal persists `daily_step_goal` via `UserPreferencesRepository`.

FR-15: On first goal completion each calendar day, a subtle pulse/celebration animation plays. Consequences: at most once per local calendar day; no gamification score or streak shame messaging.

FR-16: **Trends** renders bar charts for 7-day and 30-day step totals with a goal reference line. Consequences: chart query + render completes in < 100 ms with 90 days of continuous injected data (KPI-01); user can switch 7-day and 30-day views.

FR-17: **Trends** shows a simple weekly trend (e.g., up/down vs prior week) derived from stored samples. Consequences: trend calculation uses only local SQLite; no network call.

FR-18: The Hub App performs **no outbound network requests** in the health data pipeline. Release/production: INTERNET permission **absent**. Debug: INTERNET permitted for Flutter/Dart VM tooling only. Consequences: release APK manifest has no INTERNET; `docs/DEPENDENCIES.md` lists zero network use in health pipeline and confirms notification stack is local-only (no FCM/Firebase/Mixpanel); 24-hour airplane mode beta checklist passes on **release** build.

FR-19: User can export **Timeseries Samples** to CSV with OW-aligned column headers. Export preserves the `id` column exactly so later imports can be idempotent. Consequences: file opens in standard spreadsheet tools; includes `id`, type, unit, resolution, timestamps, provider, device_id, `zone_offset`; CSV written to local cache/temp before OS share sheet; third-party share network is user-initiated outside ASTRA's health pipeline.

FR-20: User can delete **all** local **Timeseries Samples** and derived collection state from the **Data** tab. Purge preserves non-health setup preferences: `daily_step_goal`, `theme_mode`, `accent_preset`, profile fields (`display_name`, `height_cm`, `weight_kg`), `goal_notifications_enabled`, onboarding completion, permission choices. Consequences: post-purge sample count = 0, footprint ≈ 0 KB; explicit confirmation required; all ingestion sources purged equally; onboarding does not restart; daily goal unchanged.

FR-21: When user initiates purge, the Hub encourages export first (non-blocking). Consequences: confirmation dialog mentions export option; user can cancel purge.

FR-30: User can import a previously exported ASTRA CSV (same schema as FR-19) to repopulate **timeseries_samples** after reinstall, device migration, or post-purge recovery. Consequences: validates column headers; rejects malformed rows with user-visible error (no silent partial corruption); idempotent: preserve `id`, skip duplicate `id`, skip duplicate bucket identity if a malformed CSV reuses an existing bucket with a new id; round-trip: export → purge → import restores chart-visible history.

FR-31: User can choose **System**, **Light**, or **Dark** appearance from **Profil → Appearance**. Selection applies immediately app-wide (Today, Trends, Data, Profil, onboarding if shown). Consequences: stored in `user_preferences.theme_mode`; restored on cold start without incorrect theme flash; default `system` until user changes; OS theme change with `system` updates without restart; both light and dark token sets meet NFR-5 contrast baseline on all four tab surfaces.

FR-32: User selects one of six accent presets from **Profil → Appearance** via **bi-tone circular chips**. Selection applies immediately to ring, navigation, charts, and CTAs. Persisted in `user_preferences.accent_preset`. Default: `orange`. Consequences: chips re-render when `theme_mode` or OS theme changes under System; selected chip shows visible border/ring; six presets (orange, red, green, cyan, purple, pink) with light and dark token mappings.

FR-33: **Today** activity stats row displays **distance (km)**, **calories (kcal)**, and **walking duration** computed locally from today's step data, today's active time buckets, and optional profile height/weight. Until Epic 6 ships, row remains visible with placeholders (`—`). Formulas locked 2026-06-04: Distance = `todaySteps × stride_m / 1000` (`stride_m = (height_cm / 100) × 0.414` or 0.76 m); Walking time = sum of `(end_time − start_time)` for today's `type=steps` and `value>0`; Calories = `MET × weight_kg × (walking_seconds / 3600)` with MET = 3.5 (`weight_kg` or 70 kg). Distance uses same step count as donut (SQLite daily sum scaled by live overlay). Walking time and calories may lag until next ingestion cycle. Out of scope Phase 0: sex/gender, age, incline/speed, clinical calorie claims. Consequences: unit tests for defaults, custom height/weight, empty buckets, one active bucket; local data only; General Wellness copy.

FR-22: First launch presents local-only privacy explanation before requesting permissions. Consequences: no account, email, or authentication screen; permission requests occur after trust copy, not before.

FR-23: Onboarding collects **daily_step_goal** with set-once philosophy (editable later via **Set goal** on Today). Consequences: skipping goal setup applies default from FR-9.

FR-24: Onboarding offers optional local notification permission with explanation tied to goal-celebration use case. Consequences: Hub functions fully if notifications denied.

FR-25: When **BackgroundCollector** detects that cumulative daily steps (summed from **Timeseries Samples** for the current local calendar day) meet or exceed **daily_step_goal**, the Hub fires at most one local notification per calendar day. Consequences: goal evaluation uses local-day aggregation from SQLite, not a single bucket; no notification if permission denied; no spam on subsequent opens after goal already met.

FR-26: Application source code is published under **Apache License 2.0**. Consequences: `LICENSE` file present in repo root; README states Apache 2.0.

FR-27: Repo includes `docs/OPEN_WEARABLES_ALIGNMENT.md`, `docs/SERIES_TYPES.md`, `docs/DEPENDENCIES.md`, and `docs/REGULATORY_POSITION.md`. Consequences: OW alignment lists column mapping and Phase 0 series (`steps/count`); dependencies confirm zero network use in health pipeline on release builds, document debug INTERNET exception, audit `flutter_local_notifications` and background packages (no FCM/Firebase); regulatory doc states wellness-only boundary and CNIL local-only note.

FR-28: Developer tooling can inject 90 days of synthetic **Timeseries Samples** and simulate downsampling. Consequences: inject + lifecycle + chart render benchmark reproducible on CI or documented manual script; KPI-01 validated on injected dataset.

FR-29: Project maintains a documented beta checklist covering accuracy, background, notifications, footprint, export, airplane mode, and visual cohesion per §11. Consequences: checklist exists; items trace to FRs; visual cohesion references system-default theme, light/dark override, accent presets, four-tab shell; includes release-build airplane mode, CSV export→purge→import (FR-30), step-counter reset unit test (FR-2).

**Total FRs: 33** (FR-1–FR-29 contiguous; FR-30, FR-31, FR-32, FR-33 added by later amendments).

### Non-Functional Requirements

NFR-1: Chart render latency — < 100 ms (KPI-01).
NFR-2: Install artifact size — < 50 MB (KPI-04).
NFR-3: Offline operation — 100% core features without network.
NFR-4: Data at rest — Plaintext SQLite acceptable; SQLCipher Phase 1.
NFR-5: Accessibility — WCAG 2.1 AA aspirational for Phase 0; not blocking beta; contrast baseline in **both** light and dark themes.
NFR-6: Localization — English UI for Phase 0 OSS; French copy in README acceptable.
NFR-7: Storage budget (1 year) — SQLite DB < 50 MB with lifecycle active (steps-only).
NFR-8: Storage budget (5 years) — SQLite DB < 200 MB with lifecycle active (steps-only).
NFR-9: Time semantics — UTC storage; `zone_offset` preserved at ingestion; daily goals use stored offset per §1.3.

**Total NFRs: 9**

### Additional Requirements

**Success metrics:** SM-1 chart <100ms; SM-2 background persistence (Android primary); SM-3 airplane mode 24h; SM-4 builder learning outcome; SM-5 first launch to first step data <60s; SM-6 APK <50MB; SM-7 OSS credibility (checklist + GIF + 1 tester); SM-8 storage budget. Counter-metrics: SM-C1 do not optimize DAU; SM-C2 no screens beyond four-tab MVP + onboarding; SM-C3 no cloud convenience in Phase 0.

**Information architecture:** four tabs Today / Trends / Data / Profil + onboarding overlay; floating pill bottom bar; Phosphor icons.

**Canonical sample shape (§4.3.1):** `timeseries_samples` DDL with UUID id, UTC ISO timestamps, `value >= 0`, steps must be whole counts, `zone_offset` required.

**Constraints:** no account/cloud/analytics; General Wellness (no diagnose/treat/medical grade/HIPAA); solo builder; Apache 2.0 code; proprietary brand/keys.

**Assumptions A-1–A-20** including Android reference (A-2), default goal 8000 (A-3), stale 12h/4h (A-4), destructive downsampling (A-17), no historical re-bucketing on TZ change (A-16).

**Non-goals (Phase 0):** cloud/accounts, clinical claims, readiness scores, raw waveforms, SQLCipher, BLE/ADP, OW server, multi-device sync, social, official brand assets.

**Addendum (not extra Phase 0 FRs):** SQL DDL, lifecycle ratios, code-injector guardrails, Flutter package list, Phase 1+ SQLCipher/BLE/hardware preview.

**Open questions (deferred, non-blocking):** OQ-1 step accuracy ±; OQ-3 iOS TestFlight; OQ-6 CNIL legal review. OQ-2/4/5 resolved.

### PRD Completeness Assessment

PRD is **final** and Phase-0-complete: 33 numbered FRs with testable consequences, 9 NFRs with numeric targets, explicit non-goals, IA, and assumption index. Numbering is non-contiguous after FR-29 (FR-30–33 appended). Companion reconcile files are archived and must not be treated as specs. Stale inventory risk for downstream: epics inventory still describes some pre–2026-06-04 surfaces (History vs Trends, theme on My Data vs Profil, goal edit on My Data vs Today) even though later stories amended those locations.

## Epic Coverage Validation

**Source:** `epics.md` Requirements Inventory FR Coverage Map (FR1–FR31) + epic list (Epics 1–7, 34–35) + story AC for FR-32 / FR-33.

### Coverage Matrix

| FR | PRD requirement (short) | Epic coverage | Status |
|----|-------------------------|---------------|--------|
| FR-1 | DataIngestionSource + StepNormalizer | Epic 2 Story 2.2 | ✓ Covered |
| FR-2 | PhonePedometerSource + counter reset | Epic 2 Stories 2.2, 2.4; Epic 29 persist-path hardening | ✓ Covered |
| FR-3 | AdpBleSource stub | Epic 2 Story 2.2 | ✓ Covered |
| FR-4 | BackgroundCollector Android/iOS model | Epic 2 Stories 2.4, 2.8, 2.10 | ✓ Covered |
| FR-5 | My Data background status / stale | Epic 4 Story 4.2 | ✓ Covered |
| FR-6 | Android FGS `health` type | Epic 2 Story 2.8; Epic 9 FGS notification | ✓ Covered |
| FR-7 | timeseries_samples OW schema | Epic 2 Story 2.1 | ✓ Covered |
| FR-8 | 5-minute Time Buckets | Epic 2 Stories 2.1–2.3 | ✓ Covered |
| FR-9 | user_preferences (goal, theme, accent, profile) | Epic 1 Story 1.4; accent/profile via Epic 5 | ✓ Covered (inventory text stale vs PRD accent/height/weight) |
| FR-10 | Versioned schema migrations | Epic 2 Story 2.1 | ✓ Covered |
| FR-11 | Tiered downsampling | Epic 4 Story 4.1 | ✓ Covered |
| FR-12 | Weekly VACUUM | Epic 4 Story 4.1; Epic 30 isolate lock | ✓ Covered |
| FR-13 | Footprint + last optimized | Epic 4 Story 4.2 | ✓ Covered |
| FR-14 | Today donut, Set goal, week pills, stats placeholders | Epic 2 Story 2.5; Epic 5 Story 5.9; Epic 11 dashboard | ✓ Covered (inventory still describes old ring + source chip) |
| FR-15 | Once-per-day celebration | Epic 2 Story 2.6; Epic 5 Story 5.13 | ✓ Covered |
| FR-16 | Trends 7d/30d charts <100ms | Epic 3 Stories 3.2–3.4; Epic 12 analytics | ✓ Covered (inventory still says History) |
| FR-17 | Weekly trend indicator | Epic 3 Story 3.3 | ✓ Covered |
| FR-18 | No network / release no INTERNET | Epic 7 Story 7.2 | ✓ Covered |
| FR-19 | CSV export | Epic 4 Story 4.3 | ✓ Covered |
| FR-20 | Full health-data purge, prefs preserved | Epic 4 Story 4.5 | ✓ Covered |
| FR-21 | Export-before-purge | Epic 4 Story 4.5 | ✓ Covered |
| FR-22 | Trust-first onboarding | Epic 1 Story 1.5; Epic 13 redesign | ✓ Covered |
| FR-23 | Goal setup; later edit via Today Set goal | Epic 1 Story 1.5; Epic 2/5 Set goal; Story 4.6 historical My Data editor | ✓ Covered (inventory still says edit on My Data) |
| FR-24 | Notification opt-in | Epic 1 Story 1.5 | ✓ Covered |
| FR-25 | Daily goal local notification | Epic 2 Story 2.7 | ✓ Covered |
| FR-26 | Apache 2.0 | Epic 7 Story 7.1 | ✓ Covered |
| FR-27 | Docs bundle | Epic 7 Story 7.1 | ✓ Covered |
| FR-28 | Dev inject + lifecycle simulator | Epic 3 Story 3.1 | ✓ Covered |
| FR-29 | Beta checklist | Epic 7 Story 7.3 | ✓ Covered |
| FR-30 | CSV import idempotent | Epic 4 Story 4.4 | ✓ Covered |
| FR-31 | Theme System/Light/Dark on Profil | Epic 4 Story 4.7 (originally My Data); Epic 5/10 moved to Profil | ✓ Covered (inventory still says My Data) |
| FR-32 | Six accent presets, bi-tone chips on Profil | Epic 5 Stories 5.8, 5.11 | ✓ Covered — **absent from FR Coverage Map** |
| FR-33 | Derived kcal / distance / walking time | Epic 6 Story 6.1 | ✓ Covered — **absent from FR Coverage Map** |

### Missing Requirements

### Critical Missing FRs

None. Every PRD FR-1–FR-33 has a story implementation path.

### High Priority Missing FRs

None.

### Coverage-map / inventory gaps (not missing stories)

- **FR Coverage Map lists FR1–FR31 only.** FR-32 and FR-33 exist as stories (Epic 5, Epic 6) but are omitted from the map.
- **Epics inventory FR text is stale** vs 2026-06-04 PRD amendment: History vs Trends; theme/accent/goal-edit location (My Data vs Profil/Today); FR-9 missing `accent_preset` / height / weight; FR-14 still mentions source chip and Today greeting.
- **FRs in epics but not in PRD:** FR-R1–FR-R7 (Phase 0 reprise, Epics 34–35) — intentional, sourced from `sprint-change-proposal-2026-08-31.md`.
- **ID collision warning:** Data-audit Epics 29–33 cite `AUD2-FR*` and a local “FRs covered” list that reuses FR numbers with different meaning. Do not confuse with PRD FR-1–FR-33.

### Coverage Statistics

- Total PRD FRs: **33**
- FRs covered in epics (story path): **33**
- Coverage percentage: **100%**
- FR Coverage Map completeness: **31/33 (94%)** — map should be updated to include FR-32 → Epic 5 and FR-33 → Epic 6

## UX Alignment Assessment

### UX Document Status

**Found:** `_bmad-output/planning-artifacts/ux-design-specification.md` (complete 2026-05-25, amended 2026-06-04). Fast-pass: visual foundation, components, screen flows, accessibility. Scope header matches PRD four-tab shell (Today · Trends · Data · Profil + onboarding).

### Alignment Issues

**UX ↔ PRD (aligned)**

- Journeys UJ-1–UJ-4 map to FR-5/13–15/16–17/18–24/30–33.
- Four-tab IA, Data = sovereignty (export/import/purge/footprint/status), Profil = appearance + informations, Today = donut + Set goal + week pills + stats placeholders → FR-33.
- Theme System/Light/Dark (FR-31), six bi-tone accent presets (FR-32), offline fonts (FR-18), KPI-01 no-animation chart rebind (FR-16), GoalCelebration once/day (FR-15).
- Tone/regulatory copy matches General Wellness non-goals.

**UX internal inconsistency (Bloc 3 stale vs Bloc 1–2)**

Bloc 2 and header were amended 2026-06-04; **§3 wireframes were not**:

| Location | Still shows | Canonical (PRD + UX §1–2) |
|----------|-------------|---------------------------|
| §3.1 App map | 3 surfaces: Today / History / My Data; no Profil | 4 tabs + onboarding |
| §3.2 Today wireframe | SourceChip, 3-tab bar | SourceChip optional/deferred; Set goal + stats + week pills |
| §3.4–3.5 | Tab label History; goal editor + Appearance on My Data | Trends; goal on Today; appearance on Profil |
| §3.7 Goal step | “Change anytime in My Data” | Set goal on Today (UX §2.7, FR-23) |
| §5.2 traceability | FR-16/17 “History”; FR-31 on §2.5 Appearance | Trends; Profil → Appearance |
| V-4 | PROFILE | PROFIL |
| V-11 | Today compact stale **removed**, product TBD | PRD FR-5 requires status on My Data; Today compact is UX-only |

These are documentation drift, not missing product requirements — later epics (5, 10, 11, 13) already implemented the amended IA.

**UX ↔ Architecture (aligned for Phase 0 shell)**

Architecture amended 2026-06-04: D-10 four-tab floating pill; D-27 Phosphor; `ThemeCubit` + `accent_preset`; `ProfileCubit` / `HistoryCubit` (Trends); `AppScaffold`; `ChartDayAggregate` for NFR-1; widgets including `AccentPresetSelector`; tokens in `core/constants/`. KPI-01 and reduce-motion are architectural constraints, not UI-only.

**Architecture stack vs later epics (not UX blockers):** D-11 still names `fl_chart` / `share_plus`; Epics 17/20 later replaced those packages. Implementation has moved on; architecture text is stale for charts/export, not for UX support of FR-16/19.

**Epic 34 UX not in UX spec**

Reprise stories (FR-R3, UX-DR1–3) add Trends `StatusBanner` error/stale + retry. That pattern exists on Today/My Data in the UX spec; **Trends refresh-failure is only specified in `epics.md` / `sprint-change-proposal-2026-08-31.md`**, not in `ux-design-specification.md`.

### Warnings

1. **Do not implement from §3 wireframes** — they contradict the 2026-06-04 four-tab amendment. Use UX §1–2 + PRD §10 + later epic AC.
2. **UX spec not updated for Epic 34** — Trends failure/retry banners need a UX spec addendum or story-level AC as source of truth (already in epics).
3. **V-11 Today stale banner** is unresolved in the UX spec; PRD FR-5 is satisfied by My Data. Confirm product intent before any new Today stale work.
4. UX is implied and **present** — no missing-UX warning for a user-facing app.

## Epic Quality Review

**Scope of enforcement:** Epics 1–33 are `done` (shipped). Quality defects there are **historical**. Actionable review focuses on **Epics 34–35** (next implementation). Standards: user value, epic independence (N must not require N+1), no forward story deps, BDD ACs, tables created when needed, starter-template story for greenfield.

### Best-practices checklist (pending work)

| Epic | User value | Independent of later epic | Stories sized | No forward deps | Testable ACs | FR traceability |
|------|------------|---------------------------|---------------|-----------------|--------------|-----------------|
| 34 Honest Trends & layering | Partial (see 34-1/34-2) | Yes — does not need 35 | Yes | Yes (34-2 ← 34-1 only) | Yes | FR-R1–R5 |
| 35 Snappy My Data (optional) | Weak (perf/rebuild) | Requires 34 (backward OK) | Yes | Yes (35-2 ← 35-1) | Yes | FR-R6–R7 |

### Epic 34–35 story quality

- **34-3** is the user-value core (Trends failure visible + retry). Given/When/Then, cache vs empty, l10n, out-of-scope, target files, `flutter test --tags critical`.
- **34-4 / 34-5** are user-framed (speed without changing local-day truth) with explicit NFR-9 gates and “keep Dart filter if SQL is unsafe.” Independently completable; 34-5 does not wait on 34-4.
- **35-1 / 35-2** have locked sequence, existing tests as gate, no `lib/domain/`, behaviour-unchanged ACs.

Greenfield starter: Story 1.1 (`flutter create`) matches architecture. Not relevant to reprise.

Database timing: `timeseries_samples` created in Story 2.1 when first needed. Reprise stories forbid schema change (NFR-R1). Compliant.

### 🔴 Critical Violations

None that block Epic 34 implementation.

### 🟠 Major Issues

1. **Epic 34 mixes two concerns.** Title is half user (“Honest Trends”) half technical (“layering integrity”). Stories **34-1** and **34-2** are “As a **maintainer**” with zero user-visible increment. create-epics-and-stories would split them from 34-3. They are correctly sequenced (types → lifecycle ports) and 34-3 does not forward-depend on 34-4/34-5. **Accepted** if Baptiste keeps the SCP grouping; do not start 34-4 SQL before 34-3 user honesty unless he waives order (SCP says first story is types, not SQL).

2. **Epics 14–33 are mostly technical / audit epics** (refacto, WCAG retrofit, SQL locks, maintainer docs). They violate “technical epics are wrong.” **Historical — all `done`.** Do not use them as a template for new product epics.

3. **Epic 35 is optional structural debt** framed as user value (“redraw only the section that changed”). User cannot distinguish success without instrumentation. Treat as P2 after 34, not as a product epic.

### 🟡 Minor Concerns

1. **`epics.md` FR Coverage Map stops at FR-31** while FR-32/33 have stories — inventory hygiene.
2. **Inventory FR text stale** (History, My Data theme/goal) vs shipped IA.
3. **Duplicate Epic 1–4 story bodies** in `epics.md` (overview block then repeated full AC). Risk of editing the wrong copy.
4. **Epic 5 numbering** starts at 5.5 (5.1–5.4 never existed after polish rewrite).
5. **`sprint-status.yaml` `next_recommended`** still says “CE — append Epic 34–35 AC” though AC is already in `epics.md` (2026-08-31). Tracker lag.
6. **Maintainer stories already shipped** (32-5, 33-1, 33-2) same pattern as 34-1/34-2.

### Recommendations (quality)

- Implement **34-1 → 34-2 → 34-3** in that order (SCP). 34-4 and 34-5 may follow 34-3; they must not change NFR-9.
- Do not wait on UX spec rewrite or FR Coverage Map update to start 34-1.
- After 34 closes: bump `0.15.3+41`, set Epic 35 `ready-for-dev` or skip (optional).
- Optionally later: refresh Coverage Map + delete duplicate epic 1–4 block; update `next_recommended`.

## Summary and Recommendations

### Overall Readiness Status

**READY** — for implementation of **Epic 34** (then optional Epic 35). PRD FR-1–FR-33 have story paths (100%). Architecture supports the four-tab UX. Epics 34–35 ACs are specific, test-gated, and free of forward dependencies.

Planning artifacts have **hygiene debt** (stale UX §3 wireframes, incomplete FR map, tracker `next_recommended`). That debt does **not** block 34-1 if agents use `epics.md` story AC + `sprint-change-proposal-2026-08-31.md` as source of truth.

### Critical Issues Requiring Immediate Action

None.

### Recommended Next Steps

1. **Start Story 34-1** (`create-story` then `dev-story`) — relocate presentation-owned types out of cubit files; verify `core/` has zero `presentation/` imports; `flutter test --tags critical`.
2. **Ignore UX §3 wireframes** for any UI work; for 34-3 use story AC + existing `StatusBanner` (Today/My Data). Optional: one-paragraph UX spec addendum for Trends error/stale.
3. **Fix tracker after 34-1 is ready-for-dev:** `sprint-status.yaml` `next_recommended` (CE step is done). Coverage Map FR-32/FR-33 can wait for a docs pass.

### Final Note

This assessment identified **0 critical**, **3 major (1 actionable on 34 shape, 2 historical)**, and **6 minor** issues. Address nothing mandatory before 34-1. Proceed as-is with story AC as the contract.

**Assessor:** Implementation Readiness workflow (BMad)  
**Date:** 2026-08-31  
**Project:** astra-app (Phase 0 reprise, app `0.15.2+40`)
