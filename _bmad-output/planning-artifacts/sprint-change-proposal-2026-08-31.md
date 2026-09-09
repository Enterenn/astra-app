# Sprint Change Proposal — Phase 0 reprise (Epic 34+)

**Project:** astra-app  
**Author:** Correct Course workflow  
**Date:** 2026-08-31  
**Trigger:** Post-pause holistic audit `audits/phase0-reprise/audit-master-v0.15.2.md` (v `0.15.2+40`) + adversarial review  
**Status:** **Approved** (2026-08-31 — Baptiste)  
**Mode:** Batch  
**Scope:** Moderate — backlog reorganization (PO / CE → IR → SP)

**Handoff log (2026-08-31):** Routed to CE. Tracker: `epic-34` / `epic-35` = `backlog`. AC still missing from `epics.md` until CE. Do not start DS.

---

## 1. Issue Summary

Phase 0 is **closed** (Epics 1–33 done, `overall_status: complete`, app in production). Baptiste produced a reprise audit to restart development. The audit is a useful **signal**, not a CE-ready backlog:

- It labels the work **“E34+ (Phase 1 prep)”** while PRD/architecture **Phase 1** already means SQLCipher, BLE/ADP, Health Connect.
- Several “open / élevé” items are **already shipped** (Epic 31 `permanentlyDenied`, `_initializePlatform` rethrow, existing `AppCubitCoordinator`).
- Proposed SQL “fixes” drop the **local-day + `zone_offset`** filter (NFR-9 / PRD §1.3).
- Top item (`lib/domain/` + new coordinator) **contradicts architecture D-22** (pragmatic 3-layer, no domain folder) and duplicates a class that exists.

**Core problem:** restarting implementation from the audit matrix as written would mix Phase 1 product work, re-do shipped stories, and risk time-semantics regressions.

**Evidence:**

| Claim in audit | Code / artifact (2026-08-31) |
|----------------|------------------------------|
| Create `AppCubitCoordinator` | `lib/presentation/coordinators/app_cubit_coordinator.dart` already exists |
| Finish `permanentlyDenied` funnel | `PermissionRequestStatus.permanentlyDenied` + CTAs shipped (31-1, 31-2) |
| `_initializePlatform` swallows errors | `notification_service.dart` `rethrow` (31-3) |
| Introduce `lib/domain/` | Architecture **D-22**: no domain folder |
| SQL `GROUP BY` for `getTodaySteps` | Drops `LocalDayCalculator` + `zone_offset` filter in `step_aggregation_repository.dart` |
| Diagnostics 21–33 `complete` vs §2.5 `open` | Internal contradiction in the audit |

This is **not** a failed in-flight story. Same pattern as refacto → E14–20, post-refacto → E21–28, data-pipeline → E29–33: **new epics after a closed tranche**, sourced from a **scoped** audit.

---

## 2. Impact Analysis

### Epic impact

| Epic | Impact |
|------|--------|
| **1–33** | **No reopen.** Status stays `done`. |
| **Epic 34 (new)** | **Phase 0 reprise — layering + Trends truth + History errors.** Primary vehicle. |
| **Epic 35 (optional, new)** | **My Data cubit split + selective rebuilds.** Structural debt only; after 34. |
| Phase 1 product (SQLCipher / BLE / Health Connect) | **Out of scope.** Do not create those epics from this audit. |

No remaining planned epics to resequence. `sprint-status.yaml` `next_recommended` currently says “Phase 1 planning” — that line is **wrong for this tranche** and must be rewritten after approval.

### Story impact (proposed — CE writes AC)

**Epic 34 — Phase 0 reprise hardening** (version bump: **mineur** `patch+1` + `build+1` at epic close, e.g. `0.15.3+41`)

