# Diagnostic — préférences utilisateur

**Généré :** 2026-07-21  
**Base code :** `0.12.0+30` (`pubspec.yaml`)  
**Périmètre :** `UserHealthMetricsRepository` · `UserSettingsRepository` · `UserPreferencesKvStore` · migration v3 `daily_goal_effective`  
**Statut global :** `partial`

---

## Statut

- **Dernière vérification :** 2026-07-21
- **Statut :** `partial`
- **Story / PR :** —

---

## Synthèse

| Priorité | # | Domaine | Statut |
|----------|---|---------|--------|
| 🟡 P1 | 1 | Double source de vérité objectif du jour | `open` |
| 🟡 P2 | 2 | `isDatabaseOpen` trompeur (peut lever) | `open` |

---

## 🟡 À surveiller

### 1. Deux sources de vérité pour l'objectif du jour

**Constat :** Objectif du jour maintenu en parallèle sans lien structurel (FK, trigger, vue).

| Store | Clé / table | Lecteur | Rôle |
|-------|-------------|---------|------|
| Cache prefs | `user_preferences.daily_step_goal` (`kDailyStepGoalKey`) | `getDailyStepGoal()` | Valeur courante editable |
| Journal effectif | `daily_goal_effective` | `getGoalForLocalDay` / `getGoalsForLocalDays` | Historique par jour local |

| Référence | Détail |
|-----------|--------|
| `lib/data/repositories/user_health_metrics_repository.dart:30-36` | `getDailyStepGoal()` — prefs uniquement |
| `lib/data/repositories/user_health_metrics_repository.dart:40-56` | `getGoalForLocalDay()` — journal SQL |
| `lib/data/repositories/user_health_metrics_repository.dart:101-137` | `setDailyStepGoal` — txn : journal (insert/update) + prefs |
| `lib/core/database/migrations.dart:97-132` | v3 : seed journal depuis prefs legacy |
| `lib/data/contracts/user_health_metrics_repository_contract.dart` | **`getDailyStepGoal` absent du contrat** |

**Cohérence actuelle :** `setDailyStepGoal` écrit les deux en une transaction — OK tant que tout passe par cette API.

**Chemins prod (comparaison / notif) :** utilisent `getGoalForLocalDay(todayIso)` — Today, History, BackgroundCollector (Story 8.2).

**Vestige / display :** `getDailyStepGoal()` reste sur la classe concrète ; **aucun appel dans `lib/`** hors repository. Usages restants : **tests** + doc stories. My Data affiche `state.dailyStepGoal` (défaut `kDefaultStepGoal`, mis à jour via `setDailyStepGoal` sans reload journal au refresh).

**Risque :** Futur write ne mettant à jour qu'une des deux stores → divergence historique vs cache / editor My Data.

**Piste :** Converger lecture display vers `getGoalForLocalDay(formatLocalDayIso(clock.snapshot()))` ; deprecate / retirer `getDailyStepGoal()` ; ou contrainte doc « single writer » + test d'intégrité prefs↔journal.

---

### 2. `isDatabaseOpen` trompeur

**Constat :** Getter nommé comme un prédicat booléen, mais délègue à `AstraDatabaseSession.database` qui **lève** si DB null ou fermée — ne retourne jamais `false` dans ces cas.

| Référence | Détail |
|-----------|--------|
| `lib/data/repositories/_user_preferences_kv_store.dart:13` | `bool get isDatabaseOpen => _session.database.isOpen` |
| `lib/core/database/astra_database_session.dart:20-25` | `database` → `StateError('Database is not open')` si null ou `!isOpen` |
| `lib/data/repositories/user_settings_repository.dart:30` | Exposé via contrat `UserSettingsRepositoryContract` |
| `lib/presentation/cubits/today/today_live_pipeline.dart:198` | `if (!userSettings.isDatabaseOpen) return` — ne protège pas si DB fermée (exception avant le `return`) |

**Piste :** Renommer (`tryGetDatabase`) ou implémenter safe : `_db?.isOpen ?? false` sans passer par le getter throwing.

---

## 🟢 Points forts constatés

| Domaine | Preuve |
|---------|--------|
| Validation entrée bornée | `setDailyStepGoal` > 0 ; height `kMinHeightCm`–`kMaxHeightCm` ; weight `kMinWeightKg`–`kMaxWeightKg` ; display name `kMaxDisplayNameLength` — `user_health_metrics_repository.dart:102-217` |
| Arrondi poids | `(weightKg * 10).round() / 10` — l.197-198 |
| `getGoalsForLocalDays` O(n+m) | Une requête journal + curseur — l.68-96 |
| Transaction `setDailyStepGoal` | Journal + cache prefs atomiques — l.106-137 |
| Séparation KV / métier | `UserPreferencesKvStore` (primitives) vs repositories (validation) |
| Journal goal normalisé | `_normalizeJournalGoal` — valeurs invalides → `kDefaultStepGoal` |
| Locale app validée | `setAppLocale` — `'en'` \| `'fr'` only — `user_settings_repository.dart:131-137` |
| Writes GoalRing sérialisés | `_runSerializedLastDisplayedWrite` — `user_settings_repository.dart:27-37` |

---

## Cartographie objectif (post v3)

```
setDailyStepGoal(goal)
  └─ txn
       ├─ daily_goal_effective (today row insert/update)
       └─ user_preferences.daily_step_goal (replace)

Comparaison ring / history / notif  → getGoalForLocalDay(todayIso)
Editor My Data (state)              → setDailyStepGoal + emit local state
getDailyStepGoal()                  → tests + API concrète legacy
```

---

## Plan d'action suggéré

| Phase | Action |
|-------|--------|
| **Doc** | Documenter rôle cache prefs vs journal ; single-writer `setDailyStepGoal` |
| **Moyen** | My Data refresh : charger via `getGoalForLocalDay(today)` |
| **Moyen** | Retirer ou `@Deprecated` `getDailyStepGoal()` ; test prefs↔journal sync |
| **Quick fix** | `isDatabaseOpen` safe bool ou renommage + fix guard `today_live_pipeline` |

---

## Navigation

- Dossier : [`audits_2/`](./)
- Stories : `8-1-daily-goal-history-schema` · `8-2-goal-history-consumer-migration` · `18-2-split-user-preferences-repository`
- Migration : `migrations.dart` v3
