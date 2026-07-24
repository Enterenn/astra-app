# Audits données & pipeline — index (`audits_2`)

**Généré :** 2026-07-21  
**Dernière resync :** 2026-07-24 (version `0.12.1+31`, P0-09 fixed — story 29-4)  
**Base code :** `0.12.1+31` (`pubspec.yaml`)  
**Périmètre :** couche SQLite → ingestion pedometer → `LiveStepMonitor` → compaction FR11 → WorkManager → agrégations charts → prefs utilisateur → permissions/notifications  
**Statut chantier :** `open` — aucun point marqué `fixed` dans ce dossier

Ce dossier complète [`audits/`](../audits/) (post-refacto Epics 21–28, UI/runtime) avec une analyse **granulaire du pipeline données** : chemins de fichiers, numéros de lignes, scénarios de failure, todos consolidées et liens croisés entre diagnostics.

**Usage agent / dev :** lire le diagnostic concerné **avant** d’ouvrir ou implémenter une story. Mettre à jour la colonne **Statut** du diagnostic **et** les tableaux ci-dessous quand un point est corrigé ou invalidé.

---

## Convention de statut

| Statut | Signification |
|--------|----------------|
| `open` | Constat validé, non traité |
| `partial` | Partiellement adressé ou nuance après relecture code |
| `fixed` | Corrigé dans le code courant — ne plus planifier |
| `invalid` | Faux positif ou hors périmètre — ignorer |

Priorités : **P0** critique (corruption données / sur-comptage / sécurité) · **P1** important · **P2** dette modérée · **P3** mineur · **Doc** documentation explicite requise

---

## Index des diagnostics

| # | Fichier | Domaine | Statut global | P0 ouverts | P1+ ouverts |
|---|---------|---------|---------------|------------|-------------|
| 01 | [diagnostic-couche-donnees.md](./diagnostic-couche-donnees.md) | SQLite, migrations, ingestion write, IDs | `open` | 3 | 4 |
| 02 | [diagnostic-permissions-notifications.md](./diagnostic-permissions-notifications.md) | Permissions activité/notif, `NotificationService` | `open` | 3 | 4 |
| 03 | [diagnostic-workmanager-maintenance-db.md](./diagnostic-workmanager-maintenance-db.md) | WM 15 min, maintenance hebdo, VACUUM, boot | `partial` | 0 | 3 |
| 04 | [diagnostic-downsampling-compaction-fr11.md](./diagnostic-downsampling-compaction-fr11.md) | FR11 compaction, `SampleCompactionRunner` | `partial` | 0 | 2 |
| 05 | [diagnostic-fuseaux-jours-locaux.md](./diagnostic-fuseaux-jours-locaux.md) | TZ, DST, clés regroupement, offset stocké | `partial` | 0 | 1 (doc) |
| 06 | [diagnostic-preferences-utilisateur.md](./diagnostic-preferences-utilisateur.md) | Prefs KV, journal objectif, `isDatabaseOpen` | `partial` | 0 | 2 |
| 07 | [diagnostic-ingestion-pedometer.md](./diagnostic-ingestion-pedometer.md) | `StepNormalizer`, `StepIncrementCalculator`, baseline | `fixed` | 0 | 0 |
| 08 | [diagnostic-charts-agregation-daily-monthly.md](./diagnostic-charts-agregation-daily-monthly.md) | History 30j, Trends 12 mois, `finestResolutionTotal` | `partial` | 0 | 2 |
| 09 | [diagnostic-live-step-monitor.md](./diagnostic-live-step-monitor.md) | Drain persist, affichage live, reset matériel | `partial` | 1 | 1 |

**Ordre de lecture recommandé (dépendances) :** 01 → 07 → **09** → 03 → 04 → 05 → 08 → 06 → 02

---

## Synthèse exécutive — P0 (11 points)