| Story | Title | In / notes |
|-------|--------|------------|
| **34.1** | Relocate presentation-owned types used by `core/` | Move `PermissionRequestStatus` off `onboarding_state.dart`; move `TrendsInsightAvailability` (and insight types `core/metrics` actually needs) off `history_state.dart`. **No `lib/domain/`.** |
| **34.2** | Lifecycle refresh without cubit imports | Port or callbacks on **existing** `AppCubitCoordinator`. Do not recreate the coordinator. Breaks cubit imports in lifecycle files. |
| **34.3** | History refresh failure is visible | `HistoryStatus.error` + stale/retry banner on Trends. Preserve cache-if-available. Align with `StatusBanner` patterns (Today/My Data). |
| **34.4** | Batch active-bucket reads for Trends | `getActiveBucketsForLocalDays` (or equivalent). **Must** keep `LocalDayCalculator` + stored `zone_offset` (same as per-day path). Contract + tests in `step_repository_*`. No semantic change to kcal/metrics. |
| **34.5** | `getTodaySteps` hot path without changing local-day truth | SQL/aggregation only if the Dart per-row local-day filter is preserved or proven equivalent. Existing `step_repository_today_test.dart` is the gate. |

**Epic 35 — optional, after 34** (bump: **mineur** at close)

| Story | Title | In / notes |
|-------|--------|------------|
| **35.1** | Split `MyDataCubit` along existing test seams | Export / import / purge / footprint already have dedicated tests. Cubit becomes an orchestrator. |
| **35.2** | `BlocSelector` on My Data (and Profile if still root-`watch`) | **After 35.1** — not in parallel. |

### Explicitly out of this proposal

| Audit item | Why dropped |
|------------|-------------|
| New `permanentlyDenied` funnel / `PermissionOutcome` enum | Shipped E31 |
| `_initializePlatform` swallow | Shipped 31-3 |
| New `AppCubitCoordinator` | Already exists |
| `lib/domain/` | Violates D-22 |
| Phase 1 SQLCipher / BLE / Health Connect | Different program; PRD addendum §4 |
| Split `goal_ring` / `today_screen` | Today is the rebuild **reference**; no user value |
| Empty-folder test gaps (`test/data/models/`, `test/l10n/`) | Folder ≠ coverage |
| RepaintBoundary / SQL index / goal_ring split | Profiler-first; not planned |
| Reopen post-refacto-02 boot latency, WM TTL vs VACUUM | No new measurement; do not reopen E21/E27/E30 |
| About `Semantics` + Trends skeletons as one story | Polish; defer unless CE finds a cheap 34.x leftover |

### Artifact conflicts

| Artifact | Conflict | Resolution |
|----------|----------|------------|
| **PRD** | None on FRs / MVP. Phase 0 already shipped. | **No PRD edit.** Do not treat this as Phase 1 Hub V1. |
| **architecture.md D-22** | Audit wants `lib/domain/`. | Keep D-22. Add a one-line clarification: shared types/ports live in `core/` (or `data/`), never a fourth layer. |
| **architecture.md Phase 1 deferred** | Tracker text says “Phase 1 planning”. | Unchanged deferred table. Tracker wording → “Phase 0 reprise (E34+)”. |
| **UX §2.4 / event table** | Trends column has **no** stale/error banner (`—`). History cubit fails silent. | Narrow add: Trends may show `StatusBanner` error/stale-refresh (retry). No new screen. |
| **epics.md** | Scope line: E1–33 complete; Phase 1+ out of scope. | Append E34 (+ E35 if approved). Add scope amendment. Do **not** new `*epic*.md`. |
| **EPIC-INDEX.md** | Ends at 33. | Add rows 34 / 35. |
| **sprint-status.yaml** | `complete` / next = Phase 1 planning. | After CE+SP: `in-progress`, E34 stories `backlog`. **Not in this CC file** until proposal approved + CE/SP run. |
| **audit-master-v0.15.2.md** | Matrix is unsafe as CE input. | CE source of truth = **this proposal**. After approval, mark audit items in/out in the audit (or README) so agents do not re-ingest the raw matrix. |
| **audits/manifest.yaml** | `phase0-reprise.epics: [34]` | Keep 34; add 35 if approved. |
| **AGENTS.md** | `next_recommended: Phase 1 planning` | Update to reprise E34+ after approval. |

