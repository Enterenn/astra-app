# Audit reprise Phase 0 — index

**Campagne :** phase0-reprise · voir aussi [index audits](../README.md)

**Généré :** 2026-08-31  
**Base code :** `0.15.2+40` (`pubspec.yaml`)  
**Périmètre :** audit holistique post-pause (~1 mois sans commit, app stable en prod) — architecture, qualité, performance, UI/UX

Ce dossier complète les campagnes [post-refacto](../post-refacto/README.md) (Epics 21–28) et [data-pipeline](../data-pipeline/README.md) (Epics 29–33) avec une **synthèse transversale** avant reprise dev. **Pas** la Phase 1 produit (SQLCipher / BLE).

**Source of truth for E34–35:** [`sprint-change-proposal-2026-08-31.md`](../../sprint-change-proposal-2026-08-31.md) (approved 2026-08-31). The audit matrix below is a **signal** — do not plan shipped items or `lib/domain/`.

---

## Convention de statut

| Statut | Signification |
|--------|----------------|
| `open` | Constat validé, non traité |
| `partial` | Partiellement adressé ou hérité d'une campagne précédente |
| `fixed` | Corrigé ou acceptable by design — ne plus planifier |
| `invalid` | Faux positif ou hors périmètre |

---

## Index

| # | Fichier | Domaine | Statut global | Priorité top |
|---|---------|---------|---------------|--------------|
| 01 | [audit-master-v0.15.2.md](./audit-master-v0.15.2.md) | Synthèse architecture · qualité · perf · UX | `scoped` (CC) | E34 types/port/History/SQL · E35 MyDataCubit |

---

## Synthèse rapide

### Points forts (ne pas refactor sans raison)

- Single ingestion writer · WAL · contracts repos
- `flutter analyze` clean · 647 tests · 0 TODO `lib/`
- Design system · l10n 100/100 · zéro HTTP release

### In scope (CC approved)

| Action | Epic | Source |
|--------|------|--------|
| Relocate types used by `core/` (no `lib/domain/`) | 34.1 | audit §1.2 filtered |
| Lifecycle refresh on existing `AppCubitCoordinator` | 34.2 | audit §1.2 |
| History refresh error + retry | 34.3 | audit §2.2 |
| Batch Trends buckets + `getTodaySteps` **with** local-day/`zone_offset` | 34.4–34.5 | audit §3.1–3.2 |
| Split `MyDataCubit` then `BlocSelector` | 35.1–35.2 | audit §1.3 · §3.3 |

### Dropped / already shipped (do not plan)

| Item | Why |
|------|-----|
| `permanentlyDenied` funnel / `PermissionOutcome` | Shipped E31 |
| `_initializePlatform` swallow | Shipped 31-3 |
| New `AppCubitCoordinator` / `lib/domain/` | Exists / violates D-22 |
| SQLCipher · BLE · Health Connect | Phase 1 product |
| Split Today / goal_ring · empty-folder tests · RepaintBoundary | Out of CC |

---

## Liens BMAD

| Document | Rôle |
|----------|------|
| [manifest.yaml](../manifest.yaml) | Lookup agent compact |
| [epics.md](../../epics.md) | AC Epics 1–33 |
| [EPIC-INDEX.md](../../EPIC-INDEX.md) | Registre epics |
| [sprint-status.yaml](../../../implementation-artifacts/sprint-status.yaml) | Tracker stories |

---

## Navigation

- Index audits : [`../README.md`](../README.md)
- Post-refacto : [`../post-refacto/`](../post-refacto/)
- Data pipeline : [`../data-pipeline/`](../data-pipeline/)
- Projet : [`_bmad-output/README.md`](../../../README.md)
