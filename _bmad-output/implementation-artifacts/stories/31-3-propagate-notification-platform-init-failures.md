# Story 31.3: Propagate Notification Platform Init Failures

Status: done

<!-- audits_2 Epic 31 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 31-3 · diagnostic-permissions-notifications.md #3 · AUD2-FR10 · AUD2-FR34 (partial) · Quick fix Q6 -->
<!-- Prerequisite: Story 31-2 review/done path independent; 31-1 done -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **developer**,
I want notification init failures to surface to boot and tests,
So that broken plugin setup is not silently swallowed.

## Acceptance Criteria

1. **Given** `_initializePlatform` throws or fails natively (plugin init, channel creation)
   **When** `NotificationService.initialize()` runs
   **Then** failure propagates (`rethrow` on `_initFuture`) — AUD2-FR10
   **And** `_initialized` remains `false` after failure
   **And** `_initFuture` is cleared so a later retry can re-attempt init

2. **Given** the internal catch in `_initializePlatform` (lines 118–122)
   **When** this story ships
   **Then** errors are still logged (`debugPrint` + `debugPrintStack`) **and** rethrown — no silent swallow

3. **Given** `initialize()` outer catch (lines 56–63)
   **When** `_initializePlatform` rethrows
   **Then** outer catch resets `_initFuture` when `!_initialized` and rethrows — existing contract preserved

4. **Given** `notification_service_test.dart`
   **When** extended
   **Then** init failure rethrow is covered — AUD2-FR34 (partial)
   **And** existing concurrent-init and background-timeout tests remain green

5. **Given** Story 27-3 non-blocking boot (`startNotificationInitForBoot`)
   **When** init failure propagates from `initialize()`
   **Then** boot helper still catches/logs at `main.dart` level — no crash, no reorder of cancel-before-init — AUD2-NFR4 partial
   **And** `main_notification_boot_test.dart` generic-error swallow test still passes (boot boundary, not service boundary)

6. **Given** `showGoalReached()` lazy-init path (`!_initialized` → `await initialize()`)
   **When** platform init fails
   **Then** method returns `false` — does **not** throw into `BackgroundCollector` WM task
   **And** existing permission-denied no-op behaviour unchanged

**Covers:** AUD2-FR10 · AUD2-FR34 (partial) · diagnostic-permissions-notifications.md #3 · Quick fix Q6

**Depends on:** None within Epic 31 (parallel to 31-2). Builds on Story 27-3 boot helper pattern.

**Out of scope:**
- Boot WM cancel structural gate → **31-5** (do not refactor `main.dart` boot order)
- `initializeForBackground` late-result flip-flop after timeout → **31-6**
- Centralized permission mappers → **31-4**
- Notification UX / toggle copy → **31-1** (done)
- `pubspec.yaml` version bump (Epic 31 close = minor+1)

## Tasks / Subtasks