### Technical impact

- Layering: compile-time import graph only. No schema, no ingestion writer change.
- 34.4 / 34.5: **query shape only**. Must not change NFR-9 day boundaries, double-count rules, or finest-resolution totals.
- 34.3: presentation + l10n keys EN/FR.
- Tests: `flutter test --tags critical` default; SQL stories must run `test/data/repositories/step_repository_today_test.dart` and chart/history cubit tests.
- iOS: no new background stack. Permission type move must keep `Platform.isIOS` sensor vs activity mapping.

---

## 3. Recommended Approach

**Selected: Option 1 — Direct Adjustment via new epics** (same as E14–33 audit campaigns).

| Option | Verdict |
|--------|---------|
| **1 Direct Adjustment** | **Chosen.** Append E34 (+ optional E35). Do not edit done stories 1–33. Effort **Medium**. Risk **Low** if SQL AC locks NFR-9. |
| **2 Rollback** | **Not viable.** Prod Phase 0; nothing to revert. |
| **3 PRD MVP Review** | **Not viable as primary.** MVP already delivered. Do not shrink Phase 0 and do not pull Phase 1 product into this sprint. |

**Rationale**

- Builder intent is “next sprint from the audit”, not a product pivot.
- Adversarial review showed the audit cannot drive CE unmodified.
- Architecture invariants (3-layer, local-day, single ingestion writer) stay.
- Optional E35 isolates a 2-day refactor from user-visible / query work.

**Timeline (solo, OK-commit gate):** E34 ~5–7 working days after CE/IR/SP. E35 ~2–3 days if taken.

**Risks**

| Risk | Mitigation |
|------|------------|
| CE copies audit SQL snippets | AC: local-day filter required; today/chart tests must stay green |
| Scope creep into Phase 1 | Explicit out-of-scope list; tracker wording |
| 34.2 + 34.1 collide | 34.1 types first, then 34.2 port |
| 35.2 before 35.1 | Sequence locked |

---

## 4. Detailed Change Proposals

### 4.1 PRD — no change

**Rationale:** No new FR. History/Trends error display is UX-level. Encryption/BLE remain addendum §4 (Phase 1).

### 4.2 Architecture

**Section:** Decision D-22 (and any “no domain folder” recap)

OLD:
```
D-22 | Layering model | Pragmatic 3-layer (core / data / presentation) — no artificial DDD domain folder
```

NEW:
```
D-22 | Layering model | Pragmatic 3-layer (core / data / presentation) — no artificial DDD domain folder.
     Shared types and ports used by core live in core/ (or data/), never lib/domain/.
     Presentation cubits must not be imported from core/; refresh orchestration stays on AppCubitCoordinator.
```

**Rationale:** Unblocks 34.1–34.2 without a fourth layer. Ratifies existing coordinator.

**Diagrams:** none.

### 4.3 UX

**Section:** §2.4 Trends Surface — add a failure row (new). Event table (Today / Trends / Data / Profil) — Trends column currently `—` for stale.

OLD (event table excerpt):
```
| Stale >12h | **compact** stale banner | — | **full** stale banner | — |
```

NEW:
```
| Stale >12h | **compact** stale banner | — | **full** stale banner | — |
| Trends refresh failed (no usable cache) | — | StatusBanner error + retry | — | — |
| Trends refresh failed (cache remains) | — | StatusBanner stale/info + retry; chart stays | — | — |
```

**Rationale:** Matches shipped Today/My Data honesty; closes silent History failure without a new journey.

### 4.4 Epics (`epics.md` only)

**Section:** frontmatter + Overview + Document map + **append** Epic 34 (and 35 if approved).

OLD (overview excerpt):
```
Scope: Epics 1–33 delivered … Phase 1+ (SQLCipher, BLE/ADP, Health Connect, wearable, sync hub) remains out of scope here
```

