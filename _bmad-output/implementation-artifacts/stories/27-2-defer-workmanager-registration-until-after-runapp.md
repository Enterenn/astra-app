# Story 27.2: Defer WorkManager Registration Until After runApp

Status: review

<!-- Post-audit Epic 27 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 27-2 · diagnostic-cold-start.md §Phase D2 · AUD-14 -->
<!-- Prerequisite: Story 27-1 done (parallel pref reads); Epics 21 + 25 done -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want background task registration not to block the first frame,
So that cold start reaches the GoalRing faster.

## Acceptance Criteria

1. **Given** app boot in `main.dart`
   **When** `runApp` is invoked
   **Then** `registerStepCollectionWorkmanager` and `registerDatabaseMaintenanceWorkmanager` are **not** awaited on the critical path before `runApp` (AUD-14, diagnostic-cold-start §D2)
   **And** registration is scheduled post-`runApp` (post-frame callback or equivalent) with the same `databasePath` argument as today

2. **Given** deferred registration runs after first frame
   **When** both registration functions execute
   **Then** call order is preserved: step collection first, then database maintenance (maintenance doc says call after step collection)
   **And** arguments match current boot: `databasePath = join(await getDatabasesPath(), 'astra_app.db')`

3. **Given** registration completes after first frame
   **When** the user interacts with Today immediately
   **Then** foreground live pipeline and Epic 21 fast path still work (WorkManager is reconciliation fallback, not first-frame dependency)

4. **Given** registration throws (plugin init failure, platform error)
   **When** the deferred task completes
   **Then** error is logged via `debugPrint` / `debugPrintStack` (same resilience pattern as `NotificationService` init in `main.dart`)
   **And** the UI isolate does not crash — app remains usable on boot

5. **Given** unit tests
   **When** story verification runs
   **Then** scheduling helper is covered (post-`runApp` path invokes both registrars with correct `databasePath`, errors swallowed)
   **And** existing `workmanager_callback_test.dart` registration tests remain green
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-14 · diagnostic-cold-start.md §Phase D2

**Depends on:** Story 27-1 (parallel pref reads). Independent of 27-3 (notification deferral) and 27-4 (lazy HistoryCubit).

**Out of scope:** Moving `cancelStepCollectionWorkmanager`, `NotificationService.initialize`, or `AppDependencies.create` (27-3); changing WM task definitions/frequencies in `workmanager_callback.dart`; lazy HistoryCubit (27-4); version bump (Epic 27 close → patch+1, build+1).

## Tasks / Subtasks

