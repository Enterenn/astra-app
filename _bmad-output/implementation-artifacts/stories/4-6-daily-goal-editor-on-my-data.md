# Story 4.6: Daily Goal Editor on My Data



Status: review



<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->



## Story



As a **user**,

I want to change my daily step goal from My Data,

So that I can adjust my target without repeating onboarding.



## Acceptance Criteria



1. **Given** My Data goal row

   **When** user taps it

   **Then** `GoalEditorSheet` opens with numeric field and 1,000–100,000 validation (FR23, UX-DR13)



2. **Given** invalid input

   **When** displayed

   **Then** Save is disabled with inline helper/error text



3. **Given** valid save

   **When** sheet closes

   **Then** Today ring recalculates percentage against new goal immediately



## Tasks / Subtasks



- [x] **Sub-task A — Shared step goal validation** (AC: #1–#2)

  - [x] Add `lib/core/validation/step_goal_validator.dart`:

    - `StepGoalValidationResult validateStepGoalInput(String raw)` returning `{ isValid, parsedGoal?, errorMessage? }`

    - Rules: digits only (trim whitespace), integer, `kMinStepGoal` (1_000) ≤ value ≤ `kMaxStepGoal` (100_000) from `preference_keys.dart`

    - Helper copy when empty/invalid: `"Enter a value between 1,000 and 100,000."` (UX §3.8)

  - [x] Refactor `OnboardingState.isGoalValid` / `resolvedGoal` to delegate to shared validator (keep public API unchanged)

  - [x] Unit tests: `test/core/validation/step_goal_validator_test.dart` — bounds, non-numeric, empty, leading zeros OK, 999/100001 invalid

  - [x] **Stop → review brief → wait for Baptiste OK → commit**



- [x] **Sub-task B — `GoalEditorSheet` bottom sheet** (AC: #1–#2, UX §3.8)

  - [x] Add `lib/presentation/widgets/goal_editor_sheet.dart`:

    - `Future<int?> showGoalEditorSheet(BuildContext context, {required int currentGoal})` — returns saved goal or `null` if cancelled/dismissed

    - `showModalBottomSheet` with drag handle, title `"Daily step goal"`, numeric `TextField` (digits only, number pad), helper/error line, **Save** (primary) + **Cancel** (ghost/secondary)

    - Pre-fill with `currentGoal`; Save enabled only when input is valid **and** parsed value ≠ `currentGoal` (UX: no nag if unchanged)

    - Invalid → Save disabled + error helper (reuse validator message)

    - Use `AstraButton`, `AstraSpacing`, `AstraTypography`, `AstraColors` — first bottom sheet in codebase; set `isScrollControlled: true` if keyboard overlaps

  - [x] Widget tests: `test/presentation/widgets/goal_editor_sheet_test.dart` — opens with current value; invalid disables Save; valid change returns goal; Cancel returns null; unchanged value disables Save

  - [x] **Stop → review brief → wait for Baptiste OK → commit**



- [x] **Sub-task C — `GoalEditorRow` + My Data section placement** (AC: #1, UX-DR11 partial)

  - [x] Add `lib/presentation/widgets/goal_editor_row.dart`:

    - Tappable row inside `SectionCard`: label `"Daily step goal"` + formatted value (`formatStepCount`) + chevron `>`

    - Semantics: `"Daily step goal, {value}. Double tap to edit."`

    - `onTap` callback provided by screen

  - [x] Update `MyDataScreen`:

    - Insert `SectionCard(headline: 'Daily goal')` → `GoalEditorRow` **between** Footprint and Your data sections (UX §2.5 order: Background → Footprint → **Goal** → …)

    - On tap: `showGoalEditorSheet(context, currentGoal: state.dailyStepGoal)` → if result non-null, `cubit.updateDailyStepGoal(result)`

    - Show row only when `state.status == ready` (loading uses existing `_SectionLoadingIndicator`)

  - [x] Widget tests: `test/presentation/screens/my_data_screen_test.dart` — goal section visible; displays formatted goal from cubit state; tap invokes sheet (mock cubit or pump sheet)

  - [x] **Stop → review brief → wait for Baptiste OK → commit**



- [x] **Sub-task D — `MyDataCubit.updateDailyStepGoal` + state field** (AC: #3)

  - [x] Extend `MyDataState`:

    - Add `int dailyStepGoal` (default `kDefaultStepGoal` in loading factory; populated on refresh)

    - Preserve across `copyWith` / `_emitReadySnapshot` (like export/import flags)

  - [x] Extend `MyDataCubit`:

    - Load `userPreferences.getDailyStepGoal()` in `_refreshImpl` parallel fetch

    - Add injectable `PostGoalUpdateCallback = Future<void> Function()` (mirror `postImportRefresh`)

    - Add `Future<void> updateDailyStepGoal(int goal)`:

      1. Re-validate with shared validator; no-op if invalid

      2. If goal == state.dailyStepGoal → return (sheet should prevent, but guard anyway)

      3. `await userPreferences.setDailyStepGoal(goal)` — **sole writer** (D-03)

      4. Emit updated `dailyStepGoal` on current ready snapshot

      5. `await postGoalUpdate?.call()` if injected

    - In-flight guard: block goal update while export/import/purge in flight (consistent with data actions)

  - [x] Cubit tests: `test/presentation/cubits/my_data_cubit_goal_test.dart` — refresh loads goal; update persists to repo; postGoalUpdate invoked; invalid rejected; unchanged no-op; blocked during purge

  - [x] **Stop → review brief → wait for Baptiste OK → commit**



- [x] **Sub-task E — Cross-tab refresh wiring + integration verification** (AC: #3)

  - [x] Wire `AppScaffold` `postGoalUpdate` on `MyDataCubit`:

    ```dart

    postGoalUpdate: () async {

      await _todayCubit.refreshMetadata();

      await _historyCubit.refreshGoal();

    },

    ```

    **Critical:** Use `refreshMetadata()` (not full `refresh()`) so live step overlay is not overwritten (Story 2.9 truth model). History goal line updates via existing `refreshGoal()`.

  - [x] Integration/widget test: after goal update callback, Today cubit state reflects new goal with same step count (pump scaffold or cubit unit test with mock callback)

  - [x] Manual: set goal 5000 on My Data → switch to Today → ring % updates without losing step count; History goal dashed line moves

  - [x] Manual: invalid values (999, abc) → Save disabled; valid 12000 → saves, row shows `12 000`

  - [x] Run `flutter test` + `flutter analyze`

  - [x] **Stop → review brief → wait for Baptiste OK → commit**



## Dev Notes



### Story scope boundary



**In scope for 4.6:**

- My Data **Daily goal** section with tappable row + `GoalEditorSheet`

- Shared step goal validation (reuse onboarding bounds)

- Persist via `UserPreferencesRepository.setDailyStepGoal`

- Immediate Today ring % + History goal line refresh after save

- `MyDataState.dailyStepGoal` loaded on refresh



**Out of scope — defer:**

- Theme selector / Appearance section → **Story 4.7**

- Display name edit → **Story 4.8**

- Profile initials → **Story 4.9**

- Re-trigger goal celebration on goal change → not required; `celebration_shown_date` dedup unchanged

- Onboarding goal page UI redesign → only validator refactor if shared

- Snackbar on goal save → UX spec silent close; no toast required



### Pipeline position (Epic 4)



```text

Full purge (4.5) ✅

        │

        v

Goal editor (4.6)   ← THIS STORY

        │

        v

Theme selector (4.7) → display name (4.8) → profile (4.9)

```



### Architecture contracts



| Decision / FR | Requirement for 4.6 |

|---------------|---------------------|

| FR-23 | Edit path on My Data; set-once philosophy (no recurring prompts) |

| UX-DR13 | Bottom sheet, free numeric field, 1_000–100_000, Save disabled until valid |

| UX-DR11 | Section order: insert Goal between Footprint and Your data (Appearance deferred 4.7) |

| D-03 | `UserPreferencesRepository` sole writer to `daily_step_goal` |

| D-11 | Goal survives purge (already preserved — no change needed) |

| Story 2.9 | Post-save Today update via `refreshMetadata()` + existing steps — never DB-only refresh that drops live overlay |

| Architecture cubit table | Returning to Today tab already calls `refreshMetadata()` + `historyCubit.refreshGoal()` — goal edit must proactively call same paths |



### Current code state (READ BEFORE EDITING)



| Path | Current state | What 4.6 changes | Must preserve |

|------|---------------|------------------|---------------|

| `my_data_screen.dart` | Background, Footprint, Your data only | Add Daily goal section + sheet wiring | Export/import/purge flows, banners |

| `my_data_state.dart` | No goal field | Add `dailyStepGoal` | All export/import/purge flags |

| `my_data_cubit.dart` | refresh + admin ops | Load goal; `updateDailyStepGoal`; `postGoalUpdate` | In-flight guards for data actions |

| `user_preferences_repository.dart` | `get/setDailyStepGoal` exist | **No API change** unless validation moved to repo (prefer validator only) | Single-writer rule |

| `onboarding_state.dart` | Inline validation 1k–100k | Delegate to shared validator | Onboarding tests still pass |

| `onboarding_goal_page.dart` | Full-page goal field | Optional: no UI change | Skip → 8000 behavior |

| `today_cubit.dart` | `refreshMetadata()` reads goal | Called from postGoalUpdate | Live monitor / syncSteps paths |

| `history_cubit.dart` | `refreshGoal()` exists | Called from postGoalUpdate | Chart cache / aggregates |

| `app_scaffold.dart` | postImport/postPurge wired | Add postGoalUpdate | Tab cubit lifecycle |

| `preference_keys.dart` | `kMinStepGoal`, `kMaxStepGoal`, `kDefaultStepGoal` | **Use constants — do not duplicate bounds** | Defaults |



### Recommended file layout



```text

lib/core/validation/step_goal_validator.dart           # NEW

lib/presentation/widgets/goal_editor_sheet.dart      # NEW

lib/presentation/widgets/goal_editor_row.dart        # NEW

lib/presentation/cubits/my_data_state.dart             # UPDATE — dailyStepGoal

lib/presentation/cubits/my_data_cubit.dart             # UPDATE — load + updateDailyStepGoal

lib/presentation/cubits/onboarding_state.dart        # UPDATE — delegate validation

lib/presentation/screens/my_data_screen.dart         # UPDATE — goal section

lib/presentation/screens/app_scaffold.dart           # UPDATE — postGoalUpdate



test/core/validation/step_goal_validator_test.dart   # NEW

test/presentation/widgets/goal_editor_sheet_test.dart # NEW

test/presentation/cubits/my_data_cubit_goal_test.dart  # NEW

test/presentation/screens/my_data_screen_test.dart     # UPDATE

test/presentation/cubits/onboarding_cubit_test.dart  # UPDATE if validator refactor breaks imports

```



### Goal edit flow (sequence)



```text

User taps GoalEditorRow on My Data

    → showGoalEditorSheet(currentGoal)

         ├─ Cancel / dismiss → null (no persist)

         └─ Save valid new goal

              → MyDataCubit.updateDailyStepGoal(goal)

                   → UserPreferencesRepository.setDailyStepGoal(goal)

                   → emit MyDataState.dailyStepGoal = goal

                   → postGoalUpdate():

                        TodayCubit.refreshMetadata()   // new goal, same steps

                        HistoryCubit.refreshGoal()     // chart goal line

              → sheet closes

User on Today tab → ring progressRatio recalculated (goalMet/overflow/progress)

```



### UX compliance (UX §2.5, §3.8, UX-DR13)



| Element | Spec |

|---------|------|

| Row label | `"Daily step goal"` |

| Row value | `formatStepCount` — thin-space thousands (e.g. `8 000`) |

| Sheet title | `"Daily step goal"` |

| Keyboard | Number pad, digits only |

| Bounds | 1,000 – 100,000 integer |

| Invalid | Save disabled + helper `"Enter a value between 1,000 and 100,000."` |

| Unchanged | Save disabled (no save nag) |

| Actions | Save (primary), Cancel (ghost) |

| Post-save | Sheet closes; Today % updates — **no snackbar** |

| Section headline | `"Daily goal"` in `SectionCard` |



### Today ring behavior after goal change (AC #3)



`TodayState.progressRatio` and status (`progress` / `goalMet` / `overflow`) derive from `steps` and `goal`. After save:



- `refreshMetadata()` re-reads goal from prefs and calls `_applyTodaySnapshot(steps: state.steps, goal: newGoal, …)` — **step count unchanged**, ring animates to new %.

- Do **not** call `refresh()` alone after edit — would re-query DB steps and can fight live overlay.

- Lowering goal below current steps may flip status to `goalMet`/`overflow` without re-firing celebration (dedup pref unchanged — correct).



### Anti-patterns (do NOT)



- Write `daily_step_goal` from cubit via raw sqflite

- Duplicate min/max constants outside `preference_keys.dart`

- Call `TodayCubit.refresh()` after goal edit (live overlay risk)

- Add Appearance or Theme sections (Story 4.7)

- Show recurring goal prompts outside user-initiated sheet (FR-23 set-once)

- Block goal edit with modal while export running unless using same in-flight guard as other admin ops

- Clear `celebration_shown_date` on goal change

- Use `intl` for number formatting in row (use existing `formatStepCount`)



### Previous story intelligence (Story 4.5 — immediate predecessor)



**Reuse directly:**

- `MyDataCubit` injectable callback pattern (`postImportRefresh` / `postPurgeRefresh` → mirror `postGoalUpdate`)

- `AppScaffold` wiring location for cross-cubit side effects

- `copyWith` / `_emitReadySnapshot` flag preservation when extending `MyDataState`

- In-flight guard pattern for admin operations

- Review discipline: sub-task commits, French review brief, wait for Baptiste OK



**4.5 confirmed:** `daily_step_goal` preserved on purge — goal row must still show same value after purge (load from prefs on refresh; no special case).



**4.2/4.3 notes:** Section order intentionally partial until 4.6/4.7 — insert Goal **above** Your data now; Appearance slot reserved for 4.7.



### Git intelligence (recent commits)



| Commit | Relevance |

|--------|-----------|

| `f049add` | 4.5 done — purge preserves goal; My Data screen stable |

| `0213c88` | My Data screen wiring patterns for new section |

| `fb5349e` | postPurgeRefresh callback pattern to copy for postGoalUpdate |

| Story 1-5 | Onboarding goal validation 1k–100k — extract to shared validator |



### Library / framework notes



- No new dependencies

- First `showModalBottomSheet` in app — follow Material 3 modal bottom sheet; safe area + keyboard inset

- `UserPreferencesRepository.setDailyStepGoal` throws on `goal <= 0` — validator must prevent before call



### Testing requirements



| Test | Purpose |

|------|---------|

| `step_goal_validator_test` | FR-23 bounds shared by onboarding + sheet |

| `goal_editor_sheet_test` | UX-DR13 Save disabled rules |

| `my_data_cubit_goal_test` | Persist + postGoalUpdate + guards |

| `my_data_screen_test` | Goal section visible + tap path |

| Scaffold/cubit integration | AC #3 Today goal updates without step regression |

| Manual | Today ring % + History goal line after edit |



### Handoff for Story 4.7



When Appearance/`ThemeSelector` lands, final My Data order becomes: Background → Footprint → Goal → **Appearance** → Your data. Story 4.6 must not block 4.7 inserting Appearance between Goal and Your data.



### Project context reference



- Review-before-commit: `docs/project-context.md` — one sub-task per commit, French review brief, wait for Baptiste OK

- `user_skill_level: intermediate` — explain bottom sheet, shared validator, refreshMetadata vs refresh in review brief



### References



- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 4.6, FR23, UX-DR11/13]

- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §2.5 GoalEditor, §3.5 My Data layout, §3.8 Goal Editor sheet]

- [Source: `_bmad-output/planning-artifacts/architecture.md` — cubit refresh table, D-03 single writer, purge retains goal]

- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` — FR-23]

- [Source: `_bmad-output/implementation-artifacts/stories/1-5-trust-first-onboarding-flow.md` — onboarding goal validation defer to 4.6 sheet]

- [Source: `_bmad-output/implementation-artifacts/stories/4-5-full-data-purge-with-export-nudge.md` — postRefresh callback pattern]

- [Source: `lib/core/constants/preference_keys.dart` — kMinStepGoal, kMaxStepGoal]

- [Source: `lib/presentation/cubits/today_cubit.dart` — refreshMetadata()]

- [Source: `lib/presentation/cubits/history_cubit.dart` — refreshGoal()]

- [Source: `lib/presentation/cubits/onboarding_state.dart` — isGoalValid pattern]



## Dev Agent Record



### Agent Model Used



Composer



### Debug Log References



- Cubit refresh test needed explicit `activityPermissionGranted: () async => true` (default platform checker fails in unit tests).

- Purge dialog widget test required `scrollUntilVisible` after Daily goal section lengthened the screen.



### Completion Notes List



- Shared `validateStepGoalInput` used by onboarding and goal editor sheet; bounds from `preference_keys.dart`.

- First modal bottom sheet: `GoalEditorSheet` with Save disabled when invalid or unchanged.

- My Data **Daily goal** section between Footprint and Your data; persists via `UserPreferencesRepository` only.

- `postGoalUpdate` wires `TodayCubit.refreshMetadata()` + `HistoryCubit.refreshGoal()` (not full Today refresh).

- All ACs covered by automated tests; full `flutter test` green.



### File List



- lib/core/validation/step_goal_validator.dart (new)

- lib/presentation/widgets/goal_editor_sheet.dart (new)

- lib/presentation/widgets/goal_editor_row.dart (new)

- lib/presentation/cubits/my_data_state.dart

- lib/presentation/cubits/my_data_cubit.dart

- lib/presentation/cubits/onboarding_state.dart

- lib/presentation/screens/my_data_screen.dart

- lib/presentation/screens/app_scaffold.dart

- test/core/validation/step_goal_validator_test.dart (new)

- test/presentation/widgets/goal_editor_sheet_test.dart (new)

- test/presentation/cubits/my_data_cubit_goal_test.dart (new)

- test/presentation/screens/my_data_screen_test.dart

- test/presentation/cubits/today_cubit_test.dart



## Change Log



- 2026-06-03: Story 4.6 created — daily goal editor on My Data context engine analysis complete

- 2026-06-03: Story 4.6 implemented — shared validator, goal editor UI, My Data cubit/screen, cross-tab refresh wiring

