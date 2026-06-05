# Story 6.1: Derived Activity Metrics

Status: done

<!-- Baptiste 2026-06-05: "pièce de résistance" — kcal, km, walking time. -->
<!-- 2026-06-05: Formulas amended after Gemini + Claude review — supersedes PRD FR-33 raw bucket-sum and simplified kcal coefficient. -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want distance, calories, and walking time estimated from my steps and optional height/weight,
So that Today's stats row shows meaningful numbers instead of placeholders.

## Acceptance Criteria

1. **Given** Story **5.11** shipped (`height_cm`, `weight_kg` in `user_preferences`)
   **When** `DerivedActivityMetrics.compute()` runs (all intermediate math uses `double`)
   **Then** **distance_km** = `displaySteps × stride_m / 1000` where `stride_m = (height_cm/100)×0.414` if height set, else **0.76**
   **And** **walking_duration** = sum over today's local-day buckets where `type = steps` and `value >= 40`:
   `bucket_seconds = min(300, (value / 100.0) × 60)` — threshold filters noise; cadence **100 spm**; cap **5 min** per bucket
   **And** **kcal** = `round((3.5 × 3.5 × (weight_kg ?? 70) / 200) × walking_minutes)` — ACSM MET formula (MET **3.5** moderate walking)

2. **Given** `TodayCubit` displays stats
   **When** live step overlay increases `displaySteps` above SQLite-only total
   **Then** **distance** scales with `displaySteps` (same truth model as the donut — Story 2.9)
   **And** **kcal** and **duration** reflect latest persisted buckets (acceptable lag until next ingest — document in UI copy only if needed; no banner)
   **And** `_applyLiveSteps` recomputes **distance only** from cached profile + new steps — **no** SQLite bucket query on live ticks (~500 ms throttle)

3. **Given** ingestion completes, user returns to Today tab, CSV import, or `refresh()` / extended `refreshMetadata()`
   **When** metrics recompute
   **Then** `getTodayActiveBuckets()` runs and **kcal** + **duration** update from fresh buckets
   **And** `onIngestionComplete` path (today `refreshMetadata()` only) is extended — must reload buckets, not goal/stale alone

4. **Given** no height/weight in preferences
   **When** metrics compute
   **Then** defaults **0.76 m** stride and **70 kg** apply without error

5. **Given** `getTodayActiveBuckets()` queries today's step samples
   **When** buckets are returned for duration/kcal
   **Then** only rows with `resolution = '5min'` are included (`kFiveMinuteResolution`)
   **And** coarser `1hour` / `1d` rows for the same local day are ignored (prevents double-count after import, dev inject, or compaction edge cases)

6. **Given** `TodayStatus.noPermission`
   **When** stats row renders
   **Then** values show **`0` / `0.0` / `00:00:00`** — not mocks, not `—`

7. **Given** `ActivityStatsRow` on Today (Story 5.9)
   **When** metrics are available
   **Then** mock placeholders (`420`, `4.2`, `00:37:20`) are removed
   **And** values format as: **kcal** integer (e.g. `187`), **km** one decimal (e.g. `4.2`), **duration** `HH:MM:SS` tabular (e.g. `00:37:20`)
   **And** zero-activity day shows `0` / `0.0` / `00:00:00` — not `—`

8. **Given** user updates height or weight on Profile
   **When** Today refreshes (tab return, resume, ingestion, or silent refresh)
   **Then** distance and kcal recompute with new profile inputs

9. **Given** unit tests in `test/core/metrics/derived_activity_metrics_test.dart`
   **When** run
   **Then** cover: defaults, custom profile, zero buckets, bucket below threshold (ignored), proportional bucket (50 steps → 30s), capped bucket (800 steps → 5 min), multi-bucket sum, corrected kcal vs old `3.5×weight×hours`, live-step distance-only recompute (no bucket fetch), `5min`-only filter, formatting helpers