- [x] **Sub-task A — Extract deferred registration helper** (AC: #1, #2, #4)
  - [x] Read fully: `lib/main.dart`, `lib/core/services/workmanager_callback.dart` (registration + cancel functions)
  - [x] Add `@visibleForTesting` helper in `main.dart` (e.g. `schedulePostRunAppWorkmanagerRegistration`) that:
    - Accepts `String databasePath` and optional injectable registrars for tests
    - Schedules work via `WidgetsBinding.instance.addPostFrameCallback`
    - Inside callback: `unawaited(_registerWorkmanagerTasks(...))` with try/catch logging
  - [x] `_registerWorkmanagerTasks` awaits step collection then maintenance (same as current L34–35)
  - [x] **Do not move** `cancelStepCollectionWorkmanager()` — stays before notification init (race guard, see Dev Notes)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Rewire main() boot order** (AC: #1, #3)
  - [x] Compute `databasePath` before `runApp` (same `join(await getDatabasesPath(), 'astra_app.db')`)
  - [x] Call `runApp(AstraApp(deps: deps))` **before** WM registration
  - [x] Invoke scheduling helper immediately after `runApp`
  - [x] Leave notification init, DI create, and goal-notification migration untouched
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests + regression** (AC: #5)
  - [x] Add `test/main_workmanager_boot_test.dart` (or extend nearest boot test) covering:
    - Scheduling helper calls both registrars with expected `databasePath` when post-frame callback fires
    - Registration failure is caught — no rethrow
  - [x] Run `flutter test test/main_workmanager_boot_test.dart test/core/services/workmanager_callback_test.dart --exclude-tags slow`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Defer `registerStepCollectionWorkmanager` + `registerDatabaseMaintenanceWorkmanager` until after `runApp` | Defer `cancelStepCollectionWorkmanager` (must stay pre-notification) |
| Post-frame scheduling + error swallow on registration | Notification init parallelization (27-3) |
| `@visibleForTesting` boot helper + unit test | Changing WM callback/task logic in `workmanager_callback.dart` |
| Preserve registration order and `databasePath` | Lazy `HistoryCubit` (27-4) |
| OK-commit sub-task gate | Version bump until Epic 27 close |

### Root cause (read before editing)

**Serial pre-`runApp()` WM gate (AUD-14):** `main.dart` awaits two WorkManager registration calls before `runApp`, blocking first frame on plugin init + periodic task registration [Source: `main.dart` L33–36]. WorkManager is **not** needed for first paint — it is Android reconciliation fallback when FGS cannot run (D-04) [Source: `workmanager_callback.dart` L182–185, `architecture.md` §Background].

Diagnostic D2: move registration after `runApp` via post-frame callback [Source: `diagnostic-cold-start.md` §Phase D2, §C5].

Combined with 27-1 (done), D1+D2 remove pre-`runApp()` serial I/O on the boot path toward the <100 ms Today paint target [Source: diagnostic §Priorisation item 6].

### Current boot sequence (MUST understand)

```13:37:lib/main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await cancelStepCollectionWorkmanager();
  final notificationService = NotificationService();
  try {
    await notificationService.initialize().timeout(const Duration(seconds: 3));
  } on TimeoutException catch (error) {
    debugPrint('NotificationService init timed out: $error');
  } catch (error, stackTrace) {
    debugPrint('NotificationService init failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  final deps = await AppDependencies.create(
    notificationService: notificationService,
  );
  await migrateGoalNotificationPreferenceIfNeeded(
    userSettings: deps.userSettings,
    notificationService: notificationService,
  );
  // WM registers regardless of FGS — reconciliation fallback (D-04), not realtime cadence.
  final databasePath = join(await getDatabasesPath(), 'astra_app.db');
  await registerStepCollectionWorkmanager(databasePath: databasePath);
  await registerDatabaseMaintenanceWorkmanager(databasePath: databasePath);
  runApp(AstraApp(deps: deps));
}
```

**Target sequence after this story:**

1. `ensureInitialized` → `cancelStepCollectionWorkmanager` → notification init → DI → migration (unchanged)
2. Compute `databasePath`
3. **`runApp`**
4. Post-frame: deferred WM registration (step collection → maintenance)

### Why cancel stays before notification init

```167:170:lib/core/services/workmanager_callback.dart
/// Cancels any in-flight Android step-collection WM work before UI-isolate init.
///
/// Prevents a background isolate from racing [NotificationService.initialize].
```

Moving cancel would reintroduce the race Story 2.10 hardened. **Only the two `register*` calls move.**

### Registration functions (do not change semantics)

Both live in `workmanager_callback.dart` — call them as-is from the deferred helper:

| Function | Android-only | Notes |
|----------|--------------|-------|
| `registerStepCollectionWorkmanager` | yes (`Platform.isAndroid`) | 15 min periodic; passes `databasePath` in `inputData`; `ExistingPeriodicWorkPolicy.update` when path set |
| `registerDatabaseMaintenanceWorkmanager` | yes | Weekly maintenance; requires `databasePath`; doc: call after step collection |

Each calls `workmanager.initialize(callbackDispatcher)` — idempotent on repeated init. Preserve **step collection before maintenance** order.

Existing unit coverage: `test/core/services/workmanager_callback_test.dart` groups `registerStepCollectionWorkmanager`, `registerDatabaseMaintenanceWorkmanager`, `cancelStepCollectionWorkmanager`. Do not duplicate registrar logic tests — test boot **scheduling** only.

### Recommended implementation pattern

```dart
@visibleForTesting
Future<void> registerWorkmanagerTasksForBoot({
  required String databasePath,
  Future<void> Function({String? databasePath}) registerStepCollection =
      registerStepCollectionWorkmanager,
  Future<void> Function({required String databasePath})
      registerMaintenance = registerDatabaseMaintenanceWorkmanager,
}) async {
  try {
    await registerStepCollection(databasePath: databasePath);
    await registerMaintenance(databasePath: databasePath);
  } catch (error, stackTrace) {
    debugPrint('WorkManager registration failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

void schedulePostRunAppWorkmanagerRegistration(String databasePath) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(registerWorkmanagerTasksForBoot(databasePath: databasePath));
  });
}
```

**Why post-frame (not bare `unawaited` right after `runApp`):** Ensures first frame is scheduled before plugin work runs. Diagnostic explicitly suggests post-frame callback [Source: diagnostic-cold-start §D2].

**Why `unawaited` inside callback:** Matches project convention for fire-and-forget async (`app_live_pipeline_lifecycle_test.dart`, `discarded_futures` lint). Import `dart:async` already present in `main.dart`.

**Testability:** Inject registrar closures in `registerWorkmanagerTasksForBoot` so tests never touch the real Workmanager plugin.

### Architecture compliance

- **D-04:** WorkManager orchestrates reconciliation; FGS + foreground backfill remain primary — deferring registration does not change runtime collection model [Source: `architecture.md` §Background]
- **Isolate entrypoint:** Do not modify `callbackDispatcher` or `@pragma('vm:entry-point')` [Source: `architecture.md` §WorkManager spike]
- **Layering:** Boot orchestration stays in `main.dart`; registration implementation stays in `core/services/workmanager_callback.dart`
- **Error resilience:** Match `NotificationService` init pattern in `main.dart` — log and continue, never crash boot

### File structure requirements

| File | Action |
|------|--------|
| `lib/main.dart` | **UPDATE** — reorder boot; add scheduling + registration helpers |
| `test/main_workmanager_boot_test.dart` | **NEW** — scheduling + error swallow tests |
| `lib/core/services/workmanager_callback.dart` | **DO NOT CHANGE** unless bug found |
| `lib/core/di/app_dependencies.dart` | **DO NOT TOUCH** (27-1 complete) |
| `lib/app.dart` / lifecycle coordinator | **DO NOT TOUCH** — foreground pipeline unchanged |

### Testing requirements

- Default gate: `flutter test --exclude-tags slow`
- Targeted: new boot test + `workmanager_callback_test.dart`
- Post-frame test pattern: use `testWidgets` + `await tester.pump()` (one frame) to flush callback, then `await tester.pump()` / `pumpAndSettle` with fake async registrars completing immediately
- No slow-tagged files affected
- OK-commit gate per `docs/project-context.md` — one commit per sub-task A/B/C

### Cross-story context (Epic 27)

| Story | Scope | Interaction |
|-------|-------|-------------|
| 27-1 (done) | Parallel pref reads in DI | Shipped — reduced pre-`runApp()` DI latency |
| **27-2 (this)** | WM after `runApp` | Touches `main.dart` only |
| 27-3 | Non-blocking notification init | Same file — ship after or coordinate; keep WM defer independent |
| 27-4 | Lazy `HistoryCubit` | `app_scaffold.dart` — no overlap |

Story 2.10 explicitly placed WM registration in `main.dart` after DI — this story **moves timing only**, not removal [Source: `2-10-workmanager-orchestration-and-oem-deferral-hardening.md` Sub-task D].

### Previous story intelligence (27-1)

- `_loadInitialUserPreferences` with `Future.wait` shipped in `app_dependencies.dart` — boot is faster through DI but WM still blocked first frame until this story
- Sub-task OK-commit gate enforced; minimal diff pattern preferred
- 27-1 explicitly marked `main.dart` out of scope — this story owns WM defer only

### Git intelligence (recent patterns)

Recent commits:
- `e380058` — perf(di): parallelize initial preference reads (27-1)
- Epic 26 closed at `0.11.3+28` with test-only extensions to existing files

Apply same: small `main.dart` diff + focused new test file; no broad refactors.

### Latest tech notes

- **workmanager ^0.9.0+3** — pinned in `pubspec.yaml`; no version bump needed
- **`WidgetsBinding.instance.addPostFrameCallback`** — standard Flutter; available after `ensureInitialized`
- **Platform guard:** Registration functions no-op on non-Android — deferred scheduling can run unconditionally; helpers still short-circuit inside registrars

### Project context reference

- OK-commit gate: `docs/project-context.md` §Development Workflow
- Version bump deferred to Epic 27 close: patch+1, build+1 — `.cursor/rules/app-versioning.mdc`
- Test command: `flutter test --exclude-tags slow`

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` §Story 27-2, AUD-14]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-cold-start.md` §Phase D2, §C5]
- [Source: `_bmad-output/planning-artifacts/architecture.md` §D-04, WorkManager isolate]
- [Source: `lib/main.dart`]
- [Source: `lib/core/services/workmanager_callback.dart`]
- [Source: `_bmad-output/implementation-artifacts/stories/27-1-parallelize-initial-preference-reads-with-future-wait.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/2-10-workmanager-orchestration-and-oem-deferral-hardening.md`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Targeted: `flutter test test/main_workmanager_boot_test.dart test/core/services/workmanager_callback_test.dart --exclude-tags slow` → 19 passed
- Full gate: `flutter test --exclude-tags slow` → all passed

### Completion Notes List

- Added `registerWorkmanagerTasksForBoot` + `schedulePostRunAppWorkmanagerRegistration` in `main.dart` with injectable registrars and error swallow
- Moved WM registration after `runApp` via post-frame callback; cancel stays pre-notification
- New boot scheduling tests in `test/main_workmanager_boot_test.dart`

### File List

- `lib/main.dart` — deferred WM registration helpers + boot reorder
- `test/main_workmanager_boot_test.dart` — scheduling, order, error swallow tests
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` — story status in-progress → review

## Change Log

- 2026-07-19: Story context created — AUD-14 defer WorkManager registration post-runApp (ready-for-dev).
- 2026-07-19: Implemented deferred WM registration post-runApp — helpers, boot reorder, tests (review).
