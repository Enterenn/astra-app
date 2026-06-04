# KPI-01 Regression Log (FR-29 precursor)

Tracks History chart **query + render** benchmark results for UX checklist item **V-7** ("History perf — Chart bind <100ms with 90d inject"). Epic 7.3 will copy rows into `docs/BETA_CHECKLIST.md`.

**Threshold:** total p95 < **100 ms** on mid-range Android reference device (debug build).

**CI note:** `flutter test test/dev/chart_benchmark_test.dart` runs the harness but does **not** assert the 100ms gate (host variance).

## Results

| Date | Device | Android | Profile | Rows | p50 (ms) | p95 (ms) | Pass | Git SHA | Notes |
|------|--------|---------|---------|------|----------|----------|------|---------|-------|
| — | — | — | — | — | — | — | — | — | Awaiting manual device run |

## How to add a row

1. Run benchmark on physical Android device (see `lib/dev/README.md` → KPI-01 section).
2. Copy `total_p50` / `total_p95` from `[KPI-01]` console log.
3. Record device model, Android version, profile (`raw-25920` or `compacted-10080`), row count, pass/fail, and current git SHA.