10. **Given** implementation complete
   **When** `flutter analyze` and `flutter test` run
   **Then** no regressions; `activity_stats_row_test.dart` updated for real values

**Depends on:** Stories 5.9 (stats row shell), 5.11 (height/weight prefs), 5.12 (cohesion sign-off — in review).  
**Out of scope:** age/gender fields; incline/speed ACSM speed-grade equation; clinical calorie claims; History/Trends metrics; scaling kcal/duration with live overlay (locked: bucket-only).

---

## Calculation Design Review — LOCKED (2026-06-05)

> **Amendment:** Supersedes PRD FR-33 / epics.md raw formulas (full 5-min bucket sum + simplified `3.5×weight×hours`). Validated by Baptiste + Gemini + Claude review. Document rationale in `derived_activity_metrics.dart` header.

### External review synthesis

| Source | Distance | Walking time | Calories |
|--------|----------|--------------|----------|
| **Gemini** | ✅ Ship 0.414; sex field optional Phase 1 | ❌ Reject 1-step=5min; **D+E** with threshold 20 + `min(5, steps/100)` | ❌ Fix ACSM divisor `/200`; coefficient **3.675** not 3.5 |
| **Claude** | ✅ Ship tel quel | **E** threshold **40–50**/bucket; skip D for v0 | MET OK if time fixed; alt `steps×0.04` for robustness |
| **ASTRA lock** | Ship + `double` math | **D+E combined**, threshold **40**, cadence **100 spm** | **Corrected ACSM MET**; reject `steps×0.04` (weight-aware) |

**Rejected for Phase 0:** sex/gender field (product lock 2026-06-04 — 0.414 vs 0.413 delta is <0.3% distance, not worth a new profile row). Run vs walk stride (needs wearable/accelerometer — Epic Phase 1+).

---

### Metric 1 — Distance (km) ✅ LOCKED

| | |
|---|---|
| **Formula** | `distance_km = displaySteps × stride_m / 1000.0` |
| **Stride** | If `height_cm` set: `stride_m = (height_cm / 100.0) × 0.414`. Else: **0.76** |
| **Step input** | **`displaySteps`** — monotonic `TodayState.steps` (live overlay included) |
| **Types** | Promote to `double` before division; round only at format time (1 decimal) |

**Worked examples:**

| Profile | Steps | Stride | Distance |
|---------|------:|--------|----------|
| No height | 10 000 | 0.76 m | **7.6 km** |
| 175 cm | 10 000 | 0.724 m | **7.2 km** |
| 160 cm | 8 000 | 0.662 m | **5.3 km** |

---

### Metric 2 — Walking time (duration) ✅ LOCKED — D+E

| | |
|---|---|
| **Per bucket** (5-min windows, `value` = step count in bucket) | If `value < 40` → **skip** (noise: toilet trip, coffee walk) |
| | Else: `bucket_minutes = min(5.0, value / 100.0)` |
| **Total** | `walking_seconds = sum(bucket_minutes) × 60` |
| **Constants** | `kMinActiveBucketSteps = 40`, `kWalkingCadenceSpm = 100.0`, `kMaxBucketMinutes = 5.0` |
| **Data source** | SQLite buckets only — not live overlay |

**Why 40 not 20?** Claude: 20 spm ≈ 4 steps/min — still household noise. 40 spm = 8 steps/min minimum — real locomotion even if slow. Gemini's proportional cap still applies above threshold.

**Why `min(5.0, steps/100)`?** 100 spm = moderate walk standard. 800 steps in 5 min would imply 8 min without cap — impossible in a 5-min window. Cap prevents runaway on dense buckets.

**Worked examples:**

| Bucket steps | Counted? | Duration credited |
|-------------:|:--------:|------------------:|
| 12 | No | 0 |
| 35 | No | 0 |
| 50 | Yes | **0:30** (50/100 min) |
| 300 | Yes | **3:00** |
| 500 | Yes | **5:00** (cap) |
| 800 | Yes | **5:00** (cap, not 8:00) |