| ID | Point | Diagnostic | Fichiers clés | Correctif / action |
|----|-------|------------|---------------|-------------------|
| **P0-01** | Plaintext SQLite (NFR-4 Phase 0) — écart privacy marketing | 01 | `pubspec.yaml`, `app_database.dart` | SQLCipher Phase 1 **ou** disclaimer UX explicite |
| **P0-02** | Collision PK multi-types (`deterministicFromIngestionBucket` sans `type`/`resolution`) | 01 | `sample_id_generator.dart:30-37`, `migrations.dart:85-93` | Suffixe aligné sur `idx_bucket_identity` |
| **P0-03** | `insertDevSamplesBatch` protégé par `assert` (strippé release) | 01 | `step_ingestion_repository.dart:92-99` | Garde `if (!kDebugMode) throw` |
| **P0-04** | `permanentlyDenied` jamais modélisé — toggle/bouton muet | 02 | `onboarding_state.dart`, `profile_cubit.dart`, `settings_screen.dart` | État UI + CTA `openAppSettings()` |
| **P0-05** | Pas de `.request()` activité post-onboarding ; onboarding avance si denied | 02 | `onboarding_flow.dart:52-55` | Retry + ne pas `nextStep()` si denied |
| **P0-06** | `_initializePlatform` avale erreurs — `initialize()` ne rethrow jamais | 02 | `notification_service.dart:105-122` | `rethrow` ou signal explicite |
| **P0-07** | Double comptage : upsert buckets sans txn avec `setBaseline` | 03 | `background_collector.dart:116-128` | **Fixed** — Story 29-3 : txn atomique par source |
| **P0-08** | VACUUM maintenance sans lock vs collecte WM 15 min | 03 | `data_lifecycle_service.dart`, `workmanager_callback.dart` | **Fixed** — Story 30-1 : `kDatabaseMaintenanceLockKey` + TTL 10 min |
| **P0-09** | Compaction : `ConflictAlgorithm.ignore` puis delete sources inconditionnel | 04 | `sample_compaction_runner.dart` | **Fixed** — Story 29-4 : `CompactionInsertOutcome` + guard delete |
| **P0-10** | `terminalBaseline: lastCumulative` au lieu de `baseline` (bruit capteur) | 07 | `step_normalizer.dart:108` | `baseline ?? initialBaseline` |
| **P0-11** | Drain `sinceCumulative` : filtre `>` élimine resets matériels avant normalizer | 09 | `live_step_monitor.dart:333-346`, `monitor_drain_source.dart:29` | **Fixed** — Story 29-2 : pass-through `<= baseline/2` + drop log |

---

## Liens croisés entre diagnostics

### Intégrité des pas — sur-comptage, sous-comptage, pertes (causes distinctes)

| Cause | Diagnostic | Mécanisme | Symptôme |
|-------|------------|-----------|----------|
| Baseline persistée trop basse après bruit rejeté | **07** | `lastCumulative` ≠ `baseline` interne → cycle suivant crédite trop | Sur-comptage |
| Upsert additif + baseline non commitée mid-cycle | **03** | `ON CONFLICT DO UPDATE value +=` + exception avant `setBaseline` | **Fixed (29-3)** — txn rollback buckets + baseline |
| Compaction delete sans insert effectif | **04** | Sources fines supprimées, agrégat obsolète conservé | **Fixed (29-4)** — insert-or-verify before delete |
| Drain `>` aveugle après reboot matériel | **09** | Lectures `< baseline` jetées avant `StepIncrementCalculator` | **Fixed (29-2)** — pass-through reset threshold |
| Multi-résolution même jour | **05, 08** | Atténué en lecture par `finestResolutionTotal` — **ne pas sommer toutes résolutions** | — |

### Duplication logique « créditer cette lecture ? »

| Zone | Règles divergentes | Diagnostics |
|------|-------------------|-------------|
| Permissions | `isLimited`/`isProvisional` notification vs activity | **02** |
| Persist pedometer | Filtre drain `>` vs calculateur `baseline/2` | **09** vs **07** |

### Concurrence SQLite multi-isolate

| Sujet | Diagnostic 01 | Diagnostic 03 | Audits v1 |
|-------|---------------|-----------------|-----------|
| `withRetry` / `database_closed` | `fixed` — `busy_timeout` 5000 ms (30-2) | UI offload VACUUM OK ; WM vs WM gap | [diagnostic-acces-concurrents.md](../audits/diagnostic-acces-concurrents.md) E21 done |
| Lock cross-isolate | `IngestionCollectionLock` collecte | **Absent** sur maintenance/VACUUM | Story 21-4 |

### Fuseaux / DST / agrégation

| Sujet | Diagnostic | Impact |
|-------|------------|--------|
| Offset stocké par row, jamais recalculé | **05** | Intégrité historique voyages/DST |
| Jours DST non compactés (voulu) | **05** | Plus de lignes 5min/hourly — **charts OK** via finest tier (**08**) |
| IDs compaction incluent `resolution` | **04, 05** | Contraste bug ID ingestion (**01**) |

