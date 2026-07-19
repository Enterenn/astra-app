# Story 25.4: Decouple MyDataCubit from UI Dialog Types

Status: review

<!-- Post-audit Epic 25 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 25-4 · diagnostic-convention-structure.md §3.2 · AUD-47 -->
<!-- Prerequisite: Stories 25-1, 25-2, 25-3 done -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **developer**,
I want MyDataCubit free of UI dialog enums and FilePicker defaults,
So that data lifecycle logic can be tested without presentation widgets or platform pickers embedded in the cubit.

## Acceptance Criteria

1. **Given** `lib/presentation/cubits/my_data_cubit.dart` line 19 imports `../widgets/confirm_dialog.dart` for `PurgeConfirmAction`
   **When** this story ships
   **Then** `my_data_cubit.dart` has **zero** imports from `lib/presentation/widgets/` (AUD-47)
   **And** `PurgeConfirmAction` lives in `lib/core/constants/purge_confirm_action.dart` (pure Dart enum — no Flutter dependency)
   **And** `confirm_dialog.dart` imports the core enum and optionally re-exports it so presentation call sites need minimal diff

2. **Given** `my_data_cubit.dart` lines 7, 92–110 embed `FilePicker.pickFile` / `FilePicker.saveFile` as `_defaultPickCsvFile` / `_defaultSaveCsvFile`
   **When** this story ships
   **Then** `my_data_cubit.dart` has **zero** `file_picker` import and **no** static FilePicker defaults
   **And** platform picker logic lives in `lib/data/csv/` (e.g. `csv_platform_file_picker.dart`) — data layer owns I/O adapters
   **And** `pickCsvFile` and `saveCsvFile` are **required** constructor parameters (no silent UI fallback inside cubit)
   **And** `AppScaffold` wires production implementations when constructing `MyDataCubit`

3. **Given** existing My Data user flows (export CSV, import CSV, purge with export-first nudge, error-banner retry purge)
   **When** manual smoke or widget tests run
   **Then** behaviour is user-invisible — same dialogs, snackbars, loading flags, and purge/export/import semantics (FR-20/21, UX §3.11)

4. **Given** existing test suites
   **When** `dart analyze` and `flutter test --exclude-tags slow` run
   **Then** all pass with zero behavioural regressions
   **And** targeted suites green:
   - `flutter test test/presentation/cubits/my_data_cubit_test.dart`
   - `flutter test test/presentation/cubits/my_data_cubit_export_test.dart`
   - `flutter test test/presentation/cubits/my_data_cubit_import_test.dart`
   - `flutter test test/presentation/cubits/my_data_cubit_purge_test.dart`
   - `flutter test test/presentation/widgets/confirm_dialog_test.dart`
   - `flutter test test/presentation/screens/my_data_screen_test.dart`
   - `flutter test test/presentation/screens/app_scaffold_test.dart` (purge/post-purge sections)

5. **Given** OK-commit gate per `docs/project-context.md`
   **When** implementing
   **Then** work is split into reviewable sub-tasks (extract enum → extract FilePicker → rewire composition → verify) with one commit per sub-task after Baptiste approval
   **And** no version bump until Epic 25 closes

**Covers:** AUD-47 · diagnostic-convention-structure.md §3.2 (Moyenne / BLoC)

**Depends on:** Stories 25-1, 25-2, 25-3 **done**. Independent of 25-5 (doc comments).

**Out of scope:** Changing purge/import dialog UX copy, `AppLifecycleCoordinator` → cubit coupling (§3.1), moving `showPurgeConfirmDialog` out of widgets, `ConfirmImportCallback` dialog wiring (already callback-based), version bump, Epic 26 test authoring, adding layer-violation CI lint.

## Tasks / Subtasks