NEW (amendment block, do not delete E1–33):
```
Scope amendment (2026-08-31 — Sprint Change Proposal approved):
Epic 34 = Phase 0 reprise hardening after post-pause audit.
Source of truth for in/out = sprint-change-proposal-2026-08-31.md (not the raw audit matrix).
Phase 1 product (SQLCipher, BLE, Health Connect) still out of scope.
[Epic 35 = optional MyDataCubit split — include only if approved.]
```

Story AC: **CE workflow** (`bmad-create-epics-and-stories`) in a **fresh window**, input = this proposal + architecture D-22 + NFR-9. Do not paste audit “Après” SQL.

### 4.5 Other artifacts (after approval, not this commit unless listed)

| File | Change |
|------|--------|
| `EPIC-INDEX.md` | Rows 34 / 35 |
| `audits/phase0-reprise/README.md` + audit master statut | Tag items in-scope vs dropped vs already shipped |
| `audits/manifest.yaml` | `epics: [34]` or `[34, 35]` |
| `_bmad-output/AGENTS.md` | `next_recommended` → E34 reprise, not Phase 1 product |
| `sprint-status.yaml` | **After SP**, not in CC |

---

## 5. Implementation Handoff

**Change scope: Moderate** — backlog reorganization (new epics). Not a PRD rewrite (Major). Not a single-story tweak (Minor).

| Who | Does |
|-----|------|
| **Baptiste** | Approve / edit this proposal (this step). |
| **CE** (`bmad-create-epics-and-stories`) | Append E34 (+35) AC to `epics.md` only. Fresh window. |
| **IR** (`bmad-check-implementation-readiness`) | Gate before code. |
| **SP** (`bmad-sprint-planning`) | Regen `sprint-status.yaml`. |
| **CS → DS → CR** | Story cycle. OK-commit gate unchanged. |

**Do not** start `bmad-dev-story` or `bmad-quick-dev` from the audit file.

### Success criteria

1. `epics.md` contains E34 AC that preserve NFR-9 and D-22.
2. No `lib/domain/` in stories.
3. No Phase 1 product stories in this tranche.
4. Audit/README/manifest no longer list shipped E31 items as open work.
5. First ready story is 34.1 (types), not SQL.

### Next skills (fresh windows)

1. ~~Approve this proposal~~ **done 2026-08-31**  
2. `[CE]` create the epics and stories list — **next** (fresh window)  
3. `[IR]` check implementation readiness  
4. `[SP]` run sprint planning  
5. `[CS]` create the next story  

---

## Checklist record (Correct Course)

| ID | Item | Status |
|----|------|--------|
| 1.1 | Trigger | [x] Done — no in-flight story; campaign `phase0-reprise` + AR |
| 1.2 | Problem type | [x] Done — post-tranche planning signal; audit not CE-ready |
| 1.3 | Evidence | [x] Done — audit vs code table §1 |
| 2.1 | Current epic | [N/A] — Phase 0 complete, no active epic |
| 2.2 | Epic-level change | [x] Done — add 34 (+ optional 35); do not modify 1–33 |
| 2.3 | Remaining epics | [x] Done — none planned; do not spawn Phase 1 product epics |
| 2.4 | Invalidate / new | [x] Done — 1–33 stay valid; new 34/35 |
| 2.5 | Resequence | [N/A] — nothing left to reorder |
| 3.1 | PRD | [x] Done — no FR/MVP change |
| 3.2 | Architecture | [x] Done — D-22 clarification only |
| 3.3 | UX | [x] Done — Trends refresh failure banner |
| 3.4 | Other | [x] Done — audit, index, tracker, AGENTS |
| 4.1 | Direct adjustment | [x] Viable |
| 4.2 | Rollback | [x] Not viable |
| 4.3 | MVP review | [x] Not viable as primary |
| 4.4 | Selected path | [x] Done — Option 1 via new epics |
| 5.1–5.5 | Proposal sections | [x] Done — this document |
| 6.3–6.4 | Approval / tracker | [x] Done — approved 2026-08-31; epic-34/35 `backlog` in sprint-status |
