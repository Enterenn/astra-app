# Diagnostic — LiveStepMonitor (drain & affichage live)

**Généré :** 2026-07-24  
**Base code :** `0.12.1+31` (`pubspec.yaml`)  
**Périmètre :** `LiveStepMonitor` · `MonitorDrainSource` · chemin persist vs UI live · lien `StepIncrementCalculator` / `BackgroundCollector`  
**Statut global :** `open`

---

## Statut

- **Dernière vérification :** 2026-07-24
- **Statut :** `open`
- **Story / PR :** —

---

## Synthèse

| Priorité | # | Domaine | Statut |
|----------|---|---------|--------|
| 🔴 P0 | 1 | Filtre `sinceCumulative` élimine resets matériels | `open` |
| 🟡 P1 | 2 | Duplication logique crédit vs `StepIncrementCalculator` | `open` |

---

## 🔴 Critique

### 1. `drainReadingsForCollection` élimine silencieusement les pas après reset matériel

**Constat :** Le filtre `cumulativeSteps > sinceCumulative` traite tout cumulatif ≤ baseline persistée comme « déjà crédité / bruit ». Il ne distingue pas :

| Cas | `StepIncrementCalculator` | Filtre drain |
|-----|---------------------------|--------------|
| Petite baisse (bruit) | `null` — ignorer | Exclu — OK |
| Reset matériel (`current <= baseline / 2`) | Retourne `current` — créditer | **Exclu — bug** |

| Référence | Détail |
|-----------|--------|
| `lib/core/services/live_step_monitor.dart:333-346` | `drainReadingsForCollection` — filtre `>` puis discard buffer |
| `lib/core/services/live_step_monitor.dart:320-325` | `drainReadingsForCollectionGated()` — baseline SQLite via `getBaseline` |
| `lib/data/datasources/monitor_drain_source.dart:27-33` | Chemin collecte monitor actif → drain gated → `StepNormalizer` |
| `lib/data/datasources/step_increment_calculator.dart:51-56` | Reset : `current <= resetThreshold` → crédite `current` |
| `lib/core/services/live_step_monitor.dart:23` | « this class never writes buckets » — persist via collector uniquement |

**Scénario concret :**
1. Baseline persistée = 10 000
2. Reboot téléphone → lectures 50, 100, 150
3. `50 > 10000` faux → lectures **retirées du buffer sans log** — n'atteignent jamais `StepNormalizer`
4. Pas crédités en SQLite jusqu'à ce que le compteur matériel repasse 10 000 (potentiellement des jours)

**Impact :** **Sous-comptage persisté** — l'affichage live (`_applyReadingToDelta`) peut rester correct ; seul le chemin drain/collecte est affecté.

**Correctif suggéré (une des options) :**
- Laisser passer les cumulatifs « nettement inférieurs » (`<= sinceCumulative / 2`) pour que le normalizer/calculateur tranche reset vs bruit ;
- Ou reproduire la règle `baseline / 2` dans le filtre drain ;
- Logger les lectures écartées par le gate (observabilité minimum).

**Test existant (happy path seulement) :** `idle_flush_persist_test.dart:146-168` — baseline 100, readings 90/100/120 → seul 120 passé. Valide le skip « déjà crédité », **pas** le reboot.

---

## 🟡 À surveiller

### 2. Duplication logique métier drain vs calculateur

Deux composants répondent séparément à « cette lecture doit-elle être créditée en persist ? » :

| Composant | Règle | Fichier |
|-----------|-------|---------|
| Drain gate | `cumulativeSteps > sinceCumulative` | `live_step_monitor.dart:345` |
| Calculateur | Seuil relatif `baseline/2`, rate cap, bruit | `step_increment_calculator.dart:37-56` |
| UI live | Utilise calculateur via `_applyReadingToDelta` | `live_step_monitor.dart:439-455` |

**Risque :** Correction à un seul endroit — pattern déjà vu (permissions `isLimited`/`isProvisional`, audit **02**).

**Piste :** Extraire helper partagé « shouldForwardReadingForPersistence(current, baseline) » ou supprimer le pre-filtre `>` et confier entièrement au pipeline normalizer (avec garde anti double-crédit documentée).

---

## 🟢 Points forts constatés

| Domaine | Preuve |
|---------|--------|
| Pas de bug `terminalBaseline` ici | Monitor ne persiste pas baseline SQLite — doc l.23 ; `_memoryBaseline` n'avance pas sur increment `null` (l.444-452) — aligné audit **07** |
| Séparation live vs persist | `_applyReadingToDelta` (UI) ≠ `drainReadingsForCollection` (collecte) |
| Anti double-comptage reconcile | `_reconciling` + `beginReconcile`/`endReconcile` (l.217-226) |
| Plancher monotone | `reconcileFromDatabase` — total ne redescend pas même jour local (l.252-272) |
| Buffer borné FIFO | `maxBufferedReadings = 250` (l.32, 397-401) |
| Frontière de jour | `_notifyLocalDayBoundaryIfNeeded` — bloque delta, conserve lecture (l.404-412) |
| Observabilité | `livePipelineLog` à chaque étape clé (hardware, drain, reconcile, emit) |
| Peek sans double subscription | `peekPhoneStepEvent` quand monitor arrêté (l.144-207) |
| Idle flush | `onActivityIdle` + `kActivityIdleFlushDelay` 15s |

---

## Chaîne persist (monitor actif)

```
BackgroundCollector.collectOnce
  → MonitorDrainSource.watchStepReadings()
       → drainReadingsForCollectionGated()   ← filtre > baseline
       → StepNormalizer.normalize
       → upsertIngestionBucket + setBaseline
```

Chemin UI (non affecté par bug #1) :

```
PhoneStepEvent → _bufferReading → _applyReadingToDelta → incrementCalculator → _pendingDelta → stream
```

---

## Todo consolidée (session)

| # | Action | Lié |
|---|--------|-----|
| T1 | Corriger filtre drain reset matériel (`<= baseline/2` pass-through ou déléguer au calculateur) | #1 |
| T2 | Test régression : baseline 10k, readings 50/100/150 post-reboot → crédit persist | #1 |
| T3 | Factoriser ou documenter règle unique crédit persist vs live | #2 |
| T4 | Log readings dropped by sinceCumulative gate | #1 |

---

## Plan d'action suggéré

| Phase | Action |
|-------|--------|
| **P0** | Fix filtre + test reboot (T1, T2) |
| **P1** | Unifier ou documenter règles drain vs calculator (T3) |
| **P2** | Logging gate drops (T4) |

---

## Liens audits

| Audit | Lien |
|-------|------|
| **07** ingestion pedometer | `terminalBaseline` / calculateur reset — même famille baseline |
| **03** WorkManager | Collecte via `BackgroundCollector` + `MonitorDrainSource` |
| **02** permissions | Pattern duplication logique métier |

---

## Navigation

- Dossier : [`audits_2/`](./)
- Tests : `live_step_monitor_test.dart` · `idle_flush_persist_test.dart` · `monitor_drain_source_test.dart`
- Lifecycle : `lifecycle_day_boundary_service.dart` · `app_lifecycle_coordinator.dart`
