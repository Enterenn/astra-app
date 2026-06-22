# **Rapport de diagnostic — Cold Start & Performance SQLite**

# **Synthèse exécutive**

Le skeleton de 1–2 s n’est **pas** principalement dû à SQLite en lecture seule. Il vient surtout d’une **chaîne séquentielle bloquante** avant le premier `emit` de `TodayCubit` : ingestion téléphone (jusqu’à ~2 s), démarrage du live monitor, puis un `refresh()` « complet » (aujourd’hui + bandeau semaine + métriques). SQLite contribue via des **requêtes redondantes** et un **N+1 sur les objectifs**, mais le goulot dominant est architectural.

`HistoryCubit` est **déjà partiellement lazy** (pas de `refresh()` au démarrage), mais reste instancié et peut être sollicité indirectement par l’ingestion.

---

## **1. Cartographie du Cold Start**

### **Chronologie observée**

NotificationService.init (timeout 3s)create() — ensureOpen + 7 lectures prefs séquentiellesregisterStepCollection + maintenancerunApp()bindToWidget → _foregroundBackfill = _runPersistCycleTodayCubit créé (état loading)collectOnce (pedometer 2s timeout si monitor arrêté)refresh(silent) après monitor.start + reconcileemit ready (si lastDisplayedStepsLoaded)MainAppDependenciesWorkManagerAstraAppAppLifecycleCoordinatorBackgroundCollectorTodayCubit

### **Avant `runApp()` — `main.dart` + `app_dependencies.dart`**

| **Étape** | **Fichier** | **Nature** | **Impact estimé** |
| --- | --- | --- | --- |
| `NotificationService.initialize()` | `main.dart:17-18` | Plateforme (canal notif) | 0–3000 ms (timeout 3 s) |
| `databaseSession.ensureOpen()` | `app_dependencies.dart:94` | SQLite open + WAL + migrations | 10–100 ms |
| 7 lectures prefs **séquentielles** | `app_dependencies.dart:101-107` | 7× `SELECT` PK | 20–70 ms |
| `migrateGoalNotificationPreferenceIfNeeded` | `main.dart:28-31` | 0–2 lectures + éventuelle écriture | <20 ms |
| `registerStepCollectionWorkmanager` ×2 | `main.dart:34-35` | `Workmanager.initialize` + register | 50–300 ms (Android) |

Aucune lecture de timeseries avant `runApp()`. Seules des prefs utilisateur.

### **Après `runApp()` — premier écran Today**

| **Étape** | **Fichier** | **Bloquant pour le skeleton ?** |
| --- | --- | --- |
| Création eager de 4 cubits | `app_scaffold.dart:76-126` | Non (état initial loading) |
| `_foregroundBackfill` = `_runPersistCycle` | `app_lifecycle_coordinator.dart:180-184` | **Oui** |
| `onTodayCubitReady` → `_startLivePipelineFirstTime` | `app_lifecycle_coordinator.dart:605-631` | **Oui** |
| `TodayCubit.refresh(silent: true)` | `today_cubit.dart:494-596` via `app_lifecycle_coordinator.dart:655` | **Oui** |
| Gate `lastDisplayedStepsLoaded` | `today_cubit.dart:993-997` | **Oui** — GoalRing reste en skeleton |

### **Données globales chargées au démarrage**

| **Donnée** | **Chargée au cold start ?** | **Détail** |
| --- | --- | --- |
| Steps du jour | Oui | `getTodaySteps()` — plusieurs fois |
| Bandeau semaine (7 j) | Oui | `_loadWeekDays()` → `getChartDailyAggregates(days: 7)` |
| Trends 30j / 12 mois | **Non** (onglet Trends) | `HistoryCubit` pas refreshé à l’init |
| Insights Trends | **Non** | Calculés à l’ouverture Trends |
| My Data footprint | **Non** | `MyDataCubit` pas refreshé à l’init |

**Exception indirecte** : si le backfill upsert des buckets, `_onIngestionComplete` déclenche un `HistoryCubit.refresh(silent: true)` en arrière-plan (`app_scaffold.dart:230-233`), même sur l’onglet Today.

---

## **[CRITIQUE] Bloqueurs synchrones détectés**

### **C1 — Backfill ingestion avant affichage des données locales (cause #1)**

