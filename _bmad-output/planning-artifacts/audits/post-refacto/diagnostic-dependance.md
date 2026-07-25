# **Diagnostic de dépendances**

Périmètre analysé : `lib/presentation/cubits/*_cubit.dart`, `lib/core/services/*.dart`, `lib/presentation/screens/app_scaffold.dart`.

**Note transversale :** les cubits n'importent presque jamais `lib/data/repositories/` directement — ils passent par `lib/data/contracts/`. Les dépendances repository y sont injectées au constructeur sous forme de contrats (`*RepositoryContract`). Seuls `today_cubit.dart` et `profile_cubit.dart` importent un service directement.

---

## **Couche Cubits**

| **Fichier** | **Import (`repositories/` ou `services/`)** | **Type d'usage** | **Accès** | **Instanciation** |
| --- | --- | --- | --- | --- |
| `history_cubit.dart` | — | — | Dépend de `StepAggregationRepositoryContract` + `UserHealthMetricsRepositoryContract` via `contracts.dart` (lecture seule) | Injecté constructeur — jamais `new` |
| `locale_cubit.dart` | — | — | `UserSettingsRepositoryContract` (écriture : locale) | Injecté constructeur |
| `my_data_cubit.dart` | — | — | `StepAggregationRepositoryContract` (lecture), `StepIngestionRepositoryContract` (écriture : `purge`), `UserSettingsRepositoryContract` (lecture), `UserHealthMetricsRepositoryContract` (écriture : goal, display name), `CsvServiceContract` (lecture/écriture import/export) | Injecté constructeur |
| `onboarding_cubit.dart` | — | — | `UserSettingsRepositoryContract` (écriture), `UserHealthMetricsRepositoryContract` (écriture) | Injecté constructeur |
| `profile_cubit.dart` | `core/services/notification_service.dart` | Lecture seule (`hasNotificationPermission`) | `NotificationService` : injecté constructeur (`required this.notificationService`) | Service injecté ; `UserSettings` / `UserHealthMetrics` via contrats constructeur |
| `theme_cubit.dart` | — | — | `UserSettingsRepositoryContract` (écriture : thème, accent) | Injecté constructeur |
| `today_cubit.dart` | `core/services/live_step_monitor.dart` | Lecture seule (stream pas, `currentTodaySteps`, `isRunning`) | `LiveStepMonitor` : passé en paramètre de `attachLiveMonitor()` → champ `_attachedMonitor` (pas via DI constructeur) | Monitor injecté par l'appelant ; repos via contrats constructeur |
| `units_cubit.dart` | — | — | `UserSettingsRepositoryContract` (écriture : unités d'affichage) | Injecté constructeur |

### **Détail des contrats repository (cubits sans import direct)**

| **Cubit** | **Repository (contrat)** | **Lecture** | **Écriture** | **Accès** |
| --- | --- | --- | --- | --- |
| `TodayCubit` | `StepAggregationRepositoryContract` | `getTodaySteps`, agrégats, buckets, `getLastIngestionUtc` | — | Constructeur |
|  | `UserSettingsRepositoryContract` | `getLastDisplayedSteps`, `isDatabaseOpen` | `setLastDisplayedSteps`, `tryClaimCelebrationShownDate` | Constructeur |
|  | `UserHealthMetricsRepositoryContract` | `getGoalForLocalDay`, `getHeightCm`, `getWeightKg` | `setDailyStepGoal` | Constructeur |
| `HistoryCubit` | `StepAggregationRepositoryContract` | agrégats journaliers/mensuels, buckets actifs, `clock` | — | Constructeur |
|  | `UserHealthMetricsRepositoryContract` | `getGoalsForLocalDays`, `getGoalForLocalDay`, taille/poids | — | Constructeur |
| `MyDataCubit` | `StepAggregationRepositoryContract` | footprint, count, `getLastIngestionUtc` | — | Constructeur |
|  | `StepIngestionRepositoryContract` | — | `purge` | Constructeur |
|  | `UserSettingsRepositoryContract` | `getLastDatabaseOptimizedAt` | — | Constructeur |
|  | `UserHealthMetricsRepositoryContract` | — | `setDailyStepGoal`, `setDisplayName` | Constructeur |
| `ProfileCubit` | `UserSettingsRepositoryContract` | `getGoalNotificationsEnabled` | `setGoalNotificationsEnabled` | Constructeur |
|  | `UserHealthMetricsRepositoryContract` | display name, taille, poids | mêmes champs | Constructeur |
| `OnboardingCubit` | `UserSettingsRepositoryContract` | — | `setOnboardingComplete` | Constructeur |
|  | `UserHealthMetricsRepositoryContract` | — | goal, poids, taille | Constructeur |
| `LocaleCubit` | `UserSettingsRepositoryContract` | — | `setAppLocale`, `clearAppLocale` | Constructeur |
| `UnitsCubit` | `UserSettingsRepositoryContract` | — | unités distance/poids/taille | Constructeur |
| `ThemeCubit` | `UserSettingsRepositoryContract` | — | `setThemeMode`, `setAccentPreset` | Constructeur |

**Instanciation directe dans les cubits :** aucune. Tous les repositories passent par l'injection constructeur (contrats).

---

## **Couche Services**

| **Fichier** | **Import** | **Type d'usage** | **Accès** | **Instanciation** |
| --- | --- | --- | --- | --- |
| `app_lifecycle_coordinator.dart` | `core/services/live_step_monitor.dart` | Lecture/écriture orchestrée (reconcile, reset jour, drain vers collector) | `LiveStepMonitor` via `AppDependencies` getter (`depsGetter()`) | Monitor injecté par DI — pas de `new` |
| `background_collector.dart` | `ingestion_baseline_repository.dart` | Lecture + écriture (`getBaseline`, `setBaseline`) | Constructeur (`baselineRepository`) | Injecté |
|  | `step/step_aggregation_repository.dart` | Lecture (`getTodaySteps`) | Constructeur (`stepAggregation`) | Injecté |
|  | `step/step_ingestion_repository.dart` | Écriture (`upsertIngestionBucket`) | Constructeur (`repository`) | Injecté |
|  | `user_health_metrics_repository.dart` | Lecture (`getGoalForLocalDay`) | Constructeur optionnel (`userHealthMetrics`) | Injecté |
|  | `user_settings_repository.dart` | Lecture + écriture (prefs notifications objectif, dédup) | Constructeur optionnel (`userSettings`) | Injecté |
|  | `notification_service.dart` | Écriture (`showGoalReached`) + lecture implicite (permission) | Constructeur optionnel (`notificationService`) | Injecté |
| `background_collector_factory.dart` | 5 repositories + `notification_service.dart`, `background_collector.dart` | Factory complète ingestion + notifications | Paramètres optionnels ; sinon `new` | **`new` direct** : `StepIngestionRepository(db)`, `StepAggregationRepository(db)`, `IngestionBaselineRepository(db)`, `UserSettingsRepository(session)`, `UserHealthMetricsRepository(session)`, `NotificationService()` (fallback) |
| `data_lifecycle_service.dart` | `step/step_aggregation_repository.dart` | Écriture (`downsampleStepSamples`) | Constructeur (`_repository`) + **`new`** dans `_runFileMaintenanceIsolate` | UI : injecté ; isolate maintenance : **`StepAggregationRepository(db, clock: clock)`** |
|  | `user_settings_repository.dart` | Lecture + écriture (timestamp maintenance) | Constructeur (`_userSettings`) + **`new`** dans isolate | UI : injecté ; isolate : **`UserSettingsRepository(db)`** |
| `fgs_step_collection.dart` | `background_collector_factory.dart`, `notification_service.dart`, `workmanager_callback.dart` | Orchestration collecte FGS | Paramètres optionnels passés à la factory | Pas d'instanciation locale de repo |
| `health_foreground_service.dart` | `fgs_step_collection.dart` | Délégation collecte | Callback `collectionRunner` (souvent `BackgroundCollector.collectOnce`) | Pas d'import repo |
| `live_step_monitor.dart` | `ingestion_baseline_repository.dart` | Lecture (`getBaseline`) | Constructeur (`baselineRepository`) | Injecté |
|  | `step/step_aggregation_repository.dart` | Lecture (`getTodaySteps`) | Constructeur (`stepAggregation`) | Injecté |
| `notification_service.dart` | — | — | — | Peut être `new` dans `main.dart` et `background_collector_factory` |
| `workmanager_callback.dart` | `step/step_aggregation_repository.dart`, `user_settings_repository.dart` | Maintenance DB | **`new`** dans `runDatabaseMaintenanceWorkmanagerTask` | **`StepAggregationRepository(db)`, `UserSettingsRepository(db)`** |
|  | `background_collector_factory.dart`, `data_lifecycle_service.dart`, `notification_service.dart` | Collecte + maintenance WM | Factory + service créés dans le callback isolate | Repos via factory (`new`) |
| `ingestion_collection_lock.dart` | — | — | — | — |
| `workmanager_tasks.dart` | — | Constantes uniquement | — | — |
| `health_foreground_notification.dart` | — | — | — | — |
| `fgs_step_collection.dart` | (voir ci-dessus) |  |  |  |

### **Instanciations directes de repositories (hors DI UI)**

| **Site** | **Repositories instanciés** | **Contexte** |
| --- | --- | --- |
| `background_collector_factory.dart` | 5 repos concrets + `NotificationService()` fallback | Isolates WorkManager / FGS — connexion DB éphémère |
| `data_lifecycle_service.dart` (`_runFileMaintenanceIsolate`) | `StepAggregationRepository`, `UserSettingsRepository` | Isolate `compute` pour VACUUM |
| `workmanager_callback.dart` | `StepAggregationRepository`, `UserSettingsRepository` | Tâche maintenance WorkManager |

L'UI partage une seule instance par repo via `AppDependencies.create()` ; les isolates background créent leurs propres instances sur la même base fichier.

---

## **Couche Screens**

| **Fichier** | **Import (`repositories/` ou `services/`)** | **Type d'usage** | **Accès** | **Instanciation** |
| --- | --- | --- | --- | --- |
| `app_scaffold.dart` | — | Pas d'import direct repo/service | Accès via **`widget.deps`** (getter `AppDependencies`) : `userSettings`, `liveStepMonitor`, `backgroundCollector`, `dataLifecycleService`, repos passés aux cubits | Cubits créés avec `widget.deps.*` ; pas de `new` repository dans l'écran |

### **Usage indirect notable dans `app_scaffold.dart`**

| **Dépendance (via `deps`)** | **Opération** | **Type** |
| --- | --- | --- |
| `userSettings` | `clearLastDisplayedSteps()` (post-purge) | Écriture |
| `liveStepMonitor` | `reconcileFromDatabase()`, `currentTodaySteps` | Lecture + reconcile |
| `backgroundCollector` | `registerOnIngestionComplete` | Callback |
| `dataLifecycleService` | `runMaintenance(force: true)` (post-purge) | Écriture (downsample/VACUUM) |
| Repos passés aux cubits | `stepAggregation`, `userSettings`, `userHealthMetrics`, `stepIngestion`, `csvService`, `notificationService` | Mix R/W selon cubit |

---

## **Risques de split**

Repositories (ou services partagés) référencés par **3+ consommateurs** dans le périmètre, avec type d'accès par consommateur.

### **`UserSettingsRepository` — 12 consommateurs**

| **Consommateur** | **Accès** | **Lecture** | **Écriture** |
| --- | --- | --- | --- |
| `TodayCubit` | Constructeur (contrat) | `getLastDisplayedSteps`, `isDatabaseOpen` | `setLastDisplayedSteps`, `tryClaimCelebrationShownDate` |
| `ProfileCubit` | Constructeur | `getGoalNotificationsEnabled` | `setGoalNotificationsEnabled` |
| `MyDataCubit` | Constructeur | `getLastDatabaseOptimizedAt` | — |
| `LocaleCubit` | Constructeur | — | locale app |
| `UnitsCubit` | Constructeur | — | unités affichage |
| `ThemeCubit` | Constructeur | — | thème, accent |
| `OnboardingCubit` | Constructeur | — | `setOnboardingComplete` |
| `BackgroundCollector` | Constructeur | prefs notifications | dédup notification objectif |
| `DataLifecycleService` | Constructeur + `new` (isolate) | `getLastDatabaseOptimizedAt` | `setLastDatabaseOptimizedAt` |
| `background_collector_factory` | `new` | — | — (passe au collector) |
| `workmanager_callback` | `new` (maintenance) | — | — (passe au service) |
| `AppScaffold` | Getter `deps.userSettings` | — | `clearLastDisplayedSteps` |

**Risque d'incohérence si split :** prefs UI (célébration in-app, `lastDisplayedSteps`, thème, locale…) et prefs background (dédup notification objectif, timestamp maintenance) partagent le même store. Un split sans bus d'événements ou cache partagé peut désynchroniser Today (célébration) vs BackgroundCollector (notification), ou My Data (dernière optimisation) vs maintenance isolate.

---

### **`StepAggregationRepository` — 9 consommateurs**

| **Consommateur** | **Accès** | **Lecture** | **Écriture** |
| --- | --- | --- | --- |
| `TodayCubit` | Constructeur | steps du jour, agrégats, buckets, stale | — |
| `MyDataCubit` | Constructeur | footprint, count, ingestion | — |
| `HistoryCubit` | Constructeur | agrégats 7/30j, mensuels, buckets | — |
| `LiveStepMonitor` | Constructeur | `getTodaySteps` | — |
| `BackgroundCollector` | Constructeur | `getTodaySteps` (notif objectif) | — |
| `DataLifecycleService` | Constructeur + `new` (isolate) | — | `downsampleStepSamples` |
| `background_collector_factory` | `new` | — | — |
| `workmanager_callback` | `new` (maintenance) | — | via `DataLifecycleService` |
| `AppScaffold` | Getter `deps` → cubits + monitor | indirect | `runMaintenance` post-purge |

**Risque :** lectures temps réel (Today/Monitor) vs écriture maintenance (downsample/VACUUM) sur la même abstraction. Split read/write exigerait invalidation explicite des caches cubit (`_cachedAggregates30d`, `_todaySteps`, etc.).

---

### **`UserHealthMetricsRepository` — 7 consommateurs**

| **Consommateur** | **Accès** | **Lecture** | **Écriture** |
| --- | --- | --- | --- |
| `TodayCubit` | Constructeur | goal, taille, poids | `setDailyStepGoal` |
| `ProfileCubit` | Constructeur | profil | display name, taille, poids |
| `MyDataCubit` | Constructeur | — | `setDailyStepGoal`, `setDisplayName` |
| `HistoryCubit` | Constructeur | goals par jour, taille, poids | — |
| `OnboardingCubit` | Constructeur | — | goal initial, taille, poids |
| `BackgroundCollector` | Constructeur | `getGoalForLocalDay` | — |
| `background_collector_factory` | `new` | — | — |

**Risque :** **double chemin d'écriture du goal** — `TodayCubit.updateDailyStepGoal` et `MyDataCubit.updateDailyStepGoal` écrivent tous deux dans le même repo ; `ProfileCubit` / `MyDataCubit` écrivent le display name. Split sans source de vérité unique → états cubit divergents après écriture croisée.

---

### **`IngestionBaselineRepository` — 3 consommateurs**

| **Consommateur** | **Accès** | **Lecture** | **Écriture** |
| --- | --- | --- | --- |
| `LiveStepMonitor` | Constructeur | `getBaseline` | — |
| `BackgroundCollector` | Constructeur | `getBaseline` | `setBaseline` |
| `background_collector_factory` | `new` | — | — |

**Risque :** monitor lit la baseline en mémoire ; collector écrit la baseline persistée. Split sans synchronisation → lectures gated (`drainReadingsForCollectionGated`) et normalisation incohérentes.

---

### **`StepIngestionRepository` — 3 consommateurs**

| **Consommateur** | **Accès** | **Lecture** | **Écriture** |
| --- | --- | --- | --- |
| `MyDataCubit` | Constructeur | — | `purge` |
| `BackgroundCollector` | Constructeur | — | `upsertIngestionBucket` |
| `background_collector_factory` | `new` | — | — |

**Risque :** purge UI (`MyDataCubit`) concurrente avec ingestion background (`BackgroundCollector`) sur les mêmes buckets — déjà sensible aujourd'hui ; un split aggraverait sans verrou transactionnel partagé (`IngestionCollectionLock` est local au collector).

---

### **`NotificationService` — 5+ consommateurs (service, hors repo mais critique pour split services)**

| **Consommateur** | **Accès** | **Usage** |
| --- | --- | --- |
| `ProfileCubit` | Constructeur | permission notifications |
| `BackgroundCollector` | Constructeur optionnel | `showGoalReached` |
| `background_collector_factory` | param ou `new` | init background |
| `workmanager_callback` | param → factory | collecte WM |
| `fgs_step_collection.dart` | param → factory | collecte FGS |

**Risque :** deux chemins d'init (`initialize()` UI vs `initializeForBackground()` isolate) ; split sans instance singleton ou facade → course sur le canal Android déjà documentée (`cancelStepCollectionWorkmanager` avant init UI).

---

## **Synthèse architecture**

UI isolateBackground isolatesnew instancesnew instancesnew instancesattachLiveMonitorStepAggregation contractautresUserSettings contractUserHealthMetrics contractStepAggregationRepositoryUserSettingsRepositoryIngestionBaselineRepositoryAppScaffoldTodayCubitHistoryCubitMyDataCubitProfileCubitAppDependenciesLiveStepMonitorBackgroundCollectorDataLifecycleServicebackground_collector_factoryworkmanager_callback

**Points clés pour un refactor / split :**

1. Les cubits sont déjà découplés des implémentations concrètes (contrats) — le risque est surtout **multi-écriture** (`UserHealthMetrics`, `UserSettings`) et **multi-instance** (UI vs isolates).
2. Les seules instanciations directes de repositories dans le périmètre services sont dans les **chemins isolate** (`background_collector_factory`, `data_lifecycle_service`, `workmanager_callback`).
3. `TodayCubit` + `HistoryCubit` + `MyDataCubit` partagent `StepAggregationRepository` en lecture — tout split doit prévoir une stratégie d'invalidation croisée (callbacks déjà partiellement en place via `AppScaffold._onIngestionComplete` et `postGoalUpdate`).