# Diagnostic — downsampling / compaction (FR11)

**Généré :** 2026-07-21  
**Base code :** `0.12.1+31` (`pubspec.yaml`)  
**Périmètre :** `SampleCompactionRunner` · `TransactionCompactionWriter` · `StepAggregationRepository.downsampleStepSamples` · `lifecycle_compaction.dart`  
**Statut global :** `open`

---

## Statut

- **Dernière vérification :** 2026-07-21
- **Statut :** `open`
- **Story / PR :** —

---

## Synthèse

| Priorité | # | Domaine | Statut |
|----------|---|---------|--------|
| 🔴 P0 | 1 | `ConflictAlgorithm.ignore` + suppression sources inconditionnelle | `open` |
| 🟡 P1 | 2 | `downsampleStepSamples(txn: …)` — atomicité déléguée | `partial` |
| 🟡 P2 | 3 | Compteurs `hourlyCreated` / `dailyCreated` surcomptés si ignore | `open` |

---

## 🔴 Critique

### 1. `ConflictAlgorithm.ignore` + suppression inconditionnelle des sources

**Constat :** Chaque passe de compaction insère l'agrégat avec `ConflictAlgorithm.ignore` (conflit PK silencieux), puis **supprime systématiquement** les buckets sources sans vérifier si l'insert a réellement eu lieu.

| Référence | Détail |
|-----------|--------|
| `lib/core/lifecycle/sample_compaction_runner.dart:51-56` | `insertCompactedSample` → `ConflictAlgorithm.ignore` |
| `lib/core/lifecycle/sample_compaction_runner.dart:145-151` | Tier 2 : insert → `hourlyCreated++` → delete sources |
| `lib/core/lifecycle/sample_compaction_runner.dart:195-201` | Tier 3 hourly→daily : même pattern |
| `lib/core/lifecycle/sample_compaction_runner.dart:248-254` | Tier 3 catch-up 5min→daily : même pattern |

**Scénario :** Ré-exécution après modification des données sources (ou agrégat existant divergent) → insert ignoré (PK déjà présente, valeur potentiellement **obsolète**) → sources fines **supprimées quand même**.

**Limite de l'atomicité transactionnelle :** La txn garantit « tout ou rien » au niveau commit, **pas** la justesse du contenu — perte de données fines possible dans une txn « réussie ».

**Contraste ingestion :** `deterministicFromMergedBucket` inclut `resolution` ici (`sample_compaction_runner.dart:140-143`) — IDs cohérents pour la compaction ; le bug est le couple ignore + delete, pas la génération d'ID.

**Piste (todo session) :** Vérifier `rows affected` / retour `insert` avant delete ; ou `INSERT … ON CONFLICT DO UPDATE` si valeur recalculée diffère ; ou abort txn si conflit avec valeur divergente ; logger anomalie minimum.

---

## 🟡 À surveiller

### 2. `downsampleStepSamples(txn: …)` — atomicité déléguée à l'appelant

| Référence | Détail |
|-----------|--------|
| `lib/data/repositories/step/step_aggregation_repository.dart:221-252` | Doc D-24 : passe `txn` → pas de txn interne |
| `lib/core/services/data_lifecycle_service.dart:55` | Prod : `downsampleStepSamples()` **sans** `txn` — txn interne OK |
| `test/data/repositories/step_repository_downsample_test.dart:88-96` | Seul appelant `txn:` repéré (test) |

**Statut :** `partial` — chemin prod sécurisé (txn owned). Paramètre externe prévu pour batch admin D-24 ; **aucun appelant prod** ne passe `txn` aujourd'hui. Risque futur si batch sans txn englobante.

**Action todo :** Confirmer que tout futur appelant respecte l'intention (même txn que autres writes admin).

---

### 3. Compteurs `hourlyCreated` / `dailyCreated` surcomptables

Incrément **avant** vérification du succès insert (`sample_compaction_runner.dart:146,196,249`). Si insert ignoré, compteurs et stats `CompactionResult` surestiment la création.

Impact mineur sauf si exposé à l'utilisateur (My Data / debug). `CompactionResult` consommé par `DataLifecycleService` / logs — pas d'UI directe identifiée.

---

## 🟢 Points forts constatés

| Domaine | Preuve |
|---------|--------|
| Atomicité passes FR11 | `downsampleStepSamples()` : `runAllTiers` dans une txn unique (`step_aggregation_repository.dart:247-250`) — pas de suppression orpheline mid-pass |
| Groupement rigoureux | `isCompleteFiveMinuteHourGroup`, `isCompleteHourlyDayGroup`, `isCompleteFiveMinuteDayGroup` + `contiguous*Groups` (`lifecycle_compaction.dart:152-298`, `sample_compaction_runner.dart:133-137`) |
| IDs déterministes compaction | `SampleIdGenerator.deterministicFromMergedBucket(startTimeUtc, resolution)` — cohérent avec tiers |
| Anti double-comptage lecture | `getTodaySteps` : `finestResolutionTotal(byResolution)` (`step_aggregation_repository.dart:49-67`, `_step_sample_bounds.dart:10`) |
| Architecture testable | `CompactionWriter` abstrait + `TransactionCompactionWriter` |
| Validation paramètres | `getChartDailyAggregates` / `getChartMonthlyAggregates` — `ArgumentError` si days/months invalides |
| Idempotence nominal path | Test second pass : 0 created (`step_repository_downsample_test.dart:72-86`) — OK quand données stables et agrégats alignés |
| Préservation somme steps | Test sum before/after (`step_repository_downsample_test.dart:57-69`) — happy path validé |

---

## Todo consolidée (session)

| # | Action | Lié |
|---|--------|-----|
| T1 | Vérifier résultat insert (`rows affected`) avant delete sources ; logger/abort si ignore | #1 |
| T2 | Auditer futurs appelants `downsampleStepSamples(txn: …)` pour atomicité D-24 | #2 |

---

## Plan d'action suggéré

| Phase | Action |
|-------|--------|
| **P0** | Guard insert-before-delete dans `TransactionCompactionWriter` ou runner (T1) |
| **P0** | Test régression : sources modifiées + ré-compaction → pas de perte silencieuse |
| **P1** | Documenter contrat `txn` (obligatoire txn parent) ou retirer param si inutilisé en prod |
| **P2** | Incrémenter compteurs seulement si insert réussi |

---

## Flux compaction (rappel FR11)

```
downsampleStepSamples()
  └─ db.transaction
       └─ SampleCompactionRunner.runAllTiers
            ├─ compactTierTwoFiveMinuteToHourly      (tier 2)
            ├─ compactTierThreeHourlyToDaily           (tier 3)
            └─ compactTierThreeFiveMinuteCatchUpToDaily
```

Chaque merge : `insertCompactedSample` (ignore) → delete N sources.

---

## Navigation

- Dossier : [`audits_2/`](./)
- Lié : [`diagnostic-couche-donnees.md`](./diagnostic-couche-donnees.md) (IDs ingestion) · [`diagnostic-workmanager-maintenance-db.md`](./diagnostic-workmanager-maintenance-db.md) (maintenance appelle downsample)
- Story : `4-1-data-lifecycle-service-downsampling-and-maintenance` · `18-3-split-step-repository`
