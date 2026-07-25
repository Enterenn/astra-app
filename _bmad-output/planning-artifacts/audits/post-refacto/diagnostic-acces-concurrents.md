# Diagnostic des accès concurrents à SQLite

## **1. Instances et partage de connexion**

En production (`AppDependencies.create`), **une seule** `AstraDatabaseSession` et **une seule** connexion `sqflite` `Database` sont créées (`ensureOpen()` → `openAstraDatabase`). Cette instance est injectée dans tous les repositories UI : `UserSettingsRepository`, `UserHealthMetricsRepository`, `StepIngestionRepository`, `StepAggregationRepository`, `IngestionBaselineRepository`, `CsvService`, `DataLifecycleService`. Ce n’est pas un singleton global au sens pattern, mais un **partage explicite par DI** : tous les repos pointent vers le même `_db`.

Les chemins hors UI ouvrent des connexions **séparées** sur le même fichier : `openIsolateAstraDatabase` (WorkManager, FGS, maintenance) crée une nouvelle `Database` à chaque appel, sans cache. `background_collector_factory` peut envelopper la même `Database` brute dans une nouvelle `AstraDatabaseSession` pour settings/health, tout en passant la `Database` brute aux repos step.

Tous les accès repositories passent par `AstraDatabaseSession.withRetry()` (ou `_session.run`). Exception notable : `IngestionCollectionLock` utilise `StepIngestionRepository.db` **directement**, sans `withRetry` — toujours depuis l’isolate UI, mais sans la couche de réouverture. Les appels SQL sont **initiés depuis le thread UI** ; sqflite les exécute via son mécanisme interne (thread/isolate natif). Les **autres isolates** (WorkManager, FGS) ont leurs propres connexions et peuvent provoquer `database_closed` sur la session UI, d’où `withRetry` / `ensureOpen()` au resume.

---

## **2. Chronologie SQL — lancement → premier `emit` de `TodayCubit`**

**Périmètre** : cold start standard (onboarding terminé, `enableLiveStepPipeline = true`).

**Premier emit** : `TodayState.loading()` au constructeur (`today_cubit.dart:40`) — **aucun SQL** à ce moment. Le tableau couvre tout le SQL jusqu’au **premier emit avec données** (`_refreshImpl` → `_applyTodaySnapshot` → `emit`), orchestré par `AppLifecycleCoordinator` + `BackgroundCollector`.

| **#** | **Moment** | **Méthode SQL (couche repo)** | **Repository** | **Awaited / Unawaited** |
| --- | --- | --- | --- | --- |
| **A — `main()` / `AppDependencies.create` (avant 1er emit)** |  |  |  |  |
| 1 | `ensureOpen()` | `openDatabase` + `PRAGMA journal_mode` + `PRAGMA foreign_keys` | `AstraDatabaseSession` | **awaited** |
| 2–8 | Lecture prefs initiales | `readValue` ×7 (`theme`, `accent`, `distance`, `weight`, `height`, `onboarding`, `locale`) | `UserSettingsRepository` | **awaited** (séquentiel) |
| 9 | Migration goal notif. (si besoin) | `readValue` / `writeValue` | `UserSettingsRepository` | **awaited** |
| **B — `bindToWidget` → `_foregroundBackfill` = `_runPersistCycle`** |  |  |  |  |
| 10 | `beginReconcile()` | `getBaseline` (phone) | `IngestionBaselineRepository` | **awaited** |
| 11 | `collectOnce()` → `tryAcquire()` | `query` + `insert` (lock) | `IngestionCollectionLock` (via `StepIngestionRepository.db`) | **awaited** |
| 12 | `collectOnce()` source monitor | `getBaseline` (phone) | `IngestionBaselineRepository` | **awaited** |
| 13 | `collectOnce()` source ADP (no-op stream) | `getBaseline` (wearable) | `IngestionBaselineRepository` | **awaited** |
| 14 | `collectOnce()` si buckets | `upsertIngestionBucket` → `rawInsert` | `StepIngestionRepository` | **awaited** (boucle) |
| 15 | `collectOnce()` si terminal baseline | `setBaseline` → `insert` | `IngestionBaselineRepository` | **awaited** |
| 16 | `collectOnce()` → `release()` | `delete` (lock) | `IngestionCollectionLock` | **awaited** |
| 17 | `reconcileFromDatabase()` | `getTodaySteps` → `query timeseries_samples` | `StepAggregationRepository` | **awaited** |
| 18 | `reconcileFromDatabase()` | `getBaseline` (phone) | `IngestionBaselineRepository` | **awaited** |
| **C — `onTodayCubitReady` → `_startLivePipelineFirstTime` → `_bindLiveMonitorToToday`** |  |  |  |  |
| 19 | `monitor.start()` | `getBaseline` (phone) | `IngestionBaselineRepository` | **awaited** |
| 20 | `monitor.start()` | `getTodaySteps` | `StepAggregationRepository` | **awaited** |
| 21 | `reconcileFromDatabase()` | `getTodaySteps` | `StepAggregationRepository` | **awaited** |
| 22 | `reconcileFromDatabase()` | `getBaseline` (phone) | `IngestionBaselineRepository` | **awaited** |
| 23 | `refresh(silent: true)` | `getTodaySteps` | `StepAggregationRepository` | **awaited** (dans `Future.wait`) |
| 24 | `refresh(silent: true)` | `getGoalForLocalDay` → `rawQuery daily_goal_effective` | `UserHealthMetricsRepository` | **awaited** (dans `Future.wait`) |
| 25 | `refresh(silent: true)` | `getLastIngestionUtc` → `rawQuery MAX(end_time)` | `StepAggregationRepository` | **awaited** (dans `Future.wait`) |
| 26 | `refresh(silent: true)` | `getTodayActiveBuckets` → `query timeseries_samples` | `StepAggregationRepository` | **awaited** (dans `Future.wait`) |
| 27 | `refresh(silent: true)` | `getHeightCm` / `getWeightKg` → `readValue` | `UserHealthMetricsRepository` | **awaited** (dans `Future.wait`) |
| 28 | `refresh(silent: true)` | `getLastDisplayedSteps` → `readValue` | `UserSettingsRepository` | **awaited** (dans `Future.wait`) |
| 29 | `_loadWeekDays()` | `getChartDailyAggregates` → `query timeseries_samples` | `StepAggregationRepository` | **awaited** (après le `Future.wait`) |
| 30 | `_loadWeekDays()` | `getGoalForLocalDay` ×7 | `UserHealthMetricsRepository` | **awaited** (dans `Future.wait` interne) |
| 31 | `_maybeTriggerCelebration` | `tryClaimCelebrationShownDate` → `readValue` + possible `writeValue` | `UserSettingsRepository` | **awaited** |
| → | **Premier emit données** | `emit(TodayState.fromData(...))` via `_applyTodaySnapshot` | `TodayCubit` | — |

