# Story 23.1: Add Semantic Button Label for Today Goal Action

Status: done

<!-- Post-audit Epic 23 — tracker: sprint-status-post-audit.yaml -->
<!-- Source: epics-post-audit.md Story 23-1 · diagnostic-accessibilité-statique.md Bloquant · AUD-25 · UX-AUD-02 -->
<!-- Prerequisite: Story 22-2 — done (CTA disabled during loading + basic Semantics scaffold) -->
<!-- Version bump: deferred to Epic 23 close (minor+1, patch=0, build+1) -->
<!-- Validation: optional — run validate-create-story before dev-story -->

## Story

As a **TalkBack/VoiceOver user**,
I want the Today goal control announced as a labelled button,
So that I can set my goal without relying on visual layout alone.

## Acceptance Criteria

1. **Given** the Today “Set goal” pill in `_GoalRingCard` (`today_screen.dart` L552–592)
   **When** the semantics tree is built in a display-ready state
   **Then** the node is `Semantics(button: true, label: …)` with a **dedicated action label** (AUD-25)
   **And** the label is sourced from a new ARB key (`todaySetGoalSemantics`), not reused visual copy alone
   **And** the visual `Text` keeps `todaySetGoalLabel` (“Set goal” / “Définir l'objectif”)

2. **Given** `TodayStatus.loading` **or** `lastDisplayedStepsLoaded == false`
   **When** semantics are built
   **Then** `Semantics(enabled: false)` reflects the disabled CTA (Story 22-2 contract preserved)
   **And** assistive tech announces the button as unavailable (not tappable)

3. **Given** the adjacent `GoalRing` progress semantics (UX-AUD-02: `"Steps today: {n} of {goal}"`)
   **When** this story ships
   **Then** the Set goal button label describes the **edit action**, not step progress
   **And** `GoalRing` / `AnimatedStepCount` semantics are **not** modified (liveRegion = Story 23-3)

4. **Given** English and French locales
   **When** ARB keys are added
   **Then** `app_en.arb` and `app_fr.arb` both define `todaySetGoalSemantics`
   **And** `flutter gen-l10n` output is committed under `lib/l10n/`

5. **Given** existing Today widget tests
   **When** this story ships
   **Then** new semantics tests cover enabled + disabled Set goal button (mirror `accent_preset_selector_test.dart` / `goal_ring_test.dart` patterns)
   **And** Story 16-5 / 22-2 build-isolation tests still pass (`staticSetGoal` probe unchanged)
   **And** `flutter test --exclude-tags slow` passes

**Covers:** AUD-25 · UX-AUD-02 (action vs progress separation) · diagnostic-accessibilité-statique.md Bloquant (Today InkWell)

**Depends on:** Story 22-2 — **done** (disabled CTA + `Semantics(button: true, enabled: …)` scaffold)

**Out of scope:** GoalRing `liveRegion` / step-count announcements (Story 23-3 / AUD-27), converting CTA to `AstraButton` or `DataExportButton`, `_UnitOptionTile` semantics (Story 23-2), `ExcludeSemantics` decorative sweep (AUD-33), version bump until Epic 23 closes.

## Tasks / Subtasks

- [x] **Sub-task A — Dedicated semantics ARB key** (AC: #1, #3, #4)
  - [x] Add to `app_en.arb`:
    ```json
    "todaySetGoalSemantics": "Set daily step goal",
    "@todaySetGoalSemantics": {
      "description": "Accessibility label for Today Set goal button (opens daily step goal editor)"
    }
    ```
  - [x] Add French equivalent in `app_fr.arb` (e.g. `"Définir l'objectif de pas quotidien"`)
  - [x] Run `flutter gen-l10n` (or `flutter pub get` if codegen is wired)
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task B — Wire Semantics label in `_GoalRingCard`** (AC: #1, #2, #3)
  - [x] In `today_screen.dart` Set goal block (~L561–564), replace `label: l10n.todaySetGoalLabel` with `label: l10n.todaySetGoalSemantics`
  - [x] Keep `Text(l10n.todaySetGoalLabel, …)` for visual copy — do **not** change pill styling or `AstraPressable` / `InkWell` gating from 22-2
  - [x] Preserve `Semantics(button: true, enabled: vm.enabled, …)` — do not add `hint` unless audit requires it (export buttons use label-only; match that pattern)
  - [x] Do **not** touch `GoalRing`, `GoalCelebration`, or `_GoalRingViewModel` selector slices
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task C — Semantics widget tests** (AC: #2, #5)
  - [x] Extend `test/presentation/screens/today_screen_selector_test.dart` (existing Set goal tap + build-isolation group)
  - [x] Test: display-ready state → `tester.ensureSemantics()` → `find.bySemanticsLabel(l10n.todaySetGoalSemantics)` finds one node with `button: true` and `enabled: true`
  - [x] Test: `TodayStatus.loading` → same finder reports `enabled: false` (or node absent from actionable set — assert via `tester.getSemantics`)
  - [x] Test: `lastDisplayedStepsLoaded: false` → disabled semantics
  - [x] Re-run existing Set goal tap tests — behaviour unchanged
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

- [x] **Sub-task D — Regression** (AC: #5)
  - [x] `dart analyze`
  - [x] `flutter test test/presentation/screens/today_screen_selector_test.dart`
  - [x] `flutter test test/presentation/screens/screen_smoke_test.dart`
  - [x] `flutter test --exclude-tags slow`
  - [x] **Stop → review brief → wait for Baptiste OK → commit**

## Dev Notes

### Story scope boundary

| In scope | Out of scope |
|----------|--------------|
| Dedicated `todaySetGoalSemantics` ARB key (EN + FR) | GoalRing progress / liveRegion (23-3) |
| Wire semantics label on existing Set goal `Semantics` wrapper | Refactor to shared button widget |
| Enabled + disabled semantics widget tests | Week day pill goal-achieved semantics (23-6) |
| Preserve 22-2 disable gating + 16-5 BlocSelector isolation | Version bump (Epic 23 close) |

### Root cause (read before editing)

**Audit finding (pre-22-2):** `_GoalRingCard` Set goal `InkWell` had no parent `Semantics` — Bloquant for TalkBack/VoiceOver [Source: diagnostic-accessibilité-statique.md L13–16].

**22-2 partial fix:** Added `Semantics(button: true, enabled: vm.enabled, label: l10n.todaySetGoalLabel)` but explicitly deferred “Rich semantic button label” to Epic 23 [Source: stories/22-2-disable-goal-cta-during-today-loading-states.md Out of scope].

**Remaining gap:** Visual label `"Set goal"` is terse; UX §4.3 action buttons use descriptive semantics (`myDataExportCsvSemantics`: “Export data as CSV file”). Set goal needs the same split: short visual + action-oriented accessibility label.

**UX-AUD-02 scope:** Applies to `GoalRing` progress (`todayGoalRingSemanticsProgress` / `todayGoalRingSemanticsGoalReached`) — **not** the Set goal CTA. Do not merge step count into the button label.

### Current implementation (UPDATE — do not rewrite)

```552:592:lib/presentation/screens/today_screen.dart
          BlocSelector<TodayCubit, TodayState, _SetGoalViewModel>(
            selector: _SetGoalViewModel.fromState,
            builder: (context, vm) {
              _probeSectionBuild('staticSetGoal');
              final l10n = AppLocalizations.of(context);
              // ...
              return Center(
                child: Semantics(
                  button: true,
                  enabled: vm.enabled,
                  label: l10n.todaySetGoalLabel,  // ← change to todaySetGoalSemantics
                  child: AstraPressable(
                    enabled: vm.enabled,
                    // InkWell + Text(l10n.todaySetGoalLabel) unchanged
```

**Enable predicate (preserve):**

```113:114:lib/presentation/screens/today_screen.dart
bool todaySetGoalEnabled(TodayState state) =>
    state.status != TodayStatus.loading && state.lastDisplayedStepsLoaded;
```

**GoalRing semantics (READ ONLY — Story 23-3):**

```634:654:lib/presentation/widgets/goal_ring.dart
          return Semantics(
            label: _semanticsLabel(l10n),
            value: _semanticsValue,
            // ... progress ring — do not modify in this story
```

### Reference pattern — action button semantics

Follow `DataExportButton`: visual `label` + separate `semanticsLabel` on parent `Semantics(button: true)` [Source: lib/presentation/widgets/data_export_button.dart L38–41, my_data_screen.dart L206–208].

Do **not** follow `MenuNavRow` hint concatenation (`"$label. $hint"`) — Set goal is a direct action button, not a navigation row.

### Architecture compliance

- **Presentation-only change** — no cubit, repository, or schema edits [Source: architecture.md NFR-5]
- **Localization:** All user-facing strings via ARB; run codegen after ARB edits [Source: project-context.md, Story 19-2]
- **OK commit gate:** One commit per sub-task; wait for Baptiste approval [Source: project-context.md § Development Workflow]
- **Build isolation:** `_SetGoalViewModel` selector must remain `{ enabled }` only — no `steps` / `goal` / `activityMetrics` in slice [Source: Story 16-5, 22-2 AC #3]

### File structure requirements

| File | Action |
|------|--------|
| `lib/l10n/app_en.arb` | ADD `todaySetGoalSemantics` |
| `lib/l10n/app_fr.arb` | ADD French translation |
| `lib/l10n/app_localizations*.dart` | REGENERATE via `flutter gen-l10n` |
| `lib/presentation/screens/today_screen.dart` | UPDATE Semantics `label` only (~1 line) |
| `test/presentation/screens/today_screen_selector_test.dart` | ADD semantics test group |

### Testing requirements

- Default verify: `flutter test --exclude-tags slow` [Source: project-context.md § Test commands]
- Semantics tests: `tester.ensureSemantics()` before assertions [Source: goal_ring_test.dart, accent_preset_selector_test.dart]
- Use `AppLocalizations` for expected labels — no hardcoded English in new tests
- Existing tests find Set goal by `find.text('Set goal')` — must still pass (visual label unchanged)

### Previous story intelligence

**From 22-2 (direct predecessor on same widget):**
- `_SetGoalViewModel` + `BlocSelector` already isolates Set goal from live step ticks
- Disabled path: `AstraPressable(enabled: false)`, `InkWell(onTap: null)`, muted text color
- Defense-in-depth: `_onSetGoalTapped` early-returns when `!todaySetGoalEnabled`
- Tests at `today_screen_selector_test.dart` L862+ cover tap blocking — extend with semantics, do not remove

**From 22-5 (Epic 22 close):**
- `_onSetGoalTapped` is sync callback wrapping async work — no change needed
- `discarded_futures` lint enabled project-wide — do not introduce bare future calls in callbacks

### Git intelligence summary

Recent Epic 22 commits closed robustness work; Today screen last touched for:
- `unawaited` on stale banner refresh and permission CTA (22-5)
- Set goal disable gating + basic Semantics (22-2)

No conflicting in-flight changes on `today_screen.dart` Set goal block.

### Latest tech information

- **Flutter Semantics API (3.x):** `Semantics(button: true, enabled: bool, label: String)` merges with platform accessibility bridges (TalkBack / VoiceOver). `enabled: false` maps to non-actionable state.
- **No new packages** — built-in `flutter/semantics.dart` via `material.dart`.
- **Static audit disclaimer:** diagnostic notes runtime TalkBack/VoiceOver is not a substitute for manual spot-check on device [Source: epics-post-audit.md NFR-AUD-05].

### Project context reference

- OK commit gate + diff-only delivery: `docs/project-context.md`
- Version bump at Epic 23 close only: `sprint-status-post-audit.yaml` WORKFLOW NOTES
- UX semantics table: `_bmad-output/planning-artifacts/ux-design-specification.md` §4.3

## Dev Agent Record

### Agent Model Used

Composer

### Debug Log References

- Child `Text` semantics overrode parent `Semantics.label`; fixed with `ExcludeSemantics` wrapper on visual text.

### Completion Notes List

- Added `todaySetGoalSemantics` ARB key (EN + FR) and regenerated l10n.
- Wired dedicated semantics label on Set goal button; visual copy unchanged.
- Wrapped visual `Text` in `ExcludeSemantics` so parent action label is announced.
- Added semantics widget tests (enabled, loading disabled, lastDisplayedStepsLoaded disabled).
- Code review: visual-label exclusion assertion, disabled `findsOneWidget`, FR locale smoke.
- All AC satisfied; `flutter test --exclude-tags slow` green.

### File List

- `lib/l10n/app_en.arb`
- `lib/l10n/app_fr.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_fr.dart`
- `lib/presentation/screens/today_screen.dart`
- `test/presentation/screens/today_screen_selector_test.dart`

### Change Log

- 2026-07-17: Dedicated Set goal semantics label (AUD-25) — ARB key, widget wiring, tests.
- 2026-07-17: Code review closed — hardened semantics tests; story marked done.
