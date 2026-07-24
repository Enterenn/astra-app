# Story 31.5: Structural Boot Gate — Cancel WM Before Notification Init

Status: done

<!-- audits_2 Epic 31 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 31-5 · diagnostic-workmanager-maintenance-db.md #4 · diagnostic-permissions-notifications.md · AUD2-FR17 · AUD2-FR34 (partial) -->
<!-- Prerequisite: 31-3 done (init rethrow + boot swallow boundary) · 27-2 (WM defer post-runApp) · 27-3 (non-blocking init helper) -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **developer**,
I want boot to serialize WorkManager cancel and notification init,
So that isolate races cannot regress silently when `main.dart` changes.

## Acceptance Criteria

1. **Given** app boot sequence
   **When** `cancelStepCollectionWorkmanager` and notification init run
   **Then** order is encapsulated in a single boot-gate function (cancel completes → notification init starts) — AUD2-FR17
   **And** behaviour matches current intentional ordering documented in `workmanager_callback.dart:167-169`
   **And** `main()` delegates to the gate — no inline cancel + `unawaited(init)` sequence

2. **Given** Story 27-3 non-blocking boot contract
   **When** the gate runs
   **Then** `cancelStepCollectionWorkmanager` is **awaited** before notification init is **started**
   **And** notification init may still run **in parallel** with `AppDependencies.create` (init not awaited by `main()` after gate returns)
   **And** `startNotificationInitForBoot` timeout (3 s) and swallow-at-boot-boundary behaviour unchanged — AUD2-NFR4 partial

3. **Given** a boot regression test
   **When** cancel and init are injected fakes
   **Then** init cannot start until cancel future completes — AUD2-FR34 (partial)
   **And** reordering init before cancel inside the gate causes test failure

4. **Given** existing boot tests
   **When** this story ships
   **Then** `main_notification_boot_test.dart` helper tests remain green
   **And** new gate-order test tagged `@Tags(['critical'])`
   **And** `flutter test --tags critical` passes

5. **Given** diagnostic #4 in `diagnostic-workmanager-maintenance-db.md`
   **When** gate ships
   **Then** item marked `done` with story ref
   **And** `audits_2/README.md` P1 row M7 / #4 synced if tracked

**Covers:** AUD2-FR17 · AUD2-FR34 (partial) · diagnostic-workmanager-maintenance-db.md #4

**Depends on:** 31-3 (service rethrow; boot still swallows). Independent of 31-4 (permissions) and 31-6 (Profile toggle).

**Out of scope:**
- Awaiting full notification init before `AppDependencies.create` / `runApp` — would regress 27-3 first-frame latency
- Cancelling `kDatabaseMaintenanceUniqueName` — diagnostic notes gap; separate story if needed
- `NotificationService` init contract changes → 31-6 for background timeout flip-flop
- WM post-`runApp` registration (`schedulePostRunAppWorkmanagerRegistration`) — frozen by 27-2
- `pubspec.yaml` version bump (Epic 31 close = minor+1)

## Tasks / Subtasks

