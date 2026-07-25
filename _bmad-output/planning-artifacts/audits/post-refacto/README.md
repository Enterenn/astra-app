# Audits post-refacto — index

**Campagne :** post-refacto · Epics 21–28 · voir aussi [index audits](../README.md)

**Généré :** 2026-06-22  
**Dernière resync :** 2026-07-25 (Epics 21–28 **done** · app `0.15.2+40`)  
**Base code :** `0.11.3+28` (`pubspec.yaml`)  
**Périmètre :** diagnostics techniques post-Epics 14–20 (branche `refacto` close)

Ce dossier complète [`refactoring-audit-master-v0.6.1.md`](../refactoring-audit-master-v0.6.1.md) (plan refacto livré) avec une analyse **plus granulaire** : chemins de fichiers, numéros de lignes, plans d’action numérotés et matrices de couverture.

**Usage agent / dev :** lire le diagnostic concerné **avant** d’ouvrir ou implémenter une story. Mettre à jour la colonne **Statut** quand un point est corrigé ou invalidé.

---

## Convention de statut

| Statut | Signification |
|--------|----------------|
| `open` | Constat validé, non traité |
| `partial` | Partiellement adressé ou constat nuancé après relecture code |
| `fixed` | Corrigé dans le code courant — ne plus planifier |
| `invalid` | Faux positif ou hors périmètre — ignorer |

---

## Index des diagnostics

| # | Fichier | Domaine | Statut global | Priorité | Epic cible |
|---|---------|---------|---------------|----------|------------|
| 01 | [diagnostic-acces-concurrents.md](./diagnostic-acces-concurrents.md) | SQLite multi-isolate, chronologie SQL cold start | `fixed` | P0 | E21 — done |
| 02 | [diagnostic-cold-start.md](./diagnostic-cold-start.md) | Goulot boot, fast path, indexes, lazy Trends | `partial` | P0 | E21 done · E27 backlog (D1–D3, C1) |
| 03 | [diagnostic-cycle-de-vie-ressoruce.md](./diagnostic-cycle-de-vie-ressoruce.md) | dispose, timers, subscriptions | `fixed` | P1 | E22 — done |
| 04 | [diagnostic-gestion-etat-erreur.md](./diagnostic-gestion-etat-erreur.md) | États erreur cubits, catch silencieux, fragmentation permission | `partial` | P1 | E22 done · E28 backlog (AUD-24, stale tap) |
| 05 | [diagnostic-accessibilité-statique.md](./diagnostic-accessibilité-statique.md) | WCAG statique (widgets + screens) | `fixed` | P1 | E23 — done |
| 06 | [diagnostic-etat-chargement.md](./diagnostic-etat-chargement.md) | Skeletons, spinners, états fantômes, IndexedStack | `partial` | P2 | E24 done · E28 backlog (AUD-43) |
| 07 | [diagnostic-coherence-design-system.md](./diagnostic-coherence-design-system.md) | Tokens, typo, poignées sheet, valeurs répétées | `fixed` | P2 | E24 — done |
| 08 | [diagnostic-code-mort.md](./diagnostic-code-mort.md) | Symboles orphelins vérifiés | `fixed` | P2 | E24 — done |
| 09 | [diagnostic-convention-structure.md](./diagnostic-convention-structure.md) | Monolithes, couplages DI/cubits, lints | `fixed` | P3 | E25 — done |
| 10 | [diagnostic-couverture-structurelle.md](./diagnostic-couverture-structurelle.md) | Méthodes non testées, FFI vs unit, fault injection | `fixed` | P1 | E26 — done |
| 11 | [diagnostic-dependance.md](./diagnostic-dependance.md) | Graphe repos/services, risques de split | `partial` | P3 | E25 — done |

---

## Synthèse par statut (vérification code 2026-07-19)

### Corrigé (`fixed`) — ne pas replanifier

| Point | Diagnostic | Story / preuve |
|-------|------------|----------------|
| Lock ingestion + retry session | 01 | 21-4 |
| Fast path, backfill découplé, dedup queries, index | 02 | 21-1 → 21-8 |
| `LiveStepMonitor.dispose()` séquençage | 03 | 22-1 |
| Retry profil / settings, lint `discarded_futures` | 04 | 22-3, 22-4, 22-5 (modèle unifié **non** livré) |
| Sémantique WCAG (boutons, charts clavier, live regions) | 05 | 23-1 → 23-7 |
| Loading unifié Week/Trends, toggle période guard | 06 | 24-3, 24-6 |
| `SheetDragHandle`, constantes chart centralisées | 07 | 24-1, 24-4 |
| Tokens typo/couleurs morts, constantes prefs orphelines | 08 | 24-2, 24-5 |
| Split `TodayCubit` / lifecycle, DI sans presentation, doc comments | 09 | 25-1 → 25-5 |
| Couverture orchestration + fault injection (cold start, resume, goal notif, rollover, factory bootstrap, monitor stream errors) | 10 | 26-1 → 26-6 |
| `AstraPressable._release()` animation orpheline | 03 | `if (!mounted) return` (pré-E21) |