### Permissions (chevauchement audits v1)

| Sujet | audits_2 | audits v1 |
|-------|----------|-----------|
| Permission fragmentée Today | **02** | [diagnostic-gestion-etat-erreur.md](../audits/diagnostic-gestion-etat-erreur.md) — E28 backlog |
| `openAppSettings` activité | **02** partial (Today, My Data) | — |

---

## Inventaire complet des findings (par diagnostic)

### 01 — Couche données

| # | Priorité | Finding | Statut | Réf. |
|---|----------|---------|--------|------|
| 1 | P0 | Chiffrement au repos absent | `open` | `sqflite` pur, `astra_app.db` clair |
| 2 | P0 | Collision ID multi-types | `open` | `sample_id_generator.dart:30-37` |
| 3 | P0 | Garde-fou `assert` dev/prod | `open` | `step_ingestion_repository.dart:92-99` |
| 4 | P1 | Regex identity case-sensitive | `open` | `sample_id_generator.dart:35` |
| 5 | P1 | Contention multi-isolate sans `busy_timeout` | `fixed` (30-2) | `app_database.dart` |
| 6 | P2 | `testHookAfterDeleteSamples` dans contrat public | `open` | `step_ingestion_repository_contract.dart` |
| 7 | P2 | Migration v3 `DateTime.now()` non déterministe | `open` | `migrations.dart:119-123` |

**Points forts :** migrations idempotentes, CHECK steps entiers, `idx_bucket_identity`, upsert additif, purge sélective, WAL + retry session.

---

### 02 — Permissions & notifications

| # | Priorité | Finding | Statut | Réf. |
|---|----------|---------|--------|------|
| 1 | P0 | `permanentlyDenied` non distingué | `open` | Aucun `isPermanentlyDenied` dans `lib/` |
| 2 | P0 | Re-demande activité post-onboarding | `partial` | Settings OK ; pas `.request()` ; onboarding `nextStep()` inconditionnel |
| 3 | P0 | `_initializePlatform` avale erreurs | `open` | `notification_service.dart:118-122` |
| 4 | P1 | `_mapPermissionStatus` dupliqué / `isLimited` sur activity | `open` | 3 fichiers |
| 5 | P1 | Catch → `denied` masque bugs plateforme | `open` | `onboarding_cubit.dart:108-113` |
| 6 | P2 | Pas de dédup `setGoalNotificationsEnabled` | `open` | vs `_refreshInFlight` |
| 7 | P2 | Timeout background n'annule pas init | `open` | `notification_service.dart:67-79` |

**Deps :** `permission_handler ^12.0.1`, `flutter_local_notifications ^21.0.0`

**Points forts :** typedefs injectables, `isClosed` rigoureux ProfileCubit, pas de prompt iOS auto, défense `showGoalReached`.

---

### 03 — WorkManager & maintenance DB

| # | Priorité | Finding | Statut | Réf. |
|---|----------|---------|--------|------|
| 1 | P0 | Double comptage mid-cycle collecte | `fixed` (Story 29-3) | `background_collector.dart` txn per source |
| 2 | P0 | VACUUM sans lock vs collecte | `open` | WM maintenance `maintenanceOnCurrentConnection: true` |
| 3 | P1 | Pas de WM background iOS | `fixed` (30-3) | `project-context.md` §Platform background collection |
| 4 | P1 | Ordre cancel WM / init notifications | `partial` | `main.dart:61-63` |
| 5 | P2 | TTL lock 35s inadapté VACUUM | `open` | `ingestion_collection_lock.dart:14` |
| 6 | P2 | `DateTime.now()` dans `_TimeoutBoundedSource` | `open` | `background_collector.dart:220,227` |

**Tâches WM Android :**

| Unique name | Task | Fréquence |
|-------------|------|-----------|
| `astra_step_collection_periodic` | `astra_step_collection` | 15 min |
| `astra_database_maintenance_periodic` | `astra_database_maintenance` | 7 jours |

**Points forts :** `IngestionCollectionLock`, offload UI VACUUM via `compute`, dédup in-flight, WM testable.

---

### 04 — Downsampling / compaction FR11

