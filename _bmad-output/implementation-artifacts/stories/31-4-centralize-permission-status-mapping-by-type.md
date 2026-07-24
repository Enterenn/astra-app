# Story 31.4: Centralize Permission Status Mapping by Type

Status: in-progress

<!-- audits_2 Epic 31 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 31-4 · diagnostic-permissions-notifications.md #4, #5 · AUD2-FR15 · AUD2-FR16 · AUD2-UX5 -->
<!-- Prerequisite: 31-1 done · 31-3 done · 31-2 done -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **developer**,
I want one permission mapper per permission kind,
So that notification `isLimited`/`isProvisional` rules are not wrongly applied to activity recognition.

## Acceptance Criteria

1. **Given** notification vs activity permission checks
   **When** status is mapped to app enum / granted boolean
   **Then** a centralized resolver applies type-correct rules — AUD2-FR15
   **And** activity mapping treats **only** `isGranted` as granted (not `isLimited` / `isProvisional`)
   **And** notification mapping keeps `isGranted || isLimited || isProvisional` as granted
   **And** duplicated inline / wrapper mappers in onboarding / notification paths delegate to resolvers

2. **Given** `isActivityRecognitionGranted()` and `resolveActivityPermissionStatus()`
   **When** platform returns `limited` or `provisional` for activity/sensors
   **Then** they return `false` / `PermissionRequestStatus.denied` respectively — AUD2-FR15
   **And** Today / My Data / FGS gate behaviour stays consistent (no false-positive grant)

3. **Given** `NotificationService.hasNotificationPermission()`
   **When** status is `limited` or `provisional`
   **Then** returns `true` (unchanged notification semantics)
   **And** implementation delegates to centralized notification resolver (no inline triplet)

4. **Given** a platform exception during onboarding activity permission resolution
   **When** `_resolvePermission` catch runs
   **Then** result is **not** `PermissionRequestStatus.denied` — AUD2-FR16, AUD2-UX5
   **And** error is logged with a distinct prefix (platform/technical vs user denial)
   **And** intro UI shows actionable feedback (retry + continue) without masquerading as user denial

5. **Given** existing permission / onboarding / notification tests
   **When** this story ships
   **Then** activity resolver tests assert `limited`/`provisional` → denied
   **And** notification tests assert `limited`/`provisional` → granted
   **And** onboarding cubit test for throwing requester expects `failed` (not `denied`)
   **And** `flutter test --tags critical` passes

**Covers:** AUD2-FR15 · AUD2-FR16 · AUD2-UX5 · diagnostic-permissions-notifications.md #4, #5

**Depends on:** 31-1 (`permanentlyDenied` enum + post-onboarding CTAs), 31-2 (intro feedback UI), 31-3 (notification init — independent).

**Out of scope:**
- Boot WM cancel structural gate → **31-5** (do not touch `main.dart`)
- Profile toggle concurrency / background init timeout → **31-6**
- Refactor `ProfileCubit` toggle to return `PermissionRequestStatus` — keep `NotificationToggleResult`
- `pubspec.yaml` version bump (Epic 31 close = minor+1)

## Tasks / Subtasks

