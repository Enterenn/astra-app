# Diagnostic — WorkManager & maintenance DB

**Généré :** 2026-07-21  
**Base code :** `0.12.1+31` (`pubspec.yaml`)  
**Périmètre :** `BackgroundCollector` · `IngestionCollectionLock` · `DataLifecycleService` · `workmanager_callback.dart` · boot `main.dart`  
**Statut global :** `partial` (P0 #1 fixed — story 29-3 · P0 #2 fixed — story 30-1)

---

## Statut

- **Dernière vérification :** 2026-07-24
- **Statut :** `partial` (P0 #1 fixed · P0 #2 fixed)
- **Story / PR :** Story 29-3 · Story 30-1 (`30-1-cross-isolate-lock-for-maintenance-and-vacuum`)

---

## Synthèse

| Priorité | # | Domaine | Statut |
|----------|---|---------|--------|
| 🔴 P0 | 1 | Double comptage pas si échec mid-cycle | `fixed` (29-3) |
| 🔴 P0 | 2 | VACUUM sans lock cross-isolate vs collecte | `fixed` (30-1) |
| 🟡 P1 | 3 | Pas de scheduling background iOS | `fixed` (30-3) |
| 🟡 P1 | 4 | Ordre cancel WM / init notifications non structuré | `partial` |
| 🟡 P2 | 5 | TTL lock 35s inadapté au VACUUM | `open` |
| 🟡 P2 | 6 | `DateTime.now()` dans `_TimeoutBoundedSource` | `open` |

---

## 🔴 Critique

### 1. Risque de double comptage des pas (`BackgroundCollector._collectOnce`)

**Statut :** `fixed` — Story 29-3 (txn atomique upsert + baseline par source)

**Constat (résolu Story 29-3) :** Avant fix, boucle par source sans transaction atomique bucket + baseline. L'upsert est **additif** (`ON CONFLICT … DO UPDATE SET value = value + excluded.value`). Si une exception survient après un ou plusieurs `upsertIngestionBucket` mais **avant** `setBaseline`, le prochain cycle repart de l'ancienne baseline et peut re-additionner les mêmes deltas.

| Référence | Détail |
|-----------|--------|
| `lib/core/services/background_collector.dart:116-128` | Upserts séquentiels puis `setBaseline` — pas de txn englobante |
| `lib/core/services/background_collector.dart:129-134` | `catch` par source — état partiel conservé, cycle suivant possible |
| `lib/data/repositories/step/step_ingestion_repository.dart:62-63` | Merge additif sur conflit d'identité bucket |
| `lib/data/repositories/ingestion_baseline_repository.dart:57-74` | Baseline persistée séparément (`user_preferences`) |

**Scénario :**
1. Cycle N : buckets B1..Bk upsertés, crash/exception avant `setBaseline`
2. Cycle N+1 : même readings → mêmes buckets → **valeurs additionnées une seconde fois**

**Piste :** Transaction unique (upserts + baseline) par source ; ou baseline commit avant upsert avec idempotence stricte ; ou journal de buckets déjà appliqués.

---

### 2. Aucun lock cross-isolate autour du VACUUM

**Statut :** `fixed` — Story 30-1 (lock maintenance dédié + exclusion mutuelle collecte)

**Constat (résolu Story 30-1) :** La collecte 15 min est protégée par `IngestionCollectionLock`. La maintenance hebdomadaire (`runMaintenanceOnConnection` en `maintenanceOnCurrentConnection: true`) n'acquiert **aucun** lock — collision possible si Android déclenche les deux tâches WM simultanément.

| Référence | Détail |
|-----------|--------|
| `lib/core/services/background_collector.dart:74-86` | Lock ingestion avant `_collectOnce` |
| `lib/core/services/workmanager_callback.dart:118` | Collecte WM : `collectOnce()` locké |
| `lib/core/services/workmanager_callback.dart:129-156` | Maintenance WM : `maintenanceOnCurrentConnection: true` |
| `lib/core/services/data_lifecycle_service.dart:41-59` | `runMaintenanceOnConnection` : downsample + `VACUUM` sans mutex |
| `lib/core/services/data_lifecycle_service.dart:220-225` | `PRAGMA optimize` + `VACUUM` sur connexion ouverte |
| `lib/core/services/workmanager_callback.dart:207,230` | Fréquences : 15 min vs 7 jours — overlap possible |

**Mitigation partielle :** UI-triggered maintenance offload via `compute` + connexion éphémère (`data_lifecycle_service.dart:109-112,168-180`) — évite collision UI/VACUUM, **pas** WM collecte vs WM maintenance sur le même fichier.

**Todo session :** Étendre `IngestionCollectionLock` (ou clé/TTL dédiés) pour protéger `runMaintenanceOnConnection` en mode `maintenanceOnCurrentConnection: true`.

---

## 🟡 À surveiller

### 3. Pas de scheduling background sur iOS

**Statut :** `fixed` — Story 30-3 (`docs/project-context.md` §Platform background collection)

**Constat :** Enregistrement WM conditionné à Android uniquement.

| Référence | Détail |
|-----------|--------|
| `lib/core/services/workmanager_callback.dart:174-176,191-193,221-223` | Early return si `!Platform.isAndroid` |
| `docs/project-context.md` | Gap iOS + stratégie resume/backfill documentés (AUD2-FR18) |

**Assumé/documenté** — trou de collecte réel si l'app iOS reste fermée plusieurs jours (reconciliation au resume uniquement). Phase 0 : pas de `BGAppRefresh` ; catch-up à l'ouverture de l'app.

---

### 4. Ordre d'appel critique cancel WM / init notifications

| Référence | Détail |
|-----------|--------|
| `lib/main.dart:61-63` | `await cancelStepCollectionWorkmanager()` puis `unawaited(startNotificationInitForBoot(...))` |
| `lib/core/services/workmanager_callback.dart:167-169` | Doc : éviter race isolate background vs `NotificationService.initialize` |

**Statut :** `partial` — ordre correct dans `main()` aujourd'hui ; **non protégé structurellement** (init notifications en parallèle non-awaited, pas de barrière explicite). `cancel` ne couvre que `kStepCollectionUniqueName`, pas la maintenance.

**Piste :** Séquence boot encapsulée (cancel → await init ou gate) ; tests de non-régression boot.

---

### 5. TTL du lock (35s) inadapté au VACUUM

| Référence | Détail |
|-----------|--------|
| `lib/core/services/ingestion_collection_lock.dart:14` | `ttl = const Duration(seconds: 35)` |
| `lib/core/services/data_lifecycle_service.dart:55-56` | Downsample + VACUUM peut dépasser 35s sur gros volumes |

Réutiliser le même lock/TTL pour VACUUM risquerait expiration mid-operation → seconde tâche pourrait entrer.

**Piste :** Clé séparée `maintenance_lock` + TTL long (ex. 5–10 min) ou lock sans TTL avec release explicite en `finally`.

---

### 6. `DateTime.now()` au lieu de `TimeProvider` injecté

| Référence | Détail |
|-----------|--------|
| `lib/core/services/background_collector.dart:201-231` | `_TimeoutBoundedSource.watchStepReadings` |
| `lib/core/services/background_collector.dart:220,227` | `DateTime.now().add(maxCollectionDuration)` / `isAfter(deadline)` |

`BackgroundCollector` reçoit `clock` pour le lock et les notifications, pas pour le timeout source — tests non déterministes sur cette fenêtre.

---

## 🟢 Points forts constatés

| Domaine | Preuve |
|---------|--------|
| Lock ingestion cross-isolate | `IngestionCollectionLock` — txn atomique, TTL, pas de lock orphelin post-crash (`ingestion_collection_lock.dart:22-54`) |
| UI vs WM maintenance | Offload `compute` + connexion courte pour VACUUM UI (`data_lifecycle_service.dart:168-212`) |
| Dédup in-flight | `_maintenanceInFlight` (`data_lifecycle_service.dart:142-165`), `_collectInFlight` (`background_collector.dart:63-90`), `_reopenInFlight` session DB |
| Cas limites plateforme | `RootIsolateToken` null → fallback direct ; sinon `BackgroundIsolateBinaryMessenger.ensureInitialized` (`data_lifecycle_service.dart:204-212`) |
| WM testable | `runStepCollectionWorkmanagerTask`, `runDatabaseMaintenanceWorkmanagerTask`, clients injectables |
| Boot WM non-bloquant | Enregistrement post-`runApp` via `addPostFrameCallback` (`main.dart:32-39,73`) |
| Collecte WM + notif goal | `collectOnce(enableGoalNotification: true)` (`workmanager_callback.dart:118`) |

---

## Todo consolidée (session)

| # | Action | Lié |
|---|--------|-----|
| T1 | Étendre `IngestionCollectionLock` (ou clé/TTL dédiés) autour de `runMaintenanceOnConnection` en `maintenanceOnCurrentConnection: true` | #2 — **done** (30-1) |
| T2 | Transaction bucket + baseline ou idempotence anti double-add | #1 — **done** (29-3) |

---

## Plan d'action suggéré

| Phase | Action |
|-------|--------|
| **P0** | Mutex maintenance partagé avec collecte (T1) |
| **P0** | Txn atomique upsert + baseline par source (T2) — **done** (29-3) |
| **P1** | ~~Documenter gap iOS + stratégie resume/backfill~~ — **done** (30-3) |
| **P1** | Boot gate : cancel WM → await notification init |
| **P2** | Injecter `TimeProvider` dans `_TimeoutBoundedSource` |
| **P2** | TTL maintenance distinct si réutilisation du pattern lock |

---

## Tâches WorkManager (Android)

| Unique name | Task | Fréquence | Fichier |
|-------------|------|-----------|---------|
| `astra_step_collection_periodic` | `astra_step_collection` | 15 min | `workmanager_callback.dart:204-210` |
| `astra_database_maintenance_periodic` | `astra_database_maintenance` | 7 jours | `workmanager_callback.dart:227-233` |

---

## Navigation

- Dossier : [`audits_2/`](./)
- Audits liés : [`diagnostic-couche-donnees.md`](./diagnostic-couche-donnees.md) · [`diagnostic-acces-concurrents.md`](../audits/diagnostic-acces-concurrents.md)
- Story lock : `21-4-route-ingestion-lock-through-session-with-retry`
