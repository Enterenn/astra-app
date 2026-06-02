# ASTRA dev tooling (`lib/dev/`)

FR28 dev-only helpers for Epic 3 chart development and storage benchmarks. **Not for production use.**

## Purpose

- **`DataInjectService`** — writes 90 days of synthetic 5-minute step samples (25 920 rows).
- **`LifecycleSimulator`** — previews FR11 downsampling (5 min → 1 hour → 1 day) inside SQLite transactions.
- **`ChartBenchmark`** — KPI-01 query + toggle/render latency harness (`runChartBenchmark`).

Downstream stories consume this data:

- Story 3.2 — `getChartDailyAggregates()`
- Story 3.4 — KPI-01 chart benchmark
- Story 4.1 — promote compaction logic to `DataLifecycleService`

## Reproducibility

| Setting | Value |
|---------|-------|
| Random seed | `Random(42)` (fixed) |
| Default test anchor | `2026-06-02T12:00:00Z`, zone offset `+02:00` |
| Days injected | 90 local calendar days ending on anchor day |
| Buckets per day | 288 (5-minute, `00:00`–`23:55` local) |

### Expected row counts

| Stage | Resolution | Rows |
|-------|------------|------|
| After inject | `5min` | **25 920** |
| After lifecycle simulate | `5min` (30 most recent local days, age 0–29) | **8 640** |
| After lifecycle simulate | `1hour` (age 30–364) | **1 440** |
| After lifecycle simulate | **Total** | **10 080** (~61% reduction) |
| Tier 3 (`1d`) on 90-day inject | — | **0** (no-op) |

Daily step totals per injected day target **4 000–12 000** steps via seeded scaling.

## Idempotent inject

`inject90Days()` calls `insertDevSamplesBatch(replaceExistingSteps: true)`, which **deletes existing `type='steps'` rows and inserts fresh synthetic data in one transaction**. This makes re-runs safe for benchmarks and prevents partial data loss if the insert fails. **`user_preferences` and other tables are untouched.**

⚠️ Debug builds only — re-inject clears real step samples already stored on a dev device.

## Commands

```bash
flutter test test/dev/data_inject_service_test.dart
flutter test test/dev/lifecycle_simulator_test.dart
flutter test test/dev/chart_benchmark_test.dart
flutter test test/dev/
flutter analyze lib/dev/
```

## KPI-01 chart benchmark

Reproducible harness for **History chart query + render latency** when toggling 7d ↔ 30d (NFR-1 / FR-16 / FR-28).

### Profiles

| Profile | Setup | Expected rows | Label |
|---------|-------|---------------|-------|
| **A (primary)** | `inject90Days()` only | **25 920** | `raw-25920` |
| **B (optional)** | inject + `LifecycleSimulator` | **10 080** | `compacted-10080` |

### Device benchmark (pass/fail gate)

KPI-01 **pass/fail** is measured on a **mid-range Android reference device** (debug build). CI/emulator runs are **log-only** — slow VMs must not fail the suite.

1. Install debug build on physical Android device.
2. Ensure dev DB has 90-day inject (or call `runDevInject` from a debug entry point).
3. Invoke `runChartBenchmark(repository: ..., clock: ..., assertPassGate: true)` from a debug-only trigger.
4. Capture console output — look for `[KPI-01]` log line with `total_p50` / `total_p95`.
5. **Pass:** `total_p95 < 100 ms`. Record results in `_bmad-output/implementation-artifacts/kpi-01-regression-log.md`.

### Reading output

Example log line:

```text
[KPI-01] dataset=raw-25920 rows=25920 iterations=50 query_p50=12.34ms query_p95=18.56ms toggle_p50=1.23ms toggle_p95=2.45ms total_p50=13.57ms total_p95=21.01ms pass=true
```

| Field | Meaning |
|-------|---------|
| `query_p50/p95` | `StepRepository.getChartDailyAggregates(days: 30)` |
| `toggle_p50/p95` | In-memory `HistoryCubit.selectPeriod(7d↔30d)` + optional chart pump |
| `total_p50/p95` | **KPI-01 metric** = query + toggle per iteration |

Widget render can be profiled on device via the optional `pumpChart` callback; CI smoke validates cubit toggle only (`step_bar_chart_test.dart` covers chart rendering).

## Release-build safety

- Entry points `runDevInject()` and `runDevLifecycleSimulate()` throw unless `kDebugMode` is true.
- `StepRepository.insertDevSamplesBatch()` is guarded with a debug `assert`.
- **Do not import `lib/dev/` from `main.dart`, `app.dart`, or production widgets** without a `kDebugMode` guard.
- Flutter release builds tree-shake unreachable debug paths when callers respect this policy; keep dev triggers in tests or debug-only code paths.

## File map

| File | Role |
|------|------|
| `data_inject_service.dart` | 90-day synthetic inject |
| `lifecycle_simulator.dart` | FR11 compaction orchestration |
| `lifecycle_compaction.dart` | Pure merge/age helpers (Epic 4.1 reuse) |
| `chart_benchmark.dart` | KPI-01 query + toggle/render benchmark harness |