- [x] **Sub-task A — Type-specific permission resolvers** (AC: #1, #2, #3)
  - [x] Read fully: `activity_permission_resolver.dart`, `notification_service.dart` (`hasNotificationPermission`), `onboarding_cubit.dart` (`_mapPermissionStatus`)
  - [x] Add `lib/core/permissions/notification_permission_resolver.dart`:
    - `isNotificationPermissionGranted(PermissionStatus)` — `isGranted || isLimited || isProvisional`
    - `mapNotificationPermissionStatus(PermissionStatus)` → `PermissionRequestStatus` (for future Profile reuse; optional export)
  - [x] Refine activity resolver:
    - Rename `mapPermissionStatus` → `mapActivityPermissionStatus` (update all imports)
    - Activity granted = **`status.isGranted` only**
    - Fix `isActivityRecognitionGranted()` to use shared `isActivityPermissionGranted(status)` helper
  - [x] `NotificationService.hasNotificationPermission()` delegates to `isNotificationPermissionGranted`
  - [x] Remove `OnboardingCubit._mapPermissionStatus` wrapper — call `mapActivityPermissionStatus` directly
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task B — Platform exception distinction in onboarding** (AC: #4)
  - [ ] Add `PermissionRequestStatus.failed` to `onboarding_state.dart`
  - [ ] `OnboardingCubit._resolvePermission` catch → `failed` (distinct debug log prefix, e.g. `platform error`)
  - [ ] `onboarding_flow.dart`: `failed` case — same CTAs as `denied` (Retry + Continue)
  - [ ] `onboarding_intro_page.dart`: include `failed` in feedback selector; distinct copy via new ARB key (en/fr) — e.g. technical retry message, not denial wording
  - [ ] Run `flutter gen-l10n`
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

- [ ] **Sub-task C — Tests + diagnostic close** (AC: #5)
  - [ ] Update `activity_permission_resolver_test.dart`: `limited`/`provisional` → `denied`; add `isActivityRecognitionGranted` unit coverage if needed
  - [ ] Add `notification_permission_resolver_test.dart` (or extend `notification_service_test.dart`) for notification mapper
  - [ ] Update `onboarding_cubit_test.dart`: throwing requester → `failed`
  - [ ] Update `onboarding_flow_test.dart` if widget expectations change for `failed` feedback
  - [ ] Run: `flutter test test/core/permissions/`
  - [ ] Run: `flutter test test/presentation/cubits/onboarding_cubit_test.dart`
  - [ ] Run: `flutter test test/core/services/notification_service_test.dart`
  - [ ] Run: `flutter test --tags critical`
  - [ ] Close diagnostic #4 + #5 → `done` with story ref; sync `audits_2/README.md` P1 rows if tracked
  - [ ] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

**Root bug:** Activity and notification permissions share the same mapping triplet (`isGranted || isLimited || isProvisional`) copied in three places. iOS notification `provisional`/`limited` must count as granted; **activity recognition / sensors must not**.

| Location | Current behaviour | Gap |
|----------|-------------------|-----|
| `activity_permission_resolver.dart:13-20` | `mapPermissionStatus` treats limited/provisional as granted | AUD2-FR15 — wrong for activity |
| `activity_permission_resolver.dart:32-36` | `isActivityRecognitionGranted()` same triplet | False-positive grant for FGS / Today |
| `notification_service.dart:128-131` | Inline triplet in `hasNotificationPermission()` | Duplicated — should delegate |
| `onboarding_cubit.dart:125-127` | Thin wrapper → shared wrong mapper | Remove wrapper; use activity mapper |
| `onboarding_cubit.dart:116-121` | All `catch` → `denied` | AUD2-FR16 — masks platform bugs |

```13:20:lib/core/permissions/activity_permission_resolver.dart
PermissionRequestStatus mapPermissionStatus(PermissionStatus status) {
  if (status.isGranted || status.isLimited || status.isProvisional) {
    return PermissionRequestStatus.granted;
  }
  // ...
}
```

```32:36:lib/core/permissions/activity_permission_resolver.dart
Future<bool> isActivityRecognitionGranted() async {
  final permission = resolveActivityPermission();
  final status = await permission.status;
  return status.isGranted || status.isLimited || status.isProvisional;
}
```

[Source: `diagnostic-permissions-notifications.md` #4 · `epics-audits-2.md` AUD2-FR15]

### Recommended implementation

**1. Activity resolver (fix + rename):**

```dart
bool isActivityPermissionGranted(PermissionStatus status) =>
    status.isGranted;

PermissionRequestStatus mapActivityPermissionStatus(PermissionStatus status) {
  if (status.isGranted) {
    return PermissionRequestStatus.granted;
  }
  if (status.isPermanentlyDenied) {
    return PermissionRequestStatus.permanentlyDenied;
  }
  return PermissionRequestStatus.denied;
}

Future<bool> isActivityRecognitionGranted() async {
  final status = await resolveActivityPermission().status;
  return isActivityPermissionGranted(status);
}
```

**2. Notification resolver (new file):**

```dart
bool isNotificationPermissionGranted(PermissionStatus status) =>
    status.isGranted || status.isLimited || status.isProvisional;
```

Optional: `mapNotificationPermissionStatus` mirroring activity shape — useful if Profile later centralizes permanent-deny detection; not required for AC if `hasNotificationPermission` + existing `status.isPermanentlyDenied` in Profile remain.

**3. NotificationService delegation:**

```dart
Future<bool> hasNotificationPermission() async {
  final status = await _permissionChecker();
  return isNotificationPermissionGranted(status);
}
```

**4. Onboarding platform errors:**

```dart
enum PermissionRequestStatus {
  idle,
  requesting,
  granted,
  denied,
  permanentlyDenied,
  failed, // platform/channel errors — AUD2-FR16
}
```

Catch block returns `failed`; log prefix distinct from user denial path. UI: treat like `denied` for CTAs but **different copy** (AUD2-UX5) — avoids implying user refused when plugin threw.

**5. Import impact (grep before merge):**

| Symbol | Consumers to update |
|--------|---------------------|
| `mapPermissionStatus` → `mapActivityPermissionStatus` | `onboarding_cubit.dart`, `activity_permission_resolver_test.dart` |
| `isActivityRecognitionGranted` | No signature change — behaviour fix only |
| New notification resolver | `notification_service.dart` |

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-12 / FR-25 | Notification granted semantics unchanged — centralize only |
| Injectable typedefs | Keep `NotificationPermissionChecker`, `PermissionRequester` — resolvers are pure functions |
| Presentation → core | Resolvers live in `lib/core/permissions/` — no cubit duplication |
| Token economy | Two small resolver files + enum value + targeted test updates |

[Source: `architecture.md` · `diagnostic-permissions-notifications.md` §Points forts — injectable pattern]

### File structure requirements

| File | Action |
|------|--------|
| `lib/core/permissions/activity_permission_resolver.dart` | Fix activity rules; rename mapper; shared `isActivityPermissionGranted` |
| `lib/core/permissions/notification_permission_resolver.dart` | **New** — notification granted helper (+ optional mapper) |
| `lib/core/services/notification_service.dart` | Delegate `hasNotificationPermission` |
| `lib/presentation/cubits/onboarding_cubit.dart` | Remove wrapper; catch → `failed` |
| `lib/presentation/cubits/onboarding_state.dart` | Add `failed` enum value |
| `lib/presentation/onboarding/onboarding_flow.dart` | Switch case for `failed` |
| `lib/presentation/onboarding/onboarding_intro_page.dart` | Feedback for `failed` |
| `lib/l10n/app_en.arb`, `app_fr.arb` | Technical error copy for intro |
| `test/core/permissions/activity_permission_resolver_test.dart` | Invert limited/provisional expectations |
| `test/core/permissions/notification_permission_resolver_test.dart` | **New** (or fold into notification_service_test) |
| `test/presentation/cubits/onboarding_cubit_test.dart` | Exception → `failed` |
| `planning-artifacts/audits_2/diagnostic-permissions-notifications.md` | Close #4, #5 |

**Do not touch:** `main.dart` (31-5), `profile_cubit.dart` toggle concurrency (31-6), `initializeForBackground` timeout (31-6), `pubspec.yaml` version.

### Testing requirements

| Verify | Command |
|--------|---------|
| Activity resolver | `flutter test test/core/permissions/activity_permission_resolver_test.dart` |
| Notification resolver / service | `flutter test test/core/services/notification_service_test.dart` |
| Onboarding cubit | `flutter test test/presentation/cubits/onboarding_cubit_test.dart` |
| Critical gate | `flutter test --tags critical` |

**Key test changes:**

```dart
// activity — limited/provisional are NOT granted
expect(mapActivityPermissionStatus(PermissionStatus.limited),
    PermissionRequestStatus.denied);

// onboarding — platform throw is failed, not denied
expect(cubit.state.activityPermissionStatus,
    PermissionRequestStatus.failed);
```

Do **not** run bare `flutter test`.

### Previous story intelligence

| Learning | Impact on 31-4 |
|----------|----------------|
| 31-1 added `permanentlyDenied` + `mapPermissionStatus` with limited/provisional as granted **intentionally deferred to 31-4** | This story **breaks** that temporary behaviour for activity only |
| 31-2 intro feedback switch on `denied` / `permanentlyDenied` | Extend for `failed` with distinct copy |
| 31-3 do-not-touch lists | No notification init / boot changes |
| OK commit gate A→C | Same sub-task workflow |
| Diagnostic partial-close pattern | Close #4 + #5 in Sub-task C |

[Source: `stories/31-1-model-permanently-denied-with-settings-cta.md` Sub-task A note · `stories/31-3-propagate-notification-platform-init-failures.md`]

### Cross-story context (Epic 31)

| Story | Status | Relationship |
|-------|--------|--------------|
| 31-1 | done | Introduced shared mapper — activity rules corrected here |
| 31-2 | done | Intro UI — add `failed` branch |
| 31-3 | done | Init rethrow — independent |
| **31-4** | **this story** | Central mappers + platform error distinction |
| 31-5 | backlog | Boot gate — do not overlap |
| 31-6 | backlog | Profile concurrency — may reuse notification mapper later |

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `c62056c` | 31-3 background init — preserve |
| `4a5f576` / `49a387d` | Notification service patterns — delegate, don't rewrite init |
| `9bd0c46` / `191df81` | Onboarding retry flow — extend for `failed` |
| `b360200` (31-1) | `mapPermissionStatus` origin — rename + fix |

Active branch `main`; tracker `sprint-status-audits-2.yaml`; base `0.13.1+33`.

### Latest tech / library notes

- **`permission_handler` ^12.0.1:** `PermissionStatus.limited` / `provisional` are primarily iOS notification concepts; applying them to `activityRecognition` / `sensors` was copy-paste error.
- **No package upgrade** — pure mapping / enum fix.
- **`PermissionStatus.restricted`:** Continue mapping to `denied` for activity (parental controls / enterprise).

### Project context reference

- OK commit gate: sub-tasks A→C, separate commits after Baptiste approval
- Tests: targeted file runs + `flutter test --tags critical`
- Version bump: Epic 31 close (minor+1) — not per story
- Communication: French in chat; story in English

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 31-4, AUD2-FR15, AUD2-FR16, AUD2-UX5]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-permissions-notifications.md` #4, #5]
- [Source: `lib/core/permissions/activity_permission_resolver.dart`]
- [Source: `lib/core/services/notification_service.dart`]
- [Source: `lib/presentation/cubits/onboarding_cubit.dart`]
- [Source: `lib/presentation/onboarding/onboarding_intro_page.dart`]
- [Source: `test/core/permissions/activity_permission_resolver_test.dart`]
- [Source: `test/presentation/cubits/onboarding_cubit_test.dart` L156-173]
- [Source: `stories/31-1-model-permanently-denied-with-settings-cta.md`]
- [Source: `stories/31-3-propagate-notification-platform-init-failures.md`]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

- Sub-task A: Activity mapper fixed (`isGranted` only); notification resolver extracted; onboarding delegates directly.

### Completion Notes List

- Sub-task A: `mapActivityPermissionStatus`, `isActivityPermissionGranted`, `notification_permission_resolver.dart`; tests green (19 tests).

### File List

- `lib/core/permissions/activity_permission_resolver.dart` — modified
- `lib/core/permissions/notification_permission_resolver.dart` — new
- `lib/core/services/notification_service.dart` — modified
- `lib/presentation/cubits/onboarding_cubit.dart` — modified
- `test/core/permissions/activity_permission_resolver_test.dart` — modified
- `test/core/permissions/notification_permission_resolver_test.dart` — new

### Change Log
