# BMAD — astra-app planning & implementation

Planning and delivery artifacts for **ASTRA Phase 0**. Generated with the [BMad Method](https://docs.bmad-method.org/).

**Agents:** [`AGENTS.md`](./AGENTS.md) · **Humans:** this file

**Status (2026-07-25):** Epics **1–33 complete** · app `0.15.2+40` · no active stories. Next work = Phase 1 planning.

---

## New here? Read in this order

| # | Document | Why |
|---|----------|-----|
| 1 | [`docs/project-context.md`](../docs/project-context.md) | Dev workflow, commit gate, test commands *(mandatory)* |
| 2 | [PRD](./planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md) | What the app must do (31 FRs, 9 NFRs) |
| 3 | [Architecture](./planning-artifacts/architecture.md) | Technical decisions, module layout |
| 4 | [UX specification](./planning-artifacts/ux-design-specification.md) | Screens, tokens, flows |
| 5 | [Epic index](./planning-artifacts/EPIC-INDEX.md) | All 33 epics at a glance |
| 6 | [Epics & stories](./planning-artifacts/epics.md) | Acceptance criteria Epics 1–33 |
| 7 | [Sprint tracker](./implementation-artifacts/sprint-status.yaml) | Story status (consolidated) |

Then browse [`stories/`](./implementation-artifacts/stories/) for per-story context when touching a specific area.

---

## Delivery timeline

Four sequential passes — all **done**:

```
Phase 0 (E1–13)     OSS beta · core app · nav redesign · onboarding
    ↓
Refacto (E14–20)    perf · i18n · architecture split · custom charts
    ↓
Post-audit (E21–28) cold start · a11y · boot polish · UX coherence
    ↓
Data audit (E29–33) persist integrity · SQLite concurrency · permissions
```

| Phase | Epics | Source |
|-------|-------|--------|
| **All phases** | 1–33 | [epics.md](./planning-artifacts/epics.md) (single file) |

Phase sections inside `epics.md`: Phase 0 (1–13) · Refacto (14–20) · Post-audit (21–28) · Data audit (29–33).

Audit diagnostics: [audits/](./planning-artifacts/audits/README.md) (post-refacto · data-pipeline)

Per-phase snapshots (pre-merge): [`archive/epics/`](./planning-artifacts/archive/epics/)

---

## Key artifacts

### Specifications (source of truth)

| Document | Contents |
|----------|----------|
| [PRD](./planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md) | Functional requirements, user journeys, scope |
| [Technical addendum](./planning-artifacts/prds/prd-astra-app-2026-05-22/addendum.md) | SQL DDL, ADP/firmware (future phases) |
| [Architecture](./planning-artifacts/architecture.md) | Patterns, platform model, module structure |
| [Background trust & GPS guardrails](./planning-artifacts/background-trust-and-movement-validation.md) | Alive vs killed, catch-up layers |
| [UX specification](./planning-artifacts/ux-design-specification.md) | Tokens, screens, accessibility |
| [Decision log](./planning-artifacts/prds/prd-astra-app-2026-05-22/.decision-log.md) | Product decision journal |

### Implementation tracking

| Artifact | Purpose |
|----------|---------|
| [epics.md](./planning-artifacts/epics.md) | Acceptance criteria — **Epics 1–33** (single file) |
| [sprint-status.yaml](./implementation-artifacts/sprint-status.yaml) | **Single tracker** — Epics 1–33, all stories |
| [stories/](./implementation-artifacts/stories/) | Per-story context (AC, code map, review notes) |
| [deferred-work.md](./implementation-artifacts/deferred-work.md) | Cross-story deferrals and field feedback |
| [kpi-01-regression-log.md](./implementation-artifacts/kpi-01-regression-log.md) | Chart performance benchmark log |

### Readiness gate (latest)

[implementation-readiness-report-2026-07-24.md](./planning-artifacts/implementation-readiness-report-2026-07-24.md) — alignment verdict before data-pipeline audit (Epics 29–33).

Earlier readiness reports: [`archive/readiness/`](./planning-artifacts/archive/readiness/)

---

## OSS contributor docs

These live under [`docs/`](../docs/README.md) (not in `_bmad-output/`):

- [OPEN_WEARABLES_ALIGNMENT.md](../docs/OPEN_WEARABLES_ALIGNMENT.md)
- [SERIES_TYPES.md](../docs/SERIES_TYPES.md)
- [DEPENDENCIES.md](../docs/DEPENDENCIES.md)
- [REGULATORY_POSITION.md](../docs/REGULATORY_POSITION.md)
- [BETA_CHECKLIST.md](../docs/BETA_CHECKLIST.md)

---

## Research & historical archive

| Location | Contents |
|----------|----------|
| [brainstorming/](./brainstorming/) | Phase 0 ideation session |
| [planning-artifacts/research/](./planning-artifacts/research/) | Market & domain research |
| [planning-artifacts/archive/](./planning-artifacts/archive/) | Superseded readiness, change proposals, epic snapshots |
| [implementation-artifacts/archive/](./implementation-artifacts/archive/) | Per-phase sprint snapshots, delivered ad-hoc specs |
| [prds/.../reconcile-*.md](./planning-artifacts/prds/prd-astra-app-2026-05-22/) | PRD authoring audit trail (not implementation specs) |

---

## Folder layout

```
_bmad-output/
├── AGENTS.md                 ← BMAD / Cursor machine entry
├── README.md                 ← human hub
├── planning-artifacts/
│   ├── epics.md              ← acceptance criteria Epics 1–33
│   ├── EPIC-INDEX.md         ← epic lookup table
│   ├── architecture.md, ux-design-specification.md, …
│   ├── audits/               ← code audit diagnostics (post-refacto + data-pipeline)
│   └── archive/              ← historical planning docs
└── implementation-artifacts/
    ├── sprint-status.yaml    ← consolidated tracker
    ├── stories/              ← 158 story context files
    └── archive/              ← old trackers, delivered specs
```

Machine-readable index: [index.md](./index.md)
