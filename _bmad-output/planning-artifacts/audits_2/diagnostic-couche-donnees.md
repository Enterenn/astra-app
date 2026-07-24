# Diagnostic — couche données (SQLite / ingestion)

**Généré :** 2026-07-20  
**Base code :** `0.12.1+31` (`pubspec.yaml`)  
**Périmètre :** ouverture DB → session → migrations → `StepIngestionRepository` → génération d'ID  
**Statut global :** `partial` (P0 #2 fixed — 32-1 · P0 #3 fixed — 32-2 · P1 #4 fixed — 32-1 · P1 #5 fixed — 30-2)

---

## Statut

- **Dernière vérification :** 2026-07-25
- **Statut :** `partial`
- **Story / PR :** Story 32-1 (#2, #4) · Story 32-2 (#3)

---

## Synthèse

| Priorité | # | Domaine | Statut |
|----------|---|---------|--------|
| 🔴 P0 | 1 | Chiffrement au repos absent | `open` |
| 🔴 P0 | 2 | Collision ID multi-types | `fixed` (32-1) |
| 🔴 P0 | 3 | Garde-fou dev/prod (`assert`) inopérant en release | `fixed` (32-2) |
| 🟡 P1 | 4 | Regex normalisation sensible à la casse | `fixed` (32-1) |
| 🟡 P1 | 5 | Contention multi-isolate sans `busy_timeout` | `fixed` (30-2) |
| 🟡 P2 | 6 | Fuite d'abstraction `testHookAfterDeleteSamples` | `open` |
| 🟡 P2 | 7 | Migration v3 non déterministe (`DateTime.now()`) | `open` |

---

## 🔴 Critique

### 1. Aucun chiffrement des données locales

**Constat :** `sqflite` pur, aucune dépendance SQLCipher. Les données physiologiques (`timeseries_samples`) sont stockées en clair dans `astra_app.db`.

| Référence | Détail |
|-----------|--------|
| `pubspec.yaml:14` | `sqflite: ^2.4.2+1` — pas de `sqlcipher_flutter_libs` |
| `lib/core/database/app_database.dart:10` | Chemin par défaut `astra_app.db` |
| `lib/core/database/migrations.dart:62-76` | Table `timeseries_samples` (steps, futurs types) |

**Impact :** Pour une app positionnée « privacy-first », soit manque réel à combler (ex. `sqlcipher_flutter_libs` + passphrase dérivée device/biométrie), soit point à documenter explicitement pour ne pas induire en erreur sur le niveau de protection.

**Contexte produit :** Phase 0 accepte le plaintext (NFR-4, `architecture.md` § SQLCipher Phase 1). Écart entre promesse marketing (« encrypted ») et implémentation actuelle à clarifier.

**Piste :**
- Phase 1 : SQLCipher + Keystore escrow (déjà documenté dans PRD/addendum)
- Court terme : disclaimer UX / My Data footprint si plaintext maintenu

---

### 2. Bug de génération d'ID — collision multi-types

**Constat :** `SampleIdGenerator.deterministicFromIngestionBucket` ne prend en compte que `startTimeUtc`, `provider`, `deviceId` — **pas** `type` ni `resolution`. L'unicité métier (`idx_bucket_identity`) porte sur 6 colonnes.

| Référence | Détail |
|-----------|--------|
| `lib/core/ids/sample_id_generator.dart:30-37` | ID = `startUtc36 + provider/deviceId` normalisés |
| `lib/core/database/migrations.dart:85-93` | `idx_bucket_identity` sur `(provider, device_id, type, start_time, end_time, resolution)` |
| `lib/data/repositories/step/step_ingestion_repository.dart:38-42` | Appel sans `type` / `resolution` |
| `lib/core/ids/sample_id_generator.dart:23-27` | `deterministicFromMergedBucket` inclut déjà `resolution` — incohérence interne |

**Scénario :** Deux échantillons de types différents (`steps` vs `heart_rate`) au même `start_time` / `device_id` → **même PK** → collision au lieu de coexistence légitime.

**Mitigation actuelle :** Un seul type ingéré (`steps`) — bombe à retardement dès qu'un second type arrive.

**Piste :** ~~Aligner l'ID sur l'index unique~~ — **done** (32-1) : `type`/`resolution` dans le hash ; branche legacy `steps`/`5min` sans migration.

**Statut :** `fixed` — Story 32-1

### 3. Garde-fou dev/prod inopérant

**Constat :** `insertDevSamplesBatch` protège son usage prod via un `assert(() { if (!kDebugMode) throw ...; return true; }())`. Les `assert` sont **strippés en release** par Flutter — la protection ne s'exécute pas en production.

| Référence | Détail |
|-----------|--------|
| `lib/data/repositories/step/step_ingestion_repository.dart:88-99` | Garde-fou `assert` + `kDebugMode` |
| `lib/data/repositories/step/step_ingestion_repository.dart:81-87` | Doc : « Dev/test only — DataInjectService » |

**Impact :** Appel accidentel en release passerait silencieusement (inserts directs sans `ON CONFLICT` additive).

**Piste :** Remplacer par garde runtime release-safe :

```dart
if (!kDebugMode) {
  throw StateError('insertDevSamplesBatch is only available in debug builds');
}
```

Ou isoler derrière une implémentation debug-only / `@visibleForTesting` non exposée au DI prod.

**Statut :** `fixed` — Story 32-2

---

## 🟡 À surveiller

### 4. Regex de normalisation sensible à la casse

| Référence | Détail |
|-----------|--------|
| `lib/core/ids/sample_id_generator.dart:35` | `RegExp(r'[^a-z0-9]')` — majuscules supprimées, pas normalisées |

**Comportement probablement non voulu :** `ProviderA` vs `providera` → IDs différents alors que l'index DB est case-sensitive sur `provider` tel quel.

**Piste :** ~~`.toLowerCase()` avant la regex~~ — **done** (32-1).

**Statut :** `fixed` — Story 32-1

---

### 5. Contention multi-isolate

**Constat :** UI / WorkManager / file-picker partagent le même fichier SQLite. Coordination **a posteriori** via `AstraDatabaseSession.withRetry` + détection `database_closed`, pas en amont.

| Référence | Détail |
|-----------|--------|
| `lib/core/database/astra_database_session.dart:5-9` | Commentaire multi-isolate |
| `lib/core/database/astra_database_session.dart:66-76` | `withRetry` — reopen unique, pas de boucle |
| `lib/core/database/app_database.dart:16-24` | WAL + `foreign_keys` + `PRAGMA busy_timeout=5000` |

**Statut :** `fixed` — Story 30-2 (`kDatabaseBusyTimeoutMs` dans `onConfigure`)

**Piste :** ~~`PRAGMA busy_timeout=5000` dans `onConfigure`~~ — done ; surveiller lock ingestion existant (`IngestionCollectionLock`).

---

### 6. Fuite d'abstraction — hook test dans le contrat public

| Référence | Détail |
|-----------|--------|
| `lib/data/contracts/step_ingestion_repository_contract.dart:5-7` | `testHookAfterDeleteSamples` dans l'interface |
| `lib/data/repositories/step/step_ingestion_repository.dart:124-131` | `@override` + hook dans `purge()` |

**Impact :** Toute implémentation alternative doit porter ce paramètre test-only dans son contrat public.

**Piste :** Retirer du contrat ; exposer via sous-classe test / mixin `@visibleForTesting` sur l'impl concrète uniquement.

---

### 7. Migration v3 non testable de façon déterministe

| Référence | Détail |
|-----------|--------|
| `lib/core/database/migrations.dart:119-123` | `DateTime.now()` pour `effective_from_local_day` |
| Commentaire l.119 | « One-time upgrade path: device-local calendar day (no injected clock) » |

**Assumé et commenté** — mais empêche tests migration déterministes sans mock horloge au niveau migration.

**Piste :** Injecter `TimeProvider` dans `runMigrations` / `onCreateV3` (comme ailleurs dans le codebase).

---

## 🟢 Points forts constatés

| Domaine | Preuve |
|---------|--------|
| Migrations idempotentes | `IF NOT EXISTS`, boucle versionnée `runMigrations` — `migrations.dart:10-28` |
| Migration de données (pas que schéma) | v3 `daily_goal_effective` depuis prefs — `migrations.dart:97-133` |
| Contraintes CHECK SQL | Steps non fractionnaires — `migrations.dart:75` |
| Index ciblés + unicité bucket | `idx_bucket_identity`, `idx_timeseries_query`, v4 `idx_timeseries_last_end` |
| Ingestion additive race-safe | `ON CONFLICT ... DO UPDATE SET value = value + excluded.value` — `step_ingestion_repository.dart:62-63` |
| Purge transactionnelle sélective | Préserve prefs setup — `step_ingestion_repository.dart:119-147` |
| Documentation d'intention | Commentaires « pourquoi » dans session, ingestion, migrations |
| Connexions Android réfléchies | WAL, dedup reopen concurrent, retry unique non bouclé — `app_database.dart`, `astra_database_session.dart` |

---

## Plan d'action suggéré

| Phase | Action | Lié |
|-------|--------|-----|
| **Quick fix** | ~~Garde `kDebugMode` runtime sur `insertDevSamplesBatch`~~ — done (32-2) | #3 |
| **Quick fix** | ~~Inclure `type` + `resolution` dans `deterministicFromIngestionBucket`~~ — done (32-1) | #2 |
| **Quick fix** | ~~`.toLowerCase()` sur identity provider/device~~ — done (32-1) | #4 |
| **Moyen** | ~~`PRAGMA busy_timeout` + doc contention isolate~~ — done (30-2) | #5 |
| **Moyen** | Retirer `testHookAfterDeleteSamples` du contrat | #6 |
| **Moyen** | `TimeProvider` injectable pour migration v3 | #7 |
| **Epic** | SQLCipher Phase 1 ou disclaimer privacy explicite | #1 |

---

## Prochaine étape d'audit (suggestion)

Suite logique du périmètre données :

1. **`StepAggregationRepository`** (lecture/agrégation) — robustesse côté read path, requêtes SQL, gestion erreurs contraintes.
2. **Remontée UI/Bloc** — propagation des erreurs (`database_closed`, CHECK violations) vers l'utilisateur.

---

## Navigation

- Dossier : [`audits_2/`](./)
- Audits précédents : [`audits/`](../audits/)
- Architecture : [`architecture.md`](../architecture.md) — NFR-4, SQLCipher Phase 1
