# Story 13.3: Weight & Height Onboarding Steps

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->
<!-- Mockup ref: assets/.../Weight-light-70d5a378-*.png, Height-light-2ccf1294-*.png (Baptiste 2026-06-17) -->
<!-- UX-DR27 ruler delivered in 13.2 — this story wires it into onboarding with segmented units + skip -->

## Story

As a **user**,
I want to set my weight and height with familiar unit toggles and a ruler,
So that derived metrics are accurate from day one.

## Acceptance Criteria

1. **Given** weight step (step 2)  
   **When** the page renders  
   **Then** headline reads **What is your weight?** (centered, `AstraTypography.titleFor`)  
   **And** `AstraSegmentedControl<WeightDisplayUnit>` shows **kg** / **lb** segments  
   **And** `AstraHorizontalRuler` shows default **70** in the active display unit  
   **And** footer shows **Back** + ghost **Skip** + primary **Continue** (shell pattern from 13.1)

2. **Given** weight step with kg selected  
   **When** user scrolls the ruler  
   **Then** readout updates in kg; canonical session value tracks **kg** (one decimal max, same as repository)  
   **Given** user switches segment to lb  
   **When** ruler rebuilds  
   **Then** range, ticks, and readout use lb display domain (`weightKgToDisplayLb` / `displayLbToWeightKg`)  
   **And** the **same body weight** is preserved (no reset to default on unit toggle)

3. **Given** height step (step 3)  
   **When** the page renders  
   **Then** headline reads **What is your height?**  
   **And** segmented control shows **cm** / **in** (mockup uses total inches — **not** Profile `ft+in`)  
   **And** ruler default is **170 cm** (or equivalent inches display)  
   **And** footer shows **Back** + **Skip** + primary **Let's Go** (not "Continue")

4. **Given** height step with cm selected  
   **When** user scrolls the ruler  
   **Then** readout updates in integer cm; canonical session value is `int` cm  
   **Given** user switches to inches  
   **When** ruler rebuilds  
   **Then** ruler uses total-inch display domain derived from `kMinHeightCm`/`kMaxHeightCm`  
   **And** the same body height is preserved across unit toggle

5. **Given** user taps **Skip** on weight or height  
   **When** they proceed (Skip advances immediately)  
   **Then** that metric is marked **skipped** (`null` canonical — not the ruler default)  
   **And** flow advances to the next step (weight Skip → height; height Skip → completion)

6. **Given** user taps **Continue** on weight (without Skip)  
   **When** advancing  
   **Then** current ruler selection is stored in cubit session state as canonical kg  
   **And** flow advances to height step

7. **Given** user taps **Let's Go** on height (without Skip)  
   **When** onboarding completes  
   **Then** `UserPreferencesRepository.setWeightKg` receives session kg or `null` if weight was skipped  
   **And** `setHeightCm` receives session cm or `null` if height was skipped  
   **And** `setDailyStepGoal(8000)` is called (`kDefaultStepGoal`)  
   **And** `setOnboardingComplete(true)` is called  
   **And** `OnboardingStatus.completed` fires → `app.dart` gate shows `AppScaffold`  
   **And** display-unit prefs (`weight_display_unit`, `height_display_unit`) are **not** written on first launch (session-local toggles only per sprint-change-proposal)

8. **Given** implementation complete  
   **When** `flutter analyze` and `flutter test` run  
   **Then** no new analyzer issues  
   **And** `onboarding_flow_test.dart` asserts real weight/height copy (not placeholders)  
   **And** tests cover: unit toggle preserves value, Skip → null persist, Let's Go → prefs + onboarding flag

**Depends on:** Stories 13.1 (done), 13.2 (done). **Enables:** Story 13.4 (cleanup).  
**Mockup ref:** `Weight-light`, `Height-light`.

## Tasks / Subtasks