**Day example:** 4 buckets × 500 steps each → 4 × 5 min = **20:00** walking (not 20 min from 12 stray steps across 12 buckets).

**Deferred Phase 1:** Pure threshold-only (E without D) if field tests show proportional feels too low for slow walkers.

---

### Metric 3 — Calories (kcal) ✅ LOCKED — corrected ACSM

| | |
|---|---|
| **Official ACSM** | `kcal_per_minute = (MET × 3.5 × weight_kg) / 200` |
| **Implementation** | `kcal = round((kWalkingMet × 3.5 × weight_kg / 200) × walking_minutes)` |
| **Equivalent** | `kcal ≈ round(3.675 × weight_kg × walking_hours)` when `kWalkingMet = 3.5` |
| **MET** | **3.5** = moderate walking |
| **Weight** | `weight_kg ?? 70.0` |
| **Time input** | `walking_minutes` from Metric 2 (corrected duration) |

**PRD bug fixed:** Old formula `3.5 × weight × hours` omitted the metabolic conversion (`×3.5/200`). ~5% undercount — visible on full days, not just 30-min samples.

**Worked examples (corrected):**

| Weight | Walking time | Old (wrong) | **New (locked)** |
|--------|-------------|------------:|-----------------:|
| 70 kg | 30 min | 123 | **129** |
| 70 kg | 60 min | 245 | **257** |
| 85 kg | 45 min | 223 | **234** |

**Rejected:** `kcal = steps × 0.04` — ignores weight personalization already collected on Profile; less physiologically grounded. Revisit only if MET+time still feels wrong after field test.

**Dependency chain:** Fixing Metric 2 automatically fixes kcal inflation from phantom walking hours.

---

### Live display contract (Today truth model extension)

| Metric | Live overlay? | Rationale |
|--------|---------------|-----------|
| **Distance** | **Yes** — uses `displaySteps` | User sees km move with ring during walk |
| **Walking time** | **No** — buckets only | No per-second time series; 5-min ingest lag acceptable per FR-33 |
| **Kcal** | **No** — buckets only | Tied to bucket-derived duration; avoids double-counting live steps |

**Acceptable lag:** After live steps increment, ring + km update immediately; duration/kcal update on next `BackgroundCollector` persist (or foreground backfill). **Not a defect.**

**Refresh split (performance — mandatory):**

| Trigger | Bucket SQL? | Distance | Kcal + duration |
|---------|:-----------:|:--------:|:---------------:|
| `_applyLiveSteps` (live tick) | **No** | Recompute | Keep last cached |
| `_refreshImpl` / `refresh(silent:)` | **Yes** | Recompute | Recompute |
| `refreshMetadata()` extended | **Yes** | Recompute | Recompute |
| `_onIngestionComplete` → `refreshMetadata()` | **Yes** | Recompute | Recompute |
| `postImportRefresh` → `refreshMetadata()` | **Yes** | Recompute | Recompute |

Cache `height_cm` / `weight_kg` in `TodayState` (or cubit fields) after first load so live distance recompute avoids prefs I/O per tick.

**Optional future:** Scale kcal with `displaySteps/sqliteSteps` ratio when live > persisted — **out of scope** (inconsistent with MET×time model).

---

### Display formatting (locked)

| Column | Format | Example |
|--------|--------|---------|
| Kcal | Integer, no unit suffix in value cell (label **Kcal** separate per Story 5.9) | `187` |
| Km | One decimal, half-up | `4.2`, `0.0` |
| Duration | `HH:MM:SS`, tabular figures (`FontFeature.tabularFigures`) | `01:05:00` |

Use thin-space grouping only for step count — **not** for stats row values.

---

### Decision checklist — APPROVED 2026-06-05

