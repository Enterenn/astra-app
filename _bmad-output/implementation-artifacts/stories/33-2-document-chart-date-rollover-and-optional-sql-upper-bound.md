# Story 33.2: Document Chart Date Rollover and Optional SQL Upper Bound

Status: done

<!-- audits_2 Epic 33 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 33-2 · diagnostic-charts-agregation-daily-monthly.md #1,#2 · AUD2-FR29, AUD2-FR31 -->
<!-- Prerequisite: 33-1 done · base 0.14.1+35 -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **maintainer**,
I want chart window math documented and optionally bounded in SQL,
So that History/Trends queries stay efficient and correct.

## Acceptance Criteria

1. **Given** `_step_chart_queries.dart` month rollover via `DateTime.utc(year, month ± n, day)`
   **When** this story ships
   **Then** inline comments mark intentional UTC rollover patterns — AUD2-FR31
   **And** comments warn maintainers not to replace with manual month/year splitting

2. **Given** chart sample queries using `start_time >= lowerBound` only
   **When** optional upper bound is implemented
   **Then** `sqlUpperBoundUtc` aligns with local-day window (+ buffer per `_step_sample_bounds.dart`) — AUD2-FR29
   **And** SQL uses `start_time < ?` (exclusive upper), matching `getTodaySteps` / `getActiveBucketsForLocalDay` pattern
   **And** existing chart aggregate tests pass unchanged

3. **Given** diagnostic items #1 and #2 in `diagnostic-charts-agregation-daily-monthly.md`
   **When** story ships
   **Then** both marked `fixed` with story ref `33-2`
   **And** `audits_2/README.md` rows D2 + M9 + diagnostic 08 status synced

4. **Given** Epic 33 is complete after this story
   **When** dev + review pass
   **Then** bump `pubspec.yaml` patch+1 (`0.14.1+35` → `0.14.2+36`) + `README.md` project status row before marking epic-33 done

**Covers:** AUD2-FR29 · AUD2-FR31 · diagnostic-charts-agregation-daily-monthly.md #1 (Doc T1), #2 (Perf optional)

**Depends on:** Epic 29–32 and Story 33-1 delivered. No code dependency on compaction changes.

**Out of scope:**
- Changing `finestResolutionTotal` resolution priority or summing all resolutions for a day
- Chart UI / `fl_chart` rendering changes
- New chart windows (still Phase 0: 7/30 days, 12 months only)
- Offset-aware dynamic SQL (per-row filter stays in Dart via `accumulateStepsByDayAndResolution`)

## Tasks / Subtasks

