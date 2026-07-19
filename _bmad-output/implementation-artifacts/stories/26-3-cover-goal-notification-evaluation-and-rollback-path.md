# Story 26.3: Cover Goal Notification Evaluation and Rollback Path

Status: review

<!-- Post-audit Epic 26 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 26-3 · diagnostic-couverture-structurelle.md Top #3 · AUD-52 -->
<!-- Prerequisite: Story 26-2 done; Epic 18-2 (settings/health repo split) done -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **developer**,
I want `maybeNotifyGoalReachedIfGoalMet` covered including rollback,
So that FR goal-notification failures do not leave prefs inconsistent.

## Acceptance Criteria

1. **Given** `BackgroundCollector.maybeNotifyGoalReachedIfGoalMet`
   **When** unit tests run
   **Then** at least one test **invokes the method by name** (`collector.maybeNotifyGoalReachedIfGoalMet()`) inside a dedicated `group('maybeNotifyGoalReachedIfGoalMet')` or test name containing `maybeNotifyGoalReachedIfGoalMet` (AUD-52, NFR-AUD-06)
   **And** tests do **not** require a full app widget tree — reuse in-memory SQLite + fakes in `background_collector_test.dart`

2. **Given** goal met preconditions (notifications enabled, permission granted, steps ≥ journal goal, user not on app)
   **When** `maybeNotifyGoalReachedIfGoalMet()` runs directly
   **Then** the test asserts evaluation success:
   - `NotificationService.showGoalReached` exercised (spy/presenter call count)
   - `goal_notification_shown_date` pref written for today's local day ISO

3. **Given** steps remain below goal (or goal ≤ 0)
   **When** `maybeNotifyGoalReachedIfGoalMet()` runs directly
   **Then** no notification is shown and no notification dedup pref is written

4. **Given** goal met and `tryClaimGoalNotificationShownDate` succeeds
   **When** `showGoalReached` returns `false` (presenter failure — throw caught inside `NotificationService`, or explicit `false` path)
   **Then** `clearGoalNotificationShownDateIfMatches(todayIso)` runs — **`getGoalNotificationShownDate()` is null after call** (AUD-52 rollback requirement)
   **And** a second direct call can still notify (dedup pref was rolled back)

5. **Given** existing `collectOnce(enableGoalNotification: true)` tests in `background_collector_test.dart`
   **When** this story ships
   **Then** coverage is **extended, not duplicated** — new named group owns AUD-52 contract; keep indirect collectOnce tests green
   **And** prior notification behaviour tests remain unchanged unless consolidating helpers

6. **Given** OK-commit gate per `docs/project-context.md`
   **When** implementing
   **Then** split into reviewable sub-tasks (gap analysis + named group happy/not-met + rollback + verify) with one commit per sub-task after Baptiste approval
   **And** no version bump until Epic 26 closes

**Covers:** AUD-52 · FR-25 · diagnostic-couverture-structurelle.md Top #3

**Depends on:** Epic 18-2 (settings/health split for notification path). Independent of 26-4…26-6.

**Out of scope:** Changing notification matrix (`enableGoalNotification` flags per path); `NotificationService` platform init; coordinator pause wiring (`onLifecycleStatePaused` already calls method — optional spy test, not required by AUD-52); version bump.

## Tasks / Subtasks

