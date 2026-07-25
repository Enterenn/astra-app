# **Diagnostic conventions & structure**

Analyse statique de **181 fichiers** `lib/**/*.dart` (script réutilisable : `tools/convention_diagnostic.py`). Les tableaux ci-dessous filtrent les faux positifs des heuristiques automatiques.

---

## **1. Structure de fichiers**

### **1.1 Fichiers non `snake_case`**

| **Fichier** | **Ligne** | **Problème** | **Convention attendue** |
| --- | --- | --- | --- |
| — | — | Aucun fichier public hors convention | `snake_case.dart` |

Les 4 fichiers `_*.dart` (`_step_chart_queries.dart`, etc.) sont des **part files** Dart (privés à la bibliothèque) — convention valide, pas un écart.

---

### **1.2 Nom fichier ≠ classe principale**

La règle stricte « 1 fichier = 1 classe, nom = `snake_case(Classe)` » n'est pas appliquée partout. Écarts classés ci-dessous.

**Écarts structurels (multi-classes ou type auxiliaire en tête de fichier)**

| **Fichier** | **Ligne** | **Problème** | **Convention attendue** |
| --- | --- | --- | --- |
| `lib/core/lifecycle/sample_compaction_runner.dart` | 9 | Première classe publique : `CompactionResult` | `compaction_result.dart` ou déplacer le type |
| `lib/core/metrics/derived_activity_metrics.dart` | 14 | Première classe : `DerivedActivityResult` | `derived_activity_result.dart` |
| `lib/core/services/data_lifecycle_service.dart` | 20 | Première classe : `LifecycleRunResult` | `lifecycle_run_result.dart` |
| `lib/core/time/time_provider.dart` | 1 | Première classe : `TimeSnapshot` | `time_snapshot.dart` |
| `lib/core/validation/step_goal_validator.dart` | 4 | Première classe : `StepGoalValidationResult` | `step_goal_validation_result.dart` |
| `lib/data/datasources/phone_pedometer_source.dart` | 8 | Première classe : `PhoneStepEvent` | `phone_step_event.dart` |
| `lib/data/datasources/step_normalizer.dart` | 8 | Première classe : `StepNormalizationResult` | `step_normalization_result.dart` |
| `lib/presentation/cubits/history_state.dart` | — | Contient `TrendsDayMetrics`, `HistoryState`, etc. | Types auxiliaires dans `history_models.dart` |
| `lib/presentation/cubits/today_state.dart` | — | Contient `ActivityMetricsSnapshot`, `TodayState`, etc. | Idem, fichier dédié aux modèles d'état |

**Écarts de nommage widget / préfixe `Astra`**

| **Fichier** | **Ligne** | **Problème** | **Convention attendue** |
| --- | --- | --- | --- |
| `lib/core/constants/astra_accent_palette.dart` | 7 | Classe `AccentPalette` | `accent_palette.dart` (ou renommer en `AstraAccentPalette`) |
| `lib/core/icons/phosphor_icons.dart` | 8 / 122 | Classes `PhosphorIconsRegular`, `PhosphorIconsFill` | Fichiers séparés ou nom unique `phosphor_icons.dart` accepté si documenté |
| `lib/presentation/widgets/trend_chip.dart` | — | Classe exportée `CaptionPill` | `caption_pill.dart` |
| `lib/presentation/widgets/astra_inset_shadow.dart` | — | Classe principale `AstraInsetShadowSurface` | Aligner nom fichier / widget racine |
| `lib/presentation/widgets/astra_segmented_control.dart` | — | Première classe `AstraSegmentOption` | Options dans fichier dédié ou renommer fichier |

**Acceptés / intentionnels (non bloquants)**

| **Fichier** | **Ligne** | **Problème** | **Convention attendue** |
| --- | --- | --- | --- |
| `lib/app.dart` | 1 | `AstraApp` dans `app.dart` | Convention Flutter (`main.dart` / `app.dart`) |
| `lib/presentation/widgets/*_editor_sheet.dart` | — | Widget public + `_…Body` privé | Corps privé dans le même fichier : OK |
| `lib/core/services/health_foreground_service.dart` | 18 | `HealthForegroundServiceCoordinator` | Nom long ; fichier raccourci acceptable |

---

### **1.3 Dossiers mélangeant plusieurs couches**

| **Fichier** | **Ligne** | **Problème** | **Convention attendue** |
| --- | --- | --- | --- |
| `lib/core/di/` | 19 | `app_dependencies.dart` importe `presentation/cubits/theme_state.dart` | `core/` ne doit pas dépendre de `presentation/` |
| `lib/presentation/cubits/` | — | `my_data_cubit.dart` importe `widgets/confirm_dialog.dart` (`PurgeConfirmAction`) | Enum/type partagé dans `core/` ou `data/` |
| `lib/data/contracts/` | — | Fichiers nommés `*_repository_contract.dart` | OK fonctionnellement (interfaces seulement) ; nommage `contracts/` vs `repositories/` peut prêter à confusion |

**Bon point :** séparation nette `presentation/cubits/`, `presentation/widgets/`, `presentation/screens/`, `data/repositories/`, `core/services/` — pas de dossier mélangeant widgets et cubits.

