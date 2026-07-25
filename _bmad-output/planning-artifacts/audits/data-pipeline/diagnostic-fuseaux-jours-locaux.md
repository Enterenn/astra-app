# Diagnostic — fuseaux horaires / jours locaux

**Généré :** 2026-07-21  
**Base code :** `0.12.1+31` (`pubspec.yaml`)  
**Périmètre :** `LocalDayCalculator` · `lifecycle_compaction.dart` · ingestion `zone_offset` · agrégations lecture  
**Statut global :** `fixed` (Story 33-1 — documentation DST compaction)

---

## Statut

- **Dernière vérification :** 2026-07-25
- **Statut :** `fixed`
- **Story / PR :** Story 33-1

---

## Synthèse

| Priorité | # | Domaine | Statut |
|----------|---|---------|--------|
| 📝 Doc | 1 | Journées DST jamais compactées (voulu, silencieux) | `fixed` (33-1) |
| 🟢 — | 2 | Offset stocké par échantillon, jamais recalculé | `fixed` |
| 🟢 — | 3 | Clé de regroupement incluant l'offset | `fixed` |
| 🟢 — | 4 | Triple vérification complétude avant fusion | `fixed` |

---

## 📝 À documenter (pas critique)

### 1. Journées DST jamais compactées — comportement voulu (fail closed)

**Constat :** Les journées de changement d'heure (DST) ne produisent en pratique **jamais** de groupes « complets » pour la compaction FR11. Conséquence directe de la protection contre fusion incorrecte entre offsets ou fenêtres trouées — **sûr**, mais **silencieux**.

**Mécanismes en jeu :**

| Mécanisme | Référence | Effet DST |
|-----------|-----------|-----------|
| Compte exact requis | `lifecycle_compaction.dart:6-8` | 12 / 24 / 288 buckets — jour spring-forward ≠ 24 h locales |
| Identité inclut offset | `lifecycle_compaction.dart:132-136` | `_sameSampleIdentity` exige `zoneOffset` identique |
| Clés de groupe | `lifecycle_compaction.dart:455-479` | `provider\|deviceId\|zoneOffset\|localBucket` |
| Contiguïté UTC fixe | `lifecycle_compaction.dart:138-149` | +5 min / +1 h — casse si trou ou doublon local |
| Garde merge | `lifecycle_compaction.dart:329-335,372-377,416-421` | `ArgumentError` si groupe incomplet |

**Scénario spring-forward :** Moins de buckets horaires locaux → `isCompleteHourlyDayGroup` false (`length != 24`) → pas de compaction.

**Scénario transition offset :** Ingestion capture l'offset au moment du bucket (`step_normalizer.dart:52,105`) — échantillons de part et d'autre d'une transition DST portent des `zone_offset` différents → clés de groupe distinctes → pas de fusion cross-offset.

**Test existant :** `local_day_calculator_test.dart:22-36` — deux offsets stockés sur une frontière DST, jours locaux distincts.

**Risque si non documenté :** Correctif naïf (assouplir le compte 24/288 ou ignorer l'offset) réintroduirait fusion erronée ou double-comptage.

**Action suggérée :** Commentaire explicite dans `lifecycle_compaction.dart` (près de `kHourlyBucketsPerDay` / `isComplete*`) : *« DST transition days intentionally skip compaction — do not relax without offset-aware bucket math. »*

**Statut :** `fixed` — Story 33-1 (block comment + `isComplete*` doc comments ; test DST incomplete groups)

**Impact produit :** Lignes 5 min / horaires conservées plus longtemps sur ces jours — croissance DB marginale, pas d'erreur utilisateur.

---

## 🟢 Points forts constatés

### Offset capturé par échantillon — intégrité historique

| Référence | Détail |
|-----------|--------|
| `lib/data/datasources/step_normalizer.dart:52,105` | `zoneOffset` figé à la normalisation depuis `clock.currentZoneOffset()` |
| `lib/data/models/timeseries_sample_model.dart:28,76` | Colonne `zone_offset` persistée, relue telle quelle |
| `lib/core/time/local_day_calculator.dart:3-18` | Jour local dérivé de `(utc, zoneOffset stocké)` — pas du fuseau device courant |
| `lib/core/time/local_day_formatter.dart:7-8` | Commentaire : pas de `DateTime.now()` nu pour le jour courant UI |
| `lib/data/repositories/step/step_aggregation_repository.dart:122,151` | Charts agrégés en Dart avec offset **par ligne** |

Protège l'historique contre voyages et changements de règles DST ultérieurs.

---

### Clé de regroupement incluant l'offset

```455:461:lib/core/lifecycle/lifecycle_compaction.dart
String fiveMinuteGroupKey(TimeseriesSampleModel sample) {
  final localHour = localHourBucketKey(
    startTimeUtc: sample.startTimeUtc,
    zoneOffset: sample.zoneOffset,
  );
  return '${sample.provider}|${sample.deviceId}|${sample.zoneOffset}|'
      '${localHour.toIso8601String()}';
}
```

Même pattern pour `hourlyGroupKey` et `fiveMinuteDayGroupKey` — élimine fusion cross-fuseau.

---

### Triple vérification complétude avant fusion

Pour chaque tier (`isCompleteFiveMinuteHourGroup`, `isCompleteHourlyDayGroup`, `isCompleteFiveMinuteDayGroup`) :

1. **Compte exact** — `buckets.length != k*` → false
2. **Contiguïté** — `_areConsecutiveFiveMinuteBuckets` / `_areConsecutiveHourlyBuckets`
3. **Égalité clé aux extrémités** — `groupKey(first) == groupKey(last)` + `_sameSampleIdentity` sur la chaîne

Garde-fou final : `merge*` lève `ArgumentError` si incomplet (`lifecycle_compaction.dart:329-335`).

---

### Design cohérent

| Aspect | Preuve |
|--------|--------|
| Constantes nommées FR11 | `kTierOneMaxAgeDays`, `kFiveMinuteBucketsPerDay`, etc. |
| Fonctions pures testables | `test/dev/lifecycle_compaction_test.dart`, `local_day_calculator_test.dart` |
| Fenêtre SQL conservative + filtre offset | `_step_sample_bounds.dart:24-28` — ±1 jour avant filtre par ligne |
| Lecture anti double-comptage | `finestResolutionTotal` (`_step_sample_bounds.dart:6-21`) |

---

## Todo consolidée (session)

| # | Action | Priorité |
|---|--------|----------|
| T1 | Commentaire DST / non-compaction dans `lifecycle_compaction.dart` | Doc — **done** (33-1) |
| T2 | (Optionnel) test compaction : jour DST simulé → 0 merge, buckets préservés | **done** (33-1) |

---

## Plan d'action suggéré

| Phase | Action |
|-------|--------|
| **Doc** | T1 — 5–10 lignes près des constantes `k*BucketsPer*` |
| **Ne pas faire** | Assouplir 24/288 sans modèle offset-aware |
| **Optionnel** | Note My Data / footprint : « quelques jours DST restent en résolution fine » |

---

## Navigation

- Dossier : [`data-pipeline/`](./)
- Lié : [`diagnostic-downsampling-compaction-fr11.md`](./diagnostic-downsampling-compaction-fr11.md) · [`diagnostic-couche-donnees.md`](./diagnostic-couche-donnees.md)
- Tests : `test/core/time/local_day_calculator_test.dart` · `test/dev/lifecycle_compaction_test.dart`
