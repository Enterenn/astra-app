# Story 13.4: Flow Completion & Cleanup

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->
<!-- Epic 13 finale — delete legacy 4-step pages, prune cubit dead state, align tests + beta checklist -->
<!-- Depends on Story 13.3 (done) — onboarding is already completable end-to-end; this story removes cruft -->

## Story

As a **maintainer**,
I want the old onboarding steps removed and tests updated,
So that the codebase reflects the new 3-step flow only.

## Acceptance Criteria

1. **Given** the codebase after Story 13.3  
   **When** a repo-wide search runs for legacy onboarding page classes  
   **Then** `OnboardingTrustPage`, `OnboardingPermissionsPage`, `OnboardingGoalPage`, and `OnboardingDisplayNamePage` have **no remaining Dart files** under `lib/`  
   **And** no `lib/` import references those classes  
   **And** active flow remains **intro → weight → height** only (`onboarding_flow.dart`)

2. **Given** `OnboardingCubit` / `OnboardingState` after cleanup  
   **When** inspected  
   **Then** legacy 4-step fields and methods are removed: `goalInput`, `notificationOptIn`, `notificationPermissionStatus`, `isGoalValid`, `resolvedGoal`, `setGoalInput`, `setNotificationOptIn`, `requestNotificationPermissionIfOptedIn`, `completeOnboarding`  
   **And** `activityPermissionStatus` + `requestActivityPermission()` remain (intro bridge — Story 13.1)  
   **And** `completeWithHeight()` remains the **sole** onboarding completion path  
   **And** `step_goal_validator` import is removed from `onboarding_state.dart` if no longer needed

3. **Given** user denied activity permission on intro **Continue**  
   **When** they complete weight + height and land on Steps (Today tab)  
   **Then** `TodayStatus.noPermission` empty-state applies (dashed ring, `--` count, "Open settings to allow step access" CTA)  
   **And** onboarding does **not** reappear on cold restart (`onboarding_complete=true`)  
   **And** no second onboarding permission gate exists in the post-onboarding shell

4. **Given** user granted activity on intro and completed onboarding  
   **When** app is killed and reopened  
   **Then** onboarding does not re-show (FUNC-10 / V-10)  
   **And** trust copy was shown **before** the OS permission dialog (order preserved)

5. **Given** test suite after cleanup  
   **When** `flutter analyze` and `flutter test` run  
   **Then** zero new analyzer issues  
   **And** `onboarding_cubit_test.dart` has no tests referencing removed APIs (`completeOnboarding`, `goalInput`, notification opt-in)  
   **And** `onboarding_flow_test.dart` asserts **3-step** flow (intro / weight / height) — no legacy copy ("Your steps stay on this device.", "Allow activity access", goal field)  
   **And** `widget_test.dart` onboarding gate test uses `completeWithHeight()` (or full tap-through) instead of `completeOnboarding`  
   **And** at least one test covers denied-permission intro → complete → `TodayStatus.noPermission` (flow or cubit + widget combo)

6. **Given** beta checklist FUNC-10 and VIS-10  
   **When** updated for Epic 13  
   **Then** manual repro steps read: intro trust copy → **Continue** → grant/deny activity OS dialog → weight (optional Skip) → height **Let's Go** → kill app → reopen → no onboarding re-show  
   **And** notes column documents Epic 13 redesign date

7. **Given** Epic 13 is the last story in the epic  
   **When** story 13.4 is marked done  
   **Then** bump `pubspec.yaml` to `0.6.0+11` and README.md project status version row (moyen epic close per sprint-change-proposal)  
   **And** mark `epic-13: done` in `sprint-status.yaml` (manual epic close step)

**Depends on:** Story 13.3 (done). **Closes:** Epic 13 Onboarding Redesign.

## Tasks / Subtasks

