# Audit global — reprise développement Phase 0

> **Généré le :** 2026-08-31  
> **Basé sur :** `0.15.2+40` (`pubspec.yaml`)  
> **Périmètre :** audit holistique post-pause (~1 mois sans commit, app stable en prod)  
> **Méthode :** relecture codebase complète (`lib/`, `test/`), `flutter analyze`, croisement diagnostics Epics 21–33  
> **Campagne :** [phase0-reprise](./README.md) · lookup [`manifest.yaml`](../manifest.yaml)

---

## Statut

| Champ | Valeur |
|-------|--------|
| **Statut global** | `scoped` |
| **Dernière vérification** | 2026-08-31 |
| **Epic cible** | E34–35 (Phase 0 reprise — **not** Phase 1 product) |
| **Prérequis** | Epics 1–33 done |
| **CE input** | [`sprint-change-proposal-2026-08-31.md`](../../sprint-change-proposal-2026-08-31.md) — **not** the matrix below |

---

## Résumé exécutif

**Verdict : codebase mature, production-ready, architecture pragmatique adaptée Phase 0.**

| Dimension | Note | Commentaire |
|-----------|------|-------------|
| Architecture | ✅ Solide | 3 couches documentées, single ingestion writer, DI explicite |
| Qualité code | ✅ Excellent | `flutter analyze` clean, 0 TODO/FIXME dans `lib/` |
| Tests | ✅ Substantiel | 79 fichiers · 647 cas · tags `critical`/`slow` |
| Performance | ⚠️ Acceptable | Goulot Trends (30× SQL) · `getTodaySteps` non agrégé |
| UI/UX | ✅ Bon | Design system cohérent · a11y principale OK · gaps permissions |

**Forces**
- Invariants data respectés (UTC + `zone_offset`, WAL, transactions)
- Zéro HTTP en release (privacy by architecture)
- `TodayScreen` : référence rebuild (`BlocSelector` + view models)
- 20 diagnostics Epics 21–33 déjà passés

**Top 3 actions ROI (avant Phase 1)**
1. Casser les 6 imports `core → presentation`
2. Finaliser funnel permissions (`permanentlyDenied`)
3. Batch SQL Trends (`getActiveBucketsForLocalDays`)

---

## Convention de priorité

| Niveau | Signification |
|--------|-----------------|
| **Élevé** | Bloque maintenabilité Phase 1 ou impact utilisateur direct |
| **Moyen** | Dette technique visible · quick win ou cohérence UX |
| **Bas** | Polish · différable Phase 1 |

---

## 1. Architecture & Structure

### 1.1 Organisation `lib/` — Priorité : Bas ✅

**Actuellement**

```
lib/  (206 fichiers)
├── core/          57 — DB, services, time, metrics, DI
├── data/          32 — contracts, repos, datasources, models
├── presentation/ 110 — cubits, screens, widgets (53 %)
└── l10n/           5
```

Découpage aligné README + `architecture.md`. Contracts (`data/contracts/`) isolent cubits des implémentations.

**Différent** — Pas de changement Phase 0. À Phase 1, introduire `lib/domain/` mince (types partagés + ports lifecycle) sans migration massive.

**Statut :** `fixed` (by design)

---

### 1.2 Inversion core → presentation — Priorité : Élevé 🔴

**Actuellement**

6 fichiers `core/` importent `presentation/` :

| Fichier | Import |
|---------|--------|
| `core/services/app_lifecycle_coordinator.dart` | `HistoryCubit`, `MyDataCubit`, `TodayCubit` |
| `core/services/lifecycle/lifecycle_session_state.dart` | idem |
| `core/services/lifecycle/lifecycle_live_pipeline_service.dart` | `today_state.dart` |
| `core/metrics/trends_insights.dart` | `history_state.dart` |
| `core/permissions/activity_permission_resolver.dart` | `onboarding_state.dart` |
| `core/permissions/notification_permission_resolver.dart` | `onboarding_state.dart` |

**Avant**

```dart
// core/metrics/trends_insights.dart
import '../../presentation/cubits/history_state.dart';

TrendsInsightAvailability computeInsightAvailability(...) { ... }
```

```dart
// core/services/app_lifecycle_coordinator.dart
void onResume() {
  depsGetter().todayCubit.refresh(silent: true);
}
```

**Après**

```dart
// lib/domain/models/trends_insight_availability.dart
class TrendsInsightAvailability {
  const TrendsInsightAvailability({
    required this.hasMinimumHistory,
    required this.hasWeeklyComparison,
  });
  final bool hasMinimumHistory;
  final bool hasWeeklyComparison;
}
```

