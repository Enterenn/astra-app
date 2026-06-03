# Story 4.3: CSV Export

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want to export my step history to CSV,
So that I own a portable copy of my data.

## Acceptance Criteria

1. **Given** samples in `timeseries_samples`
   **When** user taps Export CSV on My Data
   **Then** OW-aligned CSV including `id` column is written to cache/temp file first (FR19, UX-DR14)
   **And** `share_plus` opens OS share sheet on the local file path

2. **Given** export completes
   **When** on device without network
   **Then** export succeeds (SM-3 / NFR3)

3. **Given** export button state
   **When** in progress
   **Then** spinner shows and duplicate tap is disabled; success snackbar shows for 3s

## Tasks / Subtasks

- [x] **Sub-task A — CSV contract + `StepRepository.exportCsv()`** (AC: #1)
  - [x] Add `lib/data/csv/timeseries_csv_codec.dart` (or `lib/core/csv/` — pick one, keep serializer separate from repository):
    - Canonical header row (exact order, snake_case): `id,start_time,end_time,type,value,unit,resolution,provider,device_id,zone_offset`
    - `String serializeRow(TimeseriesSampleModel sample)` — values from `toMap()` / DB strings unchanged (especially `id`, ISO timestamps, `zone_offset`)
    - RFC 4180 escaping: quote fields containing `,`, `"`, or newline; double internal quotes
    - `value` for `type=steps`: emit integer string (no `.0`) — matches DB integer CHECK
  - [x] Add `Future<String> exportCsv({required String outputDirectory})` on `StepRepository`:
    - **Read-only** query: all rows `WHERE type = ?` (`kStepSampleType`), `ORDER BY start_time ASC` (stable export for round-trip tests in 4.4)
    - Stream rows to file — do not load entire DB into memory (90d inject ≈ 25k+ rows)
    - Filename: `astra-export-{yyyy-MM-dd}.csv` using `TimeProvider` local calendar date (not raw `DateTime.now()` in repository)
    - Return absolute file path written under `outputDirectory` (caller passes `getTemporaryDirectory()` path)
    - Empty DB: write header-only CSV (valid for share sheet)
  - [x] Unit tests: `test/data/csv/timeseries_csv_codec_test.dart` — escaping, header order, integer value
  - [x] Unit tests: `test/data/repositories/step_repository_export_test.dart` — inject N samples → export → parse header + row count; verify `id` round-trip byte-identical from DB
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — `MyDataCubit` export orchestration** (AC: #1–#3)
  - [x] Extend `MyDataState` with export UI fields:
    - `bool isExporting` (default false)
    - Optional `String? exportErrorMessage` for share/write failures (calm English per architecture)
  - [x] Add `Future<void> exportAndShare()` on `MyDataCubit`:
    1. In-flight guard: if `isExporting`, return immediately
    2. Emit `isExporting: true`
    3. `path_provider.getTemporaryDirectory()` → `stepRepository.exportCsv(outputDirectory: temp.path)`
    4. `SharePlus.instance.share(ShareParams(files: [XFile(filePath)], fileNameOverrides: [basename]))` — **not** deprecated `Share.shareXFiles`
    5. On success: emit `isExporting: false`; `unawaited(refresh(silent: true))` (4.2 AC — footprint hook after admin ops; export is read-only but keeps pattern)
    6. On failure: emit `isExporting: false` + `exportErrorMessage`; clear error on next successful refresh/export
  - [x] Cubit tests: exporting flag toggles; duplicate call ignored while in-flight; mock repository + fake share boundary (inject share callback typedef on cubit for testability)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — My Data “Your data” section + Export button** (AC: #1–#3, UX-DR14)
  - [x] Add `SectionCard` headline `"Your data"` below Footprint on `MyDataScreen` (UX §3.5 wireframe — **Export only**; no Import / Purge buttons — Stories 4.4–4.5)
  - [x] Export button:
    - Label: `Export CSV`
    - Style: **primary outline** per UX — accent border (`colors.accentPrimary` side on `OutlinedButton`) + `AstraButton` loading/disabled pattern OR thin wrapper widget `DataActionButton` reusing min touch target 48dp
    - `isLoading` bound to `state.isExporting`; `onPressed` null while exporting
    - Semantics: `"Export data as CSV file"` (UX accessibility table)
  - [x] On export success: `ScaffoldMessenger` snackbar `"Export saved"`, `duration: 3s`
  - [x] On export error: `StatusBanner` error variant with retry (re-tap export) — match UX action error pattern
  - [x] Widget test: button shows spinner when `isExporting`; tap disabled
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Integration + regression** (AC: #1–#2)
  - [x] Widget/integration: `MyDataScreen` pump with mock cubit → Export visible under Your data section
  - [x] Confirm **no new pub deps** (`share_plus`, `path_provider` already in `pubspec.yaml`)
  - [x] Run `flutter test` + `flutter analyze`
  - [x] Manual: inject dev data → Export → share sheet opens with `astra-export-*.csv` → airplane mode / release build still exports (no ASTRA network call)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Documentation touch (optional, small)** (FR27 precursor)
  - [x] If timeboxed in same story: add minimal `docs/OPEN_WEARABLES_ALIGNMENT.md` stub listing CSV column mapping (can be 10 lines). Otherwise defer to Epic 6 — **do not block story completion**
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 4.3:**
- OW-aligned CSV **export** of all `timeseries_samples` step rows
- Cache/temp file write **before** `share_plus` (D-14, FR-19)
- My Data **Your data** section with **Export CSV** only
- Button loading state + 3s success snackbar
- Offline-safe export (no HTTP in ASTRA pipeline)
- Repository `exportCsv()` read path + unit tests

**Out of scope — defer to later stories:**
- CSV **import** UI + `importCsv()` + `ImportResult` → **Story 4.4**
- **Purge** + export-first nudge dialog → **Stories 4.5, 4.21**
- Export → purge → import **round-trip** integration test → **Story 4.4** (FR-30); export unit tests suffice here
- Goal / Appearance sections → **Stories 4.6–4.7**
- Post-export Today/History cubit refresh — **not required** (export does not mutate DB); optional silent Today refresh **not** needed
- `docs/SERIES_TYPES.md` full bundle → Epic 6 / FR-27

Epic 4 sovereignty flows start here: first **portable data exit** path for users.

### Pipeline position (Epic 4)

```text
DataLifecycleService (4.1) ✅
My Data footprint + background status (4.2) ✅
        │
        v
CSV export (4.3)   ← THIS STORY
        │
        v
CSV import (4.4) → purge (4.5) → goal/theme/profile (4.6–4.9)
```

### Architecture contracts (must match exactly)

**FR-19 export** ([Source: `prd.md` FR-19, `architecture.md` D-14, `epics.md` Story 4.3]):

| Requirement | Implementation |
|-------------|----------------|
| OW-aligned columns | All 10 schema fields in header order (see Sub-task A) |
| Preserve `id` | Export DB `id` TEXT unchanged — no regeneration |
| Cache-first | `getTemporaryDirectory()` + `File.writeAsString` / IOSink — then share **file path** |
| No in-memory-only share | Anti-pattern explicitly forbidden |
| Offline | Export + share sheet work without INTERNET (NFR-3 / SM-3) |
| Filename | `astra-export-{yyyy-MM-dd}.csv` |

**Write path (D-03):** `exportCsv()` is a **read-only** repository method. No `db.transaction()` needed. Cubit orchestrates share UI only — does not open SQLite directly.

**Administrative writes table** ([Source: `architecture.md`]): `importCsv()`, `downsample()`, `purge()` are separate — **do not** implement import/purge stubs that look clickable.

**Cubit refresh (4.2 continuity):** Call `myDataCubit.refresh(silent: true)` after successful export so My Data stays consistent with future import/purge stories — footprint KPIs will not change on export.

### CSV format specification (implement exactly)

**Header row (comma-separated, no BOM required Phase 0):**

```text
id,start_time,end_time,type,value,unit,resolution,provider,device_id,zone_offset
```

**Example data row** (from addendum §2):

```text
a1b2c3d4-e5f6-7890-abcd-ef1234567890,2026-05-22T14:30:00Z,2026-05-22T14:35:00Z,steps,132,count,5min,internal_phone,smartphone,+02:00
```

**Rules:**
- Timestamps: already stored as ISO 8601 UTC with `Z` — export as stored in DB (`TimestampCodec.formatUtc` values)
- `zone_offset`: export immutable string e.g. `+02:00` (no conversion)
- Include **all resolutions** present (`5min`, `1hour`, `1d`) after lifecycle compaction — do not re-aggregate
- Phase 0: only `type=steps` rows (future types Phase 1+)

**Import forward-compatibility (4.4):** Header set must match what `importCsv()` will validate — keep codec in shared module both stories import.

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 4.3 changes | Must preserve |
|------|---------------|------------------|---------------|
| `lib/data/repositories/step_repository.dart` | Ingestion, footprint, downsample, chart reads | Add `exportCsv()` | `upsertIngestionBucket`, `downsampleStepSamples`, `getFootprint` |
| `lib/data/models/timeseries_sample_model.dart` | `toMap()` / `fromMap()` | Reuse for CSV row shape | Field names match SQL |
| `lib/presentation/screens/my_data_screen.dart` | Background + Footprint sections only | Add Your data + Export | Stale banner, existing sections |
| `lib/presentation/cubits/my_data_cubit.dart` | Read-only refresh | Add `exportAndShare()` + export flags | Refresh failure recovery |
| `lib/presentation/cubits/my_data_state.dart` | Footprint + background fields | Add `isExporting`, optional error | `copyWith` pattern |
| `lib/presentation/widgets/astra_button.dart` | primary/secondary/ghost | Reuse `isLoading` or accent-outline variant | Existing variants |
| `lib/presentation/screens/app_scaffold.dart` | MyDataCubit wired | No change unless DI needs share mock hook | Today/History lifecycle |
| `pubspec.yaml` | `share_plus: ^13.1.0`, `path_provider: ^2.1.5` | No version bump unless required | — |

### Recommended file layout

```text
lib/data/csv/timeseries_csv_codec.dart              # NEW — header + row serialization
lib/data/repositories/step_repository.dart          # UPDATE — exportCsv()
lib/presentation/cubits/my_data_state.dart          # UPDATE — export flags
lib/presentation/cubits/my_data_cubit.dart          # UPDATE — exportAndShare()
lib/presentation/screens/my_data_screen.dart        # UPDATE — Your data section
lib/presentation/widgets/data_export_button.dart    # NEW (optional) — accent outline + loading

test/data/csv/timeseries_csv_codec_test.dart        # NEW
test/data/repositories/step_repository_export_test.dart  # NEW
test/presentation/cubits/my_data_cubit_export_test.dart  # NEW
test/presentation/screens/my_data_screen_test.dart  # NEW or UPDATE
```

### Export flow (sequence)

```text
User taps Export CSV
    → MyDataCubit.exportAndShare()
    → isExporting = true (button spinner)
    → getTemporaryDirectory()
    → StepRepository.exportCsv(tempDir)  // writes astra-export-{date}.csv
    → SharePlus.instance.share(ShareParams(files: [XFile(path)]))
    → isExporting = false
    → SnackBar "Export saved" (3s)
    → refresh(silent: true)
```

Share sheet cancellation by user is **not** an error — treat as success path if file was written (file remains in temp; OS handles cleanup).

### UX compliance (UX-DR14)

| Element | Spec |
|---------|------|
| Section title | `Your data` (wireframe §3.5) |
| Export button | Primary outline — **accent border** (`#EAD55E`), not default `borderDefault` secondary |
| Loading | Spinner on button, disable duplicate tap |
| Success | Snackbar 3s: `"Export saved"` |
| Error | `StatusBanner` error + retry |
| Placement | After Footprint; before Goal/Appearance (not implemented yet) |

Reuse `SectionCard` from Story 4.2. Do **not** add Import/Purge placeholders.

### share_plus v13 API (use current, not deprecated)

```dart
import 'package:share_plus/share_plus.dart';

await SharePlus.instance.share(
  ShareParams(
    files: [XFile(filePath)],
    fileNameOverrides: [p.basename(filePath)],
  ),
);
```

Do **not** use `Share.share()`, `Share.shareXFiles()` — deprecated in 13.x.

### Architecture compliance

| Decision / invariant | Requirement for 4.3 |
|----------------------|---------------------|
| D-14 | Cache/temp file before share |
| D-03 | Export via `StepRepository`; cubit does not touch `Database` |
| D-25 | Export filename date from `TimeProvider` / `clock.snapshot()` |
| FR-19 | OW columns + preserved `id` |
| UX-DR14 | Export flow states (idle → spinner → snackbar) |
| NFR-3 | No network in export path |
| Anti-pattern | No `Share.shareXFiles` without persisted file; no cubit `db.insert` |

### Anti-patterns (do NOT)

- Share CSV string from memory without writing temp file first
- Regenerate UUIDs on export
- Filter to 5min-only rows (must export post-compaction `1hour` / `1d` too)
- Add `csv` package if `dart:convert` + manual escaping suffices
- Implement `importCsv()` or purge in this story
- Block UI thread with synchronous read of 25k rows into one `String` before write — stream to `IOSink`
- Use `DateTime.now()` in repository for filename
- Add Import/Purge buttons as disabled stubs

### Previous story intelligence (Story 4.2 — immediate predecessor)

Story **4.2** (done) deliverables to **build on**:
- `MyDataScreen` with `SectionCard`, scroll layout, `BlocBuilder<MyDataCubit>`
- `MyDataCubit.refresh()` + in-flight guard + silent refresh failure recovery
- `AppScaffold` refresh on tab select, ingestion, post-maintenance resume
- Explicit note: **Stories 4.3–4.5 must call `myDataCubit.refresh()` after admin ops** — export should call refresh for consistency

Story **4.2** scope boundary: only Background + Footprint — **4.3 adds third section**

Story **4.1** (done): Post-compaction DB may have mixed resolutions — export must include all rows returned by step query

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `717f7b0` | My Data code review patterns — silent refresh recovery, footprint formatters |
| `5a02f90` | Shell wiring for `MyDataCubit` — extend cubit, not scaffold structure |
| `67155df` | `SectionCard` + KPI widgets — reuse for Your data section |
| `218d89c` / `4a6b932` | Compaction — export tests should use multi-resolution DB after `downsampleStepSamples()` |

### Library / framework notes

- **Packages:** `share_plus ^13.1.0`, `path_provider ^2.1.5` already declared — update `docs/DEPENDENCIES.md` only if adding new deps (none expected)
- **cross_file:** `XFile` exported from `share_plus` package — no separate import required unless analyzer asks
- **Large exports:** 90d inject (~25k rows) — use cursor/streaming; target <2s on mid-range device (no KPI, but avoid OOM)
- **Android share:** User may pick Drive/Gmail — network is user/OS choice, not ASTRA pipeline (document in review brief)

### Testing requirements

| Test | Purpose |
|------|---------|
| `timeseries_csv_codec_test` | Header order, escaping, integer steps value |
| `step_repository_export_test` | Row count, id preservation, empty DB header-only |
| `my_data_cubit_export_test` | In-flight guard, exporting flag |
| `my_data_screen_test` | Export button + loading state |
| Manual airplane mode | AC #2 SM-3 |

**Deferred to 4.4:** Full round-trip export → purge → import → chart visible

### Project context reference

- Review-before-commit: `docs/project-context.md` — one sub-task per commit, French-friendly review brief, wait for Baptiste OK
- `user_skill_level: intermediate` — explain `share_plus` ShareParams migration in review brief

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 4.3, FR19, UX-DR14]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — D-14, exportCsv, CSV format, anti-patterns]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` — FR-19, §4.3.1]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/addendum.md` — §2 schema + JSON example]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §2.5 Data actions, §3.5 wireframe, §3.9 Export flow]
- [Source: `_bmad-output/implementation-artifacts/stories/4-2-my-data-footprint-and-background-status.md` — refresh hooks, scope boundary]
- [Source: `lib/data/models/timeseries_sample_model.dart`]
- [Source: `lib/presentation/screens/my_data_screen.dart`]
- [Source: pub.dev share_plus 13.1.0 — ShareParams + SharePlus.instance.share]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Initial test run: 8/8 repository + cubit tests passed; codec test fixed (missing import); screen tests updated to avoid pumpAndSettle hang
- Subsequent `flutter test` blocked on Windows by locked `build/native_assets/windows/sqlite3.dll` (environment file lock)
- `flutter analyze` on changed files: no issues
- Post-review: 21/21 export-related tests pass on Windows (`flutter test` targeted suites)
- Manual: Windows/desktop export flow validated; **iOS share sheet not tested** (no Mac/iPhone/iPad) — see Validation deferred below

