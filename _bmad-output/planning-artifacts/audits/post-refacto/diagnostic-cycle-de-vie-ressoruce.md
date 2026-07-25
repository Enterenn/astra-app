# **Diagnostic cycle de vie des ressources**

Périmètre analysé : **14 StatefulWidget** (`lib/presentation/widgets/` + `lib/presentation/screens/`), **12 fichiers** dans `lib/core/services/`. Types ciblés : `AnimationController`, `Timer`, `StreamSubscription`, `ChangeNotifier`.

**Synthèse** : aucun `ChangeNotifier` déclaré dans ce périmètre. Aucune classe ne présente **3+ ressources non disposées**. Les widgets à forte densité de ressources (`GoalRing`, `GoalCelebration`) gèrent correctement le nettoyage dans `dispose()`. Les points d’attention portent surtout sur des patterns **asynchrones** ou **conditionnels**.

---

## **`lib/presentation/screens/`**

### **`AppScaffold` / `_AppScaffoldState`**

| **Ressource** | **Type** | **Initialisée dans** | **Disposée dans** | **Risque** |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

Aucun champ des 4 types ciblés. Les `TodayCubit` / `HistoryCubit` / etc. sont fermés via `.close()` dans `dispose()` (lignes 223–226). La `StreamSubscription` live vit dans `TodayCubit.attachLiveMonitor()` (hors périmètre widget, mais bien annulée dans `TodayCubit.close()`).

Les 7 autres écrans sont des `StatelessWidget`.

---

## **`lib/presentation/widgets/`**

### **`GoalRing` / `_GoalRingState`**

| **Ressource** | **Type** | **Initialisée dans** | **Disposée dans** | **Risque** |
| --- | --- | --- | --- | --- |
| `_pulseController` | `AnimationController?` | `didChangeDependencies` → `_syncPulseAnimation()` | `dispose()` → `_releasePulseController()` ; aussi libéré quand pulse désactivé | **non** |
| `_countUpController` | `AnimationController?` | `_runCountUp()` (post-`initState`, callbacks) | `_releaseCountUpController()` avant recréation ; `dispose()` | **non** |
| `_microTickController` | `AnimationController?` | `_runMicroTick()` | idem | **non** |
| `_liveArcController` | `AnimationController?` | `_runMicroTick()` | idem | **non** |
| `_overflowController` | `AnimationController?` | `didChangeDependencies` → `_syncOverflowAnimation()` | `_releaseOverflowController()` ; `dispose()` | **non** |
| `_liveCoalesceTimer` | `Timer?` | `_scheduleLiveUpdate()` | `?.cancel()` avant recréation ; `dispose()` | **non** |
| `_foregroundCatchUpTimer` | `Timer?` | `_handleStepChange()` | `?.cancel()` dans `_resetDisplayed()` ; `dispose()` | **non** |

**Notes** : 7 ressources, toutes couvertes. Les contrôleurs d’animation sont recréés hors `initState` mais **toujours précédés** d’un `_release*()`. Les timers sont annulés avant recréation. Cache `GoalRingInsetShadowCache` (hors périmètre) disposé dans `dispose()`.

---

### **`GoalCelebration` / `_GoalCelebrationState`**

| **Ressource** | **Type** | **Initialisée dans** | **Disposée dans** | **Risque** |
| --- | --- | --- | --- | --- |
| `_sequenceController` | `AnimationController?` | `didChangeDependencies` → `_startSequence()` | `dispose()` → `?.dispose()` ; ancien disposé avant recréation (L74) | **non** |
| `_sequenceTimer` | `Timer?` | `_startSequence()` | `?.cancel()` avant recréation ; `dispose()` | **non** |
| `_hapticTimer` | `Timer?` | `_scheduleHaptics()` | `?.cancel()` avant recréation ; `dispose()` | **non** |

