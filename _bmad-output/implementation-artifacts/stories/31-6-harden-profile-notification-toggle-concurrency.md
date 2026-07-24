# Story 31.6: Harden Profile Notification Toggle Concurrency

Status: done

<!-- audits_2 Epic 31 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 31-6 · diagnostic-permissions-notifications.md #6, #7 · AUD2-FR24 · AUD2-FR25 · AUD2-FR34 (partial) -->
<!-- Prerequisite: 31-1 (permanent-denied UI) · 31-3 (init rethrow) · 31-5 (boot gate) · 28-3 (toggle during loading) -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want rapid taps on the goal-notification toggle to behave predictably,
So that the switch does not flip back or drop requests.

## Acceptance Criteria

1. **Given** concurrent calls to `ProfileCubit.setGoalNotificationsEnabled`
   **When** a toggle operation is already in flight
   **Then** subsequent calls are deduplicated (return the same in-flight future) — pattern parity with `_refreshInFlight` — AUD2-FR24
   **And** only one permission request + one persistence write runs for the coalesced burst
   **And** existing denial paths (`deniedReversible`, `deniedPermanent`, `failed`) and `NotificationToggleResult` contract unchanged

2. **Given** rapid opposite-direction taps (enable then disable before first completes)
   **When** deduplication applies
   **Then** the in-flight operation completes once; UI reflects cubit state after emit (no optimistic Switch flip in `settings_screen.dart`)
   **And** a follow-up tap applies the user's latest intent — acceptable trade-off vs flip-flop

3. **Given** `NotificationService.initializeForBackground` hits `_backgroundInitTimeout`
   **When** the underlying `_initializePlatform` completes after the timeout
   **Then** late completion does **not** set `_initialized = true` for the abandoned attempt — AUD2-FR25
   **And** `initializeForBackground()` return value remains `false` for that call
   **And** a subsequent `initialize()` / `initializeForBackground()` may retry init cleanly (no stuck “half-initialized” state)

4. **Given** UI-isolate `initialize()` (boot / foreground)
   **When** init succeeds normally
   **Then** behaviour unchanged — timeout abandonment applies **only** to the background timeout path, not boot swallow boundary (27-3 / 31-5)

5. **Given** unit tests
   **When** this story ships
   **Then** `profile_cubit_test.dart` covers concurrent toggle deduplication (permission request count = 1)
   **And** `notification_service_test.dart` covers late init after background timeout (`_initialized` stays false until explicit successful init)
   **And** existing notification + profile tests remain green
   **And** `flutter test --tags critical` passes

6. **Given** diagnostic items #6 and #7 in `diagnostic-permissions-notifications.md`
   **When** story ships
   **Then** both marked `done` with story ref
   **And** `audits_2/README.md` rows #6 / #7 synced if tracked

**Covers:** AUD2-FR24 · AUD2-FR25 · AUD2-FR34 (partial) · diagnostic-permissions-notifications.md #6, #7

**Depends on:** 31-1 (Settings snackbar + CTA — no UI changes here), 31-3 (service rethrow), 31-5 (boot gate — do not touch), 28-3 (toggle allowed during `loading`/`error`).

**Out of scope:**
- Settings UI changes (`settings_screen.dart` Switch/snackbar — already correct from 31-1)
- Boot sequence / `main.dart` / `boot_sequence.dart` (31-5 done)
- Permission resolver centralization (31-4 done)
- `pubspec.yaml` version bump (Epic 31 close = minor+1)
- Cancelling native plugin work (impossible) — **ignore late Dart-side result** only

## Tasks / Subtasks

