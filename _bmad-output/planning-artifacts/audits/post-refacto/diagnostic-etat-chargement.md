# **Diagnostic des états de chargement et transitions UI**

## **1. Inventaire par écran / widget**

| **Écran / Widget** | **États définis (cubit)** | **Affichage loading** | **Durée estimée** |
| --- | --- | --- | --- |
| **TodayScreen** | `TodayStatus`: `loading`, `noPermission`, `empty`, `progress`, `goalMet`, `overflow` + `isStale`, `foregroundCatchUp`, `lastDisplayedStepsLoaded` | Pas d’écran plein : sections indépendantes (voir widgets ci-dessous). Titre et scroll toujours visibles. | **Long** au cold start (backfill + SQLite + prefs) ; **court** en refresh silencieux / metadata |
| **HistoryScreen** | `HistoryStatus`: `loading`, `empty`, `ready` + `HistoryPeriod` | Titre + `PeriodToggle` toujours visibles. Graphique en skeleton. Stats/insights masqués tant que `null`. | **Long** au 1er chargement (30j + 12 mois + buckets kcal) ; **court** si cache chaud (`refreshGoal`) |
| **MenuHubScreen** | Aucun cubit | Contenu statique immédiat | Instantané |
| **ProfileScreen** | `ProfileStatus`: `loading`, `ready`, `error` | Spinner centré plein écran → corps scrollable | **Instantané** (<100 ms, 4 lectures prefs) |
| **MyDataScreen** | `MyDataStatus`: `loading`, `ready` + `isExporting/Importing/Purging`, erreurs/succès pending | Scroll + bannières erreur/stale visibles. 3 sections avec mini-spinner (24 px) chacune. Boutons masqués en `loading`. | **Court** (<1 s) ; export/import/purge **long** (>1 s) |
| **SettingsScreen** | `ProfileCubit` (même états) + `LocaleCubit`, `UnitsCubit`, `ThemeCubit` (pas d’état loading) | Spinner plein écran tant que `ProfileStatus.loading` ; puis scroll complet | Profile : **instantané** ; prefs locale/unités/thème déjà en mémoire |
| **AboutScreen** | Aucun cubit ; `FutureBuilder<PackageInfo>` | Contenu statique ; version = `SizedBox.shrink()` puis texte (pas de spinner) | **Instantané** |
| **GoalRing** | `TodayStatus` + `lastDisplayedStepsLoaded` | Arc à 0 % ; centre = skeleton pulsé (`_GoalRingCenterSkeleton`) si `loading` ou prefs non chargées ; `--` si `noPermission` | Cold start : **long** ; changement de jour : **court** |
| **ActivityStatsRow** | `TodayStatus` | Placeholders `—` (pas de spinner) | Suit le cubit Today |
| **_WeekSection** | `weekDays` vide vs rempli | `CircularProgressIndicator` centré (h=72) si `weekDays.isEmpty` | **Court** (<1 s) |
| **CollectionHealthIndicator** | `CollectionHealthDisplay.loading` dérivé | `SizedBox.shrink()` (rien affiché) | N/A |
| **StepBarChart** | `HistoryStatus` | Skeleton barres statiques (7 barres grises) ; empty = texte ; ready = graphique interactif | **Long** au 1er fetch |
| **TrendsMonthlyBarChart** | `HistoryStatus` | Même pattern skeleton (12 barres) | **Long** |
| **PeriodToggle** | `HistoryPeriod` (pas d’état loading propre) | Toujours interactif | Instantané |
| **TrendsAverageStatsRow / PeakDay / InsightCards** | Données `null` en loading | Non rendus (`if state.periodAverages != null`) | — |
| **BackgroundStatusCard / FootprintKpiRow** | Via `MyDataStatus` | Remplacés par `_SectionLoadingIndicator` (spinner 24 px) | **Court** |
| **DataExportButton / Import / Purge** | `isExporting`, `isImporting`, `isPurging` | Spinner inline 20 px, bouton désactivé ; mutex `dataActionInFlight` | **Long** (I/O fichier) |
| **AstraButton** (générique) | `isLoading` | Spinner inline, désactivé | Variable |
| **StatusBanner** | Variantes stale/error | Pas d’état loading ; affiché selon `isStale` / erreurs | — |
| **GoalCelebration** | `showCelebration` | Effet shimmer décoratif (pas un loading) | Animation ~1–2 s |
| **GoalEditorSheet / éditeurs profil** | Aucun | Formulaire immédiat, pas de fetch | Instantané |
| **TabPlaceholderBody** | — | Texte placeholder (non utilisé en prod actuelle) | — |

