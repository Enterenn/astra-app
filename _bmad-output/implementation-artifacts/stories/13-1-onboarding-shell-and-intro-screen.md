# Story 13.1: Onboarding Shell & Intro Screen

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->
<!-- Mockup ref: assets/.../onboarding-light-ae0cd500-*.png (Baptiste 2026-06-17) -->
<!-- Supersedes Story 1.5 presentation — persistence keys and app gate pattern remain. -->

## Story

As a **user**,
I want a clear trust-first intro before body metrics,
So that I understand local-only tracking before granting sensor access.

## Acceptance Criteria

1. **Given** first launch (`onboarding_complete` false)  
   **When** onboarding renders  
   **Then** a **3-segment horizontal progress bar** shows step 1 active (filled accent segment; inactive segments muted)  
   **And** headline reads **Your Health. Your Phone. Period.** (centered, `AstraTypography.titleFor`)  
   **And** elevated card copy matches (locked strings — two paragraphs):  
   - *Astra tracks your movement, habits, and health metrics using only your device's built-in sensors. No accounts, no cloud leakage.*  
   - *Your personal evolution belongs to you—and only you.*  
   **And** optional **Learn more** disclaimer expands/collapses below the card without blocking Continue  
   **And** footer shows primary **Continue** only — **no Back** on step 1  
   **And** Continue is bottom-right aligned per mockup (not full-width), with trailing arrow icon (`PhosphorIconsRegular.arrowRight`)

2. **Given** user taps **Continue** on intro  
   **When** activity permission has not been granted  
   **Then** `OnboardingCubit.requestActivityPermission()` runs **before** weight step is shown (FR-22 bridge — trust copy visible first)  
   **And** system activity recognition / motion dialog appears  
   **And** flow advances to step 2 (weight) after dialog dismisses — **grant or deny**  
   **And** Continue shows `AstraButton.isLoading` / disabled state while `activityPermissionStatus == requesting`  
   **And** permission errors recover to idle (existing try/catch in cubit — do not leave button stuck)

3. **Given** onboarding shell for steps 2–3 (placeholders until Story 13.3)  
   **When** user is on step 2 or 3  
   **Then** progress bar shows correct active segment (2 or 3)  
   **And** footer shows **Back** (`PhosphorIconsRegular.arrowLeft`) + primary CTA slot (content stub OK)  
   **And** Back calls `OnboardingCubit.previousStep()`  
   **And** system back (`PopScope`) behavior preserved: step 0 cannot pop app; steps 1–2 pop to previous step

4. **Given** implementation complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no new analyzer issues  
   **And** `onboarding_flow_test.dart` asserts new intro headline (not old trust copy)  
   **And** test asserts Continue on intro **does** invoke permission request (inverted from Story 1.5)  
   **And** test asserts advance to step 2 after permission resolves  
   **And** existing app gate tests (`widget_test.dart`) still pass with `initialOnboardingComplete: true` seed

**Depends on:** Epics 1, 6, 10 (done). **Enables:** Stories 13.2 (ruler), 13.3 (weight/height pages).  
**Mockup ref:** `onboarding-light` — workspace `assets/.../onboarding-light-ae0cd500-*.png`.

## Tasks / Subtasks

