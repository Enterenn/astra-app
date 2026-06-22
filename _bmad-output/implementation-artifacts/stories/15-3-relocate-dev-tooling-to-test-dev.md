# Story 15.3: Relocate Dev Tooling to test/dev

Status: done

<!-- Refacto Epic 15 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 15-3 · refactoring-audit-master-v0.6.1.md §4 / §6.3 -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **release engineer**,
I want dev-only simulation and benchmark code excluded from release APKs,
So that bundle size and attack surface are minimised without relying on runtime flags.

## Acceptance Criteria

1. **Given** files under `lib/dev/`  
   **When** relocated  
   **Then** move to `test/dev/`: `data_inject_service.dart`, `chart_benchmark.dart`, `chart_benchmark_dev_fab.dart`, `chart_benchmark_render_pump.dart`, `lifecycle_simulator.dart` (REF-05)  
   **And** move `lib/dev/README.md` → `test/dev/README.md` (update all path references inside)  
   **And** `lib/dev/` directory is **deleted** from the `lib/` tree

2. **Given** relocated files import production code  
   **When** imports are rewritten  
   **Then** use `package:astra_app/...` for all `lib/` dependencies (e.g. `package:astra_app/core/time/time_provider.dart`)  
   **And** same-folder dev imports stay relative (`import 'chart_benchmark.dart';`)  
   **And** **no** `../core/`, `../data/`, or `../presentation/` relative paths remain in moved files

3. **Given** production code imported dev utilities  
   **When** imports are updated  
   **Then** production `lib/` has **zero** imports from relocated files  
   **And** `app_scaffold.dart` no longer references `ChartBenchmarkDevFab` or `floatingActionButton` KPI-01 trigger  
   **And** test files import from `test/dev/` via **relative** paths (not `package:astra_app/dev/...` — `test/` is outside the package export surface)

4. **Given** `flutter build apk --release`  
   **When** analysed  
   **Then** dev simulator and benchmark classes are not present in release binary (spot-check: `strings` / symbol search for `DataInjectService`, `ChartBenchmark`, `LifecycleSimulator`, or `flutter build apk --analyze-size` treemap — no `lib/dev/` compilation unit)

5. **Given** existing tests using `data_inject_service` or `lifecycle_simulator`  
   **When** run  
   **Then** all pass with updated import paths  
   **And** `flutter test test/dev/` passes  
   **And** `flutter analyze lib/` reports no issues related to missing `lib/dev/`

6. **Given** KPI-01 device workflow previously used History-tab debug FAB  
   **When** FAB is removed from production scaffold  
   **Then** `test/dev/README.md` documents test-only entry points (`runDevChartBenchmark`, `chart_benchmark_test.dart`, optional `ChartBenchmarkDevFab` usage from **test** harness only)  
   **And** `_bmad-output/implementation-artifacts/kpi-01-regression-log.md` path references updated from `lib/dev/` to `test/dev/`

7. **Given** work completes on branch `refacto`  
   **When** story is marked done  
   **Then** **no version bump** yet — Epic 15 closes with patch+1 (`0.6.2+13` → `0.6.3+14`) when all Epic 15 stories are done

**Covers:** REF-05 · Audit §4 / §6.3 (P1) · NFR-REF-02 (release bundle hygiene)

## Tasks / Subtasks

