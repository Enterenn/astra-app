---
stepsCompleted: [1, 2, 3, 4, 5, 6]
status: complete
completedAt: 2026-07-24
readinessStatus: READY_WITH_CONDITIONS
clarificationsAt: 2026-07-24
clarificationNotes: |
  31-2 onboarding conflict resolved: UX §3.7 Skip notifications = notification opt-in on superseded flow.
  Epic 13 (approved) governs intro→weight advance after deny. 31-2 reframed as retry/CTA UX, not block.
  Remaining condition: 32-3 privacy path (disclaimer vs SQLCipher).
scope: audits_2 Epics E29-E33
inputDocuments:
  - planning-artifacts/epics-audits-2.md
  - planning-artifacts/architecture.md
  - planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md
  - planning-artifacts/prds/prd-astra-app-2026-05-22/addendum.md
  - planning-artifacts/ux-design-specification.md
  - planning-artifacts/audits_2/README.md
referenceOnly:
  - planning-artifacts/epics-post-audit.md
excluded:
  - planning-artifacts/epics.md
  - planning-artifacts/epics-refacto.md
---

# Implementation Readiness Assessment Report

**Date:** 2026-07-24
**Project:** astra-app
**Scope:** audits_2 — Epics E29–E33 (`epics-audits-2.md`)

## Step 1 — Document Inventory

### PRD
- **Primary:** `prds/prd-astra-app-2026-05-22/prd.md` (53 KB, 2026-06-04)
- **Supplement:** `addendum.md` (NFR/privacy context)
- **Shard folder:** no duplicate whole at root

### Architecture
- **Primary:** `architecture.md` (57 KB, 2026-06-17)
- No sharded duplicate

### Epics & Stories
- **Active:** `epics-audits-2.md` (38 KB, 2026-07-24) — E29–E33, 22 stories, status `complete`
- **Reference:** `epics-post-audit.md` — numbering continuity E21–E28
- **Excluded:** `epics.md` (Phase 0), `epics-refacto.md` (historical)

### UX Design
- **Primary:** `ux-design-specification.md` (54 KB, 2026-06-05) — E31 permission UX

### Audit Source (findings, not PRD)
- `audits_2/` — 9 diagnostics + README (`0.12.1+31`)

### Issues Resolved
- Multiple epics files: scope limited to `epics-audits-2.md` for this assessment

---

## Step 2 — PRD Analysis

**Note:** This assessment scope is **audits_2 hardening** (AUD2-FR1–34), not full PRD re-implementation. PRD FR-1–FR-33 were delivered in Epics 1–28. Below: PRD requirements **directly touched or strengthened** by E29–E33.

### PRD Functional Requirements (in-scope traceability)

| PRD FR | Summary | audits_2 linkage |
|--------|---------|-------------------|
| FR-2 | Phone step ingestion + hardware reset unit test | E29 (29-1, 29-2, 29-5) — fixes gap vs PRD reset test intent |
| FR-4 | Background step persistence (Android WM, iOS backfill) | E29-3, E30-1/3/4 — atomic collect, maintenance lock, iOS doc |
| FR-7 | timeseries_samples storage + OW shape | E32-1 — ID collision fix for multi-type future |
| FR-8 | 5-minute Time Buckets | E29 — normalizer/drain integrity preserves bucket writes |
| FR-9 | User preferences (daily_step_goal) | E32-4 — single source via journal |
| FR-10 | Versioned migrations | E32-5 — TimeProvider in v3 |
| FR-11 | Tiered downsampling (destructive compaction) | E29-4 — insert-before-delete guard |
| FR-12 | Weekly DB maintenance | E30-1 — VACUUM lock vs collection |
| FR-22 | Trust-first onboarding + permissions | E31-2 — intro permission outcome UX (Epic 13–aligned) |
| FR-24 | Notification opt-in | E31-1, 31-6 |
| FR-25 | Daily goal notification | E31-3, 31-6 — init rethrow, toggle hardening |
| FR-28 | Dev data inject | E32-2 — release-safe guard |

**Out of scope for E29–E33 (already shipped):** FR-1, 3, 5–6, 13–21, 23, 26–27, 29–33.

### PRD Non-Functional Requirements (in-scope)

