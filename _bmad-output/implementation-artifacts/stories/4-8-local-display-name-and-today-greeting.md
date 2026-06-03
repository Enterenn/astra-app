# Story 4.8: Local Display Name and Today Greeting

Status: done

<!-- User-confirmed 2026-06-03: English-only copy; i18n deferred. No coach personalization on celebration/notifications. -->

## Story

As a **user**,
I want to optionally tell the app my first name and see a calm greeting on Today,
So that the app feels personal without creating an account or sending data anywhere.

## Acceptance Criteria

1. **Given** first launch onboarding (trust → permissions → goal)
   **When** user reaches the new optional display-name step after goal
   **Then** copy asks what to call them (English only)
   **And** **Skip** completes onboarding without storing a name
   **And** non-empty trimmed input persists to `user_preferences` key `display_name` via `UserPreferencesRepository` only

2. **Given** no `display_name` stored (null/empty after trim)
   **When** Today loads
   **Then** no greeting line is rendered and ring layout is unchanged

3. **Given** a stored display name
   **When** Today loads
   **Then** one caption line above the goal ring shows **Hello, {name}** (Figtree caption, `text.secondary`, horizontal screen padding)
   **And** step totals are **not** repeated under the greeting (ring remains sole numeric hero)

4. **Given** My Data screen exists
   **When** user edits display name and saves
   **Then** preference persists immediately and Today greeting updates on next `TodayCubit.refreshMetadata()` without app restart

5. **Given** full health-data purge (Story 4.5)
   **When** purge completes
   **Then** `display_name` is retained with `daily_step_goal`, `theme_mode`, and onboarding flag (FR20 / D-11)

6. **Given** UX tone guardrails (UX §4.6)
   **When** greeting or onboarding copy is shown
   **Then** voice is calm and factual — no coach language, exclamation marks, or gamification

## Tasks / Subtasks