---

### **1.4 Fichiers > 500 lignes**

| **Fichier** | **Ligne** | **Problème** | **Convention attendue** |
| --- | --- | --- | --- |
| `lib/presentation/cubits/today_cubit.dart` | 1104 | 1104 lignes · 1 classe · 0 fn top-level | Découper (refresh, live monitor, célébration, multi-jour) |
| `lib/presentation/widgets/goal_ring.dart` | 990 | 990 lignes · 4 classes · 3 fn top-level | Extraire painters / effets (déjà partiellement dans `goal_ring_effects.dart`) |
| `lib/l10n/app_localizations.dart` | 1698 | Généré · 1 classe · 1 fn | Ignorer (codegen Flutter) |
| `lib/l10n/app_localizations_fr.dart` | 937 | Généré · 1 classe | Ignorer |
| `lib/l10n/app_localizations_en.dart` | 924 | Généré · 1 classe | Ignorer |
| `lib/core/services/app_lifecycle_coordinator.dart` | 848 | 848 lignes · 1 classe · 3 fn top-level | Extraire midnight boundary, persist cycle, live pipeline |
| `lib/presentation/widgets/astra_horizontal_ruler.dart` | 706 | 706 lignes · 3 classes | Séparer layout / peinture / physique de scroll |
| `lib/presentation/cubits/my_data_cubit.dart` | 690 | 690 lignes · 1 classe | Extraire import/export/purge en use-cases |
| `lib/presentation/screens/today_screen.dart` | 597 | 597 lignes · 7 classes · 3 fn | Sections `_WeekSection`, etc. → fichiers dédiés |
| `lib/presentation/cubits/today_cubit.dart` | — | Plus gros cubit du projet | Cible prioritaire de refactor |

---

## **2. Conventions Dart**

### **2.1 Classes publiques sans `///` (`lib/core/`, `lib/data/`)**

| **Fichier** | **Ligne** | **Problème** | **Convention attendue** |
| --- | --- | --- | --- |
| `lib/core/di/app_dependencies.dart` | 33 | `AppDependencies` sans doc | `///` décrivant le conteneur DI |
| `lib/core/services/background_collector.dart` | 18 | `BackgroundCollector` | Doc sur le rôle d'ingestion |
| `lib/core/services/data_lifecycle_service.dart` | 20 | `LifecycleRunResult` | Doc sur le résultat de maintenance |
| `lib/core/services/workmanager_callback.dart` | 35 | `PluginStepCollectionWorkmanagerClient` | Doc sur l'adaptateur WM |
| `lib/core/time/local_day_calculator.dart` | 3 | `LocalDayCalculator` | Doc sur la sémantique jour local |
| `lib/core/time/system_time_provider.dart` | 3 | `SystemTimeProvider` | Doc courte |
| `lib/core/time/time_provider.dart` | 1 | `TimeSnapshot` | Doc sur les champs UTC/local |
| `lib/core/time/timestamp_codec.dart` | 1 | `TimestampCodec` | Doc sur encodage/décodage |
| `lib/data/datasources/phone_pedometer_source.dart` | 8 | `PhoneStepEvent` | Doc événement capteur |
| `lib/data/datasources/phone_pedometer_source.dart` | 23 | `PhonePedometerSource` | Doc source d'ingestion |
| `lib/data/datasources/step_normalizer.dart` | 20 | `StepNormalizer` | Doc normalisation buckets |
| `lib/data/models/import_result.dart` | 1 | `ImportResult` | Doc résultat import CSV |
| `lib/data/models/normalized_step_bucket.dart` | 7 | `NormalizedStepBucket` | Doc modèle persistance |
| `lib/data/models/step_reading.dart` | 1 | `StepReading` | Doc lecture brute |
| `lib/data/models/timeseries_sample_model.dart` | 4 | `TimeseriesSampleModel` | Doc entité SQLite |
| `lib/data/repositories/step/step_aggregation_repository.dart` | 19 | `StepAggregationRepository` | Doc agrégations / charts |
| `lib/data/repositories/step/step_ingestion_repository.dart` | 12 | `StepIngestionRepository` | Doc écriture buckets |
| `lib/data/services/csv_service.dart` | 15 | `CsvService` | Doc export/import |

*Note :* classes avec `@immutable` entre `///` et `class` (ex. `AstraColors`, `AccentPalette`) sont documentées — non listées.

---

### **2.2 Méthodes `async` non `await`ées aux appels**

Le projet utilise déjà `unawaited()` de façon cohérente dans les cubits et `app_scaffold.dart`. Écarts restants : **Futures ignorées aux frontières UI** (sans `await` ni `unawaited()` explicite).