- [x] **Sub-task A — Delete legacy onboarding pages** (AC: #1)
  - [x] Delete `onboarding_trust_page.dart`, `onboarding_permissions_page.dart`, `onboarding_goal_page.dart`, `onboarding_display_name_page.dart`
  - [x] Run `rg` on `lib/` to confirm zero imports of deleted classes
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Prune cubit + state** (AC: #2)
  - [x] Remove dead fields/getters/methods from `onboarding_state.dart` and `onboarding_cubit.dart` (list in Dev Notes)
  - [x] Verify `onboarding_flow.dart`, weight/height pages, intro page still compile — no callers of removed APIs
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Rewrite cubit + widget gate tests** (AC: #5)
  - [x] Update `onboarding_cubit_test.dart`: remove `completeOnboarding` / goal / notification tests; rename "trust step" → "intro step"; keep `completeWithHeight`, permission, skip tests
  - [x] Update `widget_test.dart` onboarding gate group to use `completeWithHeight()` or tap-through Let's Go
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Flow tests + denied-permission landing** (AC: #3, #5)
  - [x] Add `onboarding_flow_test.dart` case: denied permission on intro → complete height via Skip/Let's Go → assert `onComplete` + optional pump to `AppScaffold` with `TodayStatus.noPermission` if feasible with existing test harness
  - [x] Confirm no legacy onboarding strings in any test file (`rg` audit)
  - [x] Run `flutter analyze` + `flutter test`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Docs + epic close** (AC: #6, #7)
  - [x] Update `docs/BETA_CHECKLIST.md` FUNC-10 and VIS-10 repro steps (do **not** rewrite historical pass rows — add new note for Epic 13 re-verification)
  - [x] Optional sync: `_bmad-output/planning-artifacts/architecture.md` onboarding module list (`intro, weight, height` + `astra_horizontal_ruler.dart`)
  - [x] Bump `pubspec.yaml` → `0.6.0+11`, README project status version row
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary (critical)

| Area | In scope (13.4) | Out of scope |
|------|-----------------|--------------|
| Delete legacy pages | 4 old page files | `onboarding_intro_page.dart`, weight/height pages, shell, ruler |
| Cubit cleanup | Remove 4-step dead state/APIs | Change `completeWithHeight` persist semantics |
| Permission bridge | Keep intro `requestActivityPermission` | Re-add dedicated permissions screen |
| Notification permission | Remove onboarding opt-in path | Profile notification toggle (unchanged) |
| Display name | Remove onboarding step remnants | Profile display name editor (unchanged) |
| Goal collection | Remove onboarding goal UI/state | My Data / Steps goal editor (unchanged) |
| Version bump | `0.6.0+11` at epic close | Per-story bumps |
| Epic status | Mark `epic-13: done` after 13.4 done | Epic retrospective (optional) |

**13.3 already made onboarding completable.** This story is **deletion + test/doc alignment** — not new UX.

### Files to DELETE (no active imports today)

| File | Replaced by |
|------|-------------|
| `lib/presentation/onboarding/onboarding_trust_page.dart` | `onboarding_intro_page.dart` |
| `lib/presentation/onboarding/onboarding_permissions_page.dart` | Intro Continue permission bridge |
| `lib/presentation/onboarding/onboarding_goal_page.dart` | Default `kDefaultStepGoal` on `completeWithHeight` |
| `lib/presentation/onboarding/onboarding_display_name_page.dart` | Removed from flow (Profile editor remains) |

**Keep:** `onboarding_progress_bar.dart` (used by `OnboardingShell`), `onboarding_intro_page.dart`, weight/height pages, shell, flow, metric picker layout.

### Cubit / state — remove exactly

**`onboarding_state.dart` — REMOVE:**

```dart
// Fields
notificationOptIn
goalInput
notificationPermissionStatus

// Getters
isGoalValid
resolvedGoal

// copyWith params
notificationOptIn, goalInput, notificationPermissionStatus

// Import (if unused after removal)
import '../../core/validation/step_goal_validator.dart';
```

**`onboarding_cubit.dart` — REMOVE:**

```dart
setNotificationOptIn
setGoalInput
requestNotificationPermissionIfOptedIn
completeOnboarding({int? goal, String? displayName})
```

**KEEP:** `activityPermissionStatus`, `requestActivityPermission`, body-metric session fields, `completeWithHeight`, skip/commit helpers, step navigation.

### Permission denied post-onboarding (AC #3 — do not reimplement)

Existing behavior — **verify, do not rebuild:**

| Layer | Behavior when activity denied |
|-------|------------------------------|
| Intro | `requestActivityPermission()` → `PermissionRequestStatus.denied` → still `nextStep()` to weight |
| Completion | `completeWithHeight()` sets `onboarding_complete=true` regardless of permission |
| App gate | `app.dart` shows `AppScaffold` when onboarding complete |
| Steps/Today | `TodayCubit.refreshMetadata()` → `TodayStatus.noPermission` when `activityPermissionGranted()` false |
| UI | `today_screen.dart`: dashed ring, `--`, `TextButton` → `openAppSettings()` |
| My Data | `BackgroundCollectionStatus.permissionDenied` on status card (unchanged) |

**Anti-pattern:** Adding a second permission screen or blocking completion when denied.

### `goal_notifications_enabled` on first launch

`completeWithHeight()` does **not** write `goal_notifications_enabled`. Repository default is `false` when key absent (`getGoalNotificationsEnabled()`). **Do not** add a write in 13.4 — Profile toggle owns opt-in (Story 4.x / FUNC-02).

### Current file state (READ BEFORE EDITING)

**`onboarding_flow.dart`** — already 3-step; only imports intro, weight, height, shell. No legacy pages.

**`onboarding_cubit.dart`** — dual completion paths: `completeWithHeight()` (active) + `completeOnboarding()` (dead — only tests call it).

**`onboarding_cubit_test.dart`** — 8 tests still target removed 4-step APIs (`completeOnboarding`, `goalInput`, notification opt-in). Must rewrite.

**`widget_test.dart`** (~line 300) — calls `cubitRef!.completeOnboarding(goal: 8000)` to exit onboarding gate test.

**`onboarding_flow_test.dart`** — already 3-step aware (13.1/13.3). Missing: end-to-end denied permission → shell landing test.

### FUNC-10 / VIS-10 update text (suggested)

Replace "trust before permission" repro with:

> Fresh install → intro headline **Your Health. Your Phone. Period.** visible → tap **Continue** → OS activity dialog (grant or deny) → weight step → height **Let's Go** → app shows Steps tab → force-stop → relaunch → onboarding does not reappear. If denied: Steps shows permission empty state, not onboarding.

Add note: `Epic 13 redesign — re-verify on release APK before next beta gate.`

### Suggested file tree after 13.4

```
lib/presentation/onboarding/
├── onboarding_flow.dart              # UNCHANGED (verify)
├── onboarding_intro_page.dart        # KEEP
├── onboarding_weight_page.dart         # KEEP
├── onboarding_height_page.dart       # KEEP
├── onboarding_shell.dart             # KEEP
├── onboarding_progress_bar.dart      # KEEP
├── onboarding_metric_picker_layout.dart  # KEEP
├── onboarding_trust_page.dart        # DELETE
├── onboarding_permissions_page.dart  # DELETE
├── onboarding_goal_page.dart         # DELETE
└── onboarding_display_name_page.dart # DELETE

lib/presentation/cubits/
├── onboarding_state.dart             # UPDATE — prune legacy fields
└── onboarding_cubit.dart             # UPDATE — prune legacy methods

test/presentation/cubits/
└── onboarding_cubit_test.dart        # UPDATE — remove 4-step tests

test/presentation/onboarding/
└── onboarding_flow_test.dart         # UPDATE — denied permission landing

test/widget_test.dart                 # UPDATE — completeWithHeight gate

docs/BETA_CHECKLIST.md                # UPDATE — FUNC-10, VIS-10 repro

pubspec.yaml                          # UPDATE — 0.6.0+11
README.md                             # UPDATE — version row
```

### Anti-patterns (do not do in 13.4)

- ❌ Reintroduce goal/display-name/notification steps anywhere in flow
- ❌ Block `completeWithHeight` when activity permission denied
- ❌ Delete `onboarding_intro_page.dart` or ruler/shell files
- ❌ Change `completeWithHeight` persist keys or default goal semantics
- ❌ Rewrite Profile goal/display-name/notification editors
- ❌ Bump version before story review commits complete
- ❌ Mark FUNC-10 pass without noting Epic 13 re-verification needed on device
- ❌ Batch sub-tasks into one commit without Baptiste review

### Epic 13 cross-story context

| Story | Focus | Relation to 13.4 |
|-------|-------|------------------|
| 13.1 (done) | Shell, intro, permission bridge | Intro + `activityPermissionStatus` preserved |
| 13.2 (done) | `AstraHorizontalRuler` | No changes |
| 13.3 (done) | Weight/height + `completeWithHeight` | Completion path stays; delete old pages now |
| **13.4** (this) | Delete legacy, prune state, tests, docs, version | Epic finale |

### Mandatory dev workflow

Follow [`docs/project-context.md`](../../../docs/project-context.md):

- One commit per sub-task (A–E) after Baptiste review
- Review brief format required before each commit
- Version bump only in sub-task E (epic close)

### Project Structure Notes

- Aligns with architecture target: `presentation/onboarding/` = intro + weight + height
- FR-22–24: trust on intro, activity on Continue bridge, default goal 8000 at complete (no goal UI)
- FR-23 amended: goal not collected in onboarding UI
- Supersedes Story 1.5 presentation; persistence keys (`onboarding_complete`, `daily_step_goal`) unchanged

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 13, Story 13.4]
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-06-17.md — §4.4 Story 13.4, §4.5 architecture, version `0.6.0+11`]
- [Source: _bmad-output/implementation-artifacts/stories/13-3-weight-and-height-onboarding-steps.md — completeWithHeight, deferred cleanup]
- [Source: lib/presentation/onboarding/onboarding_flow.dart — active 3-step flow]
- [Source: lib/presentation/cubits/onboarding_cubit.dart — dual completion paths]
- [Source: lib/presentation/cubits/today_cubit.dart — `TodayStatus.noPermission`]
- [Source: lib/presentation/screens/today_screen.dart — permission empty state CTA]
- [Source: docs/BETA_CHECKLIST.md — FUNC-10, VIS-10]

## Dev Agent Record

### Agent Model Used

Claude (Cursor Agent)

### Debug Log References

- Widget test `AstraApp` + denied permission abandoned: `setState` during `runAsync` + sqflite deadlock; coverage via flow test + existing `today_cubit_test` noPermission case.

### Completion Notes List

- Deleted 4 legacy onboarding page files; zero `lib/` references remain.
- Pruned `OnboardingState` / `OnboardingCubit` to 3-step APIs only; `completeWithHeight()` sole completion path.
- Rewrote cubit tests (9 cases) and widget gate to `completeWithHeight()`.
- Added denied-permission flow completion test; full suite 821 passed.
- Updated FUNC-10 / VIS-10 repro steps; bumped `0.6.0+11`; marked `epic-13: done`.
- Five commits (sub-tasks A–E) after Baptiste review gate.

### File List

- `lib/presentation/onboarding/onboarding_trust_page.dart` (deleted)
- `lib/presentation/onboarding/onboarding_permissions_page.dart` (deleted)
- `lib/presentation/onboarding/onboarding_goal_page.dart` (deleted)
- `lib/presentation/onboarding/onboarding_display_name_page.dart` (deleted)
- `lib/presentation/cubits/onboarding_state.dart`
- `lib/presentation/cubits/onboarding_cubit.dart`
- `test/presentation/cubits/onboarding_cubit_test.dart`
- `test/presentation/onboarding/onboarding_flow_test.dart`
- `test/widget_test.dart`
- `docs/BETA_CHECKLIST.md`
- `_bmad-output/planning-artifacts/architecture.md`
- `pubspec.yaml`
- `README.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

## Change Log

- 2026-06-17 — Story 13.4 implemented: legacy onboarding cleanup, test alignment, Epic 13 close at `0.6.0+11`.
- 2026-06-17 — Code review fixes: denied-permission landing test, version `0.6.1+12`.

## Technical Requirements

1. **Delete** 4 legacy onboarding page files; zero `lib/` references remain
2. **Prune** `OnboardingState` / `OnboardingCubit` per Dev Notes removal list
3. **Preserve** intro permission bridge + `completeWithHeight` completion
4. **Rewrite** cubit tests — no `completeOnboarding`, `goalInput`, notification onboarding tests
5. **Update** `widget_test.dart` onboarding gate to use `completeWithHeight`
6. **Add** denied-permission → complete → no re-onboarding test coverage
7. **Update** FUNC-10 / VIS-10 repro steps in `docs/BETA_CHECKLIST.md`
8. **Bump** version `0.6.0+11` + README at epic close (sub-task E)
9. **Run** `flutter analyze` (0 issues) + `flutter test` (all green)

## Architecture Compliance

| Decision | Requirement for 13.4 |
|----------|----------------------|
| D-09 | Single `OnboardingCubit` — prune, do not split |
| D-10 | Onboarding stack separate from tab shell — unchanged |
| D-11 | `onboarding_complete` retained after purge — unchanged |
| D-22 | `presentation/onboarding/` — intro + weight + height only after cleanup |
| Write path | `UserPreferencesRepository` via `completeWithHeight` only |
| Navigation | `BlocListener` → `app.dart` gate unchanged |

## Library & Framework Requirements

| Package | Version | 13.4 action |
|---------|---------|-------------|
| flutter_bloc | ^9.1.1 | **Reuse** — simplify state only |
| permission_handler | (existing) | **Keep** activity request on intro; remove notification onboarding path |

**Do NOT add** packages.

## File Structure Requirements

| Path | Action |
|------|--------|
| `lib/presentation/onboarding/onboarding_trust_page.dart` | DELETE |
| `lib/presentation/onboarding/onboarding_permissions_page.dart` | DELETE |
| `lib/presentation/onboarding/onboarding_goal_page.dart` | DELETE |
| `lib/presentation/onboarding/onboarding_display_name_page.dart` | DELETE |
| `lib/presentation/cubits/onboarding_state.dart` | UPDATE — prune legacy |
| `lib/presentation/cubits/onboarding_cubit.dart` | UPDATE — prune legacy |
| `test/presentation/cubits/onboarding_cubit_test.dart` | UPDATE |
| `test/presentation/onboarding/onboarding_flow_test.dart` | UPDATE |
| `test/widget_test.dart` | UPDATE |
| `docs/BETA_CHECKLIST.md` | UPDATE — FUNC-10, VIS-10 |
| `pubspec.yaml` | UPDATE — `0.6.0+11` |
| `README.md` | UPDATE — version row |

## Testing Requirements

- **Delete audit:** `rg OnboardingTrustPage|OnboardingPermissionsPage|OnboardingGoalPage|OnboardingDisplayNamePage lib/` → no matches
- **Cubit:** `completeWithHeight` persists goal 8000 + onboarding flag; skip weight/height null persist (keep existing 13.3 tests)
- **Cubit:** `requestActivityPermission` granted/denied/throws (keep existing tests)
- **Cubit:** no tests for removed `completeOnboarding` / `goalInput` / notification opt-in
- **Flow:** 3 steps only; legacy strings absent
- **Flow:** denied permission on intro still reaches weight; full complete fires `onComplete`
- **Widget gate:** `widget_test.dart` exits onboarding without `completeOnboarding`
- **Permission landing:** after complete with denied permission, Today shows `noPermission` OR cubit state verified in integration test
- **Commands:** `flutter analyze`, `flutter test`

## Previous Story Intelligence

From **Story 13.3** (done):

- `completeWithHeight()` is the active completion path — do not alter persist semantics
- Old pages intentionally left on disk — **delete now**
- `goalInput` / `notificationOptIn` left in state — **remove now**
- `widget_test` still uses `completeOnboarding` — **fix in 13.4**
- Commits: `feat(onboarding):`, `test(onboarding):` per sub-task
- Review-before-commit gate (sub-tasks A–E)

From **Story 13.1** (done):

- Permission bridge on intro only — preserve `requestActivityPermission` + loading state
- `totalSteps = 3` — do not change
- Old trust page superseded by intro — safe to delete

From **Story 13.2** (done):

- No ruler changes expected in 13.4

From **Story 1.5** (superseded):

- Historical reference only — persistence keys and app gate pattern remain valid
- Do not restore 4-step flow or dot progress indicator

## Git Intelligence Summary

Recent Epic 13 commits:

| Commit | Relevance |
|--------|-----------|
| `b30f86e` | Story 13.3 review fixes — `completeWithHeight` stable |
| `d41c4c2` | Flow tests for weight/height/skip — extend for denied permission |
| `d817fd0` | End-to-end completion wired — cleanup only remains |

**Convention:** `chore(onboarding):` for deletes, `refactor(onboarding):` for cubit prune, `test(onboarding):` for test rewrites, `docs(checklist):` for FUNC-10.

## Latest Tech Information

- **Flutter 3.x / Dart 3.12:** No API changes — file deletion + state prune only
- **permission_handler:** Activity permission on intro unchanged; notification permission removed from onboarding cubit (Profile uses separate path)
- **No schema migration** — preference keys unchanged

## Project Context Reference

Mandatory — [`docs/project-context.md`](../../../docs/project-context.md):

- Review-before-commit gate (sub-tasks A–E)
- Version bump at epic close: `0.6.0+11` in `pubspec.yaml` + `README.md`
- `.cursor/rules/app-versioning.mdc` — moyen bump for feature epic close
- Story file: `_bmad-output/implementation-artifacts/stories/13-4-flow-completion-and-cleanup.md`

## Story Completion Status

- Status: **done**
- Epic 13 status: **done** (13.1–13.4 complete)
- Version: **0.6.1+12**

### Review Findings

- [x] [Review][Patch] AC #3/#5 denied-permission → `TodayStatus.noPermission` chain — added `widget_test.dart` integration test with UI intro/weight + shell landing assertion
- [x] [Review][Patch] Denied-permission flow test bypassed UI — rewritten to tap intro Continue + weight Skip; height complete in `runAsync` (sqlite zone)
- [x] [Review][Defer] `findsAtLeastNWidgets` loosened — replaced with Semantics `Steps` label finder in `widget_test.dart`
- [x] [Review][Patch] Sprint tracking — `13-4-flow-completion-and-cleanup: done` synced in sprint-status