- [x] **Sub-task A — Preference key + repository API** (AC: #1, #4, #5)
  - [x] Add `kDisplayNameKey = 'display_name'` and `kMaxDisplayNameLength = 32` in `lib/core/constants/preference_keys.dart`
  - [x] `UserPreferencesRepository`: `Future<String?> getDisplayName()`, `Future<void> setDisplayName(String? name)` — trim; empty/whitespace-only clears key via delete (or consistent null read)
  - [x] Reject writes over max length (`ArgumentError` or silent truncate — prefer reject to match goal validation style)
  - [x] Unit tests in `test/data/repositories/user_preferences_repository_test.dart`
  - [x] Extend `test/data/repositories/step_repository_purge_test.dart`: seed `display_name`, assert key survives purge
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Onboarding display-name step** (AC: #1, #6)
  - [x] Add `lib/presentation/onboarding/onboarding_display_name_page.dart` — single text field, primary Continue, secondary Skip
  - [x] `OnboardingState.totalSteps`: `3` → `4`; progress dots on all four pages (trust=0, permissions=1, goal=2, display name=3)
  - [x] `OnboardingGoalPage`: change `onComplete` → `onContinue` calling `nextStep`; button label stays "Start tracking" / Skip uses default goal then advances (does **not** complete onboarding)
  - [x] `OnboardingCubit.completeOnboarding({int? goal, String? displayName})` — persist goal + optional name + `setOnboardingComplete(true)`
  - [x] Wire fourth child in `onboarding_flow.dart` `IndexedStack`; display name step completes onboarding
  - [x] English copy: title "What should we call you?", field label "First name", Skip "Continue without name"
  - [x] Update `test/presentation/onboarding/onboarding_flow_test.dart` and `onboarding_cubit_test.dart` for 4-step flow
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Today greeting** (AC: #2, #3, #6)
  - [x] `TodayState`: add nullable `String? displayName` (default null); include in `copyWith` / `fromData` as needed
  - [x] `TodayCubit.refresh()` and `refreshMetadata()`: load `getDisplayName()` alongside goal (use `Future.wait` in `_refreshImpl` / `refreshMetadata`)
  - [x] `TodayScreen`: if `displayName != null`, insert `Padding` + `Text('Hello, $displayName', style: AstraTypography.captionFor(colors))` **after** stale compact banner, **before** `Expanded` ring (`flex: 55`)
  - [x] Semantics: when greeting present, Today screen semantics label includes greeting; do **not** add step count to greeting semantics
  - [x] `test/presentation/screens/today_screen_test.dart` (create or extend): greeting visible/hidden; no duplicate step line under greeting
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — My Data edit row + Today refresh hook** (AC: #4)
  - [x] Add `SectionCard(headline: 'Profile')` with display-name row **between** Appearance and Your data (~after line 229 in `my_data_screen.dart`)
  - [x] Use tap-to-edit sheet pattern like `showGoalEditorSheet` (new `display_name_editor_sheet.dart` or inline minimal sheet — max 32 chars, trim on save)
  - [x] Persist via `userPreferences.setDisplayName` from screen or thin cubit method — **not** direct SQL
  - [x] `AppScaffold`: wire `postDisplayNameUpdate` on `MyDataCubit` (mirror `postGoalUpdate`) → `await _todayCubit.refreshMetadata()`
  - [x] Disable row when `dataActionInFlight` (same as goal/theme)
  - [x] Extend `my_data_screen_test.dart`: Profile section order, save triggers refresh callback (mock cubit)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Integration verification** (AC: #5–#6)
  - [x] Run `flutter analyze` and `flutter test`
  - [x] Manual: onboarding with name → Today shows Hello; skip name → no line; edit on My Data → Today updates without restart; purge keeps name + greeting
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope:**
- Local `display_name` preference (SQLite `user_preferences` key/value — no migration)
- Optional onboarding step after goal (4th step)
- Today **Hello, {name}** caption only (English hardcoded)
- My Data Profile section with edit affordance
- Purge retention test for `display_name`

**Out of scope — defer:**
- **i18n** (`flutter_localizations`, `.arb`) — later pass
- Personalized **GoalCelebration** or **notification** copy
- Step count subtitle under greeting
- **Profile initials avatar** → **Story 4.9**
- Account, cloud profile, photo upload
- Moving Appearance or Your data sections (locked by Story 4.7)

### Pipeline position (Epic 4)

```text
Theme selector (4.7) ✅
        │
        v
Display name + Today greeting (4.8)   ← THIS STORY
        │
        v
Profile initials (4.9)
```

### Architecture contracts

| Decision / FR | Requirement for 4.8 |
|---------------|---------------------|
| FR9 | Optional `display_name` in `user_preferences`; local-only; trimmed |
| FR20 / D-11 | Full purge retains `display_name` with goal, theme, onboarding |
| D-03 | `UserPreferencesRepository` sole writer to `user_preferences` |
| UX §4.6 | Calm factual copy; no exclamation; `Hello, {name}` exact format |
| Story 1.4 | Extend repository API; no new preference storage mechanism |
| Story 2.5 / 2.9 | Today layout + truth model unchanged except optional caption |
| Story 4.5 | Purge uses explicit delete list — `display_name` must never be in delete list |
| Story 4.7 | Section order: … → Goal → Appearance → **Profile** → Your data |

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 4.8 changes | Must preserve |
|------|---------------|------------------|---------------|
| `preference_keys.dart` | No `display_name` key | Add `kDisplayNameKey`, `kMaxDisplayNameLength` | Existing keys unchanged |
| `user_preferences_repository.dart` | Goal, theme, onboarding, celebration, optimize keys | Add get/set display name | Single-writer; `_readValue`/`_writeValue` pattern |
| `onboarding_state.dart` | `totalSteps = 3` | `totalSteps = 4` | Permission + goal fields |
| `onboarding_cubit.dart` | `completeOnboarding({int? goal})` only | Optional `displayName`; goal page no longer completes | Permission request flows |
| `onboarding_flow.dart` | 3-page `IndexedStack`; goal calls `_completeOnboarding` | 4 pages; goal → `nextStep`; new display name page completes | `BlocListener` on `OnboardingStatus.completed` |
| `onboarding_goal_page.dart` | `onComplete` + progress `currentStep: 2, totalSteps: 3` | `onContinue` + `totalSteps: 4` | Validation + Skip default goal |
| `today_state.dart` | steps, goal, stale, celebration | Add `displayName` | Status machine + monotonic steps |
| `today_cubit.dart` | Loads steps + goal in refresh | Also load display name in `refresh` + `refreshMetadata` | Live monitor, celebration claim, silent refresh |
| `today_screen.dart` | Stale banner → ring → chip | Greeting between banner and ring when name set | Celebration vs ring switch |
| `my_data_screen.dart` | … Goal → Appearance → Your data | Insert Profile section between Appearance and Your data | Export/import/purge, `dataActionInFlight` |
| `app_scaffold.dart` | `postGoalUpdate` → `refreshMetadata` | Add `postDisplayNameUpdate` same pattern | Ingestion/purge/import callbacks |
| `step_repository.dart` `purge()` | Deletes only derived keys | **No code change required** if `display_name` never added to delete loop | Transaction + sample wipe |
| `step_repository_purge_test.dart` | Asserts goal/theme/onboarding preserved | Add `display_name` to seed + assertion | Existing purge behavior |

### Display name data flow

```text
OnboardingDisplayNamePage / My Data sheet
    → UserPreferencesRepository.setDisplayName(trimmed | null)
    → (My Data path) MyDataCubit callback
         → AppScaffold postDisplayNameUpdate
              → TodayCubit.refreshMetadata()
                   → emit TodayState with displayName
    → TodayScreen rebuilds greeting line
```

### Onboarding step migration (critical)

| Step index | Page | Action |
|------------|------|--------|
| 0 | Trust | `nextStep` |
| 1 | Permissions | `nextStep` (unchanged) |
| 2 | Goal | **Continue** → `nextStep` (was `completeOnboarding`) |
| 3 | Display name | Continue with name OR Skip → `completeOnboarding(goal:, displayName:)` |

`OnboardingGoalPage` progress: `currentStep: 2, totalSteps: 4`.

`OnboardingDisplayNamePage` progress: `currentStep: 3, totalSteps: 4`.

Back from display name → goal via `previousStep`.

### Today layout (UX alignment)

UX §2.3 lists: stale banner → ring → chip. Story adds greeting **between** stale banner and ring (epics + product intent). Do **not** shrink ring flex ratios; greeting is a fixed-height caption row.

| Element | Style |
|---------|--------|
| Text | `Hello, $displayName` — comma, **no** exclamation |
| Typography | `AstraTypography.captionFor(colors)` → `text.secondary` |
| Padding | `AstraSpacing.kScreenHorizontalPadding` horizontal; `kSpaceSm` vertical below banner |

### My Data Profile section

| Element | Spec |
|---------|------|
| Headline | `"Profile"` (`SectionCard`) |
| Row pattern | Mirror `GoalEditorRow` — label "Display name", value or "Not set", chevron, tap opens sheet |
| Placement | After Appearance `SectionCard`, before Your data |
| Disabled | `!dataActionInFlight` same as goal/theme |
| Save feedback | Silent persist (like theme) — no snackbar unless save fails |

### Purge contract (AC #5)

`StepRepository.purge()` only deletes `kCelebrationShownDateKey`, `kIngestionCollectLockKey`, `kLastDatabaseOptimizedAtKey` from prefs. New `display_name` key is preserved **by omission** — add regression test so future agents do not add it to the delete loop.

### Recommended file layout

```text
lib/core/constants/preference_keys.dart                          # UPDATE
lib/data/repositories/user_preferences_repository.dart           # UPDATE
lib/presentation/cubits/onboarding_state.dart                  # UPDATE
lib/presentation/cubits/onboarding_cubit.dart                    # UPDATE
lib/presentation/cubits/today_state.dart                         # UPDATE
lib/presentation/cubits/today_cubit.dart                         # UPDATE
lib/presentation/onboarding/onboarding_flow.dart                 # UPDATE
lib/presentation/onboarding/onboarding_goal_page.dart            # UPDATE
lib/presentation/onboarding/onboarding_display_name_page.dart    # NEW
lib/presentation/onboarding/onboarding_display_name_editor_sheet.dart  # NEW (optional name)
lib/presentation/screens/today_screen.dart                       # UPDATE
lib/presentation/screens/my_data_screen.dart                     # UPDATE
lib/presentation/screens/app_scaffold.dart                       # UPDATE
lib/presentation/widgets/display_name_editor_row.dart            # NEW (optional — can inline in screen)
lib/presentation/cubits/my_data_cubit.dart                         # UPDATE — postDisplayNameUpdate + save helper

test/data/repositories/user_preferences_repository_test.dart     # UPDATE
test/data/repositories/step_repository_purge_test.dart           # UPDATE
test/presentation/cubits/onboarding_cubit_test.dart              # UPDATE
test/presentation/onboarding/onboarding_flow_test.dart           # UPDATE
test/presentation/screens/today_screen_test.dart                 # NEW or UPDATE
test/presentation/screens/my_data_screen_test.dart               # UPDATE
```

### Anti-patterns (do NOT)

- Store display name in `MyDataState` SQLite fields or a new table
- Call `db.insert` for `display_name` outside `UserPreferencesRepository`
- Complete onboarding from goal page (regresses 4-step flow)
- Use `TodayCubit.refresh(silent: false)` for name-only updates (flashes skeleton)
- Add step count under greeting ("10 847 steps today" duplicates ring)
- Log display name in `debugPrint` in production paths
- Put greeting inside `GoalRing` widget
- Reorder Appearance below Your data or above Footprint
- Add `display_name` to purge delete loop
- Personalize `GoalCelebration` or notifications with name

### Previous story intelligence (Story 4.7 — immediate predecessor)

**Reuse directly:**

- `SectionCard` insertion pattern on `MyDataScreen`
- `dataActionInFlight` guard for interactive controls
- Sub-task commit discipline: French review brief, wait for Baptiste OK
- `postGoalUpdate` / `refreshMetadata` wiring in `app_scaffold.dart`

**4.7 handoff (explicit):**

Final order after 4.8: Background → Footprint → Daily goal → Appearance → **Profile** → Your data. Do not move Appearance.

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `36218d6` | 4.7 done — Appearance section live; Profile slot is after line ~229 |
| `ccf65cf` | My Data section patterns |
| `26b9d44` | Screen tests with extra `BlocProvider`s — extend, don't rewrite |
| Story 4.5 / 4.6 | Purge preserve pattern; goal editor sheet pattern |

### Library / framework notes

- No new dependencies
- `shared_preferences` not used — SQLite `user_preferences` only (Story 1.4)
- Text input: standard `TextField` with `maxLength: kMaxDisplayNameLength` optional

### Testing requirements

| Test | Purpose |
|------|---------|
| `user_preferences_repository_test.dart` | Round-trip, trim, clear, max length, empty |
| `step_repository_purge_test.dart` | `display_name` survives purge |
| `onboarding_cubit_test.dart` | Skip vs save name; goal step doesn't complete |
| `onboarding_flow_test.dart` | 4 steps; display name page reachable |
| `today_screen_test.dart` | Greeting visible/hidden |
| `my_data_screen_test.dart` | Profile section placement; disabled during purge/export |
| `today_cubit_test.dart` | Optional: metadata refresh includes displayName |

### Handoff for Story 4.9

- `display_name` preference and My Data edit row must exist
- Profile **initials header** at top of My Data is 4.9 — 4.8 only adds Profile **section** with name row (4.9 may relocate or add header above Background)

### Project context reference

- Review-before-commit: `docs/project-context.md` — one sub-task per commit, French review brief, wait for Baptiste OK
- Explain in review brief: repository sole-writer, why `refreshMetadata` not full `refresh`, onboarding step index change

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 4.8, FR9, FR20]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §2.3 Today, §4.6 tone]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — user_preferences, purge, TodayCubit refresh]
- [Source: `_bmad-output/implementation-artifacts/stories/1-4-user-preferences-persistence.md`]
- [Source: `_bmad-output/implementation-artifacts/stories/4-5-full-data-purge-with-export-nudge.md` — purge allowlist]
- [Source: `_bmad-output/implementation-artifacts/stories/4-6-daily-goal-editor-on-my-data.md` — sheet/row pattern]
- [Source: `_bmad-output/implementation-artifacts/stories/4-7-theme-selector-and-my-data-integration.md` — section order]
- [Source: `lib/data/repositories/user_preferences_repository.dart`]
- [Source: `lib/presentation/onboarding/onboarding_flow.dart`]
- [Source: `lib/presentation/screens/today_screen.dart`]
- [Source: `lib/presentation/screens/app_scaffold.dart` — postGoalUpdate pattern]

## Dev Agent Record

### Agent Model Used

Composer (dev-story workflow)

### Debug Log References

### Completion Notes List

- Sub-task A: `display_name` preference API with trim, clear-on-empty, max-length reject; purge regression test.
- Sub-task B: 4-step onboarding; goal page advances only; optional name on final step.
- Sub-task C: Today `Hello, {name}` caption via `refreshMetadata` (no full refresh flash).
- Sub-task D: My Data Profile section + editor sheet; `postDisplayNameUpdate` → Today metadata refresh.
- Sub-task E: Targeted automated tests green; `app_scaffold_test` updated with `ThemeCubit` provider.

### File List

- lib/core/constants/preference_keys.dart
- lib/data/repositories/user_preferences_repository.dart
- lib/presentation/cubits/onboarding_state.dart
- lib/presentation/cubits/onboarding_cubit.dart
- lib/presentation/cubits/today_state.dart
- lib/presentation/cubits/today_cubit.dart
- lib/presentation/cubits/my_data_state.dart
- lib/presentation/cubits/my_data_cubit.dart
- lib/presentation/onboarding/onboarding_flow.dart
- lib/presentation/onboarding/onboarding_goal_page.dart
- lib/presentation/onboarding/onboarding_display_name_page.dart
- lib/presentation/onboarding/onboarding_trust_page.dart
- lib/presentation/onboarding/onboarding_permissions_page.dart
- lib/presentation/screens/today_screen.dart
- lib/presentation/screens/my_data_screen.dart
- lib/presentation/screens/app_scaffold.dart
- lib/presentation/widgets/display_name_editor_sheet.dart
- lib/presentation/widgets/display_name_editor_row.dart
- test/data/repositories/user_preferences_repository_test.dart
- test/data/repositories/step_repository_purge_test.dart
- test/presentation/cubits/onboarding_cubit_test.dart
- test/presentation/onboarding/onboarding_flow_test.dart
- test/presentation/cubits/today_cubit_test.dart
- test/presentation/screens/today_screen_test.dart
- test/presentation/screens/my_data_screen_test.dart
- test/presentation/screens/app_scaffold_test.dart
- _bmad-output/implementation-artifacts/sprint-status.yaml

## Change Log

- 2026-06-03: Code review fixes — clear display name on onboarding skip; My Data save error SnackBar; Profile row disabled tests.
- 2026-06-03: Story 4.8 implemented — display name preference, 4-step onboarding, Today greeting, My Data Profile editor.
- 2026-06-03: Story 4.8 context engine analysis completed — ready-for-dev comprehensive developer guide
