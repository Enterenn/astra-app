# Diagnostic — charts (agrégation daily / monthly)

**Généré :** 2026-07-21  
**Base code :** `0.12.0+30` (`pubspec.yaml`)  
**Périmètre :** `_step_chart_queries.dart` · `StepAggregationRepository.getChartDailyAggregates` / `getChartMonthlyAggregates` · History / Trends consumers  
**Statut global :** `partial` (solide ; dette doc/perf mineure)

---

## Statut

- **Dernière vérification :** 2026-07-21
- **Statut :** `partial`
- **Story / PR :** —

---

## Synthèse

| Priorité | # | Domaine | Statut |
|----------|---|---------|--------|
| 🟡 P3 | 1 | Astuces `DateTime.utc` non commentées | `open` |
| 🟡 P3 | 2 | Requête SQL sans borne haute | `open` |

---

## 🟡 À surveiller (mineur)

### 1. Normalisation calendaire `DateTime.utc` implicite

**Constat :** Calculs de fenêtre mensuelle s'appuient sur la normalisation Dart (mois ≤ 0, jour 0) — **correct** mais non documenté inline.

| Référence | Pattern | Effet |
|-----------|---------|-------|
| `_step_chart_queries.dart:48-51` | `DateTime.utc(year, month - (months - 1), 1)` | Recul de N mois (ex. jan − 1 → déc année préc.) |
| `_step_chart_queries.dart:126-129` | `DateTime.utc(year, month - monthOffset, 1)` | Itération mois glissants |
| `_step_chart_queries.dart:131-133` | `DateTime.utc(year, month + 1, 0)` | Dernier jour du mois (`day 0` → veille du 1er du mois suivant) |

**Risque :** Mainteneur « corrige » en logique manuelle (split année/mois) et introduit une régression.

**Piste :** Commentaire court type *« intentional DateTime.utc rollover — do not replace with manual month math »*.

---

### 2. Absence de borne haute SQL

**Constat :** Filtre SQL = `type = ? AND start_time >= ?` uniquement — pas de `start_time < upperBound`.

| Référence | Détail |
|-----------|--------|
| `_step_chart_queries.dart:10-14` | `chartSamplesWhereClause` — lower bound seulement |
| `step_aggregation_repository.dart:133-138,162-167` | Query sans plafond UTC |
| `_step_chart_queries.dart:73-74` | Fenêtre réelle : `rowLocalDay` entre `windowStart` et `referenceToday` (Dart) |

**Impact :** Lignes futures ou hors fenêtre (jour local) chargées puis ignorées — IO SQLite + parsing Dart superflus. Acceptable Phase 0 ; pas de bug UI.

**Piste (optionnelle) :** `sqlUpperBoundUtc = referenceToday.add(Duration(days: 2))` aligné sur `sampleUtcBoundsForLocalDay` (`_step_sample_bounds.dart:61-62`).

---

## 🟢 Points forts constatés

| Domaine | Preuve |
|---------|--------|
| Pas de double-comptage multi-résolution | `finestResolutionTotal` — `_step_sample_bounds.dart:6-21` ; utilisé daily l.105 et monthly l.139 |
| DST / jours non compactés | Même jour peut avoir 5min + hourly ; une seule résolution retenue → impact UI nul (cf. [`diagnostic-fuseaux-jours-locaux.md`](./diagnostic-fuseaux-jours-locaux.md)) |
| Mois courant partiel | `monthOffset == 0` → `monthEnd = referenceToday` (pas fin de mois) — `_step_chart_queries.dart:131-133` ; moyenne `/ dayCount` correcte |
| Mois passés complets | `monthEnd = DateTime.utc(..., month + 1, 0)` — jours calendaires entiers |
| Zero-fill daily | Boucle `days` avec `referenceToday.subtract(Duration(days: i))` — l.100-107 |
| Offset par ligne | `accumulateStepsByDayAndResolution` — `LocalDayCalculator` + `sample.zoneOffset` — l.69-72 |
| Validation Phase 0 | `days ∈ {7,30}`, `months == 12` — `step_aggregation_repository.dart:128-129,157-158` |
| Consommateurs | `HistoryCubit` (30j + 12 mois), `TodayWeekSelection` (7j) |
| Tests | `step_repository_chart_aggregates_test.dart`, `step_repository_chart_monthly_aggregates_test.dart` |

---

## Flux agrégation

```
getChart*Aggregates
  → dailyChartQueryBounds / monthlyChartQueryBounds
  → SQL: start_time >= sqlLowerBoundUtc
  → accumulateStepsByDayAndResolution (filtre local day)
  → finestResolutionTotal par jour
  → ChartDayAggregate | ChartMonthAggregate (moyenne mois)
```

---

## Plan d'action suggéré

| Phase | Action |
|-------|--------|
| **Doc** | Commentaires rollover `DateTime.utc` (T1) |
| **Perf (optionnel)** | Borne haute SQL cohérente avec fenêtre locale |
| **Ne pas faire** | Sommer toutes résolutions d'un même jour |

---

## Navigation

- Dossier : [`audits_2/`](./)
- Lié : [`diagnostic-fuseaux-jours-locaux.md`](./diagnostic-fuseaux-jours-locaux.md) · [`diagnostic-downsampling-compaction-fr11.md`](./diagnostic-downsampling-compaction-fr11.md)
- Modèles : `chart_day_aggregate.dart` · `chart_month_aggregate.dart`