- [x] **Sub-task A — 3-segment progress bar** (AC: #1, #3)
  - [x] Replace dot `OnboardingProgressIndicator` with horizontal **segment bar** (3 equal-width rounded rects; active = `accentPrimary`, inactive = `borderDefault` or subtle fill per mockup)
  - [x] Keep widget name or rename to `onboarding_progress_bar.dart` — update all imports
  - [x] Props: `currentStep` (0..2), `totalSteps: 3`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Shared onboarding shell chrome** (AC: #1, #3)
  - [x] Extract `OnboardingShell` (or `OnboardingScaffold`) wrapping: progress bar, `Expanded` content slot, footer row
  - [x] Footer API: `showBack: bool`, `primaryLabel`, `onPrimary`, `primaryLoading`, optional `secondary` (skip — used in 13.3)
  - [x] Step 1: no back; primary aligned **end** (right) with arrow on Continue
  - [x] Steps 2–3: back icon left, primary right (mockup pattern from weight/height screens)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Intro page + disclaimer** (AC: #1)
  - [x] Create `onboarding_intro_page.dart` (replaces trust page content — do **not** delete old files yet; Story 13.4 removes them)
  - [x] Layout: centered headline → `ElevatedCard` / `Material` with `bgElevated`, `kRadiusLg`, card padding `kCardPadding` → disclaimer
  - [x] Disclaimer: `ExpansionTile` or custom tap-to-expand **Learn more** — copy covers local-only storage, on-device sensors, no account (non-blocking)
  - [x] Wire into shell via `OnboardingFlow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Flow rewire + permission bridge** (AC: #2, #3)
  - [x] Update `OnboardingState.totalSteps` from `4` → `3`
  - [x] Refactor `onboarding_flow.dart` `IndexedStack` to 3 children: `OnboardingIntroPage`, weight placeholder, height placeholder
  - [x] Placeholder pages: minimal `OnboardingWeightPlaceholder` / `OnboardingHeightPlaceholder` — progress step 2/3 + shell footer only (no ruler — Story 13.2/13.3)
  - [x] Intro Continue handler: `await cubit.requestActivityPermission(); cubit.nextStep();` — **always** advance after request completes
  - [x] Remove intro step from old 4-step trust path in active `IndexedStack` (old pages stay on disk until 13.4)
  - [x] Preserve `BlocListener` → `onComplete` gate in `app.dart` unchanged
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Tests** (AC: #4)
  - [x] Update `test/presentation/onboarding/onboarding_flow_test.dart` for new copy + permission-on-continue + step-2 navigation
  - [x] Add widget test: disclaimer expand/collapse does not disable Continue
  - [x] Add widget test: loading state on Continue during permission request
  - [x] Run `flutter analyze` + `flutter test`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary (critical)

| Area | In scope (13.1) | Out of scope (later stories) |
|------|-----------------|------------------------------|
| Progress UI | 3-segment bar | — |
| Intro screen | Headline, card, disclaimer, Continue + permission bridge | — |
| Shell chrome | Shared footer (Back / CTA layout) | Skip ghost links (13.3) |
| Flow steps | 3-step `IndexedStack` with weight/height **placeholders** | Full weight/height UI (13.3) |
| Ruler picker | — | `AstraHorizontalRuler` (13.2) |
| Cubit cleanup | Use existing `requestActivityPermission()` on intro | Remove goal/notification fields (13.4) |
| Delete old pages | — | `OnboardingTrustPage`, permissions, goal, display name (13.4) |
| `completeOnboarding()` | Unchanged for now (still 4-step completion path via old code if reached) | Default 8000, metrics persist (13.3/13.4) |
| Version bump | None | Epic 13 close → `0.6.0+11` |

**Recommended dev order (from sprint-change-proposal):** Story **13.2** (ruler) can land before or parallel to 13.1 — no hard dependency for intro screen. Placeholders unblock 13.1 without waiting for ruler.

### Visual reference (authoritative mockup)

**Intro screen (`onboarding-light`):**

| Region | Spec |
|--------|------|
| Background | `colors.bgBase` |
| Progress | 3 horizontal pills; segment 1 filled `accentPrimary`, 2–3 muted |
| Headline | **Your Health. Your Phone. Period.** — centered, bold title token |
| Card | White/`bgElevated`, large radius (`kRadiusLg`), subtle elevation, horizontal inset `kSpace2xl` |
| Body | Two paragraphs inside card, `AstraTypography.bodyFor`, left-aligned in card |
| Disclaimer | Below card — collapsed by default; **Learn more** expands extra trust copy |
| CTA | **Continue** + `arrowRight`, bottom-right, primary fill, min height 48dp — **not** full-width |

**Do not** reuse old trust copy ("Your steps stay on this device.").

### Permission bridge (FR-22 amendment — Epic 13)

| Step | User action | Side effect |
|------|-------------|-------------|
| 1 Intro | Read trust copy | None |
| 1 Intro | Tap Continue | `requestActivityPermission()` → OS dialog → `nextStep()` to weight |
| 2 Weight (placeholder) | Back | `previousStep()` to intro |
| 3 Height (placeholder) | — | Stub until 13.3 |

**Inverted from Story 1.5:** intro Continue **must** trigger permission (tests previously asserted zero requests — update those tests).

**Non-blocking:** Denied permission still advances to weight step. No second onboarding gate on Steps tab (13.4 confirms).

**Do not** call `requestNotificationPermissionIfOptedIn()` from intro — notifications live in Settings (FR-24 amendment).

### Current file state (READ BEFORE EDITING)

**`lib/presentation/onboarding/onboarding_flow.dart`** — today:
- 4-step `IndexedStack`: Trust → Permissions → Goal → DisplayName
- Trust `onContinue` = `nextStep()` only (no permission)
- Completion only on display-name step

**Target after 13.1:**
- 3-step `IndexedStack`: Intro → WeightPlaceholder → HeightPlaceholder
- Intro `onContinue` = permission bridge + `nextStep()`
- `OnboardingState.totalSteps = 3`
- Old 4 pages remain in repo but **not** referenced in flow (13.4 deletes)

**`lib/presentation/onboarding/onboarding_progress_indicator.dart`** — today: 4 circular dots. **Replace** with segment bar.

**`lib/presentation/cubits/onboarding_state.dart`** — `totalSteps = 4`; goal/notification fields still present (13.4 simplifies).

**`lib/app.dart`** — gate pattern unchanged: `initialOnboardingComplete ? AppScaffold : OnboardingFlow`.

### Reuse — do not reinvent

| Asset | Location | Use in 13.1 |
|-------|----------|-------------|
| `AstraButton` | `lib/presentation/widgets/astra_button.dart` | Continue with `isLoading` |
| `OnboardingCubit.requestActivityPermission()` | `onboarding_cubit.dart` | Intro bridge |
| `ActivityPermissionResolver` | `core/permissions/activity_permission_resolver.dart` | Unchanged |
| `PhosphorIconsRegular` | existing onboarding pages | `arrowLeft`, `arrowRight` |
| `AstraInsetShadow` | optional on card if matches elevated surfaces | Only if consistent with Steps cards |

**Do not** add new packages. **Do not** touch `UserPreferencesRepository` schema.

### Suggested file tree after 13.1

```
lib/presentation/onboarding/
├── onboarding_flow.dart                 # UPDATE — 3 steps, intro bridge
├── onboarding_intro_page.dart           # NEW
├── onboarding_shell.dart                # NEW (or onboarding_scaffold.dart)
├── onboarding_progress_bar.dart         # NEW (replaces dot indicator)
├── onboarding_weight_placeholder.dart   # NEW — minimal stub
├── onboarding_height_placeholder.dart   # NEW — minimal stub
├── onboarding_trust_page.dart           # UNCHANGED on disk — removed in 13.4
├── onboarding_permissions_page.dart     # UNCHANGED on disk — removed in 13.4
├── onboarding_goal_page.dart            # UNCHANGED on disk — removed in 13.4
├── onboarding_display_name_page.dart    # UNCHANGED on disk — removed in 13.4
└── onboarding_progress_indicator.dart   # DELETE or replace — prefer rename to progress_bar

lib/presentation/cubits/
├── onboarding_state.dart                # UPDATE — totalSteps = 3
└── onboarding_cubit.dart                # UNCHANGED logic for permission (13.4 prunes fields)

test/presentation/onboarding/
└── onboarding_flow_test.dart            # UPDATE — new AC assertions
```

### Anti-patterns (do not do in 13.1)

- ❌ Implement `AstraHorizontalRuler` or full weight/height pickers (13.2 / 13.3)
- ❌ Delete old onboarding pages (13.4)
- ❌ Change `completeOnboarding()` persistence contract yet
- ❌ Request notification permission on intro
- ❌ Block navigation when activity permission denied
- ❌ Show OS permission dialog **before** user taps Continue on intro
- ❌ Reintroduce goal or display-name steps in active flow
- ❌ Full-width Continue on intro (mockup is bottom-right pill)
- ❌ Break `app.dart` gate or `ThemeCubit` cold-start
- ❌ Batch sub-tasks into one commit without Baptiste review

### Epic 13 cross-story context

| Story | Focus | Relation to 13.1 |
|-------|-------|------------------|
| **13.1** (this) | Shell, segment bar, intro, permission bridge | Foundation for 13.3 pages |
| 13.2 | `AstraHorizontalRuler` | Independent widget; placeholders OK without it |
| 13.3 | Weight + height pages | Replaces placeholders; segmented control + ruler |
| 13.4 | Cleanup + tests + checklist | Deletes old pages; simplifies cubit; `completeOnboarding` defaults |

### Mandatory dev workflow

Follow [`docs/project-context.md`](../../../docs/project-context.md):

- One commit per sub-task (A–E) after Baptiste review
- Review brief format required before each commit
- No version bump until Epic 13 closes (`0.6.0+11`)

### Project Structure Notes

- Aligns with architecture `lib/presentation/onboarding/` module
- FR-22 amended: trust on intro screen, permission on Continue bridge
- Presentation-only change — no ingestion, DB, or nav shell changes

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 13, Story 13.1]
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-06-17.md — §4.2 UX, §4.4 AC, implementation order]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md — §2.7 (superseded by CC §4.2)]
- [Source: _bmad-output/planning-artifacts/architecture.md — presentation/onboarding/]
- [Source: _bmad-output/implementation-artifacts/stories/1-5-trust-first-onboarding-flow.md — gate pattern, cubit, tests to invert]
- [Source: mockup assets/.../onboarding-light-ae0cd500-*.png]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- Replaced 4-dot progress indicator with `OnboardingProgressBar` (3 horizontal segments).
- Added `OnboardingShell` shared chrome: segment bar, content slot, footer with Back/Continue layout.
- New `OnboardingIntroPage` with locked headline/card copy, expandable Learn more disclaimer.
- Rewired flow to 3 steps (intro → weight placeholder → height placeholder) with permission bridge on intro Continue.
- `OnboardingState.totalSteps` updated to 3.
- 9 onboarding widget tests pass; gate tests with `initialOnboardingComplete: true` pass.

### File List

- lib/presentation/onboarding/onboarding_progress_bar.dart (NEW)
- lib/presentation/onboarding/onboarding_shell.dart (NEW)
- lib/presentation/onboarding/onboarding_intro_page.dart (NEW)
- lib/presentation/onboarding/onboarding_weight_placeholder.dart (NEW)
- lib/presentation/onboarding/onboarding_height_placeholder.dart (NEW)
- lib/presentation/onboarding/onboarding_flow.dart (UPDATED)
- lib/presentation/cubits/onboarding_state.dart (UPDATED)
- lib/presentation/onboarding/onboarding_progress_indicator.dart (DELETED)
- lib/presentation/onboarding/onboarding_trust_page.dart (UPDATED — import only)
- lib/presentation/onboarding/onboarding_permissions_page.dart (UPDATED — import only)
- lib/presentation/onboarding/onboarding_goal_page.dart (UPDATED — import only)
- lib/presentation/onboarding/onboarding_display_name_page.dart (UPDATED — import only)
- test/presentation/onboarding/onboarding_flow_test.dart (UPDATED)
- test/widget_test.dart (UPDATED — headline assertions)

## Change Log

- 2026-06-17: Story 13.1 — onboarding shell, intro screen, 3-step flow, permission bridge (Date: 2026-06-17)

## Technical Requirements

1. **Three visible steps:** Intro → Weight (placeholder) → Height (placeholder); full-screen; no bottom tabs
2. **Segment progress:** 3 horizontal segments, not dots
3. **Locked intro copy:** Headline + two card paragraphs exactly as AC #1
4. **Disclaimer:** Expandable; never blocks Continue
5. **Permission bridge:** `requestActivityPermission()` on intro Continue; advance after dialog regardless of grant/deny
6. **Loading state:** `AstraButton.isLoading` while `PermissionRequestStatus.requesting`
7. **Footer chrome:** No back step 1; back steps 2–3; Continue bottom-right with arrow on step 1
8. **Gate preserved:** `app.dart` `OnboardingFlow` / `AppScaffold` switch unchanged
9. **Repository-only writes:** No cubit SQL; no `completeOnboarding` changes in 13.1
10. **Tests:** Invert 1.5 "no permission on trust continue" assertion

## Architecture Compliance

| Decision | Requirement for 13.1 |
|----------|----------------------|
| D-09 | `OnboardingCubit` — flutter_bloc Cubit only |
| D-10 | Onboarding stack separate from bottom-tab shell |
| D-13 | `permission_handler ^12.0.1` via existing cubit |
| D-22 | Pages under `presentation/onboarding/` |
| D-27 | Phosphor icons for back/continue arrows |
| Write path | No new persistence in 13.1 |
| Navigation | No GoRouter; `MaterialApp.home` gate unchanged |
| Network | No network calls |

## Library & Framework Requirements

| Package | Version | 13.1 action |
|---------|---------|-------------|
| permission_handler | ^12.0.1 | **Reuse** — intro bridge only |
| flutter_bloc | ^9.1.1 | **Reuse** — `OnboardingCubit` |
| phosphoricons_flutter | existing | **Reuse** — arrow icons |

**Do NOT add** new runtime packages.

## File Structure Requirements

| Path | Action |
|------|--------|
| `lib/presentation/onboarding/onboarding_flow.dart` | UPDATE |
| `lib/presentation/onboarding/onboarding_intro_page.dart` | NEW |
| `lib/presentation/onboarding/onboarding_shell.dart` | NEW |
| `lib/presentation/onboarding/onboarding_progress_bar.dart` | NEW (replace dot indicator) |
| `lib/presentation/onboarding/onboarding_weight_placeholder.dart` | NEW |
| `lib/presentation/onboarding/onboarding_height_placeholder.dart` | NEW |
| `lib/presentation/cubits/onboarding_state.dart` | UPDATE — `totalSteps = 3` |
| `test/presentation/onboarding/onboarding_flow_test.dart` | UPDATE |

## Testing Requirements

- **Widget:** intro headline visible; old trust headline absent
- **Widget:** Continue triggers permission requester (mock inject)
- **Widget:** after permission resolves, step 2 placeholder visible
- **Widget:** disclaimer expand does not disable Continue
- **Widget:** loading indicator on Continue during request
- **Regression:** `widget_test.dart` shell tests with onboarding complete seed
- **Commands:** `flutter analyze` (0 issues), `flutter test` (all pass)

## Previous Story Intelligence

From **Story 1.5** (done — superseded at UX level):

- `OnboardingCubit.requestActivityPermission()` + `_resolvePermission` try/catch — **reuse**; do not duplicate permission logic
- `AstraButton.isLoading` pattern exists on permissions page — mirror on intro
- `PopScope` + `previousStep` for system back — preserve
- Tests explicitly asserted **no** permission on trust Continue — **must invert** for 13.1
- Review-before-commit: sub-tasks with Baptiste OK gate
- Injectable `permissionRequester` on cubit for tests — keep using

From **Epic 10** (done):

- Settings owns notification opt-in — do not surface in onboarding
- Profile editor owns display name — not in new flow

From **Epic 6** (done):

- `height_cm` / `weight_kg` prefs exist — placeholders only in 13.1; persistence in 13.3

## Git Intelligence Summary

Recent commits relevant to 13.1:

| Commit | Relevance |
|--------|-----------|
| `28330c8` | Epic 13 backlog + sprint-change-proposal — source of truth for flow |
| `8f40e8e` | `AstraInsetShadow` on segmented control — reference for elevated card styling |
| `f2dda2e` | Pipeline cleanup — unrelated; avoid drive-by changes |

**Convention:** `feat(onboarding):`, `test(onboarding):` scoped commits per sub-task.

## Latest Tech Information

- **permission_handler 12.0.1:** `Permission.activityRecognition` (Android API 29+); iOS uses `Permission.sensors` via `ActivityPermissionResolver` — unchanged from 1.5
- **Flutter 3.x:** `PopScope` (not deprecated `WillPopScope`) — already used in flow
- **No new APIs required** for segment bar or expandable disclaimer

## Project Context Reference

Mandatory — [`docs/project-context.md`](../../../docs/project-context.md):

- Review-before-commit gate (sub-tasks A–E)
- Commit message convention: `type(scope): imperative summary`
- Story file: `_bmad-output/implementation-artifacts/stories/13-1-onboarding-shell-and-intro-screen.md`
- Version bump only at Epic 13 close: `0.6.0+11` in `pubspec.yaml` + `README.md`

## Story Completion Status

- Status: **ready-for-dev**
- Ultimate context engine analysis completed — comprehensive developer guide created
- Epic 13 status: **in-progress** (first story created)
- **Critical guardrail:** Intro Continue must trigger activity permission **after** trust copy is shown — enforce in code and tests (opposite of Story 1.5)
