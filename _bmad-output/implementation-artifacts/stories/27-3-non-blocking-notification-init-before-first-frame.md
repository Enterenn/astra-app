# Story 27.3: Non-Blocking Notification Init Before First Frame

Status: review

<!-- Post-audit Epic 27 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 27-3 · diagnostic-cold-start.md §Phase D3 · AUD-15 -->
<!-- Prerequisite: Stories 27-1, 27-2 done; Epics 21 + 25 done -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want notification channel setup not to serially block app launch for up to 3 seconds,
So that cold start is not gated on platform notification init.

## Acceptance Criteria

1. **Given** `NotificationService.initialize()` in `main.dart`
   **When** boot runs
   **Then** notification init is not a hard serial gate before `AppDependencies.create` / `runApp` (AUD-15, diagnostic-cold-start §D3)
   **And** init runs in parallel with DI (preferred) or is deferred until after first frame, preserving the existing **3 s** UI-isolate timeout guard

2. **Given** notification init times out or fails
   **When** the app continues boot
   **Then** behaviour matches current resilience (`debugPrint` / `debugPrintStack`, no crash)
   **And** `migrateGoalNotificationPreferenceIfNeeded` in `main.dart` still receives a `NotificationService` instance (may be partially initialized)

3. **Given** notifications later become ready (or never)
   **When** goal-reached, profile toggle, or background collection flows need the service
   **Then** existing call sites tolerate late init or no-op safely — no new crash paths
   **And** `showGoalReached` lazy-init via `_initFuture` coalescing remains intact

4. **Given** `cancelStepCollectionWorkmanager()` on boot
   **When** notification init starts
   **Then** cancel still completes **before** init begins (race guard from Story 2.10 — do not reorder)

5. **Given** unit tests
   **When** story verification runs
   **Then** boot helper is covered (non-blocking start, 3 s timeout swallow, error swallow)
   **And** existing `notification_service_test.dart` + `goal_notification_migration_test.dart` remain green
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-15 · diagnostic-cold-start.md §Phase D3

**Depends on:** Stories 27-1 (parallel pref reads), 27-2 (WM defer). Independent of 27-4 (lazy HistoryCubit).

**Out of scope:** Changing notification channel IDs/copy, FGS/WorkManager notification paths, `ProfileCubit` UX, version bump (Epic 27 close → patch+1, build+1), lazy `HistoryCubit` (27-4).

## Tasks / Subtasks

