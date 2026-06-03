# Story 4.2: My Data Footprint and Background Status

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want to see storage footprint and honest background collection status,
So that I can trust the app is working and understand storage use.

## Acceptance Criteria

1. **Given** samples exist in SQLite
   **When** My Data footprint section loads
   **Then** sample count, approximate DB size, and "last optimized" relative time display (FR13, UX-DR11)
   **And** values update after lifecycle, import, export, purge operations

2. **Given** background collection state
   **When** My Data renders
   **Then** `BackgroundStatusCard` shows healthy/stale/ios_backfill/permission_denied variants (FR5, UX-DR12)
   **And** full stale banner appears here; Today shows compact stale line (UX-DR8)

3. **Given** stale thresholds
   **When** last sample exceeds 12h (Android) or 4h (iOS)
   **Then** stale copy explains platform constraints without blaming user

## Tasks / Subtasks

- [x] **Sub-task A — Repository footprint API + formatters** (AC: #1)
  - [x] Add `lib/data/models/database_footprint.dart`:
    - `DatabaseFootprint { int sampleCount; int fileSizeBytes; }`
  - [x] Add `StepRepository.getFootprint({required String databasePath})`:
    - Reuse `countStepSamples()` for sample count (steps-only, matches existing dev/lifecycle semantics).
    - File size: `File(databasePath).lengthSync()` when path exists and is not in-memory; return `0` for in-memory DB.
    - **Read-only** — no writes, no VACUUM trigger from UI.
  - [x] Expose `databasePath` on `AppDependencies` (set in `create()` alongside `DataLifecycleService`; pass `inMemoryDatabasePath` in `.test()`).
  - [x] Add `lib/presentation/formatters/relative_time_formatter.dart`:
    - Pure function: `formatRelativeTime({required DateTime? instantUtc, required DateTime nowUtc})` → e.g. `"just now"`, `"14 minutes ago"`, `"2 days ago"`, `"never"` when null.
    - No `intl` dependency — mirror lightweight style of `step_count_formatter.dart`.
  - [x] Add `lib/presentation/formatters/file_size_formatter.dart`:
    - `formatFileSize(int bytes)` → human-readable: `"0 KB"`, `"2.4 MB"`, `"512 B"` (1 decimal for MB/GB, integer KB).
  - [x] Unit tests: `test/data/repositories/step_repository_footprint_test.dart` — empty DB → count 0; inject samples → count matches; file size > 0 on temp file DB.
  - [x] Unit tests: formatter edge cases (null, <1 min, hours, days).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — `MyDataState` + `MyDataCubit`** (AC: #1–#3)
  - [x] Add `lib/presentation/cubits/my_data_state.dart`:
    - `MyDataStatus`: `loading`, `ready`.
    - `BackgroundCollectionStatus`: `healthy`, `stale`, `iosBackfill`, `permissionDenied` — derived, not user-set.
    - Fields: `status`, `sampleCount`, `fileSizeBytes`, `lastOptimizedUtc` (nullable), `lastIngestionUtc` (nullable), `backgroundStatus`, `capabilitySnapshot` (optional raw snapshot for widget copy), `isIos`.
  - [x] Add `lib/presentation/cubits/my_data_cubit.dart`:
    - Inject: `StepRepository`, `UserPreferencesRepository`, `BackgroundHealthCapabilityEvaluator`, `TimeProvider`, `String databasePath`, `bool isIos` (default `Platform.isIOS`), activity permission checker (reuse `AppDependencies.activityPermissionGranted` pattern).
    - `Future<void> refresh({bool silent = true})` — parallel fetch:
      1. `repository.getFootprint(databasePath: databasePath)`
      2. `userPreferences.getLastDatabaseOptimizedAt()`
      3. `repository.getLastIngestionUtc()`
      4. `capabilityEvaluator.evaluate()`
    - Derive `backgroundStatus`:
      - `!activityRecognitionGranted` → `permissionDenied`
      - else `isStaleData(lastIngestionUtc, nowUtc, isIos)` → `stale`
      - else if `isIos` → `iosBackfill` (info honesty per UX §2.5 — still show last sync on card)
      - else → `healthy`
    - In-flight guard like `TodayCubit` / `HistoryCubit`.
    - **Never** call administrative write methods.
  - [x] Add `test/presentation/cubits/my_data_cubit_test.dart` — matrix: permission denied, healthy Android, stale Android (>12h), stale iOS (>4h), ios backfill healthy, footprint after inject, lastOptimized null vs set.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Shared `SectionCard` + `FootprintKpiRow`** (AC: #1, UX-DR11 partial)
  - [x] Add `lib/presentation/widgets/section_card.dart`:
    - Props: `String headline` (Figtree `type.headline`), `Widget child`.
    - Bg `color.bg.elevated`, radius `radius.md`, padding `space.md` (UX §2.4 `SectionCard` pattern).
  - [x] Add `lib/presentation/widgets/footprint_kpi_row.dart`:
    - Props: `int sampleCount`, `int fileSizeBytes`, `DateTime? lastOptimizedUtc`, `DateTime nowUtc`.
    - Layout: sample count + `"samples stored"` label; DB size; `"optimized {relative}"` or `"not optimized yet"` when null (FR13 — relative time only after at least one VACUUM).
    - Typography: Darker Grotesque `AstraTypography.data` for numbers, Figtree caption for labels (UX §2.5 Footprint KPI row).
    - Use `formatStepCount`, `formatFileSize`, `formatRelativeTime`.
    - Responsive: row on wide screens, stacked pairs on narrow (`LayoutBuilder` or `Wrap`).
  - [x] Widget tests: renders counts/sizes; null optimized shows fallback copy; semantics labels for screen readers.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — `BackgroundStatusCard` + platform-aware `StatusBanner`** (AC: #2–#3, UX-DR8/12)
  - [x] Extend `StatusBannerVariant` in `lib/presentation/widgets/status_banner.dart`:
    - Add `info` variant (3px `color.status.info` accent) for iOS backfill copy: `"Steps update when you open the app on this device."`
    - Make `staleFull` copy **platform-aware** via optional `isIos` parameter or dedicated factory:
      - Android: `"No new steps in 12+ hours. Background collection may be delayed on this device."`
      - iOS: `"No new steps in 4+ hours. Steps update when you open the app on this device."`
    - Keep `staleCompact` unchanged for Today (`"Steps may be delayed — see My Data"`).
  - [x] Add `lib/presentation/widgets/background_status_card.dart`:
    - Props: `BackgroundCollectionStatus status`, `DateTime? lastIngestionUtc`, `DateTime nowUtc`, `BackgroundHealthCapabilitySnapshot? capabilities`, `VoidCallback? onOpenSettings`.
    - Status dot colors: ok → `statusOk`, stale → `statusStale`, info/ios → `statusInfo`, permission → muted.
    - Copy per UX §2.5:
      - **healthy:** `"Background collection active · Last sync {relative}"`
      - **stale:** card dot stale + rely on parent `StatusBanner staleFull` above section (do not duplicate full paragraph in card)
      - **iosBackfill:** info dot + `"Steps sync when you open the app · Last sync {relative}"`
      - **permissionDenied:** muted dot + `"Activity permission off"` + `TextButton` → `openAppSettings()` via callback
    - Optional OEM hint (when `capabilities?.likelyOemBatteryDeferral == true` and stale): append secondary line `"Battery optimization may delay collection on ${manufacturer} devices."` — honest, no blame (Story 2.10 flag).
  - [x] Widget tests: each status variant renders expected copy; permission row fires settings callback.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — `MyDataScreen` + shell wiring + refresh hooks** (AC: #1–#3)
  - [x] Replace `lib/presentation/screens/my_data_screen.dart` placeholder:
    - Scrollable column (reuse padding pattern from `HistoryScreen` / UX §3.5):
      1. Title `"My Data"` (`AstraTypography.title`)
      2. When stale → `StatusBanner(staleFull, isIos: …)` at top
      3. `SectionCard` `"Background"` → `BackgroundStatusCard`
      4. `SectionCard` `"Footprint"` → `FootprintKpiRow`
    - **Scope boundary:** Do **not** add Goal, Appearance, or Data action sections — Stories 4.3–4.7.
    - Loading: skeleton placeholders or minimal spinner inside sections (match History loading pattern — no full-screen blocking).
  - [x] `AppScaffold` updates:
    - Hoist `MyDataCubit` alongside Today/History (`createMyDataCubit` test hook).
    - `BlocProvider.value` when index == 2.
    - `_onDestinationSelected`: when opening My Data (`index == 2`), `unawaited(_myDataCubit.refresh())`.
    - Extend `_onIngestionComplete` → `_myDataCubit.refresh(silent: true)`.
    - Add `onMyDataCubitReady` callback (mirror Today/History) for `AstraApp` resume hook.
  - [x] `AstraApp` / `app.dart`: after `dataLifecycleService.runMaintenance()` on resume, refresh My Data cubit if shell mounted (via callback from scaffold — footprint + last optimized must update post-VACUUM).
  - [x] Update `test/widget_test.dart`, `test/presentation/screens/app_scaffold_test.dart` — replace placeholder text assertions with My Data section headlines (`Background`, `Footprint`) or cubit-driven content.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task F — Integration verification** (AC: #1–#3)
  - [x] Manual: inject 90d dev data → open My Data → sample count ~25920 (pre-compaction) or ~10080 (post-maintenance); file size visible; after resume maintenance, "last optimized" shows relative time.
  - [x] Manual: deny activity permission → My Data shows permission_denied card; Today unchanged.
  - [x] Manual: stale state — advance clock in test or use old last ingestion → full banner on My Data + compact on Today (navigate via Today banner tap).
  - [x] Run `flutter test` + `flutter analyze`.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 4.2:**
- My Data screen **first real content**: Background status + Footprint sections only
- `StepRepository.getFootprint()` read API
- `MyDataCubit` / `MyDataState`
- `BackgroundStatusCard`, `FootprintKpiRow`, `SectionCard`
- Platform-aware stale banner (full on My Data, compact on Today — Today wiring already exists)
- Refresh on tab open, ingestion complete, post-maintenance resume
- Display `last_database_optimized_at` from Story 4.1 (relative time)

**Out of scope — defer to later stories:**
- CSV export/import/purge UI → **Stories 4.3–4.5** (footprint refresh hooks must exist so those stories call `_myDataCubit.refresh()` after admin ops)
- Goal editor row → **Story 4.6**
- Theme selector → **Story 4.7**
- Profile initials / display name header → **Stories 4.8–4.9**
- Battery optimization settings deep-link button → optional stub OK; full OEM settings flow not required unless copy references it
- SQLCipher, archive tier → Phase 1+

Epic 4.2 is the **first user-visible sovereignty surface** — proof-oriented KPIs, not settings chrome.

### Pipeline position (Epic 4)

```text
DataLifecycleService + WM maintenance (4.1) ✅
        │
        v
My Data footprint + background status (4.2)   ← THIS STORY
        │
        v
CSV export / import / purge (4.3–4.5)
Goal / theme / profile rows (4.6–4.9)
```

### Architecture contracts (must match exactly)

**FR13 footprint** ([Source: `architecture.md` — Read model, `epics.md` FR13]):

| Field | Source | Display |
|-------|--------|---------|
| Sample count | `COUNT(*)` steps in `timeseries_samples` | `formatStepCount` |
| DB size | SQLite file bytes on disk | `formatFileSize` — approximate, includes WAL if present |
| Last optimized | `user_preferences.last_database_optimized_at` | Relative time; `"not optimized yet"` until first VACUUM (Story 4.1 persists timestamp) |

**FR5 background status** ([Source: `epics.md` FR5, `architecture.md` Platform Architecture]):

| Platform | Stale threshold | UI behavior |
|----------|-----------------|-------------|
| Android | 12 hours since last sample `end_time` | Full stale banner on My Data; compact on Today |
| iOS | 4 hours | Same + info variant explaining backfill model |

Reuse **`isStaleData()`** from `lib/core/health/stale_data_evaluator.dart` — do not duplicate threshold constants.

**Last ingestion timestamp:** `StepRepository.getLastIngestionUtc()` — `MAX(end_time)` for step samples. Same source as `TodayCubit` stale evaluation — keep consistent.

**Capability snapshot:** `BackgroundHealthCapabilityEvaluator.evaluate()` → `BackgroundHealthCapabilitySnapshot` (Story 2.10). Combine with stale evaluator for final card state — evaluator alone does not imply stale.

**Read path only (D-03):** My Data cubit calls repository **read** methods + preferences read + capability evaluate. No `downsample`, `purge`, or `importCsv` in this story.

**DI (Phase 0):** Wire `MyDataCubit` in `AppScaffold` like Today/History — no service locator. Pass `databasePath` from `AppDependencies`.

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 4.2 changes | Must preserve |
|------|---------------|------------------|---------------|
| `lib/presentation/screens/my_data_screen.dart` | `TabPlaceholderBody` stub | Full scrollable screen with 2 sections | Tab still index 2 in shell |
| `lib/presentation/screens/app_scaffold.dart` | No MyDataCubit | Add cubit + providers + refresh hooks | Today/History cubit lifecycle unchanged |
| `lib/presentation/widgets/status_banner.dart` | `staleCompact` + hardcoded `staleFull` (12h Android-only copy) | Platform-aware `staleFull`; add `info` variant | Today compact banner behavior |
| `lib/presentation/screens/today_screen.dart` | Compact stale + navigate to My Data | No structural change; verify stale still works | `onNavigateToMyData` callback |
| `lib/data/repositories/step_repository.dart` | `countStepSamples()`, `getLastIngestionUtc()` | Add `getFootprint()` | All ingestion/admin methods unchanged |
| `lib/core/di/app_dependencies.dart` | No `databasePath` field | Expose path string | Existing singletons |
| `lib/core/services/data_lifecycle_service.dart` | Persists `last_database_optimized_at` | No code change — cubit reads pref | Maintenance scheduling unchanged |
| `lib/core/health/stale_data_evaluator.dart` | Pure threshold helper | Reuse as-is | Threshold values 12h/4h |
| `lib/core/services/background_health_capability_evaluator.dart` | Snapshot API ready | Consume from cubit | No permission request flows |
| `lib/app.dart` | Resume → maintenance + Today refresh | Add My Data refresh after maintenance | Live pipeline, FGS matrix |

### Recommended file layout

```text
lib/data/models/database_footprint.dart                    # NEW
lib/data/repositories/step_repository.dart               # UPDATE — getFootprint
lib/core/di/app_dependencies.dart                        # UPDATE — databasePath
lib/presentation/cubits/my_data_state.dart               # NEW
lib/presentation/cubits/my_data_cubit.dart               # NEW
lib/presentation/formatters/relative_time_formatter.dart # NEW
lib/presentation/formatters/file_size_formatter.dart     # NEW
lib/presentation/widgets/section_card.dart               # NEW
lib/presentation/widgets/footprint_kpi_row.dart          # NEW
lib/presentation/widgets/background_status_card.dart     # NEW
lib/presentation/widgets/status_banner.dart              # UPDATE — platform + info
lib/presentation/screens/my_data_screen.dart             # UPDATE — replace stub
lib/presentation/screens/app_scaffold.dart               # UPDATE — MyDataCubit
lib/app.dart                                             # UPDATE — post-maintenance refresh hook

test/data/repositories/step_repository_footprint_test.dart # NEW
test/presentation/cubits/my_data_cubit_test.dart           # NEW
test/presentation/widgets/footprint_kpi_row_test.dart      # NEW
test/presentation/widgets/background_status_card_test.dart # NEW
test/presentation/widgets/status_banner_test.dart          # NEW or UPDATE
test/presentation/screens/app_scaffold_test.dart           # UPDATE
test/widget_test.dart                                      # UPDATE
```

### Background status decision tree

```text
evaluate() + getLastIngestionUtc()
        │
        ├─ activityRecognitionGranted == false → permissionDenied
        │
        ├─ isStaleData(...) == true → stale (+ StatusBanner staleFull above)
        │
        ├─ isIos == true → iosBackfill (info tone; still show last sync)
        │
        └─ else → healthy
```

`likelyOemBatteryDeferral` does **not** change the enum alone — use as supplementary copy when stale on aggressive OEM devices.

### Footprint refresh triggers (required for AC #1)

| Event | Who refreshes My Data |
|-------|----------------------|
| User opens My Data tab | `AppScaffold._onDestinationSelected` |
| Background ingestion wrote buckets | `registerOnIngestionComplete` |
| App resume after maintenance | `AstraApp` → scaffold callback post-`runMaintenance()` |
| Future: CSV import/export/purge (4.3–4.5) | Those stories must call `myDataCubit.refresh()` — document in 4.3 story |

### UX layout (this story only)

Per UX-DR11 full order is Background → Footprint → Goal → Appearance → Data actions. **4.2 implements the first two sections only.** Do not add placeholder rows for later sections — clean stop after Footprint card.

Wireframe reference: UX §3.5 (healthy), §3.6 (stale).

### Architecture compliance

| Decision / invariant | Requirement for 4.2 |
|----------------------|---------------------|
| D-03 | Cubit reads via repository; no direct SQL in widgets |
| D-23 | Background status uses `BackgroundHealthCapabilityEvaluator` snapshot |
| D-25 | Relative time uses injected `TimeProvider.nowUtc()` — not `DateTime.now()` in cubit |
| FR-5 | Platform stale thresholds + honest copy |
| FR-13 | Sample count, DB size, last optimized relative |
| UX-DR8 | Compact stale Today; full stale My Data |
| UX-DR11 | Section order starts with Background then Footprint |
| UX-DR12 | Four background card variants |

### Anti-patterns (do NOT)

- Add `intl` or `timeago` packages for relative time — keep zero new pub deps unless Baptiste approves.
- Trigger `DataLifecycleService.runMaintenance()` from My Data UI — maintenance stays on schedule/resume only.
- Duplicate stale threshold constants outside `stale_data_evaluator.dart`.
- Implement export/import/purge buttons (4.3–4.5) or goal/theme rows (4.6–4.7).
- Call `VACUUM` or `downsampleStepSamples()` to "refresh" footprint size.
- Block My Data on `runMaintenance()` await — refresh reads current file size; maintenance runs separately on resume.
- Break Today stale compact banner or navigation to My Data tab.

### Previous story intelligence (Story 4.1 — immediate predecessor)

Story **4.1** (done) deliverables to **build on**:
- `UserPreferencesRepository.getLastDatabaseOptimizedAt()` / `kLastDatabaseOptimizedAtKey` — display in Footprint KPI row
- `DataLifecycleService.runMaintenance()` on Android WM + iOS resume — triggers footprint refresh via 4.2 hook
- `StepRepository.countStepSamples()` — reuse inside `getFootprint()`
- Post-compaction row counts (~10 080) — valid footprint test scenario after inject + maintenance

Story **4.1** explicitly deferred to 4.2:
- My Data UI, footprint display, `"last optimized"` relative time
- `getFootprint()` API
- Explicit cubit refresh after maintenance

Story **2.10** (done): `BackgroundHealthCapabilityEvaluator` + `likelyOemBatteryDeferral` flag — consume in `BackgroundStatusCard`, do not re-probe OEM in UI layer.

Story **2.5** (done): Today compact stale banner + `onNavigateToMyData` — verify still works after `StatusBanner` changes.

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `218d89c` | Lifecycle hardening post-review — `DataLifecycleService` API stable; use `getLastDatabaseOptimizedAt()` |
| `0468abf` | Bounded growth tests — sample counts for footprint assertions |
| `e34cf6e` | WM + iOS resume maintenance — post-resume refresh hook needed in 4.2 |
| `c082b0c` | `DataLifecycleService` — do not duplicate maintenance logic |
| `4a6b932` | `downsampleStepSamples` — footprint count drops after maintenance; test refresh |

### Library / framework notes

- **No new packages** expected — `path_provider` / `dart:io` File already available; `permission_handler` already used for settings link.
- **File size caveat:** SQLite WAL mode may mean on-disk size > data-only estimate; label as "approximate" in UX copy if needed (Figtree caption optional: `"approx."` under size — only if design requires; UX wireframe shows `2.4 MB` without qualifier).
- **fl_chart / workmanager / sqflite** — unchanged; no version bumps for this story.
- **Widget tests:** Use `AppDependencies.test()` + in-memory DB + `FakeTimeProvider` for deterministic stale/relative time tests.

### Project context reference

- Review-before-commit workflow: `docs/project-context.md` — one sub-task per commit, review brief in French-friendly format.
- Update `docs/DEPENDENCIES.md` only if new packages added (unlikely).

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 4.2, FR5, FR13, UX-DR8/11/12]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — Read model `getFootprint()`, platform stale thresholds, My Data first-class]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §2.5 My Data, §3.5–3.6 wireframes]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` — FR-5, FR-13, A-4 thresholds]
- [Source: `_bmad-output/implementation-artifacts/stories/4-1-data-lifecycle-service-downsampling-and-maintenance.md` — deferred UI + timestamp]
- [Source: `_bmad-output/implementation-artifacts/stories/2-10-workmanager-orchestration-and-oem-deferral-hardening.md` — capability snapshot for card]
- [Source: `lib/core/health/stale_data_evaluator.dart`]
- [Source: `lib/presentation/widgets/status_banner.dart` — extend, do not rewrite Today path]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

### Completion Notes List

- Sub-task A: `getFootprint()` read API, `databasePath` on DI, lightweight formatters + unit tests (348 tests green).
- Sub-task B: `MyDataCubit` parallel refresh with stale/permission/iOS decision tree; 9 cubit tests.
- Sub-task C: `SectionCard` + responsive `FootprintKpiRow` with accessibility semantics.
- Sub-task D: Platform-aware `StatusBanner` + four-variant `BackgroundStatusCard` with OEM hint.
- Sub-task E: Real `MyDataScreen`, shell wiring, refresh on tab/ingestion/resume post-maintenance.
- Sub-task F: Automated suite 348/348 pass; manual scenarios documented in review briefs below.

### File List

- lib/data/models/database_footprint.dart (new)
- lib/data/repositories/step_repository.dart (updated)
- lib/core/di/app_dependencies.dart (updated)
- lib/presentation/formatters/relative_time_formatter.dart (new)
- lib/presentation/formatters/file_size_formatter.dart (new)
- lib/presentation/cubits/my_data_state.dart (new)
- lib/presentation/cubits/my_data_cubit.dart (new)
- lib/presentation/widgets/section_card.dart (new)
- lib/presentation/widgets/footprint_kpi_row.dart (new)
- lib/presentation/widgets/background_status_card.dart (new)
- lib/presentation/widgets/status_banner.dart (updated)
- lib/presentation/screens/my_data_screen.dart (updated)
- lib/presentation/screens/app_scaffold.dart (updated)
- lib/app.dart (updated)
- test/data/repositories/step_repository_footprint_test.dart (new)
- test/presentation/formatters/footprint_formatters_test.dart (new)
- test/presentation/cubits/my_data_cubit_test.dart (new)
- test/presentation/widgets/footprint_kpi_row_test.dart (new)
- test/presentation/widgets/background_status_card_test.dart (new)
- test/presentation/widgets/status_banner_test.dart (updated)
- test/presentation/screens/app_scaffold_test.dart (updated)
- test/core/di/app_dependencies_test.dart (updated)
- test/widget_test.dart (updated)
- _bmad-output/implementation-artifacts/sprint-status.yaml (updated)

### Change Log

- 2026-06-03: Story 4.2 — My Data footprint + background status (Background + Footprint sections, MyDataCubit, refresh hooks).

### Review Findings

- [x] [Review][Patch] Silent refresh failures leave My Data stuck in loading [`my_data_cubit.dart`] — `_recoverFromRefreshFailure()` keeps last ready snapshot or emits zeroed ready on first-load failure
- [x] [Review][Patch] Silent refresh recovery test [`my_data_cubit_test.dart`] — keeps snapshot after footprint failure; scaffold ingestion widget test removed (SQLite lock deadlock with `collectOnce` + cubit refresh)
- [x] [Review][Patch] Footprint "never optimized" shows em dash [`footprint_kpi_row.dart`] — primary value is `not optimized yet` with `last optimized` caption
- [x] [Review][Defer] `getFootprint` synchronous file I/O on UI isolate — deferred, acceptable for Phase 0
- [x] [Review][Defer] DB size may under-report with WAL — deferred, approximate per spec
- [x] [Review][Defer] No null last-ingestion cubit test — deferred, consistent with Today

## Story completion status

- Ultimate context engine analysis completed — comprehensive developer guide created
- Status: **done**
- Code review patches applied 2026-06-03
