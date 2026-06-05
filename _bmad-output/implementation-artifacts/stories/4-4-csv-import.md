# Story 4.4: CSV Import

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want to import a previously exported ASTRA CSV,
So that I can restore data after reinstall or device change.

## Acceptance Criteria

1. **Given** a valid ASTRA export CSV
   **When** user selects file via picker
   **Then** rows import inside a single transaction with `INSERT OR IGNORE` on UUID `id` (FR30, D-16)
   **And** duplicate bucket identity increments skip count — not silent corruption

2. **Given** malformed headers or rows
   **When** import validates
   **Then** entire transaction aborts with user-visible `StatusBanner` error (FR30)

3. **Given** existing data in DB
   **When** import starts
   **Then** `ConfirmDialog` asks to replace with row count preview (UX-DR15)

4. **Given** successful import
   **When** complete
   **Then** Today and History cubits refresh and footprint updates

## Tasks / Subtasks

- [x] **Sub-task A — CSV deserialize + validation + `ImportResult` model** (AC: #1–#2)
  - [x] Extend `lib/data/csv/timeseries_csv_codec.dart`:
    - `static List<String> parseHeaderRow(String line)` — split RFC 4180, validate exact column set/order matches `headerRow` (case-sensitive, snake_case)
    - `static TimeseriesSampleModel parseDataRow(String line)` — unescape fields, map to model via `TimeseriesSampleModel.fromMap()` shape
    - Row validation: required non-empty fields; `type == steps` only (Phase 0); `value` integer ≥ 0; `unit == count`; `resolution` in `{5min, 1hour, 1d}`; valid ISO UTC timestamps; `TimestampCodec.parseZoneOffset(zone_offset)` must not throw
    - Throw `ImportValidationException` with calm English message (include row number, 1-based data rows) on any parse/validation failure
  - [x] Add `lib/data/models/import_result.dart`:
    ```dart
    class ImportResult {
      final int totalRowsInFile;
      final int insertedCount;
      final int skippedCount; // id OR bucket UNIQUE ignored
    }
    ```
  - [x] Add `lib/core/database/import_validation_exception.dart` (or `lib/data/csv/`) — typed exception for cubit error mapping
  - [x] Unit tests: `test/data/csv/timeseries_csv_codec_test.dart` (parse group) — valid row round-trip from serialize; bad header; bad row; RFC 4180 quoted fields; `\r` handling; integer steps value
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — `StepRepository.importCsv()`** (AC: #1–#2)
  - [x] Add `Future<ImportResult> importCsv({required String filePath})`:
    1. **Parse + validate entire file first** (before any DB write) — stream/lines read; reject empty file, missing header, zero data rows allowed (no-op import returning zeros)
    2. Build `List<TimeseriesSampleModel>` in memory OR validate streaming then re-read — for 90d inject (~25k rows) memory is acceptable; prefer single pass validate-then-transact
    3. `await db.transaction((txn) async { ... })` — repository owns scope (D-24)
    4. For each sample: `final rowId = await txn.insert('timeseries_samples', sample.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);`
    5. Count `insertedCount` when `rowId != 0`; else increment `skippedCount` (covers duplicate `id` **and** duplicate bucket identity per D-16)
    6. On any unexpected DB error inside transaction: rethrow — SQLite rolls back automatically
  - [x] **Do NOT** delete existing rows in this story — merge-only import; `purge()` is Story 4.5
  - [x] Unit tests: `test/data/repositories/step_repository_import_test.dart`:
    - export → import into empty DB → all rows inserted
    - re-import same file → `insertedCount == 0`, `skippedCount == totalRows`
    - malformed CSV → throws `ImportValidationException`, DB unchanged (count before == after)
    - duplicate bucket new UUID → second insert skipped, `skippedCount` incremented
    - **Round-trip:** inject N samples → export → import into fresh empty DB → `getChartDailyAggregates` returns same totals as pre-export
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — `ConfirmDialog` widget (import variant only)** (AC: #3, UX-DR15)
  - [x] Add `lib/presentation/widgets/confirm_dialog.dart`:
    - Import overwrite variant: title `"Import data?"` (or UX `"Replace all data?"` — pick one consistent with UX §3.10), body includes **CSV row count preview** e.g. `"This file contains {N} samples."` + brief note that existing rows with matching IDs will be skipped (additive merge — **not** purge)
    - Actions: **Import** (primary) · **Cancel** (ghost)
    - Reuse Astra tokens (`AstraTypography`, `AstraSpacing`, `colors.bgElevated`)
    - **Purge variant (Export first / Delete anyway) deferred to Story 4.5** — do not implement purge dialog actions yet
  - [x] Widget test: dialog shows row count; Cancel pops false; Import pops true
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — `MyDataCubit` import orchestration + cross-cubit refresh** (AC: #1–#4)
  - [x] Extend `MyDataState`:
    - `bool isImporting` (default false)
    - `String? importErrorMessage`
  - [x] Add injectable boundaries (mirror export pattern):
    - `typedef PickCsvFileCallback = Future<String?> Function();` — returns absolute path or null if cancelled
    - `typedef ConfirmImportCallback = Future<bool> Function(int csvRowCount, int existingSampleCount);`
    - `typedef PostImportRefreshCallback = Future<void> Function();` — wired by `AppScaffold` to refresh Today + History + My Data
  - [x] Add `Future<void> pickAndImport()` flow:
    1. In-flight guard: if `isImporting` or `isExporting`, return
    2. `pickCsvFile()` → null = user cancelled, no error banner
    3. **Pre-parse row count** for confirm dialog: lightweight header + line count OR parse via codec in dry-run mode (reuse validation, no DB)
    4. If `state.sampleCount > 0`: await `confirmImport(csvRowCount, existingSampleCount)` — false = cancel
    5. Emit `isImporting: true`, clear `importErrorMessage`
    6. `stepRepository.importCsv(filePath: path)`
    7. On success: emit `isImporting: false`; call `postImportRefresh()` then `refresh(silent: true)`
    8. On `ImportValidationException`: emit error message for `StatusBanner` + retry on tap
    9. On other failures: calm generic error string
  - [x] Wire `AppScaffold` / `MyDataCubit` factory:
    ```dart
    postImportRefresh: () async {
      await _todayCubit.refreshMetadata();
      await _historyCubit.refresh(silent: true);
      await _myDataCubit.refresh(silent: true);
    }
    ```
    Architecture table requires post import/purge refresh on Today + History (architecture §Frontend — Cubit refresh triggers)
  - [x] Cubit tests: importing flag; duplicate tap ignored; confirm skipped when empty DB; mock pick/confirm/import/refresh callbacks
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — My Data Import button + UI states** (AC: #1–#4, UX-DR14/§3.10)
  - [x] Add `lib/presentation/widgets/data_import_button.dart` — **secondary** `AstraButtonVariant.secondary` (NOT accent-outline — that is export-only per UX §2.5)
    - Label: `Import CSV`
    - Semantics: `"Import CSV file"`
    - `isLoading` bound to `state.isImporting`
  - [x] Update `MyDataScreen` Your data section:
    - Export button (existing) then Import button below with `AstraSpacing.kSpaceSm` gap
    - `BlocListener` for import success → snackbar `"Import complete"` 3s (UX §2.5)
    - Import error → `StatusBanner` error variant with retry (`pickAndImport`)
    - Preserve export error/import error mutual visibility rules (both can use separate banners or single error slot — prefer separate fields like export)
  - [x] Confirm dialog invoked from screen context (needs `BuildContext`) — either:
    - Screen calls `cubit.pickAndImport(confirmImport: (n, existing) => showConfirmDialog(...))`, OR
    - Cubit emits `MyDataImportConfirmationRequested` state — **prefer injectable callback from screen to keep cubit UI-testable without BuildContext**
  - [x] Widget tests: Import button visible; spinner when importing; snackbar on success
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task F — Dependency + integration + round-trip** (AC: #1–#4)
  - [x] Add `file_picker: ^11.0.2` to `pubspec.yaml`; update `docs/DEPENDENCIES.md` (local-only, no network in health pipeline)
  - [x] Default picker in cubit:
    ```dart
    FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: false, // read from path — large files
    );
    ```
    v11.0.2 fixes Android CSV MIME filtering (#1849)
  - [x] Integration test: export file from repository → import → chart aggregates non-empty
  - [x] Run `flutter test` + `flutter analyze`
  - [x] Manual: inject dev data → export → import on empty DB → Today/History show data; re-import shows skip behavior; corrupt CSV shows error banner; airplane mode works
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 4.4:**
- OW-aligned CSV **import** with full validation before write
- `StepRepository.importCsv()` + `ImportResult` + `INSERT OR IGNORE` idempotency (D-16)
- `TimeseriesCsvCodec` deserialize/validate (mirror export codec)
- My Data **Import CSV** button (secondary style)
- `ConfirmDialog` import variant when DB non-empty
- Post-import Today + History + My Data refresh
- Round-trip test: export → import (empty DB) restores chart-visible history (FR-30)
- `file_picker` dependency (first use in project)

**Out of scope — defer to later stories:**
- **Purge** UI + `purge()` + export-first nudge dialog → **Story 4.5**
- Full beta round-trip **export → purge → import** (purge step is 4.5) — 4.4 tests export → import into empty DB
- Goal / Appearance sections → **Stories 4.6–4.7**
- Selective merge strategies / multi-device conflict UI → Phase 1+
- Purge variant of `ConfirmDialog` → **Story 4.5**

### Pipeline position (Epic 4)

```text
DataLifecycleService (4.1) ✅
My Data footprint + background status (4.2) ✅
CSV export (4.3) ✅
        │
        v
CSV import (4.4)   ← THIS STORY
        │
        v
Purge (4.5) → goal/theme/profile (4.6–4.9)
```

### Architecture contracts (must match exactly)

**FR-30 import** ([Source: `prd.md` FR-30, `architecture.md` D-16/D-24, `epics.md` Story 4.4]):

| Requirement | Implementation |
|-------------|----------------|
| Validate headers + rows | Parse entire file before transaction; abort with `ImportValidationException` |
| Single transaction | `db.transaction()` in `importCsv()` — no partial writes |
| Idempotent on `id` | `ConflictAlgorithm.ignore` on insert |
| Bucket duplicate guard | UNIQUE index `idx_bucket_identity` — ignored insert increments `skippedCount` |
| No silent corruption | Return `ImportResult` with inserted/skipped counts |
| Offline | File picker + local SQLite only (NFR-3 / SM-3) |
| Cubit refresh | Today `refreshMetadata()`, History `refresh(silent: true)`, My Data `refresh(silent: true)` |

**Confirm dialog vs merge semantics (critical):**

UX §3.10 titles the dialog `"Replace all data?"` but **Story 4.4 does NOT purge**. Architecture mandates additive `INSERT OR IGNORE` merge. The dialog is **informed consent before importing into a non-empty DB** — show CSV row count preview. Body copy should clarify that matching IDs are skipped (not overwritten). True replace-via-purge is **Story 4.5**. Do **not** call `purge()` or delete steps in `importCsv()`.

**Write path (D-03):** `importCsv()` is an **administrative write** on `StepRepository`. Cubit orchestrates picker + confirm + refresh — never opens `Database` directly.

### CSV format specification (must match export / Story 4.3)

**Header row (exact match required):**

```text
id,start_time,end_time,type,value,unit,resolution,provider,device_id,zone_offset
```

**Example data row:**

```text
a1b2c3d4-e5f6-7890-abcd-ef1234567890,2026-05-22T14:30:00Z,2026-05-22T14:35:00Z,steps,132,count,5min,internal_phone,smartphone,+02:00
```

**Import rules:**
- Reuse export codec field order — byte-compatible round-trip
- Accept all resolutions present in file (`5min`, `1hour`, `1d`)
- Phase 0: reject non-`steps` types with validation error
- Integer steps values only (match DB CHECK)

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 4.4 changes | Must preserve |
|------|---------------|------------------|---------------|
| `lib/data/csv/timeseries_csv_codec.dart` | Serialize only (`headerRow`, `serializeRow`) | Add parse + validate | Export behavior unchanged |
| `lib/data/repositories/step_repository.dart` | `exportCsv()` read path | Add `importCsv()` | `exportCsv`, `upsertIngestionBucket`, compaction |
| `lib/presentation/cubits/my_data_cubit.dart` | `exportAndShare()` + refresh | Add `pickAndImport()` + import flags | Export flow, refresh recovery |
| `lib/presentation/cubits/my_data_state.dart` | Export flags | Add `isImporting`, `importErrorMessage` | `copyWith` pattern for export fields |
| `lib/presentation/screens/my_data_screen.dart` | Export only in Your data | Add Import button + listeners | Export section, stale banner |
| `lib/presentation/widgets/data_export_button.dart` | Accent outline export | No change — import gets separate widget | Export styling |
| `lib/presentation/screens/app_scaffold.dart` | Cubit wiring, ingestion refresh | Wire `postImportRefresh` callback into `MyDataCubit` | Tab lifecycle, export cubit |
| `pubspec.yaml` | No `file_picker` | Add `file_picker ^11.0.2` | Existing deps |

### Recommended file layout

```text
lib/data/csv/timeseries_csv_codec.dart              # UPDATE — parse + validate
lib/data/models/import_result.dart                  # NEW
lib/core/database/import_validation_exception.dart  # NEW (or lib/data/csv/)
lib/data/repositories/step_repository.dart          # UPDATE — importCsv()
lib/presentation/widgets/confirm_dialog.dart        # NEW — import variant
lib/presentation/widgets/data_import_button.dart    # NEW — secondary style
lib/presentation/cubits/my_data_state.dart          # UPDATE — import flags
lib/presentation/cubits/my_data_cubit.dart          # UPDATE — pickAndImport()
lib/presentation/screens/my_data_screen.dart        # UPDATE — Import UI
lib/presentation/screens/app_scaffold.dart          # UPDATE — postImportRefresh wiring

test/data/csv/timeseries_csv_codec_test.dart  # serialize + parse groups (merged 2026-06-05)
test/data/repositories/step_repository_import_test.dart  # NEW
test/data/repositories/step_repository_roundtrip_test.dart  # NEW (optional merge with import_test)
test/presentation/cubits/my_data_cubit_import_test.dart  # NEW
test/presentation/widgets/confirm_dialog_test.dart  # NEW
test/presentation/screens/my_data_screen_test.dart  # UPDATE
```

### Import flow (sequence)

```text
User taps Import CSV
    → MyDataCubit.pickAndImport()
    → FilePicker (filter .csv) → path or cancel
    → Parse/validate row count (no DB write yet)
    → if sampleCount > 0: ConfirmDialog with N rows preview
    → isImporting = true
    → StepRepository.importCsv(path)  // validate + single transaction
    → postImportRefresh(): Today.refreshMetadata + History.refresh + MyData.refresh
    → isImporting = false
    → SnackBar "Import complete" (3s)
```

User cancels picker or confirm dialog → no error banner (not a failure).

### UX compliance (UX-DR14 / §3.10)

| Element | Spec |
|---------|------|
| Import button | **Secondary** (`AstraButtonVariant.secondary`) — not accent outline |
| Export button | Unchanged accent outline (`DataExportButton`) |
| Loading | Spinner on Import button, disable duplicate tap |
| Success snackbar | `"Import complete"` 3s |
| Error | `StatusBanner` error + retry tap |
| Confirm | Row count preview when DB has existing samples |
| Semantics | `"Import CSV file"` |

Placement: Your data section — Export then Import (stacked); Purge deferred 4.5.

### Insert idempotency implementation note

```dart
await db.transaction((txn) async {
  for (final sample in validatedSamples) {
    final rowId = await txn.insert(
      'timeseries_samples',
      sample.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (rowId == 0) {
      skippedCount++;
    } else {
      insertedCount++;
    }
  }
});
```

`ConflictAlgorithm.ignore` maps to SQLite `INSERT OR IGNORE`, which ignores **both** PRIMARY KEY (`id`) and UNIQUE (`idx_bucket_identity`) violations — satisfies D-16 dual-key reconciliation without silent partial corruption.

### Architecture compliance

| Decision / invariant | Requirement for 4.4 |
|----------------------|---------------------|
| D-16 | `INSERT OR IGNORE` + skip counting |
| D-24 | Single `db.transaction()` for all inserts |
| D-03 | Import via `StepRepository`; cubit does not touch `Database` |
| FR-30 | Validate-then-import; round-trip test |
| UX-DR14/15 | Import flow states + confirm dialog |
| NFR-3 | No network in import path |
| Cubit refresh table | Post import: Today + History + My Data |

### Anti-patterns (do NOT)

- Partial import on validation failure (validate ALL rows before transaction)
- `db.insert()` outside repository or outside transaction
- Purge/delete existing steps in import (Story 4.5)
- Regenerate UUIDs on import
- Use `INSERT OR REPLACE` (would overwrite bucket values incorrectly)
- Load entire CSV into one unvalidated string without row-level checks
- Open transactions from cubit/widget
- Add Import/Purge buttons as disabled stubs beyond Import implementation
- Use accent-outline style for Import (export-only per UX)
- Skip Today/History refresh after successful import

### Previous story intelligence (Story 4.3 — immediate predecessor)

Story **4.3** (done) deliverables to **reuse directly**:
- `TimeseriesCsvCodec.headerRow` + `serializeRow()` — extend same module for parse
- `StepRepository.exportCsv()` streaming pattern — mirror for import line reading
- `MyDataCubit` injectable boundaries (`ShareCsvFileCallback`, in-flight guards) — same pattern for picker/confirm/refresh
- `DataExportButton` / Your data `SectionCard` — add Import below Export
- `StatusBannerVariant.error` + retry tap pattern from export errors
- `docs/OPEN_WEARABLES_ALIGNMENT.md` — column contract already documented
- Code review fixes from 4.3: preserve import state across `refresh()` like export (`copyWith` in `_emitReadySnapshot`)

Story **4.3** explicitly deferred: `importCsv()`, `ImportResult`, Import button, round-trip tests.

Story **4.2** (done): `myDataCubit.refresh()` after admin ops — import must call refresh + cross-cubit hooks.

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `2a65a48` | CSV export landed — codec, `exportCsv`, `DataExportButton`, cubit export orchestration; **extend, don't duplicate** |
| `717f7b0` | My Data review patterns — silent refresh recovery, error banners |
| `5a02f90` | AppScaffold cubit wiring — add `postImportRefresh` here |
| `67155df` | `SectionCard` — reuse for Your data section layout |

### Library / framework notes

- **file_picker ^11.0.2** (Apr 2026): stable; Android CSV filter fix in 11.0.2; use `FileType.custom` + `allowedExtensions: ['csv']`; `withData: false` for path-based read of large files
- **No `csv` package** — manual RFC 4180 parse matching export codec (consistent with 4.3 decision)
- **Large imports:** 90d inject ~25k rows — validate in one pass (~few MB RAM), single transaction insert loop acceptable for Phase 0
- **Platform:** File picker returns cached copy on iOS — read via returned path; no network

### Testing requirements

| Test | Purpose |
|------|---------|
| `timeseries_csv_codec_test` (parse group) | Header/row validation, escaping round-trip |
| `step_repository_import_test` | Insert/skip counts, validation abort, bucket duplicate |
| Round-trip test | export → import empty DB → chart aggregates match |
| `my_data_cubit_import_test` | In-flight guard, confirm skip on empty DB, refresh callback |
| `confirm_dialog_test` | Row count display, actions |
| `my_data_screen_test` | Import button + loading + snackbar |
| Manual airplane mode | AC offline (SM-3) |

**Deferred to 4.5:** export → **purge** → import full beta checklist path (FR-29).

### Project context reference

- Review-before-commit: `docs/project-context.md` — one sub-task per commit, French-friendly review brief, wait for Baptiste OK
- Update `docs/DEPENDENCIES.md` when adding `file_picker`
- `user_skill_level: intermediate` — explain `file_picker`, `ConflictAlgorithm.ignore`, and confirm-dialog callback pattern in review brief

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 4.4, FR30, UX-DR15]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — D-16, D-24, importCsv, ImportResult, cubit refresh table]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` — FR-30, §4.3.1 canonical shape]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §2.5 Data actions, §3.5 wireframe, §3.10 Import flow]
- [Source: `_bmad-output/implementation-artifacts/stories/4-3-csv-export.md` — codec, export patterns, scope boundary]
- [Source: `lib/data/csv/timeseries_csv_codec.dart`]
- [Source: `lib/data/repositories/step_repository.dart` — exportCsv, insertDevSamplesBatch transaction pattern]
- [Source: `lib/core/database/migrations.dart` — idx_bucket_identity UNIQUE]
- [Source: `docs/OPEN_WEARABLES_ALIGNMENT.md`]
- [Source: pub.dev file_picker 11.0.2]

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- `file_picker ^11.0.2` incompatible with `share_plus ^13.1.0` (win32 5 vs 6); resolved with `file_picker ^12.0.0-beta.5` + `FilePicker.pickFile` API.

### Completion Notes List

- Sub-task A: RFC 4180 parse/validate in `TimeseriesCsvCodec`, `ImportResult`, `ImportValidationException`, parse unit tests.
- Sub-task B: `StepRepository.importCsv()` validate-then-single-transaction with `INSERT OR IGNORE` + skip counts; import + round-trip repository tests.
- Sub-task C: `showImportConfirmDialog` with row-count preview (merge semantics, no purge).
- Sub-task D: `MyDataCubit.pickAndImport()` with injectable pick/confirm/refresh; `AppScaffold` wires Today + History + My Data refresh.
- Sub-task E: `DataImportButton` (secondary), My Data screen listeners/banners/snackbar.
- Sub-task F: `file_picker ^12.0.0-beta.5`, `docs/DEPENDENCIES.md`; `flutter test` (397) + `flutter analyze` (info/warnings only).

### File List

- lib/data/csv/timeseries_csv_codec.dart
- lib/data/csv/import_validation_exception.dart
- lib/data/models/import_result.dart
- lib/data/repositories/step_repository.dart
- lib/presentation/cubits/my_data_state.dart
- lib/presentation/cubits/my_data_cubit.dart
- lib/presentation/screens/app_scaffold.dart
- lib/presentation/screens/my_data_screen.dart
- lib/presentation/widgets/confirm_dialog.dart
- lib/presentation/widgets/data_import_button.dart
- pubspec.yaml
- docs/DEPENDENCIES.md
- test/data/csv/timeseries_csv_codec_test.dart
- test/data/repositories/step_repository_import_test.dart
- test/presentation/cubits/my_data_cubit_import_test.dart
- test/presentation/widgets/confirm_dialog_test.dart
- test/presentation/screens/my_data_screen_test.dart

## Change Log

- 2026-06-03: Story 4.4 created — CSV import context engine analysis complete
- 2026-06-03: Story 4.4 implemented — CSV import pipeline, My Data UI, tests green (397)