- [x] **Sub-task A — Extract non-blocking init helper** (AC: #1, #2, #4)
  - [x] Read fully: `lib/main.dart`, `lib/core/services/notification_service.dart`, `lib/core/services/workmanager_callback.dart` (cancel race comment L167–169)
  - [x] Add `@visibleForTesting` helper in `main.dart` (e.g. `startNotificationInitForBoot`) that:
    - Accepts `NotificationService` + optional injectable `initialize` closure for tests
    - Applies `initialize().timeout(const Duration(seconds: 3))` with same catch blocks as today (`TimeoutException`, generic catch + stack)
    - Returns `Future<void>` (caller decides await vs `unawaited`)
  - [x] **Do not change** `_initializePlatform` swallow semantics inside `NotificationService` unless a testability gap blocks AC #3
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Rewire main() boot order** (AC: #1, #2, #4)
  - [x] Keep: `ensureInitialized` → `await cancelStepCollectionWorkmanager()` → construct `NotificationService`
  - [x] Replace blocking `await notificationService.initialize().timeout(...)` with **non-blocking** start:
    - **Preferred:** `unawaited(startNotificationInitForBoot(notificationService))` then `await AppDependencies.create(...)` — init overlaps DI
    - **Alternative:** post-frame defer (only if parallel overlap is problematic on a target platform)
  - [x] Leave `migrateGoalNotificationPreferenceIfNeeded`, WM defer (27-2), and `runApp` order unchanged relative to DI
  - [x] **Do not await** notification init before `AppDependencies.create`, migration, or `runApp`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests + regression** (AC: #5)
  - [x] Add `test/main_notification_boot_test.dart` (or extend `test/main_workmanager_boot_test.dart`) covering:
    - Helper invokes initialize with 3 s timeout semantics (inject slow/failing initializer)
    - Timeout and generic errors are swallowed — no rethrow
    - Optional: delayed init proves boot path can proceed without awaiting init completion (fake async / completer pattern)
  - [x] Run `flutter test test/main_notification_boot_test.dart test/core/services/notification_service_test.dart test/core/preferences/goal_notification_migration_test.dart --exclude-tags slow`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Remove serial `await` on notification init before DI / `runApp` | WM registration timing (27-2 done) |
| `@visibleForTesting` boot helper + unit tests | Parallel pref reads (27-1 done) |
| Preserve 3 s UI timeout + error logging | Lazy `HistoryCubit` (27-4) |
| Preserve cancel-before-init ordering | Notification copy / channel redesign |
| OK-commit sub-task gate | Version bump until Epic 27 close |

### Root cause (read before editing)

**Serial pre-DI notification gate (AUD-15):** `main.dart` awaits `NotificationService.initialize().timeout(3s)` before `AppDependencies.create`, adding **0–3000 ms** to cold start on the critical path [Source: `main.dart` L45–53, `diagnostic-cold-start.md` §Phase D3].

Diagnostic D3: initialize in parallel with `AppDependencies.create`, or defer after first frame [Source: `diagnostic-cold-start.md` §D3]. Combined with 27-1 (parallel prefs) and 27-2 (WM after `runApp`), D1–D3 complete pre-`runApp()` polish toward the <100 ms Today data target [Source: diagnostic §Priorisation item 6].

### Current boot sequence (MUST understand — post 27-2)

```42:64:lib/main.dart
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
  final databasePath = join(await getDatabasesPath(), 'astra_app.db');
  runApp(AstraApp(deps: deps));
  schedulePostRunAppWorkmanagerRegistration(databasePath);
}
```

**Target sequence after this story:**

1. `ensureInitialized` → `await cancelStepCollectionWorkmanager()` (unchanged)
2. Construct `NotificationService`
3. **`unawaited(startNotificationInitForBoot(notificationService))`** — overlaps step 4
4. `await AppDependencies.create(...)` → migration → `runApp` → WM defer (unchanged from 27-2)
5. Init may still be in flight during steps 4–5 — **by design**

### Why cancel must stay before init starts

```167:169:lib/core/services/workmanager_callback.dart
/// Cancels any in-flight Android step-collection WM work before UI-isolate init.
///
/// Prevents a background isolate from racing [NotificationService.initialize].
```

Story 27-2 explicitly kept cancel pre-notification. This story moves **await timing only** — cancel must remain awaited before firing init.

### NotificationService contract (read before editing)

Key behaviours in `lib/core/services/notification_service.dart`:

| Mechanism | Purpose | Story impact |
|-----------|---------|--------------|
| `_initFuture` coalescing in `initialize()` | Concurrent init calls share one platform init | Safe when boot fires init early and `showGoalReached` calls `initialize()` later |
| `_initializePlatform()` internal catch | Logs platform failures; may leave `_initialized == false` without rethrow | Boot helper still wraps outer `timeout` for UI isolate 3 s guard |
| `showGoalReached()` L136–142 | Calls `await initialize()` when `!_initialized` before show | **No change needed** — tolerates late init |
| `hasNotificationPermission()` | Uses `permission_handler` only | Migration + Profile toggle work **without** platform init |
| `initializeForBackground()` | Separate 2 s timeout for WM isolate | **Out of scope** — different entrypoint |

**Migration does not require init:** `migrateGoalNotificationPreferenceIfNeeded` only calls `hasNotificationPermission()` [Source: `goal_notification_migration.dart` L13].

**DI does not require init:** `AppDependencies.create` passes `notificationService` into `BackgroundCollector` but does not call `initialize()` during create [Source: `app_dependencies.dart` L150–152].

### Recommended implementation pattern

```dart
@visibleForTesting
Future<void> startNotificationInitForBoot(
  NotificationService notificationService, {
  Future<void> Function(NotificationService service)? initialize,
}) async {
  final runInit = initialize ??
      ((service) => service.initialize().timeout(const Duration(seconds: 3)));
  try {
    await runInit(notificationService);
  } on TimeoutException catch (error) {
    debugPrint('NotificationService init timed out: $error');
  } catch (error, stackTrace) {
    debugPrint('NotificationService init failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

// In main():
final notificationService = NotificationService();
unawaited(startNotificationInitForBoot(notificationService));
final deps = await AppDependencies.create(notificationService: notificationService);
```

**Why parallel (unawaited) over post-frame defer:** Diagnostic lists parallel with DI first; goal notifications may be needed soon after boot via foreground collection — starting init immediately (overlapped with DI) minimizes time-to-ready without blocking first frame. Post-frame defer is acceptable fallback only if platform testing shows overlap issues.

**Why not `Future.wait([init, create])`:** Awaiting the batch still blocks migration/`runApp` on the slowest leg (init up to 3 s). Use **unawaited** init so DI bounds pre-`runApp()` latency.

**Why keep 3 s timeout in helper:** Epic AC and current `main.dart` behaviour; distinct from `_backgroundInitTimeout` (2 s) used in WM isolate.

### Call-site safety matrix (do not break)

| Call site | Init required? | Late-init safe? |
|-----------|----------------|-----------------|
| `migrateGoalNotificationPreferenceIfNeeded` | No (`hasNotificationPermission`) | Yes |
| `BackgroundCollector` → `showGoalReached` | Lazy init inside service | Yes |
| `ProfileCubit` toggle | `hasNotificationPermission` only for gating | Yes |
| WM `initializeForBackground` | Own path | Unaffected |

Existing tests cover service-level behaviour — boot tests cover **scheduling/non-blocking** only; do not duplicate `notification_service_test.dart` init coalescing tests.

### Architecture compliance

- **Layering:** Boot orchestration in `main.dart`; notification implementation stays in `core/services/notification_service.dart`
- **D-04 / background:** WM defer (27-2) unchanged; notification init timing independent of reconciliation fallback
- **Error resilience:** Match established boot pattern — log and continue, never crash UI isolate on init failure
- **Epic 21 fast path:** No changes to `TodayCubit`, lifecycle coordinator, or ingestion — DI + boot timing only

### File structure requirements

| File | Action |
|------|--------|
| `lib/main.dart` | **UPDATE** — non-blocking init helper + rewire boot |
| `test/main_notification_boot_test.dart` | **NEW** — helper timeout/error/non-blocking tests |
| `lib/core/services/notification_service.dart` | **READ ONLY** unless init contract gap found |
| `lib/core/preferences/goal_notification_migration.dart` | **DO NOT CHANGE** |
| `lib/core/di/app_dependencies.dart` | **DO NOT TOUCH** |
| `test/main_workmanager_boot_test.dart` | **DO NOT CHANGE** (27-2 scope) |

### Testing requirements

- Default gate: `flutter test --exclude-tags slow`
- Targeted: new boot test + `notification_service_test.dart` + `goal_notification_migration_test.dart`
- Inject `platformInitializer` or custom `initialize` closure in helper tests — never hit real `flutter_local_notifications` plugin in unit tests
- OK-commit gate per `docs/project-context.md` — one commit per sub-task A/B/C

### Cross-story context (Epic 27)

| Story | Scope | Interaction |
|-------|-------|-------------|
| 27-1 (done) | Parallel pref reads | Reduced DI latency — init was still serial until this story |
| 27-2 (done) | WM after `runApp` | Same `main.dart` — notification defer is additive, keep WM helpers intact |
| **27-3 (this)** | Non-blocking notification init | Touches `main.dart`; optional minor `NotificationService` test hook |
| 27-4 | Lazy `HistoryCubit` | `app_scaffold.dart` — no overlap |

### Previous story intelligence

**27-2:** Established `@visibleForTesting` boot helpers + dedicated `test/main_workmanager_boot_test.dart` pattern; post-frame scheduling for WM; error swallow with `debugPrint`/`debugPrintStack`; explicitly left notification init blocking for 27-3.

**27-1:** Parallel pref batch in DI; marked `main.dart` out of scope — boot serial gates remain notification (this story) then addressed WM (27-2).

Apply same delivery pattern: minimal `main.dart` diff + focused new test file; sub-task OK-commit gate.

### Git intelligence (recent patterns)

Recent commits:
- `f7686ea` / `9a34058` — WM defer + boot tests (27-2)
- `e380058` — parallel pref reads (27-1)

Follow: small `main.dart` change, new `test/main_notification_boot_test.dart`, no broad refactors.

### Latest tech notes

- **flutter_local_notifications ^21.0.0** — pinned; no version bump
- **`unawaited`** — already used in `main.dart` for WM defer; `dart:async` imported
- **Concurrent init:** `NotificationService` already deduplicates via `_initFuture` — safe to start init before DI completes

### Project context reference

- OK-commit gate: `docs/project-context.md` §Development Workflow
- Version bump deferred to Epic 27 close: patch+1, build+1 — `.cursor/rules/app-versioning.mdc`
- Test command: `flutter test --exclude-tags slow`

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` §Story 27-3, AUD-15]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-cold-start.md` §Phase D3, §Priorisation]
- [Source: `lib/main.dart`]
- [Source: `lib/core/services/notification_service.dart`]
- [Source: `lib/core/services/workmanager_callback.dart` §cancel race]
- [Source: `lib/core/preferences/goal_notification_migration.dart`]
- [Source: `_bmad-output/implementation-artifacts/stories/27-2-defer-workmanager-registration-until-after-runapp.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/27-1-parallelize-initial-preference-reads-with-future-wait.md`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Targeted tests: 12/12 pass (boot + notification_service + goal_notification_migration)
- Full suite: `flutter test --exclude-tags slow` pass

### Completion Notes List

- ✅ `startNotificationInitForBoot` — 3 s timeout, error swallow, injectable `initialize` for tests
- ✅ `main()` — `unawaited` init overlaps DI; cancel-before-init order preserved
- ✅ `test/main_notification_boot_test.dart` — 4 tests (invoke, timeout, error, non-blocking)
- Commits: `e6e2128`, `7888649`, `f32cced`

### File List

- `lib/main.dart` (modified)
- `test/main_notification_boot_test.dart` (new)

## Change Log

- 2026-07-19: Story context created — AUD-15 non-blocking notification init (ready-for-dev).
- 2026-07-19: Implementation complete — non-blocking notification init (review).
