# Sprint Change Proposal — Epic 2 Passive Contract Correction

**Date:** 2026-06-02  
**Project:** astra-app  
**Author:** Correct Course workflow (Baptiste + Dev agent)  
**Status:** Approved  
**Scope classification:** Moderate

---

## Section 1: Issue Summary

### Problem statement

Epic 2 was marked **done**, but Android field testing after Epic 3 revealed a gap between the **product contract** (passive step accumulation) and **implementation reality** (foreground `LiveStepMonitor` as implicit primary path).

### Discovery context

- Field tests (2026-06-02): live foreground OK; app-switch resume OK; cold start / force-stop showed step regressions (e.g. 1273→1254 after threshold-based RAM persist).
- Spec `spec-step-lifecycle-hardening.md` addressed lifecycle bugs but exposed that passive collection (FGS + WorkManager per architecture) was not the dominant write path.
- Product alignment confirmed: user should **not** need the app open; real-time display while open is a **bonus**.

### Evidence

| Test | Result |
|------|--------|
| A — live foreground | OK |
| B — switch app → return | OK (after lifecycle fixes) |
| C — force-stop cold start | Mixed; RAM delta lost when `paused` skipped |
| Threshold persist (+5 steps) | **Regression** — visible backward jump |

---

## Section 2: Impact Analysis

### Epic impact

| Epic | Impact |
|------|--------|
| **Epic 2** | Reopened (`in-progress`); Stories 2-1–2-7 remain `done`; Stories **2.8–2.10** added |
| **Epic 3** | Formally closed (`done`) — all 4 stories complete |
| **Epic 4+** | **Paused** until Epic 2 correction complete; trust copy stays in 4.2 |
| **Epic 5** | Story 5.4 (overflow animation) unchanged — backlog |

### Story impact

- **No rollback** of Stories 2-1–2-7.
- **New:** 2.8 FGS passive pipeline, 2.9 Today truth model + live overlay, 2.10 WM/OEM hardening.
- **Implementation sequence:** 2.9 → 2.10 → 2.8.

### Artifact conflicts resolved

| Artifact | Change |
|----------|--------|
| **PRD FR-4** | Acceptance criteria shifted from 24h-off primary to same-day passive + morning check |
| **PRD SM-2** | Primary = FR-4 same-day; 24h = stress test |
| **epics.md** | FR4 summary, Story 2.4 AC, Epic 2 intro, Stories 2.8–2.10 |
| **architecture.md** | Today truth model, TodayCubit triggers, implementation gap note |
| **UX** | No change — trust copy deferred to Epic 4.2 |

### Technical impact

- Implement Android FGS health service (architecture already specified; code missing).
- Add `BackgroundHealthCapabilityEvaluator` (architecture D-23; not yet in codebase).
- Finalize lifecycle hardening in Story 2.9: **keep** monotonic/cold-start/resume fixes; **revert** threshold persist.
- iOS: backfill-only unchanged (no Apple test device).

---

## Section 3: Recommended Approach

### Selected path: **Option 1 — Direct Adjustment (Hybrid additive)**

Add Stories 2.8–2.10 within Epic 2; amend PRD/architecture acceptance criteria; do **not** rollback 2-1–2-7 or replan MVP.

### Rationale

- Architecture already defines FGS + WM; gap is implementation, not design.
- Live overlay is validated UX bonus — keep `LiveStepMonitor`.
- Daily-goal-oriented acceptance tests replace misleading 24h-off primary criterion.
- Moderate effort; avoids Epic 1–3 rework.

### Effort / risk / timeline

| Dimension | Assessment |
|-----------|------------|
| **Effort** | Medium — 3 stories, FGS is largest |
| **Risk** | Medium — OEM battery policies, FGS notification UX |
| **Timeline** | Epic 4+ paused; ~2–3 dev cycles for 2.9→2.10→2.8 |

### Options not selected

- **Rollback live pipeline:** Rejected — user wants real-time when app open.
- **MVP scope reduction:** Not needed — passive contract is core MVP, not deferrable.

---

## Section 4: Detailed Change Proposals (Approved Incremental)

All proposals #1–#6 approved 2026-06-02.

### PRD (`prd.md`)

- **FR-4 consequences:** Same-day passive (primary), morning check (secondary), force-stop documented limit, 24h stress only.
- **SM-2:** Primary = same-day FR-4; long-run 24h stress retained.

### Epics (`epics.md`)

- **FR4 one-liner** aligned with PRD.
- **Epic 2 intro** — passive + live overlay bonus.
- **Story 2.4 AC** — replaced 24h criterion with three Given/When/Then blocks.
- **Stories 2.8, 2.9, 2.10** — full AC added after Story 2.7.

### Architecture (`architecture.md`)

- **Today Display Truth Model** section added.
- **TodayCubit** refresh table updated.
- **Data flow** — parallel live overlay path documented.
- **Implementation status** note for FGS/evaluator gap.

### Sprint status (`sprint-status.yaml`)

- `epic-2: in-progress`
- Stories 2-8, 2-9, 2-10: `backlog`
- `epic-3: done`
- Pause note for Epic 4+

### Uncommitted code triage (Story 2.9 scope)

| Verdict | Items |
|---------|-------|
| **Keep** | Monotonic merge, `syncSteps`, cold-start order, `_persistOnPause`, `restart()`, buffer flush, tests |
| **Revert** | `onPersistRequested`, threshold persist (+5 steps / 2s debounce) |
| **Commit** | Deferred until Baptiste requests |

---

## Section 5: Implementation Handoff

### Scope: **Moderate**

Backlog reorganization + PRD/architecture amendments + 3 new stories. PO/DEV coordination for story creation and sequencing.

### Handoff recipients

| Role | Responsibility |
|------|----------------|
| **Developer (Amelia / bmad-quick-dev)** | Story 2.9 first — finalize truth model, revert threshold persist |
| **Developer** | Story 2.10 — `BackgroundHealthCapabilityEvaluator`, WM hardening |
| **Developer** | Story 2.8 — Android FGS health passive pipeline |
| **Baptiste** | Same-day field test protocol; approve commits when ready |

### Success criteria

- [ ] Walk ≥30 min app closed (not force-stop) → Today increases on open or ≤15 min
- [ ] App open → real-time step updates (live bonus)
- [ ] No visible backward jump within same local day
- [ ] FGS runs when app backgrounded (Story 2.8)
- [ ] `BackgroundHealthCapabilityEvaluator` operational (Story 2.10)

### Next steps

1. **Approve this proposal** (yes/no/revise)
2. `bmad-create-story` → `2-9-today-display-truth-model-and-live-overlay.md`
3. `bmad-quick-dev` → implement 2.9 (including threshold persist revert)
4. Repeat for 2.10, then 2.8
5. Field test FR-4 same-day protocol
6. Resume Epic 4 when Epic 2 returns to `done`

---

## Approval

| Decision | Name | Date |
|----------|------|------|
| Incremental proposals #1–#6 | Baptiste | 2026-06-02 |
| Full proposal | Baptiste | 2026-06-02 |
