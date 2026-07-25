---
stepsCompleted:
  - step-01-document-discovery
  - step-02-prd-analysis
  - step-03-epic-coverage-validation
  - step-04-ux-alignment
  - step-05-epic-quality-review
  - step-06-final-assessment
assessor: BMad Implementation Readiness workflow
project: astra-app
assessmentDate: 2026-06-02
documentsIncluded:
  prd:
    - prds/prd-astra-app-2026-05-22/prd.md
    - prds/prd-astra-app-2026-05-22/addendum.md
  architecture:
    - architecture.md
  epics:
    - epics.md
  ux:
    - ux-design-specification.md
documentsExcluded:
  - implementation-readiness-report-2026-05-25.md
  - research/*.md
  - prds/prd-astra-app-2026-05-22/reconcile-*.md
  - sprint-change-proposal-2026-06-02.md
  - background-trust-and-movement-validation.md
---

# Implementation Readiness Assessment Report

**Date:** 2026-06-02
**Project:** astra-app

## Document Inventory (Step 1)

| Type | Path | Size | Modified |
|------|------|------|----------|
| PRD (primary) | `prds/prd-astra-app-2026-05-22/prd.md` | 47.0 KB | 2026-06-02 |
| PRD (addendum) | `prds/prd-astra-app-2026-05-22/addendum.md` | 9.7 KB | 2026-05-22 |
| Architecture | `architecture.md` | 55.3 KB | 2026-06-02 |
| Epics | `epics.md` | 57.7 KB | 2026-06-02 |
| UX | `ux-design-specification.md` | 48.9 KB | 2026-05-25 |

**Duplicates (whole + sharded):** None identified.

**Missing required types:** None.

---

## PRD Analysis (Step 2)

### Functional Requirements

FR-1: **DataIngestionSource** interface — raw **StepReading** events + metadata; **StepNormalizer** sole converter to **Timeseries Samples**; **PhonePedometerSource** and **AdpBleSource** stub implement interface.

FR-2: **PhonePedometerSource** — OS step APIs (Android reference); samples `type=steps`, `unit=count`, `provider=internal_phone`, `device_id=smartphone`; permission flows; hardware counter reset via delta baseline (unit test required).

FR-3: **AdpBleSource** stub — implements interface, no data Phase 0; wired in DI; ADP documented as Phase 1.

FR-4: **BackgroundCollector** writes normalized **Time Buckets** to SQLite without opening app; Android continuous/near-continuous via WorkManager/FGS; iOS backfill only; Android beta acceptance (same-day passive + morning check); single writer; honest iOS stale UI.

FR-5: **My Data** background status — last collection time + stale warning (12h Android, 4h iOS); non-blaming copy.

FR-6: Android 14+ FGS type `health` when required; manifest correct; no `dataSync` misuse.

FR-7: **timeseries_samples** OW-aligned columns; no raw waveforms; composite index `type + start_time DESC`.

FR-8: Default **5-minute Time Buckets**; one row per window per device; dev override for benchmarks.

FR-9: **user_preferences** — `daily_step_goal`, `theme_mode` (`system`|`light`|`dark`); persist across restarts; defaults 8000 steps and `system` theme.

FR-10: Numbered schema migrations; fresh install + upgrade without data loss.

FR-11: **DataLifecycleService** tiered downsampling (5min → 1h → 1d); destructive irreversible compaction.

FR-12: Weekly DB maintenance (Android scheduled; iOS opportunistic); bounded growth in 90-day inject test.

FR-13: **My Data** footprint — DB size, sample count, last optimization (relative time after VACUUM).

FR-14: **Today** goal ring vs **daily_step_goal**; UTC + `zone_offset` aggregation; source label.

FR-15: Once-per-local-day goal celebration animation; no gamification/shame.

FR-16: **History** 7d/30d bar charts + goal line; render < 100 ms with 90-day inject (KPI-01).

FR-17: **History** weekly trend from local SQLite only.

FR-18: No outbound network in health pipeline; release builds without INTERNET; debug exception for Flutter tooling only; `DEPENDENCIES.md` audit.

FR-19: CSV export OW-aligned columns; preserve `id`; write to cache before share sheet.

FR-20: Full health-data purge; preserve setup prefs; explicit confirmation; sample count zero after.

FR-21: Export-before-purge nudge (non-blocking) in confirmation dialog.

FR-22: Trust-first onboarding before permissions; no account/auth.

FR-23: Onboarding **daily_step_goal** (set-once; editable later on My Data).

FR-24: Optional notification opt-in; app fully functional if denied.

FR-25: At most one local goal notification per calendar day from **BackgroundCollector** aggregation.

FR-26: Apache 2.0 — `LICENSE` + README statement.

FR-27: Docs bundle — `OPEN_WEARABLES_ALIGNMENT.md`, `SERIES_TYPES.md`, `DEPENDENCIES.md`, `REGULATORY_POSITION.md`.

FR-28: Dev inject 90-day synthetic data + lifecycle simulation; KPI-01 reproducible.

FR-29: Beta checklist tracing FRs, themes, airplane mode, CSV round-trip, reset unit test.

FR-30: CSV import — validate headers, idempotent `id`, round-trip export→purge→import.

FR-31: **System/Light/Dark** theme on **My Data**; immediate app-wide; no cold-start flash; OS theme follow when `system`.

**Total FRs: 31**

### Non-Functional Requirements

NFR-1: Chart render latency < 100 ms (KPI-01).

NFR-2: Install artifact < 50 MB (KPI-04).

NFR-3: 100% core features offline.

NFR-4: Plaintext SQLite Phase 0; SQLCipher Phase 1.

NFR-5: WCAG 2.1 AA aspirational; contrast baseline in light and dark.

NFR-6: English UI Phase 0; i18n-ready structure.

NFR-7: Storage < 50 MB at 1 year (lifecycle active, steps-only).

NFR-8: Storage < 200 MB at 5 years (lifecycle active, steps-only).

NFR-9: UTC timestamps; immutable per-row `zone_offset`; local-day aggregation per §1.3.

**Total NFRs: 9**

### Additional Requirements

- **Product principles** (§1.1): proof over promises, local-first, no account, calm UX, data minimization, transparency, background autonomy, user ownership, My Data first-class.
- **Time semantics** (§1.3) and **data ownership** (§1.4) — canonical sample shape §4.3.1 / addendum §2.
- **Success metrics** SM-1 through SM-8 and counter-metrics SM-C1–C3.
- **Constraints:** General Wellness only; no clinical claims; solo-builder scope; OSS Apache 2.0.
- **Addendum:** SQLite DDL, lifecycle detail, code-injector guardrails (§9), Phase 1+ preview (SQLCipher, BLE, wearable).
- **Assumptions A-1 through A-14** indexed in PRD §16.

### PRD Completeness Assessment

The PRD is **mature and implementation-ready** for Phase 0: globally numbered FRs with testable consequences, explicit Android/iOS platform split, NFR table, non-goals, and scope tables. Recent FR-4/SM-2 amendments (same-day passive acceptance) align with sprint change proposal 2026-06-02. Open questions (§15) are explicitly deferred and do not block Epic 4+.

---

## Epic Coverage Validation (Step 3)

### Epic FR Coverage Extracted

| FR | Epic |
|----|------|
| FR1–FR4, FR6–FR8, FR10, FR14–FR15, FR25 | Epic 2 |
| FR5, FR11–FR13, FR19–FR21, FR23, FR30–FR31 | Epic 4 |
| FR9, FR22–FR24 | Epic 1 |
| FR16–FR17, FR28 | Epic 3 |
| FR18, FR26–FR27, FR29 | Epic 7 |

**Total FRs in epics map: 31 / 31**

### Coverage Matrix (summary)

| FR | PRD (short) | Epic coverage | Status |
|----|-------------|---------------|--------|
| FR-1 … FR-31 | See PRD Analysis | Epics 1–4, 6 per map above | ✓ Covered |
| — | — | Epic 5 (design polish) | NFR-5 only (no new FRs) |

### Missing Requirements

**None.** Every PRD FR has an explicit epic assignment in `epics.md` §FR Coverage Map.

### Coverage Statistics

- Total PRD FRs: **31**
- FRs covered in epics: **31**
- Coverage percentage: **100%**

**Note:** Implementation sprint has completed Epics 1–3 (including corrective Stories 2.8–2.10). Epics 4–6 remain in backlog per `sprint-status.yaml`.

---

## UX Alignment Assessment (Step 4)

### UX Document Status

**Found:** `_bmad-output/planning-artifacts/ux-design-specification.md` (48.9 KB, updated 2026-05-25).

### UX ↔ PRD Alignment

| Area | Alignment |
|------|-----------|
| Three surfaces (Today, History, My Data) + onboarding | ✓ Matches PRD §10 IA and UJ-1–UJ-4 |
| Trust-first onboarding (FR-22–24) | ✓ §3.7 flows |
| Goal ring + celebration (FR-14–15) | ✓ §2.3, §3.3 |
| History charts + trend (FR-16–17) | ✓ §2.4, §3.4 |
| Sovereignty flows (FR-19–21, FR-30) | ✓ §3.9–3.11 |
| Theme System/Light/Dark (FR-31) | ✓ §1.1–1.2, §2.2 ThemeSelector |
| Stale background UX (FR-5) | ✓ §3.6 |
| Visual beta checklist (FR-29) | ✓ §4.7 V-1–V-13 |

**Gap (minor):** UX §5.2 traceability table omits **FR-25** (daily goal notification) and **FR-18** (release network policy) — both are system-level; notification uses platform UI, FR-18 is build/manifest concern. Acceptable but worth a one-line UX note for notification permission copy consistency with FR-24.

### UX ↔ Architecture Alignment

| UX requirement | Architecture support |
|----------------|---------------------|
| 3-tab `NavigationBar` | D-10, `AppScaffold`, no GoRouter Phase 0 |
| Theme system default + override | `ThemeCubit`, `AstraColors`, FR-31 |
| Chart performance KPI-01 | `ChartDayAggregate`, `LocalDayCalculator`, benchmark harness |
| Goal celebration + reduce motion | FR-15, semantics per UX §4.3 |
| CSV export/import/purge flows | Repository transactions, cache-then-share |
| Stale thresholds 12h/4h | Architecture + FR-5 aligned |

### Warnings

1. **UX spec date (2026-05-25) lags epics amendment (2026-06-02):** Epic 5/6 reorder and Story **5.4** (goal overflow animation polish) are in `epics.md` but not reflected in UX §5.2 or component inventory — refresh UX when starting Epic 5.
2. **`sprint-change-proposal-2026-06-02.md` excluded** from this run but already applied to PRD/architecture/epics; UX correctly deferred trust copy to Epic 4.2 — no conflict.

---

## Epic Quality Review (Step 5)

### Epic Structure Validation

| Epic | User value? | Independence | Verdict |
|------|-------------|--------------|---------|
| 1 Trust Onboarding & Shell | ✓ | Standalone | Pass |
| 2 Passive Step Tracking & Today | ✓ | Needs Epic 1 shell/prefs | Pass |
| 3 History & Trends | ✓ | Needs Epic 2 data | Pass |
| 4 Data Sovereignty (My Data) | ✓ | Needs Epics 1–2 (data + shell) | Pass |
| 5 Design Polish | ✓ | After functional surfaces | Pass (sequenced, not forward-dep) |
| 6 OSS & Beta Readiness | ✓ | Can parallel late Phase 0 | Pass |

No **technical-milestone-only** epics. Epic 1 Story 1.1 is builder-scaffold framed with user outcome; acceptable for greenfield Flutter.

### Dependency Analysis

- **Within-epic ordering** is logical (schema → ingestion → background → UI).
- **Story 3.1** references downsampling as dev preview of Epic 4 service — documented, not a blocking forward dependency.
- **Story 2.10** defers My Data copy to Epic 4.2 — explicit, correct.
- **Story 4.7** defers contrast polish to Epic 5 — explicit AC, avoids blocking FR-31 functional delivery.
- **No circular epic dependencies** identified.

### Best Practices Compliance

| Check | Result |
|-------|--------|
| Epic delivers user value | ✓ All 6 |
| Epic independence (no Epic N needs N+1) | ✓ |
| Stories appropriately sized | ✓ |
| No forward dependencies (undocumented) | ✓ |
| DB tables when needed | ✓ (Story 2.1 creates timeseries; not all upfront) |
| BDD-style acceptance criteria | ✓ Predominantly Given/When/Then |
| FR traceability | ✓ Coverage map + story refs |

### Quality Findings by Severity

#### 🔴 Critical Violations

**None.**

#### 🟠 Major Issues

1. **NFR explicit mapping:** FR Coverage Map lists FRs only; NFR1–NFR4, NFR6–NFR9 are in Requirements Inventory but not in the epic map table — coverage is implicit via stories (e.g. 3.4 for NFR-1). Recommend adding an **NFR Coverage Map** row for auditability before Epic 7.

#### 🟡 Minor Concerns

1. **FR-23 split** across Epic 1 (onboarding) and Epic 4 (My Data editor) — intentional; ensure Story 4.6 AC references FR-23 edit path.
2. **FR-26 LICENSE** appears in Story 1.1 AC and Epic 7 — duplicate traceability is fine; Epic 7 remains source of truth for OSS gate.
3. **Epic 5 Story 5.4** (overflow animation) added post-UX-spec — sync UX before implementation.

---

## Summary and Recommendations (Step 6)

### Overall Readiness Status

**READY** — Planning artifacts for Phase 0 are complete, aligned, and fully traceable. Epics 1–3 are **implemented**; Epics 4–6 are ready to execute from a requirements perspective.

This assessment validates **artifact readiness**, not runtime beta readiness (Epic 7 checklist still pending).

### Critical Issues Requiring Immediate Action

**None** for PRD ↔ UX ↔ Architecture ↔ Epics alignment.

### Recommended Next Steps

1. **Resume Epic 4** per `sprint-status.yaml` (pause lifted after Epic 2 correction — now complete): start with Story 4.1 Data Lifecycle Service.
2. **Refresh UX spec** §5.2 and component inventory for Epic 5 reorder + Story 5.4 before design polish sprint.
3. **Add NFR Coverage Map** to `epics.md` (one table, 9 rows) before Epic 7 beta hardening.
4. **Optional:** Include `sprint-change-proposal-2026-06-02.md` in future readiness runs when validating post–correct-course state.

### Issue Count Summary

| Category | Count |
|----------|-------|
| Critical | 0 |
| Major | 1 |
| Minor | 3 |
| Missing FR coverage | 0 |

### Final Note

This assessment identified **4 non-blocking issues** across traceability hygiene and document freshness. Planning is sound to proceed with **Epic 4: Data Sovereignty & Lifecycle** without replanning the MVP. Address UX/NFR map updates in parallel with Epic 4–5 execution.