- [x] **Sub-task A — Baseline + gap analysis** (AC: #1, #5)
  - [x] Read `maybeNotifyGoalReachedIfGoalMet` + `NotificationService.showGoalReached` return contract
  - [x] Grep `test/` for `maybeNotifyGoalReachedIfGoalMet` — confirm **zero** named hits (AUD-52)
  - [x] Note indirect coverage via `collectOnce(enableGoalNotification: true)` — behaviour exists, audit grep fails
  - [x] **Stop → review brief → wait for Baptiste OK → commit** (plan-only commit optional)

- [x] **Sub-task B — Named happy + not-met `maybeNotifyGoalReachedIfGoalMet` group** (AC: #1, #2, #3)
  - [x] Add `group('maybeNotifyGoalReachedIfGoalMet', () { ... })` in `test/core/services/background_collector_test.dart`
  - [x] Extract minimal `_goalNotificationCollector(...)` helper (optional) — reuse existing setUp repos + `_todayBucket`
  - [x] Test: `maybeNotifyGoalReachedIfGoalMet shows notification when goal met` — direct call, assert presenter + pref
  - [x] Test: `maybeNotifyGoalReachedIfGoalMet skips when steps below goal` — direct call, showCount 0, pref null
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Rollback on showGoalReached failure** (AC: #4)
  - [x] Test: `maybeNotifyGoalReachedIfGoalMet rolls back pref when showGoalReached fails` — presenter throws OR returns via `showGoalReached` false path; assert pref cleared; optional second call notifies again
  - [x] Prefer asserting via **direct** `maybeNotifyGoalReachedIfGoalMet()` (not only `collectOnce`)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Regression verification** (AC: #5, #6)
  - [x] Run `flutter test test/core/services/background_collector_test.dart --exclude-tags slow`
  - [x] Run `flutter test --exclude-tags slow`
  - [x] Grep confirms test name or group contains `maybeNotifyGoalReachedIfGoalMet`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Named unit tests for `maybeNotifyGoalReachedIfGoalMet` | Notification matrix / when `enableGoalNotification` is true per path |
| Goal-met + not-met + rollback pref contract | Full `NotificationService` platform presenter integration |
| Reuse existing test file + SQLite FFI setup | Coordinator pause-path integration test |
| OK-commit sub-task gate | Version bump (Epic 26 close) |

### Root cause (read before editing)

**Coverage gap (AUD-52):** `diagnostic-couverture-structurelle.md` Top #3 flags `maybeNotifyGoalReachedIfGoalMet` as **never targeted by method name** in `test/`. `background_collector_test.dart` already exercises the logic **indirectly** via `collectOnce(enableGoalNotification: true)` (including `rolls back notification pref when show fails` at L491) — CI/audit grep for `\bmaybeNotifyGoalReachedIfGoalMet\b` still fails.

**Why it matters:** FR-25 requires at-most-one local notification per calendar day when the user is **not** on the app. The method uses optimistic dedup (`tryClaimGoalNotificationShownDate`) before `showGoalReached`; if presentation fails, rollback must clear the pref or the user never gets a retry notification that day.

### Production call chain (MUST preserve — do not change in this story)

**Primary implementation** (`lib/core/services/background_collector.dart` L152–198):

```dart
Future<void> maybeNotifyGoalReachedIfGoalMet() async {
  // Early return if deps null (settings, health, notifications, clock, permissionCheck)
  if (isUserFacingAppActive?.call() ?? false) return;
  if (!await settings.getGoalNotificationsEnabled()) return;
  if (!await permissionCheck()) return;

  final todayIso = formatLocalDayIso(time.snapshot());
  final goal = await health.getGoalForLocalDay(todayIso);
  if (goal <= 0) return;

  final steps = await stepAggregation.getTodaySteps();
  if (steps < goal) return;

  if (!await settings.tryClaimGoalNotificationShownDate(todayIso)) return;

  final shown = await notifications.showGoalReached(stepsToday: steps);
  if (!shown) {
    await settings.clearGoalNotificationShownDateIfMatches(todayIso);
  }
}
```

**Call sites (read-only context):**

| Caller | When |
|--------|------|
| `collectOnce` | `enableGoalNotification: true` after bucket upserts (WM/FGS/cold paths per matrix) |
| `AppLifecycleCoordinator._onAppBackgrounded` | Shell visible + pause — user leaving app with steps already persisted |

**`showGoalReached` contract** (`lib/core/services/notification_service.dart` L130–158): returns `true` on successful present; `false` on permission skip, init failure, or caught presenter error. Rollback in collector keys off **`!shown`**, not exceptions propagating.

### Current test file state (UPDATE — read fully)

**Primary target:** `test/core/services/background_collector_test.dart` (~826 LOC)

| Existing test | Calls `maybeNotifyGoalReachedIfGoalMet`? | AUD-52 gap |
|---------------|------------------------------------------|------------|
| `notifies once and writes notification pref when goal met with permission` | No (`collectOnce`) | Indirect — keep green |
| `rolls back notification pref when show fails` | No (`collectOnce`) | Indirect rollback — named test still required |
| `skips notification when user is on the app (foreground)` | No | Optional: one direct-call skip with `isUserFacingAppActive: () => true` |
| `uses journal-resolved goal not stale prefs cache` | No | Confirms `getGoalForLocalDay` — not AUD-52 naming |

**Reuse — do not reinvent:**

- `setUp` block: in-memory DB, `FakeTimeProvider`, `UserSettingsRepository`, `UserHealthMetricsRepository`, `StepAggregationRepository`
- `_todayBucket(...)` helper for seeding steps
- `NotificationService` with injectable `goalNotificationPresenter` (existing pattern L315–320)
- `formatLocalDayIso(clock.snapshot())` for pref assertions

**Suggested named group skeleton:**

```dart
group('maybeNotifyGoalReachedIfGoalMet', () {
  test('maybeNotifyGoalReachedIfGoalMet shows notification when goal met', () async {
    var showCount = 0;
    final notificationService = NotificationService(
      permissionChecker: () async => PermissionStatus.granted,
      goalNotificationPresenter: ({required id, required title, body}) async {
        showCount += 1;
      },
    );
    await userSettings.setGoalNotificationsEnabled(true);
    await userHealthMetrics.setDailyStepGoal(100);
    await repository.upsertIngestionBucket(_todayBucket(value: 500));
    final collector = BackgroundCollector(
      sources: const [],
      normalizer: normalizer,
      repository: repository,
      stepAggregation: stepAggregation,
      baselineRepository: baselineRepository,
      userSettings: userSettings,
      userHealthMetrics: userHealthMetrics,
      clock: clock,
      notificationService: notificationService,
      notificationPermissionGranted: () async => true,
      isUserFacingAppActive: () => false,
    );

    await collector.maybeNotifyGoalReachedIfGoalMet();

    expect(showCount, 1);
    expect(
      await userSettings.getGoalNotificationShownDate(),
      formatLocalDayIso(clock.snapshot()),
    );
  });
});
```

**Rollback test nuance:** Existing collectOnce test uses presenter that **throws** — `showGoalReached` catches and returns `false`, triggering rollback. Named test should call `maybeNotifyGoalReachedIfGoalMet()` directly and assert pref null; optionally call twice to prove dedup reset.

### Architecture compliance

- **FR-25:** At most one notification per local calendar day; dedup via `tryClaimGoalNotificationShownDate` + rollback on failure [Source: prd.md §4.9]
- **Separate from celebration:** Notification dedup pref (`kGoalNotificationShownDateKey`) independent from celebration pref — do not conflate in assertions
- **Journal goal:** Uses `userHealthMetrics.getGoalForLocalDay(todayIso)` not stale `daily_step_goal` pref alone [Source: Story 8-2]
- **Foreground skip:** `isUserFacingAppActive` true → no notification (in-app celebration owns UX)
- **NFR-AUD-06:** Unit tests with fakes — no widget tree, no device notifications

### File structure requirements

| Action | Path |
|--------|------|
| **UPDATE** | `test/core/services/background_collector_test.dart` — add `group('maybeNotifyGoalReachedIfGoalMet')`, optional shared helper |
| **READ ONLY** | `lib/core/services/background_collector.dart` |
| **READ ONLY** | `lib/core/services/notification_service.dart` |
| **READ ONLY** | `lib/data/repositories/user_settings_repository.dart` (`tryClaimGoalNotificationShownDate`, `clearGoalNotificationShownDateIfMatches`) |
| **DO NOT** | Change production notification matrix or coordinator pause logic |

### Testing requirements

**Default verify command:**

```bash
flutter test test/core/services/background_collector_test.dart --exclude-tags slow
flutter test --exclude-tags slow
```

**AUD-52 verification grep:**

```bash
rg "maybeNotifyGoalReachedIfGoalMet" test/core/services/background_collector_test.dart
```

Expect: group name + test bodies calling `collector.maybeNotifyGoalReachedIfGoalMet(`.

**Assertions checklist:**

- [ ] Direct method call is the **explicit** test entry (not only `collectOnce`)
- [ ] Goal met → presenter invoked + dedup pref set
- [ ] Steps below goal → presenter not invoked + pref null
- [ ] Show failure → pref rolled back (`getGoalNotificationShownDate()` null)
- [ ] Optional: second direct call after rollback can notify again

### Previous story intelligence (26-2)

- Sub-task A→D + OK-commit gate pattern worked well — mirror for 26-3
- AUD-51/52 same class of gap: **indirect behaviour vs named audit contract**
- Full fast suite at 951+ tests after 26-2 — extend, do not break existing collector tests
- No production changes in 26-1/26-2 — expect tests-only here too

### Git intelligence

Recent commits (Story 26-2):

- `9c003d2` — close story 26-2 after code review
- `b2da4f1` / `1f7f206` — onLifecycleStateResumed failure + happy path tests

No changes to `maybeNotifyGoalReachedIfGoalMet` since Story 8-2 journal migration — safe to add named tests only.

### Project context reference

- OK-commit gate mandatory per sub-task — `docs/project-context.md`
- Default test command: `flutter test --exclude-tags slow`
- Version bump at **Epic 26 close** only (patch+1, build+1) — current `0.11.2+27`
- Sprint tracker: `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` (not legacy `sprint-status.yaml`)

### References

- [Source: `_bmad-output/planning-artifacts/epics-post-audit.md` § Story 26-3]
- [Source: `_bmad-output/planning-artifacts/audits/diagnostic-couverture-structurelle.md` § Top #3, § background_collector table]
- [Source: `_bmad-output/implementation-artifacts/stories/26-2-cover-on-lifecycle-state-resumed-failure-and-recovery.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/8-2-goal-history-consumer-migration.md` § maybeNotifyGoalReachedIfGoalMet]
- [Source: `_bmad-output/implementation-artifacts/stories/2-7-daily-goal-local-notification.md`]
- [Source: `lib/core/services/background_collector.dart` L152–198]
- [Source: `lib/core/services/notification_service.dart` L130–158]
- [Source: `test/core/services/background_collector_test.dart` — existing indirect notification tests]
- [Source: `docs/project-context.md` § Test commands, Story completion checklist]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Sub-task A: `rg maybeNotifyGoalReachedIfGoalMet test/` → 0 hits before implementation; indirect coverage via `collectOnce(enableGoalNotification: true)` at L311–518
- `showGoalReached` returns `true` on success, `false` on permission skip / init failure / caught presenter error (L130–158 notification_service.dart)

### Completion Notes List

- Added `group('maybeNotifyGoalReachedIfGoalMet')` with 3 direct-call tests (happy, not-met, rollback + retry)
- Extracted `_goalNotificationCollector` helper for DRY collector wiring
- AUD-52 grep passes (9 hits in background_collector_test.dart)
- 24/24 collector tests green; full fast suite green

### File List

- `test/core/services/background_collector_test.dart` — named AUD-52 group + helper
- `_bmad-output/implementation-artifacts/sprint-status-post-audit.yaml` — 26-3 → review

## Change Log

- 2026-07-19 — Story 26-3: named unit tests for `maybeNotifyGoalReachedIfGoalMet` (AUD-52)
