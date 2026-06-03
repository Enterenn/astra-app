# Story 4.5: Full Data Purge with Export Nudge

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want to delete all local health data with a safety prompt,
So that I can wipe my history while keeping my preferences.

## Acceptance Criteria

1. **Given** user taps "Delete all local data"
   **When** `ConfirmDialog` appears
   **Then** copy mentions export option with **Export first** / **Delete anyway** / **Cancel** (FR21, UX-DR15)
   **And** Export first triggers export flow **without closing the dialog**

2. **Given** user confirms delete
   **When** purge executes in a single repository-owned transaction
   **Then** all `timeseries_samples` and derived collection state are removed (FR20)
   **And** `daily_step_goal`, `theme_mode`, `display_name` (if set), `onboarding_complete`, and permission-related runtime state persist (D-11)

3. **Given** purge completes
   **When** user views Today / History / My Data
   **Then** empty states show 0 samples / ~0 KB; goal row unchanged; Today greeting unchanged if display name was set; no re-onboarding

4. **Given** a prior export exists on disk
   **When** user completes export → purge → import round-trip (manual or test)
   **Then** chart-visible history is restored (FR30 beta path — first full round-trip including purge)

## Tasks / Subtasks

- [x] **Sub-task A — `StepRepository.purge()` + derived-state contract** (AC: #2)
  - [x] Add `Future<void> purge()` on `lib/data/repositories/step_repository.dart`:
    - Single `db.transaction()` (D-24)
    - `DELETE FROM timeseries_samples`
    - Clear **derived collection state** in `user_preferences`:
      - All keys matching `ingestion_baseline/%` (via `DELETE ... WHERE key LIKE 'ingestion_baseline/%'`)
      - `celebration_shown_date`, `ingestion_collect_lock`, `last_database_optimized_at`
    - **Preserve allowlist** (do not delete): `daily_step_goal`, `theme_mode`, `onboarding_complete`, and any future non-health keys (`display_name`, etc.) — use explicit delete list / prefix rules, not `DELETE FROM user_preferences` wholesale
  - [x] Add `lib/data/repositories/ingestion_baseline_repository.dart` helper if useful: `Future<void> clearAllBaselines(Transaction txn)` — keeps purge SQL in one place
  - [x] Unit tests: `test/data/repositories/step_repository_purge_test.dart`:
    - Inject samples + baselines + celebration + last_optimized → purge → sample count 0, baselines gone, preserved goal/theme/onboarding
    - Transaction rollback on forced error mid-purge (DB unchanged)
    - Export → purge → import round-trip restores `getChartDailyAggregates` totals (reuse import/export helpers from 4.3/4.4 tests)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — `ConfirmDialog` purge variant + `AstraButtonVariant.danger`** (AC: #1, UX-DR15/17)
  - [x] Extend `lib/presentation/widgets/astra_button.dart` with `AstraButtonVariant.danger` (filled `colors.statusDanger`, inverse label) — min height 48dp
  - [x] Extend `lib/presentation/widgets/confirm_dialog.dart`:
    - `showPurgeConfirmDialog(BuildContext context, {required VoidCallback onExportFirst})`
    - Title: `"Delete all local data?"`
    - Body: UX §3.11 copy (export nudge, removes step history on device)
    - Actions: **Export first** (secondary) · **Delete anyway** (danger) · **Cancel** (ghost)
    - Return enum or sealed result: `cancelled` | `exportFirst` | `deleteConfirmed` — dialog stays open on Export first; parent runs export then user can still Delete anyway or Cancel
  - [x] Widget tests: `test/presentation/widgets/confirm_dialog_purge_test.dart` — three actions visible; Export first does not pop route; Delete anyway returns confirm
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — `MyDataCubit` purge orchestration + live overlay reset** (AC: #1–#3)
  - [x] Extend `MyDataState`: `bool isPurging` (default false), `String? purgeErrorMessage`
  - [x] Add injectable callbacks (mirror export/import):
    - `typedef ConfirmPurgeCallback = Future<PurgeConfirmAction> Function();`
    - `typedef PostPurgeRefreshCallback = Future<void> Function();`
  - [x] Add `Future<void> confirmAndPurge({ConfirmPurgeCallback? confirmPurge})`:
    1. In-flight guard: block if `isPurging`, `isExporting`, or `isImporting`
    2. `confirmPurge()` → cancel = no-op
    3. `exportFirst` → call existing `exportAndShare()` (dialog already handled export-first tap in screen layer — cubit receives action from callback)
    4. `deleteConfirmed` → emit `isPurging: true`, clear errors
    5. `await stepRepository.purge()`
    6. `await postPurgeRefresh()` then `refresh(silent: true)`
    7. Emit success flag for snackbar (mirror `importSuccessPending` pattern)
  - [x] Wire `AppScaffold` `postPurgeRefresh` (same file as `postImportRefresh`):
    ```dart
    postPurgeRefresh: () async {
      await widget.deps.liveStepMonitor.reconcileFromDatabase();
      await _todayCubit.refresh(silent: true);
      await _todayCubit.syncSteps(widget.deps.liveStepMonitor.currentTodaySteps);
      await _todayCubit.refreshMetadata();
      await _historyCubit.refresh(silent: true);
      await _myDataCubit.refresh(silent: true);
      unawaited(widget.deps.dataLifecycleService.runMaintenance(force: true));
    },
    ```
    **Critical:** Purge without `LiveStepMonitor.reconcileFromDatabase()` leaves a non-zero live overlay (Story 2.9 truth model violation).
  - [x] Cubit tests: in-flight guards; purge calls repository; refresh callback invoked; export-first does not call purge
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — My Data purge button + UI feedback** (AC: #1, #3, UX §3.11)
  - [x] Add `lib/presentation/widgets/data_purge_button.dart` — danger **text** button (UX §3.5: not filled; danger fill only inside dialog)
    - Label: `Delete all local data`
    - Semantics: `"Delete all local health data"`
    - `isLoading` when `state.isPurging`
  - [x] Update `MyDataScreen` Your data section: Export → Import → Purge (stacked, `kSpaceSm` gaps)
  - [x] Screen wires purge dialog:
  - [x] Snackbar: `"All local data removed"` 3s on success (UX §3.11)
  - [x] Purge error → `StatusBanner` + retry
  - [x] Disable all three data actions while any of export/import/purge in flight
  - [x] Widget tests: purge button visible; loading state; snackbar on success
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Integration verification** (AC: #3–#4)
  - [x] Repository round-trip test: inject → export → purge → import → aggregates match
  - [ ] Manual: dev inject → My Data footprint N > 0 → export → purge → 0 samples → import same file → Today/History show data; goal unchanged; onboarding not shown
  - [ ] Manual: Export first from dialog → share sheet → still in dialog → Delete anyway → empty states
  - [x] Run `flutter test` + `flutter analyze`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 4.5:**
- `StepRepository.purge()` transactional wipe of health data + derived prefs
- Purge confirm dialog with export-first nudge (FR-21)
- My Data **Delete all local data** control + loading/error/success UX
- Post-purge refresh: Today + History + My Data + **LiveStepMonitor reconcile**
- Post-purge `DataLifecycleService.runMaintenance(force: true)` off UI thread (shrink DB file)
- First **export → purge → import** round-trip test (FR-30 / FR-29 precursor)
- `AstraButtonVariant.danger` for dialog only

**Out of scope — defer:**
- Goal editor, theme selector, display name edit UI → **Stories 4.6–4.8**
- Profile initials → **4.9**
- Selective purge by date/source → Phase 1+
- Full app reset (clear onboarding) → Phase 1+
- Permission outcome persistence keys (not in DB today; runtime permission unchanged by purge)

### Pipeline position (Epic 4)

```text
CSV import (4.4) ✅ / review
        │
        v
Full purge + export nudge (4.5)   ← THIS STORY
        │
        v
Goal editor (4.6) → theme (4.7) → display name (4.8) → profile (4.9)
```

### Derived collection state (must clear on purge)

| State | Location | Why derived |
|-------|----------|-------------|
| Step samples | `timeseries_samples` | Health data (FR-20) |
| Ingestion baselines | `user_preferences` keys `ingestion_baseline/{provider}/{deviceId}` | Counter deltas for collection |
| Celebration dedup | `celebration_shown_date` | Tied to ingested goal progress |
| Collection lock | `ingestion_collect_lock` | Transient ingestion mutex |
| Last optimized | `last_database_optimized_at` | Footprint metadata for empty DB |

`getLastIngestionUtc()` becomes `null` automatically when samples are gone (MAX query).

### Preserved setup preferences (D-11 — locked)

| Key | Preserved |
|-----|-----------|
| `daily_step_goal` | Yes |
| `theme_mode` | Yes |
| `onboarding_complete` | Yes |
| `display_name` | Yes (when Story 4.8 adds it — purge must not break forward compat) |
| `ingestion_baseline/*` | **No** — cleared |
| `celebration_shown_date` | **No** — cleared (fresh celebration eligibility after new data) |

### Architecture contracts

| Decision / FR | Requirement for 4.5 |
|---------------|---------------------|
| FR-20 | Full health-data purge; explicit confirmation; 0 samples after |
| FR-21 | Export-first nudge non-blocking; dialog stays open |
| D-24 | `purge()` owns single transaction |
| D-03 | Purge via `StepRepository`; cubit orchestrates only |
| D-11 | Retain non-health setup prefs |
| Cubit refresh table | Post purge: Today `refresh` + `syncSteps` + `refreshMetadata`, History, My Data |
| VACUUM | `runMaintenance(force: true)` after purge — isolate offload on device (architecture §VACUUM) |
| Story 2.9 | Reconcile live monitor after purge — never show stale non-zero overlay |

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 4.5 changes | Must preserve |
|------|---------------|------------------|---------------|
| `step_repository.dart` | `exportCsv`, `importCsv`, `importSamples` | Add `purge()` | All import/export/ingestion paths |
| `confirm_dialog.dart` | Import variant only | Add purge variant + danger button usage | Import dialog copy/behavior |
| `astra_button.dart` | primary, secondary, ghost | Add `danger` variant | Onboarding buttons |
| `my_data_cubit.dart` | export + import flows | Add `confirmAndPurge`, purge flags | Export/import in-flight guards |
| `my_data_state.dart` | import/export flags | Add `isPurging`, purge error/success | `copyWith` recovery pattern |
| `my_data_screen.dart` | Export + Import only | Add purge button + listeners | Section layout, banners |
| `app_scaffold.dart` | `postImportRefresh` wired | Add `postPurgeRefresh` + lifecycle maintenance | Tab cubits, ingestion callback |
| `ingestion_baseline_repository.dart` | per-source baselines | Used by purge clear | get/set baseline API |

### Recommended file layout

```text
lib/data/repositories/step_repository.dart              # UPDATE — purge()
lib/presentation/widgets/astra_button.dart              # UPDATE — danger variant
lib/presentation/widgets/confirm_dialog.dart            # UPDATE — purge dialog
lib/presentation/widgets/data_purge_button.dart           # NEW
lib/presentation/cubits/my_data_state.dart              # UPDATE
lib/presentation/cubits/my_data_cubit.dart                # UPDATE
lib/presentation/screens/my_data_screen.dart            # UPDATE
lib/presentation/screens/app_scaffold.dart              # UPDATE — postPurgeRefresh

test/data/repositories/step_repository_purge_test.dart  # NEW
test/data/repositories/step_repository_roundtrip_purge_test.dart  # NEW (or merge)
test/presentation/widgets/confirm_dialog_purge_test.dart # NEW
test/presentation/cubits/my_data_cubit_purge_test.dart  # NEW
test/presentation/screens/my_data_screen_test.dart      # UPDATE
```

### Purge flow (sequence)

```text
User taps Delete all local data
    → showPurgeConfirmDialog
         ├─ Export first → MyDataCubit.exportAndShare() (dialog stays)
         ├─ Cancel → end
         └─ Delete anyway → MyDataCubit.confirmAndPurge()
              → StepRepository.purge()  // transaction
              → postPurgeRefresh():
                    LiveStepMonitor.reconcileFromDatabase()
                    Today.refresh + syncSteps + refreshMetadata
                    History.refresh(silent)
                    MyData.refresh(silent)
                    dataLifecycleService.runMaintenance(force: true)  // unawaited OK
              → SnackBar "All local data removed"
```

### UX compliance (UX §3.5, §3.11, UX-DR14/15/17)

| Element | Spec |
|---------|------|
| Purge list button | Danger **text** style (not filled) |
| Confirm **Delete anyway** | `AstraButtonVariant.danger` |
| Export first | Secondary; triggers export without closing dialog |
| Cancel | Ghost |
| Loading | Spinner on purge button; disable export/import/purge |
| Success snackbar | `"All local data removed"` 3s |
| Error | `StatusBanner` + retry |
| Placement | Your data: Export → Import → Purge (bottom) |

### Purge transaction sketch

```dart
await db.transaction((txn) async {
  await txn.delete('timeseries_samples');
  await txn.delete(
    'user_preferences',
    where: "key LIKE 'ingestion_baseline/%'",
  );
  for (final key in [
    kCelebrationShownDateKey,
    kIngestionCollectLockKey,
    kLastDatabaseOptimizedAtKey,
  ]) {
    await txn.delete(
      'user_preferences',
      where: 'key = ?',
      whereArgs: [key],
    );
  }
});
```

Run VACUUM **outside** this transaction via `DataLifecycleService` (second connection / isolate), per architecture.

### Anti-patterns (do NOT)

- `DELETE FROM user_preferences` without allowlist (would wipe goal/theme/onboarding)
- Purge from cubit/widget via raw SQL
- Skip `LiveStepMonitor.reconcileFromDatabase()` after purge
- Close purge dialog on Export first
- Block export with modal loop — export-first is optional nudge only
- Call `purge()` from `importCsv()` (4.4 merge-only import)
- Run `VACUUM` on UI isolate main connection during purge transaction
- Re-show onboarding when `onboarding_complete` is still true
- Use accent-outline style for purge list button (export-only)

### Previous story intelligence (Story 4.4 — immediate predecessor)

**Reuse directly:**
- `MyDataCubit` injectable callback pattern (`postImportRefresh` → mirror as `postPurgeRefresh`)
- `AppScaffold` wiring location for cross-cubit refresh
- `confirm_dialog.dart` module — add purge alongside import
- In-flight mutex pattern (`_importInFlight` → `_purgeInFlight`)
- `StatusBanner` + snackbar listener patterns on `MyDataScreen`
- `StepRepository.importCsv` / `exportCsv` for round-trip test
- Review discipline: sub-task commits, preserve flags across `refresh()` via `copyWith` in `_emitReadySnapshot`

**4.4 explicitly deferred to 4.5:** purge UI, `purge()`, purge dialog, export→purge→import beta path.

**4.3/4.2 notes:** Footprint KPIs read from `getFootprint` — after purge must show 0 / ~0 KB; `refresh(silent: true)` already used after admin ops.

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `bde6f82` | CSV import + file_picker — round-trip test builds on import codec |
| `324b0d1` / `f3fb915` | My Data import UI — stack purge below import |
| `394673c` | Confirm dialog — extend same file for purge variant |
| `077b1ac` | `importCsv` transaction pattern — mirror for `purge()` |

### Library / framework notes

- No new dependencies for 4.5
- `sqflite` transaction + `DELETE` only — no schema migration
- `DataLifecycleService.runMaintenance(force: true)` already supports isolate offload on Android/iOS file DB

### Testing requirements

| Test | Purpose |
|------|---------|
| `step_repository_purge_test` | Wipe samples + derived prefs; preserve setup keys |
| Round-trip purge test | export → purge → import → chart aggregates |
| `confirm_dialog_purge_test` | FR-21 three-action dialog |
| `my_data_cubit_purge_test` | Guards, callbacks, error paths |
| `my_data_screen_test` | Purge button + snackbar |
| Manual | Export-first path; goal retained; Today empty ring |

### Handoff for Story 4.8

When `display_name` lands in `user_preferences`, purge allowlist must include that key. Add assertion in purge test if key exists by then.

### Project context reference

- Review-before-commit: `docs/project-context.md` — one sub-task per commit, French review brief, wait for Baptiste OK
- `user_skill_level: intermediate` — explain transactions, derived vs setup prefs, live overlay reconcile in review brief

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 4.5, FR20–21, D-11]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — purge admin write, cubit refresh, VACUUM, transaction boundaries]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` — FR-20, FR-21, §1.4 purge semantics]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §3.11 Purge flow, §2.2 AstraButton danger]
- [Source: `_bmad-output/implementation-artifacts/stories/4-4-csv-import.md` — deferred purge scope, refresh wiring]
- [Source: `lib/data/repositories/step_repository.dart`]
- [Source: `lib/core/constants/preference_keys.dart`]
- [Source: `lib/data/repositories/ingestion_baseline_repository.dart`]
- [Source: `lib/core/services/live_step_monitor.dart` — reconcile after purge]
- [Source: `lib/presentation/screens/app_scaffold.dart` — postImportRefresh pattern]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- Sub-task A: `StepRepository.purge()` in single transaction — deletes all samples, clears ingestion baselines + celebration/lock/optimized keys; preserves goal/theme/onboarding. 3 unit tests pass including rollback and export→purge→import round-trip.
- Sub-task B: `AstraButtonVariant.danger` + `showPurgeConfirmDialog` with export-first nudge (dialog stays open on export). 3 widget tests pass.
- Sub-task C: `MyDataCubit.confirmAndPurge` with in-flight guards, `postPurgeRefresh` wired in AppScaffold (LiveStepMonitor reconcile + Today sync + maintenance). 5 cubit tests pass.
- Sub-task D: `DataPurgeButton` + My Data screen wiring (snackbar, error banner, mutual disable). 4 widget tests added.
- Sub-task E: Full suite 417 tests pass; analyze clean (pre-existing infos only). Manual verification steps documented below for Baptiste on device.
- Code review: allow delete-confirmed purge while export in flight (FR-21); emit success only after post-purge refresh; distinct refresh-failure message; 25 purge-related tests pass.

### File List

- `lib/data/repositories/step_repository.dart` — added `purge()`
- `lib/data/repositories/ingestion_baseline_repository.dart` — added `clearAllBaselines(Transaction txn)`
- `lib/presentation/widgets/astra_button.dart` — added `danger` variant
- `lib/presentation/widgets/confirm_dialog.dart` — added `PurgeConfirmAction` + `showPurgeConfirmDialog`
- `lib/presentation/widgets/data_purge_button.dart` — new
- `lib/presentation/cubits/my_data_state.dart` — purge flags
- `lib/presentation/cubits/my_data_cubit.dart` — `confirmAndPurge`, `postPurgeRefresh`
- `lib/presentation/screens/my_data_screen.dart` — purge button + dialog + snackbar
- `lib/presentation/screens/app_scaffold.dart` — `postPurgeRefresh` wiring
- `test/data/repositories/step_repository_purge_test.dart` — new
- `test/presentation/widgets/confirm_dialog_purge_test.dart` — new
- `test/presentation/cubits/my_data_cubit_purge_test.dart` — new
- `test/presentation/screens/my_data_screen_test.dart` — purge UI tests
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — story status
- `_bmad-output/implementation-artifacts/stories/4-5-full-data-purge-with-export-nudge.md` — story tracking

## Change Log

- 2026-06-03: Story 4.5 created — full data purge context engine analysis complete
- 2026-06-03: Story 4.5 implementation complete — purge repository, confirm dialog, cubit orchestration, My Data UI, 417 tests pass
- 2026-06-03: Code review fixes — export-first delete path, refresh ordering, test stability; story done