app_lifecycle_coordinator.dartLines 180-184

_foregroundBackfill = enableLiveStepPipeline

? _runPersistCycle(enableGoalNotification: false)

: deps.backgroundCollector.collectOnce(

app_lifecycle_coordinator.dartLines 605-614

Future<void> _startLivePipelineFirstTime() async {

...

await _foregroundBackfill;

...

await _bindLiveMonitorToToday();

`_runPersistCycle` appelle `BackgroundCollector.collectOnce` **avant** tout `TodayCubit.refresh`. Or au cold start le monitor n’est pas encore démarré :

monitor_drain_source.dartLines 27-35

Stream<StepReading> watchStepReadings() async* {

if (_monitor.isRunning) {

...

}

yield* _phoneFallback.watchStepReadings();

}

→ Fallback `PhonePedometerSource` + timeout **2 s/source** (`background_collector.dart:31`). C’est cohérent avec un délai de 1–2 s observé **même avec une DB locale instantanée**.

### **C2 — `getTodaySteps()` appelé 4+ fois en série au cold start**

| **#** | **Appel** | **Fichier** |
| --- | --- | --- |
| 1 | `reconcileFromDatabase` dans backfill | `live_step_monitor.dart:221-226` |
| 2 | `monitor.start()` | `live_step_monitor.dart:90` |
| 3 | `reconcileFromDatabase` (bind) | `app_lifecycle_coordinator.dart:650` |
| 4 | `TodayCubit.refresh` | `today_cubit.dart:524` |

Chaque appel lit toutes les rows du jour (~jusqu’à 288 buckets 5 min) et agrège en Dart.

### **C3 — `TodayCubit.refresh()` charge trop pour le premier paint**

today_cubit.dartLines 523-553

final results = await Future.wait<Object?>([

stepAggregation.getTodaySteps(),

_resolveTodayGoal(),

stepAggregation.getLastIngestionUtc(),

stepAggregation.getTodayActiveBuckets(),

userHealthMetrics.getHeightCm(),

userHealthMetrics.getWeightKg(),

userSettings.getLastDisplayedSteps(todayIso),

]);

...

final weekDays = await _loadWeekDays();

7 requêtes parallèles **puis** `_loadWeekDays()` qui ajoute :

- `getChartDailyAggregates(days: 7)` (scan timeseries sur ~8 jours UTC)
- **7×** `getGoalForLocalDay()` individuels (N+1)

### **C4 — Gate UI `lastDisplayedStepsLoaded`**

Le GoalRing reste en skeleton tant que `refresh` n’a pas fini **et** que `lastDisplayedStepsLoaded` n’est pas `true` (`today_cubit.dart:993-997`, `goal_ring.dart:241-242`). Impossible d’afficher les steps SQLite en <100 ms tant que le pipeline complet n’est pas terminé.

### **C5 — Pré-`runApp()` non parallélisé**

- `NotificationService` (jusqu’à 3 s) bloque tout le reste.
- 7 lectures prefs séquentielles au lieu d’un `Future.wait`.
- WorkManager enregistré **avant** `runApp()` alors qu’il n’est pas nécessaire au premier frame.

### **C6 — `HistoryCubit` : lazy partiel, pas complet**

**Bon** : pas de `refresh()` à l’init ; refresh uniquement à l’ouverture Trends (`app_scaffold.dart:250-251`).

**Problème résiduel** :

- Cubit créé eager (`app_scaffold.dart:89-94`) + écran dans `IndexedStack` (widget tree construit).
- Refresh silencieux possible via ingestion (`app_scaffold.dart:230-233`) et resume pipeline (`app_lifecycle_coordinator.dart:490-491`).

### **C7 — Thread UI : pas le goulot principal au cold start**

`trends_insights.dart` : boucles O(30) en pur Dart — **négligeable** (<1 ms).

`DerivedActivityMetrics.compute` sur ~288 buckets/jour : **<5 ms** — pas besoin de `compute()` pour Today.

Le vrai coût CPU/I/O Trends est `_buildDayMetricsCache` : **30 requêtes SQL parallèles** `getActiveBucketsForLocalDay` (`history_cubit.dart:286-291`) — pertinent à l’ouverture Trends, pas au cold start Today.

---

## **[INDEX MANQUANTS] Requêtes sans index optimal**

### **Index existants (`migrations.dart:77-92`)**

migrations.dartLines 77-80

CREATE INDEX IF NOT EXISTS idx_timeseries_query

ON timeseries_samples (type, start_time DESC)

Couvre bien : `getTodaySteps`, charts (`type + start_time >= ?`), buckets actifs (partiellement).

### **Lacunes identifiées**

| **Requête** | **Fichier** | **Problème** | **Impact volume** |
| --- | --- | --- | --- |
| `MAX(end_time) WHERE type = ?` | `step_aggregation_repository.dart:278-284` | Pas d’index sur `end_time` → scan partiel par type | Moyen (croît avec l’historique) |
| `getActiveBucketsForLocalDay` : `type + resolution + value > 0 + start_time range` | `step_aggregation_repository.dart:92-94` | Index `(type, start_time)` ne couvre pas `resolution`/`value` | Moyen (288 rows/jour filtrées en Dart aussi) |
| `getChartDailyAggregates(30/12)` : toutes résolutions, agrégation Dart | `_step_chart_queries.dart:10-15` + `step_aggregation_repository.dart:133-137` | Pas de pré-agrégation SQL ; lit toutes les rows de la fenêtre | **Élevé** à l’ouverture Trends (30j ≈ 9k rows 5min ; 12 mois >> 50k) |
| `getGoalForLocalDay` × N | `today_cubit.dart:858-861` | N requêtes au lieu d’un batch `getGoalsForLocalDays` | Faible–moyen (7 au cold start) |
| `daily_goal_effective` range | `user_health_metrics_repository.dart:42-50` | PK TEXT — OK pour `LIMIT 1` | Faible |

Pas de full table scan pur sur `timeseries_samples` grâce à `idx_timeseries_query`, mais les requêtes chart **lisent tout le volume de la fenêtre** sans filtre `resolution` en SQL.

---

## **[PLAN D'ACTION] Modifications précises (objectif <100 ms premier paint Today)**

### **Phase A — Débloquer le cold start (gain estimé : 1–2 s → 50–150 ms)**

**A1. Inverser l’ordre backfill / affichage SQLite**

Fichier : `lib/core/services/app_lifecycle_coordinator.dart`

- `_startLivePipelineFirstTime` (~L605-631) : **ne plus `await _foregroundBackfill` en premier**.
- Nouveau flux :
    1. `await _todayCubit?.refreshFastPath()` (nouvelle méthode, voir A2)
    2. `unawaited(_foregroundBackfill)` en arrière-plan
    3. Puis `monitor.start()` + `syncSteps` pour overlay live

**A2. Fast path `TodayCubit` — strictement le jour courant**

Fichier : `lib/presentation/cubits/today_cubit.dart`

- Ajouter `refreshFastPath()` (~après L202) avec **3 requêtes max** :
    - `getTodaySteps()`
    - `getGoalForLocalDay(todayIso)` (ou cache depuis prefs)
    - `getLastDisplayedSteps(todayIso)`
- Émettre immédiatement avec `lastDisplayedStepsLoaded: true`, métriques distance-only (`_liveMetricsForSteps`), `weekDays: []` ou placeholders.
- Différer en `unawaited` :
    - `_loadWeekDays()` (~L843)
    - `getTodayActiveBuckets()` + `DerivedActivityMetrics.compute` (~L527-528)
    - `getLastIngestionUtc()` + bannière stale (~L526)

**A3. Supprimer le double/triple `getTodaySteps` au bind**

Fichiers :

- `lib/core/services/app_lifecycle_coordinator.dart` ~L640-676
- `lib/core/services/live_step_monitor.dart` ~L85-90, L221-226

Passer le résultat de `refreshFastPath` au monitor (`start(seedSteps: ...)`) pour éviter relectures.

**A4. Backfill cold start sans pedometer blocking**

Fichier : `lib/core/services/app_lifecycle_coordinator.dart` ~L325-344

Option : au premier lancement, `_runPersistCycle` avec `sourceTimeout: Duration.zero` ou skip sources si monitor pas encore actif — le drain phone n’a rien à drainer de toute façon.

### **Phase B — Optimisations SQLite (gain estimé : 20–80 ms sur refresh complet)**

**B1. Batch goals semaine**

Fichier : `lib/presentation/cubits/today_cubit.dart` ~L858-861

Remplacer les 7 `getGoalForLocalDay` par un seul `userHealthMetrics.getGoalsForLocalDays(weekDayKeys.map(...))`.

**B2. Nouvel index `end_time`**

Fichier : `lib/core/database/migrations.dart` — migration v4

CREATE INDEX IF NOT EXISTS idx_timeseries_last_end

ON timeseries_samples (type, end_time DESC);

**B3. Index buckets actifs (optionnel)**

CREATE INDEX IF NOT EXISTS idx_timeseries_active

ON timeseries_samples (type, resolution, start_time)

WHERE value > 0;

(SQLite partial index si supporté ; sinon composite sans `WHERE`.)

**B4. SQL agrégé pour charts (Trends)**

Fichier : `lib/data/repositories/step/step_aggregation_repository.dart` + `_step_chart_queries.dart`

Ajouter `getChartDailyAggregatesSql` avec `GROUP BY local_day` (ou pré-calcul journalier) pour éviter de ramener 9k+ rows en Dart. Priorité pour l’ouverture Trends, pas le cold start Today.

### **Phase C — Lazy loading Trends (déjà amorcé, à compléter)**

**C1. Création lazy de `HistoryCubit`**

Fichier : `lib/presentation/screens/app_scaffold.dart` ~L66-94, L131-142

- Instancier `HistoryCubit` uniquement au premier `_onDestinationSelected(index == 1)`.
- Remplacer `IndexedStack` fixe par lazy tab (ou `AutomaticKeepAliveClientMixin` + création différée).

**C2. Guard sur refresh ingestion**

Fichier : `lib/presentation/screens/app_scaffold.dart` ~L230-233

void _onIngestionComplete() {

unawaited(_todayCubit.refreshMetadata());

if (_selectedIndex == 1) unawaited(_historyCubit.refresh(silent: true));

...

}

**C3. Différer `_buildDayMetricsCache`**

Fichier : `lib/presentation/cubits/history_cubit.dart` ~L155-167

- Phase 1 : aggregates + chart (SQL rapide) → emit `ready` sans insights kcal.
- Phase 2 : `_buildDayMetricsCache` en arrière-plan → patch state insights.
- Option : `compute(_buildDayMetricsIsolate, ...)` si >30 jours de buckets — **secondaire** vs réduction des 30 round-trips SQL (B4).

### **Phase D — Pré-`runApp()` (gain : 50–500 ms)**

**D1. Paralléliser prefs**

Fichier : `lib/core/di/app_dependencies.dart` ~L101-107

final results = await Future.wait([

userSettings.getThemeMode(),

userSettings.getAccentPreset(),

...

]);

**D2. Déplacer WorkManager après `runApp()`**

Fichier : `lib/main.dart` ~L34-35

`unawaited(registerStepCollectionWorkmanager(...))` dans un post-frame callback.

**D3. Notification init non bloquante**

Fichier : `lib/main.dart` ~L17-24

Initialiser en parallèle avec `AppDependencies.create`, ou différer après premier frame.

---

## **Objectif <100 ms — faisabilité**

| **Cible** | **Faisable ?** | **Condition** |
| --- | --- | --- |
| Premier paint GoalRing avec steps SQLite | **Oui** | A1 + A2 + A3 (sans attendre ingestion) |
| Refresh Today complet (semaine + métriques) | **~100–200 ms** | B1 + indexes |
| Cold start Flutter total (hors OS) | **>100 ms** | Notification + WorkManager + premier frame Material |

La barre des **100 ms pour les données locales Today** est atteignable avec le fast path (3 requêtes indexées sur ~288 rows max). La barre des **100 ms pour l’ensemble du cold start** nécessite aussi D1–D3.

---

## **Priorisation recommandée**

1. **A1 + A2 + A3** — impact immédiat sur le skeleton (1–2 s → <200 ms)
2. **B1** — quick win N+1 goals
3. **C2** — éviter travail Trends invisible
4. **B2 + B4** — scaling données
5. **C1 + C3** — polish Trends
6. **D1–D3** — polish pré-runApp