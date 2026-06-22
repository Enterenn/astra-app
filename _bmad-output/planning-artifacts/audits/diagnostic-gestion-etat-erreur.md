# **Diagnostic — gestion des états d'erreur UI**

Périmètre analysé : `lib/presentation/cubits/`, `lib/presentation/screens/`, `lib/presentation/widgets/`, et tous les `catch` dans `lib/`.

**Note :** aucun `BlocConsumer` dans le projet. `TodayScreen` et `MyDataScreen` utilisent respectivement `BlocSelector` et `context.watch` + `BlocListener` pour la réactivité.

---

## **Section 1 — États d'erreur dans les cubits**

| **Cubit** | **État erreur** | **Émis vers stream** | **Contenu** |
| --- | --- | --- | --- |
| **TodayCubit** | `TodayStatus.noPermission` | Oui | Permission activité refusée ; émis dans `refreshMetadata` / `_refreshImpl` |
| **TodayCubit** | `isStale == true` (pas un statut erreur) | Oui | Données périmées ; métadonnée, pas `status == error` |
| **TodayCubit** | `updateDailyStepGoal` — `catch` persist/refresh | Non | `debugPrint` + `return false` ; pas de champ erreur |
| **TodayCubit** | `_persistLastDisplayedSteps` — `DatabaseException` | Non | `return` silencieux |
| **HistoryCubit** | Pas de statut `error` | — | `HistoryStatus` = `loading` / `empty` / `ready` uniquement |
| **HistoryCubit** | `refreshGoal` — `catch` | Non | `debugPrint` ; conserve le dernier état connu |
| **HistoryCubit** | `_refreshImpl` — `catch` | Partiel | `debugPrint` puis `_recoverFromRefreshFailure()` : réémet `ready` (cache) ou `empty` — **pas d'état erreur explicite** |
| **ProfileCubit** | `ProfileStatus.error` + `loadError: ProfileLoadError.generic` | Oui | Échec de `refresh()` |
| **ProfileCubit** | `updateDisplayName` / `updateHeightCm` / `updateWeightKg` — `catch` | Non | `debugPrint` + `return false` |
| **ProfileCubit** | `postDisplayNameUpdate` — `catch` | Non | `debugPrint` + `return false` (nom peut être sauvé sans refresh) |
| **ProfileCubit** | `setGoalNotificationsEnabled` — permission `catch` | Partiel | `debugPrint` puis vérifie permission ; `return false` si refus |
| **ProfileCubit** | `setGoalNotificationsEnabled` — persist `catch` | Non | `debugPrint` + `return false` |
| **MyDataCubit** | `exportError: MyDataExportError.generic` | Oui | Échec export CSV |
| **MyDataCubit** | `importError: MyDataImportError.generic` | Oui | Échec import (dont callback `confirmImport` absent) |
| **MyDataCubit** | `importError: MyDataImportError.validation` + `importValidationDetail` | Oui | Erreur de validation CSV |
| **MyDataCubit** | `purgeError: MyDataPurgeError.generic` | Oui | Échec purge |
| **MyDataCubit** | `purgeError: MyDataPurgeError.refreshFailedAfterPurge` | Oui | Purge OK mais refresh post-purge échoué |
| **MyDataCubit** | `backgroundStatus: permissionDenied` | Oui | Permission refusée (dérivé, pas un enum erreur) |
| **MyDataCubit** | `isStale` via `backgroundStatus.stale` | Oui | Données périmées |
| **MyDataCubit** | `_refreshImpl` — `catch` | Non | `debugPrint` + `_recoverFromRefreshFailure()` sans champ erreur |
| **MyDataCubit** | `postImportRefresh` — `catch` | Non | `debugPrint` seul ; import peut réussir sans refresh |
| **MyDataCubit** | `updateDailyStepGoal` / `updateDisplayName` — `catch` | Non | `debugPrint` + `return false` |
| **MyDataCubit** | Suppression fichier temp export — `catch (_) {}` | Non | Ignoré silencieusement |
| **OnboardingCubit** | `activityPermissionStatus: denied` | Oui | Permission refusée ou exception dans `_resolvePermission` |
| **OnboardingCubit** | `completeWithHeight` | — | **Pas de try/catch** ; exception non gérée |
| **LocaleCubit** | Pas d'état erreur | Non | `catch` → `return false` ; pas d'émission erreur |
| **UnitsCubit** | Pas d'état erreur | Non | 3× `catch` → `return false` |
| **ThemeCubit** | Pas d'état erreur | Non | **Pas de try/catch** ; exception propagée à l'appelant |

---

## **Section 2 — BlocBuilder / BlocConsumer dans screens & widgets**

Aucun `BlocConsumer` trouvé. Les patterns connexes (`BlocSelector`, `BlocListener`, `context.watch`) sont notés en italique.

