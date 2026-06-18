# MASTER AUDIT : PLAN DE RÉFACTORISATION GLOBAL (V0.6.1)
# Révision consolidée — Audit initial + vérification code source

> **Généré le :** 2026-06-18  
> **Basé sur :** v0.6.1+12 (`pubspec.yaml`)  
> **Stack :** Flutter 3.22+ (Impeller) · SDK `^3.12.0` · SQLite (`sqflite`) · Local-First & 120Hz  
> **Statut sprint :** tous les epics 1–13 done

> **Convention de ce document :**
> - `✅ CONFIRMÉ` — constat vérifié dans le code source
> - `❌ INEXACT` — claim original corrigé après lecture du code
> - `➕ AJOUT` — constat absent de l'audit initial, identifié après vérification

---

## 🏛️ ÉLÉMENT 1 : Architecture & Robustesse du Code

### 1.1 Perméabilité de la Couche Vue vers la Couche Data `✅ CONFIRMÉ` — Priorité P1

**Constat :** Le widget visuel principal `GoalRing` gère lui-même des opérations de lecture/écriture en base de données, violant l'isolation de la Clean Architecture.

**Fichiers concernés (chemins exacts) :**
- `lib/presentation/widgets/goal_ring.dart` (948 lignes)
- `lib/presentation/cubits/today_cubit.dart`

**Détail technique :**
- `_loadLastDisplayedSteps()` : lignes 211–256, async, lit `UserPreferencesRepository.getLastDisplayedSteps(day)` directement depuis le widget
- `_persistLastDisplayedSteps()` : lignes 558–577, async, écrit via `prefs.setLastDisplayedSteps`, avec guards sur `disableStepPersistence`, `!mounted`, `!prefs.isDatabaseOpen`
- `GoalRing.disableStepPersistence = false` : flag statique global ligne 76, utilisé aux lignes 226, 272, 559

**Action :**
1. Supprimer `_loadLastDisplayedSteps()` et `_persistLastDisplayedSteps()` de l'état du widget
2. Transférer la logique de persistance d'affichage au `TodayCubit` (ajouter un champ `lastDisplayedSteps` dans `TodayState`)
3. Éliminer `GoalRing.disableStepPersistence = true` — le cubit devenant la source de vérité, les tests mockent le cubit directement

**Nuance :** Déplacer vers le cubit crée un couplage display-state / business-state dans `TodayState`. Si ce couplage est jugé inacceptable, une alternative propre est un service dédié `GoalRingDisplayStateService` injecté uniquement dans `GoalRing`.

---

### 1.2 Fuite de Responsabilités & Couplages ("God Classes") `✅ CONFIRMÉ` — Priorité P1

#### a) `_AstraAppState` (`lib/app.dart`, 864 lignes) `✅ CONFIRMÉ`

**Contexte :** `_AstraAppState` concentre tout le cycle de vie asynchrone de l'application.

**Inventaire complet des méthodes de pipeline :**

| Méthode | Rôle |
|---------|------|
| `_onTodayCubitReady` | Déclenche l'attachement du pipeline live |
| `_ensureLivePipelineAttached` | First-time vs re-attach |
| `_startLivePipelineFirstTime` | Backfill → bind → start persist → timer minuit |
| `_reattachLivePipeline` | Re-bind monitor après retour foreground |
| `_bindLiveMonitorToToday` | Permission, démarrage monitor, attach cubit |
| `_resumeLivePipeline` | Retour foreground avec drain/peek/catch-up |
| `_runPersistCycle` | Collector + monitor reconcile |
| `_enqueuePersistCycle` | Persist sérialisé |
| `_wireLiveMonitorDayBoundaryCallbacks` | Callback `onLocalDayBoundary` |
| `_startActivityBasedPersist` | `onActivityIdle` + staleness timer |
| `_runLocalDayBoundary*` | Rollover minuit (lignes 721–801) |

**Timers actifs :**
- `_stalenessPersistTimer` : `Timer.periodic(maxStaleness, …)` — fallback de persist
- `_midnightBoundaryTimer` : one-shot → `_onMidnightBoundaryTimerFired()` → re-schedule