- [x] **Sub-task A — Cubit session state + completion persist** (AC: #5, #6, #7)
  - [x] Extend `OnboardingState`: `weightKg` (`double?`), `heightCm` (`int?`), `weightSkipped` / `heightSkipped` (`bool`), `weightDisplayUnit` (`WeightDisplayUnit`), `heightUsesInches` (`bool` — onboarding-only; Profile still uses `HeightDisplayUnit`)
  - [x] Add cubit methods: `setWeightKg`, `setHeightCm`, `setWeightDisplayUnit`, `setHeightUsesInches`, `skipWeight()`, `skipHeight()`, `commitWeightAndContinue()`, `completeWithHeight()`
  - [x] Update `completeOnboarding()` (or replace call sites with new method) to persist `weight_kg`/`height_cm` (null when skipped), `daily_step_goal=8000`, `onboarding_complete=true` — **do not** pass `displayName`, **do not** set `goalNotificationsEnabled` from onboarding
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Shell Skip + inch conversion helpers** (AC: #1, #3, #5)
  - [x] Extend `OnboardingShell`: optional `secondaryLabel` (e.g. `Skip`), `onSecondary`, `secondaryEnabled` — ghost `AstraButton` centered above footer row or between content and footer per mockup
  - [x] Add to `display_unit_formatter.dart`: `heightCmToDisplayInches(int)`, `displayInchesToHeightCm(int)` using `_cmPerInch` (round half-up; clamp to `kMinHeightCm`/`kMaxHeightCm`) — **reuse constant, do not duplicate**
  - [x] Unit tests for inch↔cm round-trip at bounds
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Weight page** (AC: #1, #2, #5, #6)
  - [x] Create `onboarding_weight_page.dart` — headline, `AstraSegmentedControl`, `AstraHorizontalRuler` with configs from 13.2 table (kg: 30–300 step 1; lb: converted bounds)
  - [x] Ruler: `enableHaptics: true` in app; `enableHaptics: false` in tests
  - [x] On unit toggle: convert canonical kg → new display value for ruler (preserve body metric)
  - [x] Wire Skip → `skipWeight()` + `nextStep()`; Continue → `commitWeightAndContinue()`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Height page + flow wiring** (AC: #3, #4, #5, #7)
  - [x] Create `onboarding_height_page.dart` — cm/in segments, ruler configs (cm: 100–250 step 1; in: `(kMinHeightCm/kMaxHeightCm)` as inch range)
  - [x] Replace placeholders in `onboarding_flow.dart`; height primary label **Let's Go**; `onPrimary` → `completeWithHeight()`
  - [x] Delete `onboarding_weight_placeholder.dart` and `onboarding_height_placeholder.dart` (or leave unused — prefer delete if no imports remain)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task E — Tests** (AC: #8)
  - [x] Update `onboarding_flow_test.dart`: expect "What is your weight?" / "What is your height?"; placeholder text absent
  - [x] Test: weight Continue → height visible; Let's Go → `onComplete` + repo `onboarding_complete` + `daily_step_goal` 8000
  - [x] Test: Skip weight → `weight_kg` null after complete; Skip height → `height_cm` null
  - [x] Test: persisted weight/height when not skipped (e.g. 70 kg, 170 cm)
  - [x] Optional: `onboarding_weight_page_test.dart` for segmented toggle preserving value
  - [x] Run `flutter analyze` + `flutter test`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary (critical)

| Area | In scope (13.3) | Out of scope (13.4) |
|------|-----------------|---------------------|
| Weight/height pages | Full UI + ruler + segments | — |
| Placeholders | Replace + delete | — |
| `completeOnboarding` persist | weight, height, goal 8000, onboarding flag | Remove goal/notification fields from state |
| Old onboarding pages | Stay on disk (unused) | Delete `OnboardingTrustPage`, permissions, goal, display name |
| Display-unit prefs on complete | **Do not** write on first launch | Settings owns prefs |
| Profile editor sheets | Unchanged (text fields) | Optional ruler migration |
| `OnboardingShell` | Add Skip secondary | — |
| Version bump | None | Epic 13 close → `0.6.0+11` |

**This story makes onboarding completable end-to-end.** Height **Let's Go** must call completion — today `onboarding_flow.dart` step 2 has `onPrimary: () {}` (no-op); fix in 13.3.

### Visual reference (authoritative mockups)

**Weight screen (`Weight-light`):**

| Region | Spec |
|--------|------|
| Progress | Segment 2 of 3 active |
| Headline | **What is your weight?** — centered title |
| Unit toggle | `AstraSegmentedControl` kg / lb — full width, inset shadow track |
| Picker | `AstraHorizontalRuler` in elevated card — readout **70**, major labels every 10 |
| Skip | Ghost **Skip** — proceeds with `weight_kg = null` |
| Footer | Back (left) + Continue (right) |

**Height screen (`Height-light`):**

| Region | Spec |
|--------|------|
| Progress | Segment 3 of 3 active |
| Headline | **What is your height?** |
| Unit toggle | cm / **in** (total inches on ruler — mockup label "in", not ft+in) |
| Picker | Same card pattern; default **170** cm equivalent |
| Skip | Ghost **Skip** → `height_cm = null` |
| Footer | Back + **Let's Go** (primary) |

**Layout:** Headline top → spacing → segmented control → spacing → `Expanded` ruler card (center vertically in remaining space if mockup allows).

### Ruler configuration (implement exactly — from Story 13.2)

| Use case | min | max | step | majorTickEvery | Default | unitLabel |
|----------|-----|-----|------|----------------|---------|-----------|
| Weight kg | `kMinWeightKg` (30) | `kMaxWeightKg` (300) | `1` | `10` | `70` | `kg` |
| Weight lb | `weightKgToDisplayLb(30)` ≈ 66 | `weightKgToDisplayLb(300)` ≈ 661 | `1` | `10` | `weightKgToDisplayLb(70)` ≈ 154 | `lb` |
| Height cm | `kMinHeightCm` (100) | `kMaxHeightCm` (250) | `1` | `10` | `170` | `cm` |
| Height in | `heightCmToDisplayInches(100)` ≈ 39 | `heightCmToDisplayInches(250)` ≈ 98 | `1` | `12` | `heightCmToDisplayInches(170)` ≈ 67 | `in` |

Import bounds from `preference_keys.dart` — **do not duplicate**.

### Unit toggle — preserve body metric (critical)

```dart
// Weight: canonical kg in cubit; ruler shows display domain
void _onWeightUnitChanged(WeightDisplayUnit unit) {
  final kg = _canonicalKg ?? 70.0;
  cubit.setWeightDisplayUnit(unit);
  // Ruler value = unit == kg ? kg : weightKgToDisplayLb(kg)
}

// On ruler onChanged (lb mode):
cubit.setWeightKg(displayLbToWeightKg(displayLb));

// Height: canonical cm in cubit; inches mode uses total inches on ruler
```

**Anti-pattern:** Resetting to 70/170 on segment change — breaks user trust.

### Skip vs Continue semantics

| Action | Weight step | Height step |
|--------|-------------|-------------|
| **Skip** | `weightSkipped=true`, `weightKg=null`, `nextStep()` | `heightSkipped=true`, `heightCm=null`, `completeWithHeight()` |
| **Continue / Let's Go** | Save current ruler → canonical; `nextStep()` | Save current ruler → canonical; `completeOnboarding()` |

Skip does **not** persist the visible ruler default — only explicit Continue/Let's Go saves the picked value.

### `completeOnboarding` target shape (13.3)

```dart
Future<void> completeWithHeight() async {
  // height already in state from ruler unless heightSkipped
  await userPreferences.setDailyStepGoal(kDefaultStepGoal);
  await userPreferences.setWeightKg(
    state.weightSkipped ? null : state.weightKg,
  );
  await userPreferences.setHeightCm(
    state.heightSkipped ? null : state.heightCm,
  );
  await userPreferences.setOnboardingComplete(true);
  emit(state.copyWith(status: OnboardingStatus.completed));
}
```

**Do not** call `setDisplayName`, `setGoalNotificationsEnabled` from onboarding (13.4 removes dead state fields).

### Current file state (READ BEFORE EDITING)

**`onboarding_flow.dart`** — today:
- Step 1: intro (done)
- Step 2: `OnboardingWeightPlaceholder` + `onPrimary: cubit.nextStep` (no metric capture)
- Step 3: `OnboardingHeightPlaceholder` + `onPrimary: () {}` (**broken — no completion**)

**`onboarding_cubit.dart`** — `completeOnboarding({int? goal, String? displayName})` still uses `state.resolvedGoal` and notification opt-in from old 4-step flow.

**`onboarding_state.dart`** — still has `goalInput`, `notificationOptIn` (leave fields until 13.4; stop using them in 13.3 completion path).

**`AstraHorizontalRuler`** — done at `lib/presentation/widgets/astra_horizontal_ruler.dart`; API stable; use `itemExtent = 10.0`.

### Reuse — do not reinvent

| Asset | Location | Use in 13.3 |
|-------|----------|-------------|
| `AstraHorizontalRuler` | `astra_horizontal_ruler.dart` | Picker on both pages |
| `AstraSegmentedControl` | `astra_segmented_control.dart` | kg/lb; cm/in |
| `WeightDisplayUnit` | `display_unit_preferences.dart` | Weight segments |
| `weightKgToDisplayLb` / `displayLbToWeightKg` | `display_unit_formatter.dart` | lb ruler domain |
| `heightCmToFtIn` | `display_unit_formatter.dart` | **Profile only** — onboarding uses total inches helpers (add in 13.3) |
| `UserPreferencesRepository.setWeightKg/setHeightCm` | `user_preferences_repository.dart` | Completion persist; null deletes key |
| `OnboardingShell` | `onboarding_shell.dart` | Extend with Skip |
| `AstraButton` ghost | `astra_button.dart` | Skip control |
| `kDefaultStepGoal` | `preference_keys.dart` | 8000 on complete |

**Do not** add third-party picker packages. **Do not** replace Profile `weight_editor_sheet` / `height_editor_sheet`.

### Suggested file tree after 13.3

```
lib/presentation/onboarding/
├── onboarding_flow.dart                 # UPDATE — real pages, Let's Go completion
├── onboarding_weight_page.dart          # NEW
├── onboarding_height_page.dart          # NEW
├── onboarding_shell.dart                # UPDATE — Skip secondary
├── onboarding_weight_placeholder.dart   # DELETE
└── onboarding_height_placeholder.dart   # DELETE

lib/presentation/cubits/
├── onboarding_state.dart                # UPDATE — body metrics + skip flags
└── onboarding_cubit.dart                # UPDATE — session + completeWithHeight

lib/presentation/formatters/
└── display_unit_formatter.dart          # UPDATE — inch helpers for onboarding

test/presentation/onboarding/
└── onboarding_flow_test.dart            # UPDATE

test/presentation/formatters/
└── display_unit_formatter_test.dart     # UPDATE — inch helpers
```

### Anti-patterns (do not do in 13.3)

- ❌ Use `HeightDisplayUnit.ftIn` on onboarding height page (mockup is cm/**in**)
- ❌ Persist `weight_display_unit` / `height_display_unit` on first-launch complete
- ❌ Reset ruler to default on unit segment change
- ❌ Treat Skip as "save default 70/170"
- ❌ Leave height `onPrimary` as no-op
- ❌ Delete old trust/permissions/goal/display-name pages (13.4)
- ❌ Remove `goalInput` / `notificationOptIn` from state yet (13.4)
- ❌ Use `state.resolvedGoal` for completion — always `kDefaultStepGoal`
- ❌ Request notification permission from onboarding
- ❌ Batch sub-tasks into one commit without Baptiste review

### Epic 13 cross-story context

| Story | Focus | Relation to 13.3 |
|-------|-------|------------------|
| 13.1 (done) | Shell, intro, placeholders | Shell + footer; add Skip here |
| 13.2 (done) | `AstraHorizontalRuler` | Embed with configs above |
| **13.3** (this) | Weight + height pages, persist, completion | Replaces placeholders |
| 13.4 | Cleanup | Delete old pages; prune cubit state; beta checklist |

### Mandatory dev workflow

Follow [`docs/project-context.md`](../../../docs/project-context.md):

- One commit per sub-task (A–E) after Baptiste review
- Review brief format required before each commit
- No version bump until Epic 13 closes (`0.6.0+11`)

### Project Structure Notes

- Aligns with architecture: `presentation/onboarding/` intro + weight + height pages
- Canonical storage unchanged: `weight_kg` (double), `height_cm` (int) — same validation as Profile
- FR-23 amended: goal defaults to 8000 at completion, not collected in UI

### References

- [Source: _bmad-output/planning-artifacts/epics.md — Epic 13, Story 13.3]
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-06-17.md — §4.2 UX table, skip rules, FR-23]
- [Source: _bmad-output/implementation-artifacts/stories/13-2-astra-horizontal-ruler-widget.md — ruler API + configs]
- [Source: _bmad-output/implementation-artifacts/stories/13-1-onboarding-shell-and-intro-screen.md — shell, flow wiring]
- [Source: lib/presentation/onboarding/onboarding_flow.dart — placeholder + no-op height CTA]
- [Source: lib/presentation/cubits/onboarding_cubit.dart — completeOnboarding to update]
- [Source: lib/core/constants/preference_keys.dart — bounds + kDefaultStepGoal]
- [Source: mockup assets/.../Weight-light-*.png, Height-light-*.png]

## Dev Agent Record

### Agent Model Used

composer-2.5-fast

### Debug Log References

- Widget tests for DB completion use `tester.runAsync` + direct cubit calls (same pattern as `widget_test.dart` onboarding gate).

### Completion Notes List

- Extended `OnboardingState`/`OnboardingCubit` with body-metric session fields, skip flags, and `completeWithHeight()` (persists weight/height nullable, goal 8000, onboarding flag — no display-unit pref writes).
- Added `OnboardingShell` ghost Skip between content and footer.
- Added `heightCmToDisplayInches` / `displayInchesToHeightCm` formatters for onboarding total-inches mode.
- Replaced weight/height placeholders with ruler pages wired in `onboarding_flow.dart`; height CTA **Let's Go** completes onboarding end-to-end.
- Tests: 13 flow widget tests + 3 new cubit tests + inch formatter tests; 55 tests passing in targeted suite.

### File List

- `lib/presentation/cubits/onboarding_state.dart` — UPDATE
- `lib/presentation/cubits/onboarding_cubit.dart` — UPDATE
- `lib/presentation/formatters/display_unit_formatter.dart` — UPDATE
- `lib/presentation/onboarding/onboarding_shell.dart` — UPDATE
- `lib/presentation/onboarding/onboarding_flow.dart` — UPDATE
- `lib/presentation/onboarding/onboarding_weight_page.dart` — NEW
- `lib/presentation/onboarding/onboarding_height_page.dart` — NEW
- `lib/presentation/onboarding/onboarding_weight_placeholder.dart` — DELETE
- `lib/presentation/onboarding/onboarding_height_placeholder.dart` — DELETE
- `test/presentation/onboarding/onboarding_flow_test.dart` — UPDATE
- `test/presentation/cubits/onboarding_cubit_test.dart` — UPDATE
- `test/presentation/formatters/display_unit_formatter_test.dart` — UPDATE

### Change Log

- 2026-06-17: Story 13.3 — weight/height onboarding pages with ruler, unit toggles, Skip semantics, and completion persist (enables end-to-end onboarding).

## Technical Requirements

1. **Replace placeholders** with `OnboardingWeightPage` and `OnboardingHeightPage`
2. **Segmented units:** kg/lb (`WeightDisplayUnit`); cm/in (onboarding-only inches mode — not `ft+in`)
3. **Ruler binding:** display domain in widget; canonical kg/cm in cubit
4. **Unit toggle:** preserve body metric across segment changes
5. **Skip:** ghost control; `null` canonical for skipped step
6. **Completion:** Let's Go → persist metrics + `daily_step_goal=8000` + `onboarding_complete=true`
7. **No display-unit pref writes** on first-launch completion
8. **Shell:** extend for Skip; height CTA label **Let's Go**
9. **Inch helpers** in `display_unit_formatter.dart` with tests
10. **No new packages**
11. **Widget/integration tests** per AC #8

## Architecture Compliance

| Decision | Requirement for 13.3 |
|----------|----------------------|
| D-09 | `OnboardingCubit` — extend state; no new cubits |
| D-10 | Onboarding stack separate from tab shell |
| D-22 | Pages under `presentation/onboarding/` |
| D-27 | Reuse Phosphor arrows in shell (unchanged) |
| Write path | `UserPreferencesRepository` only — no cubit SQL |
| Canonical units | kg + cm in DB; display conversion in presentation |
| Navigation | `BlocListener` completion → `app.dart` gate unchanged |

## Library & Framework Requirements

| Package | Version | 13.3 action |
|---------|---------|-------------|
| flutter_bloc | ^9.1.1 | **Reuse** — extend `OnboardingCubit` |
| (existing widgets) | — | `AstraHorizontalRuler`, `AstraSegmentedControl`, `AstraButton` |

**Do NOT add** runtime packages.

## File Structure Requirements

| Path | Action |
|------|--------|
| `lib/presentation/onboarding/onboarding_weight_page.dart` | NEW |
| `lib/presentation/onboarding/onboarding_height_page.dart` | NEW |
| `lib/presentation/onboarding/onboarding_flow.dart` | UPDATE |
| `lib/presentation/onboarding/onboarding_shell.dart` | UPDATE — Skip |
| `lib/presentation/onboarding/onboarding_weight_placeholder.dart` | DELETE |
| `lib/presentation/onboarding/onboarding_height_placeholder.dart` | DELETE |
| `lib/presentation/cubits/onboarding_state.dart` | UPDATE |
| `lib/presentation/cubits/onboarding_cubit.dart` | UPDATE |
| `lib/presentation/formatters/display_unit_formatter.dart` | UPDATE — inch helpers |
| `test/presentation/onboarding/onboarding_flow_test.dart` | UPDATE |
| `test/presentation/formatters/display_unit_formatter_test.dart` | UPDATE |

## Testing Requirements

- **Flow:** weight headline visible after intro; height headline on step 3
- **Flow:** Let's Go triggers `onComplete` callback
- **Repository:** after full flow with picks → `getWeightKg()` ≈ 70, `getHeightCm()` 170, `getDailyStepGoal()` 8000, onboarding complete true
- **Skip weight:** complete with only height set (or both skipped) → `weight_kg` key absent/null
- **Skip height:** `height_cm` null after complete
- **Unit toggle (widget):** change kg→lb without scroll → canonical kg unchanged (mock cubit or page test)
- **Pattern:** `MaterialApp` + `buildAstraLightTheme()` + in-memory DB via `AppDependencies.test`
- **Ruler tests:** `enableHaptics: false` when pumping ruler in tests
- **Commands:** `flutter analyze` (0 issues), `flutter test`

## Previous Story Intelligence

From **Story 13.2** (done):

- `AstraHorizontalRuler` is standalone — wire from parent pages only
- Config table for kg/lb/cm/in documented in 13.2 dev notes — use verbatim
- `enableHaptics: false` in widget tests; `AstraInsetShadowSurface` already on ruler card
- Commits: `feat(widgets):`, `test(widgets):` — follow same discipline under `feat(onboarding):`
- Code review hardened snap/clamp — trust widget API; don't fork ruler logic into pages

From **Story 13.1** (done):

- `OnboardingShell` footer: Back left, primary right; intro uses trailing arrow
- Shell deferred **Skip** to 13.3 — implement `secondaryLabel` / `onSecondary` now
- Permission bridge on intro only — do not re-request on weight/height
- `totalSteps = 3`; placeholders intentional until this story
- Review-before-commit sub-task gate (A–E)

From **Story 10.6 / 10.7** (done):

- `WeightDisplayUnit` / `HeightDisplayUnit` exist for Settings/Profile
- Onboarding height uses **inches** per mockup — do not force `HeightDisplayUnit.ftIn` on onboarding UI
- Profile editors remain text-field sheets — out of scope

From **Epic 6** (done):

- Null height/weight → stride 0.76 m, weight 70 kg defaults for derived metrics
- Skip all metrics is valid — app must function with null prefs

## Git Intelligence Summary

Recent commits (Epic 13 ruler work):

| Commit | Relevance |
|--------|-----------|
| `0648931` | Ruler hardening after review — use shipped widget as-is |
| `2e87134` | Ruler widget test patterns |
| `142f1b8` | Semantics + haptics — use `enableHaptics` flag in tests |
| `5b74d1c` | Card chrome — match visual language on onboarding pages |
| `db72ee0` | Tick scale — parent supplies `majorTickEvery` |

**Convention:** `feat(onboarding):`, `test(onboarding):` per sub-task; `feat(formatters):` for inch helpers if separate commit.

## Latest Tech Information

- **Flutter 3.x:** `BlocProvider` + `context.read/watch<OnboardingCubit>()` — same as 13.1
- **Float drift:** Use `displayLbToWeightKg` / index-based ruler math — don't hand-roll lb conversion constants
- **Inches range:** `(heightCm / 2.54).round()` for display; inverse ` (inches * 2.54).round()` clamped to `[kMinHeightCm, kMaxHeightCm]`
- **No schema migration** — keys `weight_kg`, `height_cm` already exist

## Project Context Reference

Mandatory — [`docs/project-context.md`](../../../docs/project-context.md):

- Review-before-commit gate (sub-tasks A–E)
- Commit message convention: `type(scope): imperative summary`
- Story file: `_bmad-output/implementation-artifacts/stories/13-3-weight-and-height-onboarding-steps.md`
- Version bump only at Epic 13 close: `0.6.0+11` in `pubspec.yaml` + `README.md`

## Story Completion Status

- Status: **done**
- Ultimate context engine analysis completed — comprehensive developer guide created
- Epic 13 status: **in-progress** (13.1–13.2 done; 13.3 ready)
- **Critical guardrail:** Height **Let's Go** must complete onboarding with `daily_step_goal=8000` and nullable body metrics — fix the no-op `onPrimary` on step 3
