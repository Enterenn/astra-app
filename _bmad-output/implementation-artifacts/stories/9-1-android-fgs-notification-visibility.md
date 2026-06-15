# Story 9.1: Android FGS Notification Visibility

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want the step-tracking notification to be as discreet as Android allows,
So that passive tracking feels honest but not nagging.

## Acceptance Criteria

1. **Given** `HealthStepForegroundService` is running on Android
   **When** the foreground notification is displayed
   **Then** channel importance is minimized (`IMPORTANCE_MIN` or lowest compatible with FGS health on target SDK)
   **And** notification uses `PRIORITY_MIN` / low visibility flags, `setShowBadge(false)`, `setOnlyAlertOnce(true)`
   **And** copy remains honest (not disguised as sync/backup) — title/body may be shortened vs current

2. **Given** FGS health collection loop
   **When** this story ships
   **Then** `COLLECTION_INTERVAL_MS` and Dart collection bridge unchanged
   **And** `test/core/services/fgs_step_collection_test.dart` and `health_foreground_notification_test.dart` pass (updated expectations if copy/channel change)

3. **Given** manual test on physical Android device
   **When** app backgrounded with activity permission granted
   **Then** steps still accumulate within expected WM/FGS interval

## Tasks / Subtasks

- [x] **Sub-task A — Kotlin notification channel + builder tuning** (AC: #1)
  - [x] In `HealthStepForegroundService.kt` `ensureNotificationChannel()`:
    - [x] Set channel importance to **lowest FGS-compatible level** — see Android guardrail below (likely keep `IMPORTANCE_LOW`; do **not** use `IMPORTANCE_MIN` if it triggers the system battery warning).
    - [x] Add quiet channel flags: `enableVibration(false)`, `enableLights(false)`, `setSound(null, null)` where API permits.
    - [x] Keep `setShowBadge(false)` (already present).
  - [x] In `buildForegroundNotification()`:
    - [x] Apply lowest compatible `NotificationCompat` priority (`PRIORITY_LOW` minimum per Android FGS docs — verify `PRIORITY_MIN` does not trigger extra system warning).
    - [x] Add low-visibility flags: `setOnlyAlertOnce(true)` (keep), consider `setSilent(true)`, `setVisibility(NotificationCompat.VISIBILITY_SECRET)` for lock-screen discretion.
    - [x] Shorten title/body copy — honest health tracking, no sync/backup/coach language (UX §3.12).
  - [x] **Do not** change `CHANNEL_ID`, `NOTIFICATION_ID`, `COLLECTION_INTERVAL_MS`, service lifecycle, or `foregroundServiceType="health"`.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Dart mirror constants + tests** (AC: #1, #2)
  - [x] Update `lib/core/services/health_foreground_notification.dart` to match Kotlin copy constants exactly (single source of truth for Dart tests/docs).
  - [x] Update `test/core/services/health_foreground_notification_test.dart`:
    - [x] Assert new shortened copy.
    - [x] Keep assertions: channel id ≠ goal channel; combined copy excludes `sync`, `update`, `backup`.
  - [x] Run `flutter test test/core/services/health_foreground_notification_test.dart test/core/services/fgs_step_collection_test.dart test/android/android_manifest_test.dart`.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Documentation** (AC: #1)
  - [x] Update `docs/DEPENDENCIES.md` health FGS section with new copy and visibility notes.
  - [x] Note Android channel persistence caveat (existing installs retain user-modified channel settings).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Physical device verification** (AC: #3) — *waived by Baptiste at story close*
  - [x] On physical Android device: background app, confirm notification is less intrusive than before.
  - [x] Walk ≥100 steps or wait one `COLLECTION_INTERVAL_MS` (60s) cycle; confirm SQLite buckets advance / Today total increases on reopen.
  - [x] Record device model, Android version, pass/fail in Dev Agent Record.
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Epic close version bump** (Epic 9 policy)
  - [x] Bump `pubspec.yaml` to `0.2.2+4` and `README.md` project status row (Fix epic — patch+1, build+1).
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope (9.1):**
- Kotlin FGS notification channel importance, builder flags, and copy in `HealthStepForegroundService.kt`
- Dart mirror constants in `health_foreground_notification.dart` + unit tests
- `docs/DEPENDENCIES.md` update
- Physical device smoke test for collection continuity

**Out of scope — do not touch:**
- `COLLECTION_INTERVAL_MS` (currently `60L * 1000L` — 60s; do not change)
- `runFgsStepCollectionCycle`, `fgs_step_collection.dart`, `BackgroundCollector` write path
- `HealthForegroundServiceCoordinator` lifecycle (pause start / resume stop)
- `HealthForegroundChannel.kt` method channel contract
- `AndroidManifest.xml` FGS declarations (`foregroundServiceType="health"`, permissions)
- WorkManager registration, `BackgroundHealthCapabilityEvaluator`, My Data UI
- Goal notification channel (`astra_goal_reached`, id `1`) — separate concern (Story 2.7)
- iOS (all FGS APIs no-op on iOS)

This is a **Kotlin notification UX tuning** story — not a pipeline refactor.

### Business context

Epic 9 addresses post-beta feedback: the health FGS notification is technically correct (Story 2.8) but visually intrusive. Users accepted passive tracking during onboarding; the ongoing system notification should be as discreet as Android allows without breaking collection or misrepresenting the work (sprint-change-proposal §4.6).

**Epic 9 versioning:** Fix epic — bump to `0.2.2+4` at epic close (this story is the only story in Epic 9).

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 9.1 changes | Must preserve |
|------|---------------|------------------|---------------|
| `android/.../HealthStepForegroundService.kt` | Channel `IMPORTANCE_LOW`; builder `PRIORITY_LOW`; title `"Step tracking active"`; body `"Counting steps in the background on this device."`; `setShowBadge(false)`, `setOnlyAlertOnce(true)`; `COLLECTION_INTERVAL_MS = 60s` | Tune importance/priority/visibility flags; shorten copy | Service lifecycle, FGS type, collection loop, channel id `astra_health_tracking`, notification id `100` |
| `lib/core/services/health_foreground_notification.dart` | Dart mirror of Kotlin constants | Sync copy after Kotlin change | Channel id, notification id, separation from goal channel |
| `lib/core/services/health_foreground_service.dart` | Coordinator — start/stop on pause/resume | **No change** | Method channel API, single-writer matrix |
| `lib/core/services/fgs_step_collection.dart` | `runFgsStepCollectionCycle` isolate bootstrap | **No change** | Collection logic, `skipPhoneSourceWhenUiActive` |
| `android/.../HealthForegroundChannel.kt` | Platform channel; `requestDartCollection` gated on `uiActive` | **No change** | Channel name, method names |
| `test/core/services/health_foreground_notification_test.dart` | Asserts current copy + channel separation | Update copy expectations | Honest-copy guard (no sync/backup) |
| `test/android/android_manifest_test.dart` | Asserts health FGS manifest | **No change expected** | No `dataSync` type |
| `docs/DEPENDENCIES.md` | Documents FGS components + copy | Update copy/visibility notes | Architecture roles |

### Android FGS notification guardrails (CRITICAL)

**Do not use `IMPORTANCE_MIN` for foreground service notifications.** Android docs state that FGS notifications on `IMPORTANCE_MIN` channels trigger an **additional** higher-priority system warning ("app running in background / using battery") — worse UX than `IMPORTANCE_LOW`.

| Setting | Minimum for FGS | Current | Action |
|---------|-----------------|---------|--------|
| Channel importance | `IMPORTANCE_LOW` | `IMPORTANCE_LOW` | Keep or document why unchanged; add quiet channel flags |
| Builder priority | `PRIORITY_LOW` | `PRIORITY_LOW` | Try `PRIORITY_MIN` only if physical device shows no extra system warning |
| `setShowBadge(false)` | Required | ✓ | Keep |
| `setOnlyAlertOnce(true)` | Required | ✓ | Keep |

**Channel persistence:** Once `NotificationManager.createNotificationChannel()` runs, users can override importance in system settings. Re-running `createNotificationChannel` with the same id does **not** reset user overrides. For QA: test on fresh install or clear app notification settings.

**Recommended shorter copy (starting point — adjust if still too long):**

| Field | Current | Suggested |
|-------|---------|-----------|
| Title | `Step tracking active` | `Tracking steps` |
| Body | `Counting steps in the background on this device.` | `Background step count on this device.` |

Any copy must pass `health_foreground_notification_test.dart` honest-language guards.

### Notification separation (must not regress)

| Notification | Channel | Id | Purpose |
|--------------|---------|-----|---------|
| Goal reached | `astra_goal_reached` | `1` | FR-25 one-shot celebration |
| Health FGS | `astra_health_tracking` | `100` | System-required ongoing health work |

Never reuse goal channel for FGS. Never disguise health tracking as "sync", "update", or "backup".

### Architecture compliance

- **D-04:** FGS health + WorkManager coexistence unchanged — WM remains fallback orchestrator.
- **FR-6:** `FOREGROUND_SERVICE_HEALTH` manifest compliance unchanged.
- **FR-4:** Passive collection contract unchanged — FGS periodic `collectOnce` every 60s.
- **UX §3.12:** FGS notification is system-required background health work — separate from goal celebration (FR-25).

[Source: `_bmad-output/planning-artifacts/architecture.md` — D-04, Notifications & Goal Celebration]
[Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` — §4.6 FGS notification]

### File structure requirements

```
android/app/src/main/kotlin/com/astraapp/astra_app/
  HealthStepForegroundService.kt   # UPDATE — channel + notification builder + copy constants
  HealthForegroundChannel.kt       # READ ONLY — do not change

lib/core/services/
  health_foreground_notification.dart  # UPDATE — mirror Kotlin copy constants
  health_foreground_service.dart       # READ ONLY
  fgs_step_collection.dart             # READ ONLY

test/core/services/
  health_foreground_notification_test.dart  # UPDATE — copy expectations

docs/DEPENDENCIES.md                 # UPDATE — FGS copy/visibility notes
```

### Testing requirements

**Automated (CI):**
```bash
flutter analyze
flutter test test/core/services/health_foreground_notification_test.dart
flutter test test/core/services/fgs_step_collection_test.dart
flutter test test/android/android_manifest_test.dart
flutter test  # full suite — ingest/FGS/live monitor must stay green
```

**Manual (physical device — AC #3):**
1. Fresh debug install or cleared notification channel settings.
2. Grant `ACTIVITY_RECOGNITION` (+ `POST_NOTIFICATIONS` on API 33+).
3. Complete onboarding; background app (`Home` key).
4. Observe notification shade — confirm less intrusive than pre-change baseline.
5. Walk or wait ≥60s; reopen app — Today total or `getLastIngestionUtc()` advanced.
6. Record device model + Android version in Dev Agent Record.

**Regression guard:** Story 8.2 explicitly required FGS tests to stay green with no ingest changes — same applies here.

### Previous story intelligence (Epic 8 — most recent work)

Epic 8 (Stories 8.1–8.2) touched goal history and consumer migration. Relevant learnings for 9.1:

- **Ingestion path is frozen:** `BackgroundCollector.collectOnce`, FGS bridge, and WM callback were explicitly out of scope in 8.2 — do not modify.
- **Review-before-commit gate:** Implement sub-tasks sequentially; stop for Baptiste OK after each (project-context § Development Workflow).
- **Test discipline:** Full `flutter test` was required at story close; FGS/live-monitor suites must remain green.
- **Version bump timing:** Epic 8 bumped to `0.2.1+3` at epic close — Epic 9 bumps to `0.2.2+4` when this story completes (Sub-task E).

[Source: `_bmad-output/implementation-artifacts/stories/8-2-goal-history-consumer-migration.md`]

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `c784255` chore: close Epic 8 at v0.2.1+3 | Current version baseline; Epic 9 targets `0.2.2+4` |
| `39b36c4` fix(collector): journal goal for background notification | FGS goal notification uses `getGoalForLocalDay` — unrelated to FGS *ongoing* notification copy |
| Stories 2.8 FGS pipeline | Established `HealthStepForegroundService.kt` + Dart coordinator — 9.1 tunes notification only |

### Latest technical information (Android FGS notifications)

- **Android 14+ (API 34):** Health FGS requires `FOREGROUND_SERVICE_HEALTH` permission + `ServiceCompat.startForeground(..., FOREGROUND_SERVICE_TYPE_HEALTH)` — already implemented; do not change.
- **Channel importance floor:** `IMPORTANCE_LOW` is the practical minimum for FGS; `IMPORTANCE_MIN` causes system to post a **second** warning notification ([NotificationManager.IMPORTANCE_MIN](https://developer.android.com/reference/android/app/NotificationManager#IMPORTANCE_MIN)).
- **Builder priority floor:** FGS status notification requires `PRIORITY_LOW` or higher; lower priority triggers system drawer warning ([Launch a foreground service](https://developer.android.com/develop/background-work/services/fgs/launch)).
- **Health FGS permission:** `ACTIVITY_RECOGNITION` runtime grant required before start — already gated in `HealthForegroundServiceCoordinator.startHealthCollectionService()`.

### Project context reference

- Review-before-commit workflow mandatory (docs/project-context.md § Development Workflow).
- Version bump at epic close: `pubspec.yaml` + `README.md` (`.cursor/rules/app-versioning.mdc`).
- Solo developer — review briefs should explain Flutter/Android concepts pedagogically.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Epic 9, Story 9.1]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-15.md` — §4.6, versioning table]
- [Source: `_bmad-output/implementation-artifacts/stories/2-8-android-fgs-health-passive-pipeline.md` — FGS implementation baseline]
- [Source: `android/app/src/main/kotlin/com/astraapp/astra_app/HealthStepForegroundService.kt`]
- [Source: `lib/core/services/health_foreground_notification.dart`]
- [Source: `docs/DEPENDENCIES.md` — Health foreground service section]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Implementation Plan

**Sub-task A (Kotlin):** Tuned `ensureNotificationChannel()` with quiet flags (`enableVibration(false)`, `enableLights(false)`, `setSound(null, null)`); kept `IMPORTANCE_LOW` per Android FGS guardrail. Tuned `buildForegroundNotification()` with `setSilent(true)`, `VISIBILITY_SECRET`, kept `PRIORITY_LOW`. Shortened copy to "Tracking steps" / "Background step count on this device." Committed `e868017`.

**Sub-task B (Dart):** Synced `health_foreground_notification.dart` copy constants; updated unit test expectations. FGS test suite 6/6 green. Committed `fd57de7`.

**Sub-task C (Docs):** Updated `docs/DEPENDENCIES.md` with new copy, visibility flags, 60s interval correction, channel persistence caveat. Committed `c4d9bf9`.

**Sub-task D (Device):** Waived by Baptiste at story close — physical smoke test deferred to post-review manual check.

**Sub-task E (Version):** Bumped `pubspec.yaml` and `README.md` to `0.2.2+4` (Epic 9 fix epic close).

### Completion Notes List

### File List

- `android/app/src/main/kotlin/com/astraapp/astra_app/HealthStepForegroundService.kt` (modified — Sub-task A)
- `lib/core/services/health_foreground_notification.dart` (modified — Sub-task B)
- `test/core/services/health_foreground_notification_test.dart` (modified — Sub-task B)
- `docs/DEPENDENCIES.md` (modified — Sub-task C)
- `pubspec.yaml` (modified — Sub-task E)
- `README.md` (modified — Sub-task E)

## Story Completion Status

- Ultimate context engine analysis completed — comprehensive developer guide created
- Status: **review** — Epic 9 implementation complete; AC #3 device smoke test waived at close