| **Screen / Widget** | **Cubit** | **Erreur gérée** | **Affichage** | **Action récupération** |
| --- | --- | --- | --- | --- |
| `history_screen.dart` — `BlocBuilder` | HistoryCubit | Non (pas de statut erreur) | États `loading`/`empty`/`ready` dans les charts ; échec refresh → `empty` ou cache | Aucune |
| `profile_screen.dart` — `BlocBuilder` | ProfileCubit | Oui — `if (status == error)` | Texte inline centré (`profileLoadErrorGeneric`) | Aucune (pas de retry) |
| `profile_screen.dart` — `BlocBuilder` | UnitsCubit | N/A | Affichage unités uniquement | — |
| `profile_screen.dart` — callbacks hors Bloc | ProfileCubit | Oui — `saved == false` | SnackBar (`profileCouldNotSaveDisplayName/Height/Weight`) | Réouvrir l'éditeur manuellement |
| `settings_screen.dart` — `BlocBuilder` | ProfileCubit | Oui — `if (status == error)` | Texte inline centré (identique Profile) | Aucune |
| `settings_screen.dart` — `BlocBuilder` | LocaleCubit | Non dans le builder | — | SnackBar via `_pickLanguage` si `saved == false` |
| `settings_screen.dart` — `BlocBuilder` | UnitsCubit | Non dans le builder | — | SnackBar via `_pick*Unit` si `saved == false` |
| `settings_screen.dart` — `BlocBuilder` ×2 | ThemeCubit | Non | — | Aucune (pas de catch dans le cubit) |
| `settings_screen.dart` — Switch notifications | ProfileCubit | Oui — `saved == false` | SnackBar (`settingsNotificationUpdateError`) | Réessayer le switch |
| `my_data_screen.dart` — `BlocListener` ×3 | MyDataCubit | Succès uniquement | SnackBar export/import/purge OK | — |
| `my_data_screen.dart` — `*context.watch*` | MyDataCubit | Oui — `exportError` / `importError` / `purgeError` | `StatusBanner` error (tap = retry action) | Tap bannière → relance export/import/purge |
| `my_data_screen.dart` — `*context.watch*` | MyDataCubit | Oui — `isStale` | `StatusBanner` staleFull | Aucune |
| `my_data_screen.dart` — `*context.watch*` | MyDataCubit | Oui — `backgroundStatus.permissionDenied` | `BackgroundStatusCard` + bouton settings | `openAppSettings()` |
| `activity_stats_row.dart` — `BlocBuilder` | UnitsCubit | N/A | Unités distance | — |
| `activity_stats_row.dart` — prop `status` | TodayStatus | Partiel — `noPermission` | Zéros silencieux (`0`, `0.0`, `00:00:00`) | Aucune |
| `onboarding_height_page.dart` — `BlocBuilder` | OnboardingCubit | Non | Picker hauteur | — |
| `onboarding_weight_page.dart` — `BlocBuilder` | OnboardingCubit | Non | Picker poids | — |
| `onboarding_flow.dart` — `*BlocListener*` | OnboardingCubit | Non (écoute `completed` seulement) | — | — |
| `*today_screen.dart` — `BlocSelector` ×6* | TodayCubit | Voir détail ci-dessous | — | — |

**Détail TodayScreen (`BlocSelector`, pas `BlocBuilder`) :**

| **Widget** | **Condition** | **Affichage** | **Récupération** |
| --- | --- | --- | --- |
| `_StaleBannerSlot` | `isStale && !noPermission && !loading` | `StatusBanner` staleCompact | Tap → `refresh(silent: false)` |
| `_PermissionCta` | `noPermission` | `TextButton` (`errorNoPermission`) | `openAppSettings()` |
| `_CollectionHealthSlot` | `permissionDenied` / `stale` | `CollectionHealthIndicator` caption inline | Aucune |
| `_GoalRingCard` / `GoalRing` | `noPermission` | Anneau `--`, piste pointillée | Via `_PermissionCta` uniquement |
| `_onSetGoalTapped` | `updateDailyStepGoal` → `false` | SnackBar (`todayGoalSaveError`) | Réouvrir l'éditeur |

---

## **Section 3 — `catch(e)` log-only sans émission d'état erreur UI**

### **Dans `lib/presentation/cubits/`**

- **TodayCubit** — `updateDailyStepGoal` (persist + postGoalUpdate) : `debugPrint` + `return false`
- **TodayCubit** — `_persistLastDisplayedSteps` : `DatabaseException` → `return` silencieux
- **HistoryCubit** — `refreshGoal` : `debugPrint` uniquement
- **HistoryCubit** — `_refreshImpl` : `debugPrint` + recovery silencieuse (pas de statut erreur)
- **ProfileCubit** — `updateDisplayName`, `postDisplayNameUpdate`, `updateHeightCm`, `updateWeightKg`, permission notification, `setGoalNotificationsEnabled` : `debugPrint` + `return false`
- **MyDataCubit** — `postImportRefresh`, `_refreshImpl`, `_recoverFromRefreshFailure`, `updateDailyStepGoal`, `updateDisplayName` : `debugPrint` (+ recovery ou `return false`)
- **MyDataCubit** — suppression fichier temporaire export : `catch (_) {}`
- **OnboardingCubit** — `_resolvePermission` : `debugPrint` puis émet `denied` (pas un état erreur dédié, mais émis)
- **LocaleCubit** / **UnitsCubit** — `catch (_) { return false }` sans log

