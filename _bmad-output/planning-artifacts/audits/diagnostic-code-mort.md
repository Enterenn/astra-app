# **Diagnostic de code mort**

Analyse statique de **181 fichiers** dans `lib/` (corrélations de symboles + vérification manuelle des cas à haute confiance). Les getters l10n, les modèles de données et les API `@visibleForTesting` génèrent beaucoup de faux positifs en analyse automatique — le tableau ci-dessous ne retient que les éléments **vérifiés**.

---

## **1. Méthodes publiques sans appel depuis un autre fichier**

| **Fichier** | **Ligne** | **Élément** | **Raison de suspicion** |
| --- | --- | --- | --- |
| `lib/core/constants/astra_typography.dart` | 110 | `AstraTypography.display(BuildContext)` | Wrappers `*For(colors)` utilisés à la place ; aucun appel à `.display(context)` |
| `lib/core/constants/astra_typography.dart` | 120 | `AstraTypography.screenTitle(BuildContext)` | `screenTitleFor(colors)` utilisé dans 7 écrans |
| `lib/core/constants/astra_typography.dart` | 123 | `AstraTypography.label(BuildContext)` | `labelFor(colors)` utilisé partout |
| `lib/core/constants/astra_typography.dart` | 125 | `AstraTypography.caption(BuildContext)` | `captionFor(colors)` utilisé partout |
| `lib/core/constants/astra_typography.dart` | 128 | `AstraTypography.data(BuildContext)` | `dataFor(colors)` utilisé partout |
| `lib/core/constants/display_unit_preferences.dart` | 10 | `DistanceDisplayUnit.displayLabel` | Getter défini, jamais référencé (`storageValue` oui) |
| `lib/core/constants/display_unit_preferences.dart` | 25 | `WeightDisplayUnit.displayLabel` | Idem |
| `lib/core/constants/display_unit_preferences.dart` | 40 | `HeightDisplayUnit.displayLabel` | Idem |
| `lib/core/ids/sample_id_generator.dart` | 11 | `SampleIdGenerator.nextId()` | Aucun appel dans `lib/` (uniquement tests) — API réservée |
| `lib/core/metrics/trends_insights.dart` | 6 | `countDaysWithSteps()` | Appelée uniquement dans le même fichier ; pourrait être privée |
| `lib/core/di/app_dependencies.dart` | 71 | `AppDependencies.ingestionSources` | Champ public jamais lu hors `app_dependencies.dart` |
| `lib/core/di/app_dependencies.dart` | 72 | `AppDependencies.stepNormalizer` | Idem |
| `lib/presentation/cubits/today_cubit.dart` | 71 | `TodayCubit.liveStepAppliesPaused` | Getter `@visibleForTesting` jamais lu ; seul le setter est appelé |
| `lib/core/debug/live_pipeline_log.dart` | 57 | `resetLivePipelineLogThrottleForTests()` | API test-only (intentionnel) |
| `lib/core/services/app_lifecycle_coordinator.dart` | 232 | `runLocalDayBoundaryIfNeededForTest()` | API test-only (intentionnel) |
| `lib/data/csv/timeseries_csv_codec.dart` | 100 | `TimeseriesCsvCodec.splitCsvRecords` | Usage interne + tests uniquement |
| `lib/data/csv/timeseries_csv_codec.dart` | 151 | `TimeseriesCsvCodec.parseHeaderRow` | Idem |
| `lib/data/csv/timeseries_csv_codec.dart` | 168 | `TimeseriesCsvCodec.parseDataRow` | Idem |

**Écartés (faux positifs fréquents)** : `resolveActivityPermission` (défaut dans `onboarding_cubit.dart`), `onCreateV1/V2/V3` (appelées dans `migrations.dart`), getters l10n (`l10n.menuTitle` etc.), champs de modèles (`ImportResult.insertedCount`…), `foregroundBackfill` / `isUiActive` (lus dans `app.dart` / DI).

---

## **2. Paramètres à valeur par défaut effectivement constants**

| **Fichier** | **Ligne** | **Élément** | **Raison de suspicion** |
| --- | --- | --- | --- |
| `lib/presentation/widgets/profile_info_row.dart` | 15 | `ProfileInfoRow(enabled = true)` | Jamais passé `enabled: false` aux 2 call sites |
| `lib/presentation/widgets/profile_info_row.dart` | 16 | `ProfileInfoRow(semanticsHint)` | Jamais passé ; `editHint` utilise toujours `l10n.commonDoubleTapToEdit` |
| `lib/presentation/widgets/menu_nav_row.dart` | 16 | `MenuNavRow(semanticsHint)` | Jamais passé aux 4 call sites de `menu_hub_screen.dart` |
| `lib/presentation/onboarding/onboarding_progress_bar.dart` | 11 | `OnboardingProgressBar(totalSteps = 3)` | Toujours instancié sans `totalSteps` dans `onboarding_shell.dart` |
| `lib/presentation/cubits/today_cubit.dart` | 496 | `_refreshImpl(allowDayDecrease = false)` | Seul appel non-défaut : `allowDayDecrease: true` (l. 393) ; le défaut est la voie dominante |
| `lib/core/services/live_step_monitor.dart` | 78 | `watchTodaySteps(replayLatest = true)` | Seul override : `replayLatest: !catchUpActive` dans le coordinator |
| `lib/presentation/cubits/today_cubit.dart` | 202 | `refresh(silent = true)` | `silent: false` utilisé une fois (`today_screen.dart:341`) ; le défaut couvre la majorité des appels |