| # | Priorité | Finding | Statut | Réf. |
|---|----------|---------|--------|------|
| 1 | P0 | `ignore` + delete sources sans vérif insert | `open` | 3 passes tier2/tier3 |
| 2 | P1 | `downsampleStepSamples(txn:)` atomicité déléguée | `partial` | Prod OK ; seul test utilise `txn:` |
| 3 | P2 | Compteurs `*Created` surcomptables si ignore | `open` | Stats `CompactionResult` |

**Flux :** `downsampleStepSamples` → txn → `runAllTiers` (5min→hourly, hourly→daily, catch-up 5min→daily).

**Points forts :** txn unique FR11, `isComplete*` + contiguïté, IDs `deterministicFromMergedBucket`, tests idempotence happy path.

---

### 05 — Fuseaux horaires / jours locaux

| # | Priorité | Finding | Statut | Réf. |
|---|----------|---------|--------|------|
| 1 | Doc | Journées DST jamais compactées (fail closed silencieux) | `open` | Comptes 12/24/288 + offset dans clés |
| 2 | — | Offset stocké par échantillon | `fixed` | `step_normalizer`, `timeseries_sample_model` |
| 3 | — | Clé regroupement inclut offset | `fixed` | `fiveMinuteGroupKey`, etc. |
| 4 | — | Triple vérif complétude avant merge | `fixed` | `isComplete*` + `ArgumentError` |

**Ne pas faire :** assouplir 24/288 sans math offset-aware.

---

### 06 — Préférences utilisateur

| # | Priorité | Finding | Statut | Réf. |
|---|----------|---------|--------|------|
| 1 | P1 | Double source vérité objectif (`daily_step_goal` vs `daily_goal_effective`) | `open` | `getDailyStepGoal` vestige ; prod → `getGoalForLocalDay` |
| 2 | P2 | `isDatabaseOpen` peut lever au lieu de `false` | `open` | `_user_preferences_kv_store.dart:13` ; guard `today_live_pipeline.dart:198` |

**Cartographie objectif :**

```
setDailyStepGoal → txn → journal + prefs cache
Comparaison ring/history/notif → getGoalForLocalDay(todayIso)
My Data editor → state local + setDailyStepGoal (pas reload journal au refresh)
```

**Points forts :** validation bornée, poids arrondi 1 décimale, `getGoalsForLocalDays` O(n+m), writes GoalRing sérialisés.

---

### 07 — Ingestion pedometer

| # | Priorité | Finding | Statut | Réf. |
|---|----------|---------|--------|------|
| 1 | P0 | `terminalBaseline` = `lastCumulative` ≠ `baseline` | `fixed` (Story 29-1) | `step_normalizer.dart:118` |

**Correctif :** `terminalBaseline: baseline ?? initialBaseline` — livré Story 29-1.

**Tests :** `rejects small counter dips` + `terminalBaseline reflects last accepted baseline not rejected reading`.

**Points forts :** reset/bruit/seuil relatif, cap 5 steps/s, `--dart-define=STEP_RATE_LIMIT_ENABLED`.

---

### 08 — Charts daily / monthly

| # | Priorité | Finding | Statut | Réf. |
|---|----------|---------|--------|------|
| 1 | P3 | Rollover `DateTime.utc` implicite (mois/jour 0) | `open` | `_step_chart_queries.dart:48-51,126-133` |
| 2 | P3 | SQL sans borne haute (`start_time >=` seulement) | `open` | Filtre jour local côté Dart |

**Consommateurs :** `HistoryCubit` (30j + 12 mois), `TodayWeekSelection` (7j).

**Points forts :** `finestResolutionTotal`, mois courant partiel, zero-fill daily, offset par ligne.

---

### 09 — LiveStepMonitor

| # | Priorité | Finding | Statut | Réf. |
|---|----------|---------|--------|------|
| 1 | P0 | Filtre `sinceCumulative` (`>`) élimine resets matériels | `fixed` (29-2) | `live_step_monitor.dart` drain gate |
| 2 | P1 | Duplication règle crédit drain vs `StepIncrementCalculator` | `fixed` (29-5) | `shouldForwardForPersistence` sur calculateur |

**Chaîne :** `MonitorDrainSource` → `drainReadingsForCollectionGated()` → `BackgroundCollector` → `StepNormalizer`.

**Impact :** sous-comptage **persist SQLite** après reboot ; affichage live (`_applyReadingToDelta`) non affecté.

**Test gap :** `idle_flush_persist_test.dart:146-168` valide skip « déjà crédité », pas scénario reboot (baseline 10k → readings 50/100/150).