### Validation deferred (iOS)

- **Not tested:** iOS/iPadOS share sheet (no Mac, no physical device).
- **Mitigation in code:** `sharePositionOrigin` from export button via `share_position_origin.dart` (+ 1×1 fallback); unit test verifies origin forwarded to share callback.
- **Follow-up:** Validate on iOS simulator or device when hardware/CI macOS available (Epic 4 backlog note).

### Completion Notes List

- Implemented OW-aligned CSV export pipeline: `TimeseriesCsvCodec` + batched `StepRepository.exportCsv()` streaming to temp file
- `MyDataCubit.exportAndShare()` orchestrates temp dir → export → `SharePlus.instance.share(ShareParams(...))` with injectable boundaries for tests
- My Data screen: "Your data" section with accent-outline `DataExportButton`, loading state, 3s success snackbar, error `StatusBanner` with retry tap
- Added `StatusBannerVariant.error` for export failure UX
- No new pub dependencies; optional `docs/OPEN_WEARABLES_ALIGNMENT.md` stub added
- Code review fixes: preserve export state across `refresh`, keyset pagination, partial file cleanup, `\r` escaping, debug logging on export failure

### File List

- `lib/data/csv/timeseries_csv_codec.dart` (new)
- `lib/data/repositories/step_repository.dart` (updated)
- `lib/presentation/cubits/my_data_state.dart` (updated)
- `lib/presentation/cubits/my_data_cubit.dart` (updated)
- `lib/presentation/screens/my_data_screen.dart` (updated)
- `lib/presentation/widgets/data_export_button.dart` (new)
- `lib/presentation/widgets/status_banner.dart` (updated)
- `lib/presentation/utils/share_position_origin.dart` (new)
- `test/data/csv/timeseries_csv_codec_test.dart` (new)
- `test/data/repositories/step_repository_export_test.dart` (new)
- `test/presentation/cubits/my_data_cubit_export_test.dart` (new)
- `test/presentation/screens/my_data_screen_test.dart` (new)
- `docs/OPEN_WEARABLES_ALIGNMENT.md` (new)

## Change Log

- 2026-06-03: Story 4.3 CSV export — codec, repository exportCsv, My Data export UI, cubit orchestration, tests, OW alignment doc stub
- 2026-06-03: Code review fixes + iOS validation deferred note; story done (Windows tests + manual desktop)