- [x] **Sub-task A — Boot gate extraction** (AC: #1, #2)
  - [x] Read fully: `lib/main.dart`, `workmanager_callback.dart` (`cancelStepCollectionWorkmanager` doc), `stories/27-3-*`, `stories/27-2-*`
  - [x] Add `lib/core/services/boot_sequence.dart` (preferred over bloating `main.dart`):
    - `@visibleForTesting`
    - `Future<void> runBootGateBeforeDependencies({ required NotificationService notificationService, Future<void> Function()? cancelStepCollection, Future<void> Function(NotificationService)? startNotificationInit, void Function(Future<void>)? scheduleParallelInit, })`
    - Implementation: `await cancel()` → create `initFuture = startNotificationInit(...)` → `scheduleParallelInit?.call(initFuture) ?? unawaited(initFuture)`
  - [x] Rewire `main()`:
    ```dart
    final notificationService = NotificationService();
    await runBootGateBeforeDependencies(notificationService: notificationService);
    final deps = await AppDependencies.create(...);
    ```
  - [x] Keep `startNotificationInitForBoot` in `main.dart` (or move to `boot_sequence.dart` — single home for boot helpers)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Gate order regression test** (AC: #3, #4)
  - [x] Add `test/core/services/boot_sequence_test.dart` **or** extend `test/main_notification_boot_test.dart` with `runBootGateBeforeDependencies` group
  - [x] Test pattern:
    ```dart
    final order = <String>[];
    await runBootGateBeforeDependencies(
      notificationService: NotificationService(),
      cancelStepCollection: () async { order.add('cancel'); await cancelGate.future; },
      startNotificationInit: (_) async { order.add('init'); },
    );
    expect(order, ['cancel', 'init']);
    ```
  - [x] Negative guard: if fake init were callable before cancel completes, `order` would fail — document in test name
  - [x] Run: `flutter test test/core/services/boot_sequence_test.dart` (or boot test path)
  - [x] Run: `flutter test test/main_notification_boot_test.dart`
  - [x] Run: `flutter test --tags critical`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Diagnostic close** (AC: #5)
  - [x] Update `diagnostic-workmanager-maintenance-db.md` #4 → `done` (31-5)
  - [x] Sync `audits_2/README.md` row if present
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

**Root gap:** `main.dart` encodes correct order today (`await cancel` then `unawaited(init)`), but nothing prevents a future edit from reordering lines or firing init before cancel completes. AUD2-FR17 requires a **structural** gate, not implicit line order.

```59:63:lib/main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await cancelStepCollectionWorkmanager();
  final notificationService = NotificationService();
  unawaited(startNotificationInitForBoot(notificationService));
```

| Reference | Detail | Gap |
|-----------|--------|-----|
| `main.dart:61-63` | Cancel awaited; init unawaited | Not encapsulated — fragile |
| `workmanager_callback.dart:167-169` | Doc: cancel prevents WM isolate racing `NotificationService.initialize` | Gate must preserve this contract |
| `diagnostic-workmanager-maintenance-db.md` #4 | `partial` — no explicit barrier | This story closes it |
| `main_notification_boot_test.dart:49-63` | Proves init helper can overlap caller | Preserve — gate returns before init completes |

[Source: `diagnostic-workmanager-maintenance-db.md` #4 · `epics-audits-2.md` AUD2-FR17]

### Recommended implementation

**1. Boot gate (explicit barrier after cancel):**

```dart
// lib/core/services/boot_sequence.dart
@visibleForTesting
Future<void> runBootGateBeforeDependencies({
  required NotificationService notificationService,
  Future<void> Function()? cancelStepCollection,
  Future<void> Function(NotificationService service)? startNotificationInit,
  void Function(Future<void> initFuture)? scheduleParallelInit,
}) async {
  final cancel = cancelStepCollection ?? cancelStepCollectionWorkmanager;
  final startInit = startNotificationInit ?? startNotificationInitForBoot;

  await cancel(); // barrier: WM step-collection cancel completes first

  final initFuture = startInit(notificationService);
  (scheduleParallelInit ?? unawaited)(initFuture);
}
```

**2. Slim `main()`:**

```dart
WidgetsFlutterBinding.ensureInitialized();
final notificationService = NotificationService();
await runBootGateBeforeDependencies(notificationService: notificationService);
final deps = await AppDependencies.create(notificationService: notificationService);
// migration → runApp → schedulePostRunAppWorkmanagerRegistration — unchanged
```

**3. Where to put helpers:**

| Symbol | Recommended location |
|--------|---------------------|
| `runBootGateBeforeDependencies` | `boot_sequence.dart` (new) |
| `startNotificationInitForBoot` | Move to `boot_sequence.dart` **or** keep in `main.dart` and import — avoid duplicate |
| `registerWorkmanagerTasksForBoot` | Stay in `main.dart` (27-2 scope) |

Prefer **one boot module** if moving `startNotificationInitForBoot` — update `main_notification_boot_test.dart` import path only if moved.

**4. What NOT to change:**

| Behaviour | Reason |
|-----------|--------|
| `unawaited` init after gate | 27-3 — DI bounds pre-`runApp` latency |
| 3 s timeout in `startNotificationInitForBoot` | Epic 27-3 AC |
| Swallow timeout/errors at boot helper | 31-3 boot boundary vs service rethrow |
| Post-frame WM registration | 27-2 |
| Cancel scope = step collection only | Diagnostic #4 notes maintenance not cancelled — out of scope |

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-04 background | Cancel-before-init prevents WM isolate vs UI-isolate notification plugin race |
| Layering | Boot orchestration in `core/services/`; `NotificationService` unchanged |
| `@visibleForTesting` | Gate + existing boot helpers remain test-injectable |
| Error resilience | Gate does not catch — `startNotificationInitForBoot` owns swallow |
| Token economy | Small extraction; no new dependencies |

[Source: `architecture.md` · `spec-notification-startup-init.md` · Story 27-3]

### File structure requirements

| File | Action |
|------|--------|
| `lib/core/services/boot_sequence.dart` | **New** — `runBootGateBeforeDependencies` (+ optional move of `startNotificationInitForBoot`) |
| `lib/main.dart` | **UPDATE** — delegate to gate; remove inline cancel/unawaited pair |
| `test/core/services/boot_sequence_test.dart` | **New** — order regression (or extend `main_notification_boot_test.dart`) |
| `test/main_notification_boot_test.dart` | **UPDATE** imports only if helper moved |
| `planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md` | Close #4 |
| `planning-artifacts/audits_2/README.md` | Sync M7 / #4 row |

**Do not touch:** `notification_service.dart` (31-6), `profile_cubit.dart` (31-6), permission resolvers (31-4 done), `app_dependencies.dart`, `goal_notification_migration.dart`, `schedulePostRunAppWorkmanagerRegistration`, `pubspec.yaml`.

### Testing requirements

| Verify | Command |
|--------|---------|
| Boot gate order | `flutter test test/core/services/boot_sequence_test.dart` |
| Notification boot helper | `flutter test test/main_notification_boot_test.dart` |
| WM boot helper | `flutter test test/main_workmanager_boot_test.dart` |
| Critical gate | `flutter test --tags critical` |

**Key test (order enforcement):**

```dart
test('starts notification init only after cancel completes', () async {
  final events = <String>[];
  final cancelStarted = Completer<void>();

  await runBootGateBeforeDependencies(
    notificationService: NotificationService(),
    cancelStepCollection: () async {
      events.add('cancel-start');
      await cancelStarted.future;
      events.add('cancel-done');
    },
    startNotificationInit: (_) async {
      events.add('init');
    },
  );

  expect(events, ['cancel-start', 'cancel-done', 'init']);
});
```

Do **not** run bare `flutter test`.

### Previous story intelligence

| Learning | Impact on 31-5 |
|----------|----------------|
| 31-3: service `rethrow`; boot `startNotificationInitForBoot` swallows | Gate must not add a catch layer — delegate to existing helper |
| 31-4: explicit do-not-touch `main.dart` | **This story owns `main.dart` boot wiring** |
| 27-3: parallel init + DI by design | Gate awaits cancel only; init still parallel with DI |
| 27-2: cancel stays pre-notification; WM register post-runApp | Do not move cancel after init or WM before runApp |
| OK commit gate A→C | Same sub-task workflow |

[Source: `stories/31-3-*` · `stories/31-4-*` · `stories/27-3-*` · `stories/27-2-*`]

### Cross-story context (Epic 31)

| Story | Status | Relationship |
|-------|--------|--------------|
| 31-1 | done | Post-onboarding CTAs — independent |
| 31-2 | done | Onboarding intro — independent |
| 31-3 | done | Init rethrow — boot swallow preserved here |
| 31-4 | done | Permission mappers — independent |
| **31-5** | **this story** | Structural boot gate |
| 31-6 | backlog | Profile toggle / background init timeout — do not overlap |

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `c62056c` | 31-3 init rethrow — preserve service; boot swallow unchanged |
| `7cccb4f` | 31-4 permissions — no boot changes |
| Prior 27-2/27-3 commits | WM defer + non-blocking init — gate must not regress |

Active branch `main`; tracker `sprint-status-audits-2.yaml`; base `0.13.1+33`.

### Latest tech / library notes

- **`workmanager` ^0.5.x:** `cancelByUniqueName` is async; gate must `await` before UI-isolate notification plugin init.
- **No package upgrade** — structural refactor only.
- **Flutter 3.x `unawaited`:** from `dart:async`; gate uses it for post-barrier init scheduling.

### Project context reference

- OK commit gate: sub-tasks A→C, separate commits after Baptiste approval
- Tests: targeted file runs + `flutter test --tags critical`
- Version bump: Epic 31 close (minor+1) — not per story
- Boot WM table: `docs/project-context.md` § WorkManager registration

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 31-5, AUD2-FR17]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md` #4]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-permissions-notifications.md` — boot boundary cross-ref]
- [Source: `_bmad-output/implementation-artifacts/spec-notification-startup-init.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/27-3-non-blocking-notification-init-before-first-frame.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/27-2-defer-workmanager-registration-until-after-runapp.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/31-3-propagate-notification-platform-init-failures.md`]
- [Source: `lib/main.dart`]
- [Source: `lib/core/services/workmanager_callback.dart` L167-169]
- [Source: `test/main_notification_boot_test.dart`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

### Completion Notes List

- Sub-task A: Extracted `runBootGateBeforeDependencies` + `startNotificationInitForBoot` to `boot_sequence.dart`; `main()` delegates to gate (await cancel → unawaited init).
- Sub-task B: Added `boot_sequence_test.dart` with order regression + parallel-init contract; updated `main_notification_boot_test.dart` imports.
- Sub-task C: Closed diagnostic #4 and synced README rows (#4, M7, P1+ count).

### File List

- `lib/core/services/boot_sequence.dart` (new)
- `lib/main.dart` (updated)
- `test/core/services/boot_sequence_test.dart` (new)
- `test/main_notification_boot_test.dart` (updated)
- `_bmad-output/planning-artifacts/audits_2/diagnostic-workmanager-maintenance-db.md` (updated)
- `_bmad-output/planning-artifacts/audits_2/README.md` (updated)
- `_bmad-output/implementation-artifacts/sprint-status-audits-2.yaml` (updated)

### Change Log

- 2026-07-24: Story 31-5 — structural boot gate, order tests, diagnostic #4 closed.
