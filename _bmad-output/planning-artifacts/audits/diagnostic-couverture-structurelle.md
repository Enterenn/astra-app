# Diagnostic de couverture structurelle

**Méthode :** analyse statique uniquement (aucun test exécuté).

**Critère « testée » :** le nom de la méthode apparaît comme identifiant entier (`\bnom\b`) dans au moins un fichier sous `test/`.

**Type de test :**

- **unit** — au moins un fichier test sans `sqflite_common_ffi` ni `sqflite_test_helper`
- **integ** — uniquement des fichiers avec SQLite FFI
- **unit+integ** — les deux

**Protected** = `@visibleForTesting` (Dart n'a pas de `protected` natif).

**Limites connues :** faux positifs sur noms génériques (`refresh`, `start`, `close`…) ; faux négatifs si un chemin est exercé indirectement sans citer le nom (ex. `maybeNotifyGoalReachedIfGoalMet` via `collectOnce(enableGoalNotification: true)`).

---

## **`lib/core/services/`**

### **`app_lifecycle_coordinator.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `shouldTriggerStalenessPersist` | oui | integ | n/a |
| `shouldRunResumePhoneCatchUp` | oui | integ | n/a |
| `shouldRunResumePhonePeek` | oui | integ | n/a |
| `runSerializedLifecycleTransition` | oui | unit | **oui** (transition précédente en échec) |
| `AppLifecycleCoordinator` — `foregroundBackfill` (getter) | oui | unit | n/a |
| `bindToWidget` | oui | unit | n/a |
| `bindTodayCubit` | non | non testée | n/a |
| `bindHistoryCubit` | non | non testée | n/a |
| `bindMyDataCubit` | non | non testée | n/a |
| `onTodayCubitReady` | non | non testée | n/a |
| `onHistoryCubitReady` | non | non testée | n/a |
| `onMyDataCubitReady` | oui | integ | n/a |
| `onLifecycleStatePaused` | oui | unit | n/a |
| `onLifecycleStateResumed` | non | non testée | **non** (`_resumeLivePipeline` : `catch` jamais forcé) |
| `enqueuePersistCycleForTest` | oui | unit | n/a |
| `runLocalDayBoundaryIfNeededForTest` | oui | unit | n/a |
| `dispose` | non | non testée | n/a |
| `deps` (getter) | oui | unit+integ | n/a |

### **`background_collector.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `registerOnIngestionComplete` | oui | integ | n/a |
| `collectOnce` | oui | unit+integ | **oui** (erreur source isolée, collecte continue) |
| `maybeNotifyGoalReachedIfGoalMet` | non* | non testée | n/a |
- Exercée indirectement par `collectOnce(enableGoalNotification: true)` dans `background_collector_test.dart`, mais le nom n'apparaît pas dans `test/`.

### **`background_collector_factory.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `createIsolateBackgroundCollector` | non* | non testée | n/a |
- Appelée par `runFgsStepCollectionCycle` / `runStepCollectionWorkmanagerTask` en prod, sans occurrence du nom dans les tests.

### **`data_lifecycle_service.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `runMaintenanceOnConnection` | oui | integ | n/a |
| `DataLifecycleService.isMaintenanceDue` | oui | integ | n/a |
| `DataLifecycleService.runMaintenance` | oui | integ | n/a |
| `runPragmaOptimizeAndVacuumOnWorkerIsolate` | oui | integ | n/a |
| `runPragmaOptimizeAndVacuum` | non | non testée | n/a |

### **`fgs_step_collection.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `runFgsStepCollectionCycle` | oui | integ | **non** (`catch` global jamais forcé) |

### **`health_foreground_notification.dart`**

Aucune méthode — constantes uniquement.

### **`health_foreground_service.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `isUiActive` (getter) | non | non testée | n/a |
| `registerPlatformHandlers` | oui | unit | n/a |
| `startHealthCollectionService` | oui | unit | **non** (`on PlatformException`) |
| `stopHealthCollectionService` | oui | unit | **non** (`on PlatformException`) |
| `isHealthCollectionServiceRunning` | oui | unit | **non** (retour `false` sur exception) |
| `setUiActive` | oui | unit | **non** (`on PlatformException`) |

### **`ingestion_collection_lock.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `tryAcquire` | oui | integ | n/a |
| `release` | oui | integ | n/a |

### **`live_step_monitor.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `isRunning` / `currentTodaySteps` / `trackedLocalDay` | oui | integ | n/a |
| `watchTodaySteps` | oui | integ | n/a |
| `start` | oui | unit+integ | **non** (`onError` flux pedomètre) |
| `stop` | oui | unit+integ | n/a |
| `peekPhoneStepEvent` | oui | integ | **non** (`onError`, `TimeoutException`) |
| `beginReconcile` / `endReconcile` | oui | integ | n/a |
| `reconcileFromDatabase` | oui | integ | n/a |
| `resetForNewLocalDay` | oui | integ | n/a |
| `enqueueReadingForCollection` | non | non testée | n/a |
| `drainReadingsForCollectionGated` | oui | integ | n/a |
| `drainReadingsForCollection` | oui | integ | n/a |
| `dispose` | oui | unit+integ | n/a |

### **`notification_service.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `initialize` | oui | unit+integ | **non** (`catch` init plateforme) |
| `initializeForBackground` | oui | unit | **oui** (timeout) |
| `hasNotificationPermission` | oui | unit | n/a |
| `showGoalReached` | oui | unit | **non** (`catch` présentation) |

### **`workmanager_callback.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `callbackDispatcher` | oui | integ | n/a |
| `handleWorkmanagerTask` | non | non testée | n/a |
| `runStepCollectionWorkmanagerTask` | oui | integ | **oui** (échec avant ouverture DB) |
| `runDatabaseMaintenanceWorkmanagerTask` | oui | integ | **oui** (`databasePath` manquant) |
| `cancelStepCollectionWorkmanager` | oui | integ | n/a |
| `registerStepCollectionWorkmanager` | oui | integ | n/a |
| `registerDatabaseMaintenanceWorkmanager` | oui | integ | n/a |
| `PluginStepCollectionWorkmanagerClient.initialize` | oui | unit+integ | n/a |
| `cancelByUniqueName` / `registerPeriodicTask` | oui | integ | n/a |

### **`workmanager_tasks.dart`**

Constantes uniquement — pas de méthodes.

---

## **`lib/presentation/cubits/`**

### **`today_cubit.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `todayEditableGoal` | oui | integ | n/a |
| `liveStepAppliesPaused` | non | non testée | n/a |
| `setLiveStepAppliesPaused` | non | non testée | n/a |
| `attachLiveMonitor` | oui | integ | n/a |
| `updateDailyStepGoal` | oui | integ | **oui** (`postGoalUpdate` en échec) |
| `refresh` | oui | unit+integ | n/a |
| `syncSteps` | oui | integ | n/a |
| `clearForegroundCatchUp` | oui | integ | n/a |
| `recordLastDisplayedSteps` | oui | integ | **non** (`on DatabaseException` silencieux) |
| `refreshAfterDayRollover` | non | non testée | n/a |
| `refreshMetadata` | oui | integ | n/a |
| `selectLocalDay` | oui | integ | n/a |
| `dismissCelebration` | oui | integ | n/a |
| `close` | oui | unit+integ | n/a |

### **`history_cubit.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `refresh` | oui | unit+integ | **oui** (repo qui throw, recovery cache) |
| `refreshGoal` | oui | integ | **non** (`catch` sur lecture prefs) |
| `selectPeriod` | oui | unit+integ | n/a |

### **`profile_cubit.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `refresh` | oui | unit+integ | **non** (`catch` → `ProfileStatus.error`) |
| `updateDisplayName` | oui | integ | **non** |
| `updateHeightCm` | oui | integ | **non** |
| `updateWeightKg` | oui | integ | **non** |
| `setGoalNotificationsEnabled` | oui | integ | **non** (permission + persist) |

### **`my_data_cubit.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `pickAndImport` | oui | integ | **oui** (validation + générique) |
| `exportAndShare` | oui | integ | **oui** |
| `ackExportSuccess` / `ackImportSuccess` / `ackPurgeSuccess` | non | non testée | n/a |
| `confirmAndPurge` | oui | integ | **oui** |
| `updateDailyStepGoal` | oui | integ | **oui** |
| `updateDisplayName` | oui | integ | **non** |
| `refresh` | oui | unit+integ | **oui** (recovery partiel) |

### **`onboarding_cubit.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `nextStep` / `previousStep` | oui | integ | n/a |
| `setWeightKg` / `setHeightCm` | oui | integ | n/a |
| `setWeightDisplayUnit` | oui | integ | n/a |
| `setHeightUsesInches` | non | non testée | n/a |
| `skipWeight` / `skipHeight` | oui | integ | n/a |
| `commitWeightAndContinue` | oui | integ | n/a |
| `completeWithHeight` | oui | integ | n/a |
| `requestActivityPermission` | oui | integ | **partiel** (denied mappé ; `catch` sur throw permission non) |

### **`theme_cubit.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `setThemePreference` | oui | integ | n/a |
| `setAccentPreset` | oui | integ | n/a |

### **`units_cubit.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `setDistanceUnit` / `setWeightUnit` / `setHeightUnit` | oui | integ | **oui** (write failed) |

### **`locale_cubit.dart`**

| **Méthode** | **Testée** | **Type de test** | **Gestion erreur testée** |
| --- | --- | --- | --- |
| `setLanguage` | non | non testée | n/a |
| `setLanguagePreference` | non | non testée | **non** (`catch` persist) |

### **Fichiers état / erreurs (getters uniquement)**

| **Fichier** | **Méthode** | **Testée** | **Type** | **Gestion erreur** |
| --- | --- | --- | --- | --- |
| `history_state.dart` | `dayCount` | oui | unit+integ | n/a |
| `locale_state.dart` | `materialLocale` | oui | unit | n/a |
| `my_data_state.dart` | `isStale` | oui | unit+integ | n/a |
| `theme_state.dart` | `materialThemeMode` | oui | integ | n/a |
| `today_state.dart` | `progressRatio` | oui | integ | n/a |
| `profile_errors.dart`, `my_data_errors.dart`, `onboarding_state.dart`, `profile_state.dart`, `units_state.dart` | — | — | pas de méthode testable | — |

---

## **Gestion d'erreur jamais exercée en test (synthèse ciblée)**

Chemins `catch` / `onError` / `on PlatformException` présents dans le code source mais **sans test qui force l'échec** :

| **Zone** | **Handler** | **Impact** |
| --- | --- | --- |
| `AppLifecycleCoordinator` | `_resumeLivePipeline` → `catch` | Reprise foreground après lock — chemin critique lifecycle |
| `runFgsStepCollectionCycle` | `catch` global | Collecte FGS en arrière-plan |
| `HealthForegroundServiceCoordinator` | `PlatformException` sur start/stop/setUiActive | Coordination FGS Android |
| `LiveStepMonitor.start` | `onError` flux | Perte silencieuse du stream pedomètre |
| `LiveStepMonitor.peekPhoneStepEvent` | `onError`, `TimeoutException` | Catch-up téléphone au resume |
| `NotificationService` | `initialize` / `showGoalReached` catch | Notifications objectif |
| `ProfileCubit` | tous les `catch` de persist | Écran profil en erreur de chargement |
| `HistoryCubit.refreshGoal` | `catch` | Mise à jour objectifs Trends |
| `TodayCubit` | `DatabaseException` dans persist lastDisplayed | Affichage GoalRing |
| `LocaleCubit` | `catch` persist locale | Préférence langue |

Handlers **couvertes** : `runSerializedLifecycleTransition`, `BackgroundCollector` erreur source, `initializeForBackground` timeout, `runStepCollectionWorkmanagerTask` / `runDatabaseMaintenanceWorkmanagerTask`, erreurs import/export/purge My Data, `UnitsCubit` write failed, `HistoryCubit.refresh` recovery, `TodayCubit.updateDailyStepGoal` postGoalUpdate failed.

---

## **Synthèse — Top 5 méthodes non testées à fort impact stabilité**

Priorisation : **chemin cold start / lifecycle** (+ bonus si gestion d'erreur non couverte).

| **Rang** | **Méthode** | **Fichier** | **Pourquoi** |
| --- | --- | --- | --- |
| **1** | `onLifecycleStateResumed` | `app_lifecycle_coordinator.dart` | Orchestration complète du resume (persist, FGS stop, `_resumeLivePipeline`, sync cubits). Exercée au niveau widget (`AppLifecycleState.resumed`) mais **jamais par nom** ; le `catch` du pipeline resume est **non testé**. |
| **2** | `onTodayCubitReady` | `app_lifecycle_coordinator.dart` | Point d'entrée cold start du live pipeline (`_ensureLivePipelineAttached` → backfill → bind monitor). Absent de `test/` ; branche centrale du démarrage UI. |
| **3** | `maybeNotifyGoalReachedIfGoalMet` | `background_collector.dart` | Notification objectif hors app (FGS/WM/pause). Logique FR-25 + rollback prefs si `showGoalReached` échoue — **aucune occurrence du nom** dans les tests. |
| **4** | `createIsolateBackgroundCollector` | `background_collector_factory.dart` | Bootstrap partagé WorkManager + FGS (sources, notifications background, repos). Unique factory isolate-safe ; **jamais ciblé directement**. |
| **5** | `refreshAfterDayRollover` | `today_cubit.dart` | Reset UI minuit (catch-up, célébration, refresh SQLite). Appelé par `_runLocalDayBoundaryImpl` ; day-rollover monitor testé, **pas ce contrat cubit**. |

**Mentions proches :** `setLiveStepAppliesPaused` (pause live pendant lock écran, couplé au resume) ; `enqueueReadingForCollection` (phone peek au resume) ; `handleWorkmanagerTask` (dispatcher WM) ; `LocaleCubit.setLanguagePreference` (settings, zéro test nominal).

---

## **Chiffres globaux (ordre de grandeur)**

| **Périmètre** | **Méthodes publiques/protected** | **Non testées (nom)** | **Couverture nominale** |
| --- | --- | --- | --- |
| `lib/core/services/` (hors constantes) | ~55 | ~12 | ~78 % |
| `lib/presentation/cubits/` (hors états vides) | ~45 | ~10 | ~78 % |

**Biais integ :** une large part des cubits et services DB ne sont couverts que via SQLite FFI (`units_cubit_test`, `theme_cubit_test`, `profile_cubit_test`, `data_lifecycle_service_test`, etc.) — peu de tests purement mockés hors couche persistance.