- [x] **Sub-task A — Baseline & move plan** (AC: #1, #2)
  - [x] Confirm violations: `grep confirm_dialog my_data_cubit.dart`, `grep file_picker lib/presentation/cubits/my_data_cubit.dart`
  - [x] Inventory all `PurgeConfirmAction` import sites across `lib/` and `test/` (see Dev Notes table)
  - [x] Inventory all `MyDataCubit(` construction sites — ensure each will receive `pickCsvFile` / `saveCsvFile` after defaults removed
  - [x] Read `lib/core/constants/astra_theme_preference.dart` (25-3 precedent) and story 17-1 notes on `_defaultSaveCsvFile` API
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (plan-only commit optional)

- [x] **Sub-task B — Extract `PurgeConfirmAction` to core** (AC: #1, #3)
  - [x] Create `lib/core/constants/purge_confirm_action.dart`:
    ```dart
    enum PurgeConfirmAction { cancelled, exportFirst, deleteConfirmed }
    ```
  - [x] Update `lib/presentation/widgets/confirm_dialog.dart`: remove enum definition; import from core; **re-export** enum (mirror 25-3 `theme_state.dart` pattern)
  - [x] Update `lib/presentation/cubits/my_data_cubit.dart`: import core enum; remove `confirm_dialog.dart` import
  - [x] Verify `grep confirm_dialog lib/presentation/cubits/my_data_cubit.dart` → empty
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Extract FilePicker adapter & rewire composition** (AC: #2, #3)
  - [x] Create `lib/data/csv/csv_platform_file_picker.dart` with top-level functions matching existing default behaviour:
    - `Future<String?> pickCsvFileForImport()` — `FilePicker.pickFile(type: custom, allowedExtensions: ['csv'])` → path or null
    - `Future<bool> saveCsvExportFile(String filePath)` — read bytes, `FilePicker.saveFile(dialogTitle: 'Save CSV export', fileName: basename, bytes, …)` → savedPath != null
  - [x] Move `PickCsvFileCallback` / `SaveCsvFileCallback` typedefs to the new data file **or** keep in cubit but import enum only from core — prefer keeping typedefs adjacent to cubit if they reference no UI types
  - [x] `my_data_cubit.dart`: delete `_defaultPickCsvFile`, `_defaultSaveCsvFile`, `file_picker` import; make `pickCsvFile` and `saveCsvFile` **required** named params
  - [x] `lib/presentation/screens/app_scaffold.dart`: pass `pickCsvFile: pickCsvFileForImport, saveCsvFile: saveCsvExportFile` (or tear-offs) on `MyDataCubit(...)` construction (~L97)
  - [x] Update every test `buildCubit` / fake cubit factory missing these params — use stubs:
    - refresh-only: `pickCsvFile: () async => null, saveCsvFile: (_) async => false`
    - export/purge tests: keep existing mocks
  - [x] Grep `MyDataCubit(` in `test/` — zero constructions without both callbacks
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Regression verification** (AC: #4, #5)
  - [x] Run `dart analyze`
  - [x] Run targeted tests listed in AC #4
  - [x] Run `flutter test --exclude-tags slow` (expect ~947+ passing — same bar as 25-3)
  - [x] Optional manual smoke: My Data → Export → Import → Purge (export-first + delete anyway + cancel)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Remove `confirm_dialog.dart` import from `MyDataCubit` | Move `showPurgeConfirmDialog` widget |
| Move `PurgeConfirmAction` enum to `core/constants/` | Change purge dialog copy or buttons |
| Remove FilePicker defaults from cubit; wire at `AppScaffold` | DI registration in `AppDependencies` (scaffold is sufficient composition root for cubit) |
| Create `data/csv/` platform file picker adapter | Doc comments on core/data classes (25-5) |
| Update test factories with required callbacks | Version bump (Epic 25 close) |

### Root cause (read before editing)

**Layer / convention violation:** `MyDataCubit` imports a presentation widget file solely for a domain enum, and embeds platform FilePicker calls as constructor defaults [Source: diagnostic-convention-structure.md §3.2 L176–177, §1.3 L62].

**Why it happened:** Story 4-5 placed `PurgeConfirmAction` next to `showPurgeConfirmDialog` in `confirm_dialog.dart`. Story 4-4/17-1 added FilePicker defaults inside the cubit for production wiring convenience before callback injection was fully enforced at the composition root.

**What already works (do not rewrite):**
- Import confirmation is already callback-based (`ConfirmImportCallback`) — UI passes `showImportConfirmDialog` from `MyDataScreen` [Source: my_data_screen.dart L221–227].
- Purge flow is split correctly: screen shows dialog → passes `confirmedAction` or cubit uses `confirmPurge` callback [Source: my_data_screen.dart L261–274, my_data_cubit.dart L328–371].
- Export/import/purge in-flight guards, error enums (`MyDataExportError`, etc.), and post-action refresh callbacks are stable — **mechanical move only**.

### Current state — files to read fully before editing

**`lib/presentation/cubits/my_data_cubit.dart`** (691 LOC):
- **Today:** L7 `file_picker`; L19 `confirm_dialog.dart`; L27–31 callback typedefs; L47–60 optional callbacks with FilePicker defaults L92–110; L328–421 purge uses `PurgeConfirmAction`.
- **Change:** Core enum import; required `pickCsvFile`/`saveCsvFile`; delete static defaults + file_picker import.
- **Preserve:** All emit logic, in-flight coalescing (`_exportInFlight`, etc.), `exportFirst` → `exportAndShare()` branch, error handling, refresh/post-* callbacks.

**`lib/presentation/widgets/confirm_dialog.dart`** (130 LOC):
- **Today:** Defines `PurgeConfirmAction` L10–14; `showPurgeConfirmDialog` returns enum; `showImportConfirmDialog` unchanged.
- **Change:** Enum moves to core; re-export for backward compat.
- **Preserve:** Dialog layout, l10n keys, `onExportFirst` behaviour (export without closing dialog — FR-21).

**`lib/presentation/screens/app_scaffold.dart`** (~L95–116):
- **Today:** Constructs `MyDataCubit` without `pickCsvFile`/`saveCsvFile` (relies on cubit defaults).
- **Change:** Pass data-layer picker functions.
- **Preserve:** `postImportRefresh`, `postPurgeRefresh`, `postGoalUpdate` wiring unchanged.

**`lib/presentation/screens/my_data_screen.dart`**:
- **Today:** Imports `confirm_dialog.dart` for `showPurgeConfirmDialog` + `PurgeConfirmAction`.
- **Change:** Optional — can keep import via re-export; or import core enum directly for clarity.
- **Preserve:** Purge error banner retry passes `confirmedAction: PurgeConfirmAction.deleteConfirmed` (L162) — must still compile.

### Import / construction inventory

| File | `PurgeConfirmAction` | `MyDataCubit(` construction |
|------|---------------------|------------------------------|
| `lib/presentation/cubits/my_data_cubit.dart` | **UPDATE** → core import | N/A |
| `lib/presentation/widgets/confirm_dialog.dart` | **UPDATE** → core + re-export | N/A |
| `lib/presentation/screens/my_data_screen.dart` | via confirm_dialog re-export OK | N/A |
| `lib/presentation/screens/app_scaffold.dart` | — | **UPDATE** — add pick/save callbacks |
| `test/presentation/cubits/my_data_cubit_purge_test.dart` | **UPDATE** → core import | Already has `saveCsvFile` mock |
| `test/presentation/cubits/my_data_cubit_export_test.dart` | — | Already has `saveCsvFile` mock |
| `test/presentation/cubits/my_data_cubit_import_test.dart` | — | Already has `pickCsvFile` mock |
| `test/presentation/cubits/my_data_cubit_test.dart` | — | **UPDATE** — add stub pick/save |
| `test/presentation/screens/my_data_screen_test.dart` | via fake cubit | Check fake implements required params |
| `test/presentation/screens/app_scaffold_test.dart` | confirm_dialog | Check purge integration tests |
| `test/presentation/widgets/confirm_dialog_test.dart` | via confirm_dialog | No change if re-export kept |

### Recommended implementation

**Core enum** (mirror `astra_theme_preference.dart` — zero Flutter deps):

```dart
// lib/core/constants/purge_confirm_action.dart
enum PurgeConfirmAction {
  cancelled,
  exportFirst,
  deleteConfirmed,
}
```

**Data-layer FilePicker adapter** (only place that imports `file_picker` for My Data flows):

```dart
// lib/data/csv/csv_platform_file_picker.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

Future<String?> pickCsvFileForImport() async { /* move from _defaultPickCsvFile verbatim */ }
Future<bool> saveCsvExportFile(String filePath) async { /* move from _defaultSaveCsvFile verbatim */ }
```

**AppScaffold wiring:**

```dart
import '../../data/csv/csv_platform_file_picker.dart';

MyDataCubit(
  // ... existing deps ...
  pickCsvFile: pickCsvFileForImport,
  saveCsvFile: saveCsvExportFile,
  postImportRefresh: () async { /* unchanged */ },
  // ...
)
```

**Do not** move `showPurgeConfirmDialog` to core — it needs `BuildContext`, l10n, and Astra widgets.

**Do not** register pickers on `AppDependencies` unless scaffold wiring proves insufficient — keep scope minimal (scaffold is the cubit factory today).

### Architecture compliance

| Rule | Source | This story |
|------|--------|------------|
| Cubits must not import widgets for shared types | diagnostic §3.2, AUD-47 | Move enum to core |
| FilePicker defaults belong outside cubit | diagnostic §3.2 L176 | Data adapter + scaffold injection |
| Pragmatic 3-layer (core / data / presentation) | architecture.md | Enum in core; I/O adapter in data |
| My Data lifecycle via callbacks | architecture.md FR-20/21, story 4-5 | Preserve callback contracts |
| OK-commit gate, one commit per sub-task | docs/project-context.md | Mandatory |

### File structure requirements

| Path | Action |
|------|--------|
| `lib/core/constants/purge_confirm_action.dart` | **NEW** |
| `lib/data/csv/csv_platform_file_picker.dart` | **NEW** |
| `lib/presentation/cubits/my_data_cubit.dart` | **UPDATE** — core enum, required callbacks, no file_picker |
| `lib/presentation/widgets/confirm_dialog.dart` | **UPDATE** — enum out, re-export |
| `lib/presentation/screens/app_scaffold.dart` | **UPDATE** — wire pick/save |
| `test/presentation/cubits/my_data_cubit_test.dart` | **UPDATE** — stub callbacks in `buildCubit` |
| Other test fakes constructing `MyDataCubit` | **UPDATE** as needed |

### Testing requirements

| Command | When |
|---------|------|
| `dart analyze` | Every sub-task |
| `flutter test test/presentation/cubits/my_data_cubit*.dart` | Sub-task C/D |
| `flutter test test/presentation/widgets/confirm_dialog_test.dart` | Sub-task B |
| `flutter test test/presentation/screens/my_data_screen_test.dart test/presentation/screens/app_scaffold_test.dart` | Sub-task D |
| `flutter test --exclude-tags slow` | Final verification |

**Verification grep (manual):**
```bash
rg "confirm_dialog|file_picker" lib/presentation/cubits/my_data_cubit.dart
# expect: no matches

rg "PurgeConfirmAction" lib/presentation/widgets/confirm_dialog.dart
# expect: import/re-export from core, not enum definition

rg "MyDataCubit\(" lib/ test/ -A 15
# expect: every construction includes pickCsvFile + saveCsvFile
```

No new tests strictly required if full suite passes — behaviour is wiring-only. Optional: unit test `csv_platform_file_picker.dart` with platform channel mocks (low value — covered by cubit + screen tests with injected callbacks).

### Previous story intelligence (25-3, 25-2, 25-1)

- **Mechanical-first:** Extract types/adapters verbatim; no algorithm changes during moves (25-1, 25-2, 25-3 pattern).
- **Re-export precedent:** 25-3 moved `AstraThemePreference` to core and re-exported from `theme_state.dart` — **mirror for `PurgeConfirmAction`** to minimize presentation diff.
- **Regression bar:** 947/947 tests green after 25-3; run full `--exclude-tags slow` before final OK commit.
- **Composition root:** 25-3 fixed `AppDependencies`; this story fixes `AppScaffold` as the MyDataCubit factory — do not expand into unrelated DI refactors.
- **Code review pattern:** Document import/construction inventory in story; ≤4 sub-tasks with OK-commit gate.

### Git intelligence (recent work)

Recent commits (25-3): `Extract AstraThemePreference enum to core constants layer` → `Rewire core/di and data to use core theme preference` — **follow same two-commit split** (enum extract, then wiring). No My Data files touched in 25-3; safe to edit in isolation.

### Latest tech information

- **file_picker** (already in pubspec — Story 17-1): use existing `FilePicker.pickFile` / `FilePicker.saveFile` with `bytes` API — do not change export UX or dialog title string (`'Save CSV export'`).
- **No new packages** — pure refactor / file move.
- **flutter_bloc ^8.x:** `MyDataCubit` public method signatures unchanged except constructor adds required params.
- **Dart 3.x:** Keep existing callback typedef style.

### Project context reference

- OK-commit gate: `docs/project-context.md`
- Test default: `flutter test --exclude-tags slow`
- Version bump: Epic 25 close only (`patch+1`, `build+1`) — update `pubspec.yaml` + `README.md` then, not in this story
- Tracker: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml`

### References

- [Source: _bmad-output/planning-artifacts/epics-post-audit.md#Story 25-4]
- [Source: _bmad-output/planning-artifacts/audits/diagnostic-convention-structure.md §3.2 L172–178, Synthèse L188]
- [Source: lib/presentation/cubits/my_data_cubit.dart L7, L19, L92–110, L328–371]
- [Source: lib/presentation/widgets/confirm_dialog.dart — enum + showPurgeConfirmDialog]
- [Source: lib/presentation/screens/app_scaffold.dart L95–116 — MyDataCubit factory]
- [Source: lib/presentation/screens/my_data_screen.dart L261–274 — purge UI orchestration]
- [Source: _bmad-output/implementation-artifacts/stories/25-3-remove-presentation-dependency-from-core-di-layer.md — re-export pattern]
- [Source: _bmad-output/implementation-artifacts/stories/4-5-full-data-purge-with-export-nudge.md — PurgeConfirmAction origin]
- [Source: _bmad-output/implementation-artifacts/stories/17-1-replace-share-plus-with-file-picker-csv-export.md — saveFile API]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

### Completion Notes List

- Extracted `PurgeConfirmAction` to `lib/core/constants/`; re-exported from `confirm_dialog.dart` (25-3 pattern).
- Moved FilePicker I/O to `lib/data/csv/csv_platform_file_picker.dart`; wired at `AppScaffold`.
- `MyDataCubit`: zero widget/file_picker imports; required `pickCsvFile`/`saveCsvFile` callbacks.
- Regression: 947/947 `flutter test --exclude-tags slow`; dart analyze clean (2 info lints only).

### File List

- `lib/core/constants/purge_confirm_action.dart` (new)
- `lib/data/csv/csv_platform_file_picker.dart` (new)
- `lib/presentation/cubits/my_data_cubit.dart`
- `lib/presentation/widgets/confirm_dialog.dart`
- `lib/presentation/screens/app_scaffold.dart`
- `test/presentation/cubits/my_data_cubit_test.dart`
- `test/presentation/cubits/my_data_cubit_export_test.dart`
- `test/presentation/cubits/my_data_cubit_import_test.dart`
- `test/presentation/cubits/my_data_cubit_purge_test.dart`
- `test/presentation/cubits/my_data_cubit_goal_test.dart`
- `test/presentation/screens/my_data_screen_test.dart`
- `test/widget_test.dart`

### Change Log

- 2026-07-19: Story 25-4 implemented — decouple MyDataCubit from UI dialog types and FilePicker defaults (commit 9c2c6b9).