- [x] **Sub-task A — Profile toggle in-flight guard** (AC: #1, #2)
  - [x] Read fully: `lib/presentation/cubits/profile_cubit.dart` (`_refreshInFlight` L46–77, `setGoalNotificationsEnabled` L239–306)
  - [x] Add `Future<NotificationToggleResult>? _toggleInFlight;`
  - [x] Extract body to `_setGoalNotificationsEnabledImpl(bool enabled)`; public method coalesces:
    ```dart
    Future<NotificationToggleResult> setGoalNotificationsEnabled(bool enabled) async {
      if (_toggleInFlight != null) {
        return _toggleInFlight!;
      }
      _toggleInFlight = _setGoalNotificationsEnabledImpl(enabled);
      try {
        return await _toggleInFlight!;
      } finally {
        _toggleInFlight = null;
      }
    }
    ```
  - [x] Preserve all `isClosed` checks, loading/error guard (28-3), permission flow, emit semantics
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Background init timeout abandonment** (AC: #3, #4)
  - [x] Read fully: `lib/core/services/notification_service.dart` (`initialize`, `initializeForBackground`, `_initializePlatform`, `_initFuture`)
  - [x] Implement generation/token guard so timed-out background init cannot flip `_initialized`:
    - Recommended: `_initGeneration` incremented on background timeout; `_initializePlatform` sets `_initialized` only when its captured generation matches at completion
    - On timeout: increment generation, optionally clear `_initFuture` if init not completed (allow retry — verify no double native init race with concurrent `initialize()` test)
  - [x] Do **not** change `initialize()` rethrow contract (31-3) or boot helpers
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Tests** (AC: #5)
  - [x] `profile_cubit_test.dart` — concurrent enable burst:
    ```dart
    test('concurrent setGoalNotificationsEnabled coalesces to one permission request', () async {
      // Slow permission requester; fire two parallel setGoalNotificationsEnabled(true)
      // expect permissionRequestCount == 1; both futures same result
    });
    ```
  - [x] `notification_service_test.dart` — after timeout + late platform init:
    ```dart
    test('background init timeout ignores late platform init for _initialized', () async {
      // platformInitializer delays past backgroundInitTimeout
      // await initializeForBackground() → false
      // await delay completion
      // assert _initialized via follow-up showGoalReached / second initializeForBackground contract
    });
    ```
  - [x] Run: `flutter test test/presentation/cubits/profile_cubit_test.dart`
  - [x] Run: `flutter test test/core/services/notification_service_test.dart`
  - [x] Run: `flutter test test/core/services/background_collector_factory_test.dart` (factory uses `initializeForBackground`)
  - [x] Run: `flutter test --tags critical`
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Diagnostic close** (AC: #6)
  - [x] Update `diagnostic-permissions-notifications.md` #6, #7 → `done` (31-6)
  - [x] Sync `audits_2/README.md` rows if present
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

**Gap 1 — Toggle concurrency:** `refresh()` uses `_refreshInFlight` coalescing; `setGoalNotificationsEnabled` does not. Rapid Switch taps can interleave permission requests and DB writes, causing the Switch to reflect stale state or snackbars for superseded operations.

```46:77:lib/presentation/cubits/profile_cubit.dart
  Future<void>? _refreshInFlight;

  Future<void> refresh() async {
    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }
    _refreshInFlight = _refreshImpl();
    // ...
  }
```

```239:306:lib/presentation/cubits/profile_cubit.dart
  Future<NotificationToggleResult> setGoalNotificationsEnabled(bool enabled) async {
    // ... no _toggleInFlight guard — full async path exposed to concurrent callers
  }
```

**Gap 2 — Background init flip-flop:** `initializeForBackground` uses `.timeout()` but does not invalidate in-flight platform init. Late success can set `_initialized = true` after the caller already received `false`, affecting factory/collector notification path consistency.

```69:84:lib/core/services/notification_service.dart
  Future<bool> initializeForBackground() async {
    try {
      await initialize().timeout(_backgroundInitTimeout);
      return _initialized;
    } on TimeoutException catch (error) {
      debugPrint('NotificationService background init timed out: $error');
      return false;
    }
    // _initializePlatform may still complete and set _initialized = true
  }
```

| Reference | Detail | Gap |
|-----------|--------|-----|
| `profile_cubit.dart:46-77` | `_refreshInFlight` pattern | Toggle lacks equivalent |
| `profile_cubit.dart:239-306` | Full async toggle path | Concurrent entry |
| `settings_screen.dart:314-356` | Switch bound to cubit state; no optimistic flip | Cubit must serialize writes |
| `notification_service.dart:69-84` | Timeout returns false | Late init still mutates `_initialized` |
| `background_collector_factory.dart:39` | `notificationsReady = await initializeForBackground()` | False negative then late true is inconsistent |
| `diagnostic-permissions-notifications.md` #6, #7 | Documented gaps | This story closes both |

[Source: `diagnostic-permissions-notifications.md` #6, #7 · `epics-audits-2.md` AUD2-FR24, AUD2-FR25]

### Recommended implementation

**1. Toggle guard (mirror `refresh()` exactly):**

| Aspect | Rule |
|--------|------|
| Field | `Future<NotificationToggleResult>? _toggleInFlight` |
| Coalescing | Return same future while in flight |
| Clear | `finally { _toggleInFlight = null; }` |
| Impl extraction | `_setGoalNotificationsEnabledImpl` — move existing body verbatim first |
| UI | No `settings_screen.dart` changes — Switch already non-optimistic |

**2. Background init abandonment (generation token):**

```dart
// Sketch — adapt to existing _initFuture coalescing
int _initGeneration = 0;

Future<void> _initializePlatform({required int generation}) async {
  // ... existing platform init ...
  if (generation == _initGeneration) {
    _initialized = true;
  }
}

Future<bool> initializeForBackground() async {
  final generation = _initGeneration;
  try {
    await initialize().timeout(_backgroundInitTimeout);
    return _initialized && generation == _initGeneration;
  } on TimeoutException catch (error) {
    _initGeneration++; // abandon in-flight completion
    if (!_initialized) {
      _initFuture = null; // allow retry when still uninitialized
    }
    debugPrint('NotificationService background init timed out: $error');
    return false;
  }
}
```

**Critical constraints:**
- UI `initialize()` from boot must **not** be invalidated by WM timeout in another isolate — each isolate has its own `NotificationService` instance; generation is per-instance (WM factory creates fresh service). No cross-isolate issue.
- Preserve `concurrent initialize calls share one platform init` test — generation captured when `_initFuture` created.
- Failed init (rethrow) path from 31-3 unchanged — only timeout abandonment is new.

**3. What NOT to change:**

| Behaviour | Reason |
|-----------|--------|
| `NotificationToggleResult` enum / snackbar mapping | 31-1 delivered |
| Toggle during `ProfileStatus.loading` | 28-3 AC |
| `initialize()` rethrow on failure | 31-3 |
| Boot gate / `startNotificationInitForBoot` | 31-5 |
| `_initFuture` coalescing for concurrent `initialize()` | Existing test |
| Injected presenter bypass (`_usesPlatformPresenter == false`) | Tests / factory fakes |

### Architecture compliance

| Rule | Application |
|------|-------------|
| FR-24 / FR-25 | Toggle reliability + background init honesty |
| D-12 `flutter_local_notifications` ^21.0.0 | No API change |
| Layering | Cubit serializes UI writes; service owns init lifecycle |
| Injectable typedefs | Use slow `permissionRequester` / `platformInitializer` in tests |
| Error resilience | No exceptions to UI — retain `NotificationToggleResult` |
| Token economy | Minimal fields + impl extraction; no new service classes |

[Source: `architecture.md` · `spec-notification-startup-init.md`]

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/cubits/profile_cubit.dart` | **UPDATE** — `_toggleInFlight` + impl extraction |
| `lib/core/services/notification_service.dart` | **UPDATE** — timeout abandonment for background init |
| `test/presentation/cubits/profile_cubit_test.dart` | **UPDATE** — concurrent toggle test |
| `test/core/services/notification_service_test.dart` | **UPDATE** — late init after timeout test |
| `planning-artifacts/audits_2/diagnostic-permissions-notifications.md` | Close #6, #7 |
| `planning-artifacts/audits_2/README.md` | Sync rows if tracked |

**Do not touch:** `settings_screen.dart`, `main.dart`, `boot_sequence.dart`, permission resolvers, `background_collector_factory.dart` (unless test-only import unchanged), `pubspec.yaml`.

### Testing requirements

| Verify | Command |
|--------|---------|
| Profile toggle concurrency | `flutter test test/presentation/cubits/profile_cubit_test.dart` |
| Notification timeout / late init | `flutter test test/core/services/notification_service_test.dart` |
| Factory bootstrap regression | `flutter test test/core/services/background_collector_factory_test.dart` |
| Settings widget (no change expected) | `flutter test test/presentation/screens/settings_screen_test.dart` |
| Critical gate | `flutter test --tags critical` |

**Note:** `notification_service_test.dart` and `settings_screen_test.dart` are `@Tags(['slow'])` — run files explicitly.

Do **not** run bare `flutter test`.

### Previous story intelligence

| Learning | Impact on 31-6 |
|----------|----------------|
| 31-5: boot gate done; explicitly deferred toggle/timeout to 31-6 | This story owns `profile_cubit.dart` + `notification_service.dart` timeout semantics |
| 31-3: service rethrow; `initializeForBackground` timeout deferred here | Add abandonment without breaking rethrow/retry tests |
| 31-4: do-not-touch toggle concurrency | **Now in scope** |
| 28-3: toggle works during `loading`/`error` | Preserve guard; test concurrent calls on ready state |
| 31-1: `NotificationToggleResult` + Settings snackbars | No UI work — cubit result contract frozen |
| `_refreshInFlight` / `MyDataCubit` / `TodayCubit` coalescing | Copy pattern, do not invent queue abstraction |

[Source: `stories/31-5-*` · `stories/31-3-*` · `stories/31-4-*` · `stories/28-3-*` · `stories/31-1-*`]

### Cross-story context (Epic 31)

| Story | Status | Relationship |
|-------|--------|--------------|
| 31-1 | done | Permanent-denied UI — frozen |
| 31-2 | done | Onboarding — independent |
| 31-3 | done | Init rethrow — preserve |
| 31-4 | done | Permission mappers — independent |
| 31-5 | done | Boot gate — do not touch |
| **31-6** | **this story** | Last Epic 31 story — closes diagnostic #6/#7 |

**Epic 31 close after 31-6:** bump `pubspec.yaml` minor+1 + `README.md` per sprint tracker.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `03990e3` | 31-5 boot gate review follow-ups — boot path frozen |
| `fed35dc` | `boot_sequence.dart` extraction — do not regress |
| `c62056c` (era) | 31-3 init rethrow — preserve failure paths |
| `7cccb4f` (era) | 31-4 permissions — no toggle changes there |

Active branch `main`; tracker `sprint-status-audits-2.yaml`; base `0.13.1+33`.

### Latest tech / library notes

- **`flutter_local_notifications` ^21.0.0:** Init is async; `.timeout()` does not cancel native work — abandonment must be logical (ignore late Dart completion), not `CancelableOperation`.
- **`permission_handler`:** `.request()` is async; coalescing prevents duplicate OS dialogs from rapid taps.
- **No package upgrade** — concurrency guards only.

### Project context reference

- OK commit gate: sub-tasks A→D, separate commits after Baptiste approval
- Tests: targeted file runs + `flutter test --tags critical`
- Version bump: Epic 31 close (minor+1) — not per story

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 31-6, AUD2-FR24, AUD2-FR25]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-permissions-notifications.md` #6, #7]
- [Source: `_bmad-output/implementation-artifacts/stories/31-5-structural-boot-gate-cancel-wm-before-notification-init.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/31-3-propagate-notification-platform-init-failures.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/28-3-decouple-settings-theme-locale-units-from-profile-loading-gate.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/31-1-model-permanently-denied-with-settings-cta.md`]
- [Source: `lib/presentation/cubits/profile_cubit.dart`]
- [Source: `lib/core/services/notification_service.dart`]
- [Source: `lib/presentation/screens/settings_screen.dart` L314-356]
- [Source: `lib/core/services/background_collector_factory.dart` L39]
- [Source: `test/core/services/notification_service_test.dart`]
- [Source: `test/presentation/cubits/profile_cubit_test.dart`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Sub-task A: `_toggleInFlight` mirrors `_refreshInFlight` coalescing pattern
- Sub-task B: `_initGeneration` incremented on background timeout; late `_initializePlatform` completion ignored when generation stale

### Completion Notes List

- ✅ AC#1/#2: `ProfileCubit.setGoalNotificationsEnabled` coalesces concurrent calls via `_toggleInFlight` + `_setGoalNotificationsEnabledImpl`
- ✅ AC#3/#4: `NotificationService` uses `_initGeneration` to abandon timed-out background init; UI `initialize()` unchanged
- ✅ AC#5: concurrent toggle test + late init after timeout test; all targeted + critical tests green
- ✅ AC#6: diagnostic #6/#7 marked done; README rows synced

### File List

- `lib/presentation/cubits/profile_cubit.dart`
- `lib/core/services/notification_service.dart`
- `test/presentation/cubits/profile_cubit_test.dart`
- `test/core/services/notification_service_test.dart`
- `_bmad-output/planning-artifacts/audits_2/diagnostic-permissions-notifications.md`
- `_bmad-output/planning-artifacts/audits_2/README.md`

### Change Log

- 2026-07-24: Story 31-6 — toggle concurrency guard + background init timeout abandonment + tests + diagnostic close
- 2026-07-24: Code review — guard `_initFuture` clear on stale init failure after background timeout