**Action :** Extraire la logique d'orchestration dans `AppLifecycleCoordinator` (service injectable, testable isolément).

#### b) `AppScaffold` — `postPurgeRefresh` sans guard `✅ CONFIRMÉ + AGGRAVÉ`

L'audit mentionne "6 opérations". Le code réel en enchaîne **8** sans aucun `try/catch` et sans `mounted` dans le callback :

```dart
postPurgeRefresh: () async {
  await widget.deps.userPreferences.clearLastDisplayedSteps();
  await widget.deps.liveStepMonitor.reconcileFromDatabase();
  await _todayCubit.refresh(silent: true);
  await _todayCubit.syncSteps(widget.deps.liveStepMonitor.currentTodaySteps);
  await _todayCubit.refreshMetadata();
  await _historyCubit.refresh(silent: true);
  await _myDataCubit.refresh(silent: true);
  unawaited(widget.deps.dataLifecycleService.runMaintenance(force: true));
},
```

**Risques :**
1. Si `reconcileFromDatabase()` lève une exception, les 6 opérations suivantes sont skippées silencieusement — l'UI se retrouve dans un état partiel indéfini sans que l'utilisateur le sache
2. Pas de vérification `mounted` → `StateError` si l'utilisateur quitte l'écran pendant le traitement

**Action :**
```dart
postPurgeRefresh: () async {
  try {
    await widget.deps.userPreferences.clearLastDisplayedSteps();
    await widget.deps.liveStepMonitor.reconcileFromDatabase();
    if (!mounted) return;
    // ... reste des opérations
  } catch (e, st) {
    // logger + snackbar d'erreur
  }
},
```

#### c) Violations SRP dans les Repositories `✅ CONFIRMÉ`

**`UserPreferencesRepository` (420 lignes) — responsabilités détectées :**

| Domaine | Méthodes |
|---------|----------|
| Objectif de pas | `getDailyStepGoal`, `getGoalForLocalDay`, `setDailyStepGoal` |
| Thème / accent | `getThemeMode`, `setThemeMode`, `getAccentPreset`, `setAccentPreset` |
| Onboarding | `getOnboardingComplete`, `setOnboardingComplete` |
| Métriques corporelles | `getDisplayName`, `setDisplayName`, `getHeightCm`, `setHeightCm`, `getWeightKg`, `setWeightKg` |
| Unités d'affichage | `get/setDistanceDisplayUnit`, `get/setWeightDisplayUnit`, `get/setHeightDisplayUnit` |
| Notifications | `isGoalNotificationsPreferenceSet`, `get/setGoalNotificationsEnabled`, etc. |
| Déduplication célébration | `get/setCelebrationShownDate`, `tryClaimCelebrationShownDate` |
| État d'affichage GoalRing | `getLastDisplayedSteps`, `setLastDisplayedSteps`, `clearLastDisplayedSteps` |
| Maintenance DB | `get/setLastDatabaseOptimizedAt` |

**Action :** Scinder en `UserSettingsRepository` (thème, unités, notifications) + `UserHealthMetricsRepository` (poids, taille, objectif) + déplacer l'état GoalRing dans `TodayCubit` (cf. 1.1).

**`StepRepository` (679 lignes) — responsabilités détectées :**

| Domaine | Méthodes |
|---------|----------|
| Ingestion | `upsertIngestionBucket` |
| Lecture aujourd'hui | `getTodaySteps`, `getTodayActiveBuckets`, `getActiveBucketsForLocalDay` |
| Agrégats graphiques | `getChartDailyAggregates` (7/30j), `getChartMonthlyAggregates` (12 mois) |
| Footprint / stats | `getFootprint`, `countStepSamples`, `getLastIngestionUtc` |
| Compaction | `downsampleStepSamples` |
| Export / Import CSV | `exportCsv`, `importCsv`, `importSamples` |
| Purge | `purge` |
| Dev/test | `insertDevSamplesBatch` (assert debug-only) |

**Action :** Scinder en `StepIngestionRepository`, `StepAggregationRepository` + `CsvService` (export/import/purge CSV).

---

