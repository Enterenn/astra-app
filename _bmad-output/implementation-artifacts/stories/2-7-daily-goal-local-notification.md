# Story 2.7: Daily Goal Local Notification

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want at most one local notification when my daily step goal is reached,
So that I can celebrate offline without notification spam.

## Acceptance Criteria

1. **Given** notification permission granted during onboarding
   **When** `BackgroundCollector` detects cumulative daily steps ≥ goal from SQLite aggregation (`getTodaySteps()` / `LocalDayCalculator`)
   **Then** at most one local notification fires per local calendar day (FR25)
   **And** evaluation uses daily sum — not a single bucket in isolation

2. **Given** notification permission denied
   **When** goal is reached
   **Then** no notification is attempted and app functions normally

3. **Given** goal notification fired (or foreground celebration already set `celebration_shown_date` for today)
   **When** user opens app later or collection runs again the same day
   **Then** no duplicate notification and no duplicate celebration replay

4. **Given** user is on Today with app in foreground during resume backfill
   **When** goal is newly crossed
   **Then** `GoalCelebration` handles acknowledgment (Story 2.6) — **no** local notification from the UI-isolate resume path (avoid notification-before-celebration race)

## Tasks / Subtasks

- [x] **Sub-task A — `NotificationService` + platform init** (AC: #1–#2)
  - [x] Add `lib/core/services/notification_service.dart`:
    - [x] Wrap `FlutterLocalNotificationsPlugin` (already in pubspec `^21.0.0`).
    - [x] `Future<void> initialize()` — Android channel + Darwin settings; use named params per v21 API (`InitializationSettings(android: …, iOS: …)`).
    - [x] Android channel id e.g. `astra_goal_reached`, name "Daily goal", importance default; **local only** — no FCM.
    - [x] `Future<bool> hasNotificationPermission()` — `Permission.notification.status` via injectable checker (same pattern as onboarding cubit).
    - [x] `Future<void> showGoalReached()` — title/body calm copy per UX: **"Daily goal reached"** (no coach language); stable notification id e.g. `1` for dedup at OS layer.
    - [x] `Future<bool> initializeForBackground()` — minimal re-init safe for WorkManager isolate (document: call after `WidgetsFlutterBinding.ensureInitialized()`).
  - [x] Call `notificationService.initialize()` in `main.dart` after `WidgetsFlutterBinding.ensureInitialized()`, before `AppDependencies.create()`.
  - [x] Verify Android: `POST_NOTIFICATIONS` already in manifest; desugaring already enabled in `android/app/build.gradle.kts` — no new Gradle deps unless plugin README requires receivers (add only if build fails).
  - [x] Unit tests in `test/core/services/notification_service_test.dart` with mocked plugin/permission checker — assert `showGoalReached` no-ops when permission denied.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Goal notification evaluation in `BackgroundCollector`** (AC: #1–#4)
  - [x] Extend `BackgroundCollector` constructor with optional dependencies (all nullable / no-op when absent for existing tests):
    - `UserPreferencesRepository? userPreferences`
    - `TimeProvider? clock`
    - `NotificationService? notificationService`
    - `Future<bool> Function()? notificationPermissionGranted`
  - [x] Add `collectOnce({int maxReadingsPerSource = 50, bool enableGoalNotification = false})` — **default `false`**.
  - [x] After successful upserts (`upsertedCount > 0`), when `enableGoalNotification == true` and deps present:
    1. Check notification permission → return early if denied (AC #2).
    2. Parallel or sequential: `getDailyStepGoal()`, `getTodaySteps()`, `getCelebrationShownDate()`.
    3. Compute `todayIso` via `formatLocalDayIso(clock!.snapshot())`.
    4. If `steps >= goal && goal > 0 && shownDate != todayIso`:
       - `await notificationService!.showGoalReached()`
       - `await userPreferences!.setCelebrationShownDate(todayIso)` **immediately** (coordinates with Story 2.6 dedup).
  - [x] Keep `_onIngestionComplete` callback unchanged — UI refresh still driven separately.
  - [x] Tests in `test/core/services/background_collector_test.dart`:
    - goal met + permission + pref unset → notification called once + pref written
    - pref already today → no notification
    - permission denied → no notification, no pref write
    - `enableGoalNotification: false` → never evaluates (existing tests unchanged)
    - steps < goal → no notification
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — DI wiring + foreground/resume call sites** (AC: #3–#4)
  - [x] Extend `AppDependencies` with `NotificationService notificationService`; wire in `create()` and `test()`.
  - [x] Pass full goal-notification deps into `BackgroundCollector` in both factories.
  - [x] **`main.dart` / `AstraApp` call-site policy (critical):**
    | Call site | `enableGoalNotification` |
    |-----------|--------------------------|
    | Cold-start `_collectForegroundBackfill()` | `true` (app may be closed/minimized path) |
    | Resume `_collectAndRefreshToday()` | `false` — let `TodayCubit` celebration win (AC #4) |
    | WorkManager task (Sub-task D) | `true` |
  - [x] Update `test/core/di/app_dependencies_test.dart` for `notificationService` exposure.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — WorkManager isolate bootstrap** (AC: #1, #3)
  - [x] In `runStepCollectionWorkmanagerTask`:
    - [x] After DB open: construct `UserPreferencesRepository(db)`.
    - [x] `await notificationService.initializeForBackground()` (or shared init helper).
    - [x] Pass `userPreferences`, `clock`, `notificationService`, permission checker into `BackgroundCollector`.
    - [x] `await collector.collectOnce(enableGoalNotification: true)`.
  - [x] Extend `test/core/services/workmanager_callback_test.dart` (or add) — fake notification service records show call when goal met in WM bootstrap path.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Verification + docs** (AC: #1–#4)
  - [x] Run `flutter analyze` and `flutter test`.
  - [ ] Manual Android (physical device preferred):
    - Grant notification during onboarding → inject/walk to cross goal with app backgrounded → one notification; reopen → no second notification; Today shows full ring (celebration suppressed if pref set by notification).
    - Deny notification → goal crossed → no notification; foreground Today still shows celebration when opened.
    - Resume while on Today → celebration plays, no notification banner spam.
  - [x] Update `docs/DEPENDENCIES.md` if manifest/receiver entries added for `flutter_local_notifications`.
  - [x] Review brief documents Epic 2 complete; Epic 3 next.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 2.7:**
- `NotificationService` — local goal notification only (FR25)
- Goal evaluation hook in `BackgroundCollector` after bucket upserts
- `celebration_shown_date` write on notification (shared dedup with Story 2.6)
- `flutter_local_notifications` initialization (UI + WorkManager isolates)
- Permission gate — no request UI (onboarding handled FR24 in Story 1.5)
- Foreground/resume vs background notification policy (AC #4)

**Out of scope — defer to later stories:**
- `BackgroundHealthCapabilityEvaluator`, OEM battery deep-links, `BackgroundStatusCard` → **Story 4.2**
- Continuous Android FGS runtime notification UX → separate from goal notification (UX §4.5 edge case)
- Re-request notification permission from My Data → not Phase 0
- Scheduled/reminder notifications, streak nudges, coach copy → never
- iOS BGAppRefresh goal notification parity → best-effort via foreground backfill + WM N/A on iOS; document honest limitation
- Epic 6 `flutter_local_notifications` FCM audit → **Story 6.2** (confirm local-only)

Do not over-implement. This story is **one-shot goal notification + dedup** — not a general notification framework.

### Pipeline position (Epic 2 — final story)

```text
BackgroundCollector.collectOnce(enableGoalNotification: true)
        │
        ├─ upsert buckets (existing)
        │
        v
_maybeNotifyGoalReached()
        │
        ├─ permission granted?
        ├─ getTodaySteps() >= getDailyStepGoal() ?
        ├─ celebration_shown_date != todayIso ?
        │
        v
NotificationService.showGoalReached()
setCelebrationShownDate(todayIso)
        │
        v
(later) TodayCubit.refresh()
        │
        └─ pref == today → showCelebration: false (Story 2.6)
```

Stories 2.1–2.6 delivered schema, collection, Today UI, and celebration. Story 2.7 completes Epic 2 passive tracking loop.

### Architecture contracts (must match exactly)

**Notification flow** ([Source: `architecture.md` — Notifications & Goal Celebration]):

| Trigger | Mechanism |
|---------|-----------|
| Goal reached (background / WM / cold-start backfill) | `BackgroundCollector` after upsert → `getTodaySteps()` → if ≥ goal and pref ≠ today → `showGoalReached()` + `setCelebrationShownDate` |
| Goal reached (foreground resume on Today) | `TodayCubit` → `GoalCelebration` (2.6); collector called with `enableGoalNotification: false` |
| Dedup | `celebration_shown_date` local ISO day; reset at local midnight via `TimeProvider` |

**Evaluation:** Cumulative daily steps from `timeseries_samples` via `StepRepository.getTodaySteps()` — uses `LocalDayCalculator` per row. **Never** evaluate from single bucket delta.

**Single-writer rule:** Only `UserPreferencesRepository` writes `user_preferences`. Collector calls repo methods.

**Time semantics:** `formatLocalDayIso(clock.snapshot())` — never `DateTime.now()` for dedup key.

**DI:** `AppDependencies` holds `NotificationService` singleton ([Source: `architecture.md` — D-03 DI table]).

**Inter-process:** WorkManager isolate opens own DB + own notification plugin init — no shared memory with UI isolate.

### Notification copy (UX locked)

| Field | Value |
|-------|-------|
| Title | `Daily goal reached` |
| Body | Optional subtitle with step count e.g. `{steps} steps today` — or empty/minimal; **never** coach copy ("Amazing!", "Keep going!") |
| Tone | Calm acknowledgment — matches `GoalCelebration` micro-copy (UX §2.3.1, UX-DR6 relation) |

### Current code state

| Path | Current state | What 2.7 changes | Must preserve |
|------|---------------|-------------------|---------------|
| `lib/core/services/background_collector.dart` | Ingestion only; optional `_onIngestionComplete` | Add goal notification evaluation; `enableGoalNotification` flag | `_collectInFlight` guard; timeout bounds; sole upsert caller |
| `lib/core/services/workmanager_callback.dart` | WM bootstrap without prefs/notifications | Add `UserPreferencesRepository`, `NotificationService`, `enableGoalNotification: true` | `@pragma('vm:entry-point')`; `ensureInitialized`; isolate DB factory |
| `lib/core/di/app_dependencies.dart` | No `NotificationService` | Add service + wire collector deps | Existing test factory pattern |
| `lib/main.dart` | WM register only | Init notifications before deps | `WidgetsFlutterBinding.ensureInitialized()` order |
| `lib/app.dart` | `collectOnce()` on start + resume | Pass `enableGoalNotification` per call-site policy | Resume refresh order (collect then cubit refresh) |
| `lib/presentation/cubits/today_cubit.dart` | Celebration via pref (2.6) | **No notification calls here** | `_maybeTriggerCelebration` pref logic unchanged |
| `lib/data/repositories/user_preferences_repository.dart` | `get/setCelebrationShownDate` exist | Used by collector — no API change expected | Sole writer |
| `lib/core/services/notification_service.dart` | **Does not exist** | **NEW** | — |
| `android/app/src/main/AndroidManifest.xml` | `POST_NOTIFICATIONS` present | Add plugin receivers only if required by build | No INTERNET permission |
| `android/app/build.gradle.kts` | Desugaring enabled | Likely no change | Java 17 compat |

### Recommended file layout

```text
lib/core/services/notification_service.dart              # NEW
lib/core/services/background_collector.dart              # UPDATE
lib/core/services/workmanager_callback.dart              # UPDATE
lib/core/di/app_dependencies.dart                        # UPDATE
lib/main.dart                                            # UPDATE
lib/app.dart                                             # UPDATE (enableGoalNotification flags)

test/core/services/notification_service_test.dart        # NEW
test/core/services/background_collector_test.dart        # UPDATE
test/core/services/workmanager_callback_test.dart        # UPDATE (or NEW)
test/core/di/app_dependencies_test.dart                  # UPDATE
```

### Goal notification evaluation sketch (suggested)

```dart
Future<void> _maybeNotifyGoalReached() async {
  final prefs = userPreferences;
  final notifications = notificationService;
  final time = clock;
  final permissionCheck = notificationPermissionGranted;
  if (prefs == null || notifications == null || time == null || permissionCheck == null) {
    return;
  }

  if (!await permissionCheck()) return;

  final todayIso = formatLocalDayIso(time.snapshot());
  if (await prefs.getCelebrationShownDate() == todayIso) return;

  final goal = await prefs.getDailyStepGoal();
  if (goal <= 0) return;

  final steps = await repository.getTodaySteps();
  if (steps < goal) return;

  await notifications.showGoalReached();
  await prefs.setCelebrationShownDate(todayIso);
}
```

Invoke only when `enableGoalNotification && upsertedCount > 0`.

### Coordination with Story 2.6 (already implemented)

- **Notification-first path:** User backgrounded → WM fires notification → sets pref → opens Today → no celebration replay (2.6 AC #3) ✓
- **Celebration-first path:** User on Today → resume uses `enableGoalNotification: false` → cubit sets pref → WM later sees pref → no notification ✓
- **Do not** add notification calls to `TodayCubit` — keeps presentation layer read-only for notifications.

### Architecture compliance

| Decision / invariant | Requirement for 2.7 |
|----------------------|---------------------|
| D-03 | `NotificationService` in `AppDependencies`; collector uses repos |
| D-12 | `flutter_local_notifications` local only, ^21.0.0 |
| D-25 | Local day from `TimeProvider.snapshot()` |
| FR25 | Max one notification per local day from SQLite aggregation |
| FR24 | No new permission prompts — check status only |
| UX §2.3.1 | Calm "Daily goal reached" copy; independent from celebration widget |
| UX §4.5 | Goal notification ≠ Android FGS health system notification |

### Anti-patterns

- Do not call `showGoalReached()` from `TodayCubit` or widgets.
- Do not evaluate goal from last bucket `value` alone — use `getTodaySteps()`.
- Do not request notification permission outside onboarding (FR24 already done).
- Do not use FCM, Firebase, or scheduled notification plugins.
- Do not add a second dedup key — reuse `celebration_shown_date` only.
- Do not enable goal notification on resume path (`_collectAndRefreshToday`) — breaks celebration UX.
- Do not block `main()` indefinitely on notification init — await with timeout/logging on failure; app must remain usable if init fails (permission denied is normal).
- Do not share static `FlutterLocalNotificationsPlugin` singleton across isolates without per-isolate init.

### Testing requirements

| Area | Requirement |
|------|-------------|
| `notification_service` | Permission denied → no show; granted → show called with correct copy |
| `background_collector` | Goal met + flag true → notify + pref; pref set → skip; flag false → skip |
| `workmanager_callback` | Bootstrap passes deps; `enableGoalNotification: true` |
| `app_dependencies` | `notificationService` exposed |
| Regression | All Story 2.6 tests pass unchanged; `today_cubit` celebration dedup still works |

Run: `flutter analyze`, `flutter test`

### Previous story intelligence (2.6)

- `celebration_shown_date` pref API complete — **reuse**, do not rename.
- `formatLocalDayIso` in `lib/core/time/local_day_formatter.dart` — use for dedup key.
- `TodayCubit._maybeTriggerCelebration` persists pref immediately — same pattern for notification path.
- Code review fix: preserve in-flight celebration on silent refresh — notification path must not clear `showCelebration` (collector doesn't touch cubit).
- Review gate: **one commit per sub-task** after Baptiste OK ([Source: `docs/project-context.md`]).
- 162+ tests at 2.6 completion — maintain green suite.

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `feat(today): complete story 2.6 with code review fixes` | Celebration + pref dedup stable — build notification on same pref |
| `feat(today): trigger goal celebration once per local day in TodayCubit` | Foreground path owner — do not duplicate |
| `feat(today): wire GoalCelebration into TodayScreen` | UI integration complete — no notification UI needed |

### Library / framework requirements

| Package | Version | Usage |
|---------|---------|-------|
| flutter_local_notifications | ^21.0.0 | Already in pubspec — init + show |
| permission_handler | ^12.0.1 | Already used — `Permission.notification.status` |
| workmanager | ^0.9.0+3 | Background isolate — re-init notifications |

**No new pubspec dependencies** expected unless plugin requires explicit platform package.

### Latest technical notes (flutter_local_notifications 21.x)

- **API:** Use named parameters — `initialize(settings: initializationSettings, onDidReceiveNotificationResponse: …)`.
- **Android:** Plugin v21 bumps `compileSdk` expectations; project uses `flutter.compileSdkVersion` + desugaring — verify `flutter build apk` after wiring.
- **Background isolate:** Call `WidgetsFlutterBinding.ensureInitialized()` + `DartPluginRegistrant.ensureInitialized()` before plugin init (same as sqflite/pedometer in WM).
- **Release mode:** Ensure `@mipmap/ic_launcher` or `@drawable` icon referenced in `AndroidInitializationSettings` exists — missing drawable can hang release init (known plugin issue); use existing launcher icon.
- **iOS:** `permission_handler` SPM enables notifications; request already handled in onboarding — init Darwin settings even if iOS beta is secondary.
- **Dedup at OS level:** Reuse notification id `1` for goal channel so re-show replaces rather than stacks.

### Project context reference

- Review-before-commit workflow mandatory per sub-task.
- Baptiste is Flutter novice — review briefs should explain `FlutterLocalNotificationsPlugin`, notification channels, and isolate init.
- [Source: `docs/project-context.md`]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — Notifications & Goal Celebration, D-12, WorkManager spike]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §2.3.1, §4.5]
- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 2.7 AC]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` — FR-25]
- [Source: `_bmad-output/implementation-artifacts/stories/2-6-goal-celebration-animation.md` — pref coordination]
- [Source: `_bmad-output/implementation-artifacts/stories/2-4-background-collector-and-android-workmanager.md` — WM bootstrap pattern]

## Dev Agent Record

### Agent Model Used

Composer (Cursor)

### Debug Log References

- Goal notification tests: avoid bucket time-window collisions when pre-seeding SQLite; inject `permissionChecker` on test `NotificationService` instances.

### Completion Notes List

- Added `NotificationService` (local channel `astra_goal_reached`, id `1`, calm copy) with injectable permission/presenter for tests.
- `BackgroundCollector.collectOnce(enableGoalNotification:)` evaluates `getTodaySteps()` vs goal after upserts; writes `celebration_shown_date` on notify (Story 2.6 dedup).
- Call-site policy: cold-start + WorkManager `true`; resume on Today `false`.
- `flutter analyze` clean; **180** tests pass. Manual Android device checks deferred to Baptiste.
- No manifest/DEPENDENCIES changes (POST_NOTIFICATIONS already present; no extra receivers required).
- Code review fixes: atomic `tryClaimCelebrationShownDate`, notify-before-callback ordering, goal eval without upserts, cold-start backfill coordination, init timeout.

### File List

- lib/core/services/notification_service.dart (new)
- lib/core/services/background_collector.dart
- lib/core/services/workmanager_callback.dart
- lib/core/di/app_dependencies.dart
- lib/main.dart
- lib/app.dart
- lib/data/repositories/user_preferences_repository.dart
- lib/presentation/cubits/today_cubit.dart
- lib/presentation/screens/app_scaffold.dart
- test/core/services/notification_service_test.dart (new)
- test/core/services/background_collector_test.dart
- test/core/services/workmanager_callback_test.dart
- test/core/di/app_dependencies_test.dart
- test/data/repositories/user_preferences_repository_test.dart

### Change Log

- 2026-06-02: Story 2.7 — daily goal local notification + dedup via `celebration_shown_date`; Epic 2 passive loop complete.
- 2026-06-02: Code review — race/dedup fixes; story done.

## Story completion status

- Ultimate context engine analysis completed — comprehensive developer guide created
- Status: **done**