**Note** : `_startSequence()` ne s’exécute qu’une fois (`_sequenceStarted`). Si le widget est détruit avant `didChangeDependencies`, `onComplete` n’est pas appelé (comportement voulu).

---

### **`AstraHorizontalRuler` / `_AstraHorizontalRulerState`**

| **Ressource** | **Type** | **Initialisée dans** | **Disposée dans** | **Risque** |
| --- | --- | --- | --- | --- |
| `_pulseController` | `AnimationController` | `initState()` | `dispose()` → `.dispose()` | **non** |
| `_readoutMicroTickController` | `AnimationController?` | `_runReadoutMicroTick()` (scroll / changement valeur) | `_releaseReadoutMicroTick()` avant recréation ; `dispose()` | **non** |

`ScrollController` présent mais hors périmètre — correctement disposé.

---

### **`AstraPressable` / `_AstraPressableState`**

| **Ressource** | **Type** | **Initialisée dans** | **Disposée dans** | **Risque** |
| --- | --- | --- | --- | --- |
| `_controller` | `AnimationController` | `initState()` | `dispose()` → `.dispose()` | **conditionnel** |

**Risque** : `_release()` est `async` (`await _controller.animateTo(...)`). Si le widget est disposé pendant une animation en cours, `animateTo` peut s’exécuter sur un contrôleur déjà disposé. Faible probabilité, pattern classique Flutter.

---

### **`AstraBarChartCore` / `_AstraBarChartCoreState`**

| **Ressource** | **Type** | **Initialisée dans** | **Disposée dans** | **Risque** |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

Pas de `dispose()` — aucune ressource ciblée.

---

### **`AstraInsetShadowSurface` / `_AstraInsetShadowSurfaceState`**

| **Ressource** | **Type** | **Initialisée dans** | **Disposée dans** | **Risque** |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

Cache `ui.Image` via `_InsetShadowCache` (hors périmètre) — disposé dans `dispose()`.

---

### **`_ReadyChart` (`step_bar_chart.dart` et `trends_monthly_bar_chart.dart`)**

| **Ressource** | **Type** | **Initialisée dans** | **Disposée dans** | **Risque** |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

État local `_touchedIndex` uniquement.

---

### **Sheets éditeurs (`_DisplayNameEditorSheetBody`, `_GoalEditorSheetBody`, `_WeightEditorSheetBody`, `_HeightEditorSheetBody`)**

| **Ressource** | **Type** | **Initialisée dans** | **Disposée dans** | **Risque** |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |

`TextEditingController` uniquement (hors périmètre) — tous disposés dans `dispose()`.

---

## **`lib/core/services/`**

### **`LiveStepMonitor`**

| **Ressource** | **Type** | **Initialisée dans** | **Disposée dans** | **Risque** |
| --- | --- | --- | --- | --- |
| `_subscription` | `StreamSubscription<PhoneStepEvent>?` | `start()` | `stop()` → `await ?.cancel()` ; `dispose()` → `unawaited(stop())` | **conditionnel** |
| `_emitTimer` | `Timer?` | `_scheduleEmit()` | `stop()` ; auto-null dans callback | **non** |
| `_activityIdleTimer` | `Timer?` | `_resetActivityIdleTimer()` | `_cancelActivityIdleTimer()` dans `stop()` ; recréé avec `?.cancel()` avant | **non** |
| `_stepsController` | `StreamController<int>` | constructeur | `dispose()` → `.close()` | **non** |

**Subscriptions recréables** :

- `start()` : recrée `_subscription` ; protégé par `if (_running) return` et `stop()` annule l’ancienne.
- `peekPhoneStepEvent()` : subscription locale éphémère, annulée sur event ou timeout.

**Risque conditionnel** : `dispose()` appelle `unawaited(stop())` puis `_stepsController.close()` immédiatement — fenêtre courte où la subscription hardware peut encore être active.

---

### **`AppLifecycleCoordinator`**

