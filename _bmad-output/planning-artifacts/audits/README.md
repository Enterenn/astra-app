# Audits post-refacto — index

**Généré :** 2026-06-22  
**Base code :** `0.10.1+21` (`pubspec.yaml`)  
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
| 01 | [diagnostic-acces-concurrents.md](./diagnostic-acces-concurrents.md) | SQLite multi-isolate, chronologie SQL cold start | `open` | P0 | E21 — Cold Start & SQLite |
| 02 | [diagnostic-cold-start.md](./diagnostic-cold-start.md) | Goulot boot, fast path, indexes, lazy Trends | `open` | P0 | E21 — Cold Start & SQLite |
| 03 | [diagnostic-cycle-de-vie-ressoruce.md](./diagnostic-cycle-de-vie-ressoruce.md) | dispose, timers, subscriptions | `partial` | P1 | E22 — Robustesse runtime |
| 04 | [diagnostic-gestion-etat-erreur.md](./diagnostic-gestion-etat-erreur.md) | États erreur cubits, catch silencieux, fragmentation permission | `open` | P1 | E22 — Robustesse runtime |
| 05 | [diagnostic-accessibilité-statique.md](./diagnostic-accessibilité-statique.md) | WCAG statique (widgets + screens) | `partial` | P1 | E23 — Accessibilité |
| 06 | [diagnostic-etat-chargement.md](./diagnostic-etat-chargement.md) | Skeletons, spinners, états fantômes, IndexedStack | `open` | P2 | E24 — Design System & UX loading |
| 07 | [diagnostic-coherence-design-system.md](./diagnostic-coherence-design-system.md) | Tokens, typo, poignées sheet, valeurs répétées | `open` | P2 | E24 — Design System & UX loading |
| 08 | [diagnostic-code-mort.md](./diagnostic-code-mort.md) | Symboles orphelins vérifiés | `open` | P2 | E24 — Design System & UX loading |
| 09 | [diagnostic-convention-structure.md](./diagnostic-convention-structure.md) | Monolithes, couplages DI/cubits, lints | `open` | P3 | E25 — Architecture & dette |
| 10 | [diagnostic-couverture-structurelle.md](./diagnostic-couverture-structurelle.md) | Méthodes non testées, FFI vs unit, fault injection | `open` | P1 | E26 — Tests d’orchestration |
| 11 | [diagnostic-dependance.md](./diagnostic-dependance.md) | Graphe repos/services, risques de split | `open` | P3 | E25 — Architecture & dette |

---

## Synthèse par statut (vérification code 2026-06-22)

### Déjà corrigé (`fixed`) — ne pas replanifier

| Point | Diagnostic | Preuve |
|-------|------------|--------|
| `AstraPressable._release()` animation orpheline | 03-cycle-de-vie | `if (!mounted) return` dans `astra_pressable.dart` |
| Charts Trends sans aucune sémantique | 05-accessibilité | `Semantics` présents dans `step_bar_chart.dart`, `trends_monthly_bar_chart.dart` (manque rôle clavier / `button`) |

### Partiellement vrai (`partial`)

| Point | Diagnostic | Nuance |
|-------|------------|--------|
| UI bloquée au cold start | 01, 02 | Shell s’affiche ; **time-to-data** bloqué par `await _foregroundBackfill` |
| `getTodaySteps` ×5 / `getBaseline` ×6 | 01 | Ordre de grandeur confirmé ; comptage exact dépend des sources actives |
| `displayLabel` getters morts | 08-code-mort | Non utilisés en `lib/` ; encore référencés en tests |
| `kDefaultStepGoal` / `kDefaultAccentPreset` orphelins | 08-code-mort | **Faux** — largement utilisés ; seules `kDefault*DisplayUnit` / `kDefaultAccentPresetStorage` sont orphelines |

---

## Quick wins — Sprint 1 recommandé

Actions à fort gain / faible risque, sourcées dans les diagnostics :

| Action | Source | Fichiers clés |
|--------|--------|---------------|
| Décorréler backfill du bind live (A1) | 02-cold-start §Phase A | `app_lifecycle_coordinator.dart` |
| `refreshFastPath()` — 3 requêtes max (A2) | 02-cold-start §Phase A | `today_cubit.dart` |
| `IngestionCollectionLock` via `withRetry` | 01-acces-concurrents §1 | `background_collector.dart` |
| Sémantique bouton objectif + `_UnitOptionTile` | 05-accessibilité | `today_screen.dart`, `unit_option_picker_sheet.dart` |
| Sécuriser `LiveStepMonitor.dispose()` | 03-cycle-de-vie | `live_step_monitor.dart` |
| Extraire `SheetDragHandle` | 07-coherence-ds | `*_editor_sheet.dart` |
| Nettoyage typo morte + `borderPrimary` | 08-code-mort | `astra_typography.dart`, `astra_colors.dart` |

**Hors Sprint 1 (chantiers) :** migration SQLite réactive (01), éclatement `TodayCubit` (09), fault injection complète (10), `AppFailure` unifié (04).

---

## Epics proposés (post-audit)

| Epic | Titre | Diagnostics sources | Priorité |
|------|-------|---------------------|----------|
| **E21** | Cold Start & SQLite | 01, 02 | P0 |
| **E22** | Robustesse runtime & erreurs UI | 03, 04 | P1 |
| **E23** | Accessibilité WCAG | 05 | P1 |
| **E24** | Design System & états de chargement | 06, 07, 08 | P2 |
| **E25** | Architecture & dette structurelle | 09, 11 | P3 |
| **E26** | Tests d’orchestration & résilience | 10 | P1 |

Pour décliner en stories : `bmad-create-epics-and-stories` ou `bmad-create-story`, en citant le diagnostic et la section (ex. « Story from diagnostic-cold-start.md §A1 »).

---

## Liens BMAD

| Document | Rôle |
|----------|------|
| [`refactoring-audit-master-v0.6.1.md`](../refactoring-audit-master-v0.6.1.md) | Audit refacto Epics 14–20 (historique, done) |
| [`epics-refacto.md`](../epics-refacto.md) | Stories refacto livrées |
| [`sprint-status-refacto.yaml`](../../implementation-artifacts/sprint-status-refacto.yaml) | Tracker Epics 14–20 |
| [`architecture.md`](../architecture.md) | Décisions techniques (Today Display Truth Model, etc.) |
| [`ux-design-specification.md`](../ux-design-specification.md) | Tokens, accessibilité cible |

**Prochain tracker suggéré :** `implementation-artifacts/sprint-status-post-audit.yaml` (à créer lors du lancement E21).

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

- Parent : [`planning-artifacts/`](../)
- Projet : [`_bmad-output/README.md`](../../README.md)
- Contexte dev : [`docs/project-context.md`](../../../docs/project-context.md)