| PRD NFR | Summary | audits_2 linkage |
|---------|---------|-------------------|
| NFR-4 | Plaintext OK Phase 0; SQLCipher Phase 1 | E32-3 — disclaimer or encrypt (decision pending) |
| NFR-7 | 1-year DB < 50 MB | E29-4, E33 — compaction safety preserves lifecycle integrity |
| NFR-8 | 5-year DB < 200 MB | Same |
| NFR-9 | UTC + stored zone_offset | E33-1 — DST non-compaction documented; E29 preserves offset model |

### Additional PRD Constraints (relevant)

- **A-13:** iOS backfill-only — E30-3 documents gap (aligns FR-4)
- **A-17:** Destructive downsampling — E29-4 must not delete sources on failed insert
- **Single-writer rule** (FR-4) — E29-3 txn per source

### PRD Completeness Assessment

PRD is complete for Phase 0. audits_2 epics address **implementation gaps** discovered post-delivery (0.12.1+31), not missing PRD requirements. AUD2-FR inventory is the authoritative requirement set for this sprint.

---

## Step 3 — Epic Coverage Validation

### AUD2-FR Coverage (primary metric for this scope)

| Metric | Value |
|--------|-------|
| Total AUD2-FR | 34 |
| Covered in epics-audits-2.md | 34 |
| Coverage | **100%** |

All AUD2-FR1–34 map to E29–E33 per FR Coverage Map in `epics-audits-2.md`. AUD2-FR34 regression tests distributed across E29 (comptage) and E31-3 (notif rethrow).

### PRD ↔ Epic Coverage Matrix (in-scope PRD FRs only)

| PRD FR | Epic / Story | Status |
|--------|--------------|--------|
| FR-2 | E29-1, 29-2, 29-5 | ✓ Strengthens reset handling |
| FR-4 | E29-3, E30-1, 30-3, 30-4 | ✓ |
| FR-7 | E32-1 | ✓ |
| FR-8 | E29 (pipeline) | ✓ Implicit via integrity fixes |
| FR-9 | E32-4 | ✓ |
| FR-10 | E32-5 | ✓ |
| FR-11 | E29-4, E33-1 | ✓ |
| FR-12 | E30-1 | ✓ |
| FR-22 | E31-2 | ✓ Epic 13–aligned (retry/CTA, advance after deny OK) |
| FR-24/25 | E31-1, 31-3, 31-6 | ✓ |
| FR-28 | E32-2 | ✓ |

### Missing PRD Coverage (expected)

Full PRD FR-1–FR-33 **not** re-covered — intentional. Delivered in `epics.md` / `epics-post-audit.md`. No gap for this assessment scope.

### Extra Coverage (audit-only)

AUD2-FR5–6, 13, 20–23, 26–29, 31–32 extend beyond explicit PRD wording (hardening / doc / hygiene). Traceable to architecture NFR-4 and audit findings.

---

## Step 4 — UX Alignment Assessment

### UX Document Status

**Found:** `ux-design-specification.md`

### UX ↔ PRD ↔ Epics Alignment

| Area | UX Spec | Epics-audits-2 | Status |
|------|---------|----------------|--------|
| Today `no permission` | Dashed ring, CTA settings, non-blocking | E31-1, AUD2-UX2 | ✓ Aligned |
| Settings notifications | Toggle FR-24/25 | E31-1, 31-6, AUD2-UX1 | ✓ Aligned |
| Onboarding intro permission | Epic 13: advance after deny OK; retry/CTA on intro | E31-2 | ✓ **Resolved 2026-07-24** — UX §3.7 "Skip notifications" = notification opt-in on **superseded** flow (Trust/Permissions/Goal). Current flow: intro→weight→height. No activity skip in any valid spec. |
| My Data privacy footprint | Storage size display | E32-3 AUD2-UX4 adds encryption honesty | ✓ Extension (needed) |
| Trust copy before permission | FR-22 | E31-2 retry/settings | ✓ Compatible |

### UX ↔ Architecture Alignment

| Area | Architecture | Epics | Status |
|------|--------------|-------|--------|
| Today Display Truth Model | Live overlay ≠ persist path | E29 preserves; drain fix separate from UI | ✓ |
| SQLCipher Phase 1 path | Plaintext Phase 0 documented | E32-3 branches disclaimer vs encrypt | ✓ |
| BackgroundHealthCapabilityEvaluator | Centralized permission checks | E31-4 centralizes mapping — complements D-10 | ✓ |
| permission_handler ^12 | Documented | E31 stories target same stack | ✓ |

