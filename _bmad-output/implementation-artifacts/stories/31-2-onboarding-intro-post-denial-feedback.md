# Story 31.2: Onboarding Intro — Post-Denial Feedback (Epic 13–aligned)

Status: review

<!-- audits_2 Epic 31 — tracker: sprint-status-audits-2.yaml -->
<!-- Source: epics-audits-2.md Story 31-2 · diagnostic-permissions-notifications.md #2 · AUD2-FR8 · AUD2-UX3 · AUD2-FR7 (partial) · AUD2-FR34 (partial) -->
<!-- Prerequisite: Story 31-1 done · base 0.13.1+33 -->
<!-- Authority: sprint-change-proposal-2026-06-17 + Epic 13 Story 13.1 > UX §3.7 (obsolete) -->
<!-- Validation: optional — run validate-create-story before dev-story -->
<!-- Ultimate context engine analysis completed - comprehensive developer guide created -->

## Story

As a **new user**,
I want visible feedback and the right action when I deny activity permission on intro,
So that I know tracking is limited and can retry or open Settings before continuing.

## Acceptance Criteria

1. **Given** user taps Start on intro (Epic 13 permission bridge)
   **When** OS dialog returns `granted`
   **Then** flow advances to weight immediately (unchanged happy path)

2. **Given** OS dialog returns reversible `denied`
   **When** dialog dismisses
   **Then** user **stays on intro** — `nextStep()` is **not** called automatically — AUD2-FR8
   **And** visible inline feedback explains that step tracking requires activity access — AUD2-UX3
   **And** a **Retry** control re-triggers `.request()` (primary footer action while denied)
   **And** **Continue** (explicit secondary control) lets user proceed to weight without granting — Epic 13 Story 13.1

3. **Given** OS dialog returns `permanentlyDenied`
   **When** dialog dismisses
   **Then** user stays on intro with feedback — no silent advance — AUD2-FR8
   **And** copy explains permission was permanently denied and Settings is required to enable tracking — AUD2-UX3
   **And** **Open Settings** CTA calls `openAppSettings()` — AUD2-FR7 partial
   **And** explicit **Continue** still allows reaching weight; Today `noPermission` handles degraded tracking (UX §1001)

4. **Given** user taps Retry and grants on second dialog
   **When** permission becomes `granted`
   **Then** flow advances to weight (feedback UI dismissed)

5. **Given** current bug (`onboarding_flow.dart:52-55`)
   **When** this story ships
   **Then** `await requestActivityPermission()` is followed by branch on `activityPermissionStatus`, not unconditional `nextStep()`

6. **Given** widget or cubit test for denied + permanentlyDenied paths
   **When** dialog simulated as denied
   **Then** intro feedback is visible and weight step is not shown until explicit Continue — AUD2-FR34 (partial)

7. **Given** Epic 13 scope
   **When** this story ships
   **Then** no dedicated Permissions/Goal onboarding screens reintroduced (superseded 2026-06-17)

**Covers:** AUD2-FR8 · AUD2-UX3 · AUD2-FR7 (partial) · AUD2-FR34 (partial) · diagnostic-permissions-notifications.md #2 (onboarding path)

**Depends on:** Story 31-1 done (`PermissionRequestStatus.permanentlyDenied` + shared `mapPermissionStatus()`).

**Out of scope:**
- Blocking onboarding completion entirely on deny
- Notification init rethrow → **31-3**
- Centralized mapper extraction → **31-4**
- Boot WM cancel gate → **31-5**
- Profile toggle concurrency → **31-6**
- `pubspec.yaml` version bump (Epic 31 close = minor+1)

## Tasks / Subtasks