### **Hors couche présentation (`lib/` — pas de cubit/UI)**

- `main.dart` — init `NotificationService` : `debugPrint`
- `core/services/notification_service.dart` — init timeout/échec, `showGoalReached` : `debugPrint`
- `core/services/health_foreground_service.dart` — start/stop/setUiActive : `debugPrint`
- `core/services/app_lifecycle_coordinator.dart` — transitions lifecycle, resume pipeline : `debugPrint` / `livePipelineLog`
- `core/services/fgs_step_collection.dart` — collecte FGS : `debugPrint` + `return false`
- `core/services/workmanager_callback.dart` — collecte + maintenance DB : `debugPrint` + `return false`
- `core/services/background_collector.dart` — échec par source : `debugPrint` (continue les autres sources)
- `core/di/app_dependencies.dart` — collecte FGS in-process : `debugPrint` + `return false`
- `presentation/screens/app_scaffold.dart` — `postPurgeRefresh` : `debugPrint` + `rethrow`
- `data/csv/timeseries_csv_codec.dart` — rethrow en `ImportValidationException` (pas log-only)
- `core/database/astra_database_session.dart` — reopen ou rethrow (pas UI)

---

## **Section 4 — Même condition d'erreur, affichages différents**

### **Permission activité refusée**

| **Écran / zone** | **Affichage** | **Action** |
| --- | --- | --- |
| **Today** — `_PermissionCta` | `TextButton` avec `errorNoPermission` | `openAppSettings()` |
| **Today** — `CollectionHealthIndicator` | Caption inline `todayCollectionHealthPermissionDenied` | Aucune |
| **Today** — `GoalRing` | `--` + anneau pointillé | Aucune directe |
| **Today** — `ActivityStatsRow` | Zéros sans message | Aucune |
| **My Data** — `BackgroundStatusCard` | Texte body `myDataBackgroundPermissionDenied` | Bouton `myDataOpenSettings` → `openAppSettings()` |
| **Onboarding** — intro | Aucun message si `denied` ; flow continue à l'étape poids | Aucune |

→ **4 traitements visuels** pour la même condition sur Today seul, plus un 5ᵉ sur My Data.

### **Données périmées (stale)**

| **Écran** | **Affichage** | **Action** |
| --- | --- | --- |
| **Today** — `_StaleBannerSlot` | `StatusBanner` compact (1 ligne) | Tap → `refresh()` |
| **Today** — `CollectionHealthIndicator` | Caption stale avec horodatage relatif | Aucune |
| **My Data** — bannière | `StatusBanner` staleFull (texte long iOS/Android) | **Aucune** (pas de `onTap`) |

### **Échec de chargement / refresh silencieux**

| **Cubit** | **Comportement UI** |
| --- | --- |
| **HistoryCubit** refresh échoué | Passe en `empty` ou réaffiche le cache → l'utilisateur ne voit pas d'erreur |
| **MyDataCubit** refresh échoué | Réémet l'état `ready` existant ou un snapshot dégradé → pas de bannière erreur |

### **Échec de sauvegarde objectif quotidien**

| **Point d'entrée** | **Feedback** |
| --- | --- |
| **TodayScreen** — éditeur objectif | SnackBar `todayGoalSaveError` |
| **MyDataCubit.updateDailyStepGoal** | `return false` sans état erreur ; **pas d'UI** (méthode non branchée à un écran) |

### **Échec chargement profil**

| **Écran** | **Affichage** |
| --- | --- |
| **ProfileScreen** | Texte inline centré |
| **SettingsScreen** | Identique — **cohérent** |

### **Échec préférences (locale / unités / notifications)**

Tous via **SnackBar** dans `settings_screen.dart` — pattern homogène, mais différent du texte inline utilisé pour l'erreur de chargement profil.

---

## **Synthèse des écarts principaux**

1. **Pas de modèle d'erreur unifié** — seuls `ProfileCubit` et `MyDataCubit` (actions) ont des enums erreur explicites ; `HistoryCubit` et les échecs de refresh masquent l'erreur.
2. **Permission refusée** — la condition la plus fragmentée (5+ représentations, 1 seul CTA settings sur Today et My Data).
3. **BlocConsumer absent** — erreurs action (SnackBar) gérées hors builders via `Future<bool>` + callbacks.
4. **ThemeCubit** — seul cubit de préférences sans `catch` ni feedback UI en cas d'échec persist.
5. **Onboarding** — permission refusée mappée en `denied` mais sans message utilisateur ; `completeWithHeight` sans gestion d'erreur.