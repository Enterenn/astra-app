# Story 1.5: Trust-First Onboarding Flow

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **privacy pragmatist (Alex)**,
I want a trust-first onboarding that explains local-only storage before any permission prompt,
So that I feel confident granting activity access without creating an account.

## Acceptance Criteria

1. **Given** first launch with no onboarding completion flag (`onboarding_complete` absent or not `true`)
   **When** the app opens
   **Then** a full-screen onboarding stack appears (not bottom tabs): Trust → Permissions → Goal (FR22, UX-DR16)
   **And** no account, email, or authentication screen exists

2. **Given** the Trust step (step 1) is displayed
   **When** the user taps Continue
   **Then** the app advances to Permissions
   **And** no OS permission dialog has been shown yet (trust copy before permissions — FR22)

3. **Given** the Permissions step (step 2)
   **When** the user taps "Allow activity access"
   **Then** the OS activity permission flow is triggered via `permission_handler` (Android: `Permission.activityRecognition`; iOS: `Permission.sensors` with `NSMotionUsageDescription`)
   **And** optional notification opt-in is offered separately: toggle copy "Notify when daily goal is reached" plus ghost "Skip notifications" (FR24)
   **And** notification permission is requested only if the user opts in (toggle on or explicit allow path) — never bundled with activity permission

4. **Given** the Goal step (step 3) with default `8000` pre-filled
   **When** the user taps "Start tracking" with a valid goal OR skips goal entry
   **Then** `UserPreferencesRepository.setDailyStepGoal()` persists the value (8000 if skipped or invalid empty → default 8000)
   **And** `setOnboardingComplete(true)` is called
   **And** the user lands on `AppScaffold` with **Today** tab selected (index 0, UX D-10)

5. **Given** onboarding navigation controls on steps 2–3
   **When** the user taps system/back or an in-flow back control
   **Then** back navigation is allowed (step 3 → 2, step 2 → 1)
   **And** step 1 has no back affordance

6. **Given** any onboarding primary/secondary/ghost control
   **When** rendered
   **Then** shared `AstraButton` variants meet 48dp minimum height and token colors (UX-DR17)

7. **Given** onboarding is complete
   **When** the app is cold-started again
   **Then** `AppScaffold` is shown directly — onboarding never reappears (V-10)

8. **Given** notification permission denied or skipped
   **When** onboarding completes
   **Then** the app still reaches `AppScaffold` and functions (FR24 — no blocking loop)

## Tasks / Subtasks