- [x] **Sub-task A — Branch intro permission outcome in flow** (AC: #1, #2, #3, #5)
  - [x] Read fully: `onboarding_flow.dart`, `onboarding_cubit.dart`, `onboarding_state.dart`
  - [x] Replace `_onIntroContinue` unconditional `nextStep()` with:
    - `await cubit.requestActivityPermission()`
    - `if (status == granted) cubit.nextStep()` — else stay on intro
  - [x] Add `_onIntroRetry`: same request + auto-advance only on `granted`
  - [x] Add `_onIntroContinueAfterDeny`: `cubit.nextStep()` only (explicit user tap — Epic 13)
  - [x] Wire intro shell footer by `activityPermissionStatus`:
    - `idle` → primary **Start** (`onboardingStartBtn`), no secondary
    - `requesting` → primary loading/disabled (existing)
    - `denied` → primary **Retry** (`commonRetry`), secondary **Continue** (`onboardingContinueBtn`)
    - `permanentlyDenied` → primary **Continue**, no Retry; Open Settings lives in inline feedback (Sub-task B)
    - `granted` while still on step 0 → should not occur without advance; no special UI
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Inline post-denial feedback on intro page** (AC: #2, #3, #4)
  - [x] Read fully: `onboarding_intro_page.dart`, `today_screen.dart` `_PermissionDeniedSlot` (pattern reference)
  - [x] Convert intro content to show feedback when `activityPermissionStatus` is `denied` or `permanentlyDenied`:
    - Use `BlocSelector<OnboardingCubit, OnboardingState, PermissionRequestStatus?>` (or pass status from flow — prefer selector inside intro page for cohesion)
    - Pattern: muted dot + body copy + action `TextButton` (mirror Today/My Data voice, onboarding-specific strings)
    - `denied` → inline Retry is redundant with footer primary — feedback is **copy only** OR copy + optional inline Retry (prefer **footer Retry only** to avoid duplicate CTAs — match Today post-31-1 single-action discipline)
    - `permanentlyDenied` → copy + **Open settings** `TextButton` → `unawaited(openAppSettings())`
  - [x] Add ARB keys (en/fr):
    - `onboardingIntroPermissionDenied` — step tracking needs activity/sensor access; user can Continue without granting
    - `onboardingIntroPermissionPermanentlyDenied` — blocked in system settings; Open settings to enable tracking
  - [x] Reuse `commonRetry`, `myDataOpenSettings`, `onboardingContinueBtn` for button labels where applicable
  - [x] Add `Semantics(liveRegion: true)` on feedback block (match `_PermissionDeniedSlot`)
  - [x] Run `flutter gen-l10n`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Update + add onboarding flow tests** (AC: #6, #7)
  - [x] Read fully: `test/presentation/onboarding/onboarding_flow_test.dart` (tagged `@Tags(['slow'])`)
  - [x] **Breaking test updates** (expected — behaviour change):
    - `denied activity permission still advances to weight step` → rename/rewrite: denied **stays on intro**, feedback visible, weight headline absent
    - `denied permission on intro completes via UI skip` → after deny, tap **Continue** (secondary), then weight Skip → height Skip → complete
    - `recovers Continue after permission requester throws` → stays on intro with denied feedback; explicit Continue advances
  - [x] **New tests:**
    - `permanentlyDenied` shows Open settings + Continue; weight not shown until Continue
    - Retry after reversible deny + second request `granted` → auto-advance to weight
    - Intro does not call `nextStep()` on deny (assert step 0 + intro headline still visible)
  - [x] Run: `flutter test test/presentation/onboarding/onboarding_flow_test.dart`
  - [x] Run: `flutter test --tags critical`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Diagnostic partial close** (AC: covers diagnostic #2 onboarding slice)
  - [x] Update `planning-artifacts/audits_2/diagnostic-permissions-notifications.md`:
    - #1 → note onboarding intro feedback shipped (may move toward `done` if no other #1 gaps)
    - #2 → `partial` → onboarding retry path added; post-onboarding retry already from 31-1; update `onboarding_flow.dart:52-55` row
  - [x] Sync `audits_2/README.md` row if tracked
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Problem (read before editing)

**Root bug:** Intro Continue always advances after permission dialog, even on deny — user never sees feedback and cannot retry from intro.

```52:56:lib/presentation/onboarding/onboarding_flow.dart
  Future<void> _onIntroContinue(BuildContext context) async {
    final cubit = context.read<OnboardingCubit>();
    await cubit.requestActivityPermission();
    cubit.nextStep();
  }
```

| Location | Current behaviour | Gap |
|----------|-------------------|-----|
| `onboarding_flow.dart:52-55` | Unconditional `nextStep()` after request | AUD2-FR8 — silent advance on deny |
| `onboarding_intro_page.dart` | Static trust copy only | AUD2-UX3 — no post-denial feedback |
| `OnboardingShell` step 0 | Single **Start** CTA | No Retry/Continue dual mode after deny |
| `onboarding_flow_test.dart:203-223` | Asserts deny still advances | Must invert for new behaviour |

**Already done in 31-1 (do not redo):**
- `PermissionRequestStatus.permanentlyDenied` enum value
- `mapPermissionStatus()` / `resolveActivityPermissionStatus()` in `activity_permission_resolver.dart`
- Post-onboarding dual CTAs on Today, My Data, Settings

[Source: `diagnostic-permissions-notifications.md` #2 · `stories/31-1-model-permanently-denied-with-settings-cta.md`]

### Authority chain (product decision — resolved)

| Document | Rule |
|----------|------|
| Epic 13 / sprint-change 2026-06-17 | intro → weight → height; OS dialog on intro Start; **may reach weight after deny** |
| AUD2-FR8 (audits_2) | **No silent auto-advance on deny** — explicit Continue required |
| UX §3.7 "Skip notifications" | **Obsolete** — was notification opt-in on superseded Trust/Permissions/Goal flow |

**Net behaviour:** Deny → stay on intro + feedback + Retry (reversible) or Open Settings (permanent) + explicit **Continue** to weight. Grant (first or retry) → auto-advance. **Never block** onboarding completion.

[Source: `implementation-readiness-report-2026-07-24.md` § Clarifications · `epics-audits-2.md` Story 31-2]

### Recommended implementation

**1. Flow handlers (`onboarding_flow.dart`):**

```dart
Future<void> _onIntroStart(BuildContext context) async {
  final cubit = context.read<OnboardingCubit>();
  await cubit.requestActivityPermission();
  if (cubit.state.activityPermissionStatus == PermissionRequestStatus.granted) {
    cubit.nextStep();
  }
}

Future<void> _onIntroRetry(BuildContext context) async {
  final cubit = context.read<OnboardingCubit>();
  await cubit.requestActivityPermission();
  if (cubit.state.activityPermissionStatus == PermissionRequestStatus.granted) {
    cubit.nextStep();
  }
}

void _onIntroContinueAfterDeny(BuildContext context) {
  context.read<OnboardingCubit>().nextStep();
}
```

**2. Intro shell wiring (step 0 `OnboardingShell`):**

| `activityPermissionStatus` | Primary | Secondary | Handler |
|----------------------------|---------|-----------|---------|
| `idle` | Start | — | `_onIntroStart` |
| `requesting` | Start (loading) | — | disabled |
| `denied` | Retry | Continue | `_onIntroRetry` / `_onIntroContinueAfterDeny` |
| `permanentlyDenied` | Continue | — | `_onIntroContinueAfterDeny` |

Use `context.watch<OnboardingCubit>().state.activityPermissionStatus` (already watched in build).

**3. Intro feedback widget (`onboarding_intro_page.dart`):**

- Keep existing trust headline + card unchanged when `idle`/`requesting`/`granted`.
- When `denied` or `permanentlyDenied`, append feedback block below card (inside scroll):
  - Same visual language as `_PermissionDeniedSlot`: 8px muted dot + `AstraTypography.bodyFor`
  - `permanentlyDenied` only: add `TextButton` → `openAppSettings()` (Today uses same pattern)
  - Do **not** duplicate footer Retry as inline button for `denied` — one Retry (footer primary)

**4. Cubit — minimal or no changes:**

`requestActivityPermission()` already emits final status via `mapPermissionStatus()`. Do **not** add auto-`nextStep()` in cubit — flow owns navigation (matches Epic 13 separation).

**5. l10n (minimum new keys):**

| Key | EN (draft) | FR (draft) |
|-----|------------|------------|
| `onboardingIntroPermissionDenied` | Step tracking needs activity access on this device. You can continue without it — tracking will stay limited until you allow access. | Le suivi des pas nécessite l'accès à l'activité sur cet appareil. Vous pouvez continuer sans — le suivi restera limité tant que l'accès n'est pas autorisé. |
| `onboardingIntroPermissionPermanentlyDenied` | Activity access is blocked in system settings. Open settings to enable step tracking, or continue with limited tracking. | L'accès à l'activité est bloqué dans les paramètres système. Ouvrez les paramètres pour activer le suivi, ou continuez avec un suivi limité. |

Reuse: `commonRetry`, `myDataOpenSettings`, `onboardingContinueBtn`, `onboardingStartBtn`.

### Preserve (do not break)

| Behaviour | Must remain |
|-----------|-------------|
| Happy path grant → auto-advance to weight | AC #1 |
| Weight/height steps, skip, back navigation | Unchanged |
| `OnboardingCubit.requestActivityPermission()` injectable `permissionRequester` | Tests depend on it |
| Loading state on Start during `requesting` | Existing `primaryLoading` |
| Post-onboarding Today/My Data CTAs from 31-1 | Do not edit unless test breakage |
| 3-step flow, no Permissions/Goal screens | Epic 13 |
| `isActivityRecognitionGranted()` bool API | No change |

### Architecture compliance

| Rule | Application |
|------|-------------|
| D-13: `permission_handler` ^12.0.1 | Use existing resolver + `openAppSettings()` |
| Trust copy before permission | Start tap still shows trust UI first; dialog only after Start |
| FR-22 | Permission bridge on intro — refined UX, not removed |
| No network / no new packages | l10n + presentation only |
| Token economy | Extend 3 onboarding files + tests; no new abstractions |

[Source: `architecture.md` D-13, Permissions § · `epics-audits-2.md` AUD2-NFR4]

### File structure requirements

| File | Action |
|------|--------|
| `lib/presentation/onboarding/onboarding_flow.dart` | Branch on permission outcome; dual footer mode on intro |
| `lib/presentation/onboarding/onboarding_intro_page.dart` | Post-denial inline feedback (BlocSelector) |
| `lib/l10n/app_en.arb`, `app_fr.arb` | New onboarding intro permission strings |
| `test/presentation/onboarding/onboarding_flow_test.dart` | Invert deny tests; add permanent/retry cases |
| `planning-artifacts/audits_2/diagnostic-permissions-notifications.md` | Update #1/#2 status rows |
| `planning-artifacts/audits_2/README.md` | Sync if diagnostic table tracked |

**Do not touch:** `profile_cubit.dart`, `settings_screen.dart`, `today_screen.dart`, `background_status_card.dart` (31-1 scope), `notification_service.dart` (31-3), `main.dart` (31-5), `activity_permission_resolver.dart` enum mapping (already done), `pubspec.yaml` version.

### Testing requirements

| Verify | Command |
|--------|---------|
| Onboarding flow (primary) | `flutter test test/presentation/onboarding/onboarding_flow_test.dart` |
| Onboarding cubit (regression) | `flutter test test/presentation/cubits/onboarding_cubit_test.dart` |
| Critical gate | `flutter test --tags critical` |

**Note:** `onboarding_flow_test.dart` is `@Tags(['slow'])` — run the file explicitly; do not rely on default `--exclude-tags slow` alone for story verification.

**Inject fakes:** `permissionRequester: (_) async => PermissionStatus.denied` vs `permanentlyDenied` vs sequential grant on second call.

**Widget test patterns:**
- After deny tap Start: expect intro headline visible, weight headline absent
- Find feedback copy key/text
- Tap Continue secondary → weight step appears
- Retry path: first `denied`, second `granted` via call counter in fake requester

Do **not** run bare `flutter test`.

### Previous story intelligence (31-1)

| Learning | Impact on 31-2 |
|----------|----------------|
| `permanentlyDenied` already in enum + mapper | Use `activityPermissionStatus` directly — no enum edit |
| Today `_PermissionDeniedSlot` pattern | Copy visual/semantic pattern for intro feedback |
| Dual CTA: permanent → Open settings; reversible → Retry | Intro footer + inline Settings for permanent only |
| Diagnostic #1 marked `partial` pending 31-2 | Close onboarding slice in Sub-task D |
| OK commit gate A→D | Same sub-task workflow |
| Do-not-touch list from 31-1 | Now **do touch** `onboarding_flow.dart` + `onboarding_intro_page.dart` |

[Source: `stories/31-1-model-permanently-denied-with-settings-cta.md`]

### Cross-story context (Epic 31)

| Story | Scope | Relationship |
|-------|-------|--------------|
| 31-1 | done | Model + post-onboarding CTAs |
| **31-2** | **this story** | Onboarding intro feedback + no silent advance |
| 31-3 | Notification init rethrow | Independent |
| 31-4 | Centralize mappers | May relocate `mapPermissionStatus` — do not block 31-2 |
| 31-5 | Boot WM cancel | Independent |
| 31-6 | Toggle concurrency | Independent |

**Supersedes Story 13.1 AC #2 nuance:** 13.1 said "advance after grant or deny"; 31-2 requires **explicit Continue** after deny (AUD2-FR8). Happy-path auto-advance on grant unchanged.

### Git intelligence

| Commit | Relevance |
|--------|-----------|
| `57d6558` | feat(permissions): dual activity CTA Today/My Data — pattern to mirror |
| `b360200` | Story 31-1 done — enum/mapper ready |
| `89b57a1` | Epic 30 base `0.13.1+33` |

Active branch `main`; tracker `sprint-status-audits-2.yaml`.

### Latest tech / library notes

- **`permission_handler` ^12.0.1:** `PermissionStatus.permanentlyDenied` from `.request()` on Android after "Don't ask again". iOS may report `denied` until first request — test with injectable fakes.
- **`openAppSettings()`:** `unawaited()` — matches Today/My Data.
- **No new packages.**

### Project context reference

- OK commit gate: sub-tasks A→D, separate commits after Baptiste approval
- Tests: targeted file runs + `flutter test --tags critical` before story done
- Version bump: Epic 31 close (minor+1) — not per story
- Communication: French in chat; story in English

[Source: `docs/project-context.md` · `.cursor/rules/token-economy.mdc` · `.cursor/rules/app-versioning.mdc`]

### References

- [Source: `_bmad-output/planning-artifacts/epics-audits-2.md` §Story 31-2, AUD2-FR8, AUD2-UX3]
- [Source: `_bmad-output/planning-artifacts/sprint-change-proposal-2026-06-17.md` §4.2 onboarding rules]
- [Source: `_bmad-output/planning-artifacts/implementation-readiness-report-2026-07-24.md` §31-2 clarifications]
- [Source: `_bmad-output/planning-artifacts/audits_2/diagnostic-permissions-notifications.md` #1, #2]
- [Source: `_bmad-output/planning-artifacts/architecture.md` D-13]
- [Source: `lib/presentation/onboarding/onboarding_flow.dart`]
- [Source: `lib/presentation/onboarding/onboarding_intro_page.dart`]
- [Source: `lib/presentation/cubits/onboarding_cubit.dart`]
- [Source: `lib/presentation/screens/today_screen.dart` `_PermissionDeniedSlot`]
- [Source: `test/presentation/onboarding/onboarding_flow_test.dart`]
- [Source: `stories/31-1-model-permanently-denied-with-settings-cta.md`]
- [Source: `stories/13-1-onboarding-shell-and-intro-screen.md`]

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

### Completion Notes List

- Sub-task A: intro flow branches on permission outcome; footer Retry/Continue modes wired.
- Sub-task B: inline post-denial feedback on intro (BlocSelector, l10n en/fr, Open Settings for permanent).
- Sub-task C: onboarding flow tests inverted + 3 new cases; widget_test gate updated; 205 critical + 20 onboarding pass.
- Sub-task D: diagnostic #1/#2 and audits_2 README synced for 31-2 onboarding slice.

### File List

- `lib/presentation/onboarding/onboarding_flow.dart`
- `lib/presentation/onboarding/onboarding_intro_page.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_fr.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_fr.dart`
- `test/presentation/onboarding/onboarding_flow_test.dart`
- `test/widget_test.dart`
- `_bmad-output/planning-artifacts/audits_2/diagnostic-permissions-notifications.md`
- `_bmad-output/planning-artifacts/audits_2/README.md`
- `_bmad-output/implementation-artifacts/sprint-status-audits-2.yaml`
- `_bmad-output/implementation-artifacts/stories/31-2-onboarding-intro-post-denial-feedback.md`

## Change Log

- 2026-07-24: Story 31-2 implemented — intro post-denial feedback, no silent advance on deny, tests + diagnostic partial close.