### 1.3 Absence de la Couche Domain & Inversion des Dépendances `✅ CONFIRMÉ` — Priorité P2

**Constat :** Il n'existe pas de dossier `lib/domain/`. Aucune interface abstraite de repository. Les cubits importent directement les classes concrètes :

```dart
// lib/presentation/cubits/today_cubit.dart
import '../../data/repositories/step_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';

final StepRepository stepRepository;
final UserPreferencesRepository userPreferences;
```

Même constat pour `history_cubit.dart` et `my_data_cubit.dart`.

**Les seules abstractions existantes dans `lib/` sont :**
- `core/time/time_provider.dart` → `TimeProvider` (abstract)
- `core/services/workmanager_callback.dart` → `StepCollectionWorkmanagerClient` (abstract)
- `data/datasources/data_ingestion_source.dart` → `DataIngestionSource` (abstract)

**Impact :** Toute la suite de tests doit ouvrir une vraie session SQLite (`sqflite_common_ffi`) — suite lente et fragile. Aucun test unitaire rapide des cubits n'est possible en l'état. C'est le prérequis structurel à toute vraie suite de tests unitaires (cf. §6.1).

**Action :** Introduire au minimum :
- `abstract class StepRepositoryContract`
- `abstract class UserPreferencesRepositoryContract`

Les classes concrètes existantes implémentent ces contrats. Les cubits dépendent des abstractions. Les tests injectent des mocks.

---

### ➕ 1.4 Deadlock potentiel dans `_enqueueLifecycleTransition` — Priorité P1

> **Absent de l'audit initial.** L'audit parle de "busy-wait" — c'est inexact.

**Constat :** `_enqueueLifecycleTransition` (lignes 174–191) sérialise pause/resume via un flag booléen `_lifecycleTransitionInFlight` avec chaînage `then()`. Ce n'est **pas** un polling loop (busy-wait), c'est un verrou async.

**Risque réel :** Si la transition enchaînée lève une exception non catchée à l'intérieur du bloc `then()`, le flag `_lifecycleTransitionInFlight` reste `true` indéfiniment. Toutes les transitions lifecycle suivantes (retours foreground, passages en background) sont silencieusement ignorées. L'app cesse de persister les pas ou de se synchroniser sans aucun signal d'erreur.

**Action :** Wrapper le corps de `_enqueueLifecycleTransition` dans un `try/catch/finally` qui garantit le reset du flag :
```dart
} finally {
  _lifecycleTransitionInFlight = false;
}
```

---

## 🌐 ÉLÉMENT 2 : Internationalisation (i18n) & Localisation Évolutive — Priorité P3

### 2.1 Infrastructure Technique Native

**Solution recommandée :** `flutter_localizations` (généré via `l10n.yaml` et fichiers `.arb`).

**Avantages :**
- Aucun package tiers supplémentaire (inclus dans le SDK Flutter)
- Génération de code Dart fortement typé au *build time* via `flutter gen-l10n`
- Aucun parsing JSON asynchrone au runtime
- Compatible avec le démarrage à froid exigeant d'Astra

**Fichiers à initialiser :**

```
pubspec.yaml          → ajouter flutter: generate: true + flutter_localizations
l10n.yaml             → arb-dir: lib/l10n, template-arb-file: app_en.arb
lib/l10n/app_en.arb   → template anglais
lib/l10n/app_fr.arb   → traductions françaises
```

### 2.2 Table de migration des clés (non exhaustif)

| Périmètre | Clé | Anglais | Français |
|-----------|-----|---------|----------|
| Menu / Settings | `menuPrivacyAndData` | Privacy & My Data | Confidentialité & Mes Données |
| Menu / Settings | `menuTrackingStatus` | Step Tracking Status | État du suivi des pas |
| Today (bannière) | `bannerStaleData` | Data outdated. Tap to refresh. | Données obsolètes. Toucher pour actualiser. |
| Today (permission) | `errorNoPermission` | Step access denied. Tap to fix. | Accès aux pas refusé. Toucher pour régler. |
| Onboarding | `onboardingStartBtn` | Start | Démarrer |
| Trends (insight) | `trendsWeeklyGrowth` | Up {percentage}% from last week | En hausse de {percentage}% la semaine dernière |

