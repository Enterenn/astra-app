# Story 31.1: Model permanentlyDenied with Settings CTA

Status: in-progress

<!-- audits_2 Epic 31 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 31-1 · diagnostic-permissions-notifications.md #1 · AUD2-FR7 · AUD2-FR9 · AUD2-UX1 · AUD2-UX2 -->
<!-- Prerequisite: Epic 30 done · base 0.13.1+33 -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **user**,
I want the app to tell me when a permission is permanently denied and open Settings,
So that I am not stuck with a silent toggle or button.

## Acceptance Criteria

1. **Given** activity or notification permission in `permanentlyDenied` state
   **When** user interacts with Settings notification toggle, Today permission slot, or My Data background card
   **Then** UI distinguishes permanent vs reversible denial — AUD2-FR7, AUD2-UX1, AUD2-UX2
   **And** permanent denial shows CTA calling `openAppSettings()` with clear copy (not generic error-only snackbar)

2. **Given** reversible `denied` (not permanent) for **activity** permission
   **When** user taps CTA on Today / My Data permission UI
   **Then** `.request()` retry is offered where platform allows — AUD2-FR9
   **And** after grant, screen/cubit refreshes so tracking resumes without app restart

3. **Given** reversible `denied` for **notification** permission on Settings toggle
   **When** user enables goal notifications and OS returns reversible deny after `.request()`
   **Then** UI shows actionable feedback (retry-oriented copy or inline hint) — not the same message as permanent deny
   **And** toggle reverts to off (persisted pref unchanged)

4. **Given** `PermissionRequestStatus` enum used across onboarding and post-onboarding flows
   **When** platform status is `isPermanentlyDenied`
   **Then** app maps to `PermissionRequestStatus.permanentlyDenied` (new value) — not collapsed into `denied`

5. **Given** existing `@Tags critical` tests and localized widget/cubit tests for touched files
   **When** this story ships
   **Then** `flutter test --tags critical` passes
   **And** targeted tests cover permanent vs reversible paths for Settings, Today, and My Data

**Covers:** AUD2-FR7 · AUD2-FR9 · AUD2-UX1 · AUD2-UX2 · diagnostic-permissions-notifications.md #1 (partial — post-onboarding retry path)

**Depends on:** Epic 30 done (independent of E29 persist path).

**Out of scope (later Epic 31 stories):**
- Onboarding intro post-denial feedback / blocking auto-advance → **31-2** (`onboarding_flow.dart`)
- `_initializePlatform` rethrow → **31-3**
- Full centralized mapper + platform-exception distinction → **31-4**
- Boot WM cancel gate → **31-5**
- Profile toggle concurrency / background init timeout → **31-6**

## Tasks / Subtasks

