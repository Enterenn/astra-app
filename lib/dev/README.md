# ASTRA dev tooling (`lib/dev/`)

FR28 dev-only helpers for Epic 3 chart development and storage benchmarks. **Not for production use.**

## Purpose

- **`DataInjectService`** — writes 90 days of synthetic 5-minute step samples (25 920 rows).
- **`LifecycleSimulator`** — previews FR11 downsampling (5 min → 1 hour → 1 day) inside SQLite transactions.

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
flutter test test/dev/
flutter analyze lib/dev/
```

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