---

## **3. Champs initialisés jamais lus**

| **Fichier** | **Ligne** | **Élément** | **Raison de suspicion** |
| --- | --- | --- | --- |
| `lib/core/constants/astra_colors.dart` | 37 | `AstraColors.borderPrimary` | Assigné dans `light`/`dark`/`copyWith`/`lerp`, **jamais lu** pour du rendu (story 5.8 prévue, pas câblée) |
| `lib/presentation/cubits/today_cubit.dart` | 54 | `TodayCubit._pauseLiveStepApplies` | Écrit via setter, lu dans la logique interne ; le **getter public** `liveStepAppliesPaused` n'est jamais consommé |

**Écartés** : variables locales (`dateStr`, `oldest`/`newest` dans `trends_monthly_bar_chart.dart`), paramètres de widget (`ProfileInfoRow.editHint`), tokens `AstraSpacing.*` (tous référencés).

---

## **4. Branches if/switch probablement mortes**

| **Fichier** | **Ligne** | **Élément** | **Raison de suspicion** |
| --- | --- | --- | --- |
| — | — | — | **Aucun cas à haute confiance** |

Recherches effectuées :

- Aucun `if (true)` / `if (false)` dans `lib/`
- Switches sur enums : branches `default` servent de fallback pour entrées invalides (`parseDistanceDisplayUnit`, etc.) ou versions DB inconnues (`migrations.dart:23`)
- `HistoryPeriod.dayCount` : branche `months12` lève une `StateError` (intentionnel, pas morte)

---

## **5. Champs de state Cubit toujours à la valeur par défaut**

Pas de classes Freezed — states manuels dans `lib/presentation/cubits/`.

| **Fichier** | **Ligne** | **Élément** | **Raison de suspicion** |
| --- | --- | --- | --- |
| `lib/presentation/cubits/onboarding_state.dart` | 30 | `OnboardingState.totalSteps` (static) | Constante `3`, jamais dans un `emit()` ; lue via `OnboardingState.totalSteps` dans le cubit |
| `lib/presentation/cubits/my_data_state.dart` | 21 | `MyDataState.isIos` | Fixé au premier `emit(ready)`, **jamais** via `copyWith(isIos:)` — immuable après init |
| `lib/presentation/cubits/my_data_state.dart` | 23–31 | `exportError`, `importError`, `purgeError`, `*SuccessPending` | Restent à `null`/`false` sur le happy path ; modifiés uniquement sur chemins erreur/succès |

**Conclusion** : aucun champ d'instance n'est structurellement orphelin (tous ont au moins un chemin d'`emit`). Les nullable d'erreur sont des états « dormants » sur le happy path, pas du code mort.

---

## **6. Constantes `theme/` / `constants/` non référencées ailleurs**

| **Fichier** | **Ligne** | **Élément** | **Raison de suspicion** |
| --- | --- | --- | --- |
| `lib/core/constants/preference_keys.dart` | 5 | `kDefaultAccentPresetStorage` | Définie, jamais importée/utilisée |
| `lib/core/constants/preference_keys.dart` | 22 | `kDefaultDistanceDisplayUnit` | Idem (`parseDistanceDisplayUnit` utilise le littéral `'metric'`) |
| `lib/core/constants/preference_keys.dart` | 23 | `kDefaultWeightDisplayUnit` | Idem |
| `lib/core/constants/preference_keys.dart` | 24 | `kDefaultHeightDisplayUnit` | Idem |

**Écartés** : `darkerGrotesque` / `figtree` (utilisés dans le même fichier), tous les `AstraSpacing.*` (largement référencés), `kDefaultStepGoal`, `kMinHeightCm`, etc.

---

## **7. TODO / FIXME / HACK (liste brute)**

- `lib/presentation/screens/app_scaffold.dart:173` **TODO** — If the widget is unmounted mid-flux, we return silently to avoid StateError.

---

### **Synthèse actionnable**

| **Priorité** | **Action suggérée** |
| --- | --- |
| Haute | Supprimer ou brancher `AstraColors.borderPrimary` ; retirer les 5 wrappers `AstraTypography.*(BuildContext)` morts |
| Moyenne | Retirer les 3 getters `displayLabel` ; factoriser les 4 constantes `kDefault*DisplayUnit` / `kDefaultAccentPresetStorage` ou les utiliser dans les parseurs |
| Basse | Rendre privées `countDaysWithSteps`, `ingestionSources`/`stepNormalizer` si non exposés volontairement ; retirer le getter `liveStepAppliesPaused` si les tests n'en ont pas besoin |
| Info | 1 seul TODO dans tout `lib/` ; APIs `*ForTest` sont intentionnelles |

Souhaitez-vous que je prépare un patch de nettoyage ciblé (par ex. typography + `borderPrimary` + constantes orphelines) ?