**Points forts :** pas de write buckets, `_memoryBaseline` correct sur bruit, `_reconciling`, plancher monotone, buffer FIFO 250, day boundary, `livePipelineLog`.

---

## Todo master consolidée (priorisée)

### Quick fixes (1 PR possible)

| Todo | Diagnostics | Action |
|------|-------------|--------|
| Q1 | 07 | `terminalBaseline: baseline ?? initialBaseline` + test |
| Q2 | 09 | Fix filtre drain reset matériel + test reboot post-baseline 10k | **done** (29-2) |
| Q3 | 01 | Garde runtime `insertDevSamplesBatch` |
| Q4 | 01 | ID ingestion : inclure `type` + `resolution` |
| Q5 | 01 | `.toLowerCase()` identity provider/device |
| Q6 | 02 | `rethrow` dans `_initializePlatform` |

### P0 structurants (epics candidates)

| Todo | Diagnostics | Action |
|------|-------------|--------|
| E-A | 03, 04 | Mutex maintenance + guard compaction insert-before-delete |
| E-B | 07, 09, 03 | Intégrité baseline end-to-end (normalizer fix, drain reset, txn collecte) |
| E-C | 02 | Permission gates unifiés (`permanentlyDenied`, retry activité, notif Settings CTA) |
| E-D | 01 | Privacy at rest (SQLCipher Phase 1 ou disclaimer produit) |

### Documentation (sans changement comportement)

| Todo | Diagnostics | Action |
|------|-------------|--------|
| D1 | 05 | Commentaire DST non-compaction `lifecycle_compaction.dart` |
| D2 | 08 | Commentaire rollover `DateTime.utc` charts |
| D3 | 06 | Doc cache prefs vs journal objectif ; single-writer |
| D4 | 01 | NFR-4 / footprint plaintext si maintenu Phase 0 |

### Moyen terme

| Todo | Diagnostics | Action |
|------|-------------|--------|
| M1 | 01 | ~~`PRAGMA busy_timeout`~~ — done (30-2) |
| M2 | 01 | Retirer `testHookAfterDeleteSamples` du contrat |
| M3 | 01 | `TimeProvider` migration v3 |
| M4 | 06 | `isDatabaseOpen` safe + fix `today_live_pipeline` |
| M5 | 06 | My Data refresh via `getGoalForLocalDay(today)` ; deprecate `getDailyStepGoal` |
| M6 | 02 | Centraliser permission status par type |
| M7 | 03 | Boot gate cancel WM → await notification init |
| M8 | 03 | ~~Documenter gap iOS background~~ — done (30-3) |
| M9 | 08 | Borne haute SQL charts (perf) |

---

## Cartographie fichiers touchés (référence rapide)

| Zone | Fichiers principaux |
|------|---------------------|
| DB core | `lib/core/database/app_database.dart`, `migrations.dart`, `astra_database_session.dart` |
| IDs | `lib/core/ids/sample_id_generator.dart` |
| Ingestion write | `lib/data/repositories/step/step_ingestion_repository.dart` |
| Ingestion read/aggr | `lib/data/repositories/step/step_aggregation_repository.dart`, `_step_chart_queries.dart`, `_step_sample_bounds.dart` |
| Pedometer | `lib/data/datasources/step_normalizer.dart`, `step_increment_calculator.dart`, `monitor_drain_source.dart` |
| Live monitor | `lib/core/services/live_step_monitor.dart` |
| Collecte | `lib/core/services/background_collector.dart`, `ingestion_collection_lock.dart` |
| Lifecycle | `lib/core/lifecycle/sample_compaction_runner.dart`, `lifecycle_compaction.dart` |
| WM | `lib/core/services/workmanager_callback.dart`, `data_lifecycle_service.dart`, `main.dart` |
| TZ | `lib/core/time/local_day_calculator.dart`, `local_day_formatter.dart` |
| Prefs | `lib/data/repositories/user_health_metrics_repository.dart`, `user_settings_repository.dart`, `_user_preferences_kv_store.dart` |
| Permissions | `lib/core/permissions/activity_permission_resolver.dart`, `notification_service.dart`, `onboarding_cubit.dart`, `profile_cubit.dart` |

---

## Tests existants & gaps identifiés