- [x] **Sub-task A — Platform permission declarations** (AC: #3)
  - [x] Add to `android/app/src/main/AndroidManifest.xml` (main, not debug/profile): `<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />`
  - [x] Add to `ios/Runner/Info.plist`: `NSMotionUsageDescription` — honest copy for step counting (e.g. "ASTRA uses motion data on this device to count your steps locally.")
  - [x] iOS notification: add `permission_handler` notification keys to `Info.plist` per [permission_handler iOS setup](https://pub.dev/packages/permission_handler) if requesting `Permission.notification` on iOS 10+
  - [x] **Do not** add `INTERNET` to release manifest; **do not** add FGS declarations here (Epic 2 / Story 2.4)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — `AstraButton` shared widget** (AC: #6)
  - [x] Create `lib/presentation/widgets/astra_button.dart` — variants: `primary`, `secondary`, `ghost` (danger deferred to purge story)
  - [x] Min height `AstraSpacing.kMinTouchTarget` (48dp); radius `kRadiusSm`; label `AstraTypography.labelFor(colors)`
  - [x] Primary: fill `accentPrimary`, text `textInverse`; Secondary: outline `borderDefault`; Ghost: text `textSecondary`
  - [x] Support `onPressed` null → disabled styling; optional `isLoading` for permission request in flight
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Onboarding pages + flow shell** (AC: #1, #2, #4, #5)
  - [x] Create `lib/presentation/onboarding/onboarding_trust_page.dart` — headline/body copy per UX §3.7 step 1; progress dots `● ○ ○`; primary Continue only
  - [x] Create `lib/presentation/onboarding/onboarding_permissions_page.dart` — step 2 copy; primary "Allow activity access"; optional `Switch` for notification opt-in; ghost "Skip notifications" advances without notification request
  - [x] Create `lib/presentation/onboarding/onboarding_goal_page.dart` — numeric `TextField` default `8000`; validation 1_000–100_000 integer (UX D-8 / UX-DR13 pattern); primary "Start tracking" disabled until valid; secondary skip → 8000
  - [x] Create `lib/presentation/onboarding/onboarding_flow.dart` — `PageView` or indexed stack with `OnboardingCubit`; padding `kSpace2xl` horizontal; `bgBase`/`bgElevated` tokens; no bottom tabs
  - [x] Progress indicator widget (3 dots) updates per step
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — `OnboardingCubit` + persistence + app gate** (AC: #3, #4, #7, #8)
  - [x] Create `lib/presentation/cubits/onboarding_cubit.dart` + `onboarding_state.dart` — step index, `notificationOptIn`, goal field value, permission request status
  - [x] Inject `UserPreferencesRepository` only (no direct SQL)
  - [x] `requestActivityPermission()`: platform branch — `Permission.activityRecognition.request()` (Android), `Permission.sensors.request()` (iOS); handle denied/granted without blocking forward navigation
  - [x] `requestNotificationPermissionIfOptedIn()`: call only when toggle true; `Permission.notification.request()`; denied OK
  - [x] `completeOnboarding({int? goal})`: `setDailyStepGoal`, `setOnboardingComplete(true)`, emit completed
  - [x] Extend `AppDependencies` — add `initialOnboardingComplete` loaded in `create()` / `test()` alongside `initialTheme`
  - [x] Update `lib/app.dart` — root stateful gate: `initialOnboardingComplete ? AppScaffold() : OnboardingFlow(...)`; on complete callback `setState` → `AppScaffold`; pass `deps` into flow
  - [x] **Preserve** `ThemeCubit` / cold-start theme behavior from Story 1.4 — gate wraps `home`, does not reload theme
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Tests & verification** (AC: #1–#8)
  - [x] `test/presentation/widgets/astra_button_test.dart` — min height, variant colors
  - [x] `test/presentation/cubits/onboarding_cubit_test.dart` — step transitions, skip goal → 8000, complete calls repo (mock/fake repo)
  - [x] `test/presentation/onboarding/onboarding_flow_test.dart` — trust step: no `permission_handler` call before continue (mock platform channel or verify cubit method not invoked)
  - [x] Update `test/widget_test.dart` — seed `setOnboardingComplete(true)` in `setUpAll` so existing shell tests still pass
  - [x] Add widget test group: onboarding incomplete → shows trust headline; after `completeOnboarding` pump → `NavigationBar` visible
  - [x] Run `flutter analyze` (zero issues) and `flutter test` (all pass)
  - [x] Manual Android: fresh install → trust before dialog → goal save → relaunch skips onboarding
  - [x] Manual iOS: motion permission prompt after Allow activity (if applicable)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary (critical)

**In scope for 1.5:**
- Full-screen 3-step onboarding (Trust → Permissions → Goal)
- `OnboardingCubit` + `OnboardingFlow` + three page widgets under `lib/presentation/onboarding/`
- `AstraButton` (primary/secondary/ghost) — first shared button component
- App entry gate using persisted `onboarding_complete` + in-memory transition after complete
- Android `ACTIVITY_RECOGNITION` manifest + iOS `NSMotionUsageDescription`
- Runtime permission requests via existing `permission_handler ^12.0.1`
- Persist `daily_step_goal` + `onboarding_complete` via existing `UserPreferencesRepository`

**Out of scope — defer to later stories:**
- `flutter_local_notifications` initialization, channels, goal-celebration scheduling → **Story 2.7** (FR25)
- `BackgroundHealthCapabilityEvaluator`, battery optimization deep links → **Epic 2 / architecture evaluator**
- `GoalEditorSheet` on My Data → **Story 4.6**
- `pedometer`, `BackgroundCollector`, `WorkManager`, step ingestion → **Epic 2**
- Persisting permission outcomes to `user_preferences` keys → optional; runtime check suffices for Phase 0 unless purge story requires keys (D-11 mentions permission choices — add keys in Epic 4 purge story if needed, not required for 1.5 AC)
- `GoRouter`, deep links, account/auth UI → **forbidden**
- Custom illustrations / Lottie — optional minimal icon only
- `ThemeSelector` UI → **Story 4.7**

Do not over-implement. Story 1.5 ends with **first-run trust onboarding + shell gate** — not step tracking, notifications delivery, or My Data features.

### Onboarding gate pattern (replaces dev skip from 1.3/1.4)

Stories 1.3–1.4 intentionally used `home: const AppScaffold()` as a dev skip. **1.5 implements the real gate.**

**Recommended pattern** (load flag at startup, switch in memory on complete):

```dart
// AppDependencies.create()
final initialOnboardingComplete = await userPreferences.getOnboardingComplete();

// app.dart — StatefulWidget root
home: _showMainShell
    ? const AppScaffold()
    : OnboardingFlow(
        deps: deps,
        onComplete: () => setState(() => _showMainShell = true),
      ),
```

Initialize `_showMainShell` from `deps.initialOnboardingComplete`. Do **not** use `FutureBuilder` for the gate — read completes in `create()` before `runApp`, same as theme (Story 1.4).

After `completeOnboarding`, call parent `onComplete` **after** await repo writes so cold restart also skips onboarding.

### Trust-before-permission enforcement

| Step | User action | Permission side effect |
|------|-------------|------------------------|
| 1 Trust | Continue | **None** — only `cubit.nextStep()` |
| 2 Permissions | Allow activity | Activity/sensors OS dialog |
| 2 Permissions | Toggle notification + continue OR skip notifications | Notification dialog **only** if opted in |
| 3 Goal | Start tracking / skip | **None** — save prefs only |

Unit/widget tests must assert step-1 Continue does **not** invoke permission request methods.

### Copy (English Phase 0 — UX §3.7)

| Step | Headline | Body (summary) | Primary CTA |
|------|----------|----------------|-------------|
| Trust | "Your steps stay on this device." | No account. No cloud. Stored locally, never sent anywhere. | Continue |
| Permissions | (no large headline required) | "To count steps, ASTRA needs activity access on this phone." | Allow activity access |
| Goal | "Set a daily step goal" | "Change anytime in My Data." | Start tracking |

Use `AstraTypography.titleFor` / `bodyFor` / `headlineFor` with `context.astraColors`.

### Goal validation (align with UX D-8)

- Integer only, min **1_000**, max **100_000**
- Default display **8000**; skip → persist `kDefaultStepGoal` (8000)
- "Start tracking" disabled until valid when user edits field; skip button always available
- Reuse validation logic later in `GoalEditorSheet` (Story 4.6) — consider a tiny shared validator in `lib/core/constants/` or inline in cubit for now (no sheet UI)

### Platform permission matrix

| Platform | Activity / motion | Notification (optional) |
|----------|-------------------|-------------------------|
| Android API 29+ | Manifest `ACTIVITY_RECOGNITION` + `Permission.activityRecognition` | `Permission.notification` (Android 13+) |
| Android <29 | Implicit grant per permission_handler | Same |
| iOS | `Permission.sensors` + `NSMotionUsageDescription` | `Permission.notification` + Info.plist keys |

**Never** call activity and notification requests in the same button handler.

### `OnboardingCubit` responsibilities

- Hold `currentStep` (0..2)
- `notificationOptIn` bool from Switch
- `goalInput` string for TextField
- Methods: `nextStep()`, `previousStep()` (only if step > 0), `setNotificationOptIn(bool)`, `requestActivityPermission()`, `requestNotificationIfNeeded()`, `completeOnboarding()`
- On complete: clamp goal, `await repo.setDailyStepGoal(goal)`, `await repo.setOnboardingComplete(true)`, emit `OnboardingStatus.completed`
- Permission denied: still allow user to proceed to Goal (non-blocking — FR24 / UX empty states handled in Epic 2)

### Current repo state (post Story 1.4)

| Item | State |
|------|-------|
| `lib/app.dart` | `home: const AppScaffold()` — **replace with gate** |
| `AppDependencies` | DB + `UserPreferencesRepository` + `initialTheme` — **add `initialOnboardingComplete`** |
| `UserPreferencesRepository` | Has `getOnboardingComplete()` / `setOnboardingComplete()` — **use** |
| `lib/presentation/onboarding/` | **Absent** — create |
| `lib/presentation/widgets/astra_button.dart` | **Absent** — create |
| `OnboardingCubit` | **Absent** — create |
| Android manifest | No `ACTIVITY_RECOGNITION` yet |
| iOS Info.plist | No `NSMotionUsageDescription` yet |
| Tests | 26 passing; shell tests assume direct `AppScaffold` — **seed onboarding complete in fixture** |

### Suggested file tree after 1.5

```
lib/
├── app.dart                                    # UPDATE — onboarding gate
├── core/di/app_dependencies.dart               # UPDATE — initialOnboardingComplete
└── presentation/
    ├── cubits/
    │   ├── onboarding_cubit.dart               # NEW
    │   └── onboarding_state.dart               # NEW
    ├── onboarding/
    │   ├── onboarding_flow.dart                # NEW
    │   ├── onboarding_trust_page.dart         # NEW
    │   ├── onboarding_permissions_page.dart   # NEW
    │   └── onboarding_goal_page.dart          # NEW
    └── widgets/
        └── astra_button.dart                   # NEW

android/app/src/main/AndroidManifest.xml      # UPDATE — ACTIVITY_RECOGNITION
ios/Runner/Info.plist                           # UPDATE — NSMotionUsageDescription (+ notification if needed)

test/
├── presentation/widgets/astra_button_test.dart           # NEW
├── presentation/cubits/onboarding_cubit_test.dart        # NEW
├── presentation/onboarding/onboarding_flow_test.dart     # NEW
└── widget_test.dart                                      # UPDATE — onboarding fixture
```

### Anti-patterns (do not do in 1.5)

- ❌ Show OS permission dialog on Trust step or before Permissions screen mounts
- ❌ Request activity + notification in one combined CTA
- ❌ Add account/email/sign-in UI
- ❌ Use bottom `NavigationBar` inside onboarding
- ❌ Direct SQL from `OnboardingCubit` or pages
- ❌ Initialize `flutter_local_notifications` or schedule goal notifications
- ❌ Start `pedometer` / `BackgroundCollector` / `WorkManager`
- ❌ Add `GoRouter` or new state-management packages
- ❌ Break `AppScaffold` tab behavior, cross-fade, or theme cold-start from 1.3/1.4
- ❌ Re-show onboarding after `onboarding_complete=true` (including after future purge — D-11)
- ❌ Batch sub-tasks into one commit without Baptiste review

### Epic 1 cross-story context

| Story | Focus | Relation to 1.5 |
|-------|-------|-----------------|
| 1.2 (done) | Tokens, `ThemeCubit` | Onboarding uses `AstraColors` / typography |
| 1.3 (done) | `AppScaffold` + tabs | Shown after onboarding; Today index 0 |
| 1.4 (done) | Prefs repo + `onboarding_complete` API | **Required dependency** — gate + save on complete |
| **1.5** (this) | Onboarding UI + permissions + gate | Completes Epic 1 shell epic |
| 2.1+ | Timeseries schema, tracking | Onboarding must finish before meaningful Today data |

### Mandatory dev workflow

Follow [`docs/project-context.md`](../../../docs/project-context.md):

- One commit per sub-task (A–E) after Baptiste review
- Review brief format required before each commit
- No push unless explicitly requested

### Project Structure Notes

- Aligns with Architecture `lib/presentation/onboarding/` + `onboarding_cubit.dart`
- `AstraButton` in `lib/presentation/widgets/` per UX component inventory
- FR-22–24 mapped to onboarding module per architecture FR table

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Story 1.5, FR22–24]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — §2.6, §3.7, UX-DR16/17, D-10]
- [Source: _bmad-output/planning-artifacts/architecture.md — D-10, D-13, presentation/onboarding/]
- [Source: _bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md — §4.8 Onboarding & Trust]
- [Source: _bmad-output/implementation-artifacts/stories/1-4-user-preferences-persistence.md — repository API, gate prep]
- [Source: _bmad-output/implementation-artifacts/stories/1-3-app-scaffold-and-bottom-navigation.md — AppScaffold preservation]
- [Source: permission_handler — activityRecognition (Android), sensors (iOS)](https://pub.dev/packages/permission_handler)

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Widget tests with full onboarding tap-through hang on Windows test runner (real permission_handler channel); covered via cubit unit tests + onboarding_flow_test with injected requester.

### Completion Notes List

- Sub-task A: Android `ACTIVITY_RECOGNITION` + `POST_NOTIFICATIONS` (API 33+ opt-in notifications); iOS `NSMotionUsageDescription`; no iOS notification plist key needed (permission_handler SPM enables notifications by default).
- Sub-task B: `AstraButton` primary/secondary/ghost with 48dp min height, token colors, disabled + loading states.
- Sub-task C: 3-step full-screen onboarding (Trust → Permissions → Goal) with progress dots, back navigation steps 2–3, PopScope system back.
- Sub-task D: `OnboardingCubit` with injectable permission requester for tests; `AppDependencies.initialOnboardingComplete`; `AstraApp` stateful gate preserves ThemeCubit cold-start.
- Sub-task E: 50 automated tests; `flutter analyze` 0 issues; manual Android/iOS verification pending Baptiste on device/emulator.

### Review Findings

- [x] [Review][Patch] Permission request failure leaves UI stuck in loading — `_resolvePermission` try/catch in `onboarding_cubit.dart`
- [x] [Review][Patch] Missing AstraApp gate / back / denial tests — added in `widget_test.dart` + `onboarding_flow_test.dart`
- [x] [Review][Patch] No test for permission denied still proceeds — widget test in `onboarding_flow_test.dart`
- [x] [Review][Defer] System back on Trust step exits app — acceptable per AC #5 (no in-flow back only)
- [x] [Review][Defer] iOS notification plist keys — verify on device during manual iOS pass
- [x] Manual Android fresh-install flow — verified Baptiste
- [x] Manual iOS motion permission prompt — verified Baptiste

### File List

- android/app/src/main/AndroidManifest.xml
- ios/Runner/Info.plist
- lib/app.dart
- lib/core/di/app_dependencies.dart
- lib/presentation/cubits/onboarding_cubit.dart
- lib/presentation/cubits/onboarding_state.dart
- lib/presentation/onboarding/onboarding_flow.dart
- lib/presentation/onboarding/onboarding_goal_page.dart
- lib/presentation/onboarding/onboarding_permissions_page.dart
- lib/presentation/onboarding/onboarding_progress_indicator.dart
- lib/presentation/onboarding/onboarding_trust_page.dart
- lib/presentation/widgets/astra_button.dart
- test/presentation/cubits/onboarding_cubit_test.dart
- test/presentation/onboarding/onboarding_flow_test.dart
- test/presentation/widgets/astra_button_test.dart
- test/widget_test.dart

### Change Log

- 2026-06-01: Story 1.5 — trust-first onboarding flow, AstraButton, app gate, platform permissions, automated tests (41 passing).
- 2026-06-01: Code review fixes — permission error recovery, gate/back/denial tests, async CTA handlers (50 tests passing).

## Technical Requirements

1. **Three-step stack:** Trust → Permissions → Goal; full-screen; no tabs (FR22, UX-DR16)
2. **Trust first:** No permission dialogs before Permissions step (FR22)
3. **Activity permission:** `permission_handler` — Android `Permission.activityRecognition` + manifest; iOS `Permission.sensors` + `NSMotionUsageDescription`
4. **Notification opt-in:** Separate optional path; request only if opted in; non-blocking if denied (FR24)
5. **Goal persist:** `setDailyStepGoal` — default/skip 8000; validation 1_000–100_000 when user submits custom value (FR23)
6. **Complete flag:** `setOnboardingComplete(true)` on finish; gate on cold start (FR23, V-10)
7. **Landing:** `AppScaffold` tab index 0 (Today) after complete (UX D-10)
8. **Back navigation:** Allowed steps 2→1 and 3→2 only
9. **Buttons:** `AstraButton` 48dp min height (UX-DR17)
10. **Repository-only writes:** No direct SQL from presentation layer

## Architecture Compliance

| Decision | Requirement for 1.5 |
|----------|---------------------|
| D-09 | `OnboardingCubit` — flutter_bloc Cubit only |
| D-10 | Onboarding stack separate from bottom-tab shell |
| D-13 | `permission_handler ^12.0.1` for runtime permissions |
| D-22 | Pages under `presentation/onboarding/`; cubit under `presentation/cubits/` |
| Write path | `UserPreferencesRepository` only |
| Navigation | No GoRouter; `MaterialApp.home` gate |
| Network | No network calls; no INTERNET in main manifest |
| iOS | `NSMotionUsageDescription` in Info.plist per architecture tree |

## Library & Framework Requirements

| Package | Version | 1.5 action |
|---------|---------|------------|
| permission_handler | ^12.0.1 | **Use** — activity + optional notification |
| flutter_bloc | ^9.1.1 | **Use** — `OnboardingCubit` |
| sqflite | ^2.4.2+1 | **Unchanged** — via repository only |

**Do NOT add** new runtime packages. **Do NOT wire** `flutter_local_notifications` yet (declared in pubspec for later stories).

## File Structure Requirements

| Path | Action |
|------|--------|
| `lib/presentation/widgets/astra_button.dart` | NEW |
| `lib/presentation/cubits/onboarding_cubit.dart` | NEW |
| `lib/presentation/cubits/onboarding_state.dart` | NEW |
| `lib/presentation/onboarding/onboarding_flow.dart` | NEW |
| `lib/presentation/onboarding/onboarding_trust_page.dart` | NEW |
| `lib/presentation/onboarding/onboarding_permissions_page.dart` | NEW |
| `lib/presentation/onboarding/onboarding_goal_page.dart` | NEW |
| `lib/app.dart` | UPDATE — gate |
| `lib/core/di/app_dependencies.dart` | UPDATE — `initialOnboardingComplete` |
| `android/app/src/main/AndroidManifest.xml` | UPDATE |
| `ios/Runner/Info.plist` | UPDATE |
| `test/presentation/widgets/astra_button_test.dart` | NEW |
| `test/presentation/cubits/onboarding_cubit_test.dart` | NEW |
| `test/presentation/onboarding/onboarding_flow_test.dart` | NEW |
| `test/widget_test.dart` | UPDATE |

## Testing Requirements

- **Unit:** `onboarding_cubit_test` — steps, goal clamp, repo calls on complete
- **Widget:** `onboarding_flow_test` — trust headline visible; Continue does not trigger permission before step 2
- **Widget:** `astra_button_test` — 48dp min height
- **Widget:** `widget_test` — existing shell tests with `setOnboardingComplete(true)` in setup
- **Widget:** new group — incomplete onboarding shows flow; complete shows `NavigationBar`
- **Manual:** Fresh install flow on Android emulator; relaunch skips onboarding
- **Commands:** `flutter analyze` (0 issues), `flutter test` (all pass)

## Previous Story Intelligence

From **Story 1.4** (done):

- `getOnboardingComplete()` / `setOnboardingComplete()` already on `UserPreferencesRepository` — **do not re-add keys**
- `AppDependencies.create()` async in `main()` — extend with `initialOnboardingComplete`, not a second DB round-trip in widget tree
- Widget tests must use `AppDependencies.test(...)` + FFI DB; seed onboarding complete for shell tests
- Review-before-commit: **5 sub-tasks** (A–E), Baptiste OK before each commit
- WAL PRAGMA skipped for `:memory:` in tests — unchanged
- 26 tests baseline — grow with onboarding tests; keep all green

From **Story 1.3** (done):

- `AppScaffold` default tab index 0 — onboarding completion must land here, not History/My Data
- `AnimatedSwitcher` 200ms + reduce-motion — **do not modify** unless gate wiring requires it
- Future gate comment in 1.3 story — **now implement**

From **Story 1.2** (done):

- `AstraButton` was deferred — **1.5 introduces it** for onboarding CTAs only (danger variant still deferred)

## Git Intelligence Summary

Recent commits (Story 1.4):

| Commit | Relevance |
|--------|-----------|
| `38fa425` | PRAGMA via rawQuery on Android — keep DB open pattern |
| `97c568d` | Test factory hardening — mirror in onboarding tests |
| `69c3b9c` | `AppDependencies` + cold-start theme — extend, don't break |
| `ed38c6e` | sqflite FFI test helpers — reuse `setUpSqfliteFfi()` |

**Convention:** `feat(onboarding):`, `feat(widgets):`, `chore(android):`, `test(onboarding):` scoped commits.

## Latest Tech Information

- **permission_handler 12.0.1:** `Permission.activityRecognition` maps to Android `ACTIVITY_RECOGNITION` (API 29+); pre-Q implicitly granted. iOS activity recognition is a no-op — use `Permission.sensors` for motion/step access with `NSMotionUsageDescription`.
- **Notification:** `Permission.notification` on Android 13+; optional during onboarding only when user opts in (FR24).
- **No notification scheduling in 1.5:** `flutter_local_notifications` initialization belongs with goal-celebration logic (Story 2.7 / FR25).

## Project Context Reference

Mandatory — [`docs/project-context.md`](../../../docs/project-context.md):

- Review-before-commit gate (sub-tasks A–E)
- Commit message convention: `type(scope): imperative summary`
- Story file: `_bmad-output/implementation-artifacts/stories/1-5-trust-first-onboarding-flow.md`
- Baptiste is Flutter novice — review briefs should explain `permission_handler`, `BlocProvider`, and manifest plist changes pedagogically

## Story Completion Status

- Status: **done**
- Ultimate context engine analysis completed — comprehensive developer guide created
- Epic 1 remains **in-progress** (1.5 completes functional onboarding; retrospective optional after review)
- **Critical guardrail:** Trust step must not trigger OS permission dialogs — enforce in code and tests