```dart
// core/services/lifecycle_refresh_port.dart
abstract interface class LifecycleRefreshPort {
  Future<void> refreshToday({bool silent = false});
  Future<void> refreshHistory({bool silent = false});
  Future<void> refreshMyData({bool silent = false});
}

// presentation/coordinators/app_cubit_coordinator.dart
class AppCubitCoordinator implements LifecycleRefreshPort { ... }
```

**Statut :** `open`  
**Lié :** post-refacto-09 (convention structure) · post-refacto-11 (dépendances)

---

### 1.3 MyDataCubit god-object — Priorité : Élevé 🔴

**Actuellement**

`presentation/cubits/my_data_cubit.dart` — **748 lignes**. Mélange export CSV, import, purge, permissions, footprint, goal editor, field logs, 15+ imports cross-layer.

**Avant**

```dart
class MyDataCubit extends Cubit<MyDataState> {
  Future<void> exportCsv() async {
    // validation + temp file + picker + errors + refresh — inline
  }
}
```

**Après**

```dart
class MyDataExportController {
  Future<MyDataExportResult> export(CsvExportRequest request) async { ... }
}

class MyDataCubit extends Cubit<MyDataState> {
  Future<void> exportCsv() async {
    emit(state.copyWith(isExporting: true));
    final result = await _export.export(...);
    emit(state.copyWith(isExporting: false, exportError: result.error));
  }
}
```

Découper en `ExportController`, `ImportController`, `FootprintController`.

**Statut :** `open`  
**Lié :** post-refacto-09

---

### 1.4 Gestion de l'état (Cubit) — Priorité : Moyen 🟡

**Actuellement**

- 8 cubits · Today décomposé en 6 collaborateurs (`today_refresh_service`, `today_live_pipeline`, etc.)
- `AppCubitCoordinator` centralise refresh croisés
- Cubits root (`Theme`, `Units`, `Locale`) au `MaterialApp` ; feature cubits via `AppDependencies`

**Points positifs :** contracts repos, factory test, coordinator pattern.

**Statut :** `partial` (MyDataCubit + lifecycle coupling)

---

### 1.5 Composition root AppDependencies — Priorité : Bas ✅

**Actuellement**

445 lignes, factory `create()` + `test()`, 0 GetIt. Choix conscient solo-builder.

**Différent :** extraire sous-factories (`DataDependencies`, `BackgroundServices`) quand Phase 1 ajoute BLE + SQLCipher.

**Statut :** `fixed` (acceptable Phase 0)

---

### 1.6 Absence couche domain — Priorité : Bas ✅

**Actuellement**

Logique dans `core/metrics/`, repositories, cubits. Documenté dans `architecture.md`.

**Statut :** `fixed` (by design) · extraction progressive recommandée Phase 1

---

## 2. Qualité du code

### 2.1 Analyse statique — Priorité : Bas ✅

| Indicateur | Valeur |
|------------|--------|
| `flutter analyze` | 0 issues |
| TODO/FIXME/HACK `lib/` | 0 |
| `@Deprecated` | 1 (`getDailyStepGoal`) |
| Linter | `flutter_lints` + `discarded_futures` |

**Différent (optionnel) :** `strict-casts: true` dans `analysis_options.yaml`.

**Statut :** `fixed`

---

### 2.2 Gestion des erreurs UI — Priorité : Moyen 🟡

**Actuellement**

- My Data / Profile : enums d'erreur typés ✅
- `HistoryStatus` : `{ loading, empty, ready }` — **pas d'état `error`**
- Échec refresh History → repli silencieux cache ou `empty`
- Theme/Units/Locale : `catch (_) { return false; }` sans log

**Avant**

```dart
enum HistoryStatus { loading, empty, ready }

void _recoverFromRefreshFailure() {
  if (_cachedAggregates30d.isNotEmpty) {
    _emitReady(period: state.period); // utilisateur ne sait pas
    return;
  }
  emit(HistoryState.empty(...));
}
```

**Après**

```dart
enum HistoryStatus { loading, empty, ready, error }

void _recoverFromRefreshFailure(Object error) {
  if (_cachedAggregates30d.isNotEmpty) {
    emit(HistoryState.ready(..., refreshError: HistoryRefreshError.staleData));
    return;
  }
  emit(HistoryState.error(period: state.period));
}
```

**Statut :** `partial`  
**Lié :** post-refacto-04 (gestion état erreur)

---