### **Politique de refresh (cubits)**

| **Cubit** | **Refresh silencieux** | **Refresh explicite** |
| --- | --- | --- |
| **TodayCubit** | `silent: true` (défaut) : conserve l’UI | `silent: false` : émet `TodayStatus.loading` (bannière stale, skeleton ring) |
| **HistoryCubit** | Conserve graphique + données | Émet `loading` → skeleton (sauf si déjà `loading`) |
| **MyDataCubit** | Conserve contenu ready | Émet `loading` global (sauf si action export/import/purge en cours) |
| **ProfileCubit** | Si déjà `ready` : **pas** de spinner | Si `loading`/`error` : spinner plein écran |

---

## **2. Incohérences entre écrans**

1. **Skeleton vs spinner pour le même type d’attente (données locales SQLite)**
    - **Trends** : skeleton barres (`StepBarChart`, `TrendsMonthlyBarChart`)
    - **Today semaine** : `CircularProgressIndicator` pleine zone
    - **My Data** : mini-spinner par section
    - **Profile / Settings** : spinner plein écran centré
    - Même nature d’attente (lecture locale), 4 patterns différents.
2. **Refresh silencieux vs effacement**
    - **Today, History, MyData** : `silent: true` par défaut → contenu précédent maintenu
    - **Profile** : re-`refresh()` en état `ready` ne montre aucun indicateur
    - **History** à l’ouverture de l’onglet : `refresh()` **non silencieux** → skeleton même si données en cache
    - **Today** bannière stale : `refresh(silent: false)` → skeleton ring + masquage bannière stale
3. **Granularité du loading**
    - **Today** : loading par section (`BlocSelector` isolé)
    - **My Data** : loading par `SectionCard` mais écran scrollable entier
    - **Profile / Settings** : gate global (tout ou rien)
    - **History** : gate au niveau graphique seulement ; toggle période et titre toujours actifs
4. **Placeholders textuels vs skeleton**
    - **ActivityStatsRow** : `—` sans spinner
    - **GoalRing** : skeleton animé
    - **About** : espace vide pour la version (ni `—` ni spinner)
5. **Gestion d’erreur**
    - **Profile / Settings** : état `error` avec message texte, **sans bouton retry**
    - **History** : erreur silencieuse → cache ou `empty`
    - **MyData** : erreur par action (bannière `StatusBanner` cliquable)
    - **Today** : pas d’état `error` dédié
6. **Transitions animées**
    - **GoalRing** : count-up, micro-tick, catch-up foreground (600–1800 ms), skeleton pulsé
    - **Charts Trends** : apparition directe skeleton → graphique (pas de fade)
    - **Profile loading → ready** : coupure nette spinner → contenu
    - **History loading → empty** : skeleton → texte centré
7. **Skeleton animé vs statique**
    - **GoalRing** : pulse opacity
    - **Charts Trends** : barres grises fixes (pas d’animation)

---

## **3. États « fantômes » (UI interactive, données pas prêtes)**