| Zone | Tests | Gap |
|------|-------|-----|
| Normalizer | `step_normalizer_test.dart` (`@Tags critical`) | `terminalBaseline` couvert (bruit milieu + dernière position) — Story 29-1 |
| LiveStepMonitor | `live_step_monitor_test.dart`, `idle_flush_persist_test.dart` | Pas de test reboot : baseline haute → readings basses post-reset |
| Calculator | `step_increment_calculator_test.dart` | — |
| Compaction | `step_repository_downsample_test.dart`, `lifecycle_compaction_test.dart` | Pas de régression insert ignoré + delete |
| Collecte | `background_collector_test.dart` | Fault injection mid-cycle baseline — Story 29-3 |
| Charts | `step_repository_chart_*_test.dart` | — |
| TZ | `local_day_calculator_test.dart` (DST boundary) | Pas de test compaction jour DST |
| Lock | `ingestion_collection_lock_test.dart` | — |
| Notifications | `notification_service_test.dart` | Init failure rethrow non couvert |
| Prefs | `user_health_metrics_repository_test.dart` | Sync prefs↔journal si write partiel |

**Verify agents (workspace rules) :** `flutter test --tags critical` après fix normalizer ; tests localisés par fichier touché.

---

## Points forts globaux (à préserver)

- **Modèle local-first cohérent :** offset immuable par row, jour local dérivé de `(utc, zone_offset)`, pas de recalcul depuis fuseau device courant.
- **Défense profondeur ingestion :** CHECK SQL, index unicité bucket, upsert additif, lock cross-isolate collecte.
- **Compaction FR11 prudente :** complétude stricte, pas de fusion cross-offset, txn unique (même si bug ignore+delete à corriger).
- **Lecture anti double-comptage :** `finestResolutionTotal` partagé Today / History / Trends — résilience jours DST non compactés.
- **Séparation live vs persist :** `LiveStepMonitor` overlay UI indépendant du drain collecte — bug drain n'affecte pas l'affichage temps réel (**09**).
- **Testabilité :** typedefs injectables (permissions, notifications, WM), `CompactionWriter` abstrait, repos splittés read/write.
- **Séparation responsabilités :** normalizer vs calculator vs collector vs compaction vs chart queries vs KV store.

---

## Proposition de regroupement epics (draft)

| Epic | Titre draft | Diagnostics | Stories indicatives |
|------|-------------|-------------|-------------------|
| **E29?** | Intégrité comptage pas | 07, **09**, 03, 04 | Baseline fix, drain reset, txn collecte, compaction guard |
| **E30?** | Concurrence SQLite & maintenance | 03, 01 | Lock VACUUM, `busy_timeout` |
| **E31?** | Permissions & notifications UX | 02 | permanentlyDenied, retry, init rethrow |
| **E32?** | Hygiène données & IDs | 01, 06 | ID multi-type, dev guard, objectif single source |
| **E33?** | Doc & perf pipeline | 05, 08 | DST comment, chart SQL bound |

*(Numérotation à valider avec [`epics-post-audit.md`](../epics-post-audit.md) / sprint planning — E27–E28 restent backlog audits v1.)*

---

## Liens BMAD

| Document | Rôle |
|----------|------|
| [`audits/README.md`](../audits/README.md) | Index audits v1 (Epics 21–28) |
| [`epics-post-audit.md`](../epics-post-audit.md) | Stories 21–28 + AUDs différés |
| [`architecture.md`](../architecture.md) | NFR-4 SQLCipher, Today Display Truth Model |
| [`sprint-status-post-audit.yaml`](../../implementation-artifacts/sprint-status-post-audit.yaml) | Tracker actif |
| Stories clés | 4-1 downsampling · 8-1/8-2 goal history · 18-2/18-3 split repos · 21-4 ingestion lock · 2-9 Today Display Truth / live pipeline |

---

## Template de mise à jour

Quand un point est traité :

1. Mettre à jour la section **Statut** du diagnostic `.md` concerné.
2. Ajuster les tableaux **Index**, **P0**, **Todo master** dans ce README.
3. Référencer story/PR : ex. `29-1` ou `#123`.

```markdown
## Statut
- **Dernière vérification :** YYYY-MM-DD
- **Statut :** open | partial | fixed | invalid
- **Story / PR :** 29-1 ou #123
```

---

## Navigation

- Parent : [`planning-artifacts/`](../)
- Audits v1 : [`audits/`](../audits/)
- Projet : [`_bmad-output/README.md`](../../README.md)
- Contexte dev : [`docs/project-context.md`](../../../docs/project-context.md)