- [x] **Sub-task A — Rethrow in `_initializePlatform`** (AC: #1, #2, #3)
  - [x] Read fully: `lib/core/services/notification_service.dart` (`initialize`, `_initializePlatform`, `showGoalReached`, `initializeForBackground`)
  - [x] In `_initializePlatform` catch block (~L118–122): after log, add `rethrow`
  - [x] Verify `_initFuture = null` in catch still runs before rethrow (allows retry)
  - [x] Confirm injected `_platformInitializer` failure path also propagates (no separate swallow)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Harden `showGoalReached` lazy-init against thrown `initialize()`** (AC: #6)
  - [x] Wrap lazy `await initialize()` in try/catch; on failure return `false` (log optional — outer init already logs)
  - [x] Preserve: permission check first; presenter path unchanged; `goalNotificationPresenter` inject bypasses platform init
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests + diagnostic partial close** (AC: #4, #5)
  - [x] Add test: `platformInitializer` throws → `expect(service.initialize(), throwsA(...))` and `_initialized` stays false
  - [x] Add test: after failed init, second `initialize()` retries (initCount == 2 with succeeding second call)
  - [x] Add test: `showGoalReached` returns false when init throws (permission granted, platform init fails)
  - [x] Run: `flutter test test/core/services/notification_service_test.dart`
  - [x] Run: `flutter test test/main_notification_boot_test.dart` (regression — boot swallow unchanged)
  - [x] Run: `flutter test --tags critical`
  - [x] Update `planning-artifacts/audits_2/diagnostic-permissions-notifications.md` #3 → `done` or `partial` with story ref
  - [x] Sync `audits_2/README.md` P0-06 row if tracked
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

**Root bug:** `_initializePlatform` catches platform failures, logs, and returns normally. `initialize()`'s outer `rethrow` (L58–62) never fires — callers cannot detect broken plugin setup.

```105:122:lib/core/services/notification_service.dart
    try {
      await _plugin.initialize(settings: initSettings);
      // ... createNotificationChannel ...
      _initialized = true;
    } catch (error, stackTrace) {
      _initFuture = null;
      debugPrint('NotificationService init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      // MISSING: rethrow — AUD2-FR10
    }
```

| Location | Current behaviour | Gap |
|----------|-------------------|-----|
| `_initializePlatform` L118–122 | Log + swallow | AUD2-FR10 — failure invisible to callers |
| `initialize()` L56–63 | `rethrow` on `_initFuture` failure | Dead code today — never reached on native failure |
| `startNotificationInitForBoot` | Catches timeout + generic errors | **Correct** — boot resilience layer (Story 27-3); not this story's target |
| `showGoalReached` L141–146 | `await initialize()` then `!_initialized` check | After rethrow fix, **must catch** or WM task throws |

[Source: `diagnostic-permissions-notifications.md` #3 · `epics-audits-2.md` AUD2-FR10]

### Recommended implementation

**1. Minimal fix (`_initializePlatform` catch):**

```dart
} catch (error, stackTrace) {
  _initFuture = null;
  debugPrint('NotificationService init failed: $error');
  debugPrintStack(stackTrace: stackTrace);
  rethrow;
}
```

**2. `showGoalReached` lazy-init guard (regression prevention):**

```dart
if (_usesPlatformPresenter) {
  if (!_initialized) {
    try {
      await initialize();
    } catch (_) {
      return false;
    }
  }
  if (!_initialized) {
    return false;
  }
}
```

Rationale: `BackgroundCollector._maybeShowGoalNotification` awaits `showGoalReached` without try/catch — unhandled throw would fail WM collection task.

[Source: `background_collector.dart:211`]

**3. Do NOT change:**

| Area | Reason |
|------|--------|
| `main.dart` boot order / `startNotificationInitForBoot` | Story 27-3 + 31-5 scope; boot **should** swallow after service propagates |
| `initializeForBackground` timeout semantics | Story 31-6 |
| 3 s UI boot timeout | Story 27-3 AC preserved |
| `_initFuture` coalescing in `initialize()` | Concurrent init test depends on it |
| Injected `goalNotificationPresenter` bypass | Tests use presenter inject — no platform init |

### Layered error handling (understand before editing)

```
_initializePlatform  →  rethrow (THIS STORY)
        ↓
initialize()         →  rethrow (already exists)
        ↓
startNotificationInitForBoot  →  catch + debugPrint (Story 27-3 — KEEP)
        ↓
main()               →  unawaited — never crashes app
```

Service layer must be **honest**; boot layer remains **resilient**. Tests at each boundary validate different contracts.

[Source: `stories/27-3-non-blocking-notification-init-before-first-frame.md` · Story 27-3 explicitly deferred `_initializePlatform` rethrow to audits_2]

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-12: `flutter_local_notifications` ^21.0.0 | No API change — init/channel API unchanged |
| FR-25 local-only notifications | Failure propagation improves observability, not notification copy |
| Inter-process: WM isolate | `initializeForBackground` uses same `initialize()` — failure returns `false` on timeout; rethrow path covered by service tests |
| Injectable typedefs | `NotificationPlatformInitializer` — use in tests to simulate failure |
| Token economy | ~5 lines service + ~3 lines showGoalReached + tests; no new abstractions |

[Source: `architecture.md` D-12, Notifications § · AUD2-NFR4]

### File structure requirements

| File | Action |
|------|--------|
| `lib/core/services/notification_service.dart` | `rethrow` in `_initializePlatform`; optional try/catch in `showGoalReached` |
| `test/core/services/notification_service_test.dart` | Init failure rethrow + retry + showGoalReached false |
| `planning-artifacts/audits_2/diagnostic-permissions-notifications.md` | Close #3 |
| `planning-artifacts/audits_2/README.md` | Sync P0-06 if row tracked |

**Do not touch:** `main.dart` (31-5), `profile_cubit.dart`, onboarding files, `activity_permission_resolver.dart`, `pubspec.yaml` version.

### Testing requirements

| Verify | Command |
|--------|---------|
| Notification service (primary) | `flutter test test/core/services/notification_service_test.dart` |
| Boot helper regression | `flutter test test/main_notification_boot_test.dart` |
| Critical gate | `flutter test --tags critical` |

**Note:** `notification_service_test.dart` is `@Tags(['slow'])` — run file explicitly.

**Test patterns:**

```dart
test('initialize rethrows when platform init fails', () async {
  final service = NotificationService(
    platformInitializer: (_) async => throw StateError('plugin init failed'),
  );
  await expectLater(service.initialize(), throwsA(isA<StateError>()));
});

test('showGoalReached returns false when init fails', () async {
  final service = NotificationService(
    permissionChecker: () async => PermissionStatus.granted,
    platformInitializer: (_) async => throw StateError('plugin init failed'),
  );
  expect(await service.showGoalReached(), isFalse);
});
```

Do **not** run bare `flutter test`.

### Previous story intelligence (31-2 / 31-1)

| Learning | Impact on 31-3 |
|----------|----------------|
| Epic 31 sub-task OK commit gate | Same A→C workflow |
| Diagnostic partial-close pattern | Update #3 row in Sub-task C |
| Do-not-touch lists from 31-1/31-2 | No onboarding/profile changes |
| 31-2 in `review` — independent | No merge dependency |
| Injectable permission/notification fakes | Mirror with throwing `platformInitializer` |

[Source: `stories/31-2-onboarding-intro-post-denial-feedback.md` · `stories/31-1-model-permanently-denied-with-settings-cta.md`]

### Cross-story context (Epic 31)

| Story | Scope | Relationship |
|-------|-------|--------------|
| 31-1 | done | Notification toggle UX — uses `hasNotificationPermission`, not init |
| 31-2 | review | Onboarding — independent |
| **31-3** | **this story** | Service-level init rethrow |
| 31-4 | Centralize mappers | Independent |
| 31-5 | Boot WM cancel gate | Touches `main.dart` — do not overlap |
| 31-6 | Toggle concurrency + background init timeout | Builds on honest `_initFuture`; may add late-result guard |

**Quick fix Q6:** Epics list this as shippable in one PR — story is intentionally minimal.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `191df81` / `9bd0c46` | Epic 31 onboarding — unrelated files |
| Story 27-3 (done) | Boot helper + swallow-at-main pattern — preserve |
| `b360200` | 31-1 done — notification permission UX ready |

Active branch `main`; tracker `sprint-status-audits-2.yaml`; base `0.13.1+33`.

### Latest tech / library notes

- **`flutter_local_notifications` ^21.0.0:** `FlutterLocalNotificationsPlugin.initialize` throws on misconfiguration; `createNotificationChannel` nullable `androidPlugin` — channel failure is rare but should propagate.
- **No package upgrade** — behaviour fix only.
- **Dart 3:** `rethrow` preserves stack trace when used without argument in catch block.

### Project context reference

- OK commit gate: sub-tasks A→C, separate commits after Baptiste approval
- Tests: targeted file runs + `flutter test --tags critical`
- Version bump: Epic 31 close (minor+1) — not per story
- Communication: French in chat; story in English

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 31-3, AUD2-FR10, Quick fix Q6]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-permissions-notifications.md` #3]
- [Source: `_bmad-output/planning-artifacts/audits_2/README.md` P0-06]
- [Source: `_bmad-output/planning-artifacts/architecture.md` D-12, Notifications §]
- [Source: `lib/core/services/notification_service.dart`]
- [Source: `lib/main.dart` `startNotificationInitForBoot`]
- [Source: `lib/core/services/background_collector.dart` `_maybeShowGoalNotification`]
- [Source: `test/core/services/notification_service_test.dart`]
- [Source: `test/main_notification_boot_test.dart`]
- [Source: `stories/27-3-non-blocking-notification-init-before-first-frame.md`]
- [Source: `stories/31-1-model-permanently-denied-with-settings-cta.md`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

### Completion Notes List

- Sub-task A (`4a5f576`): `rethrow` in `_initializePlatform` catch — failures propagate via `initialize()`.
- Sub-task B+C (`49a387d`): `showGoalReached` lazy-init try/catch; 3 new tests; diagnostic #3 + P0-06 closed.
- Code review fix: `initializeForBackground` catch init failures → `false`; factory integration test.
- Tests: notification_service 9/9, background_collector_factory 6/6, main_notification_boot 4/4, critical 205/205.

### File List

- `lib/core/services/notification_service.dart`
- `test/core/services/notification_service_test.dart`
- `_bmad-output/planning-artifacts/audits_2/diagnostic-permissions-notifications.md`
- `_bmad-output/planning-artifacts/audits_2/README.md`
- `test/core/services/background_collector_factory_test.dart`

### Change Log

- 2026-07-24: Story 31-3 implemented — init failure propagation + WM-safe showGoalReached guard.
- 2026-07-24: Code review — graceful background init failure handling + tests; story done.
