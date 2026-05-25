---
status: archived
supersededBy: prd.md (2026-05-25) + implementation-readiness-report-2026-05-25.md
purpose: PRD input-reconciliation audit trail — not an implementation spec
---

# Input Reconciliation — External PRD v3.0 (French)

**Input:** User-provided inline document (May 2026)

## Coverage summary

**Captured in prd.md:** Vision, local-first/no-cloud/no-account, non-medical boundary, KPI-01/03/04 as SMs, Phase 0 sandbox intent, 3-surface MVP (expanded from external), non-goals, risks register (subset).

**Captured in addendum.md:** Hardware MCU/sensors/battery, firmware HAL stack, ADP reconciliation protocol, SQL DDL, downsampling tiers, code injector guardrails, full execution matrix Phases 0–4, Flutter packages.

**Overrides applied (documented in decision log):**
| External PRD | BMAD PRD |
|--------------|----------|
| Binôme Designer+Dev | Solo builder |
| `health_events` / 1-min buckets | `timeseries_samples` / 5-min buckets |
| MIT (brainstorming) | Apache 2.0 |
| SQLCipher Phase 0 | Phase 1 |
| V2 OW export | V2 ASTRA sync hub |
| KPI-02 battery 5–7 days | Hardware Phase 2+ (addendum only) |

**Gaps:**
1. **KPI-02 (wearable battery)** — not in Phase 0 SMs; correctly deferred to hardware phases.
2. **BIP39 recovery phrase** — Phase 1 in scope table; external PRD §10.3 captured in risks/addendum.
3. **Phase 0 exit "UI de base + KPI-01"** — BMAD adds beta checklist, OSS, learning SM-4 (superset).