### 2.3 Persistance du choix de langue

**Action :** Enregistrer la locale choisie (`en`, `fr`) dans `UserPreferencesRepository`. L'instance `MaterialApp` dans `lib/app.dart` doit lire cette préférence au démarrage et exposer un setter accessible depuis les réglages.

### 2.4 Moment opportun pour l'implémentation

L'i18n est classée P3 car elle ne débloque aucune fonctionnalité technique. Elle doit être faite **après la stabilisation de l'architecture** (après les refactos P1/P2 des éléments 1 et 3) et **avant toute release internationale ou soumission au Play Store**. Reporter après P1/P2 évite de migrer des strings hardcodées dans des fichiers qui vont être refactorisés.

---

## ⚡ ÉLÉMENT 3 : Fluidité 120Hz & Optimisation GPU (Impeller)

### 3.1 Rebuilds de Widgets Trop Larges (`TodayScreen`) — Priorité P2

**Constat :** `TodayScreen` utilise un `BlocBuilder` global qui force le rafraîchissement complet de l'interface à chaque incrément du capteur de pas.

**Action :** Remplacer par des `BlocSelector` fins :
- `WeekProgressRow` → ne rebuilder que sur changement de structure hebdomadaire
- `GoalRing` → ne rebuilder que sur `state.todaySteps` et `state.dailyGoal`
- Cartes de stats → ne rebuilder que sur `state.derivedMetrics`

---

### 3.2 Surcharge de la File Raster — `ImageFilter.blur` par frame `✅ CONFIRMÉ` — Priorité P2

**Constat confirmé dans les deux fichiers :**

`lib/presentation/widgets/goal_ring_effects.dart` (lignes 25–30) :
```dart
..imageFilter = ui.ImageFilter.blur(
  sigmaX: kAstraInsetShadowBlur / 2,
  sigmaY: kAstraInsetShadowBlur / 2,
)
```

`lib/presentation/widgets/astra_inset_shadow.dart` (lignes 23–28) : même pattern.

**Impact :** Chaque appel alloue un `SaveLayer` intermédiaire sur le GPU — 120 fois par seconde pour une ombre statique qui ne change jamais.

**Action :** Pré-rendre l'ombre une seule fois via `Picture.toImage()` lors du premier `paint`, stocker le résultat en champ d'instance du `CustomPainter`, puis utiliser `canvas.drawImage()` pour les frames suivantes. Invalider le cache uniquement si la taille du widget change (`oldDelegate.size != size`).

---

### 3.3 Surcharge d'Animations et Rendu Invisible `✅ CONFIRMÉ` — Priorité P2

#### a) GoalRing — 5 contrôleurs + 2 timers