- [x] **Sub-task A — Move files + rewrite internal imports** (AC: #1, #2)
  - [x] Read all six `lib/dev/` files **before** moving — note every `../` import to convert
  - [x] `git mv` (or equivalent) the five `.dart` files + `README.md` to `test/dev/`
  - [x] Rewrite moved-file imports:
    - `data_inject_service.dart`: `package:astra_app/core/...`, `package:astra_app/data/...`; keep `uuid` import (Story 15-4 removes it)
    - `lifecycle_simulator.dart`: repository + time imports via package
    - `chart_benchmark.dart`: cubit, repository, sqflite via package; dev siblings via relative
    - `chart_benchmark_render_pump.dart`, `chart_benchmark_dev_fab.dart`: presentation/widgets via package
  - [x] Update `test/dev/README.md`: paths, commands (`flutter analyze test/dev/` not `lib/dev/`), remove obsolete “tree-shaking via kDebugMode is sufficient” claim
  - [x] Delete empty `lib/dev/` directory
  - [x] Run `flutter analyze test/dev/`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Remove production dev import from AppScaffold** (AC: #3)
  - [x] Remove `import '../../dev/chart_benchmark_dev_fab.dart';` from `app_scaffold.dart`
  - [x] Remove `floatingActionButton: kDebugMode && _selectedIndex == 1 ? ChartBenchmarkDevFab(...) : null` block entirely
  - [x] Confirm `grep -r "dev/" lib/` returns zero matches (excluding comments if any)
  - [x] Run `flutter analyze lib/presentation/screens/app_scaffold.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Update all test import paths + full verification** (AC: #3, #5, #6)
  - [x] Replace `package:astra_app/dev/...` in **11 test files** (see File List below) with correct relative `../../dev/...` or `dev/...` paths
  - [x] Update `kpi-01-regression-log.md` `lib/dev/README.md` references → `test/dev/README.md`
  - [x] Run `flutter test test/dev/`
  - [x] Run full `flutter test` (or at minimum all files in File List that import dev helpers)
  - [x] Run `flutter analyze`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Release exclusion spot-check** (AC: #4)
  - [x] `flutter build apk --release` (or `appbundle`)
  - [x] Verify dev classes absent: search build output / analyze-size for `DataInjectService`, `ChartBenchmarkDevFab`, `runDevInject`
  - [x] Document spot-check command + result in story completion notes
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (or fold into Sub-task C if trivial)

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Physical move `lib/dev/*` → `test/dev/` | `uuid` removal (Story 15-4) — keep import in moved `data_inject_service.dart` |
| Zero `lib/` imports of dev tooling | Architecture.md rewrite (`lib/dev/` references are stale post-move) |
| Remove `ChartBenchmarkDevFab` from `AppScaffold` | New integration_test for on-device KPI-01 FAB (optional future) |
| Update test import paths (11 files) | `@Tags(['dev'])` test tagging (deferred per audit) |
| README + KPI regression log path updates | `docs/BETA_CHECKLIST.md` historical row rewrite |
| Branch `refacto` only | Version bump (deferred to Epic 15 close) |

### Why relocation beats `kDebugMode`

Audit §6.3 and epics-refacto explicitly reject `kDebugMode` + tree-shaking as sufficient:

> Dart release builds compile all transitively imported libraries. `kDebugMode` gates runtime paths but **classes remain in the APK** when imported from `lib/`. Physical exclusion requires files outside `lib/`.

Current production leak (must fix):

```9:9:lib/presentation/screens/app_scaffold.dart
import '../../dev/chart_benchmark_dev_fab.dart';
```

```314:316:lib/presentation/screens/app_scaffold.dart
      floatingActionButton: kDebugMode && _selectedIndex == 1
          ? ChartBenchmarkDevFab(deps: widget.deps)
          : null,
```

Even with `kDebugMode`, this import pulls `chart_benchmark.dart`, `data_inject_service.dart`, `lifecycle_simulator.dart`, and `HistoryCubit` benchmark harness into the release compilation graph.

### Import path migration cheat sheet

**Moved files (`test/dev/*.dart`) — production deps:**

```dart
// BEFORE (lib/dev/data_inject_service.dart)
import '../core/time/time_provider.dart';
import '../data/repositories/step_repository.dart';

// AFTER (test/dev/data_inject_service.dart)
import 'package:astra_app/core/time/time_provider.dart';
import 'package:astra_app/data/repositories/step_repository.dart';
```

**Test consumers — dev helpers:**

```dart
// BEFORE
import 'package:astra_app/dev/data_inject_service.dart';

// AFTER (from test/data/repositories/foo_test.dart)
import '../../dev/data_inject_service.dart';

// AFTER (from test/dev/chart_benchmark_test.dart)
import 'data_inject_service.dart';
```

**Do not** add `test/dev/` to `pubspec.yaml` `assets` or create a `lib` export — relative imports are the project convention for test-only helpers.

### Files to move (complete inventory)

| Source (`lib/dev/`) | Destination (`test/dev/`) | Depends on `lib/` via |
|---------------------|---------------------------|------------------------|
| `data_inject_service.dart` | same name | `StepRepository`, `TimeProvider`, `LocalDayCalculator`, models |
| `lifecycle_simulator.dart` | same name | `StepRepository`, `TimeProvider` |
| `chart_benchmark.dart` | same name | `HistoryCubit`, `StepRepository`, `sqflite`, inject + simulator |
| `chart_benchmark_render_pump.dart` | same name | `StepBarChart`, `HistoryState` |
| `chart_benchmark_dev_fab.dart` | same name | `AppDependencies`, benchmark entry points |
| `README.md` | same name | documentation only |

**Already in `test/dev/` (no move):** `data_inject_service_test.dart`, `lifecycle_simulator_test.dart`, `lifecycle_compaction_test.dart`, `chart_benchmark_test.dart`, `chart_benchmark_pump.dart`

### Test files requiring import updates

| File | Current import | New relative path |
|------|----------------|-------------------|
| `test/dev/data_inject_service_test.dart` | `package:astra_app/dev/data_inject_service.dart` | `data_inject_service.dart` |
| `test/dev/lifecycle_simulator_test.dart` | `package:astra_app/dev/...` (×2) | `data_inject_service.dart`, `lifecycle_simulator.dart` |
| `test/dev/chart_benchmark_test.dart` | `package:astra_app/dev/...` (×3) | same-folder relative |
| `test/dev/chart_benchmark_pump.dart` | `package:astra_app/dev/chart_benchmark.dart` | `chart_benchmark.dart` |
| `test/data/repositories/step_repository_chart_aggregates_test.dart` | inject + simulator | `../../dev/...` |
| `test/data/repositories/step_repository_chart_monthly_aggregates_test.dart` | inject | `../../dev/data_inject_service.dart` |
| `test/data/repositories/step_repository_downsample_test.dart` | inject | `../../dev/data_inject_service.dart` |
| `test/core/services/data_lifecycle_service_test.dart` | inject | `../../dev/data_inject_service.dart` |
| `test/core/services/workmanager_callback_test.dart` | inject | `../../dev/data_inject_service.dart` |
| `test/presentation/cubits/history_cubit_test.dart` | inject | `../../dev/data_inject_service.dart` |

### KPI-01 workflow after FAB removal

**Before:** Debug build → History tab → speed FAB → `runDevChartBenchmark` on device.

**After:** Device KPI-01 via test harness only:

```bash
flutter test test/dev/chart_benchmark_test.dart
# Manual device: run debug app, use programmatic path documented in test/dev/README.md
# or add a one-off integration test — NOT wired to AppScaffold
```

`ChartBenchmarkDevFab` remains in `test/dev/` for potential test/widget harness reuse but **must not** be imported from any `lib/` file.

### `kDebugMode` guards in moved files

Keep existing `kDebugMode` throws in `runDevInject()`, `runDevLifecycleSimulate()`, `runDevChartBenchmark()` as defensive depth — they are **not** the release-exclusion mechanism for this story. Do not add new production guards; remove production call sites instead.

### Regression risks

| Risk | Mitigation |
|------|------------|
| Broken relative imports after move | Run `flutter analyze` + full `flutter test` before marking done |
| Missed `package:astra_app/dev/` import | `rg "package:astra_app/dev" test/` must return zero after Sub-task C |
| `app_scaffold_test` assumes FAB | Grep tests — no FAB assertions found; smoke tests should still pass |
| `insertDevSamplesBatch` debug assert | Stays on `StepRepository` — inject service still calls it from tests only |
| Story 15-4 uuid overlap | Do not refactor uuid in this story; `data_inject_service.dart` still uses `Uuid()` |

### Architecture compliance

- **Agent rule #17** (architecture.md): dev tooling was `lib/dev/` + `kDebugMode` — **superseded by REF-05** for refacto branch. Post-move: dev inject = `test/dev/`, FR-28 satisfied via test fixtures not production tree.
- **Tests mirror `lib/`** under `test/` — dev helpers now correctly live alongside their tests.
- **Review-before-commit** (docs/project-context.md): one commit per sub-task, review brief, wait for Baptiste OK.

### References

- [Source: `_bmad-output/planning-artifacts/epics-refacto.md` — Story 15-3, REF-05]
- [Source: `_bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md` — §4 `lib/dev/`, §6.3]
- [Source: `lib/dev/README.md` — reproducibility tables, KPI-01 commands (migrate to `test/dev/`)]
- [Source: `_bmad-output/implementation-artifacts/stories/3-1-dev-data-inject-and-lifecycle-simulator.md` — original dev tooling patterns]
- [Source: `_bmad-output/implementation-artifacts/stories/3-4-chart-performance-benchmark-kpi-01.md` — KPI-01 harness design]
- [Source: `docs/project-context.md` — review-before-commit workflow]

## Dev Agent Record

### Agent Model Used

Claude (Cursor Agent)

### Debug Log References

- Sub-task A: `git mv` six files from `lib/dev/` → `test/dev/`; rewrote all `../` imports to `package:astra_app/...`; sibling dev imports remain relative.
- Sub-task B: Removed `ChartBenchmarkDevFab` import and `floatingActionButton` from `app_scaffold.dart`; `grep dev/ lib/` → zero matches.
- Sub-task C: Updated 10 test files to relative `../../dev/` or same-folder imports; `rg "package:astra_app/dev" test/` → zero.
- Sub-task D: `flutter build apk --release` succeeded (52.0 MB); ASCII string search in `app-release.apk` for `DataInjectService`, `ChartBenchmarkDevFab`, `runDevInject`, `LifecycleSimulator`, `ChartBenchmark`, `lib/dev/` → all **False**.

### Completion Notes List

- Moved 5 Dart files + README from `lib/dev/` to `test/dev/`; `lib/dev/` directory removed.
- Production `lib/` has zero dev imports; KPI-01 debug FAB removed from `AppScaffold`.
- `test/dev/README.md` documents test-only KPI-01 entry points (no production FAB).
- `kpi-01-regression-log.md` path reference updated to `test/dev/README.md`.
- `flutter analyze test/dev/` — clean; `flutter analyze lib/` — no dev-related issues (pre-existing info lints only).
- `flutter test test/dev/` — 26/26 pass; full `flutter test` — all pass (~214s).
- Release spot-check: `DataInjectService`, `ChartBenchmarkDevFab`, `runDevInject`, `LifecycleSimulator`, `ChartBenchmark` absent from release APK.
- No version bump (deferred to Epic 15 close per AC #7).

### File List

**Move (delete from `lib/`, create in `test/dev/`):**
- `lib/dev/data_inject_service.dart` → `test/dev/data_inject_service.dart`
- `lib/dev/lifecycle_simulator.dart` → `test/dev/lifecycle_simulator.dart`
- `lib/dev/chart_benchmark.dart` → `test/dev/chart_benchmark.dart`
- `lib/dev/chart_benchmark_render_pump.dart` → `test/dev/chart_benchmark_render_pump.dart`
- `lib/dev/chart_benchmark_dev_fab.dart` → `test/dev/chart_benchmark_dev_fab.dart`
- `lib/dev/README.md` → `test/dev/README.md`

**Modify (production):**
- `lib/presentation/screens/app_scaffold.dart` — remove dev FAB import + widget

**Modify (tests — import paths):**
- `test/dev/data_inject_service_test.dart`
- `test/dev/lifecycle_simulator_test.dart`
- `test/dev/chart_benchmark_test.dart`
- `test/dev/chart_benchmark_pump.dart`
- `test/data/repositories/step_repository_chart_aggregates_test.dart`
- `test/data/repositories/step_repository_chart_monthly_aggregates_test.dart`
- `test/data/repositories/step_repository_downsample_test.dart`
- `test/core/services/data_lifecycle_service_test.dart`
- `test/core/services/workmanager_callback_test.dart`
- `test/presentation/cubits/history_cubit_test.dart`

**Modify (docs):**
- `_bmad-output/implementation-artifacts/kpi-01-regression-log.md`

**Delete:**
- `lib/dev/` (entire directory after move)

## Change Log

- 2026-06-18: Relocated dev tooling from `lib/dev/` to `test/dev/`; removed production FAB; updated test imports and KPI docs (Story 15-3, REF-05).
- 2026-06-18: Code review approved — story marked done.