**Notes** : `_foregroundBackfill` est lancé en **unawaited** depuis `bindToWidget` (ligne 180), mais `_startLivePipelineFirstTime` fait `await _foregroundBackfill` avant le refresh — donc séquentiel côté pipeline. `collectOnce` au cold start ne passe pas par le garde `_livePipelineStarted` (celui-ci s’applique à `_persistCycleWithOptionalSync`, pas à `_runPersistCycle`).

---

## **3. `getTodaySteps()` — parallèle vs séquentiel, doublons cold start**

### **Parallèle (`Future.wait`)**

| **Fichier** | **Ligne** | **Contexte** |
| --- | --- | --- |
| `lib/presentation/cubits/today_cubit.dart` | 523–524 | `refresh()` — `getTodaySteps()` lancé en parallèle avec goal, lastIngestion, buckets, height, weight, lastDisplayed |

`refreshMetadata()` (l.430) **n’appelle pas** `getTodaySteps()` — il réutilise `_todaySteps ?? state.steps`.

### **Séquentiel (`await` successifs)**

| **Fichier** | **Ligne** | **Contexte** |
| --- | --- | --- |
| `lib/core/services/app_lifecycle_coordinator.dart` | 180–184 → 333–338 | `_runPersistCycle` : `collectOnce` puis `reconcileFromDatabase` |
| `lib/core/services/live_step_monitor.dart` | 89–90 | `start()` : `getBaseline` puis `getTodaySteps` |
| `lib/core/services/live_step_monitor.dart` | 226–227 | `reconcileFromDatabase()` : `getTodaySteps` puis `getBaseline` |
| `lib/core/services/background_collector.dart` | 182 | `maybeNotifyGoalReachedIfGoalMet()` — **pas** sur le chemin cold start UI (goal notif désactivée) |

### **Doublons — même requête SQL lancée 2+ fois (cold start)**

| **Requête équivalente** | **Occurrences** | **Fichiers (lignes)** |
| --- | --- | --- |
| **`getTodaySteps()`** (sum steps du jour) | **4×** | `live_step_monitor.dart:226` (post-collect), `:90` (start), `:226` (reconcile bind), `today_cubit.dart:524` (refresh `Future.wait`) |
| **`getBaseline(phone)`** | **6×** | `live_step_monitor.dart:316` via `beginReconcile`, `background_collector.dart:99` ×2 sources (phone + wearable), `live_step_monitor.dart:227`, `:89`, `:227` |
| **`getGoalForLocalDay(today)`** | **2×** | `today_cubit.dart:525` (`Future.wait` refresh) + `:860` (1 des 7 dans `_loadWeekDays`) — requête journal identique pour le jour courant |
| **`query timeseries_samples` (fenêtre jour)** | **3×** | `getTodaySteps` (×4 ci-dessus), `getTodayActiveBuckets` (`today_cubit.dart:527`), `getChartDailyAggregates` (`today_cubit.dart:852`) — requêtes distinctes mais chevauchement de données |

**Synthèse** : le cold start exécute `getTodaySteps()` **4 fois de suite** (séquentiel entre phases B et C), puis une **5e lecture logique** en parallèle dans le `Future.wait` du refresh — alors que les 3 premières ont déjà lu SQLite dans les 5 secondes précédentes. C’est le principal point de contention lecture sur `timeseries_samples` au démarrage.