- [x] **Sub-task A — UTC rollover documentation** (AC: #1)
  - [x] Read fully: `lib/data/repositories/step/_step_chart_queries.dart` (entire file — 155 lines)
  - [x] Read: `_step_sample_bounds.dart` — understand `sampleUtcBoundsForLocalDay` buffer semantics (±1 / +2 days)
  - [x] Add comments at each intentional `DateTime.utc` rollover site:
    - `monthlyChartQueryBounds` L48-51: `month - (months - 1)` — Dart normalizes month ≤ 0 (e.g. Jan − 1 → Dec prior year)
    - `chartMonthlyAggregatesFromRows` L126-129: month iteration via `month - monthOffset`
    - L131-133: `month + 1, 0` — day 0 = last day of previous month (calendar month end)
  - [x] Add brief comment on `dailyChartQueryBounds` L28-29: `windowStart.subtract(Duration(days: 1))` mirrors `sampleUtcBoundsForLocalDay(windowStart).lowerInclusive`
  - [x] **Do not** change logic, signatures, or return shapes in sub-task A
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — SQL upper bound (recommended, low risk)** (AC: #2)
  - [x] Extend `dailyChartQueryBounds` / `monthlyChartQueryBounds` return records with `sqlUpperBoundUtc`
  - [x] Derive bounds via existing helper — **reuse, do not duplicate magic numbers:**
    ```dart
    final sqlUpperBoundUtc =
        sampleUtcBoundsForLocalDay(referenceToday).upperExclusive;
    // upperExclusive = referenceToday + 2 days (covers +14h offset edge)
    ```
  - [x] Update `chartSamplesWhereClause` → `'type = ? AND start_time >= ? AND start_time < ?'`
  - [x] Update `chartSamplesWhereArgs` to accept lower + upper UTC bounds
  - [x] Update `step_aggregation_repository.dart` L133-138 and L162-167 to pass both bounds
  - [x] Add one-line comment on where clause linking to `_step_sample_bounds.dart` buffer contract
  - [x] Run: `flutter test test/data/repositories/step_repository_chart_aggregates_test.dart`
  - [x] Run: `flutter test test/data/repositories/step_repository_chart_monthly_aggregates_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Diagnostic closure + epic version note** (AC: #3, #4)
  - [x] Update `diagnostic-charts-agregation-daily-monthly.md` #1 → `fixed` (33-2); #2 → `fixed` (33-2)
  - [x] Refresh synthèse table + statut global (`partial` → `fixed` if both items closed)
  - [x] Sync `audits_2/README.md`: D2 → done; M9 → done; diagnostic 08 open count → 0; E33 progress
  - [x] Note in Dev Agent Record: version bump deferred until epic-33 marked done after review
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

**Undocumented Dart calendar rollover:** Monthly chart windows rely on Dart's `DateTime.utc` normalization (negative months, day 0). This is **correct** but invisible — a maintainer may "fix" it with manual year/month arithmetic and break rolling 12-month windows or month-end iteration.

**Unbounded SQL scan:** Chart queries fetch all rows `start_time >= sqlLowerBoundUtc` with no upper cap. Dart-side filtering (`accumulateStepsByDayAndResolution` L73-74) excludes out-of-window rows, so **UI is correct today** — but SQLite loads and parses extra rows (future timestamps, far-ahead test data, aged history beyond window).

**Established pattern to mirror:** Today/active-bucket queries already use bounded SQL:

```40:45:lib/data/repositories/step/step_aggregation_repository.dart
        where: 'type = ? AND start_time >= ? AND start_time < ?',
        whereArgs: [
          kStepSampleType,
          TimestampCodec.formatUtc(bounds.lowerInclusive),
          TimestampCodec.formatUtc(bounds.upperExclusive),
        ],
```

Chart queries should align with `sampleUtcBoundsForLocalDay` — same ±1 / +2 day buffer documented in `_step_sample_bounds.dart:24-28,61-62`.

[Source: `diagnostic-charts-agregation-daily-monthly.md` #1, #2]

### Current chart pipeline (do not break)

```
getChartDailyAggregates / getChartMonthlyAggregates  (step_aggregation_repository.dart)
  → dailyChartQueryBounds / monthlyChartQueryBounds   (_step_chart_queries.dart)
  → SQL: type + start_time bounds
  → accumulateStepsByDayAndResolution                 (per-row zone_offset → local day)
  → finestResolutionTotal per day                     (_step_sample_bounds.dart)
  → ChartDayAggregate | ChartMonthAggregate
  → HistoryCubit (30d + 12mo) · TodayWeekSelection (7d)
```

**Critical invariants (NFR-8 / AUD2-NFR8):**
- `finestResolutionTotal` picks one resolution tier (5min → hourly → daily) — never sum all
- Zero-fill daily loop L100-107 must still emit every calendar day in window
- Current month partial: `monthOffset == 0` → `monthEnd = referenceToday` (not calendar month end)
- Mixed-resolution same local day (DST non-compaction from 33-1): finest tier wins — charts stay correct

### Recommended comment examples

**Monthly window start (L48-51):**
```dart
// Intentional DateTime.utc month rollover — Dart normalizes month <= 0
// (e.g. June minus 11 months → July prior year). Do not replace with manual
// year/month splitting; chart tests depend on this normalization.
final windowStart = DateTime.utc(
  referenceToday.year,
  referenceToday.month - (months - 1),
  1,
);
```

**Month end via day 0 (L131-133):**
```dart
// day 0 of next month = last calendar day of monthStart's month.
// Intentional DateTime.utc rollover — do not replace with manual month math.
: DateTime.utc(monthStart.year, monthStart.month + 1, 0);
```

### SQL upper bound implementation guide

| Bound | Source | Value |
|-------|--------|-------|
| Lower | `sampleUtcBoundsForLocalDay(windowStart).lowerInclusive` | `windowStart - 1 day` (already equivalent to current `sqlLowerBoundUtc`) |
| Upper | `sampleUtcBoundsForLocalDay(referenceToday).upperExclusive` | `referenceToday + 2 days` |

**Why +2 days upper:** Covers extreme positive offsets (+14) so rows belonging to `referenceToday` local day are not clipped before Dart-side `LocalDayCalculator` filter.

**Optional refactor (nice, not required):** Replace inline `windowStart.subtract(Duration(days: 1))` with `sampleUtcBoundsForLocalDay(windowStart).lowerInclusive` for single source of truth — only if zero behavior change (verify tests).

**Files to touch for sub-task B:**

| File | Change |
|------|--------|
| `_step_chart_queries.dart` | Return `sqlUpperBoundUtc`; update where clause + args helpers |
| `step_aggregation_repository.dart` | Pass upper bound in both chart query call sites |
| Chart tests | Must pass unchanged — no test edits expected unless asserting SQL (none today) |

**Do NOT:**
- Remove Dart-side `rowLocalDay` window filter (L73-74) — SQL bound is perf optimization, not correctness substitute
- Change `days`/`months` validation (7/30/12 only)
- Add index changes — `idx_timeseries_query` already supports range scans

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-07 / NFR-1 | Pre-aggregated chart data; bounded SQL reduces row load — supports p95 < 100ms |
| Architecture §Time semantics | Per-row `zone_offset` for local day; SQL bounds are conservative UTC envelope only |
| Architecture §Chart read model | Repository aggregates; UI gets `ChartDayAggregate` / `ChartMonthAggregate` — unchanged |
| AUD2-NFR8 | Preserve `finestResolutionTotal`, zero-fill, partial current month logic |
| D-25 | Use injected `TimeProvider` via existing `clock` param — no new `DateTime.now()` |
| OK commit gate | Sub-tasks A→C with separate commits after Baptiste approval |

[Source: `architecture.md` §Time semantics, D-07, Chart read model]

### File structure requirements

| File | Action |
|------|--------|
| `lib/data/repositories/step/_step_chart_queries.dart` | **UPDATE** — comments (A) + bounds/SQL helpers (B) |
| `lib/data/repositories/step/step_aggregation_repository.dart` | **UPDATE (B)** — pass upper bound to chart queries |
| `lib/data/repositories/step/_step_sample_bounds.dart` | **READ ONLY** — reuse `sampleUtcBoundsForLocalDay`; do not change unless extracting shared helper (out of scope) |
| `test/data/repositories/step_repository_chart_aggregates_test.dart` | **VERIFY** — all tests green |
| `test/data/repositories/step_repository_chart_monthly_aggregates_test.dart` | **VERIFY** — all tests green |
| `planning-artifacts/audits_2/diagnostic-charts-agregation-daily-monthly.md` | Close #1, #2 → `fixed` |
| `planning-artifacts/audits_2/README.md` | Sync D2, M9, diagnostic 08 |

**Verify only (no edits):**
- `lib/presentation/cubits/history_cubit.dart` — consumers unchanged
- `lib/presentation/cubits/today/today_week_selection.dart` — 7-day chart consumer
- `test/dev/chart_benchmark_test.dart` — optional sanity if time permits (not required AC)

### Testing requirements

| Verify | Command |
|--------|---------|
| Chart daily aggregates | `flutter test test/data/repositories/step_repository_chart_aggregates_test.dart` |
| Chart monthly aggregates | `flutter test test/data/repositories/step_repository_chart_monthly_aggregates_test.dart` |
| Critical gate (if comments-only path for B skipped) | `flutter test --tags critical` |

Do **not** run bare `flutter test`.

**Regression focus:**
- 7/30-day window boundaries and zero-fill
- 12-month rolling window + partial current month average
- Mixed zone offset grouping into correct local day buckets
- `finestResolutionTotal` with mixed 5min/hourly same day (DST scenario — charts OK per diagnostic 08)

**Optional low-cost test (only if adding B):** Insert a row with `start_time` far beyond `referenceToday + 2 days`; assert chart totals unchanged — documents upper-bound intent. Not required if existing suite already green.

### Previous story intelligence

| Learning | Impact on 33-2 |
|----------|----------------|
| 33-1: Doc-only sub-task A + optional test pattern | Mirror: A = comments, B = optional-but-recommended SQL bound |
| 33-1: Do not touch unrelated files (`lifecycle_compaction.dart`) | Stay in chart query layer only |
| 33-1: Diagnostic + README sync in dedicated sub-task C | Close diagnostic 08 #1 + #2 together |
| 33-1: DST fine rows retained — charts use `finestResolutionTotal` | Upper bound must not clip valid offset-edge rows — use +2 day buffer |
| 33-1: Epic 33 version bump after **both** stories | Bump `0.14.1+35` → `0.14.2+36` when epic-33 marked done |

[Source: `stories/33-1-document-dst-non-compaction-intent.md`]

### Cross-story context (Epic 33)

| Story | Status | Relationship |
|-------|--------|--------------|
| 33-1 | done | DST compaction docs — charts unaffected, finest tier read path |
| **33-2** | **this story** | Chart UTC rollover docs + optional SQL upper bound |

**Epic 33 close:** After 33-2 review → bump version + mark `epic-33: done` in `sprint-status-audits-2.yaml`.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `35547e4` | 33-1 closed — pattern for story file + tracker update |
| `43b5bf0` | 33-1 implementation — doc comment style in lifecycle file |
| `cdb316f` | Epic 32 close at `0.14.1+35` — base for Epic 33 |

Active branch `main`; tracker `sprint-status-audits-2.yaml`; base `0.14.1+35`.

### Latest tech / library notes

- **No new packages** — comments + optional SQL predicate tightening only.
- **Dart `DateTime.utc` rollover** (SDK behavior, stable): month/day overflow normalized per ECMAScript-style calendar arithmetic. Document, don't replace.
- **sqflite range queries:** `start_time` stored as ISO8601 text — `>=` / `<` lexicographic order matches UTC ordering when formatted via `TimestampCodec.formatUtc`.
- **Reuse over duplication:** Prefer calling `sampleUtcBoundsForLocalDay` from `_step_chart_queries.dart` (already imports adjacent module) over hardcoding `Duration(days: 2)`.

### Project context reference

- OK commit gate: sub-tasks with separate commits after Baptiste approval
- Tests: localized chart test files for sub-task B; `--tags critical` if A-only
- Version bump: Epic 33 close — patch+1 + README (`.cursor/rules/app-versioning.mdc`)
- Chat French; story/doc English per BMAD config

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 33-2, AUD2-FR29, AUD2-FR31]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-charts-agregation-daily-monthly.md` #1, #2]
- [Source: `_bmad-output/planning-artifacts/audits_2/README.md` D2, M9, diagnostic 08]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-fuseaux-jours-locaux.md` — DST fine rows, charts OK]
- [Source: `lib/data/repositories/step/_step_chart_queries.dart`]
- [Source: `lib/data/repositories/step/_step_sample_bounds.dart`]
- [Source: `lib/data/repositories/step/step_aggregation_repository.dart`]
- [Source: `test/data/repositories/step_repository_chart_aggregates_test.dart`]
- [Source: `test/data/repositories/step_repository_chart_monthly_aggregates_test.dart`]
- [Source: `_bmad-output/implementation-artifacts/stories/33-1-document-dst-non-compaction-intent.md`]
- [Source: `_bmad-output/planning-artifacts/architecture.md` §Time semantics, D-07]

## Dev Agent Record

### Agent Model Used

Composer (dev-story)

### Debug Log References

### Completion Notes List

- Sub-task A: UTC rollover comments at monthly window start, month iteration, day-0 month end, daily lower-bound mirror.
- Sub-task B: `sqlUpperBoundUtc` via `sampleUtcBoundsForLocalDay(referenceToday).upperExclusive`; SQL `start_time < ?`; both chart query sites updated. 17/17 chart tests green.
- Sub-task C: Diagnostic 08 → `fixed`; README D2/M9 closed; E33 both stories done. Version bump `0.14.1+35` → `0.14.2+36` deferred until epic-33 marked done post-review (AC #4).
- Review follow-up: SQL upper-bound exclusion test; version bump `0.14.2+36`; epic-33 closed.

### File List

- `lib/data/repositories/step/_step_chart_queries.dart` — comments + SQL upper bound
- `lib/data/repositories/step/step_aggregation_repository.dart` — pass upper bound to chart queries
- `_bmad-output/planning-artifacts/audits_2/diagnostic-charts-agregation-daily-monthly.md` — #1/#2 fixed
- `_bmad-output/planning-artifacts/audits_2/README.md` — D2, M9, diagnostic 08, E33 sync
- `_bmad-output/implementation-artifacts/sprint-status-audits-2.yaml` — in-progress → review

## Change Log

- 2026-07-25: Story 33-2 created — chart UTC rollover docs + optional SQL upper bound
- 2026-07-25: Implementation complete — UTC docs, SQL upper bound, diagnostic 08 closed