### Partiellement vrai (`partial`) — hors périmètre sprint ou différé

| Point | Diagnostic | Nuance |
|-------|------------|--------|
| Modèle d'erreur unifié (`AppFailure`) | 04 | Retry UI livré ; enum/modèle transversal **différé** (cf. [`epics.md`](../../epics.md) Post-audit) |
| Split read/write repos (`UserSettingsRepository`, etc.) | 11 | Graphe documenté (25-5) ; split repos **non** planifié |
| Migration SQLite réactive complète | 01 | Contention réduite (lock, dedup) ; migration architecture **différée** |

### Ouvert (`open`) — Epics 27–28 backlog

| Point | Diagnostic | Story cible |
|-------|------------|-------------|
| Prefs séquentielles, WM avant `runApp`, notif bloquante | 02 §Phase D | E27 — 27-1 → 27-3 |
| `HistoryCubit` eager au boot | 02 §Phase C1 · 06 §4 | E27 — 27-4 |
| Bannière stale My Data sans tap | 04 §4 | E28 — 28-1 |
| Permission refusée fragmentée (Today) | 04 §4 | E28 — 28-2 |
| Settings bloqué par chargement profil | 06 §3 · 04 | E28 — 28-3 |

Constats résiduels **hors** E27/E28 : modèle `AppFailure` unifié (04), History refresh erreur explicite (AUD-22), onboarding permission (AUD-23), split read/write repos (11), SQL agrégé Trends (AUD-10).

---

## Quick wins — Sprint 1 (historique, livré E21–E24)

Actions initiales — **toutes adressées** dans les Epics 21–24 :

| Action | Source | Statut |
|--------|--------|--------|
| Décorréler backfill du bind live (A1) | 02 §Phase A | 21-2 |
| `refreshFastPath()` — requêtes minimales (A2) | 02 §Phase A | 21-1 |
| `IngestionCollectionLock` via `withRetry` | 01 §1 | 21-4 |
| Sémantique bouton objectif + `_UnitOptionTile` | 05 | 23-1, 23-2 |
| Sécuriser `LiveStepMonitor.dispose()` | 03 | 22-1 |
| Extraire `SheetDragHandle` | 07 | 24-1 |
| Nettoyage typo morte + tokens orphelins | 08 | 24-2, 24-5 |

**Chantiers restants :** aucun — Epics 21–28 clos. Hors scope différé : modèle `AppFailure` unifié (04), split read/write repos (11).

---

## Epics post-audit — statut sprint

| Epic | Titre | Diagnostics sources | Sprint |
|------|-------|---------------------|--------|
| **E21** | Cold Start & SQLite | 01, 02 | **done** |
| **E22** | Robustesse runtime & erreurs UI | 03, 04 | **done** |
| **E23** | Accessibilité WCAG | 05 | **done** |
| **E24** | Design System & états de chargement | 06, 07, 08 | **done** |
| **E25** | Architecture & dette structurelle | 09, 11 | **done** (`0.11.2+27`) |
| **E26** | Tests d’orchestration & résilience | 10 | **done** (`0.11.3+28`) |
| **E27** | Boot polish & lazy Trends | 02 (D, C1) | **done** |
| **E28** | UX cohérence (erreurs & permissions) | 04, 06 | **done** |

Tracker : [`sprint-status.yaml`](../../../implementation-artifacts/sprint-status.yaml) (consolidé) · snapshot : [`archive/sprint-trackers/sprint-status-post-audit.yaml`](../../../implementation-artifacts/archive/sprint-trackers/sprint-status-post-audit.yaml)

---

## Liens BMAD

| Document | Rôle |
|----------|------|
| [`refactoring-audit-master-v0.6.1.md`](../refactoring-audit-master-v0.6.1.md) | Audit refacto Epics 14–20 (historique, done) |
| [`epics.md`](../../epics.md) | Acceptance criteria Epics 1–33 (section Post-audit) |
| [`sprint-status.yaml`](../../../implementation-artifacts/sprint-status.yaml) | Tracker consolidé (Epics 1–33) |
| [`EPIC-INDEX.md`](../../EPIC-INDEX.md) | Registre epics 1–33 |
| [`architecture.md`](../architecture.md) | Décisions techniques (Today Display Truth Model, etc.) |
| [`ux-design-specification.md`](../ux-design-specification.md) | Tokens, accessibilité cible |

---

## Template de mise à jour

Quand un point est traité, modifier le diagnostic concerné **et** la colonne Statut ci-dessus :

```markdown
## Statut
- **Dernière vérification :** YYYY-MM-DD
- **Statut :** open | partial | fixed | invalid
- **Story / PR :** 21-1-… ou #123
```

---

## Navigation

- Index audits : [`../README.md`](../README.md)
- Data pipeline : [`../data-pipeline/`](../data-pipeline/)
- Projet : [`_bmad-output/README.md`](../../../README.md)
- Contexte dev : [`docs/project-context.md`](../../../../docs/project-context.md)