| **Ressource** | **Type** | **Initialisée dans** | **Disposée dans** | **Risque** |
| --- | --- | --- | --- | --- |
| `_stalenessPersistTimer` | `Timer?` | `_startActivityBasedPersist()` | `_stopStalenessPersistTimer()` ; `dispose()` → `_stopActivityBasedPersist()` | **non** |
| `_midnightBoundaryTimer` | `Timer?` | `_scheduleMidnightBoundaryTimer()` | `_cancelMidnightBoundaryTimer()` avant recréation ; `dispose()` | **non** |

**Note** : `_scheduleMidnightBoundaryTimer()` annule toujours l’ancien timer avant d’en créer un nouveau.

---

### **Services sans ressources ciblées**

| **Service** | **Ressources ciblées** | **`dispose()`** |
| --- | --- | --- |
| `BackgroundCollector` | aucune | non |
| `NotificationService` | aucune | non |
| `HealthForegroundServiceCoordinator` | aucune (`MethodChannel` handler, hors périmètre) | **non** |
| `DataLifecycleService` | aucune | non |
| `IngestionCollectionLock` | aucune | non |
| `background_collector_factory.dart` | factory | — |
| `fgs_step_collection.dart` | fonction isolée, `db?.close()` en `finally` | — |
| `workmanager_callback.dart` | `db?.close()` en `finally` | — |
| `workmanager_tasks.dart` | constantes | — |
| `health_foreground_notification.dart` | constantes | — |

---

## **Subscriptions hors `initState()` (widgets)**

**Aucune** `StreamSubscription` dans les StatefulWidget du périmètre.

Référence indirecte : `TodayCubit.attachLiveMonitor()` (appelé par `AppLifecycleCoordinator`, pas dans un `initState` widget) annule l’ancienne subscription avant d’en créer une nouvelle, et `close()` nettoie à la destruction de `AppScaffold`.

---

## **Cas critiques**

### **Critère « 3+ ressources non disposées »**

**Aucune classe ne remplit ce critère.** Toutes les ressources identifiées ont un chemin de nettoyage explicite.

### **Classes à surveiller (complexité élevée, pas de fuite avérée)**

| **Classe** | **Ressources** | **Motif** |
| --- | --- | --- |
| **`GoalRing`** | 5 `AnimationController` + 2 `Timer` | Forte densité ; recréation fréquente hors `initState` ; nettoyage centralisé via helpers `_release*()` + asserts debug en `dispose()` |
| **`LiveStepMonitor`** | 1 subscription + 2 timers + 1 `StreamController` | Service long-lived ; `dispose()` asynchrone (`unawaited(stop())`) |
| **`AppLifecycleCoordinator`** | 2 timers périodiques / one-shot | Reschedule fréquent ; pattern cancel-before-recreate correct |

### **Risques résiduels (1–2 ressources, pattern fragile)**

| **Classe** | **Problème** | **Sévérité** |
| --- | --- | --- |
| **`AstraPressable`** | Animation async après `dispose()` possible | Faible |
| **`LiveStepMonitor`** | `dispose()` ne attend pas `stop()` | Faible |
| **`HealthForegroundServiceCoordinator`** | Pas de `dispose()` ; handler `MethodChannel` jamais déréférencé | Faible (cycle de vie app) |

---

## **Recommandations ciblées**

1. **`LiveStepMonitor.dispose()`** — rendre synchrone ou documenter : `await stop()` avant `close()`, ou flag `_disposed` pour bloquer `start()` après destruction.
2. **`AstraPressable._release()`** — tester `if (!mounted) return` avant chaque `animateTo`, ou `stop()` + skip si disposé.
3. **`GoalRing`** — état sain ; conserver le pattern `_release*()` pour toute nouvelle animation.
4. **`HealthForegroundServiceCoordinator`** — ajouter `dispose()` qui fait `_channel.setMethodCallHandler(null)` si l’app peut recréer le coordinator en tests/hot restart.