- [x] **Sub-task A — Extend permission model + activity resolver** (AC: #4)
  - [x] Read fully: `onboarding_state.dart`, `activity_permission_resolver.dart`, `onboarding_cubit.dart` (`_mapPermissionStatus`)
  - [x] Add `permanentlyDenied` to `PermissionRequestStatus` enum
  - [x] Add `resolveActivityPermissionStatus()` (async) in `activity_permission_resolver.dart` returning `PermissionRequestStatus` (`idle`/`requesting` stay caller-owned)
  - [x] Map: granted path = `isGranted || isLimited || isProvisional` (preserve current behaviour until 31-4); `isPermanentlyDenied` → `permanentlyDenied`; else → `denied`
  - [x] Update `OnboardingCubit._mapPermissionStatus` to use shared mapper (minimal — onboarding UI feedback is 31-2)
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — ProfileCubit + Settings notification UX** (AC: #1, #3)
  - [x] Read fully: `profile_cubit.dart` (`setGoalNotificationsEnabled`), `settings_screen.dart` (notification Switch + SnackBar), `notification_service.dart` (`hasNotificationPermission`)
  - [x] Introduce result type, e.g. `NotificationToggleResult { success, deniedReversible, deniedPermanent }` — do **not** overload `bool` return
  - [x] After `.request()`, read `Permission.notification.status` (or injected checker) and map `isPermanentlyDenied`
  - [x] Settings: on `deniedPermanent` → SnackBar with **Open settings** action (`openAppSettings()`); on `deniedReversible` → distinct copy (retry hint)
  - [x] Preserve: disabling notifications without permission request; `isClosed` guards; no exception to UI
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task C — Today + My Data activity permission CTAs** (AC: #1, #2)
  - [ ] Read fully: `today_state.dart`, `today_refresh_service.dart`, `today_screen.dart` (`_PermissionDeniedSlot`), `my_data_cubit.dart` (`_deriveBackgroundStatus`), `background_status_card.dart`, `my_data_screen.dart`
  - [ ] Plumb `PermissionRequestStatus` (or narrowed `ActivityPermissionDenial { reversible, permanent }`) into `TodayState` when `status == noPermission`
  - [ ] Plumb same into `MyDataState` when `backgroundStatus == permissionDenied` (field or sub-enum — avoid overloading `BackgroundCollectionStatus` if it conflates iOS/stale)
  - [ ] `BackgroundStatusCard`: permanent → **Open settings**; reversible → **Retry** (`permission.request()` via injected callback from screen/cubit)
  - [ ] Today `_PermissionDeniedSlot`: same dual-CTA pattern; after successful grant → `TodayCubit.refresh()`
  - [ ] Add ARB keys (en/fr): permanent-denied copy, reversible-denied copy reuse `commonRetry` where appropriate
  - [ ] Run `flutter gen-l10n`
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task D — Tests + diagnostic partial close** (AC: #5)
  - [ ] `test/presentation/cubits/profile_cubit_test.dart`: `PermissionStatus.permanentlyDenied` → `deniedPermanent`; plain `denied` → `deniedReversible`
  - [ ] `test/presentation/screens/settings_screen_test.dart`: permanent path shows Open settings action
  - [ ] `test/presentation/cubits/today_cubit_test.dart` or widget test: reversible shows Retry key; permanent shows Open settings
  - [ ] `test/presentation/screens/my_data_screen_test.dart` or `background_status_card` widget test: dual CTA
  - [ ] Update `planning-artifacts/audits_2/diagnostic-permissions-notifications.md` #1 → `partial (31-1 post-onboarding; onboarding UI → 31-2)`; README row if tracked
  - [ ] Run: `flutter test test/presentation/cubits/profile_cubit_test.dart test/presentation/screens/settings_screen_test.dart` (+ other touched test files)
  - [ ] Run: `flutter test --tags critical`
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

**Zero `isPermanentlyDenied` usage in `lib/` today.** After permanent denial, `Permission.request()` is a no-op on Android — only `openAppSettings()` works. Current UI always routes to Settings even for first reversible deny, and notification toggle fails silently (`return false` + generic SnackBar).

| Location | Current behaviour | Gap |
|----------|-------------------|-----|
| `PermissionRequestStatus` | `{ idle, requesting, granted, denied }` | No `permanentlyDenied` — AUD2-FR7 |
| `ProfileCubit.setGoalNotificationsEnabled` | `return false` on any deny | No permanent vs reversible — AUD2-UX1 |
| `settings_screen.dart:322-327` | Generic `settingsNotificationUpdateError` SnackBar | No Settings CTA — AUD2-UX1 |
| `today_screen.dart:552` | Always `openAppSettings()` | No `.request()` retry — AUD2-FR9, AUD2-UX2 |
| `background_status_card.dart:83-90` | Always Open settings | Same — AUD2-UX2 |
| `isActivityRecognitionGranted()` | Boolean only | Callers cannot branch CTA |

[Source: `diagnostic-permissions-notifications.md` #1 · `epics-audits-2.md` Story 31-1]

### Recommended implementation

**1. Shared enum extension (minimal — 31-4 will centralize mappers):**

```dart
// onboarding_state.dart — keep name for now; 31-4 may extract to core/permissions/
enum PermissionRequestStatus {
  idle,
  requesting,
  granted,
  denied,
  permanentlyDenied,
}
```

**2. Activity status resolver (add to `activity_permission_resolver.dart`):**

```dart
Future<PermissionRequestStatus> resolveActivityPermissionStatus() async {
  final status = await resolveActivityPermission().status;
  if (status.isGranted || status.isLimited || status.isProvisional) {
    return PermissionRequestStatus.granted;
  }
  if (status.isPermanentlyDenied) {
    return PermissionRequestStatus.permanentlyDenied;
  }
  return PermissionRequestStatus.denied;
}
```

Keep `isActivityRecognitionGranted()` unchanged for hot paths — add parallel status read only where UI needs CTA branching.

**3. Notification toggle result (ProfileCubit):**

Replace `Future<bool>` with sealed result. Settings screen switches on outcome:

| Outcome | UI |
|---------|-----|
| `success` | No snackbar |
| `deniedReversible` | SnackBar — explain + optional "Try again" (re-tap switch) |
| `deniedPermanent` | SnackBar — `SnackBarAction(label: l10n.myDataOpenSettings, onPressed: openAppSettings)` |

Do **not** persist `goal_notifications_enabled=true` unless permission granted (existing invariant).

**4. Today / My Data plumbing:**

- Replace `activityPermissionGranted: () => Future<bool>` injection sites **only if needed** — prefer adding optional `activityPermissionStatus: () => Future<PermissionRequestStatus>` alongside bool checker in `TodayCubit` / `MyDataCubit` deps to avoid breaking all tests.
- On `noPermission` emit, set `activityPermissionDenial` from resolver.
- Screen passes `onRetryPermission: () async { await Permission.activityRecognition.request(); await cubit.refresh(); }` (use `resolveActivityPermission()` for platform).

**5. l10n (minimum new keys):**

| Key | EN (draft) | FR (draft) |
|-----|------------|------------|
| `settingsNotificationPermanentlyDenied` | Notifications blocked in system settings. Open settings to enable. | Notifications bloquées dans les paramètres système. Ouvrez les paramètres pour activer. |
| `settingsNotificationDeniedRetry` | Notification permission required. Try again. | Autorisation de notification requise. Réessayez. |
| `myDataBackgroundPermissionPermanentlyDenied` | Activity access blocked in system settings | Accès activité bloqué dans les paramètres système |
| `myDataBackgroundPermissionDeniedRetry` | Activity permission required for background sync | Autorisation d'activité requise pour la synchro |

Reuse `myDataOpenSettings` and `commonRetry` for button labels.

### Preserve (do not break)

| Behaviour | Must remain |
|-----------|-------------|
| Onboarding auto-advance on deny | Unchanged until **31-2** — only extend enum + mapper in cubit |
| `isActivityRecognitionGranted()` bool API | Keep for FGS/collector gates |
| Notification disable path | No permission prompt when turning off |
| ProfileCubit `isClosed` after every `await` | Mandatory |
| Injectable `permissionRequester` / `permissionChecker` in tests | Extend, don't remove |
| Epic 13 onboarding flow structure | No intro feedback UI in this story |

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-13: `permission_handler` ^12.0.1 | Use `status.isPermanentlyDenied` extension |
| Trust copy before permission | Retry CTA triggers `.request()` only on explicit tap |
| No network / no new packages | l10n + UI only |
| Token economy | Minimal new file surface — extend `activity_permission_resolver.dart`, avoid duplicate mappers (31-4 owns full centralization) |
| AUD2-NFR4 | Permission UX must never feel broken/silent |

[Source: `architecture.md` D-13, Permissions § · `epics-audits-2.md` AUD2-NFR4]

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/cubits/onboarding_state.dart` | Add `permanentlyDenied` enum value |
| `lib/core/permissions/activity_permission_resolver.dart` | Add `resolveActivityPermissionStatus()` |
| `lib/presentation/cubits/onboarding_cubit.dart` | Delegate `_mapPermissionStatus` to shared helper |
| `lib/presentation/cubits/profile_cubit.dart` | Result type for notification toggle; map permanent deny |
| `lib/presentation/cubits/profile_state.dart` | Only if needed for last toggle outcome (prefer result return over state) |
| `lib/presentation/screens/settings_screen.dart` | Branch SnackBar on toggle result |
| `lib/presentation/cubits/today_state.dart` | Optional `activityPermissionDenial` field |
| `lib/presentation/cubits/today/today_refresh_service.dart` | Resolve status when not granted |
| `lib/presentation/cubits/today_cubit.dart` | Wire status resolver dependency |
| `lib/presentation/screens/today_screen.dart` | Dual CTA in `_PermissionDeniedSlot` |
| `lib/presentation/cubits/my_data_state.dart` | Optional `activityPermissionDenial` field |
| `lib/presentation/cubits/my_data_cubit.dart` | Resolve status in refresh |
| `lib/presentation/widgets/background_status_card.dart` | Dual CTA + copy by denial mode |
| `lib/presentation/screens/my_data_screen.dart` | Pass retry callback |
| `lib/l10n/app_en.arb`, `app_fr.arb` | New strings |
| Tests (see Sub-task D) | Extend existing files |

**Do not touch:** `onboarding_flow.dart`, `onboarding_intro_page.dart` (31-2), `notification_service.dart` init catch (31-3), `main.dart` boot order (31-5), `pubspec.yaml` version (epic close).

### Testing requirements

| Verify | Command |
|--------|---------|
| Profile cubit | `flutter test test/presentation/cubits/profile_cubit_test.dart` |
| Settings screen | `flutter test test/presentation/screens/settings_screen_test.dart` |
| Today | `flutter test test/presentation/cubits/today_cubit_test.dart` |
| My Data | `flutter test test/presentation/screens/my_data_screen_test.dart` |
| Critical gate | `flutter test --tags critical` |

**Inject fakes:** Use `permissionRequester: (_) async => PermissionStatus.permanentlyDenied` vs `PermissionStatus.denied` — never rely on real OS dialogs in unit tests.

**Widget tests:** Pump Settings with seeded ProfileCubit stub returning `deniedPermanent`; tap Switch; expect SnackBar with action label matching `myDataOpenSettings`.

Do **not** run bare `flutter test`.

### Previous story intelligence (Epic 30)

| Learning | Impact on 31-1 |
|----------|----------------|
| Tracker = `sprint-status-audits-2.yaml` | Update on story create/done |
| OK commit gate per sub-task | Same A→D workflow |
| Diagnostic closure pattern | Mark #1 `partial` — full close needs 31-2 for onboarding |
| Injectable dependencies + fake clocks | Mirror with injectable permission status in cubit tests |
| Epic close = version bump | Epic 31 close = **minor+1** (`0.14.0+n`) — not this story |

[Source: `stories/30-4-inject-timeprovider-into-collection-timeout-source.md`]

### Cross-story context (Epic 31)

| Story | Scope | Relationship |
|-------|-------|--------------|
| **31-1** | **this story** | Model + post-onboarding CTAs (Settings, Today, My Data) |
| 31-2 | Onboarding intro feedback | Uses `permanentlyDenied` enum; changes `onboarding_flow.dart` |
| 31-3 | Notification init rethrow | Independent |
| 31-4 | Centralize mappers | Will replace duplicated `_mapPermissionStatus` copies |
| 31-5 | Boot gate | Independent |
| 31-6 | Toggle concurrency | Builds on 31-1 notification result type |

**Coordination:** Extend `PermissionRequestStatus` now so 31-2 does not re-edit enum. Keep mapper thin so 31-4 can extract to `permission_status_mapper.dart` without UI churn.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `89b57a1` | Epic 30 closed at `0.13.1+33` — current base |
| `6898570` | 30-4 — injectable deps pattern |
| Prior E29 commits | Unrelated to permissions |

Active branch `main`; `base_version: 0.13.1+33` per sprint tracker.

### Latest tech / library notes

- **`permission_handler` ^12.0.1:** `PermissionStatus.isPermanentlyDenied` is the canonical check after `.request()` or `.status`. On iOS, notification permanent deny may present as `denied` until first request — test with injectable fakes, not assumptions.
- **`openAppSettings()`:** Returns `Future<bool>` — fire-and-forget via `unawaited()` matches existing Today/My Data pattern.
- **No new packages.**

### Project context reference

- OK commit gate: sub-tasks A→D, separate commits after Baptiste approval
- Tests: localized file runs; `flutter test --tags critical` before story done
- Version bump: Epic 31 close (minor+1) — not per story
- Communication: French in chat; story in English

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc` · `.cursor/rules/app-versioning.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 31-1, AUD2-FR7, AUD2-FR9, AUD2-UX1, AUD2-UX2]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-permissions-notifications.md` #1, #2 partial]
- [Source: `_bmad-output/planning-artifacts/architecture.md` D-13, Permissions]
- [Source: `lib/presentation/cubits/onboarding_state.dart`]
- [Source: `lib/core/permissions/activity_permission_resolver.dart`]
- [Source: `lib/presentation/cubits/profile_cubit.dart`]
- [Source: `lib/presentation/screens/settings_screen.dart`]
- [Source: `lib/presentation/screens/today_screen.dart`]
- [Source: `lib/presentation/widgets/background_status_card.dart`]
- [Source: `lib/presentation/cubits/my_data_cubit.dart`]
- [Source: `test/presentation/cubits/profile_cubit_test.dart`]
- [Source: `stories/30-4-inject-timeprovider-into-collection-timeout-source.md`]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- Sub-task A: Added `permanentlyDenied` to enum, `mapPermissionStatus()` + `resolveActivityPermissionStatus()` in resolver, OnboardingCubit delegates to shared mapper. Tests pass.
- Sub-task B: `NotificationToggleResult` on ProfileCubit; Settings SnackBar branches permanent vs reversible; l10n keys added. Tests pass.

### File List

- `lib/presentation/cubits/onboarding_state.dart`
- `lib/core/permissions/activity_permission_resolver.dart`
- `lib/presentation/cubits/onboarding_cubit.dart`
- `test/core/permissions/activity_permission_resolver_test.dart`
- `test/presentation/cubits/onboarding_cubit_test.dart`
- `lib/presentation/cubits/profile_cubit.dart`
- `lib/core/services/notification_service.dart`
- `lib/presentation/screens/settings_screen.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_fr.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_fr.dart`
- `test/presentation/cubits/profile_cubit_test.dart`
- `test/presentation/screens/settings_screen_test.dart`
