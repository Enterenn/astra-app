# Diagnostic — ingestion pedometer (normalizer + calculator)

**Généré :** 2026-07-21  
**Base code :** `0.12.1+31` (`pubspec.yaml`)  
**Périmètre :** `StepNormalizer` · `StepIncrementCalculator` · persistance baseline (`BackgroundCollector`)  
**Statut global :** `open`

---

## Statut

- **Dernière vérification :** 2026-07-21
- **Statut :** `open`
- **Story / PR :** —

---

## Synthèse

| Priorité | # | Domaine | Statut |
|----------|---|---------|--------|
| 🔴 P0 | 1 | `terminalBaseline` = `lastCumulative` au lieu de `baseline` | `open` |

---

## 🔴 Critique

### 1. Baseline persistée corrompue si dernière lecture = bruit rejeté

**Constat :** `normalizeReadings` retourne `terminalBaseline: lastCumulative ?? initialBaseline`. Or `lastCumulative` est mis à jour sur **chaque** lecture (l.59), y compris quand `StepIncrementCalculator.calculate` retourne `null` (bruit) — cas où la variable **`baseline` locale n'avance pas** (l.78-80 `continue` sans `baseline = cumulativeSteps`).

| Référence | Détail |
|-----------|--------|
| `lib/data/datasources/step_normalizer.dart:54-59` | `lastCumulative = cumulativeSteps` à chaque itération |
| `lib/data/datasources/step_normalizer.dart:72-80` | `increment == null` → `continue` — baseline inchangée |
| `lib/data/datasources/step_normalizer.dart:82` | Baseline avancée **seulement** si increment non null |
| `lib/data/datasources/step_normalizer.dart:108` | **`terminalBaseline: lastCumulative ?? initialBaseline`** |
| `lib/core/services/background_collector.dart:121-127` | `setBaseline(cumulative: terminalBaseline)` |
| `lib/data/datasources/step_increment_calculator.dart:51-56` | Petite baisse → `null` (bruit capteur) |

**Scénario :**
1. Cycle N : baseline 5000 → lecture 5100 (+100 crédité, `baseline`=5100)
2. Dernière lecture 5099 (bruit) → delta rejeté, `baseline` reste 5100
3. `terminalBaseline` = **5099** (`lastCumulative`) persisté
4. Cycle N+1 : delta depuis 5099 alors que le compteur réel est ~5100 → **sur-comptage** au prochain increment valide

**Test existant partiel :** `step_normalizer_test.dart:264-291` — « rejects small counter dips » vérifie les buckets, **pas** `terminalBaseline`.

**Test rate-limit :** l.240-261 — `terminalBaseline` 1050 coïncide avec `baseline` car dernière lecture acceptée ; ne couvre pas le cas bruit en **dernière** position.

**Correctif suggéré :**

```dart
terminalBaseline: baseline ?? initialBaseline,
```

**Alignement doc :** Commentaire `StepIncrementCalculator` l.3-5 (« baseline always advances to latest reading in callers ») — aujourd'hui faux pour lectures rejetées ; le fix ci-dessus rend la persistance cohérente avec la baseline métier.

---

## 🟢 Points forts constatés

| Domaine | Preuve |
|---------|--------|
| Anti-bruit / reset | `StepIncrementCalculator` — reset si `current <= baseline/2`, bruit si petite baisse → `null` — `step_increment_calculator.dart:42-56` |
| Cap physiologique | `kMaxStepsPerSecond = 5` + `_maxDeltaForElapsed` — l.18-20, 59-66 |
| Limite timestamp documentée | Réception Dart vs matériel `pedometer` — l.7-10 |
| Test terrain intégré | `STEP_RATE_LIMIT_ENABLED` via `--dart-define` — l.22-27 |
| Séparation responsabilités | Buckets 5 min (`StepNormalizer`) vs delta (`StepIncrementCalculator`) |
| Buckets UTC floor | `_floorToFiveMinuteUtc` — indépendant de l'heure traitement |
| Tests critical tag | `step_normalizer_test.dart` — reset, rate-limit, glitch dip, baseline persistée |

---

## Chaîne de persistance

```
BackgroundCollector._collectOnce
  → normalizer.normalize(initialBaseline from prefs)
  → upsert buckets
  → setBaseline(terminalBaseline)   ← bug si terminalBaseline ≠ baseline interne
```

Lié audit WM : [`diagnostic-workmanager-maintenance-db.md`](./diagnostic-workmanager-maintenance-db.md) #1 (double comptage autre cause) — problèmes distincts mais même symptôme.

---

## Plan d'action suggéré

| Phase | Action |
|-------|--------|
| **P0** | `terminalBaseline: baseline ?? initialBaseline` |
| **P0** | Test : dernière lecture bruit rejetée → `terminalBaseline` == baseline avant bruit |
| **P1** | Ajuster commentaire `StepIncrementCalculator` si persistance ne suit plus « latest reading » littéral |

---

## Navigation

- Dossier : [`audits_2/`](./)
- Tests : `test/data/datasources/step_normalizer_test.dart` · `test/data/datasources/step_increment_calculator_test.dart` (si présent)