| # | Decision | Locked value |
|---|----------|--------------|
| 1 | Stride | `0.414 × height` / `0.76 m` default; `double` math |
| 2 | Walking time | Threshold **40** + proportional `min(5, steps/100)` min/bucket |
| 3 | Kcal | ACSM `(MET×3.5×weight/200)×minutes`; MET **3.5** |
| 4 | Live scaling | Distance yes; time/kcal no |
| 5 | Zero state | `0` / `0.0` / `00:00:00` |
| 6 | Sex field | **Rejected** Phase 0 (product lock) |
| 7 | Bucket filter | **`5min` resolution only** |
| 8 | Live refresh | **Distance only** on live tick; full metrics on ingest/tab/import |
| 9 | noPermission | **`0` / `0.0` / `00:00:00`** |

---

## Tasks / Subtasks

- [x] **A — `DerivedActivityMetrics` pure Dart** (AC: #1, #4, #9)
  - [x] Create `lib/core/metrics/derived_activity_metrics.dart` + immutable result type (`distanceKm`, `walkingDuration`, `kcal`)
  - [x] Constants: `kDefaultStrideM = 0.76`, `kStrideHeightFactor = 0.414`, `kDefaultWeightKg = 70.0`, `kWalkingMet = 3.5`, `kMinActiveBucketSteps = 40`, `kWalkingCadenceSpm = 100.0`, `kMaxBucketMinutes = 5.0`, `kMetOxygenFactor = 3.5`, `kMetCalorieDivisor = 200.0`
  - [x] `compute(displaySteps:, activeBuckets:, heightCm:, weightKg:)` — no Flutter imports; all math `double`
  - [x] Bucket duration: per-bucket step `value` only (not `end−start` timestamps) — proportional formula defines credited time
  - [x] Kcal: `(kWalkingMet * kMetOxygenFactor * weightKg / kMetCalorieDivisor) * walkingMinutes`
  - [x] Unit tests with fixed `DateTime` buckets — no DB
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **B — `StepRepository.getTodayActiveBuckets()`** (AC: #1, #5)
  - [x] New method: today's local-day rows where `type = steps` AND `resolution = '5min'` AND `value > 0` (activity threshold **40** applied in metrics layer, not SQL), using same `LocalDayCalculator` pattern as `getTodaySteps()`
  - [x] Return `List<TimeseriesSampleModel>` (or lightweight `ActiveStepBucket` if preferred — avoid over-abstraction)
  - [x] Repository test: seed `5min` + `1hour` buckets same day — assert only `5min` returned; cross-day rows excluded
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **C — Formatters** (AC: #7)
  - [x] `lib/presentation/formatters/activity_metrics_formatter.dart`: `formatKcal`, `formatDistanceKm`, `formatWalkingDuration`
  - [x] Formatter unit tests (edge: 0, 59s → `00:00:59`, 3661s → `01:01:01`)
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **D — Wire `TodayCubit` + `TodayState`** (AC: #2, #3, #8)
  - [x] Add `ActivityMetricsSnapshot` to `TodayState` (distanceKm, walkingDuration, kcal — raw values; format in widget)
  - [x] Cache profile inputs in state: `heightCm`, `weightKg` (nullable)
  - [x] **Full path** (`_refreshImpl`, extended `refreshMetadata()`): parallel fetch `getTodayActiveBuckets()`, `getHeightCm()`, `getWeightKg()` → full `DerivedActivityMetrics.compute(...)`
  - [x] **Live path** (`_applyLiveSteps`): recompute distance only via lightweight helper using `state.heightCm` / `state.weightKg` + new `displaySteps`; preserve cached kcal/duration
  - [x] Extend `refreshMetadata()` to fetch buckets + profile (not goal/stale only) — fixes `onIngestionComplete` and `postImportRefresh` without full step re-read
  - [x] `today_cubit_test.dart`: live tick updates distance without bucket fetch; ingestion metadata refresh updates kcal/duration; profile change on tab return
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **E — `ActivityStatsRow` real values** (AC: #6, #7, #10)
  - [x] Remove `_kMockKcal` / `_kMockKm` / `_kMockDuration`; accept metrics from `TodayState` via `BlocBuilder` in `today_screen.dart`
  - [x] Loading: `—` while `TodayStatus.loading`; **noPermission**: `0` / `0.0` / `00:00:00`
  - [x] Update `activity_stats_row_test.dart` + `today_screen_test.dart`
  - [x] **Stop → review brief → Baptiste OK → commit**

- [x] **F — Verification** (AC: #9, #10)
  - [x] `flutter analyze` + `flutter test`
  - [x] Manual: set height/weight on Profile → Today km/kcal shift; walk with app open → km moves, kcal/duration catch up after ingest
  - [x] **Stop → review brief → Baptiste OK → commit**

---

## Dev Notes

### Architecture compliance

- Pure metrics in `lib/core/metrics/` — no widget imports [Source: `_bmad-output/planning-artifacts/architecture.md` — Derived activity metrics]
- `StepRepository` read-only query — no new ingestion writes
- Today Display Truth Model: distance follows `displaySteps`; time/kcal follow SQLite [Source: Story 2.9, FR-33]
- General Wellness boundary: estimates only; no clinical claims [Source: `docs/REGULATORY_POSITION.md`]

### Files to create

| File | Purpose |
|------|---------|
| `lib/core/metrics/derived_activity_metrics.dart` | Core formulas |
| `lib/presentation/formatters/activity_metrics_formatter.dart` | Display formatting |
| `test/core/metrics/derived_activity_metrics_test.dart` | Formula tests |
| `test/presentation/formatters/activity_metrics_formatter_test.dart` | Format tests |

### Files to update

| File | Change |
|------|--------|
| `lib/data/repositories/step_repository.dart` | `getTodayActiveBuckets()` |
| `lib/presentation/cubits/today_state.dart` | Metrics fields |
| `lib/presentation/cubits/today_cubit.dart` | Full vs live refresh split; extend `refreshMetadata()` |
| `lib/presentation/screens/app_scaffold.dart` | Verify `_onIngestionComplete` / tab-return paths call extended `refreshMetadata()` (no change if cubit handles buckets) |
| `lib/presentation/widgets/activity_stats_row.dart` | Real values |
| `lib/presentation/screens/today_screen.dart` | Pass state to stats row |
| `test/data/repositories/step_repository_test.dart` | Bucket query test |
| `test/presentation/cubits/today_cubit_test.dart` | Metrics wiring |
| `test/presentation/widgets/activity_stats_row_test.dart` | Remove mock expectations |

### Refresh architecture (mandatory)

```
_applyLiveSteps(steps)
  → distance only (cached height, no SQL)

_refreshImpl / refreshMetadata() [extended]
  → getTodayActiveBuckets() [5min only]
  → getHeightCm() + getWeightKg()
  → DerivedActivityMetrics.compute() full

_onIngestionComplete → refreshMetadata()  // already wired in app_scaffold.dart
postImportRefresh    → refreshMetadata()  // already wired in app_scaffold.dart
```

Do **not** call `getTodayActiveBuckets()` from `_applyLiveSteps` — live monitor throttles ~500 ms.

### Do NOT

- Add `age`, `sex/gender`, or speed fields to `user_preferences` (Phase 0 product lock)
- Query buckets on every live step tick
- Include `1hour` / `1d` resolution rows in walking-time sum
- Use old PRD formulas (full 5-min bucket sum; `3.5×weight×hours` without `/200`)
- Scale kcal/duration with live overlay (unless Baptiste explicitly changes AC #2)
- Write metrics back to SQLite (derived at read time only)
- Use `getTodaySteps()` for distance when `displaySteps` differs (live overlay case)
- Import `fl_chart` or new packages

### Previous story intelligence

- **5.9:** `ActivityStatsRow` exists with Phosphor icons; Story AC said `—` placeholders but implementation briefly used mocks — Epic 6 replaces with computed values [Source: `lib/presentation/widgets/activity_stats_row.dart`]
- **5.11:** `getHeightCm()` / `getWeightKg()` nullable; validation 100–250 cm, 30–300 kg; survive purge
- **2.9:** `_applyTodaySnapshot` monotonic merge — metrics must use `effectiveSteps` after merge, not raw SQLite read during live session
- **StepNormalizer:** buckets are 5-min UTC floors; `value` is increment sum per window [Source: `lib/data/datasources/step_normalizer.dart`]

### Git intelligence (recent patterns)

- UI polish stories use sub-task review gates before commit (`docs/project-context.md`)
- Tests consolidated in recent chores — add focused tests, avoid redundant widget smoke
- `TodayCubit` already has `refreshMetadata()` for profile-only updates — extend, don't duplicate

### Project structure notes

- Follow `step_count_formatter.dart` pattern for metric formatters (pure functions, testable)
- Keep `DerivedActivityMetrics` static/top-level class — no Cubit in core layer

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Epic 6, Story 6.1]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` — FR-33]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — Derived activity metrics, Today truth model]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §1.6 stats row icons]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-04.md` — FR-33 locked formulas]
- [Source: `lib/data/datasources/step_normalizer.dart` — 5-min bucket semantics]
- [Source: `lib/presentation/cubits/today_cubit.dart` — refresh + live overlay]

---

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- Full-suite run: 568 pass / 2 flaky in `app_live_pipeline_lifecycle_test.dart` (pass in isolation; sqflite factory ordering — pre-existing).
- `flutter analyze`: no errors in story files (info-level lints elsewhere unchanged).

### Completion Notes List

- ✅ **A:** `DerivedActivityMetrics` pure Dart with locked formulas (stride 0.414×height, threshold 40 + proportional time, ACSM kcal `/200`). 10 unit tests.
- ✅ **B:** `getTodayActiveBuckets()` — `5min` only, `value > 0`, local-day filter. Repository tests.
- ✅ **C:** `activity_metrics_formatter.dart` — kcal int, km 1 decimal, duration `HH:MM:SS`.
- ✅ **D:** `TodayState.activityMetrics` + cached profile; full refresh/metadata path loads buckets; live path distance-only via `_liveMetricsForSteps`.
- ✅ **E:** `ActivityStatsRow` wired to real state; loading `—`, noPermission zeros.
- ✅ **F:** Story tests green; analyze clean on new code.

### File List

- `lib/core/metrics/derived_activity_metrics.dart` (new)
- `lib/presentation/formatters/activity_metrics_formatter.dart` (new)
- `lib/data/repositories/step_repository.dart`
- `lib/presentation/cubits/today_state.dart`
- `lib/presentation/cubits/today_cubit.dart`
- `lib/presentation/widgets/activity_stats_row.dart`
- `lib/presentation/screens/today_screen.dart`
- `test/core/metrics/derived_activity_metrics_test.dart` (new)
- `test/presentation/formatters/activity_metrics_formatter_test.dart` (new)
- `test/data/repositories/step_repository_active_buckets_test.dart` (new)
- `test/presentation/cubits/today_cubit_test.dart`
- `test/presentation/widgets/activity_stats_row_test.dart`

### Review Findings

- [x] [Review][Patch] Distance desynced from display steps after monotonic merge [`today_cubit.dart:425`] — fixed: `_applyTodaySnapshot` now recomputes distance from `effectiveSteps`
- [x] [Review][Patch] Missing tests for monotonic merge + distance truth model [`today_cubit_test.dart`] — added syncSteps and refresh-after-live coverage

### Change Log

- 2026-06-05: Code review patches — distance always derived from `effectiveSteps` in `_applyTodaySnapshot`; regression tests added.
- 2026-06-05: Story 6.1 implemented — derived kcal/km/duration on Today stats row; live distance scaling; bucket-only time/kcal refresh.
