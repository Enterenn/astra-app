# ASTRA dev tooling (`test/dev/`)

FR28 dev-only helpers for Epic 3 chart development and storage benchmarks. **Not compiled into release APKs** — lives outside `lib/`.

## Purpose

- **`DataInjectService`** — writes 90 days of synthetic 5-minute step samples (25 920 rows).
- **`LifecycleSimulator`** — dev-only FR11 preview; delegates to `StepRepository.downsampleStepSamples()` (same path as production).
- **`ChartBenchmark`** — KPI-01 query + toggle/render latency harness (`runChartBenchmark`).

### Production lifecycle (Story 4.1+)

Real devices use **`DataLifecycleService`** (`lib/core/services/data_lifecycle_service.dart`):

- Android: weekly WorkManager task (`astra_database_maintenance`)
- iOS / foreground: opportunistic `runMaintenance()` on app resume when due

Keep **`runDevLifecycleSimulate()`** for KPI-01 compacted profile (`kDatasetLabelCompacted10080`) and debug benchmarks — do not route production scheduling through `test/dev/`.

Downstream stories consume this data:

- Story 3.2 — `getChartDailyAggregates()`
- Story 3.4 — KPI-01 chart benchmark
- Story 4.1 — production `DataLifecycleService` (downsampling + weekly maintenance)

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
flutter analyze test/dev/
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

**Entry points (test harness only — no production FAB):**

1. **Automated:** `flutter test test/dev/chart_benchmark_test.dart` (CI smoke; no 100ms gate).
2. **On-device programmatic:** call `runDevChartBenchmark` from a test/widget harness with `pumpChart: createOverlayStepBarChartPump(context)` (see snippet below).
3. **Optional widget harness:** import `ChartBenchmarkDevFab` from `test/dev/chart_benchmark_dev_fab.dart` in a **test-only** scaffold — never from `lib/`.

Steps for manual device run:

1. Install **debug** build on physical Android device (mid-range reference, e.g. CPH2663).
2. Run benchmark via test harness or programmatic call with 90-day inject, **50 iterations**, and off-screen `StepBarChart` pumps (7d + 30d).
3. Capture console `[KPI-01]` log (`render=true`, `profile=full-stack`, `total_p95`).
4. **Pass:** `total_p95 < 100 ms`. Record in `_bmad-output/implementation-artifacts/kpi-01-regression-log.md`.

Programmatic alternative:

```dart
await runDevChartBenchmark(
  repository: stepRepository,
  clock: timeProvider,
  db: stepRepository.db,
  userPreferences: userPreferences,
  pumpChart: createOverlayStepBarChartPump(context),
  assertPassGate: true,
);
```

Use **`iterations: 50`** (default) on device for a stable p95. CI smoke uses `iterations: 1`.

### Benchmark profiles

| Profile | Enum | Per iteration | Matches |
|---------|------|---------------|---------|
| **Full stack (KPI-01 primary)** | `ChartBenchmarkProfile.fullStack` | `getChartDailyAggregates(30)` + toggle + optional chart pump | Refresh + toggle cost |
| **Toggle only** | `ChartBenchmarkProfile.toggleOnly` | Toggle + chart pump only (query p50/p95 = 0) | `PeriodToggle` after warm cache |

### Reading output

Example log line:

```text
[KPI-01] profile=full-stack render=true dataset=raw-25920 rows=25920 iterations=50 query_p50=12.34ms query_p95=18.56ms toggle_p50=1.23ms toggle_p95=2.45ms total_p50=13.57ms total_p95=21.01ms threshold=100ms pass=true
```

| Field | Meaning |
|-------|---------|
| `query_p50/p95` | `StepRepository.getChartDailyAggregates(days: 30)` |
| `toggle_p50/p95` | In-memory `HistoryCubit.selectPeriod(7d↔30d)` + optional chart pump |
| `total_p50/p95` | **KPI-01 metric** = query + toggle per iteration |

Chart render is measured when `pumpChart` is set (device harness uses `createOverlayStepBarChartPump`). CI smoke also runs `pumpChart` via `test/dev/chart_benchmark_pump.dart`.

## Release-build safety

- Files live under `test/dev/` — **not** part of the `lib/` compilation tree, so release APKs exclude dev simulator and benchmark classes.
- Entry points `runDevInject()`, `runDevLifecycleSimulate()`, and `runDevChartBenchmark()` throw unless `kDebugMode` is true (defensive depth for debug/test runs).
- `StepRepository.insertDevSamplesBatch()` is guarded with a debug `assert`.
- **Do not import `test/dev/` from any `lib/` file** — use relative imports from `test/` only.

## File map

| File | Role |
|------|------|
| `data_inject_service.dart` | 90-day synthetic inject |
| `lifecycle_simulator.dart` | Dev FR11 preview (delegates to repository downsample) |
| `chart_benchmark.dart` | KPI-01 harness + `runDevChartBenchmark()` |
| `chart_benchmark_render_pump.dart` | Off-screen `StepBarChart` pump for device/tests |
| `chart_benchmark_dev_fab.dart` | Test-only FAB widget to run KPI-01 on device |
