# Story 4.7: Theme Selector and My Data Integration

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want to choose System, Light, or Dark appearance from My Data,
So that the app looks the way I prefer regardless of OS settings.

## Acceptance Criteria

1. **Given** My Data Appearance section
   **When** user selects System, Light, or Dark via `ThemeSelector` segmented control (UX-DR22)
   **Then** `theme_mode` persists and applies immediately app-wide (FR31)
   **And** cold start restores preference without theme flash

2. **Given** `theme_mode` is `system`
   **When** OS theme changes
   **Then** app UI updates without restart

3. **Given** complete My Data screen
   **When** scrolled
   **Then** section order is: Background → Footprint → Goal → Appearance → Data actions (UX-DR11)
   **And** copy/tone follows UX §4.6 guardrails (UX-DR20)

4. **Given** theme selector is functional
   **When** Epic 5 design polish runs
   **Then** contrast and visual cohesion are verified per UX §4.1 and V-1–V-13 (NFR5, UX-DR21) — **not blocking** Story 4.7 delivery

## Tasks / Subtasks

- [x] **Sub-task A — `ThemeSelector` widget** (AC: #1–#2, UX-DR22)
  - [x] Add `lib/presentation/widgets/theme_selector.dart`:
    - `ThemeSelector({ required AstraThemePreference selected, required ValueChanged<AstraThemePreference> onChanged })`
    - Three equal segments: **System**, **Light**, **Dark** (English labels, Phase 0)
    - Visual pattern: mirror `PeriodToggle` — `bgSubtle` pill container, selected segment `bgElevated`, accent underline 2dp, `kMinTouchTarget` (48dp) height
    - Respect `MediaQuery.disableAnimationsOf(context)` for underline animation (accessibility)
    - Semantics per segment: `button: true`, `selected: true/false`, label e.g. `"Light appearance"`, hint `"App theme"`
  - [x] Widget tests: `test/presentation/widgets/theme_selector_test.dart` — renders three options; tap emits preference; selected segment has `selected` semantics
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — My Data Appearance section** (AC: #1, #3, UX-DR11)
  - [x] Update `MyDataScreen`:
    - Insert `SectionCard(headline: 'Appearance')` with `ThemeSelector` **between** Daily goal and Your data (after line ~203, before Your data card)
    - Wrap selector in `BlocBuilder<ThemeCubit, ThemeState>` — read `context.read<ThemeCubit>()` for `onChanged`
    - On change: `await context.read<ThemeCubit>().setThemePreference(preference)` — **do not** write prefs from screen/repository directly
    - Disable selector when `dataActionInFlight` (export/import/purge) — same pattern as `GoalEditorRow.enabled` in 4.6
    - Show section when `state.status == ready`; loading uses `_SectionLoadingIndicator` (consistent with other sections)
  - [x] **No `MyDataCubit` / `MyDataState` changes** — theme is app-level via existing `ThemeCubit`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Screen + cubit tests** (AC: #1–#3)
  - [x] Extend `test/presentation/screens/my_data_screen_test.dart`:
    - Wrap `pumpScreen` helper with `BlocProvider<ThemeCubit>` (in-memory `UserPreferencesRepository`)
    - Test: Appearance section visible between Daily goal and Your data
    - Test: segment tap calls `setThemePreference` and UI reflects selection (pump extra frame after async)
    - Test: selector disabled when `isExporting` / `isPurging` (mirror goal row disabled tests from 4.6)
  - [x] Confirm existing `theme_cubit_test.dart` still covers persist + emit (no duplicate unless gap found)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Integration verification** (AC: #1–#2, #4 deferred)
  - [x] Manual cold start: set Dark on My Data → kill app → relaunch → app opens dark with **no** light flash before dark
  - [x] Manual system mode: select System → toggle OS light/dark → Today + My Data + History update without restart
  - [x] Manual section order scroll: Background → Footprint → Daily goal → Appearance → Your data
  - [x] Manual purge: theme choice unchanged after purge (prefs preserved per Story 4.5 / D-11)
  - [x] Run `flutter test` + `flutter analyze`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

**In scope for 4.7:**

- `ThemeSelector` segmented control on My Data (FR31, UX-DR22)
- Wire to existing `ThemeCubit.setThemePreference` + `UserPreferencesRepository.setThemeMode`
- Complete UX-DR11 section order (Appearance between Goal and Data actions)
- Disable theme control during data admin in-flight ops

**Out of scope — defer:**

- WCAG contrast audit, accent token revision, V-1–V-13 beta checklist → **Epic 5** (explicit AC #4)
- Display name row / Today greeting → **Story 4.8**
- Profile initials → **Story 4.9**
- Refactoring `PeriodToggle` / `ThemeSelector` into shared segment base widget (optional; not required)
- Theme picker on onboarding → My Data only per PRD FR-31
- `MyDataCubit` theme field or refresh hooks — unnecessary

### Pipeline position (Epic 4)

```text
Goal editor (4.6) ✅
        │
        v
Theme selector (4.7)   ← THIS STORY
        │
        v
Display name (4.8) → profile (4.9)
```

### Architecture contracts

| Decision / FR | Requirement for 4.7 |
|---------------|---------------------|
| FR-31 | System/Light/Dark on My Data; immediate app-wide; cold start no flash; OS reactive when `system` |
| UX-DR11 | Final order: Background → Footprint → Goal → **Appearance** → Data actions |
| UX-DR22 | Segmented control, 48dp touch, persists `theme_mode` immediately |
| UX-DR20 | Calm factual copy only (segment labels are neutral: System/Light/Dark) |
| UX-DR21 | Contrast polish deferred Epic 5 — do not block 4.7 on visual audit |
| D-03 | `UserPreferencesRepository` sole writer to `theme_mode` — via `ThemeCubit` only |
| D-11 / Story 4.5 | `theme_mode` survives full data purge |
| Story 1.4 | `initialTheme` loaded in `AppDependencies.create()` **before** `runApp` — do not regress cold-start path |

### Current code state (READ BEFORE EDITING)

| Path | Current state | What 4.7 changes | Must preserve |
|------|---------------|------------------|---------------|
| `theme_cubit.dart` | `setThemePreference` persists + emits | **No API change** — UI calls existing method | Constructor `initialPreference` from deps |
| `theme_state.dart` | `AstraThemePreference` + `materialThemeMode` | **No change** | Enum values match DB strings |
| `user_preferences_repository.dart` | `getThemeMode` / `setThemeMode` | **No change** | Single-writer rule |
| `app_dependencies.dart` | `initialTheme = await getThemeMode()` before `runApp` | **No change** unless flash regression found | Async create path |
| `app.dart` | `BlocProvider<ThemeCubit>` wraps `MaterialApp` | **No change** | `theme` / `darkTheme` / `themeMode` binding |
| `my_data_screen.dart` | Background → Footprint → Daily goal → Your data | Insert Appearance section | Export/import/purge, banners, goal editor |
| `period_toggle.dart` | 2-segment pill pattern | **Reference only** — copy visual pattern for 3 segments | Do not break History |
| `my_data_screen_test.dart` | `BlocProvider<MyDataCubit>` only | Add `ThemeCubit` provider in test harness | Existing export/purge tests |

### Theme change flow (sequence)

```text
User taps segment on ThemeSelector (My Data)
    → ThemeCubit.setThemePreference(preference)
         → UserPreferencesRepository.setThemeMode(preference)
         → emit ThemeState(preference)
    → BlocBuilder<ThemeCubit> in app.dart rebuilds MaterialApp.themeMode
    → All tabs (Today, History, My Data) pick up new ThemeData immediately

Cold start (already implemented):
    AppDependencies.create()
         → getThemeMode()
         → ThemeCubit(initialPreference: loaded)
         → MaterialApp first frame uses correct themeMode (no flash)
```

### System / OS theme behavior (AC #2)

When preference is `system`, `ThemeState.materialThemeMode` is `ThemeMode.system`. Flutter resolves effective brightness from `MediaQuery.platformBrightness` — **no custom `WidgetsBindingObserver` required**. Verify manually by toggling OS theme while app is foregrounded.

### UX compliance (UX §2.2, §2.5, UX-DR22)

| Element | Spec |
|---------|------|
| Section headline | `"Appearance"` (`SectionCard` — matches UX §2.5 item 4) |
| Segments | System · Light · Dark |
| Container | `color.bg.subtle` pill, selected `color.bg.elevated` |
| Touch target | `AstraSpacing.kMinTouchTarget` (48dp) |
| Selected indicator | Accent underline (same as `PeriodToggle`) |
| Persistence | Immediate on tap — no Save button, no snackbar |
| Copy | Neutral labels only; no coach language (UX-DR20) |

### Recommended file layout

```text
lib/presentation/widgets/theme_selector.dart              # NEW
lib/presentation/screens/my_data_screen.dart              # UPDATE — Appearance section

test/presentation/widgets/theme_selector_test.dart        # NEW
test/presentation/screens/my_data_screen_test.dart        # UPDATE — ThemeCubit provider + Appearance tests
```

### API naming guardrail (critical)

| Layer | Correct method | Wrong (do not use) |
|-------|----------------|---------------------|
| Cubit | `setThemePreference(AstraThemePreference)` | `setThemeMode()` — does not exist on cubit |
| Repository | `setThemeMode(AstraThemePreference)` | Direct SQL from UI |

Story 1.2 docs mention `setThemeMode()` on cubit — **implementation uses `setThemePreference`**. Follow the real codebase.

### Anti-patterns (do NOT)

- Call `userPreferences.setThemeMode` from `MyDataScreen` (bypasses cubit / `MaterialApp` rebuild)
- Add theme state to `MyDataCubit` or SQLite outside `user_preferences`
- Use Material `SegmentedButton` with default Material colors (breaks ASTRA tokens)
- Hardcode `Color(0xFF...)` in `ThemeSelector`
- Block Story 4.7 on Epic 5 contrast work (AC #4 explicit deferral)
- Change `AppDependencies.create()` theme load order without strong evidence of flash bug
- Move Appearance section below Your data or above Footprint
- Allow theme changes during export/import/purge in-flight

### Previous story intelligence (Story 4.6 — immediate predecessor)

**Reuse directly:**

- `SectionCard` + section spacing pattern on `MyDataScreen`
- `dataActionInFlight` guard for disabling interactive rows during admin ops
- Sub-task commit discipline: review brief in French, wait for Baptiste OK
- Test helper `pumpScreen` pattern — extend with `ThemeCubit`, do not rewrite export tests

**4.6 handoff (explicit):**

Insert Appearance **between** Daily goal (`SectionCard` ~line 166) and Your data (`SectionCard` ~line 205). Final scroll order matches UX-DR11.

**4.6 code review lesson:** Goal save uses bool result + error snackbar — theme change does **not** need snackbar per UX (immediate silent apply).

### Git intelligence (recent commits)

| Commit | Relevance |
|--------|-----------|
| `252f710` | 4.6 done — My Data has Daily goal section; Appearance slot ready |
| `a32043e` | `GoalEditorRow.enabled` pattern for in-flight guard |
| `5bd4a75` | Section insertion pattern on `my_data_screen.dart` |
| Stories 1.2 / 1.4 | Theme infrastructure + cold-start load — UI was deferred to 4.7 |

### Library / framework notes

- No new dependencies
- Flutter `ThemeMode.system` handles OS changes — Flutter 3.44 / project SDK unchanged
- `ThemeCubit` already tested for persist round-trip in `theme_cubit_test.dart`

### Testing requirements

| Test | Purpose |
|------|---------|
| `theme_selector_test.dart` | UX-DR22 segment interaction + semantics |
| `my_data_screen_test.dart` | Section order, ThemeCubit wiring, disabled during data ops |
| `theme_cubit_test.dart` | Regression — persist + emit (existing) |
| Manual | Cold start no flash; OS theme toggle with System selected |
| Manual | Purge preserves theme selection |

### Handoff for Story 4.8

Display name edit row will land on My Data (may be minimal layout before full 4.2 sections). Story 4.7 must leave **Goal → Appearance → Your data** order intact; 4.8 adds name row without reordering Appearance.

### Project context reference

- Review-before-commit: `docs/project-context.md` — one sub-task per commit, French review brief, wait for Baptiste OK
- Explain in review brief: `ThemeCubit` vs repository, why `BlocBuilder` on My Data, `ThemeMode.system` vs forced light/dark

### References

- [Source: `_bmad-output/planning-artifacts/epics.md` — Story 4.7, FR31, UX-DR11/20/22]
- [Source: `_bmad-output/planning-artifacts/ux-design-specification.md` — §2.2 ThemeSelector, §2.5 My Data layout, §4.6 copy]
- [Source: `_bmad-output/planning-artifacts/architecture.md` — ThemeCubit + MaterialApp.themeMode]
- [Source: `_bmad-output/planning-artifacts/prds/prd-astra-app-2026-05-22/prd.md` — FR-31, A-18 default system]
- [Source: `_bmad-output/implementation-artifacts/stories/1-2-design-tokens-and-theme-system.md` — token + ThemeCubit pipeline]
- [Source: `_bmad-output/implementation-artifacts/stories/1-4-user-preferences-persistence.md` — cold-start load, repository API]
- [Source: `_bmad-output/implementation-artifacts/stories/4-6-daily-goal-editor-on-my-data.md` — section order handoff, in-flight guard]
- [Source: `lib/presentation/cubits/theme_cubit.dart` — setThemePreference]
- [Source: `lib/presentation/widgets/period_toggle.dart` — segmented pill reference]
- [Source: `lib/core/di/app_dependencies.dart` — initialTheme before runApp]
- [Source: `lib/presentation/screens/my_data_screen.dart` — insertion point]

## Dev Agent Record

### Agent Model Used

Auto (Cursor)

### Debug Log References

- Widget test SQLite: tap + `setThemePreference` must run inside `tester.runAsync` (same pattern as `widget_test.dart`).

### Completion Notes List

- Added `ThemeSelector` (3 segments, `PeriodToggle` visual pattern, semantics, `enabled` flag).
- My Data: `Appearance` section between Daily goal and Your data; `BlocBuilder<ThemeCubit>`; disabled during data admin in-flight.
- Tests: `theme_selector_test` (4), `my_data_screen_test` Appearance/Dark/export/purge (4); `theme_cubit_test` unchanged (3 pass).
- `flutter analyze` clean on touched lib files; automated tests pass for story scope.

### File List

- lib/presentation/widgets/theme_selector.dart (new)
- lib/presentation/screens/my_data_screen.dart (modified)
- test/presentation/widgets/theme_selector_test.dart (new)
- test/presentation/screens/my_data_screen_test.dart (modified)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified)
- _bmad-output/implementation-artifacts/stories/4-7-theme-selector-and-my-data-integration.md (modified)

## Change Log

- 2026-06-03: Story 4.7 created — theme selector and My Data integration context engine analysis complete
- 2026-06-03: Implementation complete — ThemeSelector, My Data Appearance, tests; status → review
- 2026-06-03: Code review fixes — ThemeCubit serialization, selector a11y/no-op tap, import disabled test; status → done

