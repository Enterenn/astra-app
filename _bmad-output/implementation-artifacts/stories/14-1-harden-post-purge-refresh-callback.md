# Story 14.1: Harden postPurgeRefresh Callback

Status: review

<!-- Refacto Epic 14 — branch `refacto` only until merge review -->
<!-- Source: epics-refacto.md Story 14-1 · refactoring-audit-master-v0.6.1.md §1.2b -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **user**,
I want data purge to either fully refresh my dashboards or show a clear error,
So that I never see stale or inconsistent step counts after deleting my data.

## Acceptance Criteria

1. **Given** user completes a full data purge from My Data  
   **When** `postPurgeRefresh` runs in `AppScaffold`  
   **Then** all eight async steps execute inside a single guarded flow with explicit error handling (REF-01, NFR-REF-02)  
   **And** steps run in this exact order:
   1. `userPreferences.clearLastDisplayedSteps()`
   2. `liveStepMonitor.reconcileFromDatabase()`
   3. `_todayCubit.refresh(silent: true)`
   4. `_todayCubit.syncSteps(liveStepMonitor.currentTodaySteps)`
   5. `_todayCubit.refreshMetadata()`
   6. `_historyCubit.refresh(silent: true)`
   7. `_myDataCubit.refresh(silent: true)`
   8. `dataLifecycleService.runMaintenance(force: true)` — keep `unawaited` fire-and-forget semantics

2. **Given** any awaited step in `postPurgeRefresh` throws  
   **When** the exception is caught  
   **Then** error and stack trace are logged (`kDebugMode` + `debugPrint` / `debugPrintStack` — match `MyDataCubit` pattern)  
   **And** the exception is **rethrown** so `MyDataCubit.confirmAndPurge` surfaces the existing user-facing error (`purgeErrorMessage` + `StatusBanner` on My Data)  
   **And** the failure is not silent — log message must name which phase failed (e.g. `postPurgeRefresh failed at reconcileFromDatabase`)

3. **Given** `postPurgeRefresh` is in progress  
   **When** user navigates away and `_AppScaffoldState` unmounts mid-await  
   **Then** `if (!mounted) return` guards after each `await` prevent further cubit/deps calls  
   **And** no `StateError` from calling into a disposed scaffold state

4. **Given** existing purge cubit and screen tests  
   **When** this story ships  
   **Then** `my_data_cubit_purge_test.dart` still passes (refresh-failure path unchanged)  
   **And** new coverage proves hardened callback behaviour (see Testing Requirements)

5. **Given** work completes on branch `refacto`  
   **When** story is marked done  
   **Then** **no version bump** yet — Epic 14 closes with patch+1 per `epics-refacto.md`

**Covers:** REF-01 · NFR-REF-02 · Audit §1.2b (P0)

## Tasks / Subtasks