**Inventaire complet (sous-estimé dans l'audit initial) :**

| Champ | Type | Rôle |
|-------|------|------|
| `_pulseController` | `AnimationController` | Pulse de chargement |
| `_countUpController` | `AnimationController` | Count-up animation |
| `_microTickController` | `AnimationController` | Micro-tick digit |
| `_liveArcController` | `AnimationController` | Arc live pendant micro-tick |
| `_overflowController` | `AnimationController` | Shimmer overflow |
| `_liveCoalesceTimer` | `Timer?` | Coalescing des updates live |
| `_foregroundCatchUpTimer` | `Timer?` | Catch-up au retour foreground |

7 objets à cycle de vie à gérer — surface de fuite mémoire significative si l'interruption est abrupte (appel entrant, crash partiel).

**Action :** `RepaintBoundary` autour de `GoalRing`. Vérifier que tous les contrôleurs sont bien disposés dans `dispose()` — ajouter des assertions ou un `FlutterMemoryAllocations` listener en debug.

#### b) `IndexedStack` — rendu invisible des onglets en arrière-plan

**Précision importante :** Le problème n'est **pas** dans un dossier `lib/presentation/trends/` (inexistant). Le vrai `IndexedStack` est dans `lib/presentation/screens/app_scaffold.dart` (lignes 280–283). Les onglets `HistoryScreen` (Trends) et `MenuHubScreen` sont peints en permanence même hors focus.

**Sur les charts de `HistoryScreen` spécifiquement :** ils sont rendus via un `if/else` conditionnel dans le corps de `HistoryScreen`. En Flutter, un `if/else` dans le widget tree **crée et détruit** les widgets concernés — contrairement à `Visibility(maintainState: true)` ou `Offstage` qui les gardent montés et peints. Les charts ne sont donc **pas** rendus invisiblement à l'intérieur de `HistoryScreen`. Le vrai problème de rendu en arrière-plan est l'`IndexedStack` de `AppScaffold` qui maintient `HistoryScreen` entier dans l'arbre même quand l'onglet n'est pas actif.

**Action :** Wrapper chaque onglet dans un `RepaintBoundary` dans `AppScaffold`. Pour aller plus loin, remplacer l'`IndexedStack` par un `PageView` avec `AutomaticKeepAliveClientMixin` pour garder l'état sans renderer en arrière-plan.

---

### 3.4 Goulot d'Étranglement SQLite — N Requêtes Individuelles `✅ CONFIRMÉ (diagnostic partiel inexact)` — Priorité P1

**Code confirmé (`lib/presentation/cubits/history_cubit.dart`, lignes 347–363) :**

```dart
final goals = await Future.wait<int>([
  for (final iso in distinctIsos)
    userPreferences.getGoalForLocalDay(iso),
]);
```

**Correction du diagnostic :** L'audit décrit ces requêtes comme "consécutives" et dit qu'elles "bloquent le thread principal". C'est inexact sur deux points :

1. Les requêtes sont lancées **en parallèle** via `Future.wait`, pas séquentiellement
2. `sqflite` s'exécute sur un isolate dédié — il ne bloque pas le thread UI

**Problème réel :** L'overhead n'est pas un blocage du thread UI, c'est le coût de **N aller-retours inter-isolate** (sérialisation/désérialisation du message channel Flutter) + N curseurs SQLite ouverts/fermés. Sur 30 jours, c'est 30 × 2 transitions isolate au lieu de 1.

**Action — requête batch :**
```sql
SELECT local_day, goal_steps
FROM daily_goal_effective
WHERE local_day IN (?, ?, ?, ...)
ORDER BY effective_from DESC
```
Retourner une `Map<String, int>` et supprimer le `Future.wait`.

---

### 3.5 `AstraHorizontalRuler` — Déjà Debounced Nativement `❌ INEXACT`

> **Claim original :** "surcharge le Cubit en émettant des événements continus à chaque changement infinitésimal de pixel de scroll"

**Verdict après lecture du code (`lib/presentation/widgets/astra_horizontal_ruler.dart`, 707 lignes) : FAUX.**

Le ruler utilise déjà un snap par graduation :
```dart
// ~ligne 325
final value = (pixels / itemExtent).round(); // itemExtent = 10.0
if (_lastReportedValue != value) {
  widget.onChanged(value);
  _lastReportedValue = value;
}
```

`widget.onChanged` n'est déclenché **que** lors d'un changement de valeur entière (environ tous les 10px), pas à chaque pixel. Pendant les scrolls programmatiques (`_syncingScroll == true`), le handler retourne immédiatement.

**Aucune action requise sur le debounce.** La recommandation d'ajouter un filtre temporel supplémentaire est inutile et ajouterait une latence perceptible dans l'UX du ruler.

**Point réel à surveiller :** Vérifier que le retour haptique (s'il existe dans le ruler) est bien déclenché uniquement par snap de graduation et non sur tout scroll programmatique.

---

## 📦 ÉLÉMENT 4 : Allègement de l'Application (Chasse au Poids)

> **Recommandation préalable :** Mesurer un build de production réel via `flutter build apk --release --analyze-size` avant toute modification. Les gains estimés ci-dessous sont des ordres de grandeur.

### Table de décision des dépendances

| Dépendance | Version actuelle | Problème | Solution | Gain estimé |
|------------|-----------------|----------|----------|-------------|
| `phosphoricons_flutter` | `^1.0.0` | Charge plusieurs polices complètes pour quelques icônes | Extraire uniquement les `.ttf` requis dans `/assets/fonts/` | ~200–400 KB |
| `fl_chart` | `^1.2.0` | Librairie lourde dont seule une fraction est utilisée | Réécriture `CustomPainter` natif (~250 lignes) | ~500 KB + fluidité Impeller |
| `uuid` | `^4.4.0` | Uniquement utilisé dans `StepRepository` pour les IDs de buckets | `DateTime.now().microsecondsSinceEpoch.toRadixString(36)` | ~35 KB |
| `figma_squircle` | `^0.6.3` | Masques complexes pour l'item actif de la nav bar | `ClipPath` + `Path` standard Flutter | ~15 KB |
| `share_plus` | `^13.1.0` | Utilisé uniquement pour l'export CSV | `file_picker` (déjà présent) + `FileProvider` Android direct | ~100–200 KB |
| `file_picker` | `^12.0.0-beta.5` | Version beta — risque de breaking change à chaque update | Épingler à `12.0.0-beta.5` (sans `^`) et conserver — stratégie d'attente de release stable | Stabilité |

> **➕ `share_plus` absent de l'audit initial.** Ce package est uniquement utilisé pour l'export CSV. `file_picker` est déjà dans les dépendances — un export direct via `FileProvider` Android supprime cette dépendance sans perte fonctionnelle.

### Dépendances stables à conserver

`sqflite`, `pedometer`, `workmanager`, `permission_handler`, `flutter_local_notifications`, `path_provider`, `package_info_plus`, `flutter_bloc`, `path` — essentiels et performants.

### `lib/dev/` — 6 fichiers dans l'arbre de compilation `✅ CONFIRMÉ`

**Fichiers concernés :**
- `lib/dev/data_inject_service.dart`
- `lib/dev/chart_benchmark.dart`
- `lib/dev/chart_benchmark_dev_fab.dart`
- `lib/dev/chart_benchmark_render_pump.dart`
- `lib/dev/lifecycle_simulator.dart`
- `lib/dev/README.md`

**Correction importante :** L'audit recommande "conditionner via `kDebugMode` + tree-shaking". C'est **insuffisant**. Le tree-shaking Dart ne supprime pas le code mort lié à des imports conditionnels à l'exécution — `kDebugMode` est une constante Dart mais les classes restent compilées. La seule solution garantie pour exclure ces fichiers du bundle release est de les **déplacer dans `test/`** ou dans un package séparé. Les fichiers de simulation utilisables en tests (`data_inject_service`, `lifecycle_simulator`) ont leur place dans `test/dev/` avec accès `sqflite_common_ffi`. Les benchmarks de rendu (`chart_benchmark*`) peuvent être supprimés ou déplacés dans un dossier d'outils séparé hors du projet Flutter.

> **Note :** Le `deferred-work.md` mentionne que la Phase C (tag `@Tags(['dev'])` pour `test/dev/`) est déjà identifiée comme déférée.

---

## 🗺️ ÉLÉMENT 5 : Parcours Utilisateur (UI/UX) & Alignement Produit

### 5.1 Philosophie de l'Onboarding `❌ PARTIELLEMENT INEXACT`

> **Claim original :** "exige des données personnelles obligatoires (Poids, Taille)"

**Verdict après lecture du code : FAUX pour le poids et la taille.**

L'`onboarding_flow.dart` expose 3 étapes via `IndexedStack` :
- **Index 0** — `OnboardingIntroPage` : accueil + demande permission activité physique → action "Continue"
- **Index 1** — `OnboardingWeightPage` : saisie poids → actions "Continue" **et "Skip"** ✅
- **Index 2** — `OnboardingHeightPage` : saisie taille → actions "Let's Go" **et "Skip"** ✅

Les données biométriques sont **déjà optionnelles** dans le code actuel.

**Point de friction réel (à corriger) :** La demande de permission Activité Physique se fait **à l'étape 0** (intro) avant tout contexte produit. L'utilisateur ne sait pas encore pourquoi l'app a besoin de cette permission. Une meilleure UX serait de présenter d'abord la promesse produit ("100% hors-ligne, aucun compte") et de ne demander la permission qu'une fois que l'utilisateur a montré son intention d'utiliser le tracking.

**Actions conservées de l'audit :**
- Étape 0 : Accueil épuré avec promesse "100% Hors-ligne, Aucun compte requis"
- Déplacer la demande de permission après présentation de la valeur produit
- Déporter la configuration poids/taille dans l'onglet Profil (déjà skipable, confirmer la visibilité post-onboarding)

---

### 5.2 Améliorations de l'Écran d'Accueil (`TodayScreen`) — Priorité P2

#### Indicateur de santé du service de collecte `✅ À IMPLÉMENTER`

Si le tracking se bloque en arrière-plan (économie d'énergie Android, OEM kill), l'utilisateur n'a aucun moyen de le diagnostiquer. Le `deferred-work.md` mentionne d'ailleurs `TodayState.isStale` comme "computed but not surfaced in UI".

**Action :** Ajouter un indicateur de santé au-dessus du GoalRing. État possible : "Collecte active ●", "Dernière sync il y a Xh ⚠", "Accès capteur révoqué ✕". Lier à `TodayState.isStale` et `TodayState.permissionStatus` déjà dans le state.

#### Bannière "Données obsolètes" cliquable

**Action :** Rendre `StatusBannerVariant.staleCompact` / `staleFull` (actuellement stubs non utilisés d'après `deferred-work.md`) cliquable comme CTA vers les réglages Android ou vers un refresh forcé.

#### Flash du démarrage à froid

Au cold start, le compteur affiche brièvement "0 / 10 000" le temps que la DB s'ouvre.

> **⛔ Bloqué par §1.1** — la correction propre dépend du refacto GoalRing → TodayCubit. Sans 1.1 fait d'abord, `_loadLastDisplayedSteps()` reste dans le widget et toute solution ici serait un patch temporaire.

**Action (après 1.1) :** Exposer un `TodayStatus.loading` dans `TodayState` tant que les étapes initiales n'ont pas été chargées. `TodayScreen` affiche un shimmer léger sur le ring et le compteur pendant cet état.

---

### 5.3 Finitions Générales & Valeur Ajoutée — Priorité P3

#### Insights analytiques locaux dans Trends

**Action :** Ajouter des cartes d'analyse textuelle générées localement en Dart :
- *"Moyenne de la semaine en hausse de 12%"* (calculé depuis les agrégats existants)
- *"Votre journée la plus active est le mardi"* (depuis `getChartDailyAggregates`)
- *"X jours consécutifs au-dessus de l'objectif"* (streak counter)

Aucune dépendance externe requise — exploite uniquement les données SQLite déjà agrégées.

#### Retour haptique à la navigation `✅ À VÉRIFIER`

**Action :** Ajouter `HapticFeedback.selectionClick()` au changement d'onglet dans `AppScaffold`. Vérifier si déjà implémenté dans le code actuel avant d'ajouter.

---

## ➕ ÉLÉMENT 6 : Points Additionnels Absents de l'Audit Initial

### 6.1 Tests unitaires — impossibilité structurelle `✅ CONFIRMÉ` — Priorité P2

**Constat :** L'absence d'interfaces abstraites rend **tout test unitaire rapide des cubits impossible**. Toute la suite de tests doit ouvrir une vraie session SQLite (`sqflite_common_ffi`). Suite résultante : lente (~41s pour les tests live pipeline), fragile (race conditions documentées dans `deferred-work.md`), avec 2 groupes de tests skippés en permanence. → cf. §1.3 pour l'action corrective (prérequis : interfaces abstraites).

---

### 6.2 `share_plus` — dépendance supprimable `➕ ABSENT DE L'AUDIT`

**Constat :** `share_plus ^13.1.0` est utilisé uniquement pour l'export CSV (probablement dans `StepRepository.exportCsv` ou le cubit associé). `file_picker ^12.0.0-beta.5` est déjà présent dans les dépendances et peut gérer l'écriture directe de fichiers.

**Action :** Remplacer `share_plus` par un export direct via `file_picker` (SAF — Storage Access Framework sur Android). Gain : suppression d'une dépendance, cohérence avec la philosophie local-first.

---

### 6.3 `lib/dev/` — exclusion insuffisante avec `kDebugMode` `➕ ABSENT DE L'AUDIT`

Cf. section 4. La solution correcte est le déplacement dans `test/dev/`, pas la conditionnalisation à l'exécution.

---

### 6.4 `IndexedStack` — mauvaise attribution dans l'audit original `❌ CORRIGÉ`

L'audit pointait vers `lib/presentation/trends/` (inexistant). Le vrai problème est dans `lib/presentation/screens/app_scaffold.dart`. Les charts de `HistoryScreen` utilisent un `if/else` conditionnel qui **crée et détruit** les widgets — il n'y a pas de rendu invisible à l'intérieur de `HistoryScreen`. Le `RepaintBoundary` reste pertinent mais doit être appliqué au bon niveau : **autour des onglets dans `AppScaffold`**, pas autour des charts de Trends.

---

## 📈 ÉLÉMENT 7 : Matrice de Priorisation

| Priorité | Élément | Impact | Effort | Risque de déstabilisation |
|----------|---------|--------|--------|--------------------------|
| **P0** | 1.2b `postPurgeRefresh` try/catch + mounted | Corruption silencieuse d'état UI après purge | Faible | Très faible |
| **P1** | 1.4 Deadlock `_enqueueLifecycleTransition` finally | Tracking silencieusement mort sur exception | Faible | Très faible |
| **P1** | 3.4 Batch SQL dans `_resolveGoalsForAggregates` | Performance Trends | Faible | Faible |
| **P1** | 1.1 GoalRing persistence → TodayCubit | Architecture | Moyen | Moyen |
| **P1** | 4 `lib/dev/` → `test/dev/` | Taille APK | Faible | Faible |
| **P1** | 4 `uuid` suppression | Dépendance | Faible | Faible |
| **P2** | 1.3 Interfaces abstraites repositories | Testabilité | Élevé | Moyen |
| **P2** | 3.2 `ImageFilter.blur` cache | GPU 120Hz | Moyen | Faible |
| **P2** | 3.3 `RepaintBoundary` AppScaffold tabs | GPU 120Hz | Faible | Faible |
| **P2** | 5.2 Indicateur santé collecte | UX feedback | Moyen | Faible |
| **P2** | 3.1 `BlocSelector` granulaires | CPU 120Hz | Moyen | Faible |
| **P3** | 1.2a `AppLifecycleCoordinator` extract | Architecture | Élevé | Élevé |
| **P3** | 1.2c Split repositories | Architecture | Élevé | Élevé |
| **P3** | 4 `fl_chart` → CustomPainter | Taille + perf | Très élevé | Élevé |
| **P3** | 4 `phosphoricons` → TTF sélectifs | Taille APK | Élevé | Moyen |
| **P3** | 2 Infrastructure i18n | Internationalisation | Élevé | Moyen |
| **P3** | 5.3 Insights analytiques Trends | UX valeur | Moyen | Faible |

---

## ⚠️ Points Hors-Scope Intentionnel (à ne pas toucher)

Les packages suivants sont jugés essentiels, performants et stables — **ne pas remplacer** :
- `sqflite ^2.4.2+1`
- `pedometer ^4.2.0`
- `workmanager ^0.9.0+3`
- `permission_handler ^12.0.1`
- `flutter_local_notifications ^21.0.0`
- `path_provider ^2.1.5`
- `package_info_plus ^10.1.0`
- `flutter_bloc ^9.1.1`

**`file_picker ^12.0.0-beta.5`** : à **conserver et épingler** à la version exacte dans `pubspec.yaml` (`file_picker: 12.0.0-beta.5` sans `^`). Le package est fonctionnel et requis pour l'export CSV (et pour remplacer `share_plus`). La version beta est assumée tant qu'aucune version stable n'est disponible — l'épinglage sans `^` garantit qu'aucun `flutter pub upgrade` ne le fait bouger sans décision explicite.

---

*Document consolidé — audit initial + vérification code source v0.6.1+12 — 2026-06-18*