### 2.3 Casts `as` aux frontières I/O — Priorité : Bas

**Actuellement**

~120 casts, concentrés SQLite / CSV / `Future.wait` tuples.

**Différent :** migrer hotspots vers records Dart 3 (`(a, b, c).wait`).

**Statut :** `open` (cosmétique)

---

### 2.4 Couverture tests — Priorité : Moyen 🟡

**Actuellement**

647 cas · 79 fichiers · 30 `@Tags(['critical'])`.

**Gaps :**
- `test/data/models/` — absent
- `test/presentation/formatters/` — absent
- `test/l10n/` — vide

**Statut :** `partial`  
**Lié :** post-refacto-10

---

### 2.5 Diagnostics Epics 21–33 résiduels — Priorité : Moyen 🟡

| Diagnostic | Statut | Reste ouvert |
|------------|--------|--------------|
| post-refacto-02 cold start | `partial` | boot latency |
| post-refacto-04 erreurs UI | `partial` | HistoryCubit |
| data-pipeline-02 permissions | `open`/`partial` | `_initializePlatform` avale erreurs (P0 #3) |
| data-pipeline-03 workmanager | `partial` | TTL lock 35s vs VACUUM (P2) |

**Statut :** `partial` (hérité campagnes précédentes)

---

## 3. Performance & Optimisation

### 3.1 Trends — 30 requêtes SQL parallèles — Priorité : Moyen 🟡

**Actuellement**

`history_cubit.dart` L285–290 : `Future.wait` sur 30× `getActiveBucketsForLocalDay`.

**Avant**

```dart
final bucketLists = await Future.wait(
  aggregates.map((a) => stepAggregation.getActiveBucketsForLocalDay(a.localDay)),
);
```

**Après**

```dart
// step_aggregation_repository.dart
Future<Map<DateTime, List<TimeseriesSampleModel>>> getActiveBucketsForLocalDays(
  Iterable<DateTime> localDays,
) async {
  final bounds = utcBoundsForLocalDays(localDays);
  final rows = await _session.run((db) => db.query(
    'timeseries_samples',
    where: 'type = ? AND resolution = ? AND value > 0 '
           'AND start_time >= ? AND start_time < ?',
    whereArgs: [kStepSampleType, kFiveMinuteResolution, bounds.start, bounds.end],
  ));
  return groupBucketsByLocalDay(rows, localDays);
}
```

**Statut :** `open`  
**Lié :** post-refacto-02 §AUD-10

---

### 3.2 getTodaySteps — lecture complète rows — Priorité : Moyen 🟡

**Actuellement**

`step_aggregation_repository.dart` L35–47 : query sans filtre resolution, agrégation Dart. Chemin chaud (`LiveStepMonitor`, `BackgroundCollector`, lifecycle).

**Après**

```dart
final rows = await db.rawQuery('''
  SELECT resolution, SUM(value) AS total
  FROM timeseries_samples
  WHERE type = ? AND start_time >= ? AND start_time < ?
  GROUP BY resolution
''', [...]);
return finestResolutionTotalFromRows(rows);
```

**Statut :** `open`

---

### 3.3 Re-renders UI — Priorité : Moyen 🟡

**Actuellement**

- `TodayScreen` : 7× `BlocSelector` + view models ✅ référence
- `MyDataScreen`, `ProfileScreen`, `SettingsScreen` : `context.watch` root → rebuild complet

**Avant** (`my_data_screen.dart` L131)

```dart
final state = context.watch<MyDataCubit>().state;
return SingleChildScrollView(child: Column(children: [/* 15+ widgets */]));
```

**Après**

```dart
BlocSelector<MyDataCubit, MyDataState, DatabaseFootprint?>(
  selector: (s) => s.footprint,
  builder: (_, footprint) => FootprintKpiRow(footprint: footprint),
),
```

**Statut :** `open`

---

### 3.4 Goal ring / charts — Priorité : Bas

**Actuellement**

- `goal_ring.dart` 894L · repaint ~60fps count-up · `RepaintBoundary` présent
- Charts sans `RepaintBoundary` · focus → `setState` stack complet

**Statut :** `open` (profiler avant action)

---

### 3.5 Bundle & réseau — Priorité : Bas ✅

0 HTTP · release sans `INTERNET` · 1 image runtime · fonts subset ~1.8 MB.

**Statut :** `fixed`

---

### 3.6 Fuites mémoire — Priorité : Bas ✅

Streams, timers, listeners : dispose correct (Epic 22). Buffer live capped 250 readings.

**Statut :** `fixed`  
**Lié :** post-refacto-03

---

## 4. UI & UX

### 4.1 Design system — Priorité : Bas ✅

Tokens : `AstraColors`, `AstraTypography`, `AstraSpacing`, 6 accent presets. Audit Epic 27 : `fixed`.

**Statut :** `fixed`

---

### 4.2 Accessibilité — Priorité : Moyen 🟡

**Actuellement**

- 28 clés `*Semantics` EN/FR
- Goal ring, charts clavier, reduce motion ✅
- **Gap :** `about_screen.dart` sans `Semantics` explicite

**Statut :** `partial`  
**Lié :** post-refacto-05

---

### 4.3 Funnel permissions — Priorité : Élevé 🔴

**Actuellement**

Audit data-pipeline-02 : statut global `open`/`partial`. Distinction `permanentlyDenied` incomplète ; `_initializePlatform` peut avaler erreurs.

**Après**

```dart
enum PermissionOutcome { granted, denied, permanentlyDenied }

switch (outcome) {
  case PermissionOutcome.permanentlyDenied:
    showDialog(..., action: openAppSettings);
  case PermissionOutcome.denied:
    showSnackBar(l10n.permissionDeniedRetry);
  case PermissionOutcome.granted:
    cubit.refresh();
}
```

**Statut :** `partial`  
**Lié :** data-pipeline-02 · post-refacto-04

---

### 4.4 États de chargement — Priorité : Moyen 🟡

Today : skeletons par section ✅. History : un seul `BlocBuilder` global.

**Statut :** `partial`  
**Lié :** post-refacto-06

---

### 4.5 Responsive / i18n — Priorité : Bas ✅

Mobile-first · breakpoint 480px footprint KPI · 100/100 clés EN↔FR.

**Statut :** `fixed`

---

## 5. Fichiers monolithiques (dette structurelle)

| Fichier | Lignes | Priorité |
|---------|-------:|----------|
| `presentation/widgets/goal_ring.dart` | 894 | Moyen |
| `presentation/cubits/my_data_cubit.dart` | 748 | Élevé |
| `presentation/screens/today_screen.dart` | 703 | Moyen |
| `presentation/widgets/astra_horizontal_ruler.dart` | 642 | Bas |
| `core/services/live_step_monitor.dart` | 539 | Bas |
| `core/di/app_dependencies.dart` | 445 | Bas |

**Statut global :** `partial` (Epic 25 a adressé lifecycle ; widgets restent)

---

## Matrice de priorisation consolidée

| # | Sujet | Priorité | Effort | Statut |
|---|-------|----------|--------|--------|
| 1 | Types domain + `LifecycleRefreshPort` | Élevé | 2–3 j | `open` |
| 2 | Permissions `permanentlyDenied` | Élevé | 1–2 j | `partial` |
| 3 | Découper `MyDataCubit` | Élevé | 2 j | `open` |
| 4 | `HistoryStatus.error` + bannière stale | Moyen | 0.5 j | `open` |
| 5 | Batch SQL Trends buckets | Moyen | 1 j | `open` |
| 6 | SQL aggregate `getTodaySteps` | Moyen | 0.5 j | `open` |
| 7 | `BlocSelector` My Data / Profile | Moyen | 1 j | `open` |
| 8 | Tests models + formatters | Moyen | 1 j | `open` |
| 9 | a11y About + skeletons Trends | Moyen | 0.5 j | `open` |
| 10 | Split goal_ring / today_screen | Moyen | 2 j | `open` |
| 11 | RepaintBoundary charts · index SQL | Bas | 0.5 j | `open` |

**Effort total estimé (items 1–9) :** ~10 jours

---

## Liens BMAD

| Document | Rôle |
|----------|------|
| [post-refacto/](../post-refacto/README.md) | Diagnostics Epics 21–28 |
| [data-pipeline/](../data-pipeline/README.md) | Diagnostics Epics 29–33 |
| [refactoring-audit-master-v0.6.1.md](../../refactoring-audit-master-v0.6.1.md) | Audit refacto Epics 14–20 |
| [architecture.md](../../architecture.md) | Décisions techniques |
| [epics.md](../../epics.md) | AC Epics 1–33 |
| [sprint-status.yaml](../../../implementation-artifacts/sprint-status.yaml) | Tracker stories |

---

## Template de mise à jour

```markdown
## Statut
| Champ | Valeur |
| **Statut global** | open | partial | fixed |
| **Dernière vérification** | YYYY-MM-DD |
| **Story / PR** | 34-x-… |
```