### Warnings

1. ~~**Onboarding skip vs block (E31-2)**~~ **Resolved:** Authority chain = Epic 13 / sprint-change-2026-06-17 > UX §3.7 (obsolete). Skip notifications ≠ skip activity. 31-2 unblocked.
2. **UX spec dated 2026-06-05** — §2.7/§3.7 onboarding superseded by Epic 13; edge-case §1001 (permission denied → Today dashed ring) still valid.

---

## Step 5 — Epic Quality Review

### Compliance Checklist (E29–E33)

| Criterion | Result |
|-----------|--------|
| Epics deliver user value | ✓ (E30/E33 slightly maintainer-facing — acceptable) |
| Epic independence | ✓ E31/E32 parallelizable after E29-1 |
| Story sizing | ✓ 22 stories, single-agent scope |
| No forward dependencies | ✓ 29-5 builds on 29-2; no Story N → N+2 skips |
| DB created when needed | ✓ Brownfield — no schema epic |
| Given/When/Then ACs | ✓ All stories |
| FR traceability | ✓ AUD2-FR refs in ACs |
| E29 atomic E-B bundle | ✓ Documented in epics + Do-not list |

### 🔴 Critical Violations

**None** — structure meets create-epics-and-stories standards.

### 🟠 Major Issues

1. **Open product decision — Story 32-3:** Plaintext disclaimer (default) vs SQLCipher Phase 1. Blocks E32 close.

~~2. Open product decision — Story 31-2~~ **Resolved 2026-07-24** (see Clarifications).

### 🟡 Minor Concerns

1. **E33 stories** are maintainer-oriented (doc/perf) — valid for "Maintainable Charts" epic goal.
2. **FR34 notification rethrow** only partially in E29 — correctly placed in E31-3.
3. **Line refs** in diagnostics anchored to 0.12.1+31 — re-verify at story dev if files shifted.

### Dependency Map (validated)

```
E29: 29-1 → 29-2 → 29-3 → 29-4 → 29-5 (atomic, in order)
E30: independent after E29 recommended
E31: parallel after 29-1; 31-2 unblocked (Epic 13 alignment)
E32: independent; 32-3 waits privacy decision
E33: last
```

---

## Step 6 — Summary and Recommendations

### Overall Readiness Status

**READY WITH CONDITIONS**

Implementation may proceed. **One product decision remains (32-3).** E29–E31 including 31-2 may start without it.

### Critical Issues Requiring Immediate Action

1. **Decide privacy at rest path (32-3):** Phase 0 plaintext disclaimer vs SQLCipher Phase 1 scope creep.

~~1. Decide onboarding activity permission gate (31-2)~~ **Done** — see § Clarifications below.

### Clarifications (2026-07-24)

**31-2 onboarding — false conflict resolved**

| Document | Says |
|----------|------|
| UX §3.7 wireframe | Step 2: "Allow activity" + ghost **"Skip notifications"** |
| Epic 13 / sprint-change 2026-06-17 (approved) | intro → weight → height; OS dialog on intro Continue; **advance after grant OR deny**; notifications → Settings (FR-24 amended) |
| Code (`onboarding_flow.dart`) | Matches Epic 13: `requestActivityPermission()` then `nextStep()` |

**Conclusion:** "Skip notifications" never meant skip activity. No valid spec provides activity skip on intro. AUD2-FR8 reframed: add retry/Settings UX on intro when denied; **do not block** advance to weight (Epic 13 AC). Today `no permission` state handles post-onboarding degradation (UX §1001).

### Recommended Next Steps

1. **`/bmad-create-story` 29-1** — start E29 atomic bundle (no blocker).
2. **Resolve 32-3** before story 32-3 only (disclaimer default OK for Phase 0).
3. **`/bmad-sprint-planning`** — tracker E29–E33.

### Final Note

Assessment found **1 remaining product decision (32-3)** and **0 critical structural defects**. 31-2 onboarding conflict was a false alarm — resolved via Epic 13 authority chain.

**Assessor:** BMad Implementation Readiness workflow  
**Report:** `implementation-readiness-report-2026-07-24.md`

