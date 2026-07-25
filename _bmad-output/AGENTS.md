# BMAD agent contract — astra-app

Machine entry point for BMad skills, Cursor agents, and contributors automating planning artifacts.

**Human hub:** [`README.md`](./README.md) · **Config:** [`_bmad/bmm/config.yaml`](../_bmad/bmm/config.yaml)

---

## Canonical paths (always use these)

| Role | Path | Notes |
|------|------|-------|
| **Epics + AC** | `_bmad-output/planning-artifacts/epics.md` | **Only** active `*epic*.md` at planning-artifacts root |
| **Sprint tracker** | `_bmad-output/implementation-artifacts/sprint-status.yaml` | Read/write story & epic status here |
| **Story context** | `_bmad-output/implementation-artifacts/stories/{story-key}.md` | Per-story AC, code map, review notes |
| **Epic lookup** | `_bmad-output/planning-artifacts/EPIC-INDEX.md` | Table Epics 1–33 (human + quick agent scan) |
| **Audits index** | `_bmad-output/planning-artifacts/audits/manifest.yaml` | Diagnostic → epic mapping |
| **Project rules** | `docs/project-context.md` | OK commit gate, tests, versioning |

Resolved from `_bmad/bmm/config.yaml`:

- `planning_artifacts` → `_bmad-output/planning-artifacts`
- `implementation_artifacts` → `_bmad-output/implementation-artifacts`

---

## Do not use for active work

| Path | Why |
|------|-----|
| `planning-artifacts/archive/**` | Historical snapshots |
| `planning-artifacts/epics-refacto.md` etc. | **Removed** — merged into `epics.md`; see `archive/epics/` |
| `implementation-artifacts/archive/sprint-trackers/*` | Pre-consolidation YAML |
| `*sprint-status-*.yaml` (except root `sprint-status.yaml`) | Archived |

**Sprint-planning glob:** `{planning_artifacts}/*epic*.md` must match **one file** (`epics.md`) to avoid duplicate epic parsing.

---

## Workflows → files to update

| Workflow / skill | Read | Write on completion |
|----------------|------|---------------------|
| `bmad-create-story` | `epics.md`, `sprint-status.yaml` | `stories/{key}.md`, `sprint-status.yaml` |
| `bmad-dev-story` / `bmad-quick-dev` | story file, `epics.md` (AC section) | code, `sprint-status.yaml` via sync |
| `bmad-code-review` | story file | story file, `sprint-status.yaml` → `done` |
| `bmad-sprint-planning` | `epics.md` | `sprint-status.yaml` (full regen) |
| `bmad-sprint-status` | `sprint-status.yaml` | — |
| `bmad-create-epics-and-stories` | PRD, architecture, UX | **`epics.md`** (append new epics) |

When closing an epic: bump `pubspec.yaml` + root `README.md` version row; set `last_updated` in `sprint-status.yaml`.

---

## Current state (2026-07-25)

```yaml
overall_status: complete
active_phase: null
app_version: 0.15.2+40
epics: 1–33 done
next_recommended: Phase 1 planning — extend epics.md + sprint-status.yaml with Epic 34+
```

---

## Audits layout

```
planning-artifacts/audits/
├── README.md
├── manifest.yaml
├── post-refacto/      # E21–28 diagnostics
└── data-pipeline/     # E29–33 diagnostics
```