| **Fichier** | **Ligne** | **Problème** | **Convention attendue** |
| --- | --- | --- | --- |
| `lib/presentation/screens/my_data_screen.dart` | 136 | `onTap: () => cubit.exportAndShare()` | `unawaited(cubit.exportAndShare())` |
| `lib/presentation/screens/my_data_screen.dart` | 144 | `onTap: () => cubit.pickAndImport(...)` | Idem |
| `lib/presentation/screens/my_data_screen.dart` | 159 | `onTap: () => cubit.confirmAndPurge(...)` | Idem |
| `lib/presentation/screens/today_screen.dart` | 341 | `onTap: () => context.read<TodayCubit>().refresh(...)` | `unawaited(...)` |
| `lib/presentation/screens/settings_screen.dart` | 318-331 | `setThemePreference` / `setAccentPreset` dans `onChanged` | `unawaited(cubit.setThemePreference(...))` |
| `lib/presentation/onboarding/onboarding_flow.dart` | 100-122 | `_onIntroContinue(context)` etc. dans callbacks sync | `unawaited(_onIntroContinue(context))` |

**Recommandation :** activer le lint `discarded_futures` dans `analysis_options.yaml` (non activé aujourd'hui — seul `flutter_lints` est inclus).

---

### **2.3 `void` avec opérations `async`**

| **Fichier** | **Ligne** | **Problème** | **Convention attendue** |
| --- | --- | --- | --- |
| — | — | Aucun `void` avec `await` nu détecté | — |

Les méthodes `void` déclenchant du async utilisent `unawaited()` (`today_cubit.dart`, `app_scaffold.dart`, `app.dart`). Les signatures Flutter (`initState`, `didChangeAppLifecycleState`) respectent ce pattern.

---

### **2.4 Abréviations non évidentes (champs / API publique)**

| **Fichier** | **Ligne** | **Problème** | **Convention attendue** |
| --- | --- | --- | --- |
| `lib/core/services/ingestion_collection_lock.dart` | 18 | Champ `ttl` | `lockTimeToLive` ou `acquireTimeout` |
| `lib/data/contracts/step_ingestion_repository_contract.dart` | 5 | Paramètre `txn` | `transaction` (sauf si convention SQLite documentée) |
| `lib/presentation/widgets/goal_celebration_particles.dart` | 56 | Champ `t` (animation) | `normalizedTime` ou `progress` |
| `lib/presentation/screens/today_screen.dart` | 595 | Variable `vm` (view-model local) | `weekProgress` / `goalRingModel` selon le sélecteur |
| `lib/presentation/cubits/today_cubit.dart` | 1047 | Params `a`, `b` (comparateur) | `left`, `right` ou noms métier |

*Hors scope :* `id`, `min`/`max` (bornes UI), `cm`/`kg`, `kb`/`mb` — abréviations de domaine acceptables.

---

## **3. Patterns BLoC**

### **3.1 Couplage inter-cubit**

**Aucun cubit n'appelle directement un autre cubit** (pas de `TodayCubit` injecté dans `HistoryCubit`, etc.).

Le couplage est **indirect**, via la couche orchestration :

| **Fichier** | **Ligne** | **Problème** | **Convention attendue** |
| --- | --- | --- | --- |
| `lib/presentation/screens/app_scaffold.dart` | 84-115 | Callbacks `postGoalUpdate` / `postImportRefresh` appellent `_historyCubit`, `_todayCubit`, `_myDataCubit` | Coordination centralisée acceptable ; alternative : bus d'événements / `BlocListener` global |
| `lib/core/services/app_lifecycle_coordinator.dart` | 131-844 | Références `TodayCubit?`, `HistoryCubit?`, `MyDataCubit?` + appels `refresh`, `syncSteps`, etc. | Service core couplé à presentation — envisager interface `TodayScreenController` dans `core/` |
| `lib/presentation/cubits/history_cubit.dart` | 45 | Référence doc `[TodayCubit.refreshMetadata]` uniquement | Pas de couplage code — OK |

---

### **3.2 Logique UI dans les cubits**

| **Fichier** | **Ligne** | **Problème** | **Convention attendue** |
| --- | --- | --- | --- |
| `lib/presentation/cubits/my_data_cubit.dart` | 92-108 | `FilePicker.pickFile` / `FilePicker.saveFile` dans le cubit | Injecter via `PickCsvFileCallback` / `SaveCsvFileCallback` (déjà prévus — retirer les défauts UI du cubit) |
| `lib/presentation/cubits/my_data_cubit.dart` | 19 | Import `confirm_dialog.dart` pour `PurgeConfirmAction` | Déplacer l'enum vers `data/` ou `core/` |
| — | — | Pas de `BuildContext`, `Navigator`, `showDialog` dans les cubits | UI dans screens/widgets — respecté ailleurs |

---

## **Synthèse priorisée**

| **Priorité** | **Catégorie** | **Action suggérée** |
| --- | --- | --- |
| Haute | Taille | Refactor `today_cubit.dart` (1104 L) et `app_lifecycle_coordinator.dart` (848 L) |
| Haute | Architecture | Retirer l'import `presentation/` depuis `core/di/app_dependencies.dart` |
| Moyenne | BLoC | Sortir `FilePicker` et `PurgeConfirmAction` de `MyDataCubit` |
| Moyenne | Docs | Documenter les 18 classes `core/`/`data/` listées en 2.1 |
| Basse | Lint | Activer `discarded_futures` + `unawaited()` aux callbacks UI |
| Basse | Nommage | Harmoniser fichiers multi-classes (résultats / snapshots) |