1. **Today — bouton « Définir l’objectif »** : toujours tappable pendant `TodayStatus.loading` ou `lastDisplayedStepsLoaded == false` ; ouvre le sheet avec `todayEditableGoal` (fetch async séparé).
2. **Today — scroll + titre** : entièrement interactifs pendant le chargement initial.
3. **Today — ActivityStatsRow** : affiche `—` en loading mais ressemble à des données chargées (pas de style « disabled »).
4. **Today — sélection de jour** : au tap, `selectLocalDay` passe en `loading` mais la rangée semaine reste visible avec l’ancienne sélection jusqu’au rebuild ; ring en skeleton pendant le fetch du jour.
5. **Today — goal affiché `/objectif`** : visible sous le skeleton (objectif par défaut `kDefaultStepGoal` avant résolution réelle).
6. **History — PeriodToggle** : actif pendant `HistoryStatus.loading` ; `selectPeriod` peut changer la période affichée alors que le graphique est encore en skeleton.
7. **History — 1ère visite** : le cubit reste en `loading` tant que l’onglet n’a pas été ouvert (`onHistoryCubitReady` ne déclenche pas de refresh) ; pas visible mais état « zombie » en arrière-plan.
8. **MyData — structure complète** : titres, bannières stale/erreur visibles en `loading` ; seuls les contenus de section sont en attente.
9. **MyData / Profile — pas de refresh initial** : cubits créés au boot mais `refresh()` seulement à l’ouverture menu ; si jamais ouverts, restent en `loading`.
10. **Settings — dépendance ProfileCubit** : locale, unités et thème bloqués derrière le chargement profil alors qu’ils n’en ont pas besoin.
11. **About — version manquante** : écran entièrement navigable, numéro de version absent quelques ms sans feedback.
12. **Export/Import/Purge** : pendant une action, les autres boutons sont désactivés (`dataActionInFlight`) — comportement correct, mais le reste de l’écran reste scrollable.

---

## **4. Navigation par onglets (`AppScaffold` + `IndexedStack`)**

Structure : 3 enfants dans `IndexedStack` — Today (0), History (1), Menu/Navigator (2).

### **Mémorisation d’état**

| **Onglet** | **Position scroll** | **État de sélection / navigation** |
| --- | --- | --- |
| **Today (0)** | **Oui** — widget conservé monté par `IndexedStack` ; `SingleChildScrollView` garde son offset | **Oui** — `selectedLocalDay` et `_hasUserSelectedLocalDay` dans `TodayCubit` (instance unique dans `AppScaffold`) |
| **History (1)** | **Oui** — même mécanisme | **Oui** — `HistoryPeriod` persiste dans `HistoryCubit` ; données en cache (`_cachedAggregates30d`) |
| **Menu (2)** | **Oui** pour `MenuHubScreen` | **Oui** — `Navigator` avec pile de routes conservée (Profile, Data, Settings, About restent empilés au retour) |

Pas de `PageStorageKey` explicite : la persistance repose sur le maintien des widgets montés par `IndexedStack` (comportement Flutter standard).

### **Refreshs déclenchés au changement d’onglet**

- **Retour sur Today** : `refreshMetadata()` + `historyCubit.refreshGoal()` (silencieux)
- **Ouverture Trends** : `historyCubit.refresh()` (**non silencieux** → skeleton si données déjà affichées)
- **Push menu** : `profileCubit.refresh()` ou `myDataCubit.refresh()` selon destination

### **Ce qui n’est pas mémorisé entre sessions**

- Offset scroll et sélections sont **session courante** uniquement (cubits détruits au `dispose` de `AppScaffold`).

---

## **Synthèse rapide**

L’app adopte **deux philosophies** : Today/History privilégient le **contenu maintenu + refresh silencieux** avec des indicateurs locaux ; Profile/Settings utilisent un **gate plein écran**. Les patterns visuels de loading (skeleton, spinner section, spinner plein écran, tirets `—`) ne sont pas unifiés. Les principaux risques UX sont le **PeriodToggle actif pendant le skeleton Trends**, le **bouton objectif actif pendant le chargement Today**, et l’**absence de refresh initial** pour History/MyData tant que l’utilisateur n’ouvre pas ces destinations.