- [x] **Sub-task A — Extract and harden `postPurgeRefresh`** (AC: #1–#3)
  - [x] In `lib/presentation/screens/app_scaffold.dart`, replace inline `postPurgeRefresh` lambda with a private method e.g. `_runPostPurgeRefresh()` on `_AppScaffoldState`
  - [x] Wrap awaited steps in `try/catch` with `catch (error, stackTrace)` logging; **rethrow** after log so `MyDataCubit` error UX remains authoritative
  - [x] Insert `if (!mounted) return` after every `await` before subsequent cubit/deps calls
  - [x] Keep step order identical to current production code (8 steps — audit corrected count from 6)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Regression tests for hardened callback** (AC: #4)
  - [x] Extend `test/presentation/screens/app_scaffold_test.dart` (or add focused helper test file) with injectable `createMyDataCubit` / mock `LiveStepMonitor` that throws on `reconcileFromDatabase`
  - [x] Assert: purge via `MyDataCubit.confirmAndPurge` → `purgeErrorMessage` set (existing copy) when refresh callback fails
  - [x] Assert: success path still runs all refresh steps when mocks succeed (spy/mock call counts on Today/History cubits or monitor reconcile)
  - [x] Optional: mounted guard — dispose scaffold mid-callback via test hook; verify no throw (if harness supports cleanly)
  - [x] Run `flutter analyze` + `flutter test test/presentation/screens/app_scaffold_test.dart test/presentation/cubits/my_data_cubit_purge_test.dart`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| `postPurgeRefresh` try/catch, logging, mounted guards in `AppScaffold` | Story 14-2 lifecycle deadlock (`lib/app.dart`) |
| Preserve exact 8-step refresh sequence + `unawaited` maintenance | GoalRing persistence move (Story 15-2) |
| Tests for hardened callback | Changing `MyDataCubit.confirmAndPurge` orchestration |
| Branch `refacto` only | Version bump (deferred to Epic 14 close) |

### Current code — MUST READ before editing

`postPurgeRefresh` today (lines 106–117) — **no guards, no try/catch**:

```106:117:lib/presentation/screens/app_scaffold.dart
          postPurgeRefresh: () async {
            await widget.deps.userPreferences.clearLastDisplayedSteps();
            await widget.deps.liveStepMonitor.reconcileFromDatabase();
            await _todayCubit.refresh(silent: true);
            await _todayCubit.syncSteps(
              widget.deps.liveStepMonitor.currentTodaySteps,
            );
            await _todayCubit.refreshMetadata();
            await _historyCubit.refresh(silent: true);
            await _myDataCubit.refresh(silent: true);
            unawaited(widget.deps.dataLifecycleService.runMaintenance(force: true));
          },
```

**Failure mode (P0):** If step 2 (`reconcileFromDatabase`) throws, steps 3–7 never run — UI shows partial stale state with no user signal. Purge transaction already committed; user thinks data is gone but Today may still show old overlay counts.

**Evolution since Story 4.5:** `clearLastDisplayedSteps()` was added (Story 5.13 review patch). Do not remove it — prevents GoalRing showing pre-purge cached display steps.

### Error UX — do not duplicate snackbars

`MyDataCubit` already handles `postPurgeRefresh` failures:

```412:427:lib/presentation/cubits/my_data_cubit.dart
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('MyDataCubit.confirmAndPurge failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      // ...
      emit(
        state.copyWith(
          isPurging: false,
          purgeErrorMessage: purged
              ? 'All local data was removed, but the app could not refresh. Try again.'
              : 'Purge could not be completed. Try again.',
        ),
      );
```

`MyDataScreen` renders `purgeErrorMessage` via `StatusBanner` (error variant, tappable retry). AC "snackbar **or equivalent**" — **StatusBanner satisfies this**. Do **not** add a second snackbar in `AppScaffold` unless Baptiste requests it in review; log + rethrow is the correct pattern.

### Recommended implementation shape

```dart
Future<void> _runPostPurgeRefresh() async {
  try {
    await widget.deps.userPreferences.clearLastDisplayedSteps();
    if (!mounted) return;

    await widget.deps.liveStepMonitor.reconcileFromDatabase();
    if (!mounted) return;

    await _todayCubit.refresh(silent: true);
    if (!mounted) return;

    await _todayCubit.syncSteps(
      widget.deps.liveStepMonitor.currentTodaySteps,
    );
    if (!mounted) return;

    await _todayCubit.refreshMetadata();
    if (!mounted) return;

    await _historyCubit.refresh(silent: true);
    if (!mounted) return;

    await _myDataCubit.refresh(silent: true);
    if (!mounted) return;

    unawaited(widget.deps.dataLifecycleService.runMaintenance(force: true));
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('AppScaffold.postPurgeRefresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    rethrow;
  }
}
```

Wire: `postPurgeRefresh: _runPostPurgeRefresh` (tear-off) or `() => _runPostPurgeRefresh()`.

**Do not** wrap `runMaintenance` in `await` — Story 4.5 intentionally fire-and-forgets DB shrink off the UI path.

### Cross-story context (Epic 14)

| Story | Focus | Dependency |
|-------|-------|------------|
| **14-1** (this) | `postPurgeRefresh` guards | None — first refacto story |
| 14-2 | `_enqueueLifecycleTransition` finally | Independent file (`lib/app.dart`) |

Epic 14 version bump: `0.6.1+12` → `0.6.2+13` (patch+1) when **both** stories done.

### Architecture compliance

- **Presentation orchestrates, cubits own state** — `AppScaffold` is the correct place for cross-tab refresh wiring (established in Stories 4.5, 10.1)
- **NFR-REF-02** — async flows must not fail silently; logging + propagated error required
- **Review-before-commit** — one commit per sub-task; review brief per `docs/project-context.md`
- **No new dependencies** — use existing `foundation.dart` debug logging only
- **Do not edit** `MyDataCubit`, `StepRepository.purge()`, or purge dialog UX unless a test proves a gap

### File structure requirements

```
lib/presentation/screens/app_scaffold.dart     # UPDATE — extract _runPostPurgeRefresh
test/presentation/screens/app_scaffold_test.dart  # UPDATE — post-purge refresh tests
```

No new production files expected. No `pubspec.yaml` / `docs/DEPENDENCIES.md` changes.

### Testing requirements

| Test | Purpose |
|------|---------|
| `my_data_cubit_purge_test.dart` — `sets refresh error when purge succeeds but postPurgeRefresh fails` | Regression — must still pass |
| New `app_scaffold_test` case(s) | Verify real wired callback propagates failure to cubit state |
| `flutter analyze` | Zero new issues |

**Test harness notes:**
- `AppScaffold` accepts `createTodayCubit`, `createHistoryCubit`, `createMyDataCubit` — use real `MyDataCubit` with `AppDependencies.test()` for integration-style test
- `AppDependencies.test()` accepts optional `liveStepMonitor` — inject a `_ThrowingReconcileMonitor extends LiveStepMonitor` that throws on `reconcileFromDatabase()`
- Existing `_pumpAppScaffold` + `_disposeScaffold` patterns in `app_scaffold_test.dart` — follow same structure
- `GoalRing.disableStepPersistence = true` in setUp — keep for test stability

### Manual verification (review brief)

1. Dev inject sample data → My Data → Delete all local data → confirm empty Today/History/My Data
2. Simulate failure (temporary `throw` in reconcile) → purge completes → StatusBanner shows refresh error on My Data; logs visible in debug console
3. Retry from banner → refresh succeeds when failure removed

### References

- [Source: `_bmad-output/planning-artifacts/epics-refacto.md` — Epic 14, Story 14-1]
- [Source: `_bmad-output/planning-artifacts/refactoring-audit-master-v0.6.1.md` — §1.2b postPurgeRefresh]
- [Source: `_bmad-output/implementation-artifacts/stories/4-5-full-data-purge-with-export-nudge.md` — original postPurgeRefresh wiring]
- [Source: `_bmad-output/implementation-artifacts/stories/5-13-goal-overflow-animation-polish.md` — clearLastDisplayedSteps in purge path]
- [Source: `docs/project-context.md` — review-before-commit workflow]
- [Source: `.cursor/rules/app-versioning.mdc` — bump at epic close only]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Failure test logs phase name: `AppScaffold.postPurgeRefresh failed at todayRefresh: ...`

### Completion Notes List

- Extracted `_runPostPurgeRefresh()` with 8-step sequence, `if (!mounted) return` after each await, and phase-labelled `try/catch` + rethrow.
- Added widget tests: failure path propagates to `purgeErrorMessage`; success path verifies Today/History refresh + `syncSteps` call counts via wired scaffold callback.
- `flutter analyze` clean; `app_scaffold_test.dart` (10 tests) + `my_data_cubit_purge_test.dart` (8 tests) all pass.
- No version bump (deferred to Epic 14 close per AC #5).

### File List

- `lib/presentation/screens/app_scaffold.dart`
- `test/presentation/screens/app_scaffold_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status-refacto.yaml`

### Change Log

- 2026-06-18: Hardened `postPurgeRefresh` with guarded flow, phase logging, mounted checks; added regression